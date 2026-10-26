import SwiftUI

/// Play/pause, flanked by reset and skip. The buttons share a `GlassEffectContainer`, so
/// reset and skip morph out of the play button when they appear. The Ink style has no glass
/// to morph, so it lays them out on their own.
struct TransportControls: View {
    @EnvironmentObject private var theme: ThemeModel
    let scale: CGFloat
    /// Show only the play/pause button (used by the mini bar when space is tight).
    var playOnly = false

    @EnvironmentObject private var timer: FocusTimer
    @EnvironmentObject private var wallpaper: WallpaperColors // play icon uses its accent
    @Namespace private var glassSpace
    @Environment(\.panelInk) private var ink

    var body: some View {
        if ink {
            buttons
        } else {
            GlassEffectContainer(spacing: 18 * scale) { buttons }
        }
    }

    private var buttons: some View {
        HStack(spacing: 14 * scale) {
            if timer.canReset && !playOnly {
                secondary("arrow.counterclockwise", help: "Reset to \(TimeFormat.clock(timer.duration(of: timer.phase)))",
                          label: "Reset") { timer.stop() }
                    .glassEffectID("reset", in: glassSpace)
                    .testTarget("transport.reset")
            }
            playPause
            if timer.hasStarted && !playOnly {
                secondary("forward.end.fill", help: timer.phase == .focus ? "Skip to break" : "Skip break",
                          label: "Skip") { timer.skip() }
                    .glassEffectID("skip", in: glassSpace)
                    .testTarget("transport.skip")
            }
        }
    }

    private var playPause: some View {
        Button { timer.toggle() } label: {
            Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 20 * scale, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(theme.color(for: timer.phase))
                .frame(width: 48 * scale, height: 48 * scale)
        }
        .buttonStyle(.panelGlassProminent)
        .keyboardShortcut(.space, modifiers: [])
        .disabled(timer.isLocked)
        .glassEffectID("play", in: glassSpace)
        .help(timer.isLocked ? "Lock-In is on" : (timer.isRunning ? "Pause" : "Start"))
        .accessibilityLabel(timer.isRunning ? "Pause" : "Start")
        .testTarget("transport.playPause", value: timer.isRunning ? "pause" : "play")
    }

    private func secondary(_ symbol: String, help: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13 * scale, weight: .semibold))
                .frame(width: 32 * scale, height: 32 * scale)
        }
        .buttonStyle(.panelGlass)
        .disabled(timer.isLocked)
        .help(help)
        .accessibilityLabel(label)
        .accessibilityHint(help)
    }
}
