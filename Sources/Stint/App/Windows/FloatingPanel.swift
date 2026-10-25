import AppKit

/// A borderless panel that can still take keyboard focus (for typing a title or a time).
final class FloatingPanel: NSPanel {
    /// Esc: return true if handled (e.g. it cancelled an edit); otherwise the panel hides.
    var onEscape: (() -> Bool)?
    /// Focus moved to another window or app.
    var onResignKey: (() -> Void)?
    /// About to gain or lose focus, which changes how Liquid Glass draws (clear when focused,
    /// frosted when not). Called first, so the change can be animated.
    var willChangeKey: (() -> Void)?
    /// The menu a right-click (or Control-click) anywhere on the panel opens, built as it opens.
    var makeContextMenu: (() -> NSMenu)?
    var menuPresenter = MenuPresenter.system

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        if onEscape?() != true { orderOut(nil) }
    }

    override func becomeKey() {
        willChangeKey?()
        super.becomeKey()
    }

    override func resignKey() {
        willChangeKey?()
        super.resignKey()
        onResignKey?()
    }

    override func sendEvent(_ event: NSEvent) {
        if let makeContextMenu, Self.isContextClick(event), !isOverText(event), let view = contentView {
            menuPresenter.present(makeContextMenu(), view.convert(event.locationInWindow, from: nil), view)
            return
        }
        super.sendEvent(event)
    }

    private static func isContextClick(_ event: NSEvent) -> Bool {
        event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
    }

    /// Text being edited keeps its own menu (cut, copy, paste).
    private func isOverText(_ event: NSEvent) -> Bool {
        guard let frameView = contentView?.superview else { return false }
        return frameView.hitTest(frameView.convert(event.locationInWindow, from: nil)) is NSText
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "w" {
            orderOut(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
