import AppKit
import SwiftUI
import Testing
@testable import Stint

/// Readability of white text on the panel, by the WCAG contrast formula.
@MainActor
@Suite("Text contrast")
struct ContrastTests {
    /// Relative luminance of an sRGB color.
    private func luminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func linear(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    private func contrast(_ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double)) -> Double {
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// `top` at `alpha` over `bottom`.
    private func over(_ top: (r: Double, g: Double, b: Double), _ alpha: Double, _ bottom: (r: Double, g: Double, b: Double)) -> (r: Double, g: Double, b: Double) {
        (top.r * alpha + bottom.r * (1 - alpha), top.g * alpha + bottom.g * (1 - alpha), top.b * alpha + bottom.b * (1 - alpha))
    }

    private func rgb(_ color: NSColor) -> (r: Double, g: Double, b: Double) {
        let c = color.usingColorSpace(.sRGB)!
        return (c.redComponent, c.greenComponent, c.blueComponent)
    }

    /// The lightest backgrounds the panel can show, with the tint turned all the way down
    /// over a white desktop: the Wallpaper theme's scrim, and each theme's focus and break wash.
    private var lightestPanels: [(String, (r: Double, g: Double, b: Double))] {
        let white = (r: 1.0, g: 1.0, b: 1.0)
        var panels = [("Wallpaper over white", over((0, 0, 0), 0.06, white))]
        for palette in Palette.allCases where palette != .wallpaper {
            for phase in [Phase.focus, .shortBreak] {
                let wash = rgb(palette.nsColor(for: phase, base: .systemPurple))
                panels.append(("\(palette) \(phase)", over(wash, 0.25, white)))
            }
        }
        return panels
    }

    @Test("Typed session names read clearly (4.5:1) on every theme")
    func typedText() {
        for (name, panel) in lightestPanels {
            let field = over((0, 0, 0), SessionTitleField.fieldDarkness, panel)
            let ratio = contrast((1, 1, 1), field)
            #expect(ratio >= 4.5, "\(name): \(ratio)")
        }
    }

    @Test("The placeholder stays legible (3:1) on every theme")
    func placeholder() {
        for (name, panel) in lightestPanels {
            let field = over((0, 0, 0), SessionTitleField.fieldDarkness, panel)
            let text = over((1, 1, 1), SessionTitleField.placeholderOpacity, field)
            let ratio = contrast(text, field)
            #expect(ratio >= 3, "\(name): \(ratio)")
        }
    }
}

extension ContrastTests {
    @Test("A very light custom color is deepened enough for the white clock digits (3:1, large text)", arguments: [
        NSColor.white, NSColor(srgbRed: 1, green: 0.95, blue: 0.5, alpha: 1), NSColor(srgbRed: 0.8, green: 1, blue: 0.9, alpha: 1),
    ])
    func lightCustomColors(picked: NSColor) {
        let env = TestEnvironment()
        env.settings.palette = .custom
        env.settings.customColor = picked
        let theme = ThemeModel(settings: env.settings, wallpaper: WallpaperColors(settings: env.settings))
        for phase in [Phase.focus, .shortBreak] {
            let color = rgb(theme.nsColor(for: phase))
            let ratio = contrast((1, 1, 1), color)
            #expect(ratio >= 3, "\(phase): white text on the theme color is \(ratio):1")
        }
    }
}

@Suite("Progress motion")
struct ProgressMotionTests {
    @Test("A second's tick glides; a reset or jump eases instead of crawling back")
    func motion() {
        #expect(Gliding<EmptyView>.motion(from: 0.40, to: 0.41) == .linear(duration: 1))
        #expect(Gliding<EmptyView>.motion(from: 0.95, to: 0) == .smooth(duration: 0.55))
        #expect(Gliding<EmptyView>.motion(from: 0.2, to: 0.6) == .smooth(duration: 0.55))
    }
}

extension ContrastTests {
    @Test("The Ink panel is the theme's color, solid; Glass keeps its see-through wash")
    func inkWash() {
        let env = TestEnvironment()
        let theme = ThemeModel(settings: env.settings, wallpaper: WallpaperColors(settings: env.settings))
        #expect(theme.washColors(for: .focus).top != theme.color(for: .focus))

        env.settings.panelStyle = .ink
        for phase in [Phase.focus, .shortBreak] {
            let wash = theme.washColors(for: phase)
            #expect(wash.top == theme.color(for: phase))
            #expect(wash.bottom == theme.color(for: phase))
        }
    }
}
