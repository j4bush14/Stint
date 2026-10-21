import SwiftUI

/// Global hotkeys and the AppleScript / URL automation reference.
struct ShortcutsPane: View {
    @EnvironmentObject private var s: AppSettings

    var body: some View {
        Form {
            Section {
                SettingToggle("Enable system-wide shortcuts", isOn: $s.globalHotkeys, id: "globalHotkeys")
                ForEach(HotkeyCommand.allCases, id: \.id) { sc in
                    LabeledContent(sc.name) {
                        Text(sc.display).font(.body.monospaced()).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Keyboard")
            } footer: {
                footnote("These work from any app. In the timer window, Space starts and pauses.")
            }
            Section {
                Text("""
                tell application "Stint" to begin
                tell application "Stint" to name session "Writing"
                open "stint://skip"
                """)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            } header: {
                Text("AppleScript & URLs")
            } footer: {
                footnote("Scripting commands: begin, halt, advance, rewind, new cycle, reveal, conceal, current phase, time left, session name, name session. Use them from Shortcuts with “Run AppleScript”, or call stint:// links.")
            }
        }
        .formStyle(.grouped)
    }
}
