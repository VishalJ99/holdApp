import Cocoa

class SpotlightViewController: NSViewController, TaskInputUI {

    private var textField: SubmitTextField!

    // MARK: - Edit Mode State

    private var isEditMode: Bool = false
    private var editingTaskId: String?

    // MARK: - TaskInputUI Protocol

    var onTaskSubmit: ((String, TaskCreationType) -> Void)?
    var onTaskUpdate: ((String, String) -> Void)?
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

        // Create custom text field with modifier key support
        textField = SubmitTextField(frame: NSRect(x: 20, y: 15, width: 560, height: 30))
        textField.placeholderString = "What task are you holding?"
        textField.font = NSFont.systemFont(ofSize: 18)
        textField.isBordered = false
        textField.focusRingType = .none
        textField.backgroundColor = .clear
        textField.delegate = self

        // Handle Enter key submissions with modifier detection
        textField.onSubmit = { [weak self] modifiers in
            self?.handleSubmit(modifiers: modifiers)
        }

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

    // MARK: - Private Methods

    private func handleSubmit(modifiers: NSEvent.ModifierFlags) {
        let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // EDIT MODE: Plain Enter updates task, modifiers are DISABLED
        if isEditMode {
            if !modifiers.isEmpty {
                // User pressed modifier keys in edit mode - show warning
                print("⚠️ [Edit Mode] Modifiers disabled in edit mode")
                ToastManager.shared.show("⚠️ Modifiers disabled in edit mode", type: .error)
                return
            }

            // Plain Enter in edit mode = update task
            guard let taskId = editingTaskId else {
                print("❌ [Edit Mode] No editingTaskId set")
                return
            }

            print("✏️ [Edit Mode] Updating task \(taskId) with text: \"\(text)\"")
            onTaskUpdate?(taskId, text)
            return
        }

        // NORMAL MODE: Detect which modifier keys are pressed
        let controlPressed = modifiers.contains(.control)
        let shiftPressed = modifiers.contains(.shift)
        let commandPressed = modifiers.contains(.command)

        // Determine task creation type based on modifier combination
        let creationType: TaskCreationType
        if commandPressed && controlPressed {
            // Cmd+Ctrl+Enter - sibling and switch
            creationType = .siblingAndSwitch
        } else if commandPressed {
            // Cmd+Enter - sibling
            creationType = .sibling
        } else if shiftPressed {
            // Shift+Enter - child
            creationType = .child
        } else if controlPressed {
            // Ctrl+Enter - top-level and switch
            creationType = .topLevelAndSwitch
        } else {
            // Enter - top-level
            creationType = .topLevel
        }

        // Clear text field and submit
        textField.stringValue = ""
        onTaskSubmit?(text, creationType)
    }
}

extension SpotlightViewController: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Note: Enter key submissions (including modifier combinations) are handled
        // by SubmitTextField.onSubmit callback, not here.

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
            textField.placeholderString = "Editing task... (Press Enter to save)"
            isEditMode = true
            editingTaskId = current.id
            print("✏️ [Edit Mode] Enabled - editing task: \(current.id)")
        }
    }

    func resetEditMode() {
        isEditMode = false
        editingTaskId = nil
        textField.stringValue = ""
        textField.placeholderString = "What task are you holding?"
        print("🔄 [Edit Mode] Reset")
    }
}
