import SwiftUI

struct SettingsView: View {
    @ObservedObject var timerManager: TimerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Blinker Settings")
                .font(.title2.weight(.semibold))

            Form {
                Stepper(value: $timerManager.workDurationMinutes, in: 1...180) {
                    HStack {
                        Text("Work duration")
                        Spacer()
                        Text("\(timerManager.workDurationMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $timerManager.breakDurationSeconds, in: 5...300, step: 5) {
                    HStack {
                        Text("Break duration")
                        Spacer()
                        Text("\(timerManager.breakDurationSeconds) sec")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Text("Changing the work duration resets the current countdown to the new value.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 360)
    }
}
