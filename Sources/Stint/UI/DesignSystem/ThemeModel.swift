import AppKit
import Combine
import SwiftUI

/// The current colors, derived from the chosen theme and (for the Wallpaper theme) the
/// sampled wallpaper. Views observe it instead of reading settings for colors themselves.
@MainActor
final class ThemeModel: ObservableObject {
    private let settings: AppSettings
    private let wallpaper: WallpaperColors
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings, wallpaper: WallpaperColors) {
        self.settings = settings
        self.wallpaper = wallpaper
        settings.objectWillChange.merge(with: wallpaper.objectWillChange)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// The base color for themes that don't have fixed colors.
    private var baseColor: NSColor {
        switch settings.palette {
        case .wallpaper:
            wallpaper.sample?.accent ?? WallpaperSampler.readable(.controlAccentColor)
        default:
            settings.customColor
        }
    }

    func nsColor(for phase: Phase) -> NSColor {
        settings.palette.nsColor(for: phase, base: baseColor)
    }

    func color(for phase: Phase) -> Color { Color(nsColor: nsColor(for: phase)) }

    /// The app-wide accent (the focus color of the current theme).
    var accent: Color { color(for: .focus) }

    /// The panel uses clear glass for the Wallpaper theme so what's behind it shows through.
    var glassStyle: NSGlassEffectView.Style {
        settings.palette == .wallpaper ? .clear : .regular
    }

    /// Color laid over the panel's glass. Constant per phase, so starting and pausing never
    /// shift the background; `tintStrength` sets how much of the glass shows through.
    func panelWash(for phase: Phase) -> AnyShapeStyle {
        let strength = settings.tintStrength
        guard settings.palette == .wallpaper else {
            return AnyShapeStyle(color(for: phase).opacity(0.25 + 0.6 * strength))
        }
        // Wallpaper: a gradient of the sampled colors, or a soft scrim that keeps white text
        // readable over whatever the clear glass shows.
        let opacity = 0.15 + 0.6 * strength
        let colors: [Color] = if let sample = wallpaper.sample {
            [Color(nsColor: sample.top).opacity(opacity), Color(nsColor: sample.bottom).opacity(opacity)]
        } else {
            [Color.black.opacity(0.06 + 0.25 * strength), Color.black.opacity(0.14 + 0.35 * strength)]
        }
        return AnyShapeStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
    }
}
