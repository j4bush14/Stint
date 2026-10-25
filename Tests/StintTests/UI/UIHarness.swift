import AppKit
import SwiftUI
@testable import Stint

/// Hosts real Stint views in a real window and drives them with real mouse and keyboard
/// events, so tests exercise the same code paths as a person using the app.
///
/// Views get an `AppEnvironment` built from an isolated `TestEnvironment`: throwaway
/// preferences, a temporary folder, a hand-driven clock, a fake coach and fake file dialogs.
/// Controls are found by their `testTarget` names.
///
/// Two things can't be driven this way and are tested at the level below instead: toolbar
/// items AppKit bridges into a titled window ignore synthetic clicks (see `HistoryQuery`), and
/// presenting a SwiftUI `.sheet` after a menu has been tracked ends the test run (sheet
/// contents are hosted directly). Buttons with a destructive role ignore synthetic clicks too,
/// so what they do is covered by store tests. Alerts work, and are covered.
@MainActor
final class UIHarness {
    let env = TestEnvironment()
    let app: AppEnvironment
    let fileDialogs = FakeFileDialogs()
    /// App-level requests the views made (open settings, resize the panel…), in order.
    let actions = ActionLog()
    var timer: FocusTimer { app.timer }
    var settings: AppSettings { env.settings }
    var store: SessionStore { env.store }

    private let window: NSWindow
    private let host: NSView
    private let targets = TargetRegistry()
    /// Menus the views popped up, kept instead of shown (see `MenuPresenter`).
    private let poppedMenus = PoppedMenus()

    /// Finished windows are hidden but kept alive: SwiftUI may still have updates queued for
    /// their views, and freeing a window under it crashes the next test.
    private static var retiredWindows: [NSWindow] = []

