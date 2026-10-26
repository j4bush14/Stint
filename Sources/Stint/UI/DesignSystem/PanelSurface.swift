import SwiftUI

/// The Ink panel style's look, matching the website: flat color, ink outlines and hard
/// offset shadows, like cut-out clip art.
enum Ink {
    static let line = Color(red: 0x1D / 255, green: 0x1B / 255, blue: 0x19 / 255)
    static let paper = Color(red: 0xFB / 255, green: 0xF5 / 255, blue: 0xE9 / 255)
    /// A darker patch of the panel's own color, behind outlined buttons and chips.
    static let fill = Color.black.opacity(0.16)
    static let lineWidth: CGFloat = 2.5
    /// Outlined capsules use circular ends: a stroked continuous capsule draws bumps at its ends.
    static let capsule = Capsule(style: .circular)
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

extension View {
    /// A card in the panel's style: Liquid Glass tinted by `wash`, or in the Ink style the
    /// wash as flat color with an ink outline and a hard shadow.
    @ViewBuilder
    func panelCard(_ wash: some ShapeStyle, cornerRadius: CGFloat, ink: Bool,
                   glass: Glass = .regular, shadow: CGFloat = 5) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if ink {
            background(wash, in: shape)
                .overlay(shape.strokeBorder(Ink.line, lineWidth: 3))
                .background(shape.fill(Ink.line).offset(x: shadow, y: shadow))
        } else {
            background(wash, in: shape)
                .glassEffect(glass, in: shape)
        }
    }
}

/// A chunky outlined capsule button for the Ink style. The prominent one is paper on a hard
/// shadow that it presses down onto; the others are see-through, so they have no shadow.
struct InkCapsuleButtonStyle: ButtonStyle {
    var prominent = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shadow: CGFloat = prominent ? 4 : 0
        let offset = configuration.isPressed ? shadow : 0
        return configuration.label
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Ink.capsule.fill(prominent ? Ink.paper : Ink.fill))
            .overlay(Ink.capsule.strokeBorder(Ink.line, lineWidth: 3))
            .offset(x: offset, y: offset)
            .background {
                if prominent { Ink.capsule.fill(Ink.line).offset(x: shadow, y: shadow) }
            }
            .contentShape(Capsule())
            .scaleEffect(prominent || !configuration.isPressed ? 1 : 0.96)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}
