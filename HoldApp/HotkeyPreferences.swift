import Foundation
import Carbon

// MARK: - Data Models

/// Represents a single hotkey binding (key code + modifier flags)
struct HotkeyBinding: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// All hotkey preferences for the app
struct HotkeyPreferences: Codable {
    var showSpotlight: HotkeyBinding
    var siblingSelector: HotkeyBinding
    var rootSelector: HotkeyBinding
    var dismissTask: HotkeyBinding
    var nukeAllTasks: HotkeyBinding

    /// Returns default hotkey preferences (matches current hardcoded values)
    static func defaults() -> HotkeyPreferences {
        return HotkeyPreferences(
            showSpotlight: HotkeyBinding(
                keyCode: UInt32(kVK_Space),
                modifiers: UInt32(cmdKey | shiftKey)
            ),
            siblingSelector: HotkeyBinding(
                keyCode: UInt32(kVK_ANSI_S),
                modifiers: UInt32(cmdKey | shiftKey)
            ),
            rootSelector: HotkeyBinding(
                keyCode: UInt32(kVK_ANSI_R),
                modifiers: UInt32(cmdKey | shiftKey)
            ),
            dismissTask: HotkeyBinding(
                keyCode: UInt32(kVK_ANSI_D),
                modifiers: UInt32(cmdKey | shiftKey)
            ),
            nukeAllTasks: HotkeyBinding(
                keyCode: UInt32(kVK_Delete),
                modifiers: UInt32(cmdKey | shiftKey)
            )
        )
    }
}

// MARK: - Preferences Manager

/// Manages loading, saving, and validating hotkey preferences
class HotkeyPreferencesManager {
    static let shared = HotkeyPreferencesManager()

    private let userDefaultsKey = "com.holdapp.hotkeys"
    private init() {}

    // MARK: - Load/Save

    /// Load hotkey preferences from UserDefaults, or return defaults if not found
    func loadHotkeys() -> HotkeyPreferences {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            // No saved preferences - return defaults
            return .defaults()
        }

        do {
            let preferences = try JSONDecoder().decode(HotkeyPreferences.self, from: data)
            return preferences
        } catch {
            // Corrupted data - return defaults and log error
            print("Failed to decode hotkey preferences: \(error). Using defaults.")
            return .defaults()
        }
    }

    /// Save hotkey preferences to UserDefaults
    func saveHotkeys(_ preferences: HotkeyPreferences) throws {
        let data = try JSONEncoder().encode(preferences)
        UserDefaults.standard.set(data, forKey: userDefaultsKey)

        // Post notification to trigger hotkey reload
        NotificationCenter.default.post(
            name: .hotkeyPreferencesChanged,
            object: nil
        )
    }

    /// Reset to default hotkey preferences
    func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)

        // Post notification to trigger hotkey reload
        NotificationCenter.default.post(
            name: .hotkeyPreferencesChanged,
            object: nil
        )
    }

    // MARK: - Validation

    enum ValidationError: Error, LocalizedError {
        case missingModifiers
        case duplicateBinding(action: String)

        var errorDescription: String? {
            switch self {
            case .missingModifiers:
                return "Hotkey must include at least one modifier key (⌘, ⌃, or ⇧)"
            case .duplicateBinding(let action):
                return "This hotkey is already assigned to '\(action)'"
            }
        }
    }

    /// Validate a hotkey binding
    /// - Parameters:
    ///   - binding: The binding to validate
    ///   - excludingAction: Action name to exclude from duplicate check (for editing existing)
    ///   - preferences: Current preferences to check against
    /// - Throws: ValidationError if invalid
    func validateHotkey(
        _ binding: HotkeyBinding,
        excludingAction: String? = nil,
        in preferences: HotkeyPreferences
    ) throws {
        // Check for required modifiers
        let hasCommand = (binding.modifiers & UInt32(cmdKey)) != 0
        let hasControl = (binding.modifiers & UInt32(controlKey)) != 0
        let hasShift = (binding.modifiers & UInt32(shiftKey)) != 0

        guard hasCommand || hasControl || hasShift else {
            throw ValidationError.missingModifiers
        }

        // Check for duplicates
        let bindings: [(String, HotkeyBinding)] = [
            ("Show Spotlight", preferences.showSpotlight),
            ("Sibling Selector", preferences.siblingSelector),
            ("Root Selector", preferences.rootSelector),
            ("Dismiss Task", preferences.dismissTask),
            ("Nuke All Tasks", preferences.nukeAllTasks)
        ]

        for (action, existingBinding) in bindings {
            // Skip if this is the action we're editing
            if action == excludingAction {
                continue
            }

            // Check if binding matches
            if existingBinding == binding {
                throw ValidationError.duplicateBinding(action: action)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let hotkeyPreferencesChanged = Notification.Name("com.holdapp.hotkeyPreferencesChanged")
}
