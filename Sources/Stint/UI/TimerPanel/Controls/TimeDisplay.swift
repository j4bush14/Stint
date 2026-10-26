import SwiftUI

/// The countdown digits with a rolling numeric transition, shrinking rather than wrapping.
struct CountdownText: View {
    let remaining: TimeInterval
    let size: CGFloat
    var weight: Font.Weight = .light
    @Environment(\.panelInk) private var ink

    var body: some View {
        Text(TimeFormat.clock(remaining))
            .font(.system(size: size, weight: ink ? .heavy : weight, design: .rounded).monospacedDigit())
            // Ink: chunky digits on a hard shadow, like the website's.
            .shadow(color: ink ? Ink.line : .clear, radius: 0, x: size * 0.035, y: size * 0.035)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(countsDown: true))
            .animation(.smooth(duration: 0.35), value: Int(remaining.rounded(.up)))
            .accessibilityLabel("\(TimeFormat.clock(remaining)) remaining")
    }
}

/// Wraps the time display so clicking it opens the time picker. Responds on click (no
/// waiting to see if it's a drag) and highlights on hover to show it's adjustable.
struct TimeButton<Label: View>: View {
    @Environment(\.appActions) private var actions
    @ViewBuilder var label: Label

    @EnvironmentObject private var timer: FocusTimer

    var body: some View {
        Button {
            if timer.beginEditingTime() { actions.focusPanel() }
        } label: {
            label
        }
        .buttonStyle(HoverHighlightStyle())
        .testTarget("panel.time", value: TimeFormat.clock(timer.remaining))
        .disabled(timer.isLocked)
        .help(timer.isLocked ? "Lock-In is on" : "Change the time")
        .accessibilityHint("Opens a picker to change the time")
    }
}
