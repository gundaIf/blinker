import Combine
import Foundation

@MainActor
final class TimerManager: ObservableObject {
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var isPaused = false
    @Published private(set) var isAutoPausedForIdle = false
    @Published var workDurationMinutes: Int {
        didSet {
            workDurationMinutes = max(1, workDurationMinutes)
            UserDefaults.standard.set(workDurationMinutes, forKey: Self.workDurationKey)
            applyUpdatedWorkDuration()
        }
    }
    @Published var breakDurationSeconds: Int {
        didSet {
            breakDurationSeconds = max(1, breakDurationSeconds)
            UserDefaults.standard.set(breakDurationSeconds, forKey: Self.breakDurationKey)
        }
    }

    var formattedRemainingTime: String {
        Self.timeString(from: remainingSeconds)
    }

    var compactStatusText: String {
        if isBreakActive {
            return "Break"
        }

        if breakManager.isWaitingForInactivity {
            return "Ready"
        }

        if isAutoPausedForIdle {
            return "Idle"
        }

        if isPaused {
            return "Paused"
        }

        if remainingSeconds > 0 && remainingSeconds <= Self.breakWarningLeadTime {
            return "Soon"
        }

        return "Focus"
    }

    var compactNoticeText: String? {
        if breakManager.isWaitingForInactivity {
            return "Break starts when activity stops"
        }

        if !isPaused && remainingSeconds > 0 && remainingSeconds <= Self.breakWarningLeadTime {
            return "Break in \(formattedRemainingTime)"
        }

        return nil
    }

    var isBreakWarningVisible: Bool {
        !isBreakActive && (breakManager.isWaitingForInactivity || (remainingSeconds > 0 && remainingSeconds <= Self.breakWarningLeadTime))
    }

    var breakNoticeTitle: String {
        breakManager.isWaitingForInactivity ? "Break ready" : "Break in \(formattedRemainingTime)"
    }

    var breakNoticeMessage: String {
        if breakManager.isWaitingForInactivity {
            return "You were still typing or clicking when the timer ended. The break will start once activity settles."
        }

        return "Wrap up your current thought. You can skip this break or snooze it for 5 minutes."
    }

    var isBreakActive: Bool {
        breakManager.isBreakActive
    }

    var menuBarTitle: String {
        isBreakActive ? "Break" : formattedRemainingTime
    }

    var statusText: String {
        if isBreakActive {
            return "Break in progress"
        }

        if breakManager.isWaitingForInactivity {
            return "Waiting for activity to stop"
        }

        if isAutoPausedForIdle {
            return "Timer paused while you're idle"
        }

        if isPaused {
            return "Timer paused"
        }

        if remainingSeconds > 0 && remainingSeconds <= Self.breakWarningLeadTime {
            return "Break starts in \(formattedRemainingTime)"
        }

        return "Focus session running"
    }

    private let breakManager: BreakManager
    private var countdownTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var isManuallyPaused = false

    private static let workDurationKey = "workDurationMinutes"
    private static let breakDurationKey = "breakDurationSeconds"
    private static let defaultWorkDuration = 20
    private static let defaultBreakDuration = 20
    private static let breakWarningLeadTime = 60
    private static let snoozeDuration = 5 * 60

    init(breakManager: BreakManager) {
        self.breakManager = breakManager

        let savedWorkDuration = UserDefaults.standard.object(forKey: Self.workDurationKey) as? Int
        let savedBreakDuration = UserDefaults.standard.object(forKey: Self.breakDurationKey) as? Int

        let initialWorkDuration = max(1, savedWorkDuration ?? Self.defaultWorkDuration)
        let initialBreakDuration = max(1, savedBreakDuration ?? Self.defaultBreakDuration)

        workDurationMinutes = initialWorkDuration
        breakDurationSeconds = initialBreakDuration
        remainingSeconds = initialWorkDuration * 60

        observeBreakManager()
        resumeCountdownIfAllowed()
    }

    func togglePause() {
        (isManuallyPaused || isAutoPausedForIdle) ? resume() : pause()
    }

    func pause() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isManuallyPaused = true
        isAutoPausedForIdle = false
        isPaused = true
    }

    func resume() {
        guard !isBreakActive else { return }

        isManuallyPaused = false
        resumeCountdownIfAllowed()
    }

    func resetTimer(startImmediately: Bool = true) {
        breakManager.cancelPendingBreak()
        setCountdown(seconds: workDurationMinutes * 60, startImmediately: startImmediately)
    }

    func skipBreak() {
        breakManager.cancelPendingBreak()
        setCountdown(seconds: workDurationMinutes * 60, startImmediately: true)
    }

    func snoozeBreak() {
        breakManager.cancelPendingBreak()
        setCountdown(seconds: Self.snoozeDuration, startImmediately: true)
    }

    private func startCountdown() {
        guard countdownTimer == nil, !isPaused, !isBreakActive else { return }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTick()
            }
        }

        countdownTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleTick() {
        guard remainingSeconds > 0 else {
            completeWorkSession()
            return
        }

        remainingSeconds -= 1

        if remainingSeconds == 0 {
            completeWorkSession()
        }
    }

    private func completeWorkSession() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isPaused = true
        isAutoPausedForIdle = false
        isManuallyPaused = false

        breakManager.requestBreak(duration: breakDurationSeconds) { [weak self] in
            self?.resetTimer(startImmediately: true)
        }
    }

    private func applyUpdatedWorkDuration() {
        guard !isBreakActive else { return }

        breakManager.cancelPendingBreak()
        let shouldResume = !isPaused || isAutoPausedForIdle

        setCountdown(seconds: workDurationMinutes * 60, startImmediately: shouldResume)
    }

    private func observeBreakManager() {
        breakManager.$isSystemIdle
            .sink { [weak self] isSystemIdle in
                Task { @MainActor [weak self] in
                    self?.handleSystemIdleChange(isSystemIdle)
                }
            }
            .store(in: &cancellables)
    }

    private func handleSystemIdleChange(_ isSystemIdle: Bool) {
        guard !isBreakActive else { return }

        if isSystemIdle {
            autoPauseForIdle()
            return
        }

        guard isAutoPausedForIdle, !isManuallyPaused else { return }

        isAutoPausedForIdle = false
        isPaused = false
        startCountdown()
    }

    private func autoPauseForIdle() {
        guard !isManuallyPaused, !breakManager.isWaitingForInactivity else { return }

        countdownTimer?.invalidate()
        countdownTimer = nil
        isAutoPausedForIdle = true
        isPaused = true
    }

    private func setCountdown(seconds: Int, startImmediately: Bool) {
        countdownTimer?.invalidate()
        countdownTimer = nil
        remainingSeconds = max(0, seconds)
        isManuallyPaused = !startImmediately
        isAutoPausedForIdle = false
        isPaused = !startImmediately

        if startImmediately {
            resumeCountdownIfAllowed()
        }
    }

    private func resumeCountdownIfAllowed() {
        guard !breakManager.isWaitingForInactivity else {
            isPaused = true
            return
        }

        guard !breakManager.isSystemIdle else {
            autoPauseForIdle()
            return
        }

        isAutoPausedForIdle = false
        isPaused = false
        startCountdown()
    }

    private static func timeString(from totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
