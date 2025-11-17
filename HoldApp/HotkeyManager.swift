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
        // Load hotkey preferences (defaults to current hardcoded values if not customized)
        let prefs = HotkeyPreferencesManager.shared.loadHotkeys()

        // Register Show Spotlight hotkey
        registerHotkey(
            keyCode: prefs.showSpotlight.keyCode,
            modifiers: prefs.showSpotlight.modifiers,
            hotkeyId: 1,
            hotkeyRef: &showHotKeyRef
        )

        // NOTE: Escape is NOT registered globally - each panel handles it locally in keyDown()
        // This allows Escape to work context-aware (dismiss spotlight OR sibling selector)

        // Register Sibling Selector hotkey
        registerHotkey(
            keyCode: prefs.siblingSelector.keyCode,
            modifiers: prefs.siblingSelector.modifiers,
            hotkeyId: 3,
            hotkeyRef: &siblingSelectorHotKeyRef
        )

        // Register Root Selector hotkey
        registerHotkey(
            keyCode: prefs.rootSelector.keyCode,
            modifiers: prefs.rootSelector.modifiers,
            hotkeyId: 4,
            hotkeyRef: &rootSelectorHotKeyRef
        )

        // Register Dismiss Task hotkey
        registerHotkey(
            keyCode: prefs.dismissTask.keyCode,
            modifiers: prefs.dismissTask.modifiers,
            hotkeyId: 5,
            hotkeyRef: &dismissHotKeyRef
        )

        // Register Nuke All Tasks hotkey
        registerHotkey(
            keyCode: prefs.nukeAllTasks.keyCode,
            modifiers: prefs.nukeAllTasks.modifiers,
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
        let status = RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &hotkeyRef)

        if status != noErr {
            let hotkeyString = KeyCodeHelper.formatHotkey(keyCode: keyCode, modifiers: modifiers)
            print("⚠️ Failed to register hotkey \(hotkeyString) (ID: \(hotkeyId)). Status: \(status)")
            print("   This hotkey may be in use by another application.")

            // Note: We don't crash - the app continues to work, just without this specific hotkey
            // User will need to choose a different hotkey combination in Preferences
        }
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

    /// Reload hotkeys from preferences (unregister old, register new)
    /// Called when user changes hotkey preferences
    func reloadHotkeys() {
        unregisterHotkeys()
        registerHotkeys()
    }
}
