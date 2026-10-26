import SwiftUI

// The Ink style's versions of the clock parts: paper and ink, drawn like the app icon.

/// The app icon's ring: a paper arc outlined in ink over a faint track, with a mustard dot
/// where the time has got to.
struct InkRing: View {
    let progress: Double
    let lineWidth: CGFloat

    var body: some View {
        let outline = lineWidth * 1.7
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2 - outline / 2
            ZStack {
                Circle()
                    .inset(by: outline / 2)
                    .stroke(Ink.line.opacity(0.22), lineWidth: outline)
                Gliding(value: progress) { shown in
                    ZStack {
                        let arc = Circle().inset(by: outline / 2).trim(from: 0, to: shown)
                        arc.stroke(Ink.line, style: StrokeStyle(lineWidth: outline, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        arc.stroke(Ink.paper, style: StrokeStyle(lineWidth: outline * 0.46, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        // The dot turns with the ring, so a jump sweeps round it rather than across.
                        Circle()
                            .fill(Ink.mustard)
                            .overlay(Circle().strokeBorder(Ink.line, lineWidth: max(1.5, outline * 0.16)))
                            .frame(width: outline * 0.82, height: outline * 0.82)
                            .offset(y: -radius)
                            .rotationEffect(.degrees(360 * shown))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// A chunky bar: paper outlined in ink, filling a faint track.
struct InkProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Ink.capsule.fill(Ink.line.opacity(0.22))
                Gliding(value: progress) { shown in
                    Ink.capsule
                        .fill(Ink.paper)
                        .overlay(Ink.capsule.strokeBorder(Ink.line, lineWidth: max(1.5, geo.size.height * 0.2)))
                        .frame(width: max(geo.size.height, geo.size.width * shown))
                }
            }
        }
    }
}

/// A kitchen timer drawn in ink: a paper face, ink ticks, and a tomato wedge for the time
/// left that shrinks toward 12 o'clock.
struct InkDial: View {
    /// Fraction of the phase still to go, 0…1.
    let remaining: Double

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let line = max(2, side * 0.022)
            ZStack {
                Circle().fill(Ink.paper)
                Gliding(value: 1 - remaining) { elapsed in
                    ZStack {
                        Wedge(fraction: 1 - elapsed).fill(Ink.tomato)
                        Wedge(fraction: 1 - elapsed).stroke(Ink.line, style: StrokeStyle(lineWidth: line, lineJoin: .round))
                    }
                    .padding(side * 0.13) // leaves a band for the tick marks
                }
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2
                    for tick in 0..<60 {
                        let isHour = tick % 5 == 0
                        let angle = Double(tick) / 60 * 2 * .pi - .pi / 2
                        let outer = radius - line * 1.6
                        let inner = outer - (isHour ? radius * 0.1 : radius * 0.05)
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                        path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                        context.stroke(path, with: .color(Ink.line.opacity(isHour ? 1 : 0.45)),
                                       style: StrokeStyle(lineWidth: isHour ? line : line * 0.5, lineCap: .round))
                    }
                }
                Circle().strokeBorder(Ink.line, lineWidth: line * 1.3)
                Circle()
                    .fill(Ink.mustard)
                    .overlay(Circle().strokeBorder(Ink.line, lineWidth: line))
                    .frame(width: side * 0.09, height: side * 0.09)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }
}
