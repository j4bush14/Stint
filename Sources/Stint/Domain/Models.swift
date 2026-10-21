import Foundation

// MARK: - Phase

enum Phase: String, Codable, CaseIterable, Identifiable {
    case focus, shortBreak, longBreak
    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var isBreak: Bool { self != .focus }
}

// MARK: - Tags

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

struct Tag: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var color: TagColor
    var order: Int
    var isPresetEnabled = false
    var preset = TagPreset()
}

// MARK: - Sessions

/// A pause inside a session.
struct Interruption: Codable, Hashable {
    var startedAt: Date
    var finishedAt: Date?
}

struct Session: Codable, Identifiable, Hashable {
    var id = UUID()
    var phase: Phase
    var title: String
    var tagID: UUID?
    var startedAt: Date
    var completedAt: Date?
    /// Planned length in seconds.
    var duration: TimeInterval
    var interruptions: [Interruption] = []

    var isCompleted: Bool { completedAt != nil }

    var interruptedTime: TimeInterval {
        interruptions.reduce(0) { total, i in
            total + ((i.finishedAt ?? completedAt ?? Date()).timeIntervalSince(i.startedAt))
        }
    }

    /// Wall-clock span from start to end, including pauses.
    var durationWithInterruptions: TimeInterval {
        (completedAt ?? interruptions.last?.startedAt ?? startedAt).timeIntervalSince(startedAt)
    }

    /// Time actually spent focusing.
    var focusedTime: TimeInterval {
        max(0, durationWithInterruptions - interruptedTime)
    }
}

// MARK: - Formatting

enum Fmt {
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }

    /// The two halves of the clock for flip cards: minutes and seconds, or hours and
    /// minutes once an hour or more is left.
    static func clockParts(_ seconds: TimeInterval) -> (leading: String, trailing: String) {
        let s = max(0, Int(seconds.rounded(.up)))
        return s >= 3600
            ? (String(s / 3600), String(format: "%02d", (s % 3600) / 60))
            : (String(format: "%02d", s / 60), String(format: "%02d", s % 60))
    }

    static func hoursMinutes(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        if m < 60 { return "\(m) min" }
        return "\(m / 60) hr \(m % 60) min"
    }
}
