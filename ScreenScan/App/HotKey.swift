import AppKit
import Carbon.HIToolbox

/// A system-wide hot key registered through Carbon's `RegisterEventHotKey`.
///
/// `NSEvent.addGlobalMonitorForEvents` is the obvious alternative, but it requires the
/// Accessibility permission and cannot consume the keystroke — the shortcut would also be
/// delivered to whichever app is frontmost. Carbon needs no permission and swallows it.
@MainActor
final class HotKey {
    enum Failure: Error {
        case eventHandlerInstallFailed(OSStatus)
        case registrationFailed(OSStatus)
    }

    /// ⌃⌥Q. Hardcoded — a configuration UI is explicitly out of v1 scope.
    static let defaultKeyCode = UInt32(kVK_ANSI_Q)
    static let defaultModifiers = UInt32(controlKey | optionKey)
    static let defaultDisplayString = "⌃⌥Q"

    private let identifier: UInt32
    private var reference: EventHotKeyRef?

    init(keyCode: UInt32 = HotKey.defaultKeyCode,
         modifiers: UInt32 = HotKey.defaultModifiers,
         action: @escaping () -> Void) throws {
        try HotKey.installSharedEventHandler()

        identifier = hotKeyNextIdentifier
        hotKeyNextIdentifier += 1

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: identifier)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode,
                                         modifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &reference)
        guard status == noErr, let reference else {
            throw Failure.registrationFailed(status)
        }

        self.reference = reference
        hotKeyActions[identifier] = action
    }

    // `isolated` so teardown runs on the main actor, like every other access to the
    // Carbon reference and the action registry.
    isolated deinit {
        if let reference {
            UnregisterEventHotKey(reference)
        }
        hotKeyActions[identifier] = nil
    }

    private static func installSharedEventHandler() throws {
        guard hotKeyEventHandler == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        var handler: EventHandlerRef?
        let status = InstallEventHandler(GetApplicationEventTarget(),
                                         hotKeyEventCallback,
                                         1,
                                         &eventType,
                                         nil,
                                         &handler)
        guard status == noErr else {
            throw Failure.eventHandlerInstallFailed(status)
        }
        hotKeyEventHandler = handler
    }
}

// MARK: - Carbon bridging
//
// The Carbon callback is a C function pointer and therefore cannot capture context, so the
// registry has to live at file scope. Every one of these is touched only from the main
// thread: `HotKey` is `@MainActor`, and Carbon delivers hot key events on the main thread
// through the application event target.

private let hotKeySignature: OSType = 0x5353_434E // 'SSCN'
private nonisolated(unsafe) var hotKeyNextIdentifier: UInt32 = 1
private nonisolated(unsafe) var hotKeyActions: [UInt32: () -> Void] = [:]
private nonisolated(unsafe) var hotKeyEventHandler: EventHandlerRef?

private func hotKeyEventCallback(_ nextHandler: EventHandlerCallRef?,
                                 _ event: EventRef?,
                                 _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event,
                                   EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID),
                                   nil,
                                   MemoryLayout<EventHotKeyID>.size,
                                   nil,
                                   &hotKeyID)
    guard status == noErr,
          hotKeyID.signature == hotKeySignature,
          let action = hotKeyActions[hotKeyID.id] else {
        return OSStatus(eventNotHandledErr)
    }

    MainActor.assumeIsolated { action() }
    return noErr
}
