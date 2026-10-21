import SwiftUI

extension View {
    /// Dims this control and lets clicks fall through to the "click outside to set" area
    /// while the time picker is open, so nothing else (like Play) can happen until editing ends.
    func inactiveWhileEditingTime() -> some View {
        modifier(InactiveWhileEditingTime())
    }
}

private struct InactiveWhileEditingTime: ViewModifier {
    @EnvironmentObject private var timer: FocusTimer

    func body(content: Content) -> some View {
        content
            .opacity(timer.isEditingTime ? 0.35 : 1)
            .allowsHitTesting(!timer.isEditingTime)
            .animation(.smooth(duration: 0.2), value: timer.isEditingTime)
    }
}
