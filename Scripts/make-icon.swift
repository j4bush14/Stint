// Draws the Stint app icon (a blue-to-teal squircle with a progress ring) into an .iconset.
import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = s * 0.1
    let body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let squircle = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    NSGradient(colors: [NSColor(srgbRed: 0.10, green: 0.56, blue: 0.62, alpha: 1),
                        NSColor(srgbRed: 0.11, green: 0.33, blue: 0.68, alpha: 1)])!
        .draw(in: squircle, angle: -90)

    let c = NSPoint(x: s / 2, y: s / 2)
    let r = body.width * 0.29
    let width = body.width * 0.085
    let track = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    track.lineWidth = width
    NSColor(white: 1, alpha: 0.28).setStroke()
    track.stroke()

    let arc = NSBezierPath()
    arc.appendArc(withCenter: c, radius: r, startAngle: 90, endAngle: 90 - 245, clockwise: true)
    arc.lineWidth = width
    arc.lineCapStyle = .round
    NSColor.white.setStroke()
    arc.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! draw(base).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base).png"))
    try! draw(base * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base)@2x.png"))
}
