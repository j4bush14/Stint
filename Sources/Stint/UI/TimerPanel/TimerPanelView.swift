import SwiftUI

/// Root view of the floating timer panel.
///
/// The panel is freely resizable, so this view picks one of four layouts from its size.
/// Each layout budgets its space explicitly (ring diameter, control and chrome scale are
/// derived from what's left over), which keeps controls from overlapping at any size:
/// - `mini`: a single row for short windows
/// - `compact`: just the ring and controls
/// - `wide`: the ring beside a column of controls
/// - `tall`: phase, ring, controls and tag stacked
///
/// Every layout keeps Hide at the top-left and ⋯ at the top-right (see `PanelCornerButtons`),
/// and right-click opens the same menu anywhere.
struct TimerPanelView: View {
    @EnvironmentObject private var theme: ThemeModel
    nonisolated static let defaultSize = CGSize(width: 320, height: 404)
    nonisolated static let minSize = CGSize(width: 200, height: 56)
    nonisolated static let maxSize = CGSize(width: 1400, height: 1400)

    enum Layout { case mini, compact, wide, tall }

    static func layout(for size: CGSize) -> Layout {
        let (w, h) = (size.width, size.height)
        if h < 200 || w < 170 { return .mini }
        if w >= h * 1.3 && w >= 470 { return .wide }
        if h >= 330 && w >= 230 { return .tall }
        return .compact
    }

