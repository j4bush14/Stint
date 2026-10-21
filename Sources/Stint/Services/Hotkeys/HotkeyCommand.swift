import AppKit
import Carbon.HIToolbox

/// The system-wide shortcuts. Pure data, so Settings can list them.
enum HotkeyCommand: UInt32, CaseIterable, Identifiable {
    case toggleTimer = 1, skip, resetCycle, togglePanel

    var id: UInt32 { rawValue }

    var name: String {
        switch self {
        case .toggleTimer: "Start or stop timer"
        case .skip: "Skip session or break"
        case .resetCycle: "Reset cycle"
        case .togglePanel: "Show or hide window"
        }
    }

    /// Always ⌃⌥⌘ plus this key.
    var keyCode: Int {
        switch self {
        case .toggleTimer: kVK_ANSI_P
        case .skip: kVK_ANSI_N
        case .resetCycle: kVK_ANSI_R
        case .togglePanel: kVK_ANSI_F
        }
    }

    /// The key with the shortcut's modifiers, as menus show it.
    var keyEquivalent: String {
        switch self {
        case .toggleTimer: "p"
        case .skip: "n"
        case .resetCycle: "r"
        case .togglePanel: "f"
        }
    }

    static let modifierFlags: NSEvent.ModifierFlags = [.control, .option, .command]

    var display: String { "⌃⌥⌘" + keyEquivalent.uppercased() }
}
