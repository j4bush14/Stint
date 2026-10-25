import AppKit

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
