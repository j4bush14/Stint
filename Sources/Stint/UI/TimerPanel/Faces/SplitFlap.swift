import SwiftUI

/// A row of split-flap digits, e.g. "25".
struct SplitFlapGroup: View {
    let text: String
    let digitSize: CGSize
    let tile: NSColor

    var body: some View {
        HStack(spacing: digitSize.width * 0.08) {
            // Index from the right so the ones digit keeps its identity when "9" becomes "10".
            ForEach(Array(text.reversed().enumerated()).reversed(), id: \.offset) { _, character in
                SplitFlapDigit(character: character, size: digitSize, tile: tile)
            }
        }
    }
}

/// One mechanical split-flap digit. When the digit changes, a single flap turns over the
/// center hinge: its front carries the old digit's top half, its back the new digit's
/// bottom half. Technique after the split-flap breakdown in Craft of UI's "Time Travel
/// with JavaScript" (four half-cards, one moving flap, brightness for depth).
struct SplitFlapDigit: View {
    let character: Character
    let size: CGSize
    /// The tile's (opaque) color; a flap has to hide the digit behind it.
    let tile: NSColor

    /// The digit being flipped away from, while a flip is in progress.
    @State private var previous: Character?
    /// How far the flap has turned: 0 = just released, 180 = landed.
    @State private var angle: Double = 180

    @Environment(\.panelInk) private var ink

    var body: some View {
        FlapStack(old: previous ?? character, new: character, angle: angle, size: size, tile: tile)
            .background {
                // Ink: the tile sits on ink, so the hinge reads as a dark line, over a hard shadow.
                if ink {
                    let tile = RoundedRectangle(cornerRadius: size.width * 0.14, style: .continuous)
                    tile.fill(Ink.line)
                        .offset(x: size.width * 0.06, y: size.width * 0.06)
                    tile.fill(Ink.line)
                }
            }
            .onChange(of: character) { oldValue, _ in flip(from: oldValue) }
    }

    private func flip(from oldValue: Character) {
        previous = oldValue
        angle = 0
        // A little bounce as the flap lands, like the real mechanism settling.
        withAnimation(.spring(duration: 0.42, bounce: 0.18)) {
            angle = 180
        } completion: {
            previous = nil
        }
    }
}

/// The four half-cards of a split-flap digit at a given flap angle. `Animatable`, so
/// SwiftUI redraws it every frame with the in-between angle (which side of the flap
/// faces the viewer changes mid-turn).
private struct FlapStack: View, Animatable {
    let old: Character
    let new: Character
    nonisolated var angle: Double
    let size: CGSize
    let tile: NSColor
    @Environment(\.panelInk) private var ink

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let turning = angle < 180
        ZStack {
            // The new digit's top, revealed as the flap falls away: starts in shadow.
            half(new, top: true, shade: max(0, 1 - angle / 90))
            // The old digit's bottom, until the flap lands on it: darkens under its shadow.
            half(turning ? old : new, top: false, shade: turning ? max(0, (angle - 90) / 90) : 0)

            // The flap. Front (old top) until it passes vertical, then back (new bottom).
            if turning && angle < 90 {
                half(old, top: true, shade: sin(angle * .pi / 180) * 0.6)
                    .rotation3DEffect(.degrees(-angle), axis: (1, 0, 0), anchor: .center, perspective: 0.5)
            } else if turning || angle > 180 {
                half(new, top: false, shade: abs(sin(angle * .pi / 180)) * 0.6)
                    .rotation3DEffect(.degrees(180 - angle), axis: (1, 0, 0), anchor: .center, perspective: 0.5)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// The top or bottom half-card showing `digit`. `shade` (0…1) darkens it.
    private func half(_ digit: Character, top: Bool, shade: Double) -> some View {
        let radius = size.width * 0.14
        let gap = max(1, size.height * 0.025)
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: top ? radius : 2, bottomLeadingRadius: top ? 2 : radius,
            bottomTrailingRadius: top ? 2 : radius, topTrailingRadius: top ? radius : 2,
            style: .continuous
        )
        // Lit from above: the bottom half-card is a touch darker.
        let fill = top ? tile : (tile.shadow(withLevel: 0.1) ?? tile)
        return Text(String(digit))
            .font(.system(size: size.height * (ink ? 0.68 : 0.78), weight: ink ? .heavy : .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(ink ? Ink.line : .white)
            .frame(width: size.width, height: size.height)
            // Keep this half; the full-height frame keeps the digit centered on the hinge.
            .frame(width: size.width, height: (size.height - gap) / 2, alignment: top ? .top : .bottom)
            .clipped()
            .background(shape.fill(Color(nsColor: fill)))
            .overlay(shape.fill(.black.opacity(0.55 * min(1, shade))))
            .overlay { if ink { shape.strokeBorder(Ink.line, lineWidth: max(1.5, size.width * 0.05)) } }
            .frame(width: size.width, height: size.height, alignment: top ? .top : .bottom)
    }
}
