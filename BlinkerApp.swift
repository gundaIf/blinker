import SwiftUI

@main
struct BlinkerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var timerManager: TimerManager
    @StateObject private var breakManager: BreakManager

    init() {
        let breakManager = BreakManager()
        let timerManager = TimerManager(breakManager: breakManager)

        _breakManager = StateObject(wrappedValue: breakManager)
        _timerManager = StateObject(wrappedValue: timerManager)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(timerManager: timerManager, breakManager: breakManager)
        } label: {
            HStack(spacing: 6) {
                BlinkerMenuBarIcon(state: menuBarIconState)
                Text(menuBarTitle)
            }
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView(timerManager: timerManager)
        }
        .defaultSize(width: 360, height: 220)
        .windowResizability(.contentSize)
    }

    private var menuBarTitle: String {
        if breakManager.isBreakActive {
            return "Break"
        }

        if breakManager.isWaitingForInactivity {
            return "Break Due"
        }

        return timerManager.formattedRemainingTime
    }

    private var menuBarIconState: BlinkerMenuBarIconState {
        if breakManager.isBreakActive {
            return .breakTime
        }

        if breakManager.isWaitingForInactivity {
            return .ready
        }

        if timerManager.isBreakWarningVisible {
            return .warning
        }

        return timerManager.isPaused ? .paused : .focus
    }
}
