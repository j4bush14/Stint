import AppKit
import Testing
@testable import Stint

@Suite("Colors")
struct ThemeTests {
    @Test("Hex round-trips", arguments: ["#7A5AF8", "#000000", "#FFFFFF", "#1F6FBD"])
    func hexRoundTrip(hex: String) throws {
        let color = try #require(NSColor(hex: hex))
        #expect(color.hexString == hex)
    }

    @Test("Invalid hex is rejected", arguments: ["", "#12345", "zzzzzz", "#1234567"])
    func invalidHex(hex: String) {
        #expect(NSColor(hex: hex) == nil)
    }

    @Test("Every theme has distinct focus and break colors")
    func distinctPhaseColors() {
        let custom = NSColor(hex: "#7A5AF8")!
        for palette in Palette.allCases {
            let focus = palette.nsColor(for: .focus, base: custom).hexString
            let rest = palette.nsColor(for: .shortBreak, base: custom).hexString
            #expect(focus != rest, "\(palette.name)")
        }
    }
}
