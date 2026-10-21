import AppKit
import SwiftUI

// How the app's color choices (themes, tag colors, the custom color) become real colors.

// MARK: - Color themes

extension Palette {
    /// Fixed (focus, break) colors in sRGB; nil for themes built from a base color.
    private var fixedColors: (focus: (Double, Double, Double), rest: (Double, Double, Double))? {
        switch self {
        case .lagoon: ((0.13, 0.43, 0.74), (0.08, 0.53, 0.58))
        case .ember: ((0.86, 0.38, 0.17), (0.58, 0.29, 0.44))
        case .iris: ((0.43, 0.34, 0.83), (0.25, 0.46, 0.79))
        case .moss: ((0.38, 0.56, 0.22), (0.24, 0.44, 0.44))
        case .rose: ((0.81, 0.27, 0.46), (0.56, 0.36, 0.71))
        case .graphite: ((0.30, 0.32, 0.37), (0.43, 0.46, 0.52))
        case .wallpaper, .custom: nil
        }
    }

    /// - Parameter base: the focus color for `custom` and `wallpaper`; ignored otherwise.
    func nsColor(for phase: Phase, base: NSColor) -> NSColor {
        guard let colors = fixedColors else {
            return phase == .focus ? base : Self.companion(of: base)
        }
        let c = phase == .focus ? colors.focus : colors.rest
        return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
    }

    /// A break color derived from a focus color: shifted hue, softer and a bit darker.
    static func companion(of color: NSColor) -> NSColor {
        let c = color.usingColorSpace(.sRGB) ?? color
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: (h + 0.09).truncatingRemainder(dividingBy: 1), saturation: s * 0.8, brightness: b * 0.82, alpha: 1)
    }
}


// MARK: - Tag colors

extension TagColor {
    var color: Color {
        switch self {
        case .sky: Color(red: 0.25, green: 0.58, blue: 0.92)
        case .violet: Color(red: 0.58, green: 0.42, blue: 0.90)
        case .coral: Color(red: 0.95, green: 0.45, blue: 0.40)
        case .amber: Color(red: 0.96, green: 0.70, blue: 0.20)
        case .sage: Color(red: 0.45, green: 0.68, blue: 0.45)
        case .slate: Color(red: 0.50, green: 0.55, blue: 0.62)
        }
    }
}

// MARK: - Custom color

extension AppSettings {
    /// The Custom theme's focus color, stored as a hex string.
    var customColor: NSColor {
        get { NSColor(hex: customColorHex) ?? .systemPurple }
        set { customColorHex = newValue.hexString }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "#%02X%02X%02X", Int(round(c.redComponent * 255)),
                      Int(round(c.greenComponent * 255)), Int(round(c.blueComponent * 255)))
    }
}