    init<Content: View>(size: CGSize, coach: any FocusCoach = FakeCoach(),
                        @ViewBuilder content: () -> Content) {
        _ = NSApplication.shared
        app = env.makeApp(coach: coach, fileDialogs: fileDialogs)
        app.actions = actions.recorder

        let registry = targets
        let root = content()
            .appEnvironment(app)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The test runner is a background process, so every click would count as one that
            // activates the app; gestures ignore those by default. Behave like an active window.
            .allowsWindowActivationEvents(true)
            .environment(\.menuPresenter, poppedMenus.presenter)
            .overlayPreferenceValue(TestTargetsKey.self) { found in
                GeometryReader { proxy in
                    let _ = registry.update(found, in: proxy)
                    Color.clear
                }
            }

        // The app's own panel class, so right-clicks and focus behave as in the app.
        let window = FloatingPanel(contentRect: NSRect(origin: .zero, size: size),
                                   styleMask: [.borderless], backing: .buffered, defer: false)
        window.onEscape = { true } // Esc is for the views under test, not for hiding the window
        window.menuPresenter = poppedMenus.presenter
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = [] // the window decides the size, as in the app
        window.contentView = hosting
        self.window = window
        host = hosting
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: 200, y: 200))
        window.makeKeyAndOrderFront(nil)
        pump(0.3)
    }

    isolated deinit {
        window.attachedSheet.map { window.endSheet($0) }
        window.orderOut(nil)
        Self.retiredWindows.append(window)
    }

    // MARK: Finding

    func exists(_ name: String) -> Bool { targets.items[name] != nil }

    /// What a target currently displays (see `testTarget(_:value:)`).
    func value(_ name: String) -> String? { targets.items[name]?.value }

    func frame(_ name: String) -> CGRect? { targets.items[name]?.frame }

    var targetNames: [String] { targets.items.keys.sorted() }

    // MARK: Clicking

    /// Lets SwiftUI and the run loop catch up (layout, animations, state updates).
    func pump(_ seconds: TimeInterval = 0.2) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Lets tasks the views started on the main actor run, then catches up. Those can't run
    /// while a synchronous test is pumping, because the test itself occupies the main queue.
    func settle(_ seconds: TimeInterval = 0.3) async {
        try? await Task.sleep(for: .seconds(seconds))
        pump()
    }

    /// Clicks the center of a target. Returns false if it isn't on screen.
    @discardableResult
    func click(_ name: String) -> Bool {
        click(name, at: .center)
    }

    /// Clicks at a relative spot inside a target: (0, 0) is its top-left, (1, 1) its
    /// bottom-right. Used for the up arrow of a stepper or one segment of a segmented control.
    @discardableResult
    func click(_ name: String, at spot: UnitPoint) -> Bool {
        guard let point = point(in: name, at: spot) else { return false }
        click(at: point)
        return true
    }

    /// Clicks a point in the view's coordinates (origin top-left).
    func click(at point: CGPoint) {
        clickInWindow(at: windowPoint(point))
    }

    /// Clicks the switch at the trailing end of a toggle's row.
    @discardableResult
    func toggle(_ name: String) -> Bool {
        click(name, at: UnitPoint(x: 0.97, y: 0.5))
    }

    // MARK: Menus

    /// Clicks a control that opens a menu (SwiftUI `Menu`, a pop-up `Picker`) and chooses the
    /// item at `path`, e.g. `["Window Size", "Compact"]` for a submenu item. Returns the
    /// titles of the menu that opened (empty if none did); an empty `path` only looks.
    @discardableResult
    func chooseMenuItem(_ name: String, path: [String], at spot: UnitPoint = .center) -> [String] {
        guard let point = point(in: name, at: spot) else { return [] }
        return withMenuChooser(path: path) { clickInWindow(at: windowPoint(point)) }
    }

    /// The last menu a view popped up, if any (cleared by each `chooseMenuItem`).
    var lastPoppedMenu: NSMenu? { poppedMenus.last }

    /// Right-clicks a point and chooses from the menu that opens.
    @discardableResult
    func chooseContextMenuItem(at point: CGPoint, path: [String]) -> [String] {
        let location = windowPoint(point)
        return withMenuChooser(path: path) { window.sendEvent(mouseEvent(.rightMouseDown, at: location)) }
    }

    // MARK: Other input

    /// Drags vertically from a target's center, in `steps` moves (up is negative `dy`).
    func drag(_ name: String, dy: CGFloat, steps: Int = 8) {
        guard let start = frame(name).map({ CGPoint(x: $0.midX, y: $0.midY) }) else { return }
        NSApp.sendEvent(mouseEvent(.leftMouseDown, at: windowPoint(start)))
        pump(0.05)
        for step in 1...steps {
            let point = CGPoint(x: start.x, y: start.y + dy * CGFloat(step) / CGFloat(steps))
            NSApp.sendEvent(mouseEvent(.leftMouseDragged, at: windowPoint(point)))
            pump(0.02)
        }
        NSApp.sendEvent(mouseEvent(.leftMouseUp, at: windowPoint(CGPoint(x: start.x, y: start.y + dy))))
        pump()
    }

    /// Types text into whatever has keyboard focus.
    func type(_ text: String) {
        for character in text {
            key(String(character), keyCode: 0)
        }
        pump()
    }

    enum Key {
        case `return`, escape, up, down, left, right
        var code: UInt16 {
            switch self {
            case .return: 36
            case .escape: 53
            case .up: 126
            case .down: 125
            case .left: 123
            case .right: 124
            }
        }
        var characters: String {
            switch self {
            case .return: "\r"
            case .escape: "\u{1b}"
            case .up: String(UnicodeScalar(NSUpArrowFunctionKey)!)
            case .down: String(UnicodeScalar(NSDownArrowFunctionKey)!)
            case .left: String(UnicodeScalar(NSLeftArrowFunctionKey)!)
            case .right: String(UnicodeScalar(NSRightArrowFunctionKey)!)
            }
        }
    }

    func press(_ key: Key) {
        self.key(key.characters, keyCode: key.code)
        pump()
    }

    /// Resizes the window, as dragging its edge does.
    func resize(to size: CGSize) {
        window.setContentSize(size)
        pump(0.3)
    }

    // MARK: Sheets and alerts

    /// Whether the real mouse pointer is over the test window (hover effects depend on it).
    var isPointerOverWindow: Bool { window.frame.contains(NSEvent.mouseLocation) }

    /// Whether a sheet (a dialog, an alert or a SwiftUI `.sheet`) is attached to the window.
    var hasSheet: Bool { window.attachedSheet != nil }

    /// Clicks a button in the attached sheet or alert by its title.
    @discardableResult
    func pressSheetButton(_ title: String) -> Bool {
        guard let sheet = window.attachedSheet,
              let button = Self.buttons(in: sheet.contentView).first(where: { $0.title == title }) else { return false }
        button.performClick(nil)
        pump(0.3)
        return true
    }

    /// Titles of the buttons in the attached sheet or alert.
    var sheetButtonTitles: [String] {
        window.attachedSheet.map { Self.buttons(in: $0.contentView).map(\.title).filter { !$0.isEmpty } } ?? []
    }

    // MARK: Private

    private func point(in name: String, at spot: UnitPoint) -> CGPoint? {
        guard let rect = frame(name) else { return nil }
        return CGPoint(x: rect.minX + rect.width * spot.x, y: rect.minY + rect.height * spot.y)
    }

    /// View coordinates (origin top-left) to window coordinates (origin bottom-left).
    private func windowPoint(_ point: CGPoint) -> NSPoint {
        host.convert(NSPoint(x: point.x, y: host.isFlipped ? point.y : host.bounds.height - point.y), to: nil)
    }

    private func clickInWindow(at location: NSPoint) {
        if let control = enclosingControl(at: location) {
            activate(control, at: control.convert(location, from: nil))
        } else {
            // Through NSApp, so `NSApp.currentEvent` is set as in a real click.
            NSApp.sendEvent(mouseEvent(.leftMouseDown, at: location))
            NSApp.sendEvent(mouseEvent(.leftMouseUp, at: location))
        }
        pump()
    }

    /// The native control at a window point, if any (SwiftUI may host its own views inside it).
    private func enclosingControl(at location: NSPoint) -> NSControl? {
        guard let frameView = window.contentView?.superview else { return nil }
        var view = frameView.hitTest(frameView.convert(location, from: nil))
        while let current = view {
            if let field = current as? NSTextField {
                if field.isEditable { return field }
            } else if let control = current as? NSControl {
                return control
            }
            view = current.superview
        }
        return nil
    }

    /// Native controls (switches, steppers, segmented controls, sliders) run a mouse-tracking
    /// loop that reads the event queue, which a test can't feed safely. They're activated the
    /// way a click there would: the control is found by hit-testing the clicked point, and the
    /// click's position picks the stepper arrow, segment or slider value.
    private func activate(_ control: NSControl, at point: NSPoint) {
        switch control {
        case let segmented as NSSegmentedControl:
            var x: CGFloat = 0
            for segment in 0..<segmented.segmentCount {
                let width = segmented.width(forSegment: segment) > 0
                    ? segmented.width(forSegment: segment)
                    : segmented.bounds.width / CGFloat(segmented.segmentCount)
                if point.x < x + width || segment == segmented.segmentCount - 1 {
                    segmented.selectedSegment = segment
                    break
                }
                x += width
            }
            segmented.sendAction(segmented.action, to: segmented.target)
        case let stepper as NSStepper:
            let up = control.isFlipped ? point.y < stepper.bounds.midY : point.y > stepper.bounds.midY
            stepper.doubleValue = min(stepper.maxValue, max(stepper.minValue,
                stepper.doubleValue + (up ? stepper.increment : -stepper.increment)))
            stepper.sendAction(stepper.action, to: stepper.target)
        case let slider as NSSlider:
            let fraction = point.x / slider.bounds.width
            slider.doubleValue = slider.minValue + (slider.maxValue - slider.minValue) * fraction
            slider.sendAction(slider.action, to: slider.target)
        case let field as NSTextField where field.isEditable:
            window.makeFirstResponder(field)
        default:
            control.performClick(nil)
        }
    }

    /// While a menu is open AppKit tracks the mouse modally. The choice is made by a timer that
    /// also runs during menu tracking: it triggers the item's action and closes the menu, as
    /// choosing it would.
    private func withMenuChooser(path: [String], open: () -> Void) -> [String] {
        let chooser = MenuChooser(path: path)
        let observer = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil
        ) { note in
            nonisolated(unsafe) let menu = note.object as? NSMenu
            MainActor.assumeIsolated { if let menu { chooser.began(menu) } }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        poppedMenus.last = nil
        open()
        pump()
        if chooser.titles.isEmpty, let menu = poppedMenus.last {
            // A menu the app pops up itself: choose from the menu it would have shown.
            MenuChooser.choose(path, in: menu)
            pump()
            return menu.items.map(\.title).filter { !$0.isEmpty }
        }
        return chooser.titles
    }

    private func mouseEvent(_ type: NSEvent.EventType, at location: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                           timestamp: ProcessInfo.processInfo.systemUptime,
                           windowNumber: window.windowNumber, context: nil,
                           eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    private func key(_ characters: String, keyCode: UInt16) {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [],
                                         timestamp: ProcessInfo.processInfo.systemUptime,
                                         windowNumber: window.windowNumber, context: nil,
                                         characters: characters, charactersIgnoringModifiers: characters,
                                         isARepeat: false, keyCode: keyCode)!
            window.sendEvent(event)
        }
    }

    private static func buttons(in view: NSView?) -> [NSButton] {
        guard let view else { return [] }
        return ((view as? NSButton).map { [$0] } ?? []) + view.subviews.flatMap { buttons(in: $0) }
    }
}

