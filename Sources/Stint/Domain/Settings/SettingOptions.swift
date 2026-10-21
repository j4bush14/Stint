import Foundation

// The choices behind multiple-choice settings.

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
