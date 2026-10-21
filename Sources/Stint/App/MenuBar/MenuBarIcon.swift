import AppKit

/// A change of the time shown, part-way through its animation.
struct MenuBarTransition {
    /// The time shown before the change.
    let from: String
    /// How far along the change is, 0…1.
    let progress: CGFloat
}

/// Draws `MenuBarContent` as one template image (so it follows the menu bar's light or dark
/// look): the panel's ring or dial in miniature with a sweeping second hand, a break cup,
/// ready/paused marks, and the time as digits that roll or split-flap tiles that flip.
@MainActor
enum MenuBarIcon {
    static let height: CGFloat = 16
    private static let gap: CGFloat = 4
    private static let digitFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    private static let tileFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)

    /// Colors for a tinted image: the glyph in `glyph`, and the time in the menu bar's
    /// own text color (a tinted image can't be a template, so it can't adapt by itself).
    struct Tint: Equatable {
        let glyph: NSColor
        let text: NSColor
    }

    /// The whole item, or nil when there's nothing to draw. `transition` animates the time
    /// from what was shown before; `tint` colors the glyph (the break cup).
    static func image(for content: MenuBarContent, transition: MenuBarTransition? = nil, tint: Tint? = nil) -> NSImage? {
        let glyph = content.glyph.map(glyphImage)
        let time = content.time.map { time in
            content.usesFlipTiles ? TimeDrawing.tiles(time, font: tileFont) : TimeDrawing.digits(time, font: digitFont)
        }
        guard glyph != nil || time != nil else { return nil }

        let glyphWidth = glyph?.size.width ?? 0
        let width = glyphWidth + (glyph != nil && time != nil ? gap : 0) + (time?.width ?? 0)
        let image = NSImage(size: NSSize(width: ceil(width), height: height), flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            if let glyph {
                let rect = NSRect(x: 0, y: (bounds.height - glyph.size.height) / 2,
                                  width: glyph.size.width, height: glyph.size.height)
                colored(tint?.glyph, in: context) { glyph.draw(in: rect) }
            }
            if let time {
                let x = width - time.width
                context.saveGState()
                context.setAlpha(content.isDimmed ? 0.5 : 1) // a stopped clock's time is dimmed
                colored(tint?.text, in: context) {
                    time.draw(NSRect(x: x, y: 0, width: time.width, height: bounds.height), transition, context)
                }
                context.restoreGState()
            }
            return true
        }
        image.isTemplate = tint == nil
        return image
    }

    /// Draws template-style (black) artwork, recolored to `color` if one is given.
    private static func colored(_ color: NSColor?, in context: CGContext, _ draw: () -> Void) {
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        draw()
        if let color {
            context.setBlendMode(.sourceAtop)
            context.setFillColor(color.cgColor)
            context.fill(context.boundingBoxOfClipPath)
        }
        context.endTransparencyLayer()
    }

    /// The glyph on its own.
    static func glyphImage(_ glyph: MenuBarContent.Glyph) -> NSImage {
        switch glyph {
        case .cup:
            let symbol = NSImage(systemSymbolName: "cup.and.heat.waves.fill", accessibilityDescription: "Break")?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold)) ?? NSImage()
            symbol.isTemplate = true
            return symbol
        case .ring(let step, let mark, let second):
            return drawn(width: height) { rect in ring(in: rect, step: step, mark: mark, second: second) }
        case .dial(let step, let mark, let second):
            return drawn(width: height) { rect in dial(in: rect, step: step, mark: mark, second: second) }
        case .mark(let mark):
            return drawn(width: 9) { rect in draw(mark, in: rect, size: 7) }
        }
    }

    // MARK: Glyphs

    /// The panel's ring: a faint track with the elapsed part drawn from 12 o'clock, and a
    /// hand that sweeps once a minute while running.
    private static func ring(in rect: NSRect, step: Int, mark: MenuBarContent.Mark, second: Int?) {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let inset = rect.insetBy(dx: 1.75, dy: 1.75)
        let track = NSBezierPath(ovalIn: inset)
        track.lineWidth = 1.75
        NSColor.black.withAlphaComponent(0.35).setStroke()
        track.stroke()
        if step > 0 {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: inset.width / 2, startAngle: 90,
                          endAngle: 90 - CGFloat(step) / CGFloat(MenuBarContent.steps) * 360, clockwise: true)
            arc.lineWidth = 2.25
            arc.lineCapStyle = .round
            NSColor.black.setStroke()
            arc.stroke()
        }
        if let second {
            hand(at: second, from: center, length: inset.width / 2 - 3).stroke()
        }
        draw(mark, in: rect, size: 5.5)
    }

    /// The panel's dial: an outline with a wedge of the time left, shrinking toward 12, and a
    /// hand cut through it that sweeps once a minute while running.
    private static func dial(in rect: NSRect, step: Int, mark: MenuBarContent.Mark, second: Int?) {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let outline = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
        outline.lineWidth = 1.25
        NSColor.black.setStroke()
        outline.stroke()
        let left = 1 - CGFloat(step) / CGFloat(MenuBarContent.steps)
        if left > 0 {
            let wedge = NSBezierPath()
            wedge.move(to: center)
            wedge.appendArc(withCenter: center, radius: rect.width / 2 - 3, startAngle: 90,
                            endAngle: 90 - left * 360, clockwise: true)
            wedge.close()
            NSColor.black.withAlphaComponent(mark == .none ? 1 : 0.45).setFill()
            wedge.fill()
        }
        let graphics = NSGraphicsContext.current
        if let second {
            graphics?.compositingOperation = .clear
            hand(at: second, from: center, length: rect.width / 2 - 3).stroke()
            graphics?.compositingOperation = .sourceOver
        }
        if mark != .none {
            // Clear a spot so the mark reads on top of the wedge.
            graphics?.compositingOperation = .clear
            NSBezierPath(ovalIn: rect.insetBy(dx: 4.5, dy: 4.5)).fill()
            graphics?.compositingOperation = .sourceOver
            draw(mark, in: rect, size: 4.5)
        }
    }

    /// A clock hand pointing at `second` (0 at 12 o'clock, clockwise).
    private static func hand(at second: Int, from center: NSPoint, length: CGFloat) -> NSBezierPath {
        let angle = (90 - CGFloat(second) * 6) * .pi / 180
        let path = NSBezierPath()
        path.move(to: center)
        path.line(to: NSPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length))
        path.lineWidth = 1.25
        path.lineCapStyle = .round
        NSColor.black.setStroke()
        return path
    }

    /// ▶ for ready, ❚❚ for paused, centered in `rect`.
    private static func draw(_ mark: MenuBarContent.Mark, in rect: NSRect, size: CGFloat) {
        NSColor.black.setFill()
        let center = NSPoint(x: rect.midX, y: rect.midY)
        switch mark {
        case .none:
            break
        case .ready:
            let half = size / 2
            let triangle = NSBezierPath()
            triangle.move(to: NSPoint(x: center.x - half * 0.8, y: center.y - half))
            triangle.line(to: NSPoint(x: center.x - half * 0.8, y: center.y + half))
            triangle.line(to: NSPoint(x: center.x + half, y: center.y))
            triangle.close()
            triangle.fill()
        case .paused:
            let bar = max(1.5, size * 0.28)
            for x in [center.x - bar * 1.5, center.x + bar / 2] {
                NSBezierPath(roundedRect: NSRect(x: x, y: center.y - size / 2, width: bar, height: size),
                             xRadius: bar / 3, yRadius: bar / 3).fill()
            }
        }
    }

    private static func drawn(width: CGFloat, _ draw: @escaping (NSRect) -> Void) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            draw(rect)
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// The time part of the menu bar image: its width and how to draw it, with or without a
/// transition from the previous time.
@MainActor
private struct TimeDrawing {
    let width: CGFloat
    let draw: (NSRect, MenuBarTransition?, CGContext) -> Void

