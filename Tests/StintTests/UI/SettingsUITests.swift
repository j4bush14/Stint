import AppKit
import SwiftUI
import Testing
@testable import Stint

extension UITests {
    @MainActor
    @Suite("Settings")
    struct SettingsPanes {
        /// A settings pane beside a live timer panel, to check changes reach the panel. The pane
        /// is built inside the harness so it picks up the test's settings, not the real ones.
        private func paneWithPanel<Pane: View>(@ViewBuilder _ pane: @escaping () -> Pane) -> UIHarness {
            UIHarness(size: CGSize(width: 900, height: 960)) {
                HStack(spacing: 0) {
                    TimerPanelView().frame(width: 320, height: 404)
                    pane().frame(width: 580)
                }
            }
        }

        // MARK: Appearance

        @Test("Clicking a theme swatch selects it", arguments: Palette.allCases)
        func themes(palette: Palette) {
            let ui = paneWithPanel { AppearancePane() }
            #expect(ui.click("palette.\(palette.rawValue)"))
            #expect(ui.settings.palette == palette)
            #expect(ui.value("palette.\(palette.rawValue)") == "selected")
            for other in Palette.allCases where other != palette {
                #expect(ui.value("palette.\(other.rawValue)") == nil, "\(other) should not look selected")
            }
        }

        @Test("Each clock style segment switches the panel's face", arguments: ClockStyle.allCases.enumerated().map { $0 })
        func clockStyleSegments(index: Int, style: ClockStyle) {
            let ui = paneWithPanel { AppearancePane() }
            let count = Double(ClockStyle.allCases.count)
            #expect(ui.click("appearance.clockStyle", at: UnitPoint(x: (Double(index) + 0.5) / count, y: 0.5)))
            #expect(ui.settings.clockStyle == style)
            #expect(ui.value("appearance.clockStyle") == style.rawValue)
            #expect(ui.value("face") == style.rawValue)
        }

        @Test("Appearance toggles flip their settings")
        func appearanceToggles() {
            let ui = paneWithPanel { AppearancePane() }
            let before = (ui.settings.coloredMenuBarIcon, ui.settings.titleInMenuBarIcon)
            ui.toggle("toggle.coloredMenuBarIcon")
            ui.toggle("toggle.titleInMenuBarIcon")
            #expect(ui.settings.coloredMenuBarIcon == !before.0)
            #expect(ui.settings.titleInMenuBarIcon == !before.1)
            #expect(ui.value("toggle.titleInMenuBarIcon") == (before.1 ? "off" : "on"))
        }

        // MARK: Timer

        @Test("Stepping a length updates the setting and the idle panel")
        func steppers() {
            let ui = paneWithPanel { TimerPane() }
            ui.click("stepper.Focus", at: UnitPoint(x: 0.5, y: 0.25))
            #expect(ui.settings.focusMinutes == 26)
            #expect(ui.value("stepper.Focus") == "26")
            #expect(ui.value("panel.time") == "26:00")

            ui.click("stepper.Focus", at: UnitPoint(x: 0.5, y: 0.75))
            ui.click("stepper.Focus", at: UnitPoint(x: 0.5, y: 0.75))
            #expect(ui.settings.focusMinutes == 24)
            #expect(ui.value("panel.time") == "24:00")

            ui.click("stepper.Short break", at: UnitPoint(x: 0.5, y: 0.25))
            #expect(ui.settings.shortBreakMinutes == 6)
            ui.click("stepper.Long break", at: UnitPoint(x: 0.5, y: 0.25))
            #expect(ui.settings.longBreakMinutes == 16)

            ui.click("stepper.Focus sessions per cycle", at: UnitPoint(x: 0.5, y: 0.25))
            #expect(ui.settings.cycle == 5)
            #expect(ui.value("panel.phase") == "focus 1/5")
        }

        @Test("Timer toggles flip their settings, and Lock-In locks the panel")
        func timerToggles() {
            let ui = paneWithPanel { TimerPane() }
            ui.toggle("toggle.startBreakAutomatically")
            #expect(!ui.settings.startBreakAutomatically)
            ui.toggle("toggle.startFocusAutomatically")
            #expect(ui.settings.startFocusAutomatically)

            ui.toggle("toggle.lockIn")
            #expect(ui.settings.lockIn)
            ui.click("transport.playPause")
            ui.click("transport.playPause")
            #expect(ui.timer.isRunning, "Lock-In should stop the pause click")
        }

