import AppKit
import Combine
import SwiftUI

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        app.run()
    }
}

/// Builds the app (the composition root) and connects timer events to the services that
/// react to them. Everything is created here and handed down; nothing reaches back up.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let app = AppEnvironment.live()
    private var windows: WindowPresenter!
    private var statusItem: StatusItemController!
    private var panel: TimerPanelController!
    private var notifier: Notifier!
    private var appBlocker: AppBlocker!
    private var webBlocker: WebBlocker!
    private var hotkeys: Hotkeys!
    private var cancellables = Set<AnyCancellable>()

    private var timer: FocusTimer { app.timer }
    private var settings: AppSettings { app.settings }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppEnvironment.scripting = app
        windows = WindowPresenter(app: app)
        app.actions = makeActions()

        NSApp.mainMenu = MainMenu.make(settingsTarget: self, settingsAction: #selector(openSettings))
        settings.didChange
            .sink { [weak self] in self?.applyAppearance() }
            .store(in: &cancellables)
        applyAppearance()

        statusItem = StatusItemController(timer: timer, store: app.store, settings: settings, theme: app.theme) { [unowned self] in
            app.actions
        }
        panel = TimerPanelController(app: app) { [unowned self] in statusItem.buttonFrameOnScreen }
        startServices()
        connectTimerEvents()

        // Give the menu bar a moment to lay out the status item so the panel can anchor to it.
        if settings.showWindowAtLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.panel.show() }
        }
        if settings.startTimerAtLaunch { timer.start() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            (AppCommand(url: url) ?? .showPanel).perform(in: app)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer.saveIncompleteSession()
    }

    // MARK: Wiring

    private func makeActions() -> AppActions {
        AppActions(
            showPanel: { [unowned self] in panel.show() },
            hidePanel: { [unowned self] in panel.hide() },
            togglePanel: { [unowned self] in panel.toggle() },
            focusPanel: { [unowned self] in panel.focus() },
            resizePanel: { [unowned self] size in panel.resize(to: size) },
            showSettings: { [unowned self] tab in windows.showSettings(tab: tab) },
            showHistory: { [unowned self] in windows.showHistory() },
            closeBreakTakeover: { [unowned self] in windows.closeBreakTakeover() },
            quit: { NSApp.terminate(nil) }
        )
    }

    private func startServices() {
        notifier = Notifier(settings: settings, store: app.store, coach: app.coach) { [unowned self] action in
            AppCommand(action).perform(in: app)
        }
        notifier.start()
        appBlocker = AppBlocker(settings: settings, timer: timer) { [unowned self] name in
            notifier.blocked(appName: name)
        }
        appBlocker.start()
        webBlocker = WebBlocker(settings: settings, timer: timer, dataDirectory: SessionStore.defaultDirectory)
        webBlocker.start()
        hotkeys = Hotkeys(settings: settings) { [unowned self] hotkey in
            AppCommand(hotkey).perform(in: app)
        }
        hotkeys.start()
        if settings.syncWithCalendar { app.calendar.reloadCalendars() }
    }

    /// What happens around the app when the timer changes phase, starts or ticks.
    private func connectTimerEvents() {
        timer.onPhaseCompleted = { [unowned self] session in
            notifier.phaseCompleted(session, next: timer.phase)
            app.calendar.add(session)
        }
        timer.onStart = { [unowned self] in
            guard timer.phase == .focus else { return }
            if settings.hideWindowOnTimerStart { panel.hide() }
            appBlocker.checkFrontmost()
        }
        timer.onSecond = { [unowned self] in
            if settings.tickingSound && timer.phase == .focus { Sounds.tick() }
        }
        timer.onPhaseChanged = { [unowned self] phase in
            if phase.isBreak && settings.fullscreenBreak {
                windows.showBreakTakeover()
            } else if phase == .focus {
                windows.closeBreakTakeover()
            }
        }
    }

    private func applyAppearance() {
        NSApp.appearance = switch settings.appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    @objc private func openSettings() { windows.showSettings(tab: nil) }
}
