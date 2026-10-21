import Foundation

/// What the menu bar item shows for a moment of the timer. Decided here, drawn by
/// `MenuBarIcon`, so the rules are tested without a menu bar.
///
/// The item mirrors the panel: its shape follows the clock style (a ring, a dial, plain
/// digits or flip tiles), and the timer's state reads at a glance: ▶ when ready to start,
/// ❚❚ when paused, a cup during breaks, and dimmed time whenever it isn't counting down.
struct MenuBarContent: Equatable {
    /// What a glyph says about the timer, drawn small inside or beside it.
    enum Mark: Equatable {
        case none, ready, paused
    }

    enum Glyph: Equatable {
        /// Focus progress as the panel draws it: a ring filling clockwise, or a dial's wedge
        /// of time left. `step` is progress in fortieths, so the icon only redraws when it
        /// visibly changes.
        /// `second` places a hand that sweeps once a minute while the timer runs (nil when it
        /// doesn't), so the icon shows at a glance that time is passing.
        case ring(step: Int, mark: Mark, second: Int?)
        case dial(step: Int, mark: Mark, second: Int?)
        /// A break.
        case cup
        /// Just the state, beside digits that already show the time.
        case mark(Mark)
    }

    static let steps = 40

    var glyph: Glyph?
    /// The time left, or nil when the item shows only its glyph.
    var time: String?
    /// The session title shown before the time, if that's turned on.
    var title: String?
    /// Draw the time as split-flap tiles rather than text.
    var usesFlipTiles = false
    /// The timer isn't counting down (ready or paused), so the time is shown dimmed.
    var isDimmed = false
    var isBreak = false

    init(phase: Phase, isRunning: Bool, hasStarted: Bool, progress: Double, elapsed: TimeInterval,
         remaining: TimeInterval, title: String, showsTitle: Bool, style: MenuBarIconStyle, clock: ClockStyle) {
        let mark: Mark = isRunning ? .none : hasStarted ? .paused : .ready
        let second = isRunning ? Int(elapsed) % 60 : nil
        let showsGlyph = style != .timeOnly
        let showsTime = style != .iconOnly
        let step = Int((min(max(progress, 0), 1) * Double(Self.steps)).rounded())

        if showsGlyph {
            if phase.isBreak {
                glyph = .cup
            } else if clock == .dial {
                glyph = .dial(step: step, mark: mark, second: second)
            } else if clock == .ring || !showsTime {
                glyph = .ring(step: step, mark: mark, second: second)
            } else if mark != .none {
                // Digits already show the time; only say why they aren't moving.
                glyph = .mark(mark)
            }
        }
        if showsTime {
            time = Fmt.clock(remaining)
            usesFlipTiles = clock == .flip
            if showsTitle, !title.isEmpty { self.title = title }
        }
        isDimmed = mark != .none
        isBreak = phase.isBreak
    }

    /// What VoiceOver reads, e.g. "Focus, paused, 12:30 left".
    static func accessibilityLabel(phase: Phase, isRunning: Bool, hasStarted: Bool, remaining: TimeInterval) -> String {
        let state = isRunning ? nil : hasStarted ? "paused" : "ready"
        return [phase.title, state, "\(Fmt.clock(remaining)) left"].compactMap { $0 }.joined(separator: ", ")
    }
}
