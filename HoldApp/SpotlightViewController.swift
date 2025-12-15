import Cocoa

class SpotlightViewController: NSViewController, TaskInputUI {

    private var textField: SubmitTextField!
    private var flapView: NSVisualEffectView!
    private var pencilIconView: NSImageView!
    private var visualEffectView: NSVisualEffectView!

    // MARK: - Dynamic Sizing Constants
    private let pillHorizontalPadding: CGFloat = 40  // 20pt each side
    private let pillVerticalPadding: CGFloat = 24    // 12pt top/bottom
    private let minPillHeight: CGFloat = 60
    private let flapSpace: CGFloat = 30
    private let animationDuration: TimeInterval = 0.25
    private var currentPillHeight: CGFloat = 60

    private var maxPillHeight: CGFloat {
        guard let screen = NSScreen.main else { return 400 }
        return screen.visibleFrame.height * 0.5 - flapSpace
    }

    // MARK: - Edit Mode State

    private var isEditMode: Bool = false
    private var editingTaskId: String?

    // MARK: - Parent Selection State

    var selectedParentId: String?
    var selectedParentText: String?
    var preservedText: String?  // Text preserved when opening parent selector
    var isReparentMode: Bool = false  // True when Cmd+P pressed in edit mode (re-parent existing task)
    var reparentTaskId: String?  // Task ID being re-parented

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
        visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: flapSpace, width: 600, height: minPillHeight))
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
        // Positioned to align with top of text (pill top minus padding)
        // In Cocoa coords (origin at bottom), we position relative to pill height
        let topPadding: CGFloat = 12
        let pencilIconHeight: CGFloat = 24
        let pencilY = minPillHeight - topPadding - pencilIconHeight
        pencilIconView = NSImageView(frame: NSRect(x: 20, y: pencilY, width: 24, height: pencilIconHeight))

        // Use SymbolConfiguration to make the glyph fill the frame better (less internal padding)
        // Increased point size to 22 (approx 25% larger than 18)
        let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        pencilIconView.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: "Edit")?.withSymbolConfiguration(config)

        pencilIconView.contentTintColor = NSColor.white.withAlphaComponent(0.9)
        pencilIconView.isHidden = true // Hidden by default
        visualEffectView.addSubview(pencilIconView)  // Add to pill, not container

        // 4. Create custom text field
        // FIXED HEIGHT: Text field has large fixed height so NSTextField never reflows
        // Coordinates are relative to visualEffectView (the pill)
        // Text anchored to TOP of pill - in Cocoa coords, we position so textField.maxY = pillHeight - topPadding
        // Formula: textFieldY = pillHeight - topPadding - textFieldHeight
        // New lines flow BELOW and get clipped by pill's masksToBounds until pill expands
        let fixedTextFieldHeight = maxPillHeight - pillVerticalPadding
        let textFieldY = minPillHeight - topPadding - fixedTextFieldHeight
        textField = SubmitTextField(frame: NSRect(x: 20, y: textFieldY, width: 560, height: fixedTextFieldHeight))
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

        // Add text field to the PILL (not container) so masksToBounds clips overflow
        visualEffectView.addSubview(textField)
    }

    private func handleParentSelectorRequest() {
        print("🔑 [SpotlightViewController] Parent selector requested")
        let currentText = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentText.isEmpty else {
            print("⚠️ [SpotlightViewController] Cannot open parent selector - no text entered")
            return
        }

        // Check if we're in edit mode (re-parenting existing task)
        if isEditMode, let taskId = editingTaskId {
            isReparentMode = true
            reparentTaskId = taskId
            print("🔄 [SpotlightViewController] Re-parent mode: task \(taskId)")
        } else {
            isReparentMode = false
            reparentTaskId = nil
        }

        // Preserve text for when user returns
        preservedText = currentText
        print("📝 [SpotlightViewController] Preserved text: \(currentText)")

        // Notify AppDelegate to open parent selector
        onParentSelectorRequested?(currentText)
    }

    // MARK: - Dynamic Height Calculation

    private func calculateRequiredHeight(for text: String) -> CGFloat {
        guard !text.isEmpty else { return minPillHeight }

        let textFieldWidth = textField.frame.width
        let font = textField.font ?? NSFont.systemFont(ofSize: 24)

        let constraintSize = NSSize(width: textFieldWidth, height: .greatestFiniteMagnitude)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        let boundingRect = (text as NSString).boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )

        let textHeight = ceil(boundingRect.height)
        let pillHeight = textHeight + pillVerticalPadding

        return min(max(pillHeight, minPillHeight), maxPillHeight)
    }

    private func updatePillHeight(_ newHeight: CGFloat, animated: Bool) {
        guard newHeight != currentPillHeight else { return }
        currentPillHeight = newHeight

        let newContainerHeight = newHeight + flapSpace
        let topPadding: CGFloat = 12

        // Calculate pill frame (in container coordinates)
        let pillFrame = NSRect(x: 0, y: flapSpace, width: 600, height: newHeight)

        // Calculate text field Y position to keep text anchored to pill TOP
        // textField has FIXED height (maxPillHeight - pillVerticalPadding), only Y changes
        // Formula: textFieldY = pillHeight - topPadding - textFieldHeight
        let fixedTextFieldHeight = maxPillHeight - pillVerticalPadding
        let textFieldY = newHeight - topPadding - fixedTextFieldHeight
        let textFieldX: CGFloat = pencilIconView.isHidden ? 20 : 54

        // Calculate pencil Y to align with text top
        let pencilY = newHeight - topPadding - 24

        // INSTANT: Update container and reposition text/pencil (only Y changes, height stays fixed)
        // Since textField height doesn't change, NSTextField won't reflow - text stays stable
        view.frame.size.height = newContainerHeight
        textField.frame.origin.y = textFieldY
        textField.frame.origin.x = textFieldX
        pencilIconView.frame.origin.y = pencilY

        // Notify panel to resize window
        if let panel = view.window as? SpotlightPanel {
            panel.updateHeight(newContainerHeight, animated: animated)
        }

        // ANIMATED: Only animate the visual pill - this creates the "reveal" effect
        // Text below the pill is clipped by masksToBounds, revealed as pill expands
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                visualEffectView.animator().frame = pillFrame
            }
        } else {
            visualEffectView.frame = pillFrame
        }
    }

    func focusTextField() {
        // Always reset edit mode on show - guards against stale state from
        // Escape (which bypasses onCancel) or other unexpected exit paths
        resetEditMode()
        // Force reset all size variables to default (no animation, no guards)
        resetToDefaultSize()
        view.window?.makeFirstResponder(textField)
    }

    /// Force reset all pill/textField/container sizes to default minimum state.
    /// Called on every show to ensure fresh start regardless of previous state.
    private func resetToDefaultSize() {
        // Reset state variable
        currentPillHeight = minPillHeight

        let topPadding: CGFloat = 12
        let newContainerHeight = minPillHeight + flapSpace

        // Reset pill frame (in container coordinates)
        let pillFrame = NSRect(x: 0, y: flapSpace, width: 600, height: minPillHeight)
        visualEffectView.frame = pillFrame

        // Reset text field position (coordinates relative to pill)
        let fixedTextFieldHeight = maxPillHeight - pillVerticalPadding
        let textFieldY = minPillHeight - topPadding - fixedTextFieldHeight
        let textFieldX: CGFloat = pencilIconView.isHidden ? 20 : 54
        textField.frame.origin.y = textFieldY
        textField.frame.origin.x = textFieldX

        // Reset pencil icon position
        pencilIconView.frame.origin.y = minPillHeight - topPadding - 24

        // Reset container height
        view.frame.size.height = newContainerHeight

        // Reset panel window size
        if let panel = view.window as? SpotlightPanel {
            panel.updateHeight(newContainerHeight, animated: false)
        }
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
        isReparentMode = false
        reparentTaskId = nil
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
                ToastManager.shared.show("Modifiers disabled in edit mode", level: .warning)
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

        // Clear text field, reset height, and submit
        textField.stringValue = ""
        updatePillHeight(minPillHeight, animated: false)
        onTaskSubmit?(text, creationType)
    }
}

