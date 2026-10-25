# Restore Spotlight chord interception

Ticket: PER-600 (parent PER-474)
Status: independently reviewed; archived
Date: 2026-10-25

The installed MacBook 1.6 (15) binary contains the PER-461 session capture code, and sandbox preferences assign Cmd+Tab to New Parent. Accessibility has an allow row in TCC; this alone does not prove a live tap works. Current authority is the MacBook checkout at f84e8dd; its untracked preview assets are preserved.

Independent Astra high review: localized surface PASS; no blocking runtime findings.

Two routing gaps justify a local fix: Spotlight stops its session tap on key resignation but previously restarted only through show(), so clicking back into the visible panel did not restart protected capture. Submission was handled only in sendEvent, while AppKit also routes modified keys through performKeyEquivalent. Route entry chords through that earlier path and restart capture on becomeKey. Preserve exact chord matching and the configured-keys-only session capture scope.

The standalone actual-panel regression fails on f84e8dd and passes with the change for Control-Return, Control-keypad Enter, and initial/regained key capture setup. The stub controller avoids task writes and CloudKit. This does not prove physical keyboard suppression on the installed app; that remains a separate deployment check. macOS build becomes 1.7 (16); iOS is unchanged.
