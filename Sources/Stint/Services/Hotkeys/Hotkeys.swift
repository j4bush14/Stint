import AppKit
import Carbon.HIToolbox
import Combine

/// Registers the global shortcuts with Carbon while the setting is on, and reports presses.
@MainActor
final class Hotkeys {
    private static let modifiers = UInt32(controlKey | optionKey | cmdKey)
    private static let signature = OSType(0x5354_4E54) // 'STNT'

    private let settings: AppSettings
    private let perform: (HotkeyCommand) -> Void
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var cancellable: AnyCancellable?

    init(settings: AppSettings, perform: @escaping (HotkeyCommand) -> Void) {
        self.settings = settings
        self.perform = perform
    }

    func start() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // Carbon calls back with a C function; `self` travels in the user-data pointer.
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard let context, let command = HotkeyCommand(rawValue: hotKeyID.id) else { return noErr }
            nonisolated(unsafe) let pointer = context
            DispatchQueue.main.async {
                Unmanaged<Hotkeys>.fromOpaque(pointer).takeUnretainedValue().perform(command)
            }
            return noErr
        }, 1, &spec, context, &handler)

        cancellable = settings.didChange
            .sink { [weak self] in self?.sync() }
        sync()
    }

    private func sync() {
        if settings.globalHotkeys && refs.isEmpty {
            for command in HotkeyCommand.allCases {
                var ref: EventHotKeyRef?
                let id = EventHotKeyID(signature: Self.signature, id: command.rawValue)
                if RegisterEventHotKey(UInt32(command.keyCode), Self.modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr,
                   let ref {
                    refs.append(ref)
                }
            }
        } else if !settings.globalHotkeys && !refs.isEmpty {
            refs.forEach { UnregisterEventHotKey($0) }
            refs.removeAll()
        }
    }
}
