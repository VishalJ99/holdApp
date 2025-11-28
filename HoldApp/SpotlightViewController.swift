import Cocoa

class SpotlightViewController: NSViewController, TaskInputUI {

    private var textField: SubmitTextField!
    private var flapView: NSVisualEffectView!
    private var pencilIconView: NSImageView!

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
        // Increased height to 90 to accommodate the flap (60 pill + 30 flap space)
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 90))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.layer?.masksToBounds = false
        
        self.view = containerView

        // 2. Create the Flap View (Behind the pill)
        // Centered, sticking out from the bottom
        let flapWidth: CGFloat = 140
        let flapHeight: CGFloat = 40 // 30 visible + 10 overlap
        let flapX = (600 - flapWidth) / 2
        
        flapView = NSVisualEffectView(frame: NSRect(x: flapX, y: 0, width: flapWidth, height: flapHeight))
        flapView.material = .popover
        flapView.state = .active
        flapView.blendingMode = .behindWindow
        flapView.wantsLayer = true
        flapView.layer?.cornerRadius = 12
        flapView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner] // Round bottom corners
        flapView.alphaValue = 0 // Hidden by default
        
        // Add "Editing" Label (Centered in flap)
        let label = NSTextField(labelWithString: "Editing")
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor.white.withAlphaComponent(0.9)
        label.sizeToFit()
        
        // Center label in flap
        label.frame.origin = CGPoint(
            x: (flapWidth - label.frame.width) / 2,
            y: 10
        )
        flapView.addSubview(label)
        
        containerView.addSubview(flapView)

        // 3. Create the Main Pill (Visual Effect View)
        // Moved up by 30 to make room for flap
        let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 30, width: 600, height: 60))
        visualEffectView.autoresizingMask = [.width] // Resize with container width
        visualEffectView.material = .popover
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        
        // Configure layer for pill shape
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 30
        visualEffectView.layer?.cornerCurve = .continuous
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1.0
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        
        containerView.addSubview(visualEffectView)

        // 3.5 Create Pencil Icon (Inside Pill, LHS)
        // Positioned at x=20, centered vertically in the pill (y=30 to y=90 -> height 60)
        // Pill Y starts at 30. Center is 30 + 30 = 60.
        // 3.5 Create Pencil Icon (Inside Pill, LHS)
        // Positioned at x=20, centered vertically in the pill (y=30 to y=90 -> height 60)
        // Pill Y starts at 30. Center is 30 + 30 = 60.
        // 3.5 Create Pencil Icon (Inside Pill, LHS)
        // Positioned at x=20, centered vertically in the pill (y=30 to y=90 -> height 60)
        // Pill Y starts at 30. Center is 30 + 30 = 60.
        // Icon size 24 (25% larger). Y = 60 - 12 = 48.
        pencilIconView = NSImageView(frame: NSRect(x: 20, y: 48, width: 24, height: 24))
        
        // Use SymbolConfiguration to make the glyph fill the frame better (less internal padding)
        // Increased point size to 22 (approx 25% larger than 18)
        let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        pencilIconView.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: "Edit")?.withSymbolConfiguration(config)
        
        pencilIconView.contentTintColor = NSColor.white.withAlphaComponent(0.9)
        pencilIconView.isHidden = true // Hidden by default
        containerView.addSubview(pencilIconView)

        // 4. Create custom text field
        // Adjusted Y position to 42 (12 + 30)
        textField = SubmitTextField(frame: NSRect(x: 20, y: 42, width: 560, height: 36))
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

        // Add text field to the container
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
        // Always reset edit mode on show - guards against stale state from
        // Escape (which bypasses onCancel) or other unexpected exit paths
        resetEditMode()
        view.window?.makeFirstResponder(textField)
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

        // Handle Down Arrow - exit edit mode and clear text
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            resetEditMode()  // Resets isEditMode, editingTaskId, text, and placeholder
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
            updateEditModeUI(isEditing: true)
        }
    }

    func resetEditMode() {
        isEditMode = false
        editingTaskId = nil
        textField.stringValue = ""
        textField.placeholderString = "Hold..."
        print("🔄 [Edit Mode] Reset")
        updateEditModeUI(isEditing: false)
    }

    private func updateEditModeUI(isEditing: Bool) {
        // No animation - instant update
        flapView.alphaValue = isEditing ? 1.0 : 0.0
        flapView.frame.origin.y = 0
        
        // Toggle pencil
        pencilIconView.isHidden = !isEditing
        
        // Shift text field
        // Normal: x=20, width=560
        // Editing: x=54 (20 + 24 + 10 padding), width=526
        if isEditing {
            textField.frame = NSRect(x: 54, y: 42, width: 526, height: 36)
        } else {
            textField.frame = NSRect(x: 20, y: 42, width: 560, height: 36)
        }
    }
    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
        if let textView = fieldEditor as? NSTextView {
            textView.insertionPointColor = .white
        }
        return true
    }
}
