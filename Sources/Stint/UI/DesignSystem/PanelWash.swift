import SwiftUI

/// The panel's color wash. Built from two solid colors (the bottom one, with the top one
/// fading down over it) so a change of color, like a new wallpaper sample or the switch to a
/// break, fades smoothly instead of jumping.
struct PanelWash: View {
    @EnvironmentObject private var theme: ThemeModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let phase: Phase

    var body: some View {
        let colors = theme.washColors(for: phase)
        ZStack {
            Rectangle().fill(colors.bottom)
            Rectangle().fill(colors.top)
                .mask(LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .top, endPoint: .bottom))
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.6), value: colors.top)
        .animation(reduceMotion ? nil : .smooth(duration: 0.6), value: colors.bottom)
        .allowsHitTesting(false)
    }
}
