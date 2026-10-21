import Combine
import Foundation

/// An object whose `@Pref` properties are stored in `defaults`.
@MainActor
protocol PreferenceStore: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    var defaults: UserDefaults { get }
}

extension PreferenceStore {
    /// Fires after any setting changes, so subscribers read the new values. (`objectWillChange`
    /// fires before the change; this delivers it on the next pass of the main run loop.)
    var didChange: AnyPublisher<Void, Never> {
        objectWillChange.receive(on: RunLoop.main).eraseToAnyPublisher()
    }
}

/// A UserDefaults-backed property for `PreferenceStore` classes that publishes
/// `objectWillChange` on every write (unlike `@AppStorage`, which only works in views).
@propertyWrapper
struct Pref<Value> {
    private let key: String
    private let defaultValue: Value
    private let decode: (Any) -> Value?
    private let encode: (Value) -> Any

    init(wrappedValue: Value, _ key: String) where Value == Int {
        self.init(key, wrappedValue, decode: { $0 as? Int }, encode: { $0 })
    }

    init(wrappedValue: Value, _ key: String) where Value == Bool {
        self.init(key, wrappedValue, decode: { $0 as? Bool }, encode: { $0 })
    }

    init(wrappedValue: Value, _ key: String) where Value == Double {
        self.init(key, wrappedValue, decode: { $0 as? Double }, encode: { $0 })
    }

    init(wrappedValue: Value, _ key: String) where Value == String {
        self.init(key, wrappedValue, decode: { $0 as? String }, encode: { $0 })
    }

    init(wrappedValue: Value, _ key: String) where Value: RawRepresentable, Value.RawValue == String {
        self.init(key, wrappedValue, decode: { ($0 as? String).flatMap(Value.init(rawValue:)) }, encode: { $0.rawValue })
    }

    private init(_ key: String, _ defaultValue: Value, decode: @escaping (Any) -> Value?, encode: @escaping (Value) -> Any) {
        self.key = key
        self.defaultValue = defaultValue
        self.decode = decode
        self.encode = encode
    }

    @MainActor static subscript<T: PreferenceStore>(
        _enclosingInstance object: T,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<T, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<T, Pref<Value>>
    ) -> Value {
        get {
            let pref = object[keyPath: storageKeyPath]
            return object.defaults.object(forKey: pref.key).flatMap(pref.decode) ?? pref.defaultValue
        }
        set {
            object.objectWillChange.send()
            let pref = object[keyPath: storageKeyPath]
            object.defaults.set(pref.encode(newValue), forKey: pref.key)
        }
    }

    @available(*, unavailable, message: "@Pref can only be used inside PreferenceStore classes")
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }
}
