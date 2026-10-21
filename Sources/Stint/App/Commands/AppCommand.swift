import Foundation

/// Something the app can be asked to do from outside its windows: a `stint://` link, a global
/// shortcut, a notification button or an AppleScript command. Each source turns its input
/// into a command, and `perform(in:)` is the one place commands are carried out, so a new
/// command or source needs no other wiring.
enum AppCommand: Equatable {
    case start, pause, toggle, stop, skip, rewind, newCycle
    case showPanel, hidePanel, togglePanel, showHistory
    case showSettings(SettingsTab?)
    /// Opens the panel's time picker.
    case editTime
    case rename(String)

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
        case .showPanel: app.actions.showPanel()
        case .hidePanel: app.actions.hidePanel()
        case .togglePanel: app.actions.togglePanel()
        case .showHistory: app.actions.showHistory()
        case .showSettings(let tab): app.actions.showSettings(tab)
        case .rename(let title): timer.title = title
        case .editTime:
            app.actions.showPanel()
            timer.beginEditingTime()
        }
    }
}

// MARK: - Sources

extension AppCommand {
    /// A `stint://` link, e.g. `stint://start`, `stint://settings/appearance`,
    /// `stint://name?text=Writing`. Nil for anything else.
    init?(url: URL) {
        guard url.scheme?.lowercased() == "stint", let host = url.host?.lowercased() else { return nil }
        switch host {
        case "start": self = .start
        case "pause": self = .pause
        case "toggle": self = .toggle
        case "stop": self = .stop
        case "skip": self = .skip
        case "rewind": self = .rewind
        case "new-cycle": self = .newCycle
        case "show": self = .showPanel
        case "hide": self = .hidePanel
        case "history": self = .showHistory
        case "set-time": self = .editTime
        case "settings":
            self = .showSettings(url.pathComponents.dropFirst().first.flatMap(SettingsTab.init(rawValue:)))
        case "name":
            let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "text" }?.value
            self = .rename(text ?? "")
        default: return nil
        }
    }

    /// What a global shortcut does.
    init(_ hotkey: HotkeyCommand) {
        switch hotkey {
        case .toggleTimer: self = .toggle
        case .skip: self = .skip
        case .resetCycle: self = .newCycle
        case .togglePanel: self = .togglePanel
        }
    }

    /// What a button on a "session finished" notification does.
    init(_ action: NotificationAction) {
        switch action {
        case .startNext: self = .start
        case .skip: self = .skip
        case .open: self = .showPanel
        }
    }
}
