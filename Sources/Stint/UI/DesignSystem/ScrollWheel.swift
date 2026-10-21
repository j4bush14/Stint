import AppKit
import SwiftUI

extension View {
    /// Calls `action` with whole steps (+ up, − down) when the scroll wheel or trackpad
    /// scrolls over this view. Clicks pass through untouched.
    func onScrollWheel(_ action: @escaping (Int) -> Void) -> some View {
        background(ScrollWheelReader(onSteps: action))
    }
}

private struct ScrollWheelReader: NSViewRepresentable {
    let onSteps: (Int) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onSteps = onSteps
        return view
    }

    func updateNSView(_ view: ReaderView, context: Context) {
        view.onSteps = onSteps
    }

    final class ReaderView: NSView {
        var onSteps: ((Int) -> Void)?
        private var monitor: Any?
        private var stepper = ScrollStepper()

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                // Local monitors run on the main thread; the event never leaves it.
                nonisolated(unsafe) let event = event
                let consumed = MainActor.assumeIsolated { self?.handle(event) ?? false }
                return consumed ? nil : event
            }
        }

        /// Returns true if the event was over this view and has been used.
        private func handle(_ event: NSEvent) -> Bool {
            guard event.window === window,
                  bounds.contains(convert(event.locationInWindow, from: nil)) else { return false }
            let steps = stepper.steps(deltaY: event.scrollingDeltaY, isPrecise: event.hasPreciseScrollingDeltas)
            if steps != 0 { onSteps?(steps) }
            return true
        }
    }
}

/// Turns scroll deltas into whole steps: a mouse wheel notch is one step; a trackpad gives
/// one step per `pointsPerStep` points of travel, carrying the remainder over.
struct ScrollStepper {
    var pointsPerStep: CGFloat = 14
    private var accumulated: CGFloat = 0

    mutating func steps(deltaY: CGFloat, isPrecise: Bool) -> Int {
        guard isPrecise else { return deltaY == 0 ? 0 : (deltaY > 0 ? 1 : -1) }
        accumulated += deltaY
        let steps = Int(accumulated / pointsPerStep)
        accumulated -= CGFloat(steps) * pointsPerStep
        return steps
    }
}
