import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) { self.action = action }

    func setEnabled(_ enabled: Bool) throws {
        if !enabled {
            if let hotKey { UnregisterEventHotKey(hotKey) }
            hotKey = nil
            if let handler { RemoveEventHandler(handler) }
            handler = nil
            return
        }
        guard hotKey == nil else { return }
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue().action()
            }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let registered = installed == noErr ? RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(cmdKey | optionKey),
            EventHotKeyID(signature: 0x44534C50, id: 1), GetApplicationEventTarget(), 0, &hotKey) : installed
        guard registered == noErr else {
            try setEnabled(false)
            throw SleepControlError.commandFailed(AppLanguage.current.text("无法注册 ⌥⌘S，可能已被其他应用占用。", "Could not register ⌥⌘S. Another app may be using it."))
        }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
