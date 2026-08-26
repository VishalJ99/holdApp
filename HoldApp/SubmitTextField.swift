import Cocoa

/// Spotlight text field with a dedicated parent-selector shortcut.
/// Entry Chords are intercepted by `SpotlightPanel` before the text system sees them.
class SubmitTextField: NSTextField {

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

        return super.performKeyEquivalent(with: event)
    }
}
