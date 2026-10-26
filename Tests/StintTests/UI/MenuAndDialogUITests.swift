import AppKit
import SwiftUI
import Testing
@testable import Stint

extension UITests {
    /// The ⋯ menu, the right-click menu and the tag menu on the timer panel.
    @MainActor
    @Suite("Panel menus")
    struct PanelMenus {
        /// The window buttons showing, as when the pointer is over the panel, above the phase.
        private func header(onRename: @escaping () -> Void = {}) -> UIHarness {
            UIHarness(size: CGSize(width: 320, height: 60)) {
                VStack {
                    MenuHeader(onRename: onRename)
                    PhaseLabel(scale: 1)
                }
            }
        }

        @Test("The ⋯ menu lists every command")
        func lists() {
            let ui = header()
            let titles = ui.chooseMenuItem("panel.menu", path: [])
            #expect(titles == ["Rename Session…", "Start New Cycle", "Restart at Focus", "Clock Style", "Panel Style", "Window Size",
                               "History", "Settings…", "Hide Window", "Quit Stint"])
        }

        @Test("Clock Style in the ⋯ menu switches the face", arguments: ClockStyle.allCases)
        func clockStyle(style: ClockStyle) {
            let ui = header()
            ui.settings.clockStyle = style == .ring ? .flip : .ring
            ui.chooseMenuItem("panel.menu", path: ["Clock Style", style.label])
            #expect(ui.settings.clockStyle == style)
        }

        @Test("Window Size resizes the panel to the preset", arguments: PanelSizePreset.allCases)
        func windowSize(preset: PanelSizePreset) {
            let ui = header()
            ui.chooseMenuItem("panel.menu", path: ["Window Size", preset.title])
            #expect(ui.actions.last == "resizePanel(\(Int(preset.size.width))x\(Int(preset.size.height)))")
        }

        @Test("Window commands reach the app", arguments: [
            ("History", "showHistory"),
            ("Settings…", "showSettings(last)"),
            ("Hide Window", "hidePanel"),
            ("Quit Stint", "quit"),
        ] as [(String, String)])
        func commands(item: String, action: String) {
            let ui = header()
            ui.chooseMenuItem("panel.menu", path: [item])
            #expect(ui.actions.entries == [action])
        }

        @Test("Rename Session… starts renaming")
        func rename() {
            final class Flag { var set = false }
            let renamed = Flag()
            let ui = header { renamed.set = true }
            ui.chooseMenuItem("panel.menu", path: ["Rename Session…"])
            #expect(renamed.set)
        }

        @Test("Restart at Focus jumps to any focus session in the cycle, with the current one checked")
        func restartAtFocus() throws {
            let ui = header()
            ui.chooseMenuItem("panel.menu", path: ["Restart at Focus", "Focus 3 of 4"])
            #expect(ui.timer.completedFocus == 2)
            #expect(ui.timer.phase == .focus)
            #expect(ui.value("panel.phase") == "focus 3/4")

            ui.chooseMenuItem("panel.menu", path: ["Restart at Focus", "Focus 1 of 4"])
            #expect(ui.value("panel.phase") == "focus 1/4")
            let steps = try #require(ui.lastPoppedMenu?.items.first { $0.title == "Restart at Focus" }?.submenu)
            #expect(steps.items.map(\.title) == ["Focus 1 of 4", "Focus 2 of 4", "Focus 3 of 4", "Focus 4 of 4"])
            #expect(steps.items.filter { $0.state == .on }.map(\.title) == ["Focus 3 of 4"]) // as it was when opened
        }

        @Test("Start New Cycle goes back to the first focus session")
        func newCycle() {
            let ui = header()
            ui.timer.skip()
            ui.timer.skip()
            ui.pump()
            #expect(ui.value("panel.phase") == "focus 2/4")
            ui.chooseMenuItem("panel.menu", path: ["Start New Cycle"])
            #expect(ui.timer.completedFocus == 0)
            #expect(ui.value("panel.phase") == "focus 1/4")
        }

        @Test("The hide button hides the panel")
        func hide() {
            let ui = header()
            ui.click("panel.hide")
            #expect(ui.actions.entries == ["hidePanel"])
        }

        @Test("Right-clicking the panel offers the same menu in every layout", arguments: [
            TimerPanelView.defaultSize, CGSize(width: 240, height: 290), CGSize(width: 560, height: 280),
            CGSize(width: 300, height: 72),
        ])
        func contextMenu(size: CGSize) {
            let ui = UIHarness(size: size) { TimerPanelView() }
            let titles = ui.chooseContextMenuItem(at: CGPoint(x: 6, y: size.height / 2),
                                                  path: ["Clock Style", "Digital"])
            #expect(titles.contains("Window Size"))
            #expect(ui.settings.clockStyle == .digital)
        }

        @Test("Rename from the right-click menu opens the title field")
        func contextRename() {
            let size = TimerPanelView.defaultSize
            let ui = UIHarness(size: size) { TimerPanelView() }
            ui.chooseContextMenuItem(at: CGPoint(x: 6, y: size.height / 2), path: ["Rename Session…"])
            #expect(ui.exists("panel.titleField"))
            ui.type("Essay")
            ui.press(.return)
            #expect(ui.timer.title == "Essay")
        }

        @Test("The tag menu picks a tag, clears it, or opens tag settings")
        func tagMenu() throws {
            let ui = UIHarness(size: TimerPanelView.defaultSize) { TimerPanelView() }
            let tag = try #require(ui.store.tags.sorted { $0.order < $1.order }.last)

            ui.chooseMenuItem("panel.tag", path: [tag.title])
            #expect(ui.timer.selectedTagID == tag.id)
            #expect(ui.value("panel.tag") == tag.title)

            ui.chooseMenuItem("panel.tag", path: ["No Tag"])
            #expect(ui.timer.selectedTagID == nil)
            #expect(ui.value("panel.tag") == "No Tag")

            ui.chooseMenuItem("panel.tag", path: ["Edit Tags…"])
            #expect(ui.actions.last == "showSettings(tags)")
        }
    }
}

