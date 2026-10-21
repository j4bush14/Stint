import SwiftUI

/// Session lengths, cycle, auto-advance and Lock-In.
struct TimerPane: View {
    @EnvironmentObject private var s: AppSettings

    var body: some View {
        Form {
            Section("Lengths") {
                StepperRow(title: "Focus", value: $s.focusMinutes, range: 1...180, unit: "min")
                StepperRow(title: "Short break", value: $s.shortBreakMinutes, range: 1...60, unit: "min")
                StepperRow(title: "Long break", value: $s.longBreakMinutes, range: 1...120, unit: "min")
            }
            Section {
                StepperRow(title: "Focus sessions per cycle", value: $s.cycle, range: 1...12)
            } header: {
                Text("Cycle")
            } footer: {
                footnote("A long break follows the last focus session of each cycle.")
            }
            Section("Auto-Advance") {
                SettingToggle("Start breaks automatically", isOn: $s.startBreakAutomatically, id: "startBreakAutomatically")
                SettingToggle("Start focus sessions automatically", isOn: $s.startFocusAutomatically, id: "startFocusAutomatically")
            }
            Section {
                SettingToggle("Lock-In", isOn: $s.lockIn, id: "lockIn")
            } footer: {
                footnote("While a focus session runs, pausing, skipping and restarting are disabled. Breaks stay flexible.")
            }
        }
        .formStyle(.grouped)
    }
}
