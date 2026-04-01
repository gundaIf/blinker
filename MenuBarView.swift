import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var breakManager: BreakManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timerManager.formattedRemainingTime)
                    .font(.inter(size: 31, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary.opacity(0.96))

                Text(timerManager.compactStatusText)
                    .font(.inter(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.48))
                    .textCase(.uppercase)
            }

            if let compactNoticeText = timerManager.compactNoticeText {
                Text(compactNoticeText)
                    .font(.inter(size: 11.5, weight: .regular))
                    .foregroundStyle(Color.primary.opacity(0.42))
            }

            subtleDivider

            HStack(spacing: 6) {
                MenuInlineButton(title: timerManager.isPaused ? "Resume" : "Pause") {
                    timerManager.togglePause()
                }
                .disabled(breakManager.isBreakActive || breakManager.isWaitingForInactivity)

                bullet

                MenuInlineButton(title: "Reset") {
                    timerManager.resetTimer(startImmediately: true)
                }
                .disabled(breakManager.isBreakActive)

                bullet

                MenuInlineButton(title: "Settings") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            if timerManager.isBreakWarningVisible {
                HStack(spacing: 6) {
                    MenuInlineButton(title: "Skip") {
                        timerManager.skipBreak()
                    }

                    bullet

                    MenuInlineButton(title: "Snooze") {
                        timerManager.snoozeBreak()
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            subtleDivider

            MenuInlineButton(title: "Quit") {
                NSApp.terminate(nil)
            }
            .tone(0.42)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 248)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.72))
        )
    }

    private var subtleDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }

    private var bullet: some View {
        Text("•")
            .font(.inter(size: 11, weight: .medium))
            .foregroundStyle(Color.primary.opacity(0.22))
    }
}

private struct MenuInlineButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    private var baseTone: Double = 0.68

    init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.inter(size: 12.5, weight: .medium))
                .foregroundStyle(Color.primary.opacity(isHovered ? min(baseTone + 0.18, 0.92) : baseTone))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(isHovered ? 0.08 : 0.001))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    func tone(_ value: Double) -> MenuInlineButton {
        var copy = self
        copy.baseTone = value
        return copy
    }
}

private extension Font {
    static func inter(size: CGFloat, weight: NSFont.Weight) -> Font {
        let fontNames: [NSFont.Weight: [String]] = [
            .regular: ["Inter-Regular", "Inter"],
            .medium: ["Inter-Medium", "Inter"],
            .semibold: ["Inter-SemiBold", "Inter"],
            .bold: ["Inter-Bold", "Inter"]
        ]

        for fontName in fontNames[weight, default: ["Inter"]] {
            if let font = NSFont(name: fontName, size: size) {
                return Font(font)
            }
        }

        return .system(size: size, weight: weight.swiftUIWeight, design: .rounded)
    }
}

private extension NSFont.Weight {
    var swiftUIWeight: Font.Weight {
        switch self {
        case .bold:
            return .bold
        case .semibold:
            return .semibold
        case .medium:
            return .medium
        default:
            return .regular
        }
    }
}
