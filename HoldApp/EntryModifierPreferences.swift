import Foundation
import AppKit
import Carbon

// MARK: - Entry Chords

/// A Spotlight submission chord. Enter is implicit; this stores the keys held with it.
struct EntryChord: Codable, Equatable, Hashable {
    static let supportedModifierMask: NSEvent.ModifierFlags = [
        .command, .option, .shift, .control
    ]

    let modifierRawValue: UInt
    let heldKeyCodes: [UInt16]

    init(
        modifiers: NSEvent.ModifierFlags = [],
        heldKeyCodes: Set<UInt16> = []
    ) {
        self.modifierRawValue = modifiers
            .intersection(Self.supportedModifierMask)
            .rawValue
        self.heldKeyCodes = heldKeyCodes.sorted()
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierRawValue)
            .intersection(Self.supportedModifierMask)
    }

    var heldKeys: Set<UInt16> {
        Set(heldKeyCodes)
    }

    var isEmpty: Bool {
        modifiers.isEmpty && heldKeyCodes.isEmpty
    }

    func union(_ other: EntryChord) -> EntryChord {
        EntryChord(
            modifiers: modifiers.union(other.modifiers),
            heldKeyCodes: heldKeys.union(other.heldKeys)
        )
    }

    var displayName: String {
        var components: [String] = []

        if modifiers.contains(.command) { components.append("Cmd") }
        if modifiers.contains(.option) { components.append("Option") }
        if modifiers.contains(.shift) { components.append("Shift") }
        if modifiers.contains(.control) { components.append("Ctrl") }
        components.append(contentsOf: heldKeyCodes.map(EntryChordKey.displayName))

        return components.joined(separator: " + ")
    }

    var displayNameWithEnter: String {
        isEmpty ? "Enter" : "\(displayName) + Enter"
    }
}

/// Non-text physical keys that may be reserved as held Entry Chord components.
enum EntryChordKey {
    static let allowedKeyCodes: Set<UInt16> = [
        UInt16(kVK_Tab),
        UInt16(kVK_Delete),
        UInt16(kVK_ForwardDelete),
        UInt16(kVK_Home),
        UInt16(kVK_End),
        UInt16(kVK_PageUp),
        UInt16(kVK_PageDown),
        UInt16(kVK_Help),
        UInt16(kVK_LeftArrow),
        UInt16(kVK_RightArrow),
        UInt16(kVK_UpArrow),
        UInt16(kVK_DownArrow),
        UInt16(kVK_F1),
        UInt16(kVK_F2),
        UInt16(kVK_F3),
        UInt16(kVK_F4),
        UInt16(kVK_F5),
        UInt16(kVK_F6),
        UInt16(kVK_F7),
        UInt16(kVK_F8),
        UInt16(kVK_F9),
        UInt16(kVK_F10),
        UInt16(kVK_F11),
        UInt16(kVK_F12),
        UInt16(kVK_F13),
        UInt16(kVK_F14),
        UInt16(kVK_F15),
        UInt16(kVK_F16),
        UInt16(kVK_F17),
        UInt16(kVK_F18),
        UInt16(kVK_F19),
        UInt16(kVK_F20)
    ]

    static func isAllowed(_ keyCode: UInt16) -> Bool {
        allowedKeyCodes.contains(keyCode)
    }

    static func isSubmissionKey(_ keyCode: UInt16) -> Bool {
        keyCode == UInt16(kVK_Return) || keyCode == UInt16(kVK_ANSI_KeypadEnter)
    }

    static func displayName(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Forward Delete"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        case kVK_Help: return "Help"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
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
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        default: return "Key \(keyCode)"
        }
    }
}

enum EntryChordAction: Equatable {
    case topLevel
    case topLevelAndSwitch
    case child
    case sibling
    case siblingAndSwitch
    case newParent
}

/// Testable held-key state used while Spotlight reserves configured non-text keys.
struct EntryChordHeldKeyState: Equatable {
    private(set) var heldKeyCodes: Set<UInt16> = []

    mutating func keyDown(_ keyCode: UInt16, reservedKeyCodes: Set<UInt16>) -> Bool {
        guard reservedKeyCodes.contains(keyCode) else { return false }
        heldKeyCodes.insert(keyCode)
        return true
    }

    mutating func keyUp(_ keyCode: UInt16, reservedKeyCodes: Set<UInt16>) -> Bool {
        let wasHeld = heldKeyCodes.remove(keyCode) != nil
        return wasHeld || reservedKeyCodes.contains(keyCode)
    }

    mutating func reset() {
        heldKeyCodes.removeAll()
    }
}

// MARK: - Data Model

/// Preferences for Spotlight entry chords. Enter is always the final key.
struct EntryModifierPreferences: Codable, Equatable {
    var childChord: EntryChord
    var siblingChord: EntryChord
    var switchChord: EntryChord
    var newParentChord: EntryChord

    static func defaults() -> EntryModifierPreferences {
        EntryModifierPreferences(
            childChord: EntryChord(modifiers: .shift),
            siblingChord: EntryChord(modifiers: .command),
            switchChord: EntryChord(modifiers: .control),
            newParentChord: EntryChord(modifiers: [.command, .shift])
        )
    }

    var allHeldKeyCodes: Set<UInt16> {
        childChord.heldKeys
            .union(siblingChord.heldKeys)
            .union(switchChord.heldKeys)
            .union(newParentChord.heldKeys)
    }

