import Cocoa
import Carbon

class HotkeyManager {
    private var showHotKeyRef: EventHotKeyRef?
    private var siblingSelectorHotKeyRef: EventHotKeyRef?
    private var rootSelectorHotKeyRef: EventHotKeyRef?
    private var dismissHotKeyRef: EventHotKeyRef?
    private var nukeHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    var onShowHotkey: (() -> Void)?
    var onSiblingSelector: (() -> Void)?
    var onRootSelector: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onNuke: (() -> Void)?

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

        // NOTE: Escape is NOT registered globally - each panel handles it locally in keyDown()
        // This allows Escape to work context-aware (dismiss spotlight OR sibling selector)

        // Register Command+Shift+S to show sibling selector
        registerHotkey(
            keyCode: UInt32(kVK_ANSI_S),
            modifiers: UInt32(cmdKey | shiftKey),
            hotkeyId: 3,
            hotkeyRef: &siblingSelectorHotKeyRef
        )

        // Register Command+Shift+R to show root selector
        registerHotkey(
            keyCode: UInt32(kVK_ANSI_R),
            modifiers: UInt32(cmdKey | shiftKey),
            hotkeyId: 4,
            hotkeyRef: &rootSelectorHotKeyRef
        )

        // Register Command+Shift+D to dismiss current task
        registerHotkey(
            keyCode: UInt32(kVK_ANSI_D),
            modifiers: UInt32(cmdKey | shiftKey),
            hotkeyId: 5,
            hotkeyRef: &dismissHotKeyRef
        )

        // Register Command+Shift+Backspace to nuke all tasks
        registerHotkey(
            keyCode: UInt32(kVK_Delete),
            modifiers: UInt32(cmdKey | shiftKey),
            hotkeyId: 6,
            hotkeyRef: &nukeHotKeyRef
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
            } else if hotkeyId.id == 3 {
                manager.onSiblingSelector?()
            } else if hotkeyId.id == 4 {
                manager.onRootSelector?()
            } else if hotkeyId.id == 5 {
                manager.onDismiss?()
            } else if hotkeyId.id == 6 {
                manager.onNuke?()
            }
            // Note: hotkeyId 2 (Escape) removed - handled locally by panels

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
        if let ref = siblingSelectorHotKeyRef {
            UnregisterEventHotKey(ref)
            siblingSelectorHotKeyRef = nil
        }
        if let ref = rootSelectorHotKeyRef {
            UnregisterEventHotKey(ref)
            rootSelectorHotKeyRef = nil
        }
        if let ref = dismissHotKeyRef {
            UnregisterEventHotKey(ref)
            dismissHotKeyRef = nil
        }
        if let ref = nukeHotKeyRef {
            UnregisterEventHotKey(ref)
            nukeHotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}
