import AppKit
import SwiftUI

/// Shows a pop-up menu. The app pops it up for real; tests substitute one that keeps the
/// menu so they can choose from it (AppKit's menu loop can't run inside a test).
struct MenuPresenter: Sendable {
    let present: @MainActor (_ menu: NSMenu, _ location: NSPoint, _ view: NSView) -> Void

    static let system = MenuPresenter { menu, location, view in
        menu.popUp(positioning: nil, at: location, in: view)
    }
}

extension EnvironmentValues {
    @Entry var menuPresenter = MenuPresenter.system
}
