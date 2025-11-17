import Foundation
import AppKit

// MARK: - Data Model

/// Preferences for Spotlight entry modifiers (always used with Enter key)
struct EntryModifierPreferences: Codable {
    var childModifier: ModifierFlags      // Default: Shift - creates child + auto-switches
    var siblingModifier: ModifierFlags    // Default: Cmd - creates sibling
    var switchModifier: ModifierFlags     // Default: Ctrl - switches to created task

    /// Codable wrapper for NSEvent.ModifierFlags
    struct ModifierFlags: Codable, Equatable {
        let rawValue: UInt

        init(_ flags: NSEvent.ModifierFlags) {
            self.rawValue = flags.rawValue
        }

        var nsEventFlags: NSEvent.ModifierFlags {
            return NSEvent.ModifierFlags(rawValue: rawValue)
        }

        // Convenience constructors
        static let shift = ModifierFlags(.shift)
        static let command = ModifierFlags(.command)
        static let control = ModifierFlags(.control)
        static let none = ModifierFlags([])
    }

    /// Default preferences matching current hardcoded behavior
    static func defaults() -> EntryModifierPreferences {
        return EntryModifierPreferences(
            childModifier: .shift,
            siblingModifier: .command,
            switchModifier: .control
        )
    }
}

// MARK: - Preferences Manager

/// Manages loading, saving, and validating entry modifier preferences
class EntryModifierPreferencesManager {
    static let shared = EntryModifierPreferencesManager()

    private let userDefaultsKey = "com.holdapp.entryModifiers"
    private init() {}

    // MARK: - Load/Save

    /// Load entry modifier preferences from UserDefaults, or return defaults if not found
    func loadModifiers() -> EntryModifierPreferences {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            // No saved preferences - return defaults
            return .defaults()
        }

        do {
            let preferences = try JSONDecoder().decode(EntryModifierPreferences.self, from: data)
            return preferences
        } catch {
            // Corrupted data - return defaults and log error
            print("Failed to decode entry modifier preferences: \(error). Using defaults.")
            return .defaults()
        }
    }

    /// Save entry modifier preferences to UserDefaults
    func saveModifiers(_ preferences: EntryModifierPreferences) throws {
        let data = try JSONEncoder().encode(preferences)
        UserDefaults.standard.set(data, forKey: userDefaultsKey)

        // Post notification to trigger reload
        NotificationCenter.default.post(
            name: .entryModifierPreferencesChanged,
            object: nil
        )
    }

    /// Reset to default entry modifier preferences
    func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)

        // Post notification to trigger reload
        NotificationCenter.default.post(
            name: .entryModifierPreferencesChanged,
            object: nil
        )
    }

    // MARK: - Validation

    enum ValidationError: Error, LocalizedError {
        case optionNotSupported
        case duplicateModifier(action: String)

        var errorDescription: String? {
            switch self {
            case .optionNotSupported:
                return "Option key is not supported for entry modifiers (macOS limitation)"
            case .duplicateModifier(let action):
                return "This modifier is already assigned to '\(action)'"
            }
        }
    }

    /// Validate an entry modifier
    /// - Parameters:
    ///   - modifier: The modifier to validate
    ///   - excludingAction: Action name to exclude from duplicate check
    ///   - preferences: Current preferences to check against
    /// - Throws: ValidationError if invalid
    func validateModifier(
        _ modifier: EntryModifierPreferences.ModifierFlags,
        excludingAction: String? = nil,
        in preferences: EntryModifierPreferences
    ) throws {
        let flags = modifier.nsEventFlags

        // Check for Option key (not supported due to macOS text input system)
        if flags.contains(.option) {
            throw ValidationError.optionNotSupported
        }

        // Check for duplicates
        let modifiers: [(String, EntryModifierPreferences.ModifierFlags)] = [
            ("Create Child", preferences.childModifier),
            ("Create Sibling", preferences.siblingModifier),
            ("Switch to Task", preferences.switchModifier)
        ]

        for (action, existingModifier) in modifiers {
            // Skip if this is the action we're editing
            if action == excludingAction {
                continue
            }

            // Check if modifier matches
            if existingModifier == modifier {
                throw ValidationError.duplicateModifier(action: action)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let entryModifierPreferencesChanged = Notification.Name("com.holdapp.entryModifierPreferencesChanged")
}