/// Records the app-level actions views ask for, as readable strings such as
/// `showSettings(tags)` or `resizePanel(240x290)`.
@MainActor
final class ActionLog {
    private(set) var entries: [String] = []

    var last: String? { entries.last }

    var recorder: AppActions {
        AppActions(
            showPanel: { [unowned self] in entries.append("showPanel") },
            hidePanel: { [unowned self] in entries.append("hidePanel") },
            togglePanel: { [unowned self] in entries.append("togglePanel") },
            focusPanel: { [unowned self] in entries.append("focusPanel") },
            resizePanel: { [unowned self] size in entries.append("resizePanel(\(Int(size.width))x\(Int(size.height)))") },
            showSettings: { [unowned self] tab in entries.append("showSettings(\(tab?.rawValue ?? "last"))") },
            showHistory: { [unowned self] in entries.append("showHistory") },
            closeBreakTakeover: { [unowned self] in entries.append("closeBreakTakeover") },
            quit: { [unowned self] in entries.append("quit") }
        )
    }
}

/// Collects target frames (in the hosted view's coordinates) as SwiftUI lays out.
@MainActor
private final class TargetRegistry {
    struct Item {
        var frame: CGRect
        var value: String?
    }

    var items: [String: Item] = [:]

    func update(_ found: [String: TestTarget], in proxy: GeometryProxy) {
        items = found.mapValues { Item(frame: proxy[$0.bounds], value: $0.value) }
    }
}

