import Cocoa
import Carbon

class HotkeyManager {
    private var showHotKeyRef: EventHotKeyRef?
    private var hideHotKeyRef: EventHotKeyRef?
    private var siblingSelectorHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    var onShowHotkey: (() -> Void)?
    var onHideHotkey: (() -> Void)?
    var onSiblingSelector: (() -> Void)?

    deinit {
        unregisterHotkeys()
    }

    func registerHotkeys() {
        // Register Command+Shift+Space to show
        registerHotkey(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(cmdKey | shiftKey),
            hotkeyId: 1,
            hotkeyRef: &showHotKeyRef
        )

        // Register Escape to hide
        registerHotkey(
            keyCode: UInt32(kVK_Escape),
            modifiers: 0,
            hotkeyId: 2,
            hotkeyRef: &hideHotKeyRef
        )

        // Register Command+Shift+S to show sibling selector
        registerHotkey(
            keyCode: UInt32(kVK_ANSI_S),
            modifiers: UInt32(cmdKey | shiftKey),
            hotkeyId: 3,
            hotkeyRef: &siblingSelectorHotKeyRef
        )

        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotkeyId = EventHotKeyID()
            GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyId)

            if hotkeyId.id == 1 {
                manager.onShowHotkey?()
            } else if hotkeyId.id == 2 {
                manager.onHideHotkey?()
            } else if hotkeyId.id == 3 {
                manager.onSiblingSelector?()
            }

            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }

    private func registerHotkey(keyCode: UInt32, modifiers: UInt32, hotkeyId: UInt32, hotkeyRef: inout EventHotKeyRef?) {
        var hotkeyID = EventHotKeyID(signature: OSType(0x484B4559), id: hotkeyId) // 'HKEY'
        RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
    }

    func unregisterHotkeys() {
        if let ref = showHotKeyRef {
            UnregisterEventHotKey(ref)
            showHotKeyRef = nil
        }
        if let ref = hideHotKeyRef {
            UnregisterEventHotKey(ref)
            hideHotKeyRef = nil
        }
        if let ref = siblingSelectorHotKeyRef {
            UnregisterEventHotKey(ref)
            siblingSelectorHotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}
