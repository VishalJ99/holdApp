# Spotlight actions use recordable non-text Entry Chords

Status: agent decision pending review
Date: 2026-08-26
Ticket: PER-461
Supersedes: the fixed-picker and Option-key constraints in PER-459; preserves its dedicated exact New Parent action

## Decision

Each Spotlight entry action stores an exact `EntryChord`: Command, Option, Shift, and Control flags plus any held non-text physical keys, with Enter remaining the final submission key. Preferences records the chord directly instead of choosing from fixed dropdown values.

Allowed held keys are Tab, Delete and Forward Delete, navigation keys, Help, arrows, and F1-F20. Printable keys and Space are rejected because they must remain available for task text. Escape remains the universal cancel key, Return/keypad Enter remain submission keys, and Caps Lock/Fn/media keys are not recordable.

Configured non-text keys are reserved only while the Spotlight panel is open and key. When at least one saved chord contains a non-text key, the panel installs a session-level active keyboard event tap and discards only configured key-down/key-up events. This prevents macOS-reserved combinations such as Command + Tab from acting before Hold, while Return, printable keys, and unconfigured controls continue through the normal AppKit input path. The panel tracks which configured keys are physically held and combines that state with the current modifier flags when Enter is pressed. Chords match exactly; an unassigned combination preserves the typed task and reports that it is not assigned. The runtime tap is removed when Spotlight hides or resigns key.

While a Preferences Record control is explicitly active, Hold installs a session-level active keyboard event tap and discards key-down, key-up, and modifier-change events after recording them. This prevents macOS-reserved combinations such as Command + Tab from opening their system UI before the recorder can see the chord. The tap is removed immediately when the chord is accepted or cancelled, the Preferences view disappears, or Hold loses application focus; normal keyboard behavior is unchanged at every other time. Starting this protected recording mode requires macOS Accessibility permission, and Hold sends the user to the relevant System Settings pane when permission is absent.

## Rationale

Tab and function keys are key events rather than `NSEvent.ModifierFlags`, so the previous modifier-only dropdown and text-field Return callback could not represent or reliably receive them. Intercepting configured keys at the session boundary before macOS, then routing them into the existing panel held-key state, supports system-reserved chords without allowing keys that would type into Spotlight.

Exact matching keeps every action deterministic and makes collision validation possible. The derived Sibling + Switch chord remains the union of those two saved chords, and New Parent remains a separately configurable exact action.

## Compatibility and Defaults

- Existing modifier-only JSON is migrated to the new chord fields.
- Older three-field settings continue to derive New Parent from Child plus Sibling.
- Defaults preserve the existing behavior: Shift + Enter for Child, Command + Enter for Sibling, Control + Enter for independent task + switch, and Command + Shift + Enter for New Parent.
- Restore Defaults removes the saved preference and immediately refreshes Spotlight.

## Implementation Notes

- `HoldApp/EntryModifierPreferences.swift` owns chord representation, allowed keys, migration, exact action resolution, held-key state, defaults, persistence, and conflict validation.
- `HoldApp/EntryModifierViewController.swift` owns the four Record controls, the recording-only session event tap and Accessibility-permission prompt, and Restore Defaults.
- `HoldApp/SpotlightPanel.swift` owns the visible-Spotlight session event tap and intercepts configured Entry Chord keys before macOS or AppKit can act.
- `HoldApp/SpotlightViewController.swift` owns shared held-key state for session-tap and AppKit delivery, then resolves the captured chord to a task creation type.
