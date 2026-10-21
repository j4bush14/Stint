import AppKit

/// The status item's menu, built fresh each time it opens so every item reflects the
/// timer right now: the primary command says what it will do ("Start Focus", "Pause",
/// "Resume"), and only commands that make sense are offered.
@MainActor
enum StatusMenu {
    static func make(timer: FocusTimer, store: SessionStore, settings: AppSettings, actions: AppActions) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let locked = timer.isLocked
        // When the global shortcuts are on, the menu shows them as reminders.
        let shortcut = { (command: HotkeyCommand) in settings.globalHotkeys ? command : nil }

        menu.addItem(header(timer: timer, store: store))
        menu.addItem(.separator())

        let primary = ClosureMenuItem(primaryTitle(timer), symbol: timer.isRunning ? "pause.fill" : "play.fill",
                                      shortcut: shortcut(.toggleTimer)) { timer.toggle() }
        primary.isEnabled = !locked
        menu.addItem(primary)

        if !timer.hasStarted {
            let startFor = NSMenuItem(title: "Start For", action: nil, keyEquivalent: "")
            startFor.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
            startFor.submenu = NSMenu()
            for minutes in TimePicker.presetMinutes {
                startFor.submenu?.addItem(ClosureMenuItem("\(minutes) minutes") {
                    timer.setTimeLeft(TimeInterval(minutes * 60))
                    timer.start()
                })
            }
            menu.addItem(startFor)
        }

        let skip = ClosureMenuItem(timer.phase == .focus ? "Skip to Break" : "Skip Break",
                                   symbol: "forward.end.fill", shortcut: shortcut(.skip)) { timer.skip() }
        skip.isEnabled = !locked
        menu.addItem(skip)

        if timer.canReset {
            let reset = ClosureMenuItem("Reset Timer", symbol: "arrow.counterclockwise") { timer.stop() }
            reset.isEnabled = !locked
            menu.addItem(reset)
        }
        if timer.completedFocus > 0 || timer.phase != .focus {
            let newCycle = ClosureMenuItem("Start New Cycle", symbol: "arrow.trianglehead.2.clockwise",
                                           shortcut: shortcut(.resetCycle)) { timer.resetCycle() }
            newCycle.isEnabled = !locked
            menu.addItem(newCycle)
        }

        menu.addItem(tagItem(timer: timer, store: store, enabled: !locked))
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Show Timer", symbol: "macwindow", shortcut: shortcut(.togglePanel)) { actions.showPanel() })
        menu.addItem(ClosureMenuItem("History", symbol: "chart.bar.xaxis") { actions.showHistory() })
        menu.addItem(ClosureMenuItem("Settings…", symbol: "gearshape", key: ",") { actions.showSettings(nil) })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Quit Stint", key: "q") { actions.quit() })
        return menu
    }

    /// "Start Focus", "Start Long Break", "Pause" or "Resume".
    static func primaryTitle(_ timer: FocusTimer) -> String {
        timer.isRunning ? "Pause" : timer.hasStarted ? "Resume" : "Start \(timer.phase.title)"
    }

    /// Where the timer is, e.g. "Focus · 2 of 4" over "12:30 left · Essay · Deep Work".
    private static func header(timer: FocusTimer, store: SessionStore) -> NSMenuItem {
        let title = timer.phase == .focus
            ? "Focus · \(timer.focusNumber) of \(timer.cycle)"
            : timer.phase.title
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        var details = ["\(TimeFormat.clock(timer.remaining)) left"]
        if timer.hasStarted && !timer.isRunning { details.append("paused") }
        if !timer.title.isEmpty { details.append(timer.title) }
        if let tag = store.tag(for: timer.selectedTagID) { details.append(tag.title) }
        if timer.isLocked { details.append("Lock-In") }
        item.subtitle = details.joined(separator: " · ")
        return item
    }

    private static func tagItem(timer: FocusTimer, store: SessionStore, enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: "Tag", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "tag", accessibilityDescription: nil)
        item.isEnabled = enabled
        let submenu = NSMenu()
        let choices: [(String, UUID?)] = [("No Tag", nil)] + store.tags.sorted { $0.order < $1.order }.map { ($0.title, $0.id) }
        for (title, id) in choices {
            let choice = ClosureMenuItem(title) { timer.selectedTagID = id }
            choice.state = timer.selectedTagID == id ? .on : .off
            submenu.addItem(choice)
        }
        item.submenu = submenu
        return item
    }
}

/// A menu item that runs a closure, so menus need no target object per command.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, symbol: String? = nil, key: String = "", shortcut: HotkeyCommand? = nil,
         handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(runHandler), keyEquivalent: shortcut?.keyEquivalent ?? key)
        target = self
        if shortcut != nil { keyEquivalentModifierMask = HotkeyCommand.modifierFlags }
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func runHandler() { handler() }
}