    // MARK: Rolling digits

    /// Digits that roll: each changed character slides up and out as the new one rises in.
    static func digits(_ time: String, font: NSFont) -> TimeDrawing {
        let characters = time.map(String.init)
        let widths = characters.map { ($0 as NSString).size(withAttributes: [.font: font]).width }
        return TimeDrawing(width: widths.reduce(0, +)) { rect, transition, _ in
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            // Center the digits' cap height in the image.
            let baseline = rect.minY + (rect.height - font.capHeight) / 2
            let old = transition.map { $0.from.map(String.init) }
            let rolls = old?.count == characters.count
            var x = rect.minX
            for (index, character) in characters.enumerated() {
                let changed = rolls && old?[index] != character
                if changed, let transition, let previous = old?[index] {
                    let t = ease(transition.progress)
                    let travel = rect.height * 0.75
                    drawText(previous, x: x, baseline: baseline + travel * t, alpha: 1 - t, font: font, attributes: attributes)
                    drawText(character, x: x, baseline: baseline - travel * (1 - t), alpha: t, font: font, attributes: attributes)
                } else {
                    drawText(character, x: x, baseline: baseline, alpha: 1, font: font, attributes: attributes)
                }
                x += widths[index]
            }
        }
    }

    private static func drawText(_ text: String, x: CGFloat, baseline: CGFloat, alpha: CGFloat,
                                 font: NSFont, attributes: [NSAttributedString.Key: Any]) {
        var attributes = attributes
        attributes[.foregroundColor] = NSColor.black.withAlphaComponent(alpha)
        (text as NSString).draw(at: NSPoint(x: x, y: baseline + font.descender), withAttributes: attributes)
    }

