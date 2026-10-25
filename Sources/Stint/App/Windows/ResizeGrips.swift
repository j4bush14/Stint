import AppKit

/// Which edges of the panel a resize moves. The bits match `NSCursor.FrameResizePosition`.
struct ResizeEdges: OptionSet, Hashable {
    let rawValue: UInt
    static let top = ResizeEdges(rawValue: 1 << 0)
    static let left = ResizeEdges(rawValue: 1 << 1)
    static let bottom = ResizeEdges(rawValue: 1 << 2)
    static let right = ResizeEdges(rawValue: 1 << 3)
}

/// Invisible grips around the panel's edge. A borderless window gets resize zones only a few
/// points wide, and the rounded corners hide them; these are wider, follow the visible
/// rounded corners, show the macOS resize cursors, and keep the opposite edge in place.
final class ResizeGrips: NSView {
    /// How far in from the edge a grip reaches.
    nonisolated static let band: CGFloat = 7

    /// The panel's corner radius, so the corner grips follow the visible curve.
    var cornerRadius: CGFloat = 34

    private var drag: (edges: ResizeEdges, mouse: NSPoint, frame: NSRect)?
    private var showsResizeCursor = false

    override var isFlipped: Bool { false }

    // MARK: Hit testing and cursors

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return Self.edges(at: local, in: bounds.size, cornerRadius: cornerRadius).isEmpty ? nil : self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseMoved(with event: NSEvent) { updateCursor(at: convert(event.locationInWindow, from: nil)) }
    override func mouseExited(with event: NSEvent) { updateCursor(at: NSPoint(x: -1, y: -1)) }

    private func updateCursor(at point: NSPoint) {
        guard drag == nil else { return }
        let edges = Self.edges(at: point, in: bounds.size, cornerRadius: cornerRadius)
        if let position = NSCursor.FrameResizePosition(rawValue: edges.rawValue), !edges.isEmpty {
            NSCursor.frameResize(position: position, directions: .all).set()
            showsResizeCursor = true
        } else if showsResizeCursor {
            NSCursor.arrow.set()
            showsResizeCursor = false
        }
    }

    // MARK: Dragging

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let edges = Self.edges(at: convert(event.locationInWindow, from: nil), in: bounds.size, cornerRadius: cornerRadius)
        guard !edges.isEmpty else { return }
        drag = (edges, window.convertPoint(toScreen: event.locationInWindow), window.frame)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let drag else { return }
        // In screen coordinates: the window itself moves while its left or bottom edge is dragged.
        let mouse = window.convertPoint(toScreen: event.locationInWindow)
        let frame = Self.resized(drag.frame, edges: drag.edges,
                                 by: NSSize(width: mouse.x - drag.mouse.x, height: mouse.y - drag.mouse.y),
                                 min: window.contentMinSize, max: window.contentMaxSize)
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        drag = nil
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    // MARK: Geometry

    /// The edges a grip at `point` resizes, or none. Along the straight sides it's a band
    /// `band` wide; in the corners, a band just inside the rounded edge you can see.
    nonisolated static func edges(at point: NSPoint, in size: NSSize, cornerRadius: CGFloat, band: CGFloat = band) -> ResizeEdges {
        guard NSRect(origin: .zero, size: size).contains(point) else { return [] }
        let radius = min(max(cornerRadius, band), min(size.width, size.height) / 2)
        let centerX: CGFloat? = point.x < radius ? radius : point.x > size.width - radius ? size.width - radius : nil
        let centerY: CGFloat? = point.y < radius ? radius : point.y > size.height - radius ? size.height - radius : nil
        if let centerX, let centerY {
            // In a corner: only the band along the curve, so controls near it still get clicks.
            guard hypot(point.x - centerX, point.y - centerY) >= radius - band else { return [] }
            return [point.x < centerX ? .left : .right, point.y < centerY ? .bottom : .top]
        }
        var edges: ResizeEdges = []
        if point.x < band { edges.insert(.left) } else if point.x > size.width - band { edges.insert(.right) }
        if point.y < band { edges.insert(.bottom) } else if point.y > size.height - band { edges.insert(.top) }
        return edges
    }

    /// `frame` resized by dragging `edges` by `delta`, within `min`…`max`, keeping the
    /// opposite edges where they were.
    nonisolated static func resized(_ frame: NSRect, edges: ResizeEdges, by delta: NSSize, min: NSSize, max: NSSize) -> NSRect {
        func clampWidth(_ w: CGFloat) -> CGFloat { Swift.min(Swift.max(w, min.width), max.width) }
        func clampHeight(_ h: CGFloat) -> CGFloat { Swift.min(Swift.max(h, min.height), max.height) }
        var result = frame
        if edges.contains(.right) { result.size.width = clampWidth(frame.width + delta.width) }
        if edges.contains(.left) {
            result.size.width = clampWidth(frame.width - delta.width)
            result.origin.x = frame.maxX - result.width
        }
        if edges.contains(.top) { result.size.height = clampHeight(frame.height + delta.height) }
        if edges.contains(.bottom) {
            result.size.height = clampHeight(frame.height - delta.height)
            result.origin.y = frame.maxY - result.height
        }
        return result
    }
}
