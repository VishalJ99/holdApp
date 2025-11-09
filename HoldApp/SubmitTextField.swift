import Cocoa

/// Custom NSTextField that properly handles Enter key with modifier keys.
///
/// Standard NSTextField doesn't trigger delegate callbacks for modifier+Enter combinations
/// because the text input system interprets them as text insertion commands.
/// This subclass intercepts these key events at the performKeyEquivalent level.
///
/// Note: Uses Control instead of Option as modifier because Option+Enter is treated
/// as text input (newline) by macOS and bypasses performKeyEquivalent entirely.
class SubmitTextField: NSTextField {

    /// Callback triggered when Enter or modifier+Enter is pressed
    /// Parameters: modifiers pressed (empty set for plain Enter)
    var onSubmit: ((NSEvent.ModifierFlags) -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Check for Return/Enter key (keyCode 36)
        if event.keyCode == 36 {
            // Get relevant modifier flags, ignoring system flags like Caps Lock, Function, etc.
            let relevantModifiers: NSEvent.ModifierFlags = [.control, .shift, .command]
            let modifiers = event.modifierFlags.intersection(relevantModifiers)

            // Trigger submission callback with detected modifiers
            onSubmit?(modifiers)
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}
