// Draws the Stint app icon, "Lagoon Ring", into an .iconset (and optionally one PNG):
// a teal-to-blue tile with a white progress ring, on the macOS icon grid.
//
//   swift Scripts/make-icon.swift build/AppIcon.iconset            # every size for iconutil
//   swift Scripts/make-icon.swift build/AppIcon.iconset 512 out.png # also one PNG of that size
import AppKit

/// The design, in the 1024-point space of the macOS icon grid.
enum LagoonRing {
    static let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    static let cornerRadius: CGFloat = 185
    static let center = NSPoint(x: 512, y: 512)

    static func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    static func draw(in context: CGContext) {
        let tile = NSBezierPath(roundedRect: body, xRadius: cornerRadius, yRadius: cornerRadius)

        // The tile, with a soft shadow beneath it.
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: NSColor.black.withAlphaComponent(0.32).cgColor)
        color(0x2350C2).setFill()
        tile.fill()
        context.restoreGState()
        NSGradient(starting: color(0x22A6B0), ending: color(0x2350C2))!.draw(in: tile, angle: -90)

        // Light from above, and a hairline edge.
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.2), NSColor.white.withAlphaComponent(0)],
                   atLocations: [0, 1], colorSpace: .sRGB)!.draw(in: tile, angle: -90)
        let edge = NSBezierPath(roundedRect: body.insetBy(dx: 2, dy: 2), xRadius: cornerRadius - 2, yRadius: cornerRadius - 2)
        edge.lineWidth = 4
        NSColor.white.withAlphaComponent(0.14).setStroke()
        edge.stroke()

        // The ring: a faint track and the progress so far, from 12 o'clock.
        ring(sweep: 360, color: NSColor.white.withAlphaComponent(0.25))
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: NSColor.black.withAlphaComponent(0.28).cgColor)
        ring(sweep: 290, color: .white)
        context.restoreGState()
    }

    private static func ring(sweep: CGFloat, color: NSColor) {
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: 250, startAngle: 90, endAngle: 90 - sweep, clockwise: true)
        path.lineWidth = 70
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }
}

func png(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    let context = graphics.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    LagoonRing.draw(in: context)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let arguments = CommandLine.arguments
let iconset = arguments[1]
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! png(base).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(base)x\(base).png"))
    try! png(base * 2).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(base)x\(base)@2x.png"))
}
if arguments.count == 4, let size = Int(arguments[2]) {
    try! png(size).write(to: URL(fileURLWithPath: arguments[3]))
}
