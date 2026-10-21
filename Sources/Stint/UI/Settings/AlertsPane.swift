import AppKit
import SwiftUI

/// Notifications, on-device encouragement and sounds.
struct AlertsPane: View {
    @Environment(\.focusCoach) private var coach
    @EnvironmentObject private var s: AppSettings

    var body: some View {
        Form {
            Section {
                SettingToggle("Notify when a session ends", isOn: $s.allowNotifications, id: "allowNotifications")
                Picker("Message", selection: $s.notificationMessage) {
                    ForEach(NotificationMessage.allCases) { Text($0.label).tag($0) }
                }
                .disabled(!s.allowNotifications)
                .testTarget("alerts.message", value: s.notificationMessage.rawValue)
                Button("Notification Settings…") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                }
            } header: {
                Text("Notifications")
            } footer: {
                if s.notificationMessage == .encouragement {
                    footnote(coach.unavailableReason.map { "\($0) Until then, a quote is shown." }
                             ?? "Written on this Mac by the on-device model. Nothing leaves your computer.")
                }
            }
            Section("Sounds") {
                soundPicker("Focus finished", selection: $s.focusCompleteSound)
                soundPicker("Break finished", selection: $s.breakCompleteSound)
                LabeledContent("Volume") {
                    Slider(value: $s.notificationsVolume, in: 0...1) { _ in }
                        .testTarget("alerts.volume", value: String(format: "%.2f", s.notificationsVolume))
                        .frame(width: 180)
                }
                SettingToggle("Soft tick while focusing", isOn: $s.tickingSound, id: "tickingSound")
            }
        }
        .formStyle(.grouped)
    }

    private func soundPicker(_ title: String, selection: Binding<String>) -> some View {
        HStack {
            Picker(title, selection: selection) {
                ForEach(Sounds.names, id: \.self) { Text($0).tag($0) }
            }
            .testTarget("alerts.sound.\(title)", value: selection.wrappedValue)
            Button { Sounds.play(selection.wrappedValue, volume: s.notificationsVolume) } label: { Image(systemName: "speaker.wave.2.fill") }
                .buttonStyle(.borderless)
                .help("Preview")
        }
    }
}
