import AppKit
import Combine

/// The menu bar item. It shows the timer in the panel's clock style (see `MenuBarContent`),
/// animating each change of the time the way the panel does; a click shows or hides the
/// timer, a right-click opens `StatusMenu`.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let timer: FocusTimer
    private let store: SessionStore
    private let settings: AppSettings
    private let theme: ThemeModel
    private let actions: () -> AppActions
    private var cancellables = Set<AnyCancellable>()
    private var lastRendered: (content: MenuBarContent, tint: MenuBarIcon.Tint?)?
    private var animation: Timer?
    private var transition: (content: MenuBarContent, from: String, start: Date)?

    private static let transitionDuration: TimeInterval = 0.3

    /// - Parameter actions: read when a menu item is chosen, so it sees actions set up later.
    init(timer: FocusTimer, store: SessionStore, settings: AppSettings, theme: ThemeModel,
         actions: @escaping () -> AppActions) {
        self.timer = timer
        self.store = store
        self.settings = settings
        self.theme = theme
        self.actions = actions
        super.init()
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.toolTip = "Stint: click to show or hide the timer, right-click for more"
        }
        Publishers.Merge(timer.objectWillChange, theme.objectWillChange) // theme also relays settings
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.render() }
            .store(in: &cancellables)
        // A tinted image is drawn for the menu bar's current look; redraw when it changes.
        item.button?.publisher(for: \.effectiveAppearance)
            .dropFirst()
            .sink { [weak self] _ in
                self?.lastRendered = nil
                self?.render()
            }
            .store(in: &cancellables)
        render()
    }

    var buttonFrameOnScreen: NSRect? {
        guard let button = item.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func render() {
        guard let button = item.button else { return }
        let content = MenuBarContent(phase: timer.phase, isRunning: timer.isRunning, hasStarted: timer.hasStarted,
                                     progress: timer.progress, elapsed: timer.elapsed, remaining: timer.remaining,
                                     title: timer.title, showsTitle: settings.titleInMenuBarIcon,
                                     style: settings.menuBarIconStyle, clock: settings.clockStyle)
        let tint = settings.coloredMenuBarIcon && content.isBreak ? breakTint(for: button) : nil
        let previous = lastRendered
        if let previous, previous.content == content, previous.tint == tint { return }
        lastRendered = (content, tint)

        button.imagePosition = .imageTrailing // the session title, if shown, reads first
        button.attributedTitle = text(content.title.map { $0 + " " } ?? "", dimmed: content.isDimmed)
        button.setAccessibilityLabel(MenuBarContent.accessibilityLabel(
            phase: timer.phase, isRunning: timer.isRunning, hasStarted: timer.hasStarted, remaining: timer.remaining))

        if let from = previous?.content.time, let to = content.time, from != to,
           timer.isRunning, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            animate(content, from: from)
        } else {
            stopAnimation()
            button.image = MenuBarIcon.image(for: content, tint: tint)
        }
    }

    /// The break color for the cup, lightened on a dark menu bar, with the bar's text color.
    private func breakTint(for button: NSStatusBarButton) -> MenuBarIcon.Tint {
        let isDark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let color = theme.nsColor(for: .shortBreak)
        return MenuBarIcon.Tint(glyph: isDark ? color.blended(withFraction: 0.45, of: .white) ?? color : color,
                                text: isDark ? .white : .black)
    }

    /// Plays the change of time (digits rolling, a tile flipping) over a few frames.
    private func animate(_ content: MenuBarContent, from: String) {
        stopAnimation()
        transition = (content, from, Date())
        drawTransitionFrame()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.drawTransitionFrame() }
        }
        RunLoop.main.add(timer, forMode: .common) // keeps running while a menu is open
        animation = timer
    }

    private func drawTransitionFrame() {
        guard let (content, from, start) = transition else { return }
        let progress = min(1, Date().timeIntervalSince(start) / Self.transitionDuration)
        item.button?.image = MenuBarIcon.image(for: content, transition: MenuBarTransition(from: from, progress: progress),
                                               tint: lastRendered?.tint)
        if progress >= 1 { stopAnimation() }
    }

    private func stopAnimation() {
        animation?.invalidate()
        animation = nil
        transition = nil
    }

    /// Time that isn't counting down is dimmed, like a stopped stopwatch.
    private func text(_ string: String, dimmed: Bool) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: dimmed ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ])
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            item.menu = StatusMenu.make(timer: timer, store: store, settings: settings, actions: actions())
            item.button?.performClick(nil)
            item.menu = nil
        } else {
            actions().togglePanel()
        }
    }
}
