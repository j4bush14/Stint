import SwiftUI

/// Picks a time with columns for minutes and seconds (and hours past 60 minutes).
/// Each column changes with its arrows, the scroll wheel or trackpad, a vertical drag, or
/// the ↑/↓ keys (←/→ switch columns). Return or clicking outside sets it; Esc cancels.
struct TimePicker: View {
    @EnvironmentObject private var theme: ThemeModel
    let fontSize: CGFloat
    /// Hides the arrows and presets where space is tight (the mini bar).
    var isCompact = false

    @EnvironmentObject private var timer: FocusTimer
    @FocusState private var isFocused: Bool
    @State private var selected: Unit = .minutes
    @State private var dragSteps = 0

    enum Unit: CaseIterable, Identifiable {
        case hours, minutes, seconds
        var id: Self { self }
        var step: TimeInterval {
            switch self {
            case .hours: 3600
            case .minutes: 60
            case .seconds: 1
            }
        }
        var name: String {
            switch self {
            case .hours: "hours"
            case .minutes: "minutes"
            case .seconds: "seconds"
            }
        }
    }

    nonisolated static let presetMinutes = [5, 15, 25, 45, 60]

    private var units: [Unit] {
        timer.timeDraft >= 3600 ? [.hours, .minutes, .seconds] : [.minutes, .seconds]
    }

    var body: some View {
        VStack(spacing: fontSize * 0.18) {
            HStack(spacing: fontSize * 0.04) {
                ForEach(units) { unit in
                    if unit != units.first {
                        Text(":")
                            .font(.system(size: fontSize, weight: .light, design: .rounded))
                            .opacity(0.6)
                    }
                    column(unit)
                }
            }
            if !isCompact {
                presets
            }
        }
        .testTarget("picker", value: TimeFormat.clock(timer.timeDraft))
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { nudge(selected, by: 1); return .handled }
        .onKeyPress(.downArrow) { nudge(selected, by: -1); return .handled }
        .onKeyPress(.leftArrow) { moveSelection(by: -1); return .handled }
        .onKeyPress(.rightArrow) { moveSelection(by: 1); return .handled }
        .onKeyPress(.return) { timer.commitTimeEdit(); return .handled }
        .onKeyPress(.escape) { timer.cancelTimeEdit(); return .handled }
        .onAppear { isFocused = true }
        .onChange(of: units) { _, newUnits in
            if !newUnits.contains(selected) { selected = .minutes }
        }
    }

    // MARK: Columns

    private func column(_ unit: Unit) -> some View {
        VStack(spacing: 0) {
            if !isCompact { arrow("chevron.up", unit: unit, by: 1) }
            Text(String(format: "%02d", value(of: unit)))
                .font(.system(size: fontSize, weight: .light, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .fixedSize() // never truncate while other views animate around it
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: value(of: unit))
                .padding(.horizontal, fontSize * 0.08)
                .background {
                    RoundedRectangle(cornerRadius: fontSize * 0.18, style: .continuous)
                        .fill(.white.opacity(selected == unit && isFocused ? 0.14 : 0))
                }
                .contentShape(Rectangle())
                .onTapGesture { selected = unit }
                .gesture(dragToAdjust(unit))
                .onScrollWheel { steps in
                    selected = unit
                    nudge(unit, by: steps)
                }
                .testTarget("picker.\(unit.name)", value: String(value(of: unit)))
            if !isCompact { arrow("chevron.down", unit: unit, by: -1) }
        }
        .accessibilityElement()
        .accessibilityLabel(unit.name)
        .accessibilityValue("\(value(of: unit))")
        .accessibilityAdjustableAction { direction in
            nudge(unit, by: direction == .increment ? 1 : -1)
        }
    }

    private func arrow(_ symbol: String, unit: Unit, by steps: Int) -> some View {
        Button {
            selected = unit
            nudge(unit, by: steps)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: fontSize * 0.26, weight: .semibold))
                .frame(width: fontSize * 0.9, height: fontSize * 0.36)
                .contentShape(Rectangle())
        }
        .buttonStyle(HoverHighlightStyle())
        .buttonRepeatBehavior(.enabled) // hold to keep changing
        .accessibilityLabel("\(steps > 0 ? "More" : "Fewer") \(unit.name)")
        .testTarget("picker.\(unit.name).\(steps > 0 ? "up" : "down")")
    }

    /// Drag up to increase, down to decrease: one step per 12 points.
    private func dragToAdjust(_ unit: Unit) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                let steps = Int(-value.translation.height / 12)
                if steps != dragSteps {
                    nudge(unit, by: steps - dragSteps)
                    dragSteps = steps
                }
                selected = unit
            }
            .onEnded { _ in dragSteps = 0 }
    }

    private var presets: some View {
        let chip = max(26, fontSize * 0.68)
        return HStack(spacing: max(5, fontSize * 0.12)) {
            ForEach(Self.presetMinutes, id: \.self) { minutes in
                let isCurrent = timer.timeDraft == TimeInterval(minutes * 60)
                Button { timer.setTimeDraft(TimeInterval(minutes * 60)) } label: {
                    Text("\(minutes)")
                        .font(.system(size: max(11, chip * 0.42), weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(isCurrent ? theme.color(for: timer.phase) : .white)
                        .frame(width: chip, height: chip) // inside the label, so the glass fills the chip
                }
                .buttonStyle(PanelGlassButtonStyle(prominent: isCurrent))
                    .testTarget("picker.preset.\(minutes)")
                    .help("\(minutes) minutes")
                    .accessibilityLabel("\(minutes) minutes")
            }
        }
        .fixedSize()
    }

    // MARK: Values

    private func value(of unit: Unit) -> Int {
        let total = Int(timer.timeDraft)
        switch unit {
        case .hours: return total / 3600
        case .minutes: return units.contains(.hours) ? (total % 3600) / 60 : total / 60
        case .seconds: return total % 60
        }
    }

    private func nudge(_ unit: Unit, by steps: Int) {
        guard steps != 0 else { return }
        timer.setTimeDraft(timer.timeDraft + TimeInterval(steps) * unit.step)
    }

    private func moveSelection(by offset: Int) {
        guard let index = units.firstIndex(of: selected) else { return }
        selected = units[min(max(0, index + offset), units.count - 1)]
    }
}
