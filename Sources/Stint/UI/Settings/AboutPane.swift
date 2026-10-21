import AppKit
import SwiftUI

/// App name, version and where data is stored.
struct AboutPane: View {
    @EnvironmentObject private var store: SessionStore
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stint").font(.title3.bold())
                        Text("A focus timer for the menu bar.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                LabeledContent("Version", value: version)
            }
            Section {
                LabeledContent("History and tags") {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.directory])
                    }
                }
            } footer: {
                footnote("Everything Stint records stays on this Mac.")
            }
        }
        .formStyle(.grouped)
    }
}
