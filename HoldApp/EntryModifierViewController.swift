import Cocoa
import AppKit

/// View controller for entry modifier preferences (Spotlight modifiers)
class EntryModifierViewController: NSViewController {

    // UI Elements
    private var childLabel: NSTextField!
    private var childDropdown: NSPopUpButton!
    private var siblingLabel: NSTextField!
    private var siblingDropdown: NSPopUpButton!
    private var switchLabel: NSTextField!
    private var switchDropdown: NSPopUpButton!

    private var saveButton: NSButton!
    private var cancelButton: NSButton!
    private var restoreDefaultsButton: NSButton!

    private var instructionLabel: NSTextField!

    // Data
    private var editedPreferences: EntryModifierPreferences
    private var hasUnsavedChanges = false

    // Modifier options
    private let modifierOptions: [(String, EntryModifierPreferences.ModifierFlags)] = [
        ("Shift", .shift),
        ("Cmd", .command),
        ("Ctrl", .control)
    ]

    init() {
        self.editedPreferences = EntryModifierPreferencesManager.shared.loadModifiers()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        // Instruction label at top
        instructionLabel = NSTextField(labelWithString: "Customize which modifier keys control task creation in Spotlight.\nAll modifiers are used with the Enter key.")
        instructionLabel.font = .systemFont(ofSize: 11)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.lineBreakMode = .byWordWrapping
        instructionLabel.maximumNumberOfLines = 2
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)

