import AppKit
import Testing
@testable import Stint

@Suite("Menu bar content")
struct MenuBarContentTests {
    private func content(phase: Phase = .focus, running: Bool = true, started: Bool = true, progress: Double = 0.5,
                         elapsed: TimeInterval = 75, remaining: TimeInterval = 750, title: String = "",
                         showsTitle: Bool = false, style: MenuBarIconStyle = .iconAndTime,
                         clock: ClockStyle = .ring) -> MenuBarContent {
        MenuBarContent(phase: phase, isRunning: running, hasStarted: started, progress: progress, elapsed: elapsed,
                       remaining: remaining, title: title, showsTitle: showsTitle, style: style, clock: clock)
    }

    @Test("The icon takes the shape of the clock style", arguments: [
        (ClockStyle.ring, MenuBarContent.Glyph.ring(step: 20, mark: .none, second: 15)),
        (.dial, .dial(step: 20, mark: .none, second: 15)),
    ] as [(ClockStyle, MenuBarContent.Glyph)])
    func shapes(clock: ClockStyle, glyph: MenuBarContent.Glyph) {
        #expect(content(clock: clock).glyph == glyph)
    }

    @Test("Digits need no icon while counting, and become tiles for the flip clock")
    func digits() {
        let digital = content(clock: .digital)
        #expect(digital.glyph == nil)
        #expect(digital.time == "12:30")
        #expect(!digital.usesFlipTiles)
        #expect(content(clock: .flip).usesFlipTiles)
    }

    @Test("Ready and paused show ▶ and ❚❚, dim the time and stop the second hand")
    func states() {
        let ready = content(running: false, started: false)
        #expect(ready.glyph == .ring(step: 20, mark: .ready, second: nil))
        #expect(ready.isDimmed)
        let paused = content(running: false)
        #expect(paused.glyph == .ring(step: 20, mark: .paused, second: nil))
        #expect(paused.isDimmed)
        #expect(content(running: false, clock: .digital).glyph == .mark(.paused))
        #expect(!content().isDimmed)
    }

    @Test("Breaks show a cup in every clock style", arguments: ClockStyle.allCases)
    func breaks(clock: ClockStyle) {
        let shown = content(phase: .shortBreak, clock: clock)
        #expect(shown.glyph == .cup)
        #expect(shown.isBreak)
    }

    @Test("Icon Only keeps a ring even for digit styles; Time Only drops the icon")
    func showSetting() {
        let iconOnly = content(style: .iconOnly, clock: .flip)
        #expect(iconOnly.glyph == .ring(step: 20, mark: .none, second: 15))
        #expect(iconOnly.time == nil)
        let timeOnly = content(running: false, style: .timeOnly)
        #expect(timeOnly.glyph == nil)
        #expect(timeOnly.time == "12:30")
        #expect(timeOnly.isDimmed)
    }

    @Test("The second hand goes round once a minute")
    func secondHand() {
        #expect(content(elapsed: 0).glyph == .ring(step: 20, mark: .none, second: 0))
        #expect(content(elapsed: 119.6).glyph == .ring(step: 20, mark: .none, second: 59))
    }

    @Test("The session title shows only when asked for and set")
    func title() {
        #expect(content(title: "Essay").title == nil)
        #expect(content(title: "Essay", showsTitle: true).title == "Essay")
        #expect(content(title: "", showsTitle: true).title == nil)
    }

    @Test("VoiceOver hears the phase, state and time")
    func accessibility() {
        #expect(MenuBarContent.accessibilityLabel(phase: .focus, isRunning: false, hasStarted: true, remaining: 750)
                == "Focus, paused, 12:30 left")
        #expect(MenuBarContent.accessibilityLabel(phase: .longBreak, isRunning: true, hasStarted: true, remaining: 61)
                == "Long Break, 01:01 left")
    }
}

@MainActor
@Suite("Menu bar drawing")
struct MenuBarIconTests {
    private func content(clock: ClockStyle, running: Bool = true) -> MenuBarContent {
        MenuBarContent(phase: .focus, isRunning: running, hasStarted: true, progress: 0.3, elapsed: 30, remaining: 750,
                       title: "", showsTitle: false, style: .iconAndTime, clock: clock)
    }

    @Test("Every style draws a template image the height of the menu bar icon", arguments: ClockStyle.allCases)
    func draws(clock: ClockStyle) throws {
        let image = try #require(MenuBarIcon.image(for: content(clock: clock)))
        #expect(image.isTemplate)
        #expect(image.size.height == MenuBarIcon.height)
        #expect(image.size.width > MenuBarIcon.height)
        #expect(image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
    }

    @Test("Transitions keep the image's size at every frame", arguments: ClockStyle.allCases)
    func transitions(clock: ClockStyle) throws {
        let final = try #require(MenuBarIcon.image(for: content(clock: clock)))
        for progress in stride(from: 0.0, through: 1.0, by: 0.25) {
            let frame = try #require(MenuBarIcon.image(for: content(clock: clock),
                                                       transition: MenuBarTransition(from: "12:31", progress: progress)))
            #expect(frame.size == final.size)
            #expect(frame.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
        }
    }
}

