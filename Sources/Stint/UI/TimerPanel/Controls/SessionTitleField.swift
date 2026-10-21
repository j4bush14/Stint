import SwiftUI

/// The session name: a label that turns into a text field when clicked.
struct SessionTitleField: View {
    @Environment(\.appActions) private var actions
    @Binding var isEditing: Bool
    let width: CGFloat
    let fontSize: CGFloat

    @EnvironmentObject private var timer: FocusTimer
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField("What are you working on?", text: $draft)
                    .testTarget("panel.titleField")
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .frame(width: width)
                    .glassEffect(.regular, in: .capsule)
                    .focused($focused)
                    .onSubmit(commit)
                    .onExitCommand { isEditing = false }
                    .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
                    .onAppear {
                        draft = timer.title
                        actions.focusPanel()
                        focused = true
                    }
            } else {
                Button { isEditing = true } label: {
                    Text(timer.title.isEmpty ? "Add a title" : timer.title)
                        .opacity(timer.title.isEmpty ? 0.55 : 0.9)
                        .lineLimit(1)
                        .frame(maxWidth: width)
                }
                .buttonStyle(HoverHighlightStyle())
                .help("Name this session")
                .testTarget("panel.title", value: timer.title)
            }
        }
        .font(.system(size: fontSize, weight: .medium))
    }

    private func commit() {
        guard isEditing else { return }
        timer.title = draft.trimmingCharacters(in: .whitespaces)
        isEditing = false
    }
}
