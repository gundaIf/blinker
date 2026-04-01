import SwiftUI

enum BlinkerMenuBarIconState {
    case focus
    case paused
    case ready
    case warning
    case breakTime
}

struct BlinkerMenuBarIcon: View {
    let state: BlinkerMenuBarIconState

    var body: some View {
        ZStack {
            EyeOutlineShape()
                .stroke(style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))

            indicator
        }
        .frame(width: 15, height: 10)
        .foregroundStyle(Color.primary.opacity(0.88))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .focus:
            Circle()
                .stroke(lineWidth: 1.15)
                .frame(width: 4.1, height: 4.1)

        case .paused:
            HStack(spacing: 1.6) {
                Capsule()
                    .frame(width: 1.35, height: 4.8)

                Capsule()
                    .frame(width: 1.35, height: 4.8)
            }

        case .ready:
            Circle()
                .frame(width: 2.6, height: 2.6)

        case .warning:
            Circle()
                .stroke(lineWidth: 1.05)
                .frame(width: 3.8, height: 3.8)
                .overlay {
                    Circle()
                        .frame(width: 1.3, height: 1.3)
                }

        case .breakTime:
            Capsule()
                .frame(width: 5.8, height: 1.5)
                .offset(y: 0.2)
        }
    }
}

private struct EyeOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        let left = rect.minX + 0.8
        let right = rect.maxX - 0.8
        let top = rect.minY + 1.1
        let bottom = rect.maxY - 1.1

        path.move(to: CGPoint(x: left, y: midY))
        path.addQuadCurve(
            to: CGPoint(x: right, y: midY),
            control: CGPoint(x: midX, y: top)
        )
        path.addQuadCurve(
            to: CGPoint(x: left, y: midY),
            control: CGPoint(x: midX, y: bottom)
        )

        return path
    }
}
