import AppKit
import SwiftUI

/// The panel's menu, opened by the ⋯ button or a right-click anywhere on the panel.
///
/// It's an AppKit menu built when it opens, a snapshot of that moment. (A SwiftUI menu is
/// rebuilt whenever the timer ticks, so while the clock ran, its items were replaced under
/// the pointer every second and a click could land on Hide Window instead of a clock style.)
@MainActor
enum PanelMenu {
    static func make(timer: FocusTimer, settings: AppSettings, actions: AppActions,
                     onRename: @escaping () -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(ClosureMenuItem("Rename Session…", symbol: "pencil", handler: onRename))
        let newCycle = ClosureMenuItem("Start New Cycle", symbol: "arrow.trianglehead.2.clockwise") { timer.resetCycle() }
        newCycle.isEnabled = !timer.isLocked
        menu.addItem(newCycle)
        menu.addItem(restartFocusItem(timer: timer))
        menu.addItem(.separator())
        menu.addItem(clockStyleItem(settings: settings))
        menu.addItem(panelStyleItem(settings: settings))
        menu.addItem(windowSizeItem(actions: actions))
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("History", symbol: "chart.bar.xaxis") { actions.showHistory() })
        menu.addItem(ClosureMenuItem("Settings…", symbol: "gearshape") { actions.showSettings(nil) })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Hide Window", symbol: "xmark") { actions.hidePanel() })
        menu.addItem(ClosureMenuItem("Quit Stint") { actions.quit() })
        return menu
    }

    /// "Clock Style ▸ Ring / Digital / Dial / Flip", with the current one checked.
    /// The menu bar's menu offers the same submenu.
    static func clockStyleItem(settings: AppSettings) -> NSMenuItem {
        let item = NSMenuItem(title: "Clock Style", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
        let submenu = NSMenu()
        for style in ClockStyle.allCases {
            let choice = ClosureMenuItem(style.label) {
                withAnimation(.smooth) { settings.clockStyle = style }
            }
            choice.state = settings.clockStyle == style ? .on : .off
            submenu.addItem(choice)
        }
        item.submenu = submenu
        return item
    }

    /// "Restart at Focus ▸ Focus 1 of 4 …", one item per focus session in the cycle, with the
    /// one under way checked. The menu bar's menu offers the same submenu.
    static func restartFocusItem(timer: FocusTimer) -> NSMenuItem {
        let item = NSMenuItem(title: "Restart at Focus", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "arrow.uturn.backward", accessibilityDescription: nil)
        item.isEnabled = !timer.isLocked
        let submenu = NSMenu()
        for index in 0..<timer.cycle {
            let choice = ClosureMenuItem("Focus \(index + 1) of \(timer.cycle)") { timer.restartFocus(at: index) }
            choice.state = timer.phase == .focus && timer.completedFocus == index ? .on : .off
            submenu.addItem(choice)
        }
        item.submenu = submenu
        return item
    }

    /// "Panel Style ▸ Glass / Ink", with the current one checked. The menu bar's menu offers
    /// the same submenu.
    static func panelStyleItem(settings: AppSettings) -> NSMenuItem {
        let item = NSMenuItem(title: "Panel Style", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "paintbrush.pointed", accessibilityDescription: nil)
        let submenu = NSMenu()
        for style in PanelStyle.allCases {
            let choice = ClosureMenuItem(style.label) {
                withAnimation(.smooth) { settings.panelStyle = style }
            }
            choice.state = settings.panelStyle == style ? .on : .off
            submenu.addItem(choice)
        }
        item.submenu = submenu
        return item
    }

    private static func windowSizeItem(actions: AppActions) -> NSMenuItem {
        let item = NSMenuItem(title: "Window Size", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        let submenu = NSMenu()
        for preset in PanelSizePreset.allCases {
            submenu.addItem(ClosureMenuItem(preset.title) { actions.resizePanel(preset.size) })
        }
        item.submenu = submenu
        return item
    }
}

/// The ⋯ button. Opens the panel menu just below itself.
struct PanelMenuButton: View {
    let scale: CGFloat
    let isVisible: Bool
    let makeMenu: () -> NSMenu
    @Environment(\.menuPresenter) private var presenter
    @State private var anchor = MenuAnchor()

    var body: some View {
        Button {
            anchor.popUp(makeMenu(), with: presenter)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12 * scale, weight: .semibold))
                .frame(width: panelButtonSize * scale, height: panelButtonSize * scale)
                .panelSurface(Circle())
                .padding(4 * scale) // a slightly larger target than the circle you see
                .contentShape(.circle)
                .padding(-4 * scale)
        }
        .buttonStyle(.plain)
        .background(MenuAnchorView(anchor: anchor))
        .help("More")
        .accessibilityLabel("More")
        .revealed(isVisible)
        .testTarget("panel.menu")
    }
}

/// Where a pop-up menu opens: the AppKit view behind a SwiftUI control.
@MainActor
final class MenuAnchor {
    fileprivate weak var view: NSView?

    /// Opens `menu` with its top-left corner just below the anchor's bottom-left.
    func popUp(_ menu: NSMenu, with presenter: MenuPresenter) {
        guard let view else { return }
        presenter.present(menu, NSPoint(x: 0, y: view.isFlipped ? view.bounds.maxY + 6 : -6), view)
    }
}

private struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = PassThroughView()
        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        anchor.view = view
    }

    /// Only marks a position; clicks go to the SwiftUI button on top.
    private final class PassThroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

enum PanelSizePreset: String, CaseIterable, Identifiable {
    case mini, compact, standard, large, wide
    var id: String { rawValue }

    var title: String {
        self == .mini ? "Mini Bar" : rawValue.capitalized
    }

    var size: CGSize {
        switch self {
        case .mini: CGSize(width: 300, height: 72)
        case .compact: CGSize(width: 240, height: 290)
        case .standard: TimerPanelView.defaultSize
        case .large: CGSize(width: 460, height: 580)
        case .wide: CGSize(width: 560, height: 280)
        }
    }
}