@MainActor
@Suite("Menu bar menu")
struct StatusMenuTests {
    let env = TestEnvironment()

    init() {
        _ = NSApplication.shared // menu items send their actions through the app
    }

    private func menu(_ app: AppEnvironment, actions: AppActions = AppActions()) -> NSMenu {
        StatusMenu.make(timer: app.timer, store: app.store, settings: app.settings, actions: actions)
    }

    private func titles(_ menu: NSMenu) -> [String] { menu.items.map(\.title).filter { !$0.isEmpty } }

    private func choose(_ title: String, in menu: NSMenu) {
        guard let index = menu.items.firstIndex(where: { $0.title == title }) else {
            Issue.record("No \"\(title)\" in \(titles(menu))")
            return
        }
        menu.performActionForItem(at: index)
    }

    @Test("Before starting: where the timer is and what Start will do")
    func ready() {
        let app = env.makeApp()
        let shown = menu(app)
        #expect(titles(shown) == ["Focus · 1 of 4", "Start Focus", "Start For", "Skip to Break", "Tag",
                                  "Show Timer", "History", "Settings…", "Quit Stint"])
        #expect(shown.items[0].subtitle == "25:00 left")
        choose("Start Focus", in: shown)
        #expect(app.timer.isRunning)
    }

    @Test("While running the primary command pauses; then it resumes")
    func runningAndPaused() {
        let app = env.makeApp()
        app.timer.start()
        choose("Pause", in: menu(app))
        #expect(!app.timer.isRunning)
        let paused = menu(app)
        #expect(paused.items[0].subtitle?.contains("paused") == true)
        #expect(titles(paused).contains("Restart Session"))
        choose("Resume", in: paused)
        #expect(app.timer.isRunning)
    }

    @Test("Start For sets the length and starts")
    func startFor() throws {
        let app = env.makeApp()
        let startFor = try #require(menu(app).items.first { $0.title == "Start For" }?.submenu)
        #expect(startFor.items.map(\.title) == TimePicker.presetMinutes.map { "\($0) minutes" })
        choose("45 minutes", in: startFor)
        #expect(app.timer.isRunning)
        #expect(app.timer.phaseLength == 45 * 60)
    }

    @Test("Skip moves on and the next menu offers a new cycle")
    func skipAndNewCycle() {
        let app = env.makeApp()
        choose("Skip to Break", in: menu(app))
        #expect(app.timer.phase == .shortBreak)
        let onBreak = menu(app)
        #expect(titles(onBreak).contains("Start Short Break"))
        #expect(titles(onBreak).contains("Skip Break"))
        choose("Start New Cycle", in: onBreak)
        #expect(app.timer.phase == .focus)
        #expect(app.timer.completedFocus == 0)
    }

    @Test("The tag menu checks the current tag and changes it")
    func tags() throws {
        let app = env.makeApp()
        let tag = try #require(app.store.tags.first)
        let tagMenu = try #require(menu(app).items.first { $0.title == "Tag" }?.submenu)
        #expect(tagMenu.items.first?.state == .on) // No Tag
        choose(tag.title, in: tagMenu)
        #expect(app.timer.selectedTagID == tag.id)
        let again = try #require(menu(app).items.first { $0.title == "Tag" }?.submenu)
        #expect(again.items.first { $0.title == tag.title }?.state == .on)
    }

    @Test("Lock-In disables everything that would end or pause the session")
    func lockIn() {
        let app = env.makeApp()
        app.settings.lockIn = true
        app.timer.start()
        let locked = menu(app)
        for title in ["Pause", "Skip to Break", "Restart Session", "Tag"] {
            #expect(locked.items.first { $0.title == title }?.isEnabled == false, "\(title) is disabled")
        }
        #expect(locked.items[0].subtitle?.contains("Lock-In") == true)
    }

    @Test("Window commands reach the app")
    func windows() {
        let app = env.makeApp()
        final class Log { var entries: [String] = [] }
        let log = Log()
        var actions = AppActions()
        actions.showPanel = { log.entries.append("show") }
        actions.showHistory = { log.entries.append("history") }
        actions.showSettings = { _ in log.entries.append("settings") }
        actions.quit = { log.entries.append("quit") }
        for title in ["Show Timer", "History", "Settings…", "Quit Stint"] { choose(title, in: menu(app, actions: actions)) }
        #expect(log.entries == ["show", "history", "settings", "quit"])
    }

    @Test("With global shortcuts on, the menu shows them")
    func shortcuts() throws {
        let app = env.makeApp()
        app.settings.globalHotkeys = true
        let start = try #require(menu(app).items.first { $0.title == "Start Focus" })
        #expect(start.keyEquivalent == "p")
        #expect(start.keyEquivalentModifierMask == HotkeyCommand.modifierFlags)
    }
}
