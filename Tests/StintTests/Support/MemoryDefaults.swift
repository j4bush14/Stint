import Foundation

/// UserDefaults kept in memory, so tests leave nothing in ~/Library/Preferences.
///
/// A suite on disk can't be cleaned up reliably: removing it at the end of a test is undone
/// by any later write, and views the UI tests keep alive (see `UIHarness`) still write
/// settings after their test has finished. This covers the calls the app makes; anything
/// else goes to the test runner's own domain, never to Stint's.
final class MemoryDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    init() {
        super.init(suiteName: nil)!
    }

    override func object(forKey key: String) -> Any? {
        lock.withLock { values[key] }
    }

    override func set(_ value: Any?, forKey key: String) {
        lock.withLock { values[key] = value }
    }

    override func removeObject(forKey key: String) {
        set(nil, forKey: key)
    }

    override func set(_ value: Int, forKey key: String) { set(value as Any?, forKey: key) }
    override func set(_ value: Bool, forKey key: String) { set(value as Any?, forKey: key) }
    override func set(_ value: Double, forKey key: String) { set(value as Any?, forKey: key) }

    override func string(forKey key: String) -> String? { object(forKey: key) as? String }
    override func integer(forKey key: String) -> Int { object(forKey: key) as? Int ?? 0 }
    override func bool(forKey key: String) -> Bool { object(forKey: key) as? Bool ?? false }
    override func double(forKey key: String) -> Double { object(forKey: key) as? Double ?? 0 }
}