    // MARK: Split-flap tiles

    private static let colonWidth: CGFloat = 5
    private static let tilePadding: CGFloat = 6

    /// Split-flap tiles, one per group ("25" ":" "00"). A changed tile flips: the old top
    /// half falls over the hinge, then the new bottom half lands, as on the panel.
    static func tiles(_ time: String, font: NSFont) -> TimeDrawing {
        let groups = time.split(separator: ":").map(String.init)
        let widths = groups.map { ($0 as NSString).size(withAttributes: [.font: font]).width + tilePadding }
        let width = widths.reduce(0, +) + colonWidth * CGFloat(max(0, groups.count - 1))
        return TimeDrawing(width: width) { rect, transition, context in
            let old = transition.map { $0.from.split(separator: ":").map(String.init) }
            let flips = old?.count == groups.count
            var x = rect.minX
            for (index, group) in groups.enumerated() {
                if index > 0 {
                    NSColor.black.setFill()
                    for dy in [-2.5, 2.5] as [CGFloat] {
                        NSBezierPath(ovalIn: NSRect(x: x + colonWidth / 2 - 1, y: rect.midY + dy - 1, width: 2, height: 2)).fill()
                    }
                    x += colonWidth
                }
                let card = NSRect(x: x, y: rect.minY, width: widths[index], height: rect.height)
                if flips, let transition, let previous = old?[index], previous != group {
                    flip(from: previous, to: group, in: card, progress: transition.progress, font: font, context: context)
                } else {
                    half(group, of: card, top: true, font: font, context: context)
                    half(group, of: card, top: false, font: font, context: context)
                }
                x += widths[index]
            }
        }
    }

    private static func flip(from old: String, to new: String, in card: NSRect, progress: CGFloat,
                             font: NSFont, context: CGContext) {
        let t = ease(progress)
        let halfHeight = card.height / 2
        if t < 0.5 {
            // The old top half falls toward the hinge, uncovering the new top half behind it.
            let fold = cos(t * .pi) // 1 → 0
            half(new, of: card, top: true, font: font, context: context,
                 clip: NSRect(x: card.minX, y: card.midY + halfHeight * fold, width: card.width, height: halfHeight * (1 - fold)))
            half(old, of: card, top: false, font: font, context: context)
            half(old, of: card, top: true, font: font, context: context, scale: fold, alpha: 0.85)
        } else {
            // The new bottom half lands over the old one.
            let fold = -cos(t * .pi) // 0 → 1
            half(new, of: card, top: true, font: font, context: context)
            half(old, of: card, top: false, font: font, context: context,
                 clip: NSRect(x: card.minX, y: card.minY, width: card.width, height: halfHeight * (1 - fold)))
            half(new, of: card, top: false, font: font, context: context, scale: fold, alpha: 0.85)
        }
    }

    /// One half of a tile (the card with its digits and hinge notches cut out), optionally squashed
    /// toward the hinge by `scale` and clipped further by `clip`.
    private static func half(_ digits: String, of card: NSRect, top: Bool, font: NSFont, context: CGContext,
                             clip: NSRect? = nil, scale: CGFloat = 1, alpha: CGFloat = 1) {
        guard scale > 0.01 else { return }
        context.saveGState()
        var region = NSRect(x: card.minX, y: top ? card.midY : card.minY, width: card.width, height: card.height / 2)
        if let clip { region = region.intersection(clip) }
        guard !region.isEmpty else { context.restoreGState(); return }
        context.clip(to: region)
        context.setAlpha(alpha)
        context.translateBy(x: 0, y: card.midY)
        context.scaleBy(x: 1, y: scale)
        context.translateBy(x: 0, y: -card.midY)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        NSColor.black.setFill()
        NSBezierPath(roundedRect: card, xRadius: 3.5, yRadius: 3.5).fill()
        context.setBlendMode(.destinationOut)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let size = (digits as NSString).size(withAttributes: attributes)
        (digits as NSString).draw(at: NSPoint(x: card.midX - size.width / 2, y: card.midY - size.height / 2 + 0.5),
                                  withAttributes: attributes)
        // The hinge: notches at the card's edges (a line across would read as strikethrough).
        for x in [card.minX, card.maxX - 1.5] {
            context.fill(CGRect(x: x, y: card.midY - 0.6, width: 1.5, height: 1.2))
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func ease(_ t: CGFloat) -> CGFloat {
        let t = min(max(t, 0), 1)
        return t * t * (3 - 2 * t)
    }
}
