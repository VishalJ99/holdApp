import Cocoa

class SpotlightViewController: NSViewController, TaskInputUI {

    private var textField: NSTextField!

    // MARK: - TaskInputUI Protocol

    var onTaskSubmit: ((String, TaskCreationType) -> Void)?
    var onCancel: (() -> Void)?

    var isVisible: Bool {
        return view.window?.isVisible ?? false
    }

    func show() {
        // Handled by SpotlightPanel
    }

    func hide() {
        // Handled by SpotlightPanel
    }

    override func loadView() {
        // Create the main view
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 60))

        // Create text field
        textField = NSTextField(frame: NSRect(x: 20, y: 15, width: 560, height: 30))
        textField.placeholderString = "What task are you holding?"
        textField.font = NSFont.systemFont(ofSize: 18)
        textField.isBordered = false
        textField.focusRingType = .none
        textField.backgroundColor = .clear
        textField.delegate = self

        view.addSubview(textField)
    }

    func focusTextField() {
        view.window?.makeFirstResponder(textField)
        textField.stringValue = ""
    }

    override func keyDown(with event: NSEvent) {
        // Handle Escape key
        if event.keyCode == 53 { // Escape key
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }
}

extension SpotlightViewController: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Handle Enter key with modifiers
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return true }

            let modifiers = NSEvent.modifierFlags

            // Detect which modifier keys are pressed
            let optionPressed = modifiers.contains(.option)
            let shiftPressed = modifiers.contains(.shift)
            let commandPressed = modifiers.contains(.command)

            // Determine task creation type
            let creationType: TaskCreationType
            if commandPressed && optionPressed {
                // Cmd+Option+Enter - sibling and switch
                creationType = .siblingAndSwitch
            } else if commandPressed {
                // Cmd+Enter - sibling
                creationType = .sibling
            } else if shiftPressed {
                // Shift+Enter - child
                creationType = .child
            } else if optionPressed {
                // Option+Enter - top-level and switch
                creationType = .topLevelAndSwitch
            } else {
                // Enter - top-level
                creationType = .topLevel
            }

            // Clear text field and submit
            textField.stringValue = ""
            onTaskSubmit?(text, creationType)
            return true
        }

        // Handle Up Arrow - load current task
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            loadCurrentTask()
            return true
        }

        // Handle Down Arrow - clear text
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            textField.stringValue = ""
            return true
        }

        return false
    }

    private func loadCurrentTask() {
        if let current = AppState.shared.currentTask {
            textField.stringValue = current.text
        }
    }
}
