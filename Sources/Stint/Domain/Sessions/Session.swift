import Foundation

/// A pause inside a session.
struct Interruption: Codable, Hashable {
    var startedAt: Date
    var finishedAt: Date?
}

/// One recorded focus session or break, with its pauses.
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