        // MARK: General

        @Test("General toggles flip their settings")
        func generalToggles() {
            let ui = UIHarness(size: CGSize(width: 580, height: 700)) { GeneralPane() }
            for (name, read) in [
                ("showWindowAtLaunch", { ui.settings.showWindowAtLaunch }),
                ("hideWindowOnTimerStart", { ui.settings.hideWindowOnTimerStart }),
                ("fullscreenBreak", { ui.settings.fullscreenBreak }),
                ("alwaysShowPanelButtons", { ui.settings.alwaysShowPanelButtons }),
            ] as [(String, () -> Bool)] {
                let before = read()
                #expect(ui.toggle("toggle.\(name)"), "\(name) is on screen")
                #expect(read() == !before, "\(name) flips")
            }
        }

        // MARK: Blocking

        @Test("Adding and removing a site by clicking")
        func blockedSites() {
            let ui = UIHarness(size: CGSize(width: 580, height: 820)) { BlockingPane() }
            ui.toggle("toggle.webBlocking")
            #expect(ui.settings.webBlocking)

            ui.click("blocking.siteField")
            ui.type("example.org")
            ui.click("blocking.addSite")
            #expect(ui.settings.blockedSites.contains("example.org"))
            #expect(ui.exists("blocking.remove.example.org"))

            ui.click("blocking.remove.example.org")
            #expect(!ui.settings.blockedSites.contains("example.org"))
            #expect(!ui.exists("blocking.remove.example.org"))
        }

        // MARK: Tags

        @Test("New Tag adds a tag and its name can be edited")
        func tags() {
            let ui = UIHarness(size: CGSize(width: 580, height: 600)) { TagsPane() }
            let count = ui.store.tags.count
            ui.click("tags.new")
            #expect(ui.store.tags.count == count + 1)
            #expect(ui.value("tag.name.\(count)") == "New Tag")
        }
    }
}

extension UITests.SettingsPanes {
    @Test("Alert switches and the volume slider")
    func alerts() {
        let ui = UIHarness(size: CGSize(width: 580, height: 700)) { AlertsPane() }
        ui.toggle("toggle.allowNotifications")
        #expect(!ui.settings.allowNotifications)
        ui.toggle("toggle.tickingSound")
        #expect(ui.settings.tickingSound)
        ui.click("alerts.volume", at: UnitPoint(x: 0.25, y: 0.5))
        #expect(abs(ui.settings.notificationsVolume - 0.25) < 0.1)
    }

    @Test("The global shortcuts switch")
    func shortcuts() {
        let ui = UIHarness(size: CGSize(width: 580, height: 700)) { ShortcutsPane() }
        let before = ui.settings.globalHotkeys
        ui.toggle("toggle.globalHotkeys")
        #expect(ui.settings.globalHotkeys == !before)
    }

    @Test("Renaming a tag by typing")
    func renameTag() throws {
        let ui = UIHarness(size: CGSize(width: 580, height: 600)) { TagsPane() }
        let first = try #require(ui.store.tags.first)
        ui.click("tag.name.\(first.order)") // selects the current name
        ui.type("Reading")
        ui.press(.return)
        #expect(ui.store.tags.first?.title == "Reading")
        #expect(ui.value("tag.name.\(first.order)") == "Reading")
    }
}

extension UITests {
    @MainActor
    @Suite("History")
    struct HistoryWindow {
        @Test("Each range tab switches the period shown", arguments: StatsRange.allCases.enumerated().map { $0 })
        func rangeTabs(index: Int, range: StatsRange) {
            let ui = UIHarness(size: CGSize(width: 640, height: 700)) { HistoryView() }
            let count = Double(StatsRange.allCases.count)
            #expect(ui.click("history.range", at: UnitPoint(x: (Double(index) + 0.5) / count, y: 0.5)))
            #expect(ui.value("history.range") == range.rawValue)
            #expect(ui.value("history.period") != nil)
        }

        @Test("Switching ranges changes the period title")
        func periodChanges() {
            let ui = UIHarness(size: CGSize(width: 640, height: 700)) { HistoryView() }
            let week = ui.value("history.period")
            ui.click("history.range", at: UnitPoint(x: 0.125, y: 0.5)) // Day
            let day = ui.value("history.period")
            ui.click("history.range", at: UnitPoint(x: 0.875, y: 0.5)) // Year
            let year = ui.value("history.period")
            #expect(Set([week, day, year]).count == 3)
        }
    }
}
