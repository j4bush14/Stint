import AppKit

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
