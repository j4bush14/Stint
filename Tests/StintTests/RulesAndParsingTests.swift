import Foundation
import Testing
@testable import Stint

@Suite("Website blocking rules")
struct WebBlockingRuleTests {
    private let blockedPage = "file:///blocked.html"

    private func blocked(_ url: String, _ rules: [String], mode: BlockListMode = .block) -> Bool {
        WebBlocker.isBlocked(url, rules: rules, mode: mode, blockedPage: blockedPage)
    }

    @Test("Keywords match anywhere in the address, ignoring case")
    func keywords() {
        #expect(blocked("https://www.reddit.com/r/swift", ["reddit"]))
        #expect(blocked("https://old.REDDIT.com", ["reddit"]))
        #expect(!blocked("https://developer.apple.com", ["reddit"]))
    }

    @Test("Rules starting with = match one exact address prefix")
    func exactPrefix() {
        let rules = ["=https://www.youtube.com/watch"]
        #expect(blocked("https://www.youtube.com/watch?v=1", rules))
        #expect(!blocked("https://www.youtube.com/feed/subscriptions", rules))
    }

    @Test("Allow mode blocks everything that isn't listed")
    func allowMode() {
        #expect(!blocked("https://docs.swift.org", ["swift.org"], mode: .allow))
        #expect(blocked("https://news.ycombinator.com", ["swift.org"], mode: .allow))
    }

    @Test("Tells the blocked page which site it replaced")
    func blockedPageLink() {
        #expect(WebBlocker.blockedPageLink(base: blockedPage, for: "https://www.reddit.com/r/swift")
                == blockedPage + "?site=reddit.com")
        #expect(WebBlocker.blockedPageLink(base: blockedPage, for: "not a url") == blockedPage)
    }

    @Test("Never blocks browser pages or the blocked page itself")
    func ignoresNonWebPages() {
        #expect(!blocked("about:blank", ["about"]))
        #expect(!blocked(blockedPage, ["blocked"], mode: .allow))
    }
}

@Suite("stint:// links")
struct AppCommandLinkTests {
    @Test("Parses simple commands", arguments: [
        ("stint://start", AppCommand.start), ("stint://pause", .pause), ("stint://toggle", .toggle),
        ("stint://stop", .stop), ("stint://skip", .skip), ("stint://rewind", .rewind),
        ("stint://new-cycle", .newCycle), ("stint://show", .showPanel), ("stint://hide", .hidePanel),
        ("stint://history", .showHistory), ("stint://set-time", .editTime), ("STINT://Start", .start),
    ])
    func simple(link: String, command: AppCommand) {
        #expect(AppCommand(url: URL(string: link)!) == command)
    }

    @Test("Opens settings, optionally at a pane")
    func settings() {
        #expect(AppCommand(url: URL(string: "stint://settings")!) == .showSettings(nil))
        #expect(AppCommand(url: URL(string: "stint://settings/appearance")!) == .showSettings(.appearance))
        #expect(AppCommand(url: URL(string: "stint://settings/nonsense")!) == .showSettings(nil))
    }

    @Test("Names the session from the text parameter")
    func name() {
        #expect(AppCommand(url: URL(string: "stint://name?text=Write%20chapter%203")!) == .rename("Write chapter 3"))
        #expect(AppCommand(url: URL(string: "stint://name")!) == .rename(""))
    }

    @Test("Rejects other schemes and unknown commands", arguments: ["https://start", "stint://launch-rockets"])
    func rejects(link: String) {
        #expect(AppCommand(url: URL(string: link)!) == nil)
    }
}

@Suite("App commands")
@MainActor
struct AppCommandTests {
    let env = TestEnvironment()

    @Test("Shortcuts and notification buttons map to commands")
    func sources() {
        #expect(HotkeyCommand.allCases.map(AppCommand.init) == [.toggle, .skip, .newCycle, .togglePanel])
        #expect([NotificationAction.startNext, .skip, .open].map(AppCommand.init) == [.start, .skip, .showPanel])
    }

    @Test("Timer commands drive the timer")
    func timer() {
        let app = env.makeApp()
        AppCommand.start.perform(in: app)
        #expect(app.timer.isRunning)
        AppCommand.pause.perform(in: app)
        #expect(!app.timer.isRunning)
        AppCommand.rename("Essay").perform(in: app)
        #expect(app.timer.title == "Essay")
        AppCommand.skip.perform(in: app)
        #expect(app.timer.phase == .shortBreak)
        AppCommand.newCycle.perform(in: app)
        #expect(app.timer.phase == .focus && app.timer.completedFocus == 0)
    }

