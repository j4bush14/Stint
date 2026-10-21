import SwiftUI

/// Where a control marked with `testTarget(_:value:)` is, and what it shows.
struct TestTarget {
    var bounds: Anchor<CGRect>
    var value: String?
}

/// Controls marked with `testTarget(_:value:)`, keyed by name. UI tests read these to click
/// real controls in a real window and check what's displayed; the app never reads them.
struct TestTargetsKey: PreferenceKey {
    static let defaultValue: [String: TestTarget] = [:]

    static func reduce(value: inout [String: TestTarget], nextValue: () -> [String: TestTarget]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Names this view for UI tests (like an accessibility identifier), optionally with the
    /// value it currently displays.
    func testTarget(_ name: String, value: String? = nil) -> some View {
        // A marker in the background has this view's frame, and as a sibling its value combines
        // with targets inside this view instead of replacing them.
        background(TestTargetMarker(name: name, value: value))
    }
}

private struct TestTargetMarker: View {
    let name: String
    let value: String?

    var body: some View {
        Color.clear
            .allowsHitTesting(false) // a marker must never intercept clicks
            .anchorPreference(key: TestTargetsKey.self, value: .bounds) { bounds in
                [name: TestTarget(bounds: bounds, value: value)]
            }
    }
}
