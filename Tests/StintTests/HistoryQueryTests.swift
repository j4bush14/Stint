import Foundation
import Testing
@testable import Stint

@Suite("History query")
struct HistoryQueryTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1 // weeks start on Sunday
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    /// Wednesday, October 21, 2026, 10:00 UTC.
    private static let wednesday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 10))!

    private func query(_ range: StatsRange = .week, filter: TagFilter = .all) -> HistoryQuery {
        HistoryQuery(range: range, anchor: Self.wednesday, filter: filter, calendar: Self.calendar)
    }

    private func session(daysFromAnchor days: Double, minutes: Double = 25, tag: UUID? = nil,
                         completed: Bool = true, phase: Phase = .focus) -> Session {
        let start = Self.wednesday.addingTimeInterval(days * 86400)
        return Session(phase: phase, title: "", tagID: tag, startedAt: start,
                       completedAt: completed ? start.addingTimeInterval(minutes * 60) : nil,
                       duration: minutes * 60)
    }

    @Test("Each range covers the calendar period around the anchor", arguments: [
        (StatsRange.day, 1.0), (.week, 7), (.month, 31), (.year, 365),
    ] as [(StatsRange, Double)])
    func intervals(range: StatsRange, days: Double) {
        let interval = query(range).interval
        #expect(interval.contains(Self.wednesday))
        #expect(interval.duration == days * 86400)
    }

    @Test("Titles name the period", arguments: [
        (StatsRange.day, "Oct 21, 2026"), (.week, "Oct 18 – Oct 24"), (.month, "October 2026"), (.year, "2026"),
    ] as [(StatsRange, String)])
    func titles(range: StatsRange, title: String) {
        #expect(query(range).title == title)
    }

    @Test("Shifting moves by whole periods")
    func shifting() {
        var week = query(.week)
        week.shift(by: -1)
        #expect(week.title == "Oct 11 – Oct 17")
        week.shift(by: 2)
        #expect(week.title == "Oct 25 – Oct 31")

        var month = query(.month)
        month.shift(by: -10)
        #expect(month.title == "December 2025")
    }

    @Test("Moving forward is only possible once the next period has begun")
    func forward() {
        let week = query(.week)
        #expect(!week.canMoveForward(now: Self.wednesday))
        #expect(week.canMoveForward(now: week.interval.end))
    }

    @Test("Only sessions inside the period are shown")
    func periodFilter() {
        let inside = session(daysFromAnchor: 1)
        let lastWeek = session(daysFromAnchor: -6)
        let nextWeek = session(daysFromAnchor: 5)
        #expect(query(.week).sessions(from: [inside, lastWeek, nextWeek]) == [inside])
        #expect(query(.month).sessions(from: [inside, lastWeek, nextWeek]).count == 3)
    }

    @Test("The tag filter keeps all, untagged or one tag's sessions")
    func tagFilter() {
        let reading = UUID()
        let tagged = session(daysFromAnchor: 0, tag: reading)
        let other = session(daysFromAnchor: 0, tag: UUID())
        let untagged = session(daysFromAnchor: 0)
        let all = [tagged, other, untagged]
        #expect(query(filter: .all).sessions(from: all) == all)
        #expect(query(filter: .untagged).sessions(from: all) == [untagged])
        #expect(query(filter: .tag(reading)).sessions(from: all) == [tagged])
    }

    @Test("Chart bars add up completed focus time per bucket and tag")
    func bars() {
        let reading = UUID()
        let sessions = [
            session(daysFromAnchor: 0, minutes: 25),
            session(daysFromAnchor: 0.01, minutes: 20),
            session(daysFromAnchor: 0.02, minutes: 30, tag: reading),
            session(daysFromAnchor: 1, minutes: 50),
            session(daysFromAnchor: 0, minutes: 40, completed: false),
            session(daysFromAnchor: 0, minutes: 5, phase: .shortBreak),
        ]
        let bars = query(.week).focusBars(for: sessions) { $0 == reading ? "Reading" : "Untagged" }
        #expect(bars.map(\.tag) == ["Reading", "Untagged", "Untagged"])
        #expect(bars.map(\.minutes) == [30, 45, 50])
        #expect(bars.map(\.date) == [
            Self.calendar.startOfDay(for: Self.wednesday),
            Self.calendar.startOfDay(for: Self.wednesday),
            Self.calendar.startOfDay(for: Self.wednesday.addingTimeInterval(86400)),
        ])
    }
}

@Suite("Scroll stepping")
struct ScrollStepperTests {
    @Test("A mouse wheel notch is one step either way")
    func wheel() {
        var stepper = ScrollStepper()
        #expect(stepper.steps(deltaY: 3, isPrecise: false) == 1)
        #expect(stepper.steps(deltaY: -0.5, isPrecise: false) == -1)
        #expect(stepper.steps(deltaY: 0, isPrecise: false) == 0)
    }

    @Test("Trackpad travel adds up into steps and keeps the remainder")
    func trackpad() {
        var stepper = ScrollStepper(pointsPerStep: 10)
        #expect(stepper.steps(deltaY: 6, isPrecise: true) == 0)
        #expect(stepper.steps(deltaY: 6, isPrecise: true) == 1)  // 12 → one step, 2 left
        #expect(stepper.steps(deltaY: 19, isPrecise: true) == 2) // 21 → two steps, 1 left
        #expect(stepper.steps(deltaY: -31, isPrecise: true) == -3)
    }
}
