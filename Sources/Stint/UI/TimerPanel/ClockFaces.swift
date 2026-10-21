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
                .frame(width: size * 0.78, height: max(4, size * 0.022))
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

    /// Flip tiles are opaque (a flap has to hide the digit behind it), tinted to the theme.
    private var tileColor: NSColor {
        let base = theme.nsColor(for: timer.phase)
        return base.blended(withFraction: 0.18, of: .white) ?? base
    }

    private var flip: some View {
        let parts = Fmt.clockParts(timer.remaining)
        let digitSize = CGSize(width: size * 0.17, height: size * 0.25)
        return VStack(spacing: size * 0.06) {
            TimeButton {
                HStack(spacing: size * 0.02) {
                    SplitFlapGroup(text: parts.leading, digitSize: digitSize, tile: tileColor)
                    Text(":")
                        .font(.system(size: size * 0.14, weight: .semibold, design: .rounded))
                        .opacity(0.6)
                    SplitFlapGroup(text: parts.trailing, digitSize: digitSize, tile: tileColor)
                }
                .padding(.vertical, 4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Fmt.clock(timer.remaining)) remaining")
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

// MARK: - Building blocks

/// A circular progress track. The stroke is inset by half its width so it never
/// draws outside the view's frame, whatever size the ring is.
struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .inset(by: lineWidth / 2)
                .stroke(.white.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress) // glide between once-a-second updates
        }
    }
}

/// A thin horizontal progress bar.
struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(.white)
                    .frame(width: max(geo.size.height, geo.size.width * progress))
                    .animation(.linear(duration: 1), value: progress) // glide between once-a-second updates
            }
        }
    }
}

/// A kitchen-timer dial: a wedge showing the time left that shrinks toward 12 o'clock.
struct Dial: View {
    /// Fraction of the phase still to go, 0…1.
    let remaining: Double

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.1))
            Wedge(fraction: remaining)
                .fill(.white.opacity(0.6))
                .scaleEffect(0.78) // leaves a band for the tick marks
                .animation(.linear(duration: 1), value: remaining)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2
                for tick in 0..<60 {
                    let isHour = tick % 5 == 0
                    let angle = Double(tick) / 60 * 2 * .pi - .pi / 2
                    let outer = radius - 2
                    let inner = outer - (isHour ? radius * 0.1 : radius * 0.05)
                    var path = Path()
                    path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                    path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                    context.stroke(path, with: .color(.white.opacity(isHour ? 0.7 : 0.3)),
                                   lineWidth: isHour ? 2 : 1)
                }
            }
            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
        }
        .accessibilityHidden(true)
    }
}

/// A pie slice from 12 o'clock, clockwise, covering `fraction` of the circle.
struct Wedge: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        guard fraction > 0 else { return path }
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * min(1, fraction)), clockwise: false)
        path.closeSubpath()
        return path
    }
}


/// Small pips, one per focus session in the cycle.
struct CyclePips: View {
    @ObservedObject var timer: FocusTimer

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<timer.cycle, id: \.self) { index in
                let done = index < timer.completedFocus
                let current = timer.phase == .focus && index == timer.completedFocus
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(done ? 1 : (current ? 0.6 : 0.25)))
                    .frame(width: current ? 14 : 6, height: 4)
            }
        }
        .animation(.smooth, value: timer.completedFocus)
        .animation(.smooth, value: timer.phase)
        .accessibilityElement()
        .accessibilityLabel("\(timer.completedFocus) of \(timer.cycle) focus sessions done")
    }
}
