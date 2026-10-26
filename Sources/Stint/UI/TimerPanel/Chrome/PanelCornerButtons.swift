import AppKit
import SwiftUI

/// The panel's window buttons: Hide at the top-left corner, where every Mac window keeps
/// its close button, and the ⋯ menu at the top-right. They sit in the panel's corners in
/// every layout (the mini bar puts them at either end of its row) and appear while the
/// pointer is over the panel, or always if that's turned on in Settings.
struct PanelCornerButtons: View {
    let scale: CGFloat
    let isVisible: Bool
    let makeMenu: () -> NSMenu

    var body: some View {
        HStack(spacing: 0) {
            PanelHideButton(scale: scale, isVisible: isVisible)
            Spacer(minLength: 0) // no content, so clicks between the buttons reach the panel
            PanelMenuButton(scale: scale, isVisible: isVisible, makeMenu: makeMenu)
        }
    }
}

/// Size of a window button at scale 1.
let panelButtonSize: CGFloat = 22

struct PanelHideButton: View {
    @Environment(\.appActions) private var actions
    let scale: CGFloat
    let isVisible: Bool

    var body: some View {
        Button { actions.hidePanel() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10 * scale, weight: .bold))
                .frame(width: panelButtonSize * scale, height: panelButtonSize * scale)
                .panelSurface(Circle()) // matches ⋯ beside it
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hide")
        .help("Hide (Esc)")
            .revealed(isVisible)
            .testTarget("panel.hide", value: isVisible ? "visible" : "hidden")
    }
}

extension View {
    /// Shows a window button, or hides it without taking clicks meant for the panel.
    func revealed(_ isVisible: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .animation(.easeOut(duration: 0.2), value: isVisible)
    }
}