        // Create Child row
        childLabel = NSTextField(labelWithString: "Create Child:")
        childLabel.font = .systemFont(ofSize: 13)
        childLabel.alignment = .right
        childLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childLabel)

        childDropdown = createDropdown()
        populateDropdown(childDropdown, selected: editedPreferences.childModifier)
        childDropdown.target = self
        childDropdown.action = #selector(modifierChanged)
        view.addSubview(childDropdown)

        // Create Sibling row
        siblingLabel = NSTextField(labelWithString: "Create Sibling:")
        siblingLabel.font = .systemFont(ofSize: 13)
        siblingLabel.alignment = .right
        siblingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(siblingLabel)

        siblingDropdown = createDropdown()
        populateDropdown(siblingDropdown, selected: editedPreferences.siblingModifier)
        siblingDropdown.target = self
        siblingDropdown.action = #selector(modifierChanged)
        view.addSubview(siblingDropdown)

        // Switch to Task row
        switchLabel = NSTextField(labelWithString: "Switch to Task:")
        switchLabel.font = .systemFont(ofSize: 13)
        switchLabel.alignment = .right
        switchLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(switchLabel)

        switchDropdown = createDropdown()
        populateDropdown(switchDropdown, selected: editedPreferences.switchModifier)
        switchDropdown.target = self
        switchDropdown.action = #selector(modifierChanged)
        view.addSubview(switchDropdown)

        // Buttons at bottom
        saveButton = NSButton(title: "Save", target: self, action: #selector(savePreferences))
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.isEnabled = false
        view.addSubview(saveButton)

        cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelChanges))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        restoreDefaultsButton = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaults))
        restoreDefaultsButton.bezelStyle = .rounded
        restoreDefaultsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(restoreDefaultsButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Instruction label
            instructionLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Create Child row
            childLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 40),
            childLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            childLabel.widthAnchor.constraint(equalToConstant: 150),

            childDropdown.centerYAnchor.constraint(equalTo: childLabel.centerYAnchor),
            childDropdown.leadingAnchor.constraint(equalTo: childLabel.trailingAnchor, constant: 20),
            childDropdown.widthAnchor.constraint(equalToConstant: 150),

            // Create Sibling row
            siblingLabel.topAnchor.constraint(equalTo: childLabel.bottomAnchor, constant: 20),
            siblingLabel.leadingAnchor.constraint(equalTo: childLabel.leadingAnchor),
            siblingLabel.widthAnchor.constraint(equalToConstant: 150),

            siblingDropdown.centerYAnchor.constraint(equalTo: siblingLabel.centerYAnchor),
            siblingDropdown.leadingAnchor.constraint(equalTo: siblingLabel.trailingAnchor, constant: 20),
            siblingDropdown.widthAnchor.constraint(equalToConstant: 150),

            // Switch to Task row
            switchLabel.topAnchor.constraint(equalTo: siblingLabel.bottomAnchor, constant: 20),
            switchLabel.leadingAnchor.constraint(equalTo: childLabel.leadingAnchor),
            switchLabel.widthAnchor.constraint(equalToConstant: 150),

            switchDropdown.centerYAnchor.constraint(equalTo: switchLabel.centerYAnchor),
            switchDropdown.leadingAnchor.constraint(equalTo: switchLabel.trailingAnchor, constant: 20),
            switchDropdown.widthAnchor.constraint(equalToConstant: 150),

            // Buttons at bottom
            restoreDefaultsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            restoreDefaultsButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }

    private func createDropdown() -> NSPopUpButton {
        let dropdown = NSPopUpButton(frame: .zero, pullsDown: false)
        dropdown.translatesAutoresizingMaskIntoConstraints = false
        return dropdown
    }

    private func populateDropdown(_ dropdown: NSPopUpButton, selected: EntryModifierPreferences.ModifierFlags) {
        dropdown.removeAllItems()

        for (name, modifier) in modifierOptions {
            dropdown.addItem(withTitle: name)

            if modifier == selected {
                dropdown.selectItem(withTitle: name)
            }
        }
    }

    // MARK: - Actions

    @objc private func modifierChanged() {
        // Update edited preferences based on dropdown selections (no validation yet)
        if let childIndex = childDropdown.indexOfSelectedItem as Int?, childIndex >= 0, childIndex < modifierOptions.count {
            editedPreferences.childModifier = modifierOptions[childIndex].1
        }

        if let siblingIndex = siblingDropdown.indexOfSelectedItem as Int?, siblingIndex >= 0, siblingIndex < modifierOptions.count {
            editedPreferences.siblingModifier = modifierOptions[siblingIndex].1
        }

        if let switchIndex = switchDropdown.indexOfSelectedItem as Int?, switchIndex >= 0, switchIndex < modifierOptions.count {
            editedPreferences.switchModifier = modifierOptions[switchIndex].1
        }

        // Mark as changed and enable save button (validation happens on save)
        hasUnsavedChanges = true
        saveButton.isEnabled = true
    }

    private func validateCurrentSelection() throws {
        // Check for duplicates
        let modifiers = [
            editedPreferences.childModifier,
            editedPreferences.siblingModifier,
            editedPreferences.switchModifier
        ]

        for i in 0..<modifiers.count {
            for j in (i+1)..<modifiers.count {
                if modifiers[i] == modifiers[j] {
                    throw EntryModifierPreferencesManager.ValidationError.duplicateModifier(action: "multiple actions")
                }
            }
        }
    }

    @objc private func savePreferences() {
        // Validate before saving
        do {
            try validateCurrentSelection()
        } catch let error as EntryModifierPreferencesManager.ValidationError {
            showAlert(title: "Invalid Configuration", message: error.localizedDescription)
            return
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
            return
        }

        // Save if validation passes
        do {
            try EntryModifierPreferencesManager.shared.saveModifiers(editedPreferences)
            hasUnsavedChanges = false
            saveButton.isEnabled = false

            showAlert(title: "Preferences Saved", message: "Entry modifiers have been updated successfully.")

        } catch {
            showAlert(title: "Error", message: "Failed to save preferences: \(error.localizedDescription)")
        }
    }

    @objc private func cancelChanges() {
        if hasUnsavedChanges {
            let alert = NSAlert()
            alert.messageText = "Discard Changes?"
            alert.informativeText = "You have unsaved changes. Are you sure you want to discard them?"
            alert.addButton(withTitle: "Discard")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                reloadFromPreferences()
            }
        } else {
            view.window?.close()
        }
    }

    @objc private func restoreDefaults() {
        let alert = NSAlert()
        alert.messageText = "Restore Default Modifiers?"
        alert.informativeText = "This will reset entry modifiers to:\n• Child: Shift\n• Sibling: Cmd\n• Switch: Ctrl"
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            EntryModifierPreferencesManager.shared.resetToDefaults()
            reloadFromPreferences()

            showAlert(title: "Defaults Restored", message: "Entry modifiers have been reset to default values.")
        }
    }

    private func reloadFromPreferences() {
        editedPreferences = EntryModifierPreferencesManager.shared.loadModifiers()

        populateDropdown(childDropdown, selected: editedPreferences.childModifier)
        populateDropdown(siblingDropdown, selected: editedPreferences.siblingModifier)
        populateDropdown(switchDropdown, selected: editedPreferences.switchModifier)

        hasUnsavedChanges = false
        saveButton.isEnabled = false
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
