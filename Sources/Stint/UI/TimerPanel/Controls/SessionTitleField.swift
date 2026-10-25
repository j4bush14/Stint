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
                TextField("Session name", text: $draft,
                          prompt: Text("Name this session").foregroundStyle(.white.opacity(Self.placeholderOpacity)))
                    .testTarget("panel.titleField")
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .tint(.white) // the text cursor
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .frame(width: width)
                    // A fixed dark capsule rather than glass, which lightens over bright
                    // wallpapers: white text stays readable on every theme and backdrop.
                    .background(Capsule().fill(.black.opacity(Self.fieldDarkness)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                    .focused($focused)
                    .onSubmit(commit)
                    .onExitCommand { isEditing = false }
                    .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
                    .onAppear {
                        draft = timer.title
                        actions.focusPanel()
                        focused = true
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Button { isEditing = true } label: {
                    Text(timer.title.isEmpty ? "Add a title" : timer.title)
                        .opacity(timer.title.isEmpty ? Self.placeholderOpacity : 0.92)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 0.5) // lifts it off light colors
                        .lineLimit(1)
                        .frame(maxWidth: width)
                }
                .buttonStyle(HoverHighlightStyle())
                .help("Name this session")
                .testTarget("panel.title", value: timer.title)
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.2), value: isEditing)
        .font(.system(size: fontSize, weight: .medium))
    }

    /// How dark the editing capsule is, and how strong placeholder text is: enough for
    /// white text to read over the lightest colors the panel can take (see the tests).
    nonisolated static let fieldDarkness = 0.55
    nonisolated static let placeholderOpacity = 0.7

    private func commit() {
        guard isEditing else { return }
        timer.title = draft.trimmingCharacters(in: .whitespaces)
        isEditing = false
    }
}
