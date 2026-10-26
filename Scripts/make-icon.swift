// Draws the Stint app icon into an .iconset (and optionally one PNG): Stint's ring as ink
// clip art, a flat teal tile with an ink outline and a hard shadow, matching the website.
//
//   swift Scripts/make-icon.swift build/AppIcon.iconset            # every size for iconutil
//   swift Scripts/make-icon.swift build/AppIcon.iconset 512 out.png # also one PNG of that size
import AppKit

/// The design, in the 1024-point space of the macOS icon grid (y up). The tile and its
/// shadow together fill the grid's 824-point body; the shadow drops down and to the right.
enum InkRing {
    static let tile = NSRect(x: 100, y: 124, width: 800, height: 800)
    static let shadowOffset: CGFloat = 24
    static let cornerRadius: CGFloat = 180
    static let outline: CGFloat = 46
    static let center = NSPoint(x: 500, y: 524)
    static let radius: CGFloat = 223
    static let sweep: CGFloat = 290

    static let ink = color(0x1D1B19)
    static let teal = color(0x29A3AD)
    static let paper = color(0xFBF5E9)
    static let mustard = color(0xF4BD3E)

    static func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    static func draw(in context: CGContext) {
        // The hard shadow, then the tile with its outline drawn inside its edge.
        ink.setFill()
        NSBezierPath(roundedRect: tile.offsetBy(dx: shadowOffset, dy: -shadowOffset),
                     xRadius: cornerRadius, yRadius: cornerRadius).fill()
        let inset = tile.insetBy(dx: outline / 2, dy: outline / 2)
        let body = NSBezierPath(roundedRect: inset, xRadius: cornerRadius - outline / 2, yRadius: cornerRadius - outline / 2)
        teal.setFill()
        body.fill()
        body.lineWidth = outline
        ink.setStroke()
        body.stroke()

        // A cartoon shine in the top-left corner.
        let shine = NSBezierPath()
        shine.move(to: point(6.5, 14.5))
        shine.curve(to: point(14.5, 6.5), controlPoint1: point(8, 10.5), controlPoint2: point(10.5, 8))
        shine.lineWidth = 46
        shine.lineCapStyle = .round
        paper.setStroke()
        shine.stroke()

        // The ring: a faint track, then the progress so far from 12 o'clock, outlined in ink.
        arc(sweep: 360, width: 108, color: ink.withAlphaComponent(0.22))
        arc(sweep: sweep, width: 138, color: ink)
        arc(sweep: sweep, width: 62, color: paper)

        // A dot of mustard where the ring has got to.
        let angle = (90 - sweep) * .pi / 180
        let end = NSPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        let dot = NSBezierPath(ovalIn: NSRect(x: end.x - 46, y: end.y - 46, width: 92, height: 92))
        mustard.setFill()
        dot.fill()
        dot.lineWidth = 31
        ink.setStroke()
        dot.stroke()
    }

    /// A point in the website mark's 52-unit tile space (origin top-left), on the icon grid.
    private static func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: tile.minX + x * tile.width / 52, y: tile.maxY - y * tile.height / 52)
    }

    private static func arc(sweep: CGFloat, width: CGFloat, color: NSColor) {
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - sweep, clockwise: true)
        path.lineWidth = width
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
    InkRing.draw(in: context)
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
