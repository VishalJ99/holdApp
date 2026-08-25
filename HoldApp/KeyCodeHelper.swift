import Foundation
import Carbon
import AppKit

/// Helper utilities for converting between key codes and human-readable strings
class KeyCodeHelper {

    // MARK: - Key Code to String

    /// Convert a key code to a human-readable string
    /// - Parameter keyCode: The Carbon key code
    /// - Returns: Human-readable key name (e.g., "Space", "S", "Delete")
    static func keyCodeToString(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        // Letters
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"

        // Numbers
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"

        // Special Keys
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "Esc"

        // Arrow Keys
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"

        // Function Keys
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"

        // Punctuation
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Grave: return "`"

        default:
            return "Key \(keyCode)"
        }
    }

    // MARK: - Modifier Formatting

    /// Return modifier symbols in standard macOS order.
    private static func modifierSymbolComponents(_ modifiers: UInt32) -> [String] {
        var components: [String] = []

        if (modifiers & UInt32(controlKey)) != 0 {
            components.append("⌃")
        }
        if (modifiers & UInt32(optionKey)) != 0 {
            components.append("⌥")
        }
        if (modifiers & UInt32(shiftKey)) != 0 {
            components.append("⇧")
        }
        if (modifiers & UInt32(cmdKey)) != 0 {
            components.append("⌘")
        }

        return components
    }

    /// Convert Carbon modifier flags to NSEvent modifier flags
    /// - Parameter carbonModifiers: Carbon modifier flags (cmdKey, shiftKey, etc.)
    /// - Returns: NSEvent.ModifierFlags
    static func carbonToNSEventModifiers(_ carbonModifiers: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []

        if (carbonModifiers & UInt32(cmdKey)) != 0 {
            flags.insert(.command)
        }
        if (carbonModifiers & UInt32(shiftKey)) != 0 {
            flags.insert(.shift)
        }
        if (carbonModifiers & UInt32(optionKey)) != 0 {
            flags.insert(.option)
        }
        if (carbonModifiers & UInt32(controlKey)) != 0 {
            flags.insert(.control)
        }

        return flags
    }

    /// Format modifiers as symbols (e.g., "⌘⇧⌃")
    /// - Parameter modifiers: Carbon modifier flags
    /// - Returns: String with modifier symbols
    static func modifierSymbols(_ modifiers: UInt32) -> String {
        return modifierSymbolComponents(modifiers).joined()
    }

    /// Format modifiers as text (e.g., "Cmd+Shift+Ctrl")
    /// - Parameter modifiers: Carbon modifier flags
    /// - Returns: String with modifier names
    static func modifierText(_ modifiers: UInt32) -> String {
        var components: [String] = []

        // Order: Control, Option, Shift, Command
        if (modifiers & UInt32(controlKey)) != 0 {
            components.append("Ctrl")
        }
        if (modifiers & UInt32(optionKey)) != 0 {
            components.append("Opt")
        }
        if (modifiers & UInt32(shiftKey)) != 0 {
            components.append("Shift")
        }
        if (modifiers & UInt32(cmdKey)) != 0 {
            components.append("Cmd")
        }

        return components.joined(separator: "+")
    }

    // MARK: - Full Hotkey Formatting

    /// Format a full hotkey binding as legible, separated symbols (e.g., "⇧  ⌘  Space")
    /// - Parameters:
    ///   - keyCode: The key code
    ///   - modifiers: The modifier flags
    /// - Returns: Formatted string like "⇧  ⌘  Space"
    static func formatHotkey(keyCode: UInt32, modifiers: UInt32) -> String {
        let keyName = keyCodeToString(keyCode)
        return (modifierSymbolComponents(modifiers) + [keyName]).joined(separator: "  ")
    }

    /// Format a full hotkey binding as text (e.g., "Cmd+Shift+Space")
    /// - Parameters:
    ///   - keyCode: The key code
    ///   - modifiers: The modifier flags
    /// - Returns: Formatted string like "Cmd+Shift+Space"
    static func formatHotkeyText(keyCode: UInt32, modifiers: UInt32) -> String {
        let modText = modifierText(modifiers)
        let keyName = keyCodeToString(keyCode)

        if modText.isEmpty {
            return keyName
        } else {
            return "\(modText)+\(keyName)"
        }
    }

    // MARK: - NSEvent Helpers

    /// Extract Carbon-compatible modifiers from NSEvent
    /// - Parameter event: The NSEvent
    /// - Returns: Carbon modifier flags
    static func carbonModifiers(from event: NSEvent) -> UInt32 {
        var modifiers: UInt32 = 0

        if event.modifierFlags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if event.modifierFlags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if event.modifierFlags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if event.modifierFlags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        return modifiers
    }
}
