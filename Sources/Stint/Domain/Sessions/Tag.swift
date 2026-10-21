import Foundation

/// A tag's color, by name; how each looks is up to the UI.
enum TagColor: String, Codable, CaseIterable, Identifiable {
    case sky, violet, coral, amber, sage, slate
    var id: String { rawValue }
}

/// Per-tag timer settings that override the global ones while the tag is selected.
struct TagPreset: Codable, Hashable {
    var focusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var cycle: Int = 4
    var startFocusAutomatically = false
    var startBreakAutomatically = true
}

/// A label for what a session was about, optionally with its own timer lengths.
struct Tag: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var color: TagColor
    var order: Int
    var isPresetEnabled = false
    var preset = TagPreset()
}