extension SpotlightViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        // Resize immediately - no debounce needed since text field resizes instantly
        // and only the visual pill animates
        let text = textField.stringValue
        let newPillHeight = calculateRequiredHeight(for: text)
        updatePillHeight(newPillHeight, animated: true)
    }

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
            // Resize pill to fit the loaded task text
            let newPillHeight = calculateRequiredHeight(for: current.text)
            updatePillHeight(newPillHeight, animated: true)
        }
    }

    func resetEditMode() {
        isEditMode = false
        editingTaskId = nil
        textField.stringValue = ""
        textField.placeholderString = "Hold..."
        print("🔄 [Edit Mode] Reset")
        updateEditModeUI(isEditing: false)
        // Shrink pill back to minimum height
        updatePillHeight(minPillHeight, animated: true)
    }

    private func updateEditModeUI(isEditing: Bool) {
        // No animation - instant update
        flapView.alphaValue = isEditing ? 1.0 : 0.0
        flapView.frame.origin.y = 0

        // Toggle pencil
        pencilIconView.isHidden = !isEditing

        // Update pencil icon Y position (coordinates relative to pill, not container)
        let topPadding: CGFloat = 12
        pencilIconView.frame.origin.y = currentPillHeight - topPadding - 24

        // Shift text field X position based on edit mode
        // Normal: x=20, width=560
        // Editing: x=54 (20 + 24 + 10 padding), width=526
        // Only change X and width - keep Y and height fixed (height = maxPillHeight - pillVerticalPadding)
        let textFieldX: CGFloat = isEditing ? 54 : 20
        let textFieldWidth: CGFloat = isEditing ? 526 : 560
        textField.frame.origin.x = textFieldX
        textField.frame.size.width = textFieldWidth
    }
    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
        if let textView = fieldEditor as? NSTextView {
            textView.insertionPointColor = .white
        }
        return true
    }
}
