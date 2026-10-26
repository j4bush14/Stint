import AppKit
import SwiftUI

/// Color theme, glass tint, light/dark mode and the menu bar item.
struct AppearancePane: View {
    @EnvironmentObject private var s: AppSettings
    @EnvironmentObject private var wallpaper: WallpaperColors

    private var customColor: Binding<Color> {
        Binding(
            get: { Color(nsColor: s.customColor) },
            set: { s.customColor = NSColor($0) }
        )
    }

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 14)], spacing: 14) {
                    ForEach(Palette.allCases) { palette in
                        Button { withAnimation(.smooth) { s.palette = palette } } label: {
                            PaletteSwatch(palette: palette, selected: s.palette == palette,
                                          custom: s.customColor, wallpaper: wallpaper.sample)
                        }
                        .buttonStyle(.plain)
                        .testTarget("palette.\(palette.rawValue)", value: s.palette == palette ? "selected" : nil)
                    }
                }
                .padding(.vertical, 6)
                if s.palette == .custom {
                    ColorPicker("Focus color", selection: customColor, supportsOpacity: false)
                }
            } header: {
                Text("Color")
            } footer: {
                footnote(colorFootnote)
            }

            Section("Clock") {
                Picker("Style", selection: $s.clockStyle) {
                    ForEach(ClockStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden() // the section header already says "Clock"
                .testTarget("appearance.clockStyle", value: s.clockStyle.rawValue)
            }

            Section {
                Picker("Panel", selection: $s.panelStyle) {
                    ForEach(PanelStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .testTarget("appearance.panelStyle", value: s.panelStyle.rawValue)
            } header: {
                Text("Style")
            } footer: {
                footnote("Glass is Liquid Glass tinted with your theme. Ink is flat color with ink outlines, like the Stint website.")
            }

            Section {
                LabeledContent("Tint") {
                    Slider(value: $s.tintStrength, in: 0...1) {
                        Text("Tint")
                    } minimumValueLabel: {
                        Text("Clear")
                    } maximumValueLabel: {
                        Text("Strong")
                    }
                    .labelsHidden() // the row already says "Tint"
                    .frame(width: 260)
                }
                .disabled(s.panelStyle == .ink) // Ink is solid color
                ThemePreview()
            } header: {
                Text("Glass")
            } footer: {
                footnote("How much color sits on the timer's glass. Less tint lets more of the desktop show through.")
            }

            Section("Mode") {
                Picker("Appearance", selection: $s.appearance) {
                    ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Picker("Show", selection: $s.menuBarIconStyle) {
                    ForEach(MenuBarIconStyle.allCases) { Text($0.label).tag($0) }
                }
                SettingToggle("Color the break icon", isOn: $s.coloredMenuBarIcon, id: "coloredMenuBarIcon")
                SettingToggle("Show the session title", isOn: $s.titleInMenuBarIcon, id: "titleInMenuBarIcon")
            } header: {
                Text("Menu Bar")
            } footer: {
                footnote("The icon takes the shape of your clock style and shows ▶ when ready, ❚❚ when paused and a cup during breaks. Click it to show the timer; right-click for more. Stint has no Dock icon: if it's missing from the menu bar, the bar may be full (⌘-drag icons to make room).")
            }
        }
        .formStyle(.grouped)
    }

    private var colorFootnote: String {
        switch s.palette {
        case .wallpaper where wallpaper.sample == nil:
            "The timer uses clear glass, so your wallpaper shows through it. Stint can't read this wallpaper's file (it's kept by another app or in a private folder), so it can't add matching colors."
        case .wallpaper:
            "The timer uses clear glass and takes its colors from the part of your wallpaper behind it. Move the timer and the colors follow."
        case .custom:
            "Pick a focus color; Stint derives a calmer break color from it, and keeps both deep enough for white text to read."
        default:
            "Each theme pairs a focus color with a calmer break color."
        }
    }
}

/// A round swatch split between a theme's focus and break colors.
struct PaletteSwatch: View {
    let palette: Palette
    let selected: Bool
    let custom: NSColor
    let wallpaper: WallpaperSampler.Sample?

    var body: some View {
        VStack(spacing: 6) {
            swatch
                .frame(width: 40, height: 40)
                .overlay {
                    Circle()
                        .strokeBorder(selected ? Color.primary : .clear, lineWidth: 2)
                        .padding(-4)
                }
            Text(palette.name)
                .font(.caption)
                .foregroundStyle(selected ? .primary : .secondary)
        }
        .contentShape(Rectangle())
        .accessibilityLabel("\(palette.name) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var swatch: some View {
        switch palette {
        case .wallpaper:
            ZStack {
                if let wallpaper {
                    Circle().fill(LinearGradient(colors: [Color(nsColor: wallpaper.top), Color(nsColor: wallpaper.bottom)],
                                                 startPoint: .top, endPoint: .bottom))
                } else {
                    Circle().fill(.quaternary)
                }
                Image(systemName: "photo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(wallpaper == nil ? Color.secondary : .white)
            }
        default:
            ZStack {
                Circle().fill(Color(nsColor: palette.nsColor(for: .shortBreak, base: custom)))
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .fill(Color(nsColor: palette.nsColor(for: .focus, base: custom)))
                if palette == .custom {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

/// Miniature timer panels showing the current theme and tint on Liquid Glass.
struct ThemePreview: View {
    @EnvironmentObject private var theme: ThemeModel
    @EnvironmentObject private var s: AppSettings
    @EnvironmentObject private var wallpaper: WallpaperColors

    var body: some View {
        HStack(spacing: 12) {
            sample(.focus, label: "Focus")
            sample(.shortBreak, label: "Break")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func sample(_ phase: Phase, label: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(.white.opacity(0.2), lineWidth: 4)
                Circle().trim(from: 0, to: 0.62)
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(phase == .focus ? "25:00" : "05:00")
                    .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
            }
            .frame(width: 64, height: 64)
            Text(label).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(theme.panelWash(for: phase), in: .rect(cornerRadius: 22))
        .glassEffect(s.palette == .wallpaper ? .clear : .regular, in: .rect(cornerRadius: 22))
    }
}
