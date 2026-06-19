# iOS local-only standalone fallback before Mac pointer exists

Status: human decision
Date: 2026-05-14
Ticket: NO-TICKET

## Decision

The iOS app stays local-only until the Mac-created `CURRENT_TASK_POINTER` record exists. Before that, iOS shows a black-screen one-task surface: a centered "what are you holding?" placeholder, a centered single-line cursor after tapping to edit, portrait keyboard behavior that keeps the cursor inline with the placeholder while the keyboard overlays from the bottom, landscape keyboard behavior that respects keyboard safe area so the cursor moves into the visible space above the wider keyboard, a keyboard done/tick action that submits non-empty text or cancels an empty draft back to the placeholder instead of inserting a newline, saved local text in the same centered display style, and single-tap-to-edit on the saved text. The disconnected badge opens a centered setup modal explaining that Hold captures tasks on Mac and displays them on iPhone, with three setup steps, an x close control, and one prominent Share/Copy link action for sending the App Store URL to the Mac; iOS also opens that modal automatically on first launch after either an absent-pointer fetch or an initial CloudKit fetch failure, then persists dismissal in `@AppStorage("hasShownMacConnectionHelpOnboarding")` so it does not reopen by default on every launch. Compact landscape layouts use a bounded card with a capped-width share button, extra space between the intro copy and steps, and scrollable instructions to avoid clipping. When `CURRENT_TASK_POINTER` appears after iOS has already resolved a disconnected state, iOS briefly shows a green "mac connected" badge, cancels local editing and setup help, then hides the badge and becomes read-only.

## Rationale

App Review rejected the iOS app under Guideline 4.2 because the passive display did not appear sufficiently functional in isolation. The local-only fallback keeps the iOS binary useful without making it a full task app or writing iOS-authored tasks into CloudKit. Pointer existence is enough to infer Mac connection because iOS no longer creates CloudKit entries.

## Implementation Notes

- The app does not use `MacPresence/MAC_PRESENCE`.
- `CloudKitManager.fetchCurrentTask` returns whether the pointer record exists.
- iOS stores standalone text in local `@AppStorage("standaloneHoldText")`.
- iOS standalone mode never writes `CURRENT_TASK_POINTER`.
- If the pointer record exists but contains no current task text, iOS is still considered Mac-connected and remains read-only.
- `HoldApp-iOSUITests/HoldApp_iOSUITests.swift` covers first-run setup help, closing to the placeholder, and reopening from the disconnected badge. Physical-device UI automation can still be blocked by Xcode failing to enable automation mode on the attached iPhone.
