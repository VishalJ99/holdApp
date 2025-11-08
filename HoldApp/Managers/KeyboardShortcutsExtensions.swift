import Foundation

// KeyboardShortcuts extension
// NOTE: This file requires the KeyboardShortcuts package to be added via SPM
// URL: https://github.com/sindresorhus/KeyboardShortcuts
//
// To add in Xcode:
// 1. File → Add Package Dependencies
// 2. Enter: https://github.com/sindresorhus/KeyboardShortcuts
// 3. Add to HoldApp target
//
// Once added, uncomment the code below:

/*
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showSpotlight = Self("showSpotlight", default: .init(.space, modifiers: [.command, .shift]))
    static let showEditor = Self("showEditor", default: .init(.backslash, modifiers: [.command, .shift]))
    static let completeTask = Self("completeTask", default: .init(.return, modifiers: [.command, .shift]))
    static let dismissTask = Self("dismissTask", default: .init(.delete, modifiers: [.command, .shift]))
    static let showCheatSheet = Self("showCheatSheet", default: .init(.slash, modifiers: [.command, .shift]))
}
*/

// Notification names for hotkey events (used until KeyboardShortcuts package is added)
extension Notification.Name {
    static let showSpotlight = Notification.Name("showSpotlight")
    static let showEditor = Notification.Name("showEditor")
    static let completeCurrentTask = Notification.Name("completeCurrentTask")
    static let dismissCurrentTask = Notification.Name("dismissCurrentTask")
    static let showCheatSheet = Notification.Name("showCheatSheet")
}
