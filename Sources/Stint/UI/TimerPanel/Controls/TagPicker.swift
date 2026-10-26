import SwiftUI

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
            .panelSurface(Ink.capsule)
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
