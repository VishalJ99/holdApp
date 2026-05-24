# iOS standalone fallback when Mac presence is stale

Status: pending human review
Date: 2026-05-14
Ticket: NO-TICKET

## Decision

The iOS app remains display-only when a fresh Mac presence heartbeat exists, but shows a minimalist Mac companion onboarding flow and then a single-field standalone hold entry when the current pointer is empty and no fresh Mac heartbeat is available.

## Rationale

App Review rejected the iOS app under Guideline 4.2 because the passive display did not appear sufficiently functional in isolation. A minimal onboarding flow explains why the Mac companion unlocks the fuller task hierarchy, while the standalone hold setter preserves the Mac-primary product shape and makes the iOS binary useful when reviewed or used without the Mac app running.

## Implementation Notes

- The Mac app writes CloudKit `MacPresence/MAC_PRESENCE` on launch and every 60 seconds while running.
- iOS treats the Mac as fresh for five minutes after `lastSeenAt`.
- On first no-Mac/no-current-task launch, iOS shows a black onboarding carousel with horizontal step dots and copy for the Mac companion plus the simple iPhone holder.
- iOS standalone entry writes only `CURRENT_TASK_POINTER` with `sourcePlatform = iOS`; full task hierarchy remains Mac-owned.
