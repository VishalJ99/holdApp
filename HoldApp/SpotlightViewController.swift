import Cocoa

class SpotlightViewController: NSViewController, TaskInputUI {

    private var textField: SubmitTextField!

    // MARK: - Edit Mode State

    private var isEditMode: Bool = false
    private var editingTaskId: String?

    // MARK: - Parent Selection State

    var selectedParentId: String?
    var selectedParentText: String?
    var preservedText: String?  // Text preserved when opening parent selector

    // MARK: - TaskInputUI Protocol

    var onTaskSubmit: ((String, TaskCreationType) -> Void)?
    var onTaskUpdate: ((String, String) -> Void)?
    var onCancel: (() -> Void)?
    var onParentSelectorRequested: ((String) -> Void)?  // Called with text from field

    var isVisible: Bool {
        return view.window?.isVisible ?? false
    }

    // MARK: - Lifecycle

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        // Listen for entry modifier preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadModifierPreferences),
            name: .entryModifierPreferencesChanged,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        // Listen for entry modifier preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadModifierPreferences),
            name: .entryModifierPreferencesChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func reloadModifierPreferences() {
        // No action needed - preferences are loaded on each submit
    }

    func show() {
        // Handled by SpotlightPanel
    }

    func hide() {
        // Handled by SpotlightPanel
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Force window to recalculate shadow based on the pill-shaped content
        view.window?.invalidateShadow()
        view.window?.backgroundColor = .clear // Double check
    }

    override func loadView() {
        // 1. Create a transparent container view as the root view
        // This ensures the window's content view is just a clear canvas
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 60))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.layer?.masksToBounds = false // Allow shadow to flow outside if needed (though window shadow handles it)
        
        self.view = containerView

        // 2. Create the Visual Effect View (The Pill)
        // This is now a subview, strictly defined as the pill shape
        let visualEffectView = NSVisualEffectView(frame: containerView.bounds)
        visualEffectView.autoresizingMask = [.width, .height] // Resize with container
        visualEffectView.material = .popover
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        
        // Configure layer for pill shape
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 30
        visualEffectView.layer?.cornerCurve = .continuous
        visualEffectView.layer?.masksToBounds = true // Clip the blur to the pill shape
        visualEffectView.layer?.borderWidth = 1.0
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        
        containerView.addSubview(visualEffectView)

        // 3. Create custom text field
        textField = SubmitTextField(frame: NSRect(x: 20, y: 12, width: 560, height: 36))
        textField.placeholderString = "Hold..."
        textField.font = NSFont.systemFont(ofSize: 24, weight: .light)
        textField.textColor = .white
        textField.isBordered = false
        textField.focusRingType = .none
        textField.backgroundColor = .clear
        textField.delegate = self

        // Handle Enter key submissions with modifier detection
        textField.onSubmit = { [weak self] modifiers in
            self?.handleSubmit(modifiers: modifiers)
        }

        // Handle Cmd+P (parent selector)
        textField.onParentSelector = { [weak self] in
            self?.handleParentSelectorRequest()
        }

        // Add text field to the container (on top of visual effect view)
        // Note: We add it to containerView so it's not clipped if we ever want it to pop out, 
        // but visually it sits 'on' the pill. 
        // Actually, better to add to visualEffectView to ensure it moves with it? 
        // No, visualEffectView clips. If text field is inside, it's clipped. That's fine.
        // Let's add it to containerView to be safe, but ensure z-order.
        containerView.addSubview(textField)
    }

    private func handleParentSelectorRequest() {
        print("🔑 [SpotlightViewController] Parent selector requested")
        let currentText = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentText.isEmpty else {
            print("⚠️ [SpotlightViewController] Cannot open parent selector - no text entered")
            return
        }

        // Preserve text for when user returns
        preservedText = currentText
        print("📝 [SpotlightViewController] Preserved text: \(currentText)")

        // Notify AppDelegate to open parent selector
        onParentSelectorRequested?(currentText)
    }

    func focusTextField() {
        view.window?.makeFirstResponder(textField)
        textField.stringValue = ""
    }

    func restorePreservedText() {
        if let text = preservedText {
            textField.stringValue = text
            print("📝 [SpotlightViewController] Restored preserved text: \(text)")
        }
    }

    func setSelectedParent(parentId: String, parentText: String) {
        selectedParentId = parentId
        selectedParentText = parentText
        print("✅ [SpotlightViewController] Parent selected: \(parentText) (ID: \(parentId))")
    }

    func clearParentSelection() {
        selectedParentId = nil
        selectedParentText = nil
        preservedText = nil
        print("🔄 [SpotlightViewController] Cleared parent selection")
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

        // NORMAL MODE: Load modifier preferences and detect which are pressed
        let prefs = EntryModifierPreferencesManager.shared.loadModifiers()

        let isChildPressed = modifiers.contains(prefs.childModifier.nsEventFlags)
        let isSiblingPressed = modifiers.contains(prefs.siblingModifier.nsEventFlags)
        let isSwitchPressed = modifiers.contains(prefs.switchModifier.nsEventFlags)

        // Determine task creation type using compositional logic
        // Child modifier always implies switch (going deeper in tree)
        let creationType: TaskCreationType
        if isChildPressed {
            // Child modifier - create child and auto-switch
            creationType = .child
        } else if isSiblingPressed && isSwitchPressed {
            // Sibling + switch modifiers - create sibling and switch to it
            creationType = .siblingAndSwitch
        } else if isSiblingPressed {
            // Sibling modifier only - create sibling without switching
            creationType = .sibling
        } else if isSwitchPressed {
            // Switch modifier only - create top-level and switch to it
            creationType = .topLevelAndSwitch
        } else {
            // No modifiers - create top-level without switching
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
        textField.placeholderString = "Hold..."
        print("🔄 [Edit Mode] Reset")
    }
    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
        if let textView = fieldEditor as? NSTextView {
            textView.insertionPointColor = .white
        }
        return true
    }
}
