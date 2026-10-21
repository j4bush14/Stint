import SwiftUI

/// Startup, timer-window behavior and calendar logging.
struct GeneralPane: View {
    @EnvironmentObject private var s: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Startup") {
                SettingToggle("Open Stint when I log in", isOn: $launchAtLogin, id: "launchAtLogin")
                    .onChange(of: launchAtLogin) { _, v in LaunchAtLogin.set(v); launchAtLogin = LaunchAtLogin.isEnabled }
                SettingToggle("Show the timer window on launch", isOn: $s.showWindowAtLaunch, id: "showWindowAtLaunch")
                SettingToggle("Start the timer on launch", isOn: $s.startTimerAtLaunch, id: "startTimerAtLaunch")
                SettingToggle("Begin a fresh cycle on launch", isOn: $s.resetCycleAtLaunch, id: "resetCycleAtLaunch")
            }
            Section("Timer Window") {
                SettingToggle("Always show the Hide and ⋯ buttons", isOn: $s.alwaysShowPanelButtons, id: "alwaysShowPanelButtons")
                SettingToggle("Hide the window when a session starts", isOn: $s.hideWindowOnTimerStart, id: "hideWindowOnTimerStart")
                SettingToggle("Take over the screen during breaks", isOn: $s.fullscreenBreak, id: "fullscreenBreak")
            }
            CalendarSection()
        }
        .formStyle(.grouped)
    }
}

struct CalendarSection: View {
    @EnvironmentObject private var s: AppSettings
    @EnvironmentObject private var cal: CalendarSync

    var body: some View {
        Section {
            SettingToggle("Log focus sessions to Calendar", isOn: $s.syncWithCalendar, id: "syncWithCalendar")
                .onChange(of: s.syncWithCalendar) { _, on in if on { cal.requestAccess() } }
            if s.syncWithCalendar && cal.authorized {
                Picker("Calendar", selection: $s.calendarIdentifier) {
                    Text("Default").tag("")
                    ForEach(cal.calendars, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) }
                }
            }
        } header: {
            Text("Calendar")
        } footer: {
            footnote("Each finished focus session becomes an event, so your calendar shows where your deep work went.")
        }
        .onAppear { cal.reloadCalendars() }
    }
}
