import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class BreakManager: ObservableObject {
    @Published private(set) var isBreakActive = false
    @Published private(set) var isWaitingForInactivity = false
    @Published private(set) var isSystemIdle = false
    @Published private(set) var currentIdleDuration: TimeInterval = 0

    private var breakTimer: Timer?
    private var activityTimer: Timer?
    private var overlayWindows: [NSWindow] = []
    private var pendingBreakDuration: Int?
    private var pendingBreakCompletion: (() -> Void)?
    private var lastBreakMessageIndex: Int?

    private let interactionStopThreshold: TimeInterval = 8
    private let systemIdleThreshold: TimeInterval = 60
    private let monitoredEventTypes: [CGEventType] = [
        .keyDown,
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
        .mouseMoved,
        .scrollWheel
    ]
    private let breakMessages = [
        "Let your eyes settle for a moment.",
        "Your screen can wait twenty seconds.",
        "Blink. Breathe. Come back clearer.",
        "A short pause still counts as progress.",
        "Step back for a beat.",
        "Rest your focus, not just your eyes.",
        "Nothing urgent needs your gaze right now.",
        "Take the small break before you need the big one.",
        "The work will still be here in a moment.",
        "Pause now, continue with a steadier mind."
    ]

    init() {
        refreshActivityState()
        startActivityMonitoring()
    }

    var isUserActivelyInteracting: Bool {
        currentIdleDuration < interactionStopThreshold
    }

    func requestBreak(duration: Int, onComplete: @escaping () -> Void) {
        guard !isBreakActive else { return }

        refreshActivityState()

        guard !isUserActivelyInteracting else {
            pendingBreakDuration = duration
            pendingBreakCompletion = onComplete
            isWaitingForInactivity = true
            return
        }

        startBreak(duration: duration, onComplete: onComplete)
    }

    func cancelPendingBreak() {
        pendingBreakDuration = nil
        pendingBreakCompletion = nil
        isWaitingForInactivity = false
    }

    private func startBreak(duration: Int, onComplete: @escaping () -> Void) {
        cancelPendingBreak()

        isBreakActive = true
        showOverlay(duration: duration, message: nextBreakMessage())

        breakTimer?.invalidate()
        breakTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(duration), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.endBreak()
                onComplete()
            }
        }
    }

    private func startActivityMonitoring() {
        activityTimer?.invalidate()
        activityTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshActivityState()
            }
        }
    }

    private func refreshActivityState() {
        currentIdleDuration = monitoredEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0

        isSystemIdle = currentIdleDuration >= systemIdleThreshold

        guard isWaitingForInactivity,
              !isUserActivelyInteracting,
              let pendingBreakDuration,
              let pendingBreakCompletion else {
            return
        }

        startBreak(duration: pendingBreakDuration, onComplete: pendingBreakCompletion)
    }

    private func showOverlay(duration: Int, message: String) {
        overlayWindows = NSScreen.screens.map { screen in
            let window = BreakOverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = false
            window.isMovable = false
            window.hidesOnDeactivate = false
            window.contentView = NSHostingView(rootView: BreakOverlayView(duration: duration, message: message))
            return window
        }

        overlayWindows.forEach { window in
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func endBreak() {
        breakTimer?.invalidate()
        breakTimer = nil
        isBreakActive = false

        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
    }

    private func nextBreakMessage() -> String {
        guard breakMessages.count > 1 else {
            return breakMessages.first ?? "Look away for a moment."
        }

        let availableIndices = breakMessages.indices.filter { $0 != lastBreakMessageIndex }
        let selectedIndex = availableIndices.randomElement() ?? breakMessages.startIndex
        lastBreakMessageIndex = selectedIndex
        return breakMessages[selectedIndex]
    }
}

private final class BreakOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct BreakOverlayView: View {
    let duration: Int
    let message: String
    @State private var isVisible = false
    @State private var isBreathing = false
    @State private var remainingSeconds: Int
    private let backgroundColor = Color(red: 244 / 255, green: 241 / 255, blue: 236 / 255)
    private let primaryTextColor = Color(red: 47 / 255, green: 47 / 255, blue: 47 / 255)
    private let secondaryTextColor = Color(red: 122 / 255, green: 117 / 255, blue: 111 / 255)
    private let accentColor = Color(red: 163 / 255, green: 177 / 255, blue: 138 / 255)

    init(duration: Int, message: String) {
        self.duration = duration
        self.message = message
        _remainingSeconds = State(initialValue: duration)
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return Double(remainingSeconds) / Double(duration)
    }

    private var secondsLabel: String {
        "\(remainingSeconds)"
    }

    var body: some View {
        ZStack {
            BreakBackdropView(
                backgroundColor: backgroundColor,
                accentColor: accentColor,
                isBreathing: isBreathing
            )
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(calmMessage)
                    .font(.system(size: 46, weight: .light, design: .serif))
                    .tracking(-0.8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(primaryTextColor)
                    .lineSpacing(8)
                    .frame(maxWidth: 620)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 10)
                    .animation(.easeOut(duration: 0.5), value: isVisible)

                VStack(spacing: 8) {
                    Text(secondsLabel)
                        .font(.system(size: 34, weight: .regular, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(secondaryTextColor)

                    Text(remainingSeconds == 1 ? "second remaining" : "seconds remaining")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(secondaryTextColor.opacity(0.9))
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 10)
                .animation(.easeOut(duration: 0.55).delay(0.05), value: isVisible)

                Capsule()
                    .fill(accentColor.opacity(0.28))
                    .frame(width: 140, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(accentColor)
                            .frame(width: max(14, 140 * progress), height: 4)
                            .animation(.linear(duration: 0.9), value: progress)
                    }
                    .opacity(isVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.55).delay(0.08), value: isVisible)
            }
            .scaleEffect(isBreathing ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true), value: isBreathing)
            .padding(.horizontal, 96)
            .padding(.vertical, 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .task {
            guard remainingSeconds > 0 else { return }

            isBreathing = true

            withAnimation(.easeOut(duration: 0.5)) {
                isVisible = true
            }

            while remainingSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                guard remainingSeconds > 0 else { break }
                remainingSeconds -= 1
            }
        }
    }

    private var calmMessage: String {
        switch message {
        case "Your screen can wait twenty seconds.":
            return "Look away for a moment"
        case "Step back for a beat.":
            return "Rest your eyes"
        default:
            return message
        }
    }
}

private struct BreakBackdropView: View {
    let backgroundColor: Color
    let accentColor: Color
    let isBreathing: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)

            Circle()
                .fill(accentColor.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 72)
                .scaleEffect(isBreathing ? 1.02 : 1.0)
                .offset(x: -160, y: -120)
                .animation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true), value: isBreathing)

            Circle()
                .fill(accentColor.opacity(0.06))
                .frame(width: 260, height: 260)
                .blur(radius: 84)
                .scaleEffect(isBreathing ? 1.0 : 1.02)
                .offset(x: 200, y: 150)
                .animation(.easeInOut(duration: 5.8).repeatForever(autoreverses: true), value: isBreathing)
        }
    }
}
