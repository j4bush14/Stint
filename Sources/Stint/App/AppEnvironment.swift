import SwiftUI

/// The composition root: builds the app's models and services once and hands them to
/// views (through the SwiftUI environment) and to services (through their initializers).
/// Nothing else creates or looks up these objects, so each can be replaced in tests.
@MainActor
final class AppEnvironment {
    let settings: AppSettings
    let store: SessionStore
    let timer: FocusTimer
    let wallpaper: WallpaperColors
    let theme: ThemeModel
    let calendar: CalendarSync
    let router = SettingsRouter()
    let coach: any FocusCoach
    let fileDialogs: any FileDialogs
    /// Window-level actions; the app delegate fills these in once its windows exist.
    var actions = AppActions()

    init(settings: AppSettings, store: SessionStore, timer: FocusTimer,
         coach: any FocusCoach, fileDialogs: any FileDialogs) {
        self.settings = settings
        self.store = store
        self.timer = timer
        self.coach = coach
        self.fileDialogs = fileDialogs
        wallpaper = WallpaperColors(settings: settings)
        theme = ThemeModel(settings: settings, wallpaper: wallpaper)
        calendar = CalendarSync(settings: settings, store: store)
    }

    /// The real app: user defaults, Application Support, Apple Intelligence, system dialogs.
    static func live() -> AppEnvironment {
        let settings = AppSettings()
        let store = SessionStore(directory: SessionStore.defaultDirectory)
        let timer = FocusTimer(settings: settings, store: store, state: .standard)
        return AppEnvironment(settings: settings, store: store, timer: timer,
                              coach: OnDeviceCoach(), fileDialogs: SystemFileDialogs())
    }

    /// Set at launch. Only AppleScript commands read it: AppKit creates those objects itself,
    /// so they can't be handed their dependencies like everything else.
    static var scripting: AppEnvironment?
}

extension View {
    /// Supplies every model and service a Stint view may need.
    func appEnvironment(_ app: AppEnvironment) -> some View {
        environmentObject(app.settings)
            .environmentObject(app.store)
            .environmentObject(app.timer)
            .environmentObject(app.wallpaper)
            .environmentObject(app.theme)
            .environmentObject(app.calendar)
            .environmentObject(app.router)
            .environment(\.appActions, app.actions)
            .environment(\.fileDialogs, app.fileDialogs)
            .environment(\.focusCoach, app.coach)
    }
}