    @Test("Window commands reach the app, and editing the time shows the panel first")
    func windows() {
        let app = env.makeApp()
        final class Log { var entries: [String] = [] }
        let log = Log()
        app.actions.showPanel = { log.entries.append("show") }
        app.actions.togglePanel = { log.entries.append("toggle") }
        app.actions.showSettings = { log.entries.append("settings:\($0?.rawValue ?? "-")") }
        for command in [AppCommand.togglePanel, .showSettings(.tags), .editTime] { command.perform(in: app) }
        #expect(log.entries == ["toggle", "settings:tags", "show"])
        #expect(app.timer.isEditingTime)
    }
}

@Suite("Formatting")
struct FormattingTests {
    @Test("Clock format", arguments: [(0.0, "00:00"), (59.2, "01:00"), (1500, "25:00"), (3661, "1:01:01"), (-5, "00:00")])
    func clock(seconds: Double, text: String) {
        #expect(TimeFormat.clock(seconds) == text)
    }

    @Test("Flip clock halves", arguments: [(1500.0, "25", "00"), (59.2, "01", "00"), (5400, "1", "30")])
    func clockParts(seconds: Double, leading: String, trailing: String) {
        #expect(TimeFormat.clockParts(seconds) == (leading, trailing))
    }

    @Test("Hours and minutes", arguments: [(59.0, "0 min"), (1500, "25 min"), (5400, "1 hr 30 min")])
    func hoursMinutes(seconds: Double, text: String) {
        #expect(TimeFormat.hoursMinutes(seconds) == text)
    }
}

@MainActor
@Suite("Timer panel layout")
struct PanelLayoutTests {
    @Test("Picks a layout from the window size", arguments: [
        (CGSize(width: 300, height: 72), TimerPanelView.Layout.mini),
        (CGSize(width: 160, height: 400), .mini),
        (CGSize(width: 240, height: 290), .compact),
        (CGSize(width: 320, height: 404), .tall),
        (CGSize(width: 560, height: 280), .wide),
        (CGSize(width: 1200, height: 520), .wide),
        (CGSize(width: 420, height: 400), .tall),
    ])
    func layout(size: CGSize, expected: TimerPanelView.Layout) {
        #expect(TimerPanelView.layout(for: size) == expected)
    }

    @Test("Every size preset fits within the panel's limits")
    func presetsFit() {
        for preset in PanelSizePreset.allCases {
            #expect(preset.size.width >= TimerPanelView.minSize.width, "\(preset)")
            #expect(preset.size.height >= TimerPanelView.minSize.height, "\(preset)")
            #expect(preset.size.width <= TimerPanelView.maxSize.width, "\(preset)")
        }
    }
}

@MainActor
@Suite("Settings")
struct SettingsTests {
    let env = TestEnvironment()

    @Test("Defaults")
    func defaults() {
        let s = env.settings
        #expect(s.focusMinutes == 25)
        #expect(s.shortBreakMinutes == 5)
        #expect(s.longBreakMinutes == 15)
        #expect(s.cycle == 4)
        #expect(s.startBreakAutomatically)
        #expect(!s.startFocusAutomatically)
        #expect(!s.lockIn)
        #expect(s.palette == .lagoon)
        #expect(s.clockStyle == .ring)
        #expect(s.tintStrength == 0.5)
    }

    @Test("Values persist in the injected defaults")
    func persists() {
        env.settings.focusMinutes = 50
        env.settings.palette = .ember
        env.settings.blockedSites = ["a.com", " ", "b.com"]

        let reloaded = AppSettings(defaults: env.settings.defaults)
        #expect(reloaded.focusMinutes == 50)
        #expect(reloaded.palette == .ember)
        #expect(reloaded.blockedSites == ["a.com", "b.com"])
    }

    @Test("Changes publish so views update")
    func publishes() {
        var changes = 0
        let token = env.settings.objectWillChange.sink { changes += 1 }
        env.settings.cycle = 6
        #expect(changes == 1)
        token.cancel()
    }
}

@Suite("Summary prompt")
struct SummaryPromptTests {
    @Test("Describes the period with real numbers")
    func describe() {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let tag = Tag(title: "Writing", color: .sky, order: 0)
        let sessions = [
            Session(phase: .focus, title: "Draft", tagID: tag.id, startedAt: start,
                    completedAt: start + 1500, duration: 1500),
            Session(phase: .focus, title: "", tagID: nil, startedAt: start + 3600,
                    completedAt: nil, duration: 1500),
            Session(phase: .shortBreak, title: "", tagID: nil, startedAt: start + 1500,
                    completedAt: start + 1800, duration: 300),
        ]
        let text = SummaryPrompt.describe(sessions, tags: [tag])
        #expect(text.contains("Completed focus sessions: 1 of 2 started"))
        #expect(text.contains("Total focused time: 25 minutes"))
        #expect(text.contains("Breaks taken: 1"))
        #expect(text.contains("Tag Writing: 1 session, 25 minutes"))
        #expect(text.contains("Draft"))
    }
}
