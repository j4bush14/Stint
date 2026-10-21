import Foundation

/// A `stint://` link, e.g. `stint://start`, `stint://settings/appearance`, `stint://name?text=Writing`.
enum URLCommand: Equatable {
    case start, pause, toggle, stop, skip, rewind, newCycle, show, hide, history, setTime
    case settings(SettingsTab?)
    case name(String)

    init?(_ url: URL) {
        guard url.scheme?.lowercased() == "stint", let host = url.host?.lowercased() else { return nil }
        switch host {
        case "start": self = .start
        case "pause": self = .pause
        case "toggle": self = .toggle
        case "stop": self = .stop
        case "skip": self = .skip
        case "rewind": self = .rewind
        case "new-cycle": self = .newCycle
        case "show": self = .show
        case "hide": self = .hide
        case "history": self = .history
        case "set-time": self = .setTime
        case "settings":
            self = .settings(url.pathComponents.dropFirst().first.flatMap(SettingsTab.init(rawValue:)))
        case "name":
            let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "text" }?.value
            self = .name(text ?? "")
        default: return nil
        }
    }

    @MainActor
    func perform(in app: AppEnvironment) {
        let timer = app.timer
        switch self {
        case .start: timer.start()
        case .pause: timer.pause()
        case .toggle: timer.toggle()
        case .stop: timer.stop()
        case .skip: timer.skip()
        case .rewind: timer.previous()
        case .newCycle: timer.resetCycle()
        case .show: app.actions.showPanel()
        case .hide: app.actions.hidePanel()
        case .history: app.actions.showHistory()
        case .settings(let tab): app.actions.showSettings(tab)
        case .name(let text): timer.title = text
        case .setTime:
            app.actions.showPanel()
            timer.beginEditingTime()
        }
    }
}
