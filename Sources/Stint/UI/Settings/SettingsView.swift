import SwiftUI
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, timer, appearance, alerts, blocking, tags, shortcuts, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "General"
        case .timer: return "Timer"
        case .appearance: return "Appearance"
        case .alerts: return "Alerts & Sounds"
        case .blocking: return "Distraction Blocking"
        case .tags: return "Tags"
        case .shortcuts: return "Shortcuts & Automation"
        case .about: return "About"
        }
    }
    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .timer: return "timer"
        case .appearance: return "paintpalette"
        case .alerts: return "bell.badge"
        case .blocking: return "hand.raised"
        case .tags: return "tag"
        case .shortcuts: return "command"
        case .about: return "info.circle"
        }
    }
}

@MainActor
final class SettingsRouter: ObservableObject {
    @Published var tab: SettingsTab = .general
}

/// Sidebar layout: a floating Liquid Glass sidebar with the selected pane beside it.
struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeModel
    @EnvironmentObject private var router: SettingsRouter
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: Binding(
                get: { router.tab },
                set: { if let tab = $0 { router.tab = tab } }
            )) { tab in
                Label(tab.title, systemImage: tab.symbol)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(210)
        } detail: {
            content(for: router.tab)
                .navigationTitle(router.tab.title)
        }
        .frame(minWidth: 700, minHeight: 540)
        .tint(theme.accent)
    }

    @ViewBuilder
    private func content(for tab: SettingsTab) -> some View {
        switch tab {
        case .general: GeneralPane()
        case .timer: TimerPane()
        case .appearance: AppearancePane()
        case .alerts: AlertsPane()
        case .blocking: BlockingPane()
        case .tags: TagsPane()
        case .shortcuts: ShortcutsPane()
        case .about: AboutPane()
        }
    }
}
