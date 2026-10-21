import AppKit
import Combine

/// The menu bar item: a progress ring plus the remaining time. Left-click toggles the window,
/// right-click opens a menu.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let timer: FocusTimer
    private let settings: AppSettings
    private let theme: ThemeModel
    private let actions: () -> AppActions
    private var cancellables = Set<AnyCancellable>()
    private var lastRender = ""

    /// - Parameter actions: read when a menu item is chosen, so it sees actions set up later.
    init(timer: FocusTimer, settings: AppSettings, theme: ThemeModel, actions: @escaping () -> AppActions) {
        self.timer = timer
        self.settings = settings
        self.theme = theme
        self.actions = actions
        super.init()
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }
        Publishers.Merge(timer.objectWillChange, theme.objectWillChange) // theme also relays settings
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.render() }
            .store(in: &cancellables)
        render()
    }

    private func render() {
        guard let button = item.button else { return }
        let style = settings.menuBarIconStyle
        var text = ""
        if style != .ringOnly {
            text = Fmt.clock(timer.remaining)
            if settings.titleInMenuBarIcon, !timer.title.isEmpty { text = "\(timer.title)  \(text)" }
        }
        // Quantize progress so the icon is only redrawn when it visibly changes.
        let step = Int((timer.progress * 40).rounded())
        // During breaks the ring can take a light version of the break color.
        let tint = settings.coloredMenuBarIcon && timer.phase.isBreak
            ? theme.nsColor(for: .shortBreak).blended(withFraction: 0.35, of: .white)
            : nil
        let key = "\(text)|\(step)|\(tint?.hexString ?? "-")|\(timer.isRunning)|\(style.rawValue)"
        guard key != lastRender else { return }
        lastRender = key

        button.title = text.isEmpty ? "" : " " + text
        button.image = style == .timeOnly ? nil : Self.icon(step: step, paused: !timer.isRunning, tint: tint)
        button.setAccessibilityLabel("\(timer.phase.title) \(Fmt.clock(timer.remaining))")
    }

    /// The progress ring; template (adapts to the menu bar) unless given a tint.
    static func icon(step: Int, paused: Bool, tint: NSColor?) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            let color = tint ?? .black
            let inset = rect.insetBy(dx: 1.5, dy: 1.5)
            let ring = NSBezierPath(ovalIn: inset)
            ring.lineWidth = 1.5
            color.setStroke()
            ring.stroke()

            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = inset.width / 2 - 2
            if step > 0 {
                let pie = NSBezierPath()
                pie.move(to: center)
                pie.appendArc(withCenter: center, radius: radius, startAngle: 90,
                              endAngle: 90 - CGFloat(step) / 40 * 360, clockwise: true)
                pie.close()
                color.setFill()
                pie.fill()
            }
            if paused && step == 0 {
                let dot = NSBezierPath(ovalIn: NSRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
                color.setFill()
                dot.fill()
            }
            return true
        }
        image.isTemplate = tint == nil
        return image
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            item.menu = buildMenu()
            item.button?.performClick(nil)
            item.menu = nil
        } else {
            actions().togglePanel()
        }
    }

    var buttonFrameOnScreen: NSRect? {
        guard let button = item.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let header = NSMenuItem(title: "\(timer.phase.title) — \(Fmt.clock(timer.remaining))", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        menu.addItem(action(timer.isRunning ? "Pause" : "Start", #selector(toggleTimer)))
        menu.addItem(action(timer.phase == .focus ? "Skip session" : "Skip break", #selector(skip)))
        menu.addItem(action("Restart cycle", #selector(reset)))
        menu.addItem(.separator())
        menu.addItem(action("Show Window", #selector(showWindow)))
        menu.addItem(action("History", #selector(showStats)))
        menu.addItem(action("Settings…", #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(action("Quit", #selector(quit), key: "q"))
        if timer.isLocked {
            for item in menu.items where [#selector(toggleTimer), #selector(skip), #selector(reset)].contains(item.action) {
                item.isEnabled = false
            }
            menu.autoenablesItems = false
        }
        return menu
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleTimer() { timer.toggle() }
    @objc private func skip() { timer.skip() }
    @objc private func reset() { timer.resetCycle() }
    @objc private func showWindow() { actions().showPanel() }
    @objc private func showStats() { actions().showHistory() }
    @objc private func showSettings() { actions().showSettings(nil) }
    @objc private func quit() { actions().quit() }
}
