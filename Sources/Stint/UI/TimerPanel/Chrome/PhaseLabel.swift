import SwiftUI

/// The phase and the position in the cycle, e.g. "Focus · 2 of 4".
struct PhaseLabel: View {
    let scale: CGFloat

    @EnvironmentObject private var timer: FocusTimer

    var body: some View {
        HStack(spacing: 5 * scale) {
            if timer.isLocked {
                Image(systemName: "lock.fill")
                    .help("Lock-In is on")
            }
            Text(timer.phase.title)
            if timer.phase == .focus {
                Text("· \(timer.focusNumber) of \(timer.cycle)")
                    .monospacedDigit()
                    .opacity(0.65)
            }
        }
        .font(.system(size: 12 * scale, weight: .semibold))
        .lineLimit(1)
        .testTarget("panel.phase", value: "\(timer.phase.rawValue) \(timer.focusNumber)/\(timer.cycle)")
    }
}