extension UITests {
    /// Pop-up menus, file choosers and confirmation alerts in Settings.
    @MainActor
    @Suite("Settings dialogs")
    struct SettingsDialogs {
        /// Pop-up buttons sit at the trailing end of their form row.
        private let popUp = UnitPoint(x: 0.9, y: 0.5)

        @Test("The notification message pop-up", arguments: NotificationMessage.allCases)
        func message(choice: NotificationMessage) {
            let ui = UIHarness(size: CGSize(width: 580, height: 700)) { AlertsPane() }
            ui.settings.notificationMessage = choice == .quote ? .none : .quote
            ui.pump()
            ui.chooseMenuItem("alerts.message", path: [choice.label], at: popUp)
            #expect(ui.settings.notificationMessage == choice)
            #expect(ui.value("alerts.message") == choice.rawValue)
        }

        @Test("The sound pop-ups")
        func sounds() {
            let ui = UIHarness(size: CGSize(width: 580, height: 700)) { AlertsPane() }
            let titles = ui.chooseMenuItem("alerts.sound.Focus finished", path: ["Submarine"], at: popUp)
            #expect(titles == Sounds.names)
            #expect(ui.settings.focusCompleteSound == "Submarine")
            ui.chooseMenuItem("alerts.sound.Break finished", path: ["None"], at: popUp)
            #expect(ui.settings.breakCompleteSound == "None")
        }

        @Test("Block-list mode pop-ups", arguments: ["blocking.appMode", "blocking.webMode"])
        func blockModes(target: String) {
            let ui = UIHarness(size: CGSize(width: 580, height: 820)) { BlockingPane() }
            ui.chooseMenuItem(target, path: [BlockListMode.allow.label], at: popUp)
            #expect(ui.value(target) == BlockListMode.allow.rawValue)
            ui.chooseMenuItem(target, path: [BlockListMode.block.label], at: popUp)
            #expect(ui.value(target) == BlockListMode.block.rawValue)
        }

