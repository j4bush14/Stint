import AppKit
import SwiftUI
import Testing
@testable import Stint

extension UITests {
    /// The panel's resize grips, dragged with real mouse events.
    @MainActor
    @Suite("Panel resizing")
    struct PanelResizing {
        private static var retired: [NSWindow] = []
        private func drag(_ panel: NSWindow, from start: NSPoint, by delta: CGSize) {
            func event(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                   windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            }
            let origin = panel.frame.origin
            panel.sendEvent(event(.leftMouseDown, start))
            for step in 1...6 {
                // Each event's position is relative to the window as it is at that moment.
                let screen = NSPoint(x: origin.x + start.x + delta.width * CGFloat(step) / 6,
                                     y: origin.y + start.y + delta.height * CGFloat(step) / 6)
                panel.sendEvent(event(.leftMouseDragged, NSPoint(x: screen.x - panel.frame.minX, y: screen.y - panel.frame.minY)))
            }
            let end = NSPoint(x: origin.x + start.x + delta.width - panel.frame.minX, y: origin.y + start.y + delta.height - panel.frame.minY)
            panel.sendEvent(event(.leftMouseUp, end))
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }

        @Test("Dragging an edge or a rounded corner resizes, keeping the opposite side put")
        func dragEdges() throws {
            _ = NSApplication.shared
            // A window laid out like the panel: content with the grips over it.
            let panel = FloatingPanel(contentRect: NSRect(x: 300, y: 300, width: 320, height: 404),
                                      styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.contentMinSize = TimerPanelView.minSize
            panel.contentMaxSize = TimerPanelView.maxSize
            let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 404))
            let grips = ResizeGrips(frame: container.bounds)
            grips.autoresizingMask = [.width, .height]
            container.addSubview(grips)
            panel.contentView = container
            panel.orderFront(nil)
            defer { panel.orderOut(nil); Self.retired.append(panel) }
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))

            drag(panel, from: NSPoint(x: 317, y: 200), by: CGSize(width: 60, height: 0)) // right edge
            #expect(panel.frame == NSRect(x: 300, y: 300, width: 380, height: 404))

            drag(panel, from: NSPoint(x: 3, y: 200), by: CGSize(width: -40, height: 0)) // left edge
            #expect(panel.frame == NSRect(x: 260, y: 300, width: 420, height: 404))

            drag(panel, from: NSPoint(x: 12, y: 12), by: CGSize(width: 30, height: 50)) // bottom-left corner, inward
            #expect(panel.frame.maxX == 680 && panel.frame.maxY == 704, "top-right corner stays put")
            #expect(panel.frame.size == NSSize(width: 390, height: 354))
        }
    }
}
