import Foundation

enum StatsRange: String, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    /// Granularity of a chart bar.
    var bucket: Calendar.Component {
        switch self {
        case .day: .hour
        case .week, .month: .day
        case .year: .month
        }
    }
}

enum TagFilter: Hashable {
    case all, untagged, tag(UUID)

    func matches(_ session: Session) -> Bool {
        switch self {
        case .all: true
        case .untagged: session.tagID == nil
        case .tag(let id): session.tagID == id
        }
    }
}

/// Focused minutes for one tag in one chart bucket (an hour, day or month).
struct FocusBar: Identifiable, Equatable {
    let date: Date
    let minutes: Double
    let tag: String
    var id: String { "\(date.timeIntervalSince1970)-\(tag)" }
}

/// What the History window shows: the day, week, month or year containing `anchor`,
/// optionally narrowed to one tag. A plain value, so its rules are tested without a window.
struct HistoryQuery: Hashable {
    var range: StatsRange = .week
    var anchor = Date()
    var filter: TagFilter = .all
    var calendar = Calendar.current

    var interval: DateInterval {
        calendar.dateInterval(of: range.component, for: anchor) ?? DateInterval(start: anchor, duration: 86400)
    }

    /// The sessions that started in the period and match the tag filter.
    func sessions(from all: [Session]) -> [Session] {
        all.filter { interval.contains($0.startedAt) && filter.matches($0) }
    }

    /// Moves a whole period back (negative) or forward.
    mutating func shift(by periods: Int) {
        anchor = calendar.date(byAdding: range.component, value: periods, to: anchor) ?? anchor
    }

    /// Whether the next period has begun, so there's something to move forward to.
    func canMoveForward(now: Date = Date()) -> Bool {
        interval.end <= now
    }

    /// "Oct 20, 2026", "Oct 18 – Oct 24", "October 2026" or "2026".
    var title: String {
        let format = DateFormatter()
        format.calendar = calendar
        format.timeZone = calendar.timeZone
        switch range {
        case .day:
            format.dateStyle = .medium
        case .week:
            format.setLocalizedDateFormatFromTemplate("MMM d")
            let end = interval.end.addingTimeInterval(-1)
            return "\(format.string(from: interval.start)) – \(format.string(from: end))"
        case .month:
            format.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        case .year:
            format.setLocalizedDateFormatFromTemplate("yyyy")
        }
        return format.string(from: anchor)
    }

    /// Completed focus time per chart bucket and tag, oldest first.
    func focusBars(for sessions: [Session], tagName: (UUID?) -> String) -> [FocusBar] {
        var minutes: [String: FocusBar] = [:]
        for session in sessions where session.phase == .focus && session.isCompleted {
            guard let bucket = calendar.dateInterval(of: range.bucket, for: session.startedAt)?.start else { continue }
            let tag = tagName(session.tagID)
            let key = "\(bucket.timeIntervalSince1970)-\(tag)"
            let previous = minutes[key]?.minutes ?? 0
            minutes[key] = FocusBar(date: bucket, minutes: previous + session.focusedTime / 60, tag: tag)
        }
        return minutes.values.sorted { ($0.date, $0.tag) < ($1.date, $1.tag) }
    }
}
