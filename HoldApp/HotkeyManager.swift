import Cocoa
import Carbon

class HotkeyManager {
    private var hotkeyRefs: [Int: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    var onShowSpotlight: (() -> Void)?
    var onShowEditor: (() -> Void)?
    var onCompleteTask: (() -> Void)?
    var onDismissTask: (() -> Void)?
    var onShowCheatSheet: (() -> Void)?

    deinit {
        unregisterHotkeys()
    }

    func registerHotkeys() {
        // Register Cmd+Shift+Space for Spotlight
        registerHotkey(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(cmdKey | shiftKey),
            hotkeyId: 1
        )

        // Register Cmd+Shift+\ for Editor
        registerHotkey(
            keyCode: UInt32(kVK_ANSI_Backslash),
            modifiers: UInt32(cmdKey | shiftKey),
            hotkeyId: 2
        )

        // Register Cmd+Shift+Return for Complete
        registerHotkey(
            keyCode: UInt32(kVK_Return),
            modifiers: UInt32(cmdKey | shiftKey),
            hotkeyId: 3
        )

        // Register Cmd+Shift+Delete for Dismiss
        registerHotkey(
            keyCode: UInt32(kVK_Delete),
            modifiers: UInt32(cmdKey | shiftKey),
            hotkeyId: 4
        )

        // Register Cmd+? for Cheat Sheet (Cmd+Shift+/ on US keyboard)
        registerHotkey(
            keyCode: UInt32(kVK_ANSI_Slash),
            modifiers: UInt32(cmdKey | shiftKey),
            hotkeyId: 5
        )

        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotkeyId = EventHotKeyID()
            GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyId)

            switch hotkeyId.id {
            case 1:
                manager.onShowSpotlight?()
            case 2:
                manager.onShowEditor?()
            case 3:
                manager.onCompleteTask?()
            case 4:
                manager.onDismissTask?()
            case 5:
                manager.onShowCheatSheet?()
            default:
                break
            }

            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }

    private func registerHotkey(keyCode: UInt32, modifiers: UInt32, hotkeyId: Int) {
        var hotkeyRef: EventHotKeyRef?
        var hotkeyID = EventHotKeyID(signature: OSType(0x484B4559), id: UInt32(hotkeyId)) // 'HKEY'
        let status = RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &hotkeyRef)

        if status == noErr, let ref = hotkeyRef {
            hotkeyRefs[hotkeyId] = ref
            print("✅ Registered hotkey \(hotkeyId)")
        } else {
            print("❌ Failed to register hotkey \(hotkeyId): \(status)")
        }
    }

    func unregisterHotkeys() {
        for (_, ref) in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}
