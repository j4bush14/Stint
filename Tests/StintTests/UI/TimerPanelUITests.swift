import AppKit
import SwiftUI
import Testing
@testable import Stint

/// All UI tests live under one serialized suite: each gets its own app environment, but they
/// share the application's windows and event handling, so they must never overlap.
@MainActor
@Suite("UI", .serialized)
struct UITests {}

extension UITests {
    @MainActor
    @Suite("Timer panel")
    struct TimerPanel {
        private func panel(size: CGSize = TimerPanelView.defaultSize, style: ClockStyle = .ring) -> UIHarness {
            let ui = UIHarness(size: size) { TimerPanelView() }
            ui.settings.clockStyle = style
            ui.pump()
            return ui
        }

        /// A point inside the panel but away from every control.
        private func emptySpot(_ ui: UIHarness, size: CGSize = TimerPanelView.defaultSize) -> CGPoint {
            CGPoint(x: 6, y: size.height * 0.55)
        }

        // MARK: Transport

        @Test("Play, pause and stop update the timer and the display", arguments: ClockStyle.allCases)
        func transport(style: ClockStyle) throws {
            let ui = panel(style: style)
            #expect(ui.value("face") == style.rawValue)
            #expect(ui.value("transport.playPause") == "play")
            #expect(!ui.exists("transport.stop"))

            #expect(ui.click("transport.playPause"))
            #expect(ui.timer.isRunning)
            #expect(ui.value("transport.playPause") == "pause")
            #expect(ui.exists("transport.stop"))
            #expect(ui.exists("transport.skip"))

            ui.env.run(ui.timer, for: 65)
            ui.pump()
            #expect(ui.value("panel.time") == "23:55")

            ui.click("transport.playPause")
            #expect(!ui.timer.isRunning)
            #expect(ui.value("transport.playPause") == "play")

            ui.click("transport.stop")
            #expect(!ui.timer.hasStarted)
            #expect(!ui.exists("transport.stop"))
            #expect(ui.value("panel.time") == "25:00")
        }

        @Test("Skip moves to the break and the header follows")
        func skip() {
            let ui = panel()
            #expect(ui.value("panel.phase") == "focus 1/4")
            ui.click("transport.playPause")
            ui.click("transport.skip")
            #expect(ui.timer.phase == .shortBreak)
            #expect(ui.value("panel.phase") == "shortBreak 2/4")
            #expect(ui.value("panel.time") == "05:00")
            #expect(ui.value("transport.playPause") == "play")
        }

        // MARK: Picking a time

        @Test("Clicking the time opens the picker; arrows, presets and clicking out set it", arguments: ClockStyle.allCases)
        func pickTimeWithClicks(style: ClockStyle) {
            let ui = panel(style: style)
            #expect(ui.click("panel.time"))
            #expect(ui.timer.isEditingTime)
            #expect(ui.exists("picker"))
            #expect(!ui.exists("panel.time"))
            #expect(ui.value("picker") == "25:00")

            ui.click("picker.minutes.up")
            #expect(ui.value("picker") == "26:00")
            #expect(ui.value("picker.minutes") == "26")
            ui.click("picker.seconds.down")
            #expect(ui.value("picker") == "25:59")
            ui.click("picker.preset.45")
            #expect(ui.value("picker") == "45:00")

            // The countdown can't start while picking: Play is inactive.
            ui.click("transport.playPause")
            #expect(!ui.timer.isRunning)

            ui.click(at: emptySpot(ui))
            #expect(!ui.timer.isEditingTime)
            #expect(!ui.exists("picker"))
            #expect(ui.value("panel.time") == "45:00")
            #expect(ui.timer.remaining == 45 * 60)

            ui.click("transport.playPause")
            #expect(ui.timer.isRunning)
        }

        @Test("The picker works from the keyboard")
        func pickTimeWithKeys() {
            let ui = panel()
            ui.click("panel.time")
            ui.press(.up)
            #expect(ui.value("picker") == "26:00")
            ui.press(.right)
            ui.press(.up)
            #expect(ui.value("picker") == "26:01")
            ui.press(.return)
            #expect(!ui.timer.isEditingTime)
            #expect(ui.value("panel.time") == "26:01")

            ui.click("panel.time")
            ui.press(.down)
            ui.press(.escape)
            #expect(!ui.timer.isEditingTime)
            #expect(ui.value("panel.time") == "26:01")
        }

