import SwiftUI

/// The panel's window buttons: Hide at the top-left corner, where every Mac window keeps
/// its close button, and the ⋯ menu at the top-right. They sit in the panel's corners in
/// every layout (the mini bar puts them at either end of its row) and appear while the
/// pointer is over the panel, or always if that's turned on in Settings.
struct PanelCornerButtons: View {
    let scale: CGFloat
    let isVisible: Bool
    let menu: PanelMenu

    var body: some View {
        HStack(spacing: 0) {
            PanelHideButton(scale: scale, isVisible: isVisible)
            Spacer(minLength: 0) // no content, so clicks between the buttons reach the panel
            PanelMenuButton(menu: menu, scale: scale, isVisible: isVisible)
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
                .glassEffect(.regular.interactive(), in: .circle) // matches ⋯ beside it
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hide")
        .help("Hide (Esc)")
            .revealed(isVisible)
            .testTarget("panel.hide", value: isVisible ? "visible" : "hidden")
    }
}

/// The phase and the position in the cycle, e.g. "Focus · 2 of 4".
struct PhaseLabel: View {
    let scale: CGFloat

    @EnvironmentObject private var timer: FocusTimer

    var body: some View {
        HStack(spacing: 5 * scale) {
            if timer.isLocked {
                Image(systemName: "lock.fill")
                    .help("Lock-In is on")
            }
            Text(timer.phase.title)
            if timer.phase == .focus {
                Text("· \(min(timer.completedFocus + 1, timer.cycle)) of \(timer.cycle)")
                    .monospacedDigit()
                    .opacity(0.65)
            }
        }
        .font(.system(size: 12 * scale, weight: .semibold))
        .lineLimit(1)
        .testTarget("panel.phase", value: "\(timer.phase.rawValue) \(min(timer.completedFocus + 1, timer.cycle))/\(timer.cycle)")
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

/// The session's tag, shown under the controls; click to change it.
struct TagPicker: View {
    @Environment(\.appActions) private var actions
    let scale: CGFloat

    @EnvironmentObject private var timer: FocusTimer
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        let tag = store.tag(for: timer.selectedTagID)
        Menu {
            Picker("Tag", selection: $timer.selectedTagID) {
                Text("No Tag").tag(UUID?.none)
                ForEach(store.tags.sorted { $0.order < $1.order }) { tag in
                    Text(tag.title).tag(Optional(tag.id))
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Edit Tags…") { actions.showSettings(.tags) }
        } label: {
            HStack(spacing: 5 * scale) {
                Circle()
                    .fill(tag?.color.color ?? .white.opacity(0.5))
                    .frame(width: 7 * scale, height: 7 * scale)
                Text(tag?.title ?? "No Tag")
                    .font(.system(size: 11 * scale, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10 * scale)
            .padding(.vertical, 5 * scale)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(timer.isLocked)
        .help("Tag this session")
        .testTarget("panel.tag", value: tag?.title ?? "No Tag")
    }
}

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