/// Picks an item from a menu once it starts tracking.
@MainActor
private final class MenuChooser {
    let path: [String]
    private(set) var titles: [String] = []

    init(path: [String]) { self.path = path }

    func began(_ menu: NSMenu) {
        guard titles.isEmpty else { return } // a submenu opening, or a menu already handled
        titles = menu.items.map(\.title).filter { !$0.isEmpty }
        nonisolated(unsafe) let menu = menu // timers fire on the main thread
        let timer = Timer(timeInterval: 0.05, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.choose(in: menu) }
        }
        RunLoop.main.add(timer, forMode: .common) // .common includes menu tracking
    }

    private func choose(in menu: NSMenu) {
        Self.choose(path, in: menu)
        menu.cancelTracking()
    }

    /// Triggers the item at `path`, following submenus, as choosing it would.
    static func choose(_ path: [String], in menu: NSMenu) {
        var current = menu
        for (depth, title) in path.enumerated() {
            guard let index = current.items.firstIndex(where: { $0.title == title }) else { return }
            if depth == path.count - 1 {
                current.performActionForItem(at: index)
            } else if let submenu = current.items[index].submenu {
                submenu.update()
                current = submenu
            }
        }
    }
}

/// Keeps the menus views pop up, so tests can look at them and choose from them.
@MainActor
private final class PoppedMenus {
    var last: NSMenu?

    var presenter: MenuPresenter {
        MenuPresenter { [weak self] menu, _, _ in self?.last = menu }
    }
}
