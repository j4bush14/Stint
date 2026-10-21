import AppKit
import Combine
import SwiftUI

/// A borderless panel that can still take keyboard focus (for typing a title or a time).
final class FloatingPanel: NSPanel {
    /// Esc: return true if handled (e.g. it cancelled an edit); otherwise the panel hides.
    var onEscape: (() -> Bool)?
    /// Focus moved to another window or app.
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        if onEscape?() != true { orderOut(nil) }
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "w" {
            orderOut(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Owns the floating timer panel: its Liquid Glass container, placement under the
/// menu bar icon, size presets and corner radius.
@MainActor
final class TimerPanelController: NSObject, NSWindowDelegate {
    private let app: AppEnvironment
    private let panel: FloatingPanel
    private let glass: NSGlassEffectView
    /// Where the menu bar icon is, for placing the panel beneath it.
    private let anchor: () -> NSRect?
    /// True until the panel has a saved frame or has been placed under the menu bar icon.
    private var needsPlacement: Bool
    private var cancellables = Set<AnyCancellable>()

    private static let autosaveName = "TimerPanel"
    private static let maxCornerRadius: CGFloat = 34

    init(app: AppEnvironment, anchor: @escaping () -> NSRect?) {
        self.app = app
        self.anchor = anchor
        panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: TimerPanelView.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered, defer: false
        )
        // The panel is a pane of Liquid Glass. Its color comes from a wash inside the content
        // (see TimerPanelView): NSGlassEffectView drops `tintColor` whenever the window isn't
        // key, which made the panel flicker between colored and gray as focus moved.
        glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: TimerPanelView.defaultSize))
        needsPlacement = true
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // Liquid Glass draws its own edge and shadow
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentMinSize = TimerPanelView.minSize
        panel.contentMaxSize = TimerPanelView.maxSize
        panel.delegate = self
        // A time being picked is set when focus leaves the panel, and Esc cancels it.
        let timer = app.timer
        panel.onResignKey = { timer.commitTimeEdit() }
        panel.onEscape = {
            guard timer.isEditingTime else { return false }
            timer.cancelTimeEdit()
            return true
        }

        glass.style = app.theme.glassStyle
        let hosting = NSHostingView(rootView: TimerPanelView().appEnvironment(app))
        hosting.sizingOptions = [] // the window decides the size; SwiftUI adapts to it
        glass.contentView = hosting
        panel.contentView = glass
        panel.setContentSize(TimerPanelView.defaultSize)

        needsPlacement = !panel.setFrameUsingName(Self.autosaveName)
        panel.setFrameAutosaveName(Self.autosaveName)
        updateCornerRadius()

        app.wallpaper.track(panel)
        app.settings.objectWillChange
            .receive(on: RunLoop.main) // read the new value, not the old one
            .sink { [weak self] in self?.updateGlassStyle() }
            .store(in: &cancellables)
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        if needsPlacement || !isFullyOnScreen { placeBelowMenuBarIcon() }
        panel.orderFrontRegardless()
        panel.makeKey()
        app.wallpaper.refresh()
    }

    func hide() {
        app.timer.commitTimeEdit()
        panel.orderOut(nil)
    }

    /// Makes the panel take keyboard input (for the time picker and title field).
    func focus() {
        panel.makeKey()
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    /// Animates to a preset size, keeping the top edge and horizontal center in place.
    func resize(to size: CGSize) {
        let old = panel.frame
        var frame = NSRect(x: old.midX - size.width / 2, y: old.maxY - size.height,
                           width: size.width, height: size.height)
        if let screen = panel.screen?.visibleFrame {
            frame.origin.x = min(max(frame.minX, screen.minX + 8), screen.maxX - frame.width - 8)
            frame.origin.y = max(frame.minY, screen.minY + 8)
        }
        panel.setFrame(frame, display: true, animate: true)
        updateCornerRadius()
    }

    func windowDidResize(_ notification: Notification) {
        updateCornerRadius()
        app.wallpaper.refresh()
    }

    func windowDidMove(_ notification: Notification) {
        app.wallpaper.refresh()
    }

    // MARK: Private

    private func updateGlassStyle() {
        if glass.style != app.theme.glassStyle { glass.style = app.theme.glassStyle }
    }

    /// Rounded corners for the larger layouts, a full capsule for the mini bar.
    private func updateCornerRadius() {
        glass.cornerRadius = min(Self.maxCornerRadius, panel.frame.height / 2)
    }

    private var isFullyOnScreen: Bool {
        NSScreen.screens.contains { $0.visibleFrame.insetBy(dx: -1, dy: -1).contains(panel.frame) }
    }

    /// The menu bar icon only has a screen position once the menu bar has laid it out,
    /// so placement happens when the panel is shown rather than at launch.
    private func placeBelowMenuBarIcon() {
        let size = panel.frame.size
        guard let icon = anchor(),
              let screen = NSScreen.screens.first(where: { $0.frame.contains(icon) })?.visibleFrame else {
            if let screen = NSScreen.main?.visibleFrame {
                panel.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 16, y: screen.maxY - size.height - 8))
            }
            return
        }
        let x = min(max(icon.midX - size.width / 2, screen.minX + 8), screen.maxX - size.width - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: screen.maxY - size.height - 8))
        needsPlacement = false
    }
}
