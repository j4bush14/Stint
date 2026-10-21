import SwiftUI

// Shapes the clock faces are built from.

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
