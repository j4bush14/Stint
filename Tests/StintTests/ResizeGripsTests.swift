import AppKit
import Testing
@testable import Stint

@Suite("Resize grips")
struct ResizeGripsTests {
    let size = NSSize(width: 320, height: 404)

    @Test("Straight edges grip a band along each side", arguments: [
        (NSPoint(x: 3, y: 200), ResizeEdges.left), (NSPoint(x: 317, y: 200), .right),
        (NSPoint(x: 160, y: 3), .bottom), (NSPoint(x: 160, y: 401), .top),
    ] as [(NSPoint, ResizeEdges)])
    func sides(point: NSPoint, edges: ResizeEdges) {
        #expect(ResizeGrips.edges(at: point, in: size, cornerRadius: 34) == edges)
    }

    @Test("Corners grip along the rounded edge you can see", arguments: [
        (NSPoint(x: 12, y: 12), ResizeEdges([.left, .bottom])), (NSPoint(x: 308, y: 12), ResizeEdges([.right, .bottom])),
        (NSPoint(x: 12, y: 392), ResizeEdges([.left, .top])), (NSPoint(x: 308, y: 392), ResizeEdges([.right, .top])),
    ] as [(NSPoint, ResizeEdges)])
    func corners(point: NSPoint, edges: ResizeEdges) {
        #expect(ResizeGrips.edges(at: point, in: size, cornerRadius: 34) == edges)
    }

    @Test("The middle of the panel and the inside of a corner aren't grips")
    func notGrips() {
        #expect(ResizeGrips.edges(at: NSPoint(x: 160, y: 200), in: size, cornerRadius: 34).isEmpty)
        #expect(ResizeGrips.edges(at: NSPoint(x: 26, y: 26), in: size, cornerRadius: 34).isEmpty)
        #expect(ResizeGrips.edges(at: NSPoint(x: -1, y: 200), in: size, cornerRadius: 34).isEmpty)
    }

    @Test("Dragging an edge keeps the opposite edge in place")
    func keepsOppositeEdge() {
        let frame = NSRect(x: 100, y: 100, width: 320, height: 404)
        let limits = (min: NSSize(width: 200, height: 56), max: NSSize(width: 1400, height: 1400))
        let left = ResizeGrips.resized(frame, edges: .left, by: NSSize(width: -50, height: 0), min: limits.min, max: limits.max)
        #expect(left == NSRect(x: 50, y: 100, width: 370, height: 404))
        let topRight = ResizeGrips.resized(frame, edges: [.top, .right], by: NSSize(width: 30, height: 20), min: limits.min, max: limits.max)
        #expect(topRight == NSRect(x: 100, y: 100, width: 350, height: 424))
        let bottom = ResizeGrips.resized(frame, edges: .bottom, by: NSSize(width: 0, height: 40), min: limits.min, max: limits.max)
        #expect(bottom.maxY == frame.maxY)
        #expect(bottom.height == 364)
    }

    @Test("Resizing stops at the panel's limits without moving the far edge")
    func limits() {
        let frame = NSRect(x: 100, y: 100, width: 320, height: 404)
        let shrunk = ResizeGrips.resized(frame, edges: [.left, .bottom], by: NSSize(width: 500, height: 500),
                                         min: NSSize(width: 200, height: 56), max: NSSize(width: 1400, height: 1400))
        #expect(shrunk.size == NSSize(width: 200, height: 56))
        #expect(shrunk.maxX == frame.maxX && shrunk.maxY == frame.maxY)
    }
}
