import SwiftUI

// Shapes the clock faces are built from.

/// Shows `value` moving the way a clock should: a steady linear glide for each second's
/// small step forward, and a quick ease for jumps (a reset, a skip, a new phase, a typed-in
/// time) instead of crawling there over a second.
struct Gliding<Content: View>: View {
    let value: Double
    @ViewBuilder let content: (Double) -> Content
    @State private var shown: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content(shown ?? value)
            .onChange(of: value) { old, new in
                withAnimation(reduceMotion ? nil : Self.motion(from: old, to: new)) { shown = new }
            }
    }

    /// The animation for a move from `old` to `new` (both 0…1).
    nonisolated static func motion(from old: Double, to new: Double) -> Animation {
        let step = new - old
        return step > 0 && step < 0.05 ? .linear(duration: 1) : .smooth(duration: 0.55)
    }
}

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
            Gliding(value: progress) { shown in
                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: shown)
                    .stroke(.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
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
                Gliding(value: progress) { shown in
                    Capsule()
                        .fill(.white)
                        .frame(width: max(geo.size.height, geo.size.width * shown))
                }
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
            // Gliding works on progress (rising), so the wedge's shrink reads as a step forward.
            Gliding(value: 1 - remaining) { elapsed in
                Wedge(fraction: 1 - elapsed)
                    .fill(.white.opacity(0.6))
                    .scaleEffect(0.78) // leaves a band for the tick marks
            }
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
