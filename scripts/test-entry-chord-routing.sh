#!/bin/bash
# PER-600: real NSPanel routing without task persistence or CloudKit.
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /private/tmp/hold-entry-chords.XXXXXX)
cat > "$check_dir/main.swift" <<'SWIFT'
import Cocoa
import QuartzCore
class SpotlightViewController: NSViewController {
 var handled: [NSEvent] = []
 var captureChecks = 0
 var hasReservedEntryChordKeys: Bool { captureChecks += 1; return false }
 func handleEntryChordEvent(_ e: NSEvent) -> Bool { handled.append(e); return [36,76].contains(e.keyCode) }
 func resetHeldEntryChordKeys() {}
 func focusTextField() {}
 func handleHeldEntryChordKey(_ key: UInt16, isKeyDown: Bool) -> Bool { false }
}
class ToastManager {
 static let shared = ToastManager()
 enum Level { case warning }
 func show(_ text: String, level: Level) {}
}
let app = NSApplication.shared
let panel = SpotlightPanel()
let vc = SpotlightViewController()
vc.view = NSView(frame: .zero)
panel.contentViewController = vc
var failures = 0
func check(_ condition: Bool, _ message: String) {
 print("\(condition ? "PASS" : "FAIL"): \(message)")
 if !condition { failures += 1 }
}
for key: UInt16 in [36, 76] {
 let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .control, timestamp: 0, windowNumber: panel.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: key)!
 let before = vc.handled.count
 check(panel.performKeyEquivalent(with: event), "Control + submission key \(key) consumed before AppKit equivalent handling")
 check(vc.handled.count == before + 1, "Submission key \(key) routed exactly once")
}
panel.becomeKey()
let first = vc.captureChecks
check(first > 0, "becomeKey attempts capture setup")
panel.resignKey()
panel.becomeKey()
check(vc.captureChecks > first, "regaining key restarts capture setup")
panel.orderOut(nil)
exit(failures == 0 ? 0 : 1)
SWIFT
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc "${HOLD_PANEL_SOURCE:-HoldApp/SpotlightPanel.swift}" "$check_dir/main.swift" -o "$check_dir/check"
"$check_dir/check"
