import Foundation

/// Writes focus summaries and encouragement. The app uses `OnDeviceCoach` (Apple
/// Intelligence); tests and previews substitute their own.
protocol FocusCoach: Sendable {
    var isAvailable: Bool { get }
    /// A user-facing explanation when the coach can't be used.
    var unavailableReason: String? { get }

    /// Streams a short summary of a period's sessions, as cumulative snapshots.
    func summary(of sessions: [Session], periodName: String, tags: [Tag]) -> AsyncThrowingStream<String, Error>

    /// One encouraging sentence for a finished focus session, or nil if unavailable or slow.
    func encouragement(afterFocusTitled title: String, minutes: Int, completedToday: Int) async -> String?
}

/// Builds the factual text the coach is given. Pure, so it's unit-tested directly.
enum SummaryPrompt {
    static func describe(_ sessions: [Session], tags: [Tag]) -> String {
        let focusSessions = sessions.filter { $0.phase == .focus }
        let completed = focusSessions.filter(\.isCompleted)
        let focusedMinutes = Int(completed.reduce(0) { $0 + $1.focusedTime } / 60)
        let interruptions = focusSessions.reduce(0) { $0 + $1.interruptions.count }
        var lines = [
            "Completed focus sessions: \(completed.count) of \(focusSessions.count) started",
            "Total focused time: \(focusedMinutes) minutes",
            "Pauses during focus sessions: \(interruptions)",
            "Breaks taken: \(sessions.filter { $0.phase.isBreak && $0.isCompleted }.count)",
        ]

        let byHour = Dictionary(grouping: completed) { Calendar.current.component(.hour, from: $0.startedAt) }
        if let best = byHour.max(by: { $0.value.count < $1.value.count }) {
            lines.append("Most productive hour: \(best.key):00 (\(sessionCount(best.value.count)))")
        }
        let byWeekday = Dictionary(grouping: completed) { Calendar.current.component(.weekday, from: $0.startedAt) }
        if byWeekday.count > 1, let best = byWeekday.max(by: { $0.value.count < $1.value.count }) {
            lines.append("Best day: \(Calendar.current.weekdaySymbols[best.key - 1])")
        }
        let byTag = Dictionary(grouping: completed) { s in tags.first { $0.id == s.tagID }?.title ?? "Untagged" }
        for (tag, list) in byTag.sorted(by: { $0.value.count > $1.value.count }).prefix(4) {
            lines.append("Tag \(tag): \(sessionCount(list.count)), \(Int(list.reduce(0) { $0 + $1.focusedTime } / 60)) minutes")
        }
        let titles = Array(Set(completed.map(\.title).filter { !$0.isEmpty })).prefix(6)
        if !titles.isEmpty {
            lines.append("Session names: \(titles.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    private static func sessionCount(_ n: Int) -> String {
        n == 1 ? "1 session" : "\(n) sessions"
    }
}
