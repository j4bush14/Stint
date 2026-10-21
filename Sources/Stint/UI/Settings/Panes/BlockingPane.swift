import AppKit
import SwiftUI

/// App and website blocking during focus sessions.
struct BlockingPane: View {
    @Environment(\.fileDialogs) private var fileDialogs
    @EnvironmentObject private var s: AppSettings
    @State private var newSite = ""

    var body: some View {
        Form {
            Section {
                SettingToggle("Block apps while focusing", isOn: $s.appBlocking, id: "appBlocking")
                Picker("Mode", selection: $s.appListMode) {
                    ForEach(BlockListMode.allCases) { Text($0.label).tag($0) }
                }
                .testTarget("blocking.appMode", value: s.appListMode.rawValue)
                ForEach(s.blockedApps, id: \.self) { id in
                    HStack {
                        appIcon(id)
                        Text(appName(id))
                        Spacer()
                        Button { s.blockedApps.removeAll { $0 == id } } label: { Image(systemName: "minus.circle.fill") }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Remove \(appName(id))")
                            .testTarget("blocking.removeApp.\(id)")
                    }
                }
                Button("Choose Apps…", systemImage: "plus", action: addApp)
                    .testTarget("blocking.chooseApps")
            } header: {
                Text("Apps")
            } footer: {
                footnote(s.appListMode == .block
                         ? "Listed apps are hidden as soon as they come to the front during a focus session."
                         : "During a focus session, only the listed apps (plus Finder) can come to the front.")
            }

            Section {
                SettingToggle("Block websites while focusing", isOn: $s.webBlocking, id: "webBlocking")
                Picker("Mode", selection: $s.webListMode) {
                    ForEach(BlockListMode.allCases) { Text($0.label).tag($0) }
                }
                .testTarget("blocking.webMode", value: s.webListMode.rawValue)
                ForEach(s.blockedSites, id: \.self) { site in
                    HStack {
                        Text(site).font(.body.monospaced())
                        Spacer()
                        Button { s.blockedSites.removeAll { $0 == site } } label: { Image(systemName: "minus.circle.fill") }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Remove \(site)")
                            .testTarget("blocking.remove.\(site)")
                    }
                }
                HStack {
                    TextField("Site or keyword", text: $newSite)
                        .onSubmit(addSite)
                        .testTarget("blocking.siteField")
                    Button("Add", action: addSite).disabled(newSite.trimmingCharacters(in: .whitespaces).isEmpty)
                        .testTarget("blocking.addSite")
                }
            } header: {
                Text("Websites")
            } footer: {
                footnote("""
                A rule matches any address containing it, so "reddit" covers every Reddit page. \
                Start a rule with = to match one exact address prefix instead, e.g. =https://www.youtube.com/watch. \
                Works in Safari, Chrome, Arc, Brave, Edge and Vivaldi; macOS asks once for permission per browser. \
                Breaks and paused sessions are never blocked.
                """)
            }
        }
        .formStyle(.grouped)
    }

    private func addSite() {
        let site = newSite.trimmingCharacters(in: .whitespaces)
        guard !site.isEmpty, !s.blockedSites.contains(site) else { return }
        s.blockedSites.append(site)
        newSite = ""
    }

    private func addApp() {
        for url in fileDialogs.chooseApplications() {
            if let id = Bundle(url: url)?.bundleIdentifier, !s.blockedApps.contains(id) {
                s.blockedApps.append(id)
            }
        }
    }

    private func appName(_ id: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func appIcon(_ id: String) -> some View {
        let image = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            .map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!
        return Image(nsImage: image).resizable().frame(width: 18, height: 18)
    }
}
