# New parent uses a dedicated exact modifier combination

Status: agent decision pending review
Date: 2026-08-25
Ticket: PER-459

## Decision

The macOS New Parent action has its own persisted multi-modifier combination in Entry Modifiers Preferences. It defaults to Cmd+Shift, matches the pressed modifier set exactly, and is evaluated before the compositional Child, Sibling, and Switch rules. Existing saved preferences that predate this field derive New Parent from their saved Child plus Sibling modifiers, preserving their prior shortcut.

The Preferences control offers Cmd+Shift, Cmd+Ctrl, Shift+Ctrl, and Cmd+Shift+Ctrl. A selection equal to the configured Sibling plus Switch combination is rejected so the existing Sibling + Switch action remains reachable.

## Rationale

The previous New Parent behavior was implicit: pressing the Child and Sibling modifiers together triggered it. That meant users could only change New Parent indirectly by changing two other actions. A dedicated exact combination gives the requested direct control, makes the former combination stop creating parents after the preference changes, and prevents extra held modifiers from triggering New Parent accidentally.

## Alternatives Considered

- Keep deriving New Parent from Child plus Sibling: rejected because it does not provide an independent Preferences control.
- Assign one standalone modifier to New Parent: rejected because Shift, Command, and Control already have individual entry actions, while Option+Enter is not reliably intercepted by the macOS text input system.
- Let New Parent override Sibling + Switch: rejected because it would silently make an existing documented action unavailable.

## Implementation Notes

- `HoldApp/EntryModifierPreferences.swift` owns persistence, display formatting, and legacy decoding.
- `HoldApp/EntryModifierViewController.swift` owns the New Parent picker and conflict validation.
- `HoldApp/SpotlightViewController.swift` performs the exact New Parent match before other entry rules.
- `HoldApp/WelcomeWindow.swift` renders the saved combinations in the welcome guide.
