import AppKit

/// Hides blocked apps when they come to the front during a focus session.
@MainActor
final class AppBlocker {
    /// Apps that are never blocked in allow-list mode.
    nonisolated static let essentials: Set<String> = [
        "com.apple.finder", "com.apple.systempreferences", "com.apple.loginwindow",
        "com.apple.dock", "com.apple.controlcenter", "com.apple.Spotlight",
    ]

    private let settings: AppSettings
    private let timer: FocusTimer
    private let onBlocked: (_ appName: String) -> Void
    private var observation: NotificationCenter.ObservationToken?

    init(settings: AppSettings, timer: FocusTimer, onBlocked: @escaping (_ appName: String) -> Void) {
        self.settings = settings
        self.timer = timer
        self.onBlocked = onBlocked
    }

    func start() {
        // Typed, main-actor workspace message (no userInfo dictionary digging).
        observation = NSWorkspace.shared.notificationCenter.addObserver(
            of: NSWorkspace.shared, for: .didActivateApplication
        ) { [weak self] message in
            self?.check(message.application)
        }
    }

    /// Called when a focus session starts, to catch the app that's already in front.
    func checkFrontmost() {
        if let app = NSWorkspace.shared.frontmostApplication { check(app) }
    }

    /// Whether an app should be hidden, given the list and its mode. Pure, for testing.
    nonisolated static func isBlocked(_ bundleID: String, list: [String], mode: BlockListMode) -> Bool {
        let listed = list.contains(bundleID)
        return mode == .block ? listed : (!listed && !essentials.contains(bundleID))
    }

    private func check(_ app: NSRunningApplication) {
        guard settings.appBlocking, timer.isFocusing,
              let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier,
              Self.isBlocked(id, list: settings.blockedApps, mode: settings.appListMode) else { return }
        app.hide()
        onBlocked(app.localizedName ?? id)
    }
}
