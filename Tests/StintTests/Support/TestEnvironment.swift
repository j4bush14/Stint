import Foundation
@testable import Stint

/// A clock the tests move by hand.
final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    func advance(_ seconds: TimeInterval) { now += seconds }
}

/// Isolated settings, store and timer state for one test, cleaned up afterwards.
/// Nothing here touches the user's real preferences or history.
@MainActor
final class TestEnvironment {
    let settings: AppSettings
    let store: SessionStore
    let state: UserDefaults
    let clock = TestClock()
    let directory: URL

    private let settingsSuite = "stint-tests-settings-\(UUID().uuidString)"
    private let stateSuite = "stint-tests-state-\(UUID().uuidString)"

    init() {
        settings = AppSettings(defaults: UserDefaults(suiteName: settingsSuite)!)
        state = UserDefaults(suiteName: stateSuite)!
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("stint-tests-\(UUID().uuidString)", isDirectory: true)
        store = SessionStore(directory: directory)
    }

    /// A timer driven by `clock` that only ticks when the test calls `tick()`.
    func makeTimer() -> FocusTimer {
        let clock = clock
        return FocusTimer(settings: settings, store: store, state: state,
                          now: { clock.now }, schedulesTicks: false)
    }

    /// A full app built from this environment, with fakes for the AI coach and file dialogs.
    func makeApp(coach: any FocusCoach = FakeCoach(), fileDialogs: any FileDialogs = FakeFileDialogs()) -> AppEnvironment {
        AppEnvironment(settings: settings, store: store, timer: makeTimer(), coach: coach, fileDialogs: fileDialogs)
    }

    /// Advances the clock and lets the timer react, as the run-loop timer would.
    func run(_ timer: FocusTimer, for seconds: TimeInterval) {
        clock.advance(seconds)
        timer.tick()
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: settingsSuite)
        UserDefaults().removePersistentDomain(forName: stateSuite)
        try? FileManager.default.removeItem(at: directory)
    }
}
