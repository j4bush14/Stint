import SwiftUI

/// Items shared by the ⋯ button and the right-click menu.
struct PanelMenu: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appActions) private var actions
    let onRename: () -> Void

    @EnvironmentObject private var timer: FocusTimer

    var body: some View {
        Button("Rename Session…", action: onRename)
        Button("Start New Cycle") { timer.resetCycle() }
            .disabled(timer.isLocked)
        Picker("Clock Style", selection: Binding(
            get: { settings.clockStyle },
            set: { style in withAnimation(.smooth) { settings.clockStyle = style } }
        )) {
            ForEach(ClockStyle.allCases) { Text($0.label).tag($0) }
        }
        Menu("Window Size") {
            ForEach(PanelSizePreset.allCases) { preset in
                Button(preset.title) { actions.resizePanel(preset.size) }
            }
        }
        Divider()
        Button("History") { actions.showHistory() }
        Button("Settings…") { actions.showSettings(nil) }
        Divider()
        Button("Hide Window") { actions.hidePanel() }
        Button("Quit Stint") { actions.quit() }
    }
}

struct PanelMenuButton: View {
    let menu: PanelMenu
    let scale: CGFloat
    let isVisible: Bool

    var body: some View {
        Menu { menu } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12 * scale, weight: .semibold))
                .frame(width: panelButtonSize * scale, height: panelButtonSize * scale)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
        .revealed(isVisible)
        .testTarget("panel.menu")
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
