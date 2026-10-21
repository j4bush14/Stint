import Combine
import Foundation

// MARK: - Option types

/// What the menu bar item shows. The icon takes the shape of the chosen clock style.
enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    // Raw values predate the icon following the clock style; kept so saved choices survive.
    case iconAndTime = "ringAndTime", iconOnly = "ringOnly", timeOnly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .iconAndTime: "Icon & Time"
        case .iconOnly: "Icon Only"
        case .timeOnly: "Time Only"
        }
    }
}

enum BlockListMode: String, CaseIterable, Identifiable {
    case block, allow
    var id: String { rawValue }
    var label: String { self == .block ? "Block Listed" : "Allow Only Listed" }
}

/// A color theme: one hue for focus, a calmer companion hue for breaks. `custom` and
/// `wallpaper` derive both from a base color supplied at runtime. Colors live in the UI.
enum Palette: String, CaseIterable, Identifiable {
    case lagoon, ember, iris, moss, rose, graphite, wallpaper, custom
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

/// How the timer panel shows the time.
enum ClockStyle: String, CaseIterable, Identifiable {
    case ring, digital, dial, flip
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// What the "focus session done" notification says.
enum NotificationMessage: String, CaseIterable, Identifiable {
    case none, quote, encouragement
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: "Nothing extra"
        case .quote: "A quote"
        case .encouragement: "Encouragement from Apple Intelligence"
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

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
