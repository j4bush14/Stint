import SwiftUI

/// The Ink panel style's look, matching the website: flat color, ink outlines and hard
/// offset shadows, like cut-out clip art.
enum Ink {
    static let line = Color(red: 0x1D / 255, green: 0x1B / 255, blue: 0x19 / 255)
    static let paper = Color(red: 0xFB / 255, green: 0xF5 / 255, blue: 0xE9 / 255)
    /// A darker patch of the panel's own color, behind outlined buttons and chips.
    static let fill = Color.black.opacity(0.16)
    static let lineWidth: CGFloat = 2.5
}

extension EnvironmentValues {
    /// True when the timer panel uses the Ink style instead of Liquid Glass.
    @Entry var panelInk = false
}

extension View {
    /// Liquid Glass behind a panel control, or an outlined flat shape in the Ink style.
    func panelSurface<S: InsettableShape>(_ shape: S) -> some View {
        modifier(PanelSurface(shape: shape))
    }
}

private struct PanelSurface<S: InsettableShape>: ViewModifier {
    @Environment(\.panelInk) private var ink
    let shape: S

    func body(content: Content) -> some View {
        if ink {
            content
                .background(shape.fill(Ink.fill))
                .overlay(shape.strokeBorder(Ink.line, lineWidth: Ink.lineWidth))
        } else {
            content.glassEffect(.regular.interactive(), in: shape)
        }
    }
}
