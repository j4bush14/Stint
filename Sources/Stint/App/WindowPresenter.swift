import AppKit
import SwiftUI

/// Opens and reuses the app's secondary windows: Settings, History and the break takeover.
@MainActor
final class WindowPresenter {
    private let app: AppEnvironment
    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?
    private var takeoverWindow: NSWindow?

    init(app: AppEnvironment) {
        self.app = app
    }

    func showSettings(tab: SettingsTab?) {
        if let tab { app.router.tab = tab }
        settingsWindow = present(settingsWindow, title: "Settings", root: SettingsView())
    }

    func showHistory() {
        historyWindow = present(historyWindow, title: "History", root: HistoryView())
    }

    func showBreakTakeover() {
        guard takeoverWindow == nil, let screen = NSScreen.main else { return }
        let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .modalPanel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentViewController = NSHostingController(rootView: BreakTakeoverView().appEnvironment(app))
        window.setFrame(screen.frame, display: true)
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.animator().alphaValue = 1
        takeoverWindow = window
    }

    func closeBreakTakeover() {
        takeoverWindow?.orderOut(nil)
        takeoverWindow = nil
    }

    private func present<V: View>(_ existing: NSWindow?, title: String, root: V) -> NSWindow {
        let window = existing ?? {
            let hosting = NSHostingController(rootView: root.appEnvironment(app))
            // Let SwiftUI's .toolbar and .navigationTitle drive the window's glass toolbar.
            hosting.sceneBridgingOptions = [.toolbars, .title]
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.toolbarStyle = .unified
            window.title = title
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName(title)
            window.center()
            return window
        }()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        return window
    }
}