        @Test("Changing the time of a running session holds it, then resumes")
        func editWhileRunning() {
            let ui = panel()
            ui.click("transport.playPause")
            ui.env.run(ui.timer, for: 60)
            ui.click("panel.time")
            #expect(!ui.timer.isRunning)
            ui.click("picker.preset.15")
            ui.click(at: emptySpot(ui))
            #expect(ui.timer.isRunning)
            #expect(ui.value("panel.time") == "15:00")
        }

        // MARK: Title

        @Test("Clicking the title lets you name the session")
        func rename() {
            let ui = panel()
            #expect(ui.click("panel.title"))
            #expect(ui.exists("panel.titleField"))
            ui.type("Write tests")
            ui.press(.return)
            #expect(ui.timer.title == "Write tests")
            #expect(!ui.exists("panel.titleField"))
            #expect(ui.value("panel.title") == "Write tests")
        }

        // MARK: Clock styles

        @Test("Switching clock style while running keeps the time and controls working")
        func switchStyles() {
            let ui = panel()
            ui.click("transport.playPause")
            ui.env.run(ui.timer, for: 30)
            for style in ClockStyle.allCases {
                ui.settings.clockStyle = style
                ui.pump(0.35)
                #expect(ui.value("face") == style.rawValue, "\(style)")
                #expect(ui.value("panel.time") == "24:30", "\(style)")
                #expect(ui.timer.isRunning, "\(style)")
                #expect(ui.exists("transport.stop"), "\(style)")
            }
            ui.click("transport.playPause")
            #expect(!ui.timer.isRunning)
        }

        // MARK: AppSettings reflected live

        @Test("Changing a length in Settings updates an idle panel immediately")
        func settingsUpdatePanel() {
            let ui = panel()
            ui.settings.focusMinutes = 40
            ui.pump()
            #expect(ui.value("panel.time") == "40:00")
            ui.settings.cycle = 6
            ui.pump()
            #expect(ui.value("panel.phase") == "focus 1/6")
        }

        @Test("Choosing a tag shows it on the panel")
        func tagShown() throws {
            let ui = panel()
            let tag = try #require(ui.store.tags.first)
            ui.timer.selectedTagID = tag.id
            ui.pump()
            #expect(ui.value("panel.tag") == tag.title)
        }

        // MARK: Lock-In

        @Test("Lock-In ignores clicks on pause, stop, skip and the time")
        func lockIn() {
            let ui = panel()
            ui.settings.lockIn = true
            ui.click("transport.playPause")
            #expect(ui.timer.isRunning)
            ui.click("transport.playPause")
            ui.click("transport.stop")
            ui.click("transport.skip")
            ui.click("panel.time")
            #expect(ui.timer.isRunning)
            #expect(ui.timer.phase == .focus)
            #expect(!ui.timer.isEditingTime)
        }

        // MARK: Layouts

        @Test("Every layout can pick a time and start", arguments: [
            CGSize(width: 300, height: 72), CGSize(width: 240, height: 290),
            CGSize(width: 560, height: 280), CGSize(width: 460, height: 580),
        ])
        func layouts(size: CGSize) {
            let ui = panel(size: size)
            #expect(ui.click("panel.time"), "time at \(size)")
            #expect(ui.exists("picker"), "picker at \(size)")
            ui.press(.up)
            ui.click(at: CGPoint(x: size.width - 8, y: size.height - 8))
            #expect(!ui.timer.isEditingTime, "click outside at \(size)")
            #expect(ui.timer.remaining == 26 * 60, "at \(size)")
            #expect(ui.click("transport.playPause"), "play at \(size)")
            #expect(ui.timer.isRunning, "at \(size)")
        }

        @Test("Resizing keeps state and switches layout")
        func resize() {
            let ui = panel()
            ui.click("transport.playPause")
            ui.resize(to: CGSize(width: 300, height: 72))
            #expect(ui.timer.isRunning)
            #expect(ui.exists("transport.playPause"))
            #expect(!ui.exists("face"), "the mini bar has no clock face")
            ui.resize(to: TimerPanelView.defaultSize)
            #expect(ui.exists("face"))
            #expect(ui.value("transport.playPause") == "pause")
        }
    }
}

