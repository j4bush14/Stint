import Foundation

/// UserDefaults-backed settings.
@MainActor
final class AppSettings: PreferenceStore {
    let defaults: UserDefaults

    /// Tests pass their own suite so they never touch the user's preferences.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // Timer
    @Pref("timer.focusMinutes") var focusMinutes = 25
    @Pref("timer.shortBreakMinutes") var shortBreakMinutes = 5
    @Pref("timer.longBreakMinutes") var longBreakMinutes = 15
    @Pref("timer.sessionsPerCycle") var cycle = 4
    @Pref("timer.autoStartFocus") var startFocusAutomatically = false
    @Pref("timer.autoStartBreaks") var startBreakAutomatically = true
    @Pref("timer.lockIn") var lockIn = false

    // Window
    @Pref("window.hideOnStart") var hideWindowOnTimerStart = false
    @Pref("window.breakTakeover") var fullscreenBreak = false
    @Pref("window.showAtLaunch") var showWindowAtLaunch = true
    /// Show the panel's Hide and ⋯ buttons all the time, not just under the pointer.
    @Pref("window.alwaysShowButtons") var alwaysShowPanelButtons = false

    // Launch
    @Pref("launch.startTimer") var startTimerAtLaunch = false
    @Pref("launch.freshCycle") var resetCycleAtLaunch = false

    // Menu bar
    @Pref("menuBar.style") var menuBarIconStyle: MenuBarIconStyle = .iconAndTime
    @Pref("menuBar.tintDuringBreaks") var coloredMenuBarIcon = true
    @Pref("menuBar.showTitle") var titleInMenuBarIcon = false

    // Notifications & sound
    @Pref("alerts.enabled") var allowNotifications = true
    @Pref("alerts.message") var notificationMessage: NotificationMessage = .encouragement
    @Pref("sound.focusDone") var focusCompleteSound = "Glass"
    @Pref("sound.breakDone") var breakCompleteSound = "Hero"
    @Pref("sound.volume") var notificationsVolume = 0.8
    @Pref("sound.tick") var tickingSound = false

    // Hotkeys
    @Pref("hotkeys.enabled") var globalHotkeys = true

    // Blocking
    @Pref("blocking.apps") var appBlocking = false
    @Pref("blocking.appMode") var appListMode: BlockListMode = .block
    @Pref("blocking.appList") var blockedAppsRaw = ""
    @Pref("blocking.web") var webBlocking = false
    @Pref("blocking.webMode") var webListMode: BlockListMode = .block
    @Pref("blocking.webList") var blockedSitesRaw = "youtube.com\nreddit.com\nnews.ycombinator.com"

    // Calendar
    @Pref("calendar.enabled") var syncWithCalendar = false
    @Pref("calendar.id") var calendarIdentifier = ""

    // Appearance
    @Pref("look.appearance") var appearance: Appearance = .system
    @Pref("look.palette") var palette: Palette = .lagoon
    @Pref("look.panelStyle") var panelStyle: PanelStyle = .glass
    @Pref("look.customColor") var customColorHex = "#7A5AF8"
    /// 0 = mostly clear glass, 1 = strongly colored.
    @Pref("look.tintStrength") var tintStrength = 0.5
    @Pref("look.clockStyle") var clockStyle: ClockStyle = .ring

    var blockedApps: [String] {
        get { blockedAppsRaw.split(separator: "\n").map(String.init) }
        set { blockedAppsRaw = newValue.joined(separator: "\n") }
    }

    var blockedSites: [String] {
        get { blockedSitesRaw.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        set { blockedSitesRaw = newValue.joined(separator: "\n") }
    }
}
