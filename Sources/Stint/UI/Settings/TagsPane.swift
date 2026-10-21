import SwiftUI

/// Tag list with drag-to-reorder (macOS 27 `reorderable`).
struct TagsPane: View {
    @EnvironmentObject private var store: SessionStore
    @State private var pendingDelete: Tag?

    var body: some View {
        Form {
            Section {
                ForEach(store.tags) { tag in
                    TagRow(tag: store.binding(for: tag.id)) { pendingDelete = tag }
                }
                .reorderable()
                Button("New Tag", systemImage: "plus") {
                    store.tags.append(Tag(title: "New Tag", color: TagColor.allCases.randomElement()!, order: store.tags.count))
                }
                .testTarget("tags.new")
            } header: {
                Text("Tags")
            } footer: {
                footnote("Drag to reorder. Give a tag its own timer to use different lengths whenever it's selected.")
            }
        }
        .formStyle(.grouped)
        .reorderContainer(for: Tag.self) { difference in
            let target: UUID? = switch difference.destination.position {
            case .before(let id): id
            case .end: nil
            }
            withAnimation(.smooth) { store.moveTags(difference.sources, before: target) }
        }
        .alert("Delete “\(pendingDelete?.title ?? "")”?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) { if let t = pendingDelete { store.deleteTag(t) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            let count = pendingDelete.map(store.sessionCount(for:)) ?? 0
            Text(count == 0 ? "No sessions use this tag." : "\(count) past session\(count == 1 ? "" : "s") will become untagged.")
        }
    }
}

/// One tag: color, editable name and an optional custom timer, revealed by expanding.
struct TagRow: View {
    @Binding var tag: Tag
    var onDelete: () -> Void
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            SettingToggle("Use its own timer", isOn: $tag.isPresetEnabled, id: "tag.\(tag.order).preset")
            if tag.isPresetEnabled {
                StepperRow(title: "Focus", value: $tag.preset.focusMinutes, range: 1...180, unit: "min")
                StepperRow(title: "Short break", value: $tag.preset.shortBreakMinutes, range: 1...60, unit: "min")
                StepperRow(title: "Long break", value: $tag.preset.longBreakMinutes, range: 1...120, unit: "min")
                StepperRow(title: "Focus sessions per cycle", value: $tag.preset.cycle, range: 1...12)
                SettingToggle("Start breaks automatically", isOn: $tag.preset.startBreakAutomatically, id: "tag.\(tag.order).startBreakAutomatically")
                SettingToggle("Start focus sessions automatically", isOn: $tag.preset.startFocusAutomatically, id: "tag.\(tag.order).startFocusAutomatically")
            }
        } label: {
            HStack(spacing: 10) {
                colorMenu
                TextField("Tag name", text: $tag.title, prompt: Text("Tag name"))
                    .labelsHidden()
                    .testTarget("tag.name.\(tag.order)", value: tag.title)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if tag.isPresetEnabled {
                    Label("Custom timer", systemImage: "timer")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                        .help("This tag has its own timer")
                }
                Button("Delete Tag", systemImage: "trash", role: .destructive, action: onDelete)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Delete tag")
                    .testTarget("tag.delete.\(tag.order)")
            }
        }
    }

    private var colorMenu: some View {
        Menu {
            Picker("Color", selection: $tag.color) {
                ForEach(TagColor.allCases) { color in
                    Label(color.rawValue.capitalized, systemImage: "circle.fill")
                        .tint(color.color)
                        .tag(color)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Circle()
                .fill(tag.color.color)
                .frame(width: 14, height: 14)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Tag color")
        .testTarget("tag.color.\(tag.order)", value: tag.color.rawValue)
    }
}

private extension SessionStore {
    /// A binding to one tag by ID, so tag rows can edit in place while the list reorders.
    func binding(for id: UUID) -> Binding<Tag> {
        Binding(
            get: { self.tags.first { $0.id == id } ?? Tag(title: "", color: .slate, order: 0) },
            set: { newValue in
                if let i = self.tags.firstIndex(where: { $0.id == id }) { self.tags[i] = newValue }
            }
        )
    }
}
