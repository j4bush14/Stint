import AppKit
import SwiftUI
import Testing
@testable import Stint

extension UITests {
    /// The Ink panel style: chosen in Settings, and every panel control still works in it.
    @MainActor
    @Suite("Ink style")
    struct InkStyle {
        private func inkPanel(size: CGSize = TimerPanelView.defaultSize, style: ClockStyle = .ring) -> UIHarness {
            let ui = UIHarness(size: size) { TimerPanelView() }
            ui.settings.panelStyle = .ink
            ui.settings.clockStyle = style
            ui.pump()
            return ui
        }

        @Test("Ink is the default; Glass in Settings switches the panel, and Ink switches it back")
        func picker() {
            let ui = UIHarness(size: CGSize(width: 900, height: 960)) {
                HStack(spacing: 0) {
                    TimerPanelView().frame(width: 320, height: 404)
                    AppearancePane().frame(width: 580)
                }
            }
            #expect(ui.value("panel.style") == "ink")

            // The segmented control sits at the trailing end of its row: Glass, then Ink.
            #expect(ui.click("appearance.panelStyle", at: UnitPoint(x: 0.84, y: 0.5)))
            #expect(ui.settings.panelStyle == .glass)
            #expect(ui.value("appearance.panelStyle") == "glass")
            #expect(ui.value("panel.style") == "glass")

            #expect(ui.click("appearance.panelStyle", at: UnitPoint(x: 0.95, y: 0.5)))
            #expect(ui.settings.panelStyle == .ink)
            #expect(ui.value("panel.style") == "ink")
        }

        @Test("Play, pause, reset and skip work in Ink", arguments: ClockStyle.allCases)
        func transport(style: ClockStyle) {
            let ui = inkPanel(style: style)
            #expect(ui.value("panel.style") == "ink")
            #expect(ui.value("face") == style.rawValue)

            #expect(ui.click("transport.playPause"))
            #expect(ui.timer.isRunning)
            ui.env.run(ui.timer, for: 65)
            ui.pump()
            #expect(ui.value("panel.time") == "23:55")

            #expect(ui.click("transport.playPause"))
            #expect(!ui.timer.isRunning)
            #expect(ui.click("transport.reset"))
            #expect(!ui.timer.hasStarted)
            #expect(ui.value("panel.time") == "25:00")

            #expect(ui.click("transport.playPause"))
            #expect(ui.click("transport.skip"))
            #expect(ui.timer.phase == .shortBreak)
            #expect(ui.value("panel.time") == "05:00")
        }

        @Test("The ⋯ menu and the hide button work in Ink")
        func cornerButtons() {
            let ui = UIHarness(size: CGSize(width: 320, height: 60)) { InkCornerButtons() }
            let titles = ui.chooseMenuItem("panel.menu", path: ["Clock Style", "Flip"])
            #expect(titles.contains("Window Size"))
            #expect(ui.settings.clockStyle == .flip)
            #expect(ui.click("panel.hide"))
            #expect(ui.actions.last == "hidePanel")
        }

        @Test("Panel Style in the panel's menu switches between Glass and Ink, with the current one checked")
        func menuSwitch() throws {
            // Right-click opens the same menu as ⋯, which only shows while the pointer is over the panel.
            let size = TimerPanelView.defaultSize
            let ui = UIHarness(size: size) { TimerPanelView() }
            let spot = CGPoint(x: 6, y: size.height / 2)

            let titles = ui.chooseContextMenuItem(at: spot, path: ["Panel Style", "Glass"])
            #expect(titles.contains("Panel Style"))
            #expect(ui.settings.panelStyle == .glass)
            #expect(ui.value("panel.style") == "glass")

            ui.chooseContextMenuItem(at: spot, path: ["Panel Style", "Ink"])
            #expect(ui.settings.panelStyle == .ink)
            #expect(ui.value("panel.style") == "ink")

            let menu = PanelMenu.make(timer: ui.timer, settings: ui.settings, actions: ui.app.actions, onRename: {})
            let styles = try #require(menu.items.first { $0.title == "Panel Style" }?.submenu)
            #expect(styles.items.map(\.title) == ["Glass", "Ink"])
            #expect(styles.items.filter { $0.state == .on }.map(\.title) == ["Ink"])
        }

        @Test("The tag chip opens its menu in Ink")
        func tagMenu() throws {
            let ui = inkPanel()
            let tag = try #require(ui.store.tags.first)
            ui.chooseMenuItem("panel.tag", path: [tag.title])
            #expect(ui.timer.selectedTagID == tag.id)
            #expect(ui.value("panel.tag") == tag.title)
        }

        @Test("The mini bar starts and pauses in Ink")
        func miniBar() {
            let ui = inkPanel(size: CGSize(width: 320, height: 60))
            #expect(ui.click("transport.playPause"))
            #expect(ui.timer.isRunning)
            #expect(ui.click("transport.playPause"))
            #expect(!ui.timer.isRunning)
        }
    }
}

/// The panel's corner buttons in the Ink style, with their real menu.
private struct InkCornerButtons: View {
    @EnvironmentObject private var timer: FocusTimer
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appActions) private var actions

    var body: some View {
        PanelCornerButtons(scale: 1, isVisible: true) {
            PanelMenu.make(timer: timer, settings: settings, actions: actions, onRename: {})
        }
        .environment(\.panelInk, true)
    }
}
