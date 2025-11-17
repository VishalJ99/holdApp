import Cocoa
import Carbon

/// View controller for the hotkey preferences tab
class HotkeyRecorderViewController: NSViewController {

    // UI Elements
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var saveButton: NSButton!
    private var cancelButton: NSButton!
    private var restoreDefaultsButton: NSButton!

    // Data
    private var hotkeyItems: [HotkeyItem] = []
    private var editedPreferences: HotkeyPreferences
    private var hasUnsavedChanges = false

    // Recording state
    private var recordingRowIndex: Int? = nil

    struct HotkeyItem {
        let actionName: String
        let actionKey: WritableKeyPath<HotkeyPreferences, HotkeyBinding>
        var binding: HotkeyBinding
    }

    init() {
        // Load current preferences
        self.editedPreferences = HotkeyPreferencesManager.shared.loadHotkeys()

        // Initialize hotkey items
        self.hotkeyItems = [
            HotkeyItem(
                actionName: "Show Spotlight",
                actionKey: \.showSpotlight,
                binding: editedPreferences.showSpotlight
            ),
            HotkeyItem(
                actionName: "Sibling Selector",
                actionKey: \.siblingSelector,
                binding: editedPreferences.siblingSelector
            ),
            HotkeyItem(
                actionName: "Root Selector",
                actionKey: \.rootSelector,
                binding: editedPreferences.rootSelector
            ),
            HotkeyItem(
                actionName: "Dismiss Task",
                actionKey: \.dismissTask,
                binding: editedPreferences.dismissTask
            ),
            HotkeyItem(
                actionName: "Nuke All Tasks",
                actionKey: \.nukeAllTasks,
                binding: editedPreferences.nukeAllTasks
            )
        ]

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
        // Create table view
        tableView = NSTableView()
        tableView.style = .plain
        tableView.headerView = nil
        tableView.rowHeight = 40
        tableView.intercellSpacing = NSSize(width: 0, height: 8)
        tableView.backgroundColor = .clear

        // Add columns
        let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        actionColumn.title = "Action"
        actionColumn.width = 200
        tableView.addTableColumn(actionColumn)

        let hotkeyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("hotkey"))
        hotkeyColumn.title = "Hotkey"
        hotkeyColumn.width = 250
        tableView.addTableColumn(hotkeyColumn)

        let recordColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("record"))
        recordColumn.title = ""
        recordColumn.width = 100
        tableView.addTableColumn(recordColumn)

        tableView.delegate = self
        tableView.dataSource = self

        // Wrap in scroll view
        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Create buttons
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
            // Scroll view (table)
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -20),

            // Buttons at bottom
            restoreDefaultsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            restoreDefaultsButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Actions

    @objc private func recordButtonClicked(_ sender: NSButton) {
        let row = tableView.row(for: sender)
        guard row >= 0 && row < hotkeyItems.count else { return }

        // Start recording
        recordingRowIndex = row
        sender.title = "Press keys..."
        sender.isEnabled = false

        // Make the table view first responder to capture keystrokes
        view.window?.makeFirstResponder(tableView)
    }

    @objc private func savePreferences() {
        // Update preferences from edited items
        for item in hotkeyItems {
            editedPreferences[keyPath: item.actionKey] = item.binding
        }

        // Save to UserDefaults
        do {
            try HotkeyPreferencesManager.shared.saveHotkeys(editedPreferences)
            hasUnsavedChanges = false
            saveButton.isEnabled = false

            // Show success message
            showAlert(title: "Preferences Saved", message: "Hotkeys have been updated successfully.")

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
                // Reload from preferences
                reloadFromPreferences()
            }
        } else {
            view.window?.close()
        }
    }

    @objc private func restoreDefaults() {
        let alert = NSAlert()
        alert.messageText = "Restore Default Hotkeys?"
        alert.informativeText = "This will reset all hotkeys to their default values."
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            HotkeyPreferencesManager.shared.resetToDefaults()
            reloadFromPreferences()

            showAlert(title: "Defaults Restored", message: "Hotkeys have been reset to default values.")
        }
    }

    private func reloadFromPreferences() {
        editedPreferences = HotkeyPreferencesManager.shared.loadHotkeys()

        // Update items
        for (index, item) in hotkeyItems.enumerated() {
            hotkeyItems[index].binding = editedPreferences[keyPath: item.actionKey]
        }

        hasUnsavedChanges = false
        saveButton.isEnabled = false
        tableView.reloadData()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    // MARK: - Keystroke Capture

    override func keyDown(with event: NSEvent) {
        guard let rowIndex = recordingRowIndex else {
            super.keyDown(with: event)
            return
        }

        // Extract key info
        let keyCode = event.keyCode
        let modifiers = KeyCodeHelper.carbonModifiers(from: event)

        // Handle Escape - cancel recording
        if keyCode == kVK_Escape {
            cancelRecording(at: rowIndex)
            return
        }

        // Create new binding
        let newBinding = HotkeyBinding(keyCode: UInt32(keyCode), modifiers: modifiers)

        // Validate
        do {
            try HotkeyPreferencesManager.shared.validateHotkey(
                newBinding,
                excludingAction: hotkeyItems[rowIndex].actionName,
                in: editedPreferences
            )

            // Valid - update
            hotkeyItems[rowIndex].binding = newBinding
            hasUnsavedChanges = true
            saveButton.isEnabled = true

            // Exit recording mode
            recordingRowIndex = nil
            tableView.reloadData()

        } catch let error as HotkeyPreferencesManager.ValidationError {
            // Show error
            showAlert(title: "Invalid Hotkey", message: error.localizedDescription)

            // Exit recording mode
            cancelRecording(at: rowIndex)
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
            cancelRecording(at: rowIndex)
        }
    }

    private func cancelRecording(at rowIndex: Int) {
        recordingRowIndex = nil
        tableView.reloadData(forRowIndexes: IndexSet(integer: rowIndex), columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
    }
}

// MARK: - NSTableViewDataSource

extension HotkeyRecorderViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return hotkeyItems.count
    }
}

// MARK: - NSTableViewDelegate

extension HotkeyRecorderViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = hotkeyItems[row]

        if tableColumn?.identifier.rawValue == "action" {
            // Action name
            let textField = NSTextField(labelWithString: item.actionName)
            textField.font = .systemFont(ofSize: 13)
            return textField

        } else if tableColumn?.identifier.rawValue == "hotkey" {
            // Hotkey display
            let hotkeyString = KeyCodeHelper.formatHotkey(
                keyCode: item.binding.keyCode,
                modifiers: item.binding.modifiers
            )
            let textField = NSTextField(labelWithString: hotkeyString)
            textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            return textField

        } else if tableColumn?.identifier.rawValue == "record" {
            // Record button
            let button = NSButton(title: "Record", target: self, action: #selector(recordButtonClicked(_:)))
            button.bezelStyle = .rounded

            // If this row is being recorded, update button state
            if recordingRowIndex == row {
                button.title = "Press keys..."
                button.isEnabled = false
            }

            return button
        }

        return nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false  // Disable row selection
    }
}
