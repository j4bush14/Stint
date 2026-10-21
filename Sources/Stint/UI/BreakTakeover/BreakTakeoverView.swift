import SwiftUI

/// Optional full-screen break screen shown when "Take over the screen during breaks" is on.
struct BreakTakeoverView: View {
    @Environment(\.appActions) private var actions
    @EnvironmentObject private var theme: ThemeModel
    @EnvironmentObject private var timer: FocusTimer

    var body: some View {
        ZStack {
            VisualEffectView(material: .fullScreenUI)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Text(timer.phase.title)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(TimeFormat.clock(timer.remaining))
                    .font(.system(size: 120, weight: .light, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.smooth, value: Int(timer.remaining.rounded(.up)))
                Text("Look away from the screen, roll your shoulders, refill your water.")
                    .font(.title3)
                    .opacity(0.85)
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(timer.isRunning ? "Pause" : "Resume", systemImage: timer.isRunning ? "pause.fill" : "play.fill") {
                            timer.toggle()
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.white.opacity(0.92))
                        .foregroundStyle(theme.color(for: timer.phase))
                        Button("End Break", systemImage: "forward.end.fill") {
                            timer.skip()
                            actions.closeBreakTakeover()
                        }
                        .buttonStyle(.glass)
                        Button("Hide", systemImage: "xmark") { actions.closeBreakTakeover() }
                            .buttonStyle(.glass)
                    }
                    .controlSize(.extraLarge)
                }
                .padding(.top, 18)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 70)
            .padding(.vertical, 50)
            .background(theme.panelWash(for: timer.phase), in: .rect(cornerRadius: 44))
            .glassEffect(.regular, in: .rect(cornerRadius: 44))
        }
    }
}

/// Bridges `NSVisualEffectView` for a behind-window blur.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