extension UITests.TimerPanel {
    @Test("Hidden window buttons let clicks through; visible ones take them", arguments: [false, true])
    func hiddenButtonsDontCatchClicks(visible: Bool) throws {
        final class Taps { var count = 0 }
        let taps = Taps()
        let ui = UIHarness(size: CGSize(width: 320, height: 60)) {
            ZStack {
                Color.white.opacity(0.001).onTapGesture { taps.count += 1 }
                PanelCornerButtons(scale: 1, isVisible: visible, menu: PanelMenu(onRename: {}))
            }
        }
        #expect(ui.value("panel.hide") == (visible ? "visible" : "hidden"))
        #expect(ui.click("panel.hide"))
        #expect(taps.count == (visible ? 0 : 1))
    }

    @Test("Every time preset sets its length", arguments: TimePicker.presetMinutes)
    func presets(minutes: Int) {
        let ui = UIHarness(size: TimerPanelView.defaultSize) { TimerPanelView() }
        ui.click("panel.time")
        #expect(ui.click("picker.preset.\(minutes)"))
        ui.press(.return)
        #expect(ui.timer.remaining == TimeInterval(minutes * 60))
        #expect(ui.value("panel.time") == TimeFormat.clock(TimeInterval(minutes * 60)))
    }

    @Test("Pressing Space while naming a session types a space, not Start")
    func spaceInTitle() {
        let ui = UIHarness(size: TimerPanelView.defaultSize) { TimerPanelView() }
        ui.click("panel.title")
        ui.type("Deep work")
        ui.press(.return)
        #expect(ui.timer.title == "Deep work")
        #expect(!ui.timer.isRunning)
    }
}

extension UITests.TimerPanel {
    @Test("Hide sits at the top-left and ⋯ at the top-right in every layout", arguments: [
        TimerPanelView.defaultSize, CGSize(width: 240, height: 420), CGSize(width: 460, height: 580),
        CGSize(width: 240, height: 290), CGSize(width: 200, height: 230),
        CGSize(width: 560, height: 280), CGSize(width: 900, height: 520),
    ])
    func windowButtonsInCorners(size: CGSize) throws {
        let ui = UIHarness(size: size) { TimerPanelView() }
        ui.settings.alwaysShowPanelButtons = true
        ui.pump()
        let hide = try #require(ui.frame("panel.hide"))
        let menu = try #require(ui.frame("panel.menu"))
        #expect(ui.value("panel.hide") == "visible")
        #expect(hide.minX < 24 && hide.minY < 24, "Hide at \(hide)")
        #expect(menu.maxX > size.width - 24 && menu.minY < 24, "⋯ at \(menu)")
        #expect(abs(hide.midY - menu.midY) < 1, "both on one line")
        if let phase = ui.frame("panel.phase") {
            #expect(!phase.intersects(hide) && !phase.intersects(menu))
        }
    }

    @Test("The mini bar has Hide first and ⋯ last; Hide moves into ⋯ when narrow", arguments: [
        CGSize(width: 300, height: 72), CGSize(width: 420, height: 120), CGSize(width: 220, height: 60),
    ])
    func windowButtonsInMiniBar(size: CGSize) throws {
        let ui = UIHarness(size: size) { TimerPanelView() }
        ui.settings.alwaysShowPanelButtons = true
        ui.pump()
        let menu = try #require(ui.frame("panel.menu"))
        let play = try #require(ui.frame("transport.playPause"))
        #expect(menu.minX > play.maxX && menu.maxX > size.width - 24)
        if size.width >= 250 {
            let hide = try #require(ui.frame("panel.hide"))
            #expect(hide.minX < 24)
        } else {
            #expect(!ui.exists("panel.hide"))
        }
    }

    @Test("Window buttons wait for the pointer unless set to always show")
    func windowButtonsAlwaysShown() {
        let ui = UIHarness(size: TimerPanelView.defaultSize) { TimerPanelView() }
        #expect(ui.value("panel.hide") == "hidden")
        ui.settings.alwaysShowPanelButtons = true
        ui.pump()
        #expect(ui.value("panel.hide") == "visible")
        ui.click("panel.hide")
        #expect(ui.actions.entries == ["hidePanel"])
    }
}