        @Test("Choose Apps… adds the chosen apps, and they can be removed")
        func chooseApps() {
            let ui = UIHarness(size: CGSize(width: 580, height: 820)) { BlockingPane() }
            ui.fileDialogs.applications = [URL(fileURLWithPath: "/System/Applications/Calculator.app")]
            #expect(ui.click("blocking.chooseApps"))
            #expect(ui.fileDialogs.askedForApplications == 1)
            #expect(ui.settings.blockedApps == ["com.apple.calculator"])
            #expect(ui.exists("blocking.removeApp.com.apple.calculator"))

            ui.click("blocking.chooseApps") // choosing it again doesn't duplicate it
            #expect(ui.settings.blockedApps == ["com.apple.calculator"])

            ui.click("blocking.removeApp.com.apple.calculator")
            #expect(ui.settings.blockedApps.isEmpty)
            #expect(!ui.exists("blocking.removeApp.com.apple.calculator"))
        }

        @Test("Cancelling Choose Apps… changes nothing")
        func chooseNoApps() {
            let ui = UIHarness(size: CGSize(width: 580, height: 820)) { BlockingPane() }
            ui.click("blocking.chooseApps")
            #expect(ui.fileDialogs.askedForApplications == 1)
            #expect(ui.settings.blockedApps.isEmpty)
        }

        @Test("Deleting a tag asks first; Delete removes it, Cancel keeps it", arguments: ["Cancel", "Delete"])
        func deleteTag(answer: String) throws {
            let ui = UIHarness(size: CGSize(width: 580, height: 600)) { TagsPane() }
            let first = try #require(ui.store.tags.first)
            let count = ui.store.tags.count
            ui.click("tag.delete.\(first.order)")
            #expect(ui.hasSheet)
            #expect(Set(ui.sheetButtonTitles) == ["Delete", "Cancel"])
            #expect(ui.pressSheetButton(answer))
            #expect(!ui.hasSheet)
            #expect(ui.store.tags.count == (answer == "Delete" ? count - 1 : count))
            #expect(ui.store.tags.contains { $0.id == first.id } == (answer == "Cancel"))
        }

        @Test("A tag's color menu", arguments: [TagColor.coral, .sage])
        func tagColor(color: TagColor) throws {
            let ui = UIHarness(size: CGSize(width: 580, height: 600)) { TagsPane() }
            let first = try #require(ui.store.tags.first)
            ui.chooseMenuItem("tag.color.\(first.order)", path: [color.rawValue.capitalized])
            #expect(ui.store.tags.first?.color == color)
            #expect(ui.value("tag.color.\(first.order)") == color.rawValue)
        }
    }
}

extension UITests {
    /// The History window's summary. (Its toolbar is bridged into the window by AppKit and
    /// ignores synthetic clicks; `HistoryQuery` covers what the toolbar changes.)
    @MainActor
    @Suite("History summary")
    struct HistorySummary {
        /// The History window with one session finished a minute ago.
        private func history(coach: any FocusCoach = FakeCoach()) -> UIHarness {
            let ui = UIHarness(size: CGSize(width: 640, height: 900), coach: coach) { HistoryView() }
            let end = Date().addingTimeInterval(-60)
            ui.store.upsert(Session(phase: .focus, title: "Draft essay", tagID: nil,
                                    startedAt: end.addingTimeInterval(-25 * 60), completedAt: end, duration: 25 * 60))
            ui.pump()
            return ui
        }

        @Test("Summarize shows the coach's summary")
        func summarize() async {
            let ui = history()
            #expect(ui.click("summary.run"))
            await ui.settle()
            #expect(ui.value("summary") == FakeCoach().summaryParts.last)
        }

        @Test("A failed summary says so")
        func summaryFails() async {
            let ui = history(coach: FakeCoach(fails: true))
            ui.click("summary.run")
            await ui.settle()
            #expect(ui.value("summary") == "failed")
        }

        @Test("Summarize is unavailable when the coach is")
        func summaryUnavailable() {
            let ui = history(coach: FakeCoach(isAvailable: false, unavailableReason: "Not on this Mac."))
            #expect(!ui.exists("summary.run"))
        }
    }

