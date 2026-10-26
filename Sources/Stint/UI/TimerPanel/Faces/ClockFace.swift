import AppKit
import SwiftUI

/// The timer's main display in the chosen clock style, sized to a square of `size` points.
/// While a new time is being picked, every style shows the same time picker instead.
struct ClockFace: View {
    @EnvironmentObject private var theme: ThemeModel
    let size: CGFloat
    var showsTitle = true
    @Binding var isEditingTitle: Bool

    @EnvironmentObject private var timer: FocusTimer
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if timer.isEditingTime {
                if settings.clockStyle == .ring {
                    ProgressRing(progress: timer.progress, lineWidth: ringLine).opacity(0.5)
                }
                TimePicker(fontSize: size * 0.19)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                face
                    // A gentle breath when focus turns into a break and back.
                    .keyframeAnimator(initialValue: 1.0, trigger: reduceMotion ? .focus : timer.phase) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        SpringKeyframe(1.035, duration: 0.22, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.5, spring: .smooth)
                    }
                    .testTarget("face", value: settings.clockStyle.rawValue)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .animation(.smooth(duration: 0.22), value: timer.isEditingTime)
    }

    private var ringLine: CGFloat { max(6, size * 0.042) }
    private var titleFont: CGFloat { max(11, size * 0.06) }

    @ViewBuilder
    private var face: some View {
        switch settings.clockStyle {
        case .ring: ring
        case .digital: digital
        case .dial: dial
        case .flip: flip
        }
    }

    // MARK: Styles

    private var ring: some View {
        ZStack {
            ProgressRing(progress: timer.progress, lineWidth: ringLine)
            CyclePips(timer: timer)
                .offset(y: size * 0.36)
            VStack(spacing: size * 0.02) {
                TimeButton { CountdownText(remaining: timer.remaining, size: size * 0.25) }
                title(width: size * 0.66)
            }
            .padding(.horizontal, ringLine * 2)
        }
    }

    private var digital: some View {
        VStack(spacing: size * 0.05) {
            TimeButton { CountdownText(remaining: timer.remaining, size: size * 0.3, weight: .regular) }
            ProgressBar(progress: timer.progress)
                .frame(width: size * 0.78, height: theme.isInk ? max(10, size * 0.045) : max(4, size * 0.022))
            title(width: size * 0.8)
            CyclePips(timer: timer)
        }
    }

    private var dial: some View {
        VStack(spacing: size * 0.04) {
            Dial(remaining: 1 - timer.progress)
                .frame(width: size * 0.66, height: size * 0.66)
            TimeButton { CountdownText(remaining: timer.remaining, size: size * 0.13, weight: .medium) }
            CyclePips(timer: timer)
        }
    }

    /// Flip tiles are opaque (a flap has to hide the digit behind it), tinted to the theme,
    /// or paper in the Ink style.
    private var tileColor: NSColor {
        if theme.isInk { return Ink.paperNS }
        let base = theme.nsColor(for: timer.phase)
        return base.blended(withFraction: 0.18, of: .white) ?? base
    }

    private var flip: some View {
        let parts = TimeFormat.clockParts(timer.remaining)
        let digitSize = CGSize(width: size * 0.17, height: size * 0.25)
        return VStack(spacing: size * 0.06) {
            TimeButton {
                HStack(spacing: size * 0.02) {
                    SplitFlapGroup(text: parts.leading, digitSize: digitSize, tile: tileColor)
                    Text(":")
                        .font(.system(size: size * 0.14, weight: theme.isInk ? .heavy : .semibold, design: .rounded))
                        .opacity(theme.isInk ? 1 : 0.6)
                        .shadow(color: theme.isInk ? Ink.line : .clear, radius: 0, x: size * 0.006, y: size * 0.006)
                    SplitFlapGroup(text: parts.trailing, digitSize: digitSize, tile: tileColor)
                }
                .padding(.vertical, 4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(TimeFormat.clock(timer.remaining)) remaining")
            title(width: size * 0.8)
            CyclePips(timer: timer)
        }
    }

    @ViewBuilder
    private func title(width: CGFloat) -> some View {
        if showsTitle {
            SessionTitleField(isEditing: $isEditingTitle, width: width, fontSize: titleFont)
        }
    }
}