    @EnvironmentObject private var timer: FocusTimer
    @EnvironmentObject private var settings: AppSettings
    @State private var isEditingTitle = false
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Pieces every layout shares (the face, controls, phase, tag, corner buttons) glide
    /// between their places when the layout changes, instead of popping.
    @Namespace private var morph

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let layout = Self.layout(for: size)
            Group {
                switch layout {
                case .mini: mini(size)
                case .compact: compact(size)
                case .wide: wide(size)
                case .tall: tall(size)
                }
            }
            .frame(width: size.width, height: size.height)
            // Crossing into another layout animates: shared pieces move, the rest cross-fades.
            .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: layout)
        }
        // While a time is being picked, a click anywhere outside the picker sets it.
        .background {
            if timer.isEditingTime {
                Color.white.opacity(0.001)
                    .onTapGesture { timer.commitTimeEdit() }
            }
        }
        // Drag the panel from anywhere that isn't a control; the first click works even
        // while another app is active.
        .contentShape(Rectangle())
        .contextMenu { menu } // the same commands as ⋯, in every layout
        .gesture(WindowDragGesture())
        .allowsWindowActivationEvents(true)
        .background(theme.panelWash(for: timer.phase))
        .animation(.smooth(duration: 0.5), value: timer.phase)
        .foregroundStyle(.white)
        .onHover { isHovering = $0 }
        .animation(.smooth(duration: 0.3), value: timer.hasStarted)
        .animation(.smooth(duration: 0.3), value: timer.isRunning)
    }

    // MARK: Scales

    /// Transport-control scale tied to the ring, clamped so buttons stay comfortable to hit.
    private func controlScale(for diameter: CGFloat) -> CGFloat {
        min(1.4, max(0.8, diameter / 214))
    }

    /// Header and footer grow gently on big windows so they stay in proportion with the ring.
    private func chromeScale(for size: CGSize) -> CGFloat {
        min(1.5, max(1, min(size.width, size.height) / 420))
    }

    private var menu: PanelMenu { PanelMenu(onRename: { isEditingTitle = true }) }

    private var showsButtons: Bool { isHovering || settings.alwaysShowPanelButtons }

    /// Hide and ⋯ in the panel's top corners, `inset` from the edges.
    private func cornerButtons(scale: CGFloat, inset: CGFloat) -> some View {
        PanelCornerButtons(scale: scale, isVisible: showsButtons, menu: menu)
            .padding(inset)
            .inactiveWhileEditingTime()
            .matchedGeometryEffect(id: Part.cornerButtons, in: morph)
    }

    /// The pieces that move between layouts.
    private enum Part: Hashable {
        case face, controls, phase, tag, cornerButtons
    }

    /// The phase, in a row as tall as the corner buttons and kept clear of them.
    private func phaseRow(scale: CGFloat) -> some View {
        PhaseLabel(scale: scale)
            .frame(maxWidth: .infinity)
            .frame(height: panelButtonSize * scale)
            .padding(.horizontal, (panelButtonSize + 8) * scale)
            .matchedGeometryEffect(id: Part.phase, in: morph)
    }

    // MARK: Layouts

    private func tall(_ size: CGSize) -> some View {
        let chrome = chromeScale(for: size)
        // Vertical budget: padding + header + footer + gaps ≈ 114 × chrome,
        // plus the controls (≈ 0.28 × diameter).
        let diameter = max(130, min(size.width - 48, (size.height - 114 * chrome) / 1.28))
        let scale = controlScale(for: diameter)
        let padding = 14 * chrome
        return VStack(spacing: 0) {
            phaseRow(scale: chrome)
            Spacer(minLength: 8)
            ClockFace(size: diameter, isEditingTitle: $isEditingTitle)
                .matchedGeometryEffect(id: Part.face, in: morph)
            Spacer(minLength: 8)
            TransportControls(scale: scale)
                .inactiveWhileEditingTime()
                .matchedGeometryEffect(id: Part.controls, in: morph)
                .padding(.bottom, 12 * scale)
            TagPicker(scale: chrome)
                .inactiveWhileEditingTime()
                .matchedGeometryEffect(id: Part.tag, in: morph)
        }
        .padding(padding)
        .overlay(alignment: .top) { cornerButtons(scale: chrome, inset: padding) }
    }

    private func compact(_ size: CGSize) -> some View {
        // Vertical budget: padding + gap ≈ 40, plus the controls (≈ 0.28 × diameter).
        let diameter = max(110, min(size.width - 40, (size.height - 40) / 1.28))
        // The corners beside a circle are free; the buttons go there unless the ring
        // fills the window so tightly that they'd touch it (then right-click still works).
        let inset: CGFloat = 10
        let ringCenter = CGPoint(x: size.width / 2, y: max(14, (size.height - 1.28 * diameter) / 2) + diameter / 2)
        let buttonCenter = inset + panelButtonSize / 2
        let cornersFree = hypot(ringCenter.x - buttonCenter, ringCenter.y - buttonCenter)
            >= diameter / 2 + panelButtonSize / 2 + 4
        return VStack(spacing: 12) {
            ClockFace(size: diameter, showsTitle: diameter >= 150, isEditingTitle: $isEditingTitle)
                .matchedGeometryEffect(id: Part.face, in: morph)
            TransportControls(scale: controlScale(for: diameter))
                .inactiveWhileEditingTime()
                .matchedGeometryEffect(id: Part.controls, in: morph)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if cornersFree { cornerButtons(scale: 1, inset: inset) }
        }
    }

    private func wide(_ size: CGSize) -> some View {
        let chrome = chromeScale(for: size)
        let padding = 16 * chrome
        let column = 230 * chrome // room for the header and three controls
        let diameter = max(130, min(size.height - 2 * padding, size.width - 2 * padding - 20 - column))
        let scale = min(controlScale(for: diameter), (size.width - diameter - 2 * padding - 20) / 190)
        return HStack(spacing: 20) {
            ClockFace(size: diameter, isEditingTitle: $isEditingTitle)
                .matchedGeometryEffect(id: Part.face, in: morph)
            VStack(spacing: 10) {
                phaseRow(scale: chrome)
                Spacer(minLength: 0)
                TransportControls(scale: scale)
                    .inactiveWhileEditingTime()
                    .matchedGeometryEffect(id: Part.controls, in: morph)
                Spacer(minLength: 0)
                TagPicker(scale: chrome)
                    .inactiveWhileEditingTime()
                    .matchedGeometryEffect(id: Part.tag, in: morph)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
        }
        .padding(padding)
        // Hide sits in the corner beside the ring, ⋯ above the column of controls.
        .overlay(alignment: .top) { cornerButtons(scale: chrome, inset: padding) }
    }

    /// A single row: Hide, a small ring, the time, the controls (just play when narrow) and ⋯.
    /// Hide and ⋯ keep their places while hidden, so nothing moves when they appear.
    private func mini(_ size: CGSize) -> some View {
        let (w, h) = (size.width, size.height)
        let ringSize = max(20, min(h - 24, 52))
        let showsAllControls = timer.hasStarted && w >= 360
        let buttonScale = min(0.85, max(0.55, h / 110))
        let buttonsWidth = (showsAllControls ? 140 : 48) * buttonScale
        let windowButtonScale: CGFloat = 0.9
        let showsHide = w >= 250 // when narrower, Hide is in ⋯ (and Esc)
        let windowButtonsWidth = (showsHide ? 2 : 1) * (panelButtonSize * windowButtonScale + 10)
        // The time gets the remaining width; ~2.9 em fits "25:00" in rounded monospaced digits.
        let timeWidth = w - 20 - ringSize - buttonsWidth - 24 - windowButtonsWidth
        let fontSize = max(13, min(h * 0.42, 44, timeWidth / 2.9))
        return HStack(spacing: 12) {
            if showsHide {
                PanelHideButton(scale: windowButtonScale, isVisible: showsButtons)
                    .inactiveWhileEditingTime()
                    .padding(.trailing, -2)
            }
            ProgressRing(progress: timer.progress, lineWidth: 3.5)
                .frame(width: ringSize, height: ringSize)
                .matchedGeometryEffect(id: Part.face, in: morph)

            VStack(alignment: .leading, spacing: 0) {
                if timer.isEditingTime {
                    TimePicker(fontSize: fontSize, isCompact: true)
                } else {
                    TimeButton { CountdownText(remaining: timer.remaining, size: fontSize, weight: .medium) }
                        .padding(.leading, -8) // align the digits, not the hover highlight
                }
                if h >= 84 && !timer.isEditingTime {
                    Text(timer.title.isEmpty ? timer.phase.title : timer.title)
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.75)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            TransportControls(scale: buttonScale, playOnly: !showsAllControls)
                .inactiveWhileEditingTime()
                .matchedGeometryEffect(id: Part.controls, in: morph)

            PanelMenuButton(menu: menu, scale: windowButtonScale, isVisible: showsButtons)
                .inactiveWhileEditingTime()
                .padding(.leading, -2)
        }
        .padding(.horizontal, 10)
    }
}
