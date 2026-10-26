import SwiftUI

/// Circular Liquid Glass button for the timer panel.
///
/// The system `.glass` / `.glassProminent` styles switch to an inactive look whenever their
/// window isn't key. That's right for document windows, but a floating panel would visibly
/// flash every time a click moved focus to or from it. This style is built on the
/// `glassEffect` modifier, which renders the same regardless of key state.
///
/// In the Ink style the buttons are outlined instead, and the primary one is a paper disc on
/// a hard shadow that presses down onto it.
struct PanelGlassButtonStyle: ButtonStyle {
    /// A solid white button for the primary action.
    var prominent = false

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.panelInk) private var ink

    func makeBody(configuration: Configuration) -> some View {
        if ink { inkBody(configuration) } else { glassBody(configuration) }
    }

    private func inkBody(_ configuration: Configuration) -> some View {
        let shadow: CGFloat = prominent ? 3 : 0
        let offset = configuration.isPressed ? shadow : 0
        return configuration.label
            .background(Circle().fill(prominent ? Ink.paper : Ink.fill))
            .overlay(Circle().strokeBorder(Ink.line, lineWidth: Ink.lineWidth))
            .offset(x: offset, y: offset)
            .background {
                if prominent { Circle().fill(Ink.line).offset(x: shadow, y: shadow) }
            }
            .contentShape(Circle())
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }

    private func glassBody(_ configuration: Configuration) -> some View {
        configuration.label
            .background {
                if prominent { Circle().fill(.white) }
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PanelGlassButtonStyle {
    static var panelGlass: PanelGlassButtonStyle { PanelGlassButtonStyle() }
    static var panelGlassProminent: PanelGlassButtonStyle { PanelGlassButtonStyle(prominent: true) }
}