    /// The sheet for one past session, hosted on its own.
    @MainActor
    @Suite("Session details")
    struct SessionDetails {
        private func editor() -> (UIHarness, Session) {
            let end = Date().addingTimeInterval(-60)
            let session = Session(phase: .focus, title: "Draft essay", tagID: nil,
                                  startedAt: end.addingTimeInterval(-1500), completedAt: end, duration: 1500)
            let ui = UIHarness(size: CGSize(width: 440, height: 560)) { SessionDetailView(session: session) }
            ui.store.upsert(session)
            return (ui, session)
        }

        @Test("Save keeps a new title")
        func save() {
            let (ui, session) = editor()
            ui.click("session.title")
            ui.type("Outline")
            ui.click("session.save")
            #expect(ui.store.sessions.first { $0.id == session.id }?.title == "Outline")
        }

        @Test("Cancel throws edits away")
        func cancel() {
            let (ui, session) = editor()
            ui.click("session.title")
            ui.type("Outline")
            ui.click("session.cancel")
            #expect(ui.store.sessions.first { $0.id == session.id }?.title == "Draft essay")
        }
    }
}

extension UITests.TimerPanel {
    @Test("Dragging a picker column changes it, up for more")
    func pickerDrag() {
        let ui = UIHarness(size: TimerPanelView.defaultSize) { TimerPanelView() }
        ui.click("panel.time")
        ui.pump(0.4) // let the picker finish appearing before grabbing a column
        ui.drag("picker.minutes", dy: -36) // three steps of 12 points
        #expect(ui.value("picker.minutes") == "28")
        ui.drag("picker.minutes", dy: 60)
        #expect(ui.value("picker.minutes") == "23")
        ui.press(.return)
        #expect(ui.timer.remaining == 23 * 60)
    }
}

/// The panel's corner buttons with their real menu, built from the hosted environment.
private struct MenuHeader: View {
    @EnvironmentObject private var timer: FocusTimer
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appActions) private var actions
    let onRename: () -> Void

    var body: some View {
        PanelCornerButtons(scale: 1, isVisible: true) {
            PanelMenu.make(timer: timer, settings: settings, actions: actions, onRename: onRename)
        }
    }
}

extension UITests.PanelMenus {
    /// The bug this guards against: the menu was a SwiftUI menu, rebuilt on every tick of a
    /// running timer, so its items moved under the pointer and a click could hit Hide Window.
    /// Now it's a snapshot built when it opens.
    @Test("The ⋯ and right-click menus don't change while the clock runs", arguments: ["⋯ button", "right-click"])
    func menuIsStableWhileRunning(opener: String) throws {
        let ui = UIHarness(size: TimerPanelView.defaultSize) { TimerPanelView() }
        ui.settings.alwaysShowPanelButtons = true
        ui.click("transport.playPause")
        #expect(ui.timer.isRunning)

        if opener == "⋯ button" {
            ui.chooseMenuItem("panel.menu", path: [])
        } else {
            ui.chooseContextMenuItem(at: CGPoint(x: 6, y: TimerPanelView.defaultSize.height / 2), path: [])
        }
        let menu = try #require(ui.lastPoppedMenu, "the menu opened as a snapshot")
        let items = menu.items.map(ObjectIdentifier.init)
        let styles = try #require(menu.items.first { $0.title == "Clock Style" }?.submenu)

        ui.env.run(ui.timer, for: 2) // time passes while it's open
        ui.pump()
        #expect(menu.items.map(ObjectIdentifier.init) == items, "no item was replaced")
        #expect(styles.items.map(\.title) == ClockStyle.allCases.map(\.label))
    }

    @Test("Choosing a clock style while running keeps the window and switches the face", arguments: ClockStyle.allCases)
    func clockStyleWhileRunning(style: ClockStyle) {
        let ui = UIHarness(size: TimerPanelView.defaultSize) { TimerPanelView() }
        ui.settings.alwaysShowPanelButtons = true
        ui.settings.clockStyle = style == .ring ? .flip : .ring
        ui.click("transport.playPause")
        ui.env.run(ui.timer, for: 1)
        ui.chooseMenuItem("panel.menu", path: ["Clock Style", style.label])
        #expect(ui.settings.clockStyle == style)
        #expect(ui.value("face") == style.rawValue)
        #expect(ui.actions.entries.isEmpty, "nothing else (like Hide Window) was triggered")
        #expect(ui.timer.isRunning)
    }
}
