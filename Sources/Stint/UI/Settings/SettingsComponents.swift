import SwiftUI

/// Small secondary text under a settings section.
func footnote(_ text: String) -> some View {
    Text(text).font(.caption).foregroundStyle(.secondary)
}

/// A settings row with its label on the left and the value plus a stepper on the right,
/// matching how System Settings lays out numeric options.
struct StepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: String?

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Text(unit.map { "\(value) \($0)" } ?? "\(value)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Stepper(title, value: $value, in: range)
                    .labelsHidden()
                    .testTarget("stepper.\(title)", value: "\(value)")
            }
        }
    }
}

/// A switch for one setting. Tests find it as `toggle.<id>`.
struct SettingToggle: View {
    let title: String
    @Binding var isOn: Bool
    let id: String

    init(_ title: String, isOn: Binding<Bool>, id: String) {
        self.title = title
        _isOn = isOn
        self.id = id
    }

    var body: some View {
        Toggle(title, isOn: $isOn)
            .testTarget("toggle.\(id)", value: isOn ? "on" : "off")
    }
}
