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

    /// Callback triggered when Cmd+P is pressed (parent selector)
    var onParentSelector: (() -> Void)?

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureWrapping()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureWrapping()
    }

    private func configureWrapping() {
        self.usesSingleLineMode = false
        self.cell?.wraps = true
        self.cell?.isScrollable = false
        self.lineBreakMode = .byWordWrapping
        self.maximumNumberOfLines = 0  // No line limit
    }

    // MARK: - Key Handling

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Check for Cmd+P (parent selector)
        if event.keyCode == 35 && event.modifierFlags.contains(.command) {  // P key
            print("🔑 [SubmitTextField] Cmd+P detected - triggering parent selector")
            onParentSelector?()
            return true
        }

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
