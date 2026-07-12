import Carbon.HIToolbox

@MainActor
public final class GlobalShortcutRegistration {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: @MainActor () -> Void

    public init?(_ shortcut: Shortcut, action: @escaping @MainActor () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        guard InstallEventHandler(
            GetApplicationEventTarget(),
            globalShortcutCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        ) == noErr else { return nil }
        let identifier = EventHotKeyID(signature: 0x504E_4348, id: UInt32.random(in: 1 ... .max))
        guard RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        ) == noErr else {
            if let eventHandler { RemoveEventHandler(eventHandler) }
            return nil
        }
    }

    public func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKey = nil
        eventHandler = nil
    }

    fileprivate func perform() { action() }
}

private func globalShortcutCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let shortcut = Unmanaged<GlobalShortcutRegistration>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { shortcut.perform() }
    return noErr
}
