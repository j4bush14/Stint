import SwiftUI

/// Circular Liquid Glass button for the timer panel.
///
/// The system `.glass` / `.glassProminent` styles switch to an inactive look whenever their
/// window isn't key. That's right for document windows, but a floating panel would visibly
/// flash every time a click moved focus to or from it. This style is built on the
/// `glassEffect` modifier, which renders the same regardless of key state.
struct PanelGlassButtonStyle: ButtonStyle {
    /// A solid white button for the primary action.
    var prominent = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
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
