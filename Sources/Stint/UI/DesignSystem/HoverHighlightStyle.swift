import SwiftUI

/// A soft rounded highlight on hover and press, for text that can be clicked.
struct HoverHighlightStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.16 : (isHovering ? 0.09 : 0)))
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