    func action(for submittedChord: EntryChord) -> EntryChordAction? {
        if submittedChord.isEmpty { return .topLevel }
        if submittedChord == newParentChord { return .newParent }
        if submittedChord == siblingChord.union(switchChord) { return .siblingAndSwitch }
        if submittedChord == childChord { return .child }
        if submittedChord == siblingChord { return .sibling }
        if submittedChord == switchChord { return .topLevelAndSwitch }
        return nil
    }

    private struct LegacyModifierFlags: Codable {
        let rawValue: UInt

        var chord: EntryChord {
            EntryChord(modifiers: NSEvent.ModifierFlags(rawValue: rawValue))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case childChord
        case siblingChord
        case switchChord
        case newParentChord
        case childModifier
        case siblingModifier
        case switchModifier
        case newParentModifier
    }

    init(
        childChord: EntryChord,
        siblingChord: EntryChord,
        switchChord: EntryChord,
        newParentChord: EntryChord
    ) {
        self.childChord = childChord
        self.siblingChord = siblingChord
        self.switchChord = switchChord
        self.newParentChord = newParentChord
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        childChord = try Self.decodeChord(
            from: container,
            currentKey: .childChord,
            legacyKey: .childModifier
        )
        siblingChord = try Self.decodeChord(
            from: container,
            currentKey: .siblingChord,
            legacyKey: .siblingModifier
        )
        switchChord = try Self.decodeChord(
            from: container,
            currentKey: .switchChord,
            legacyKey: .switchModifier
        )

        if container.contains(.newParentChord) {
            newParentChord = try container.decode(EntryChord.self, forKey: .newParentChord)
        } else if container.contains(.newParentModifier) {
            newParentChord = try container
                .decode(LegacyModifierFlags.self, forKey: .newParentModifier)
                .chord
        } else {
            newParentChord = childChord.union(siblingChord)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(childChord, forKey: .childChord)
        try container.encode(siblingChord, forKey: .siblingChord)
        try container.encode(switchChord, forKey: .switchChord)
        try container.encode(newParentChord, forKey: .newParentChord)
    }

    private static func decodeChord(
        from container: KeyedDecodingContainer<CodingKeys>,
        currentKey: CodingKeys,
        legacyKey: CodingKeys
    ) throws -> EntryChord {
        if container.contains(currentKey) {
            return try container.decode(EntryChord.self, forKey: currentKey)
        }
        return try container.decode(LegacyModifierFlags.self, forKey: legacyKey).chord
    }
}

// MARK: - Preferences Manager

final class EntryModifierPreferencesManager {
    static let shared = EntryModifierPreferencesManager()

    private let userDefaultsKey = "com.holdapp.entryModifiers"
    private init() {}

    func loadModifiers() -> EntryModifierPreferences {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return .defaults()
        }

        do {
            let preferences = try JSONDecoder().decode(EntryModifierPreferences.self, from: data)
            try validatePreferences(preferences)
            return preferences
        } catch {
            print("Failed to decode entry chord preferences: \(error). Using defaults.")
            return .defaults()
        }
    }

    func saveModifiers(_ preferences: EntryModifierPreferences) throws {
        try validatePreferences(preferences)
        let data = try JSONEncoder().encode(preferences)
        UserDefaults.standard.set(data, forKey: userDefaultsKey)

        NotificationCenter.default.post(
            name: .entryModifierPreferencesChanged,
            object: nil
        )
    }

    func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)

        NotificationCenter.default.post(
            name: .entryModifierPreferencesChanged,
            object: nil
        )
    }

    enum ValidationError: Error, LocalizedError {
        case emptyChord
        case unsupportedKey(String)
        case duplicateChord(action: String)
        case conflictingCombination(action: String)

        var errorDescription: String? {
            switch self {
            case .emptyChord:
                return "Plain Enter is reserved for creating an independent task."
            case .unsupportedKey(let key):
                return "\(key) cannot be used because it can enter or edit text in Spotlight."
            case .duplicateChord(let action):
                return "This chord is already assigned to '\(action)'."
            case .conflictingCombination(let action):
                return "This chord conflicts with '\(action)'."
            }
        }
    }

    func validatePreferences(_ preferences: EntryModifierPreferences) throws {
        let actions: [(String, EntryChord)] = [
            ("Create Child", preferences.childChord),
            ("Create Sibling", preferences.siblingChord),
            ("New Parent", preferences.newParentChord),
            ("Switch to Task", preferences.switchChord)
        ]

        for (_, chord) in actions {
            guard !chord.isEmpty else { throw ValidationError.emptyChord }
            if let unsupportedKey = chord.heldKeyCodes.first(where: { !EntryChordKey.isAllowed($0) }) {
                throw ValidationError.unsupportedKey(EntryChordKey.displayName(unsupportedKey))
            }
        }

        let siblingAndSwitch = preferences.siblingChord.union(preferences.switchChord)
        let effectiveActions = actions + [("Sibling + Switch", siblingAndSwitch)]

        for firstIndex in effectiveActions.indices {
            for secondIndex in effectiveActions.index(after: firstIndex)..<effectiveActions.endIndex {
                if effectiveActions[firstIndex].1 == effectiveActions[secondIndex].1 {
                    if effectiveActions[firstIndex].0 == "New Parent"
                        || effectiveActions[secondIndex].0 == "New Parent" {
                        throw ValidationError.conflictingCombination(
                            action: effectiveActions[firstIndex].0 == "New Parent"
                                ? effectiveActions[secondIndex].0
                                : effectiveActions[firstIndex].0
                        )
                    }
                    throw ValidationError.duplicateChord(action: effectiveActions[secondIndex].0)
                }
            }
        }
    }
}

extension Notification.Name {
    static let entryModifierPreferencesChanged = Notification.Name("com.holdapp.entryModifierPreferencesChanged")
}
