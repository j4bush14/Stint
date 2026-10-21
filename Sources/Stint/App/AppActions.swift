import SwiftUI

/// Window-level actions views can ask for, instead of reaching for the app delegate.
/// The app delegate supplies the real ones; the defaults do nothing (tests, previews).
struct AppActions {
    var showPanel: @MainActor () -> Void = {}
    var hidePanel: @MainActor () -> Void = {}
    var togglePanel: @MainActor () -> Void = {}
    /// Makes the timer panel take keyboard input (time picker, title field).
    var focusPanel: @MainActor () -> Void = {}
    var resizePanel: @MainActor (CGSize) -> Void = { _ in }
    var showSettings: @MainActor (SettingsTab?) -> Void = { _ in }
    var showHistory: @MainActor () -> Void = {}
    var closeBreakTakeover: @MainActor () -> Void = {}
    var quit: @MainActor () -> Void = {}
}

extension EnvironmentValues {
    @Entry var appActions = AppActions()
    @Entry var fileDialogs: any FileDialogs = SystemFileDialogs()
    @Entry var focusCoach: any FocusCoach = OnDeviceCoach()
}
