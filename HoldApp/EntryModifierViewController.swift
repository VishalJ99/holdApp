import Cocoa
import Carbon

/// Preferences for the chords used when submitting text from Spotlight.
final class EntryModifierViewController: NSViewController {
    private struct ChordItem {
        let title: String
        let keyPath: WritableKeyPath<EntryModifierPreferences, EntryChord>
    }

    private let items: [ChordItem] = [
        ChordItem(title: "Create Child", keyPath: \.childChord),
        ChordItem(title: "Create Sibling", keyPath: \.siblingChord),
        ChordItem(title: "New Parent", keyPath: \.newParentChord),
        ChordItem(title: "Switch to Task", keyPath: \.switchChord)
    ]

    private var chordLabels: [NSTextField] = []
    private var recordButtons: [NSButton] = []
    private var instructionLabel: NSTextField!
    private var saveButton: NSButton!

    private var editedPreferences: EntryModifierPreferences
    private var hasUnsavedChanges = false

    private var recordingIndex: Int?
    private var recordingModifiers: NSEvent.ModifierFlags = []
    private var recordingHeldKeyCodes: Set<UInt16> = []
    private var recordingMonitor: Any?

    private let defaultInstructions = "Click Record, hold modifiers or non-text keys, then press Enter. Letters, numbers, punctuation, and Space are not allowed."

    init() {
        editedPreferences = EntryModifierPreferencesManager.shared.loadModifiers()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopRecording()
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        refreshChordRows()
    }

    override func viewWillDisappear() {
        stopRecording()
        super.viewWillDisappear()
    }

    private func setupUI() {
        instructionLabel = NSTextField(wrappingLabelWithString: defaultInstructions)
        instructionLabel.font = .systemFont(ofSize: 11)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.maximumNumberOfLines = 2
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)

        let rowStack = NSStackView()
        rowStack.orientation = .vertical
        rowStack.alignment = .leading
        rowStack.spacing = 14
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rowStack)

        for (index, item) in items.enumerated() {
            let actionLabel = NSTextField(labelWithString: item.title)
            actionLabel.font = .systemFont(ofSize: 13, weight: .medium)
            actionLabel.alignment = .right
            actionLabel.setContentHuggingPriority(.required, for: .horizontal)
            actionLabel.widthAnchor.constraint(equalToConstant: 145).isActive = true

            let chordLabel = NSTextField(labelWithString: "")
            chordLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            chordLabel.textColor = .labelColor
            chordLabel.lineBreakMode = .byTruncatingMiddle
            chordLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            chordLabel.widthAnchor.constraint(equalToConstant: 240).isActive = true
            chordLabels.append(chordLabel)

            let recordButton = NSButton(title: "Record", target: self, action: #selector(toggleRecording(_:)))
            recordButton.bezelStyle = .rounded
            recordButton.tag = index
            recordButton.widthAnchor.constraint(equalToConstant: 82).isActive = true
            recordButton.setAccessibilityLabel("Record chord for \(item.title)")
            recordButtons.append(recordButton)

            let row = NSStackView(views: [actionLabel, chordLabel, recordButton])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 16
            rowStack.addArrangedSubview(row)
        }

        let restoreDefaultsButton = NSButton(
            title: "Restore Defaults",
            target: self,
            action: #selector(restoreDefaults)
        )
        restoreDefaultsButton.bezelStyle = .rounded
        restoreDefaultsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(restoreDefaultsButton)

        saveButton = NSButton(title: "Save", target: self, action: #selector(savePreferences))
        saveButton.bezelStyle = .rounded
        saveButton.isEnabled = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelChanges))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 22),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            rowStack.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 32),
            rowStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            restoreDefaultsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            restoreDefaultsButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Recording

    @objc private func toggleRecording(_ sender: NSButton) {
        if recordingIndex == sender.tag {
            stopRecording()
            refreshChordRows()
            return
        }

        stopRecording()
        recordingIndex = sender.tag
        recordingModifiers = []
        recordingHeldKeyCodes = []
        setInstructions(defaultInstructions, color: .secondaryLabelColor)

        recordingMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            guard let self else { return event }
            guard event.window === self.view.window else { return event }
            return self.handleRecordingEvent(event) ? nil : event
        }

        refreshChordRows()
    }

    private func handleRecordingEvent(_ event: NSEvent) -> Bool {
        guard let recordingIndex else { return false }
        recordingModifiers = event.modifierFlags.intersection(EntryChord.supportedModifierMask)

        switch event.type {
        case .flagsChanged:
            refreshChordRows()
            return true

        case .keyUp:
            guard EntryChordKey.isAllowed(event.keyCode) else { return false }
            recordingHeldKeyCodes.remove(event.keyCode)
            refreshChordRows()
            return true

        case .keyDown:
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                setInstructions(defaultInstructions, color: .secondaryLabelColor)
                refreshChordRows()
                return true
            }

            if EntryChordKey.isSubmissionKey(event.keyCode) {
                guard !event.isARepeat else { return true }
                let chord = EntryChord(
                    modifiers: recordingModifiers,
                    heldKeyCodes: recordingHeldKeyCodes
                )
                guard !chord.isEmpty else {
                    NSSound.beep()
                    setInstructions(
                        "Plain Enter is reserved for creating an independent task.",
                        color: .systemRed
                    )
                    return true
                }

                editedPreferences[keyPath: items[recordingIndex].keyPath] = chord
                hasUnsavedChanges = true
                saveButton.isEnabled = true
                stopRecording()
                setInstructions(defaultInstructions, color: .secondaryLabelColor)
                refreshChordRows()
                return true
            }

            guard EntryChordKey.isAllowed(event.keyCode) else {
                NSSound.beep()
                setInstructions(
                    "That key can type into Spotlight. Choose modifiers or a non-text key.",
                    color: .systemRed
                )
                return true
            }

            recordingHeldKeyCodes.insert(event.keyCode)
            refreshChordRows()
            return true

        default:
            return false
        }
    }

    private func stopRecording() {
        if let recordingMonitor {
            NSEvent.removeMonitor(recordingMonitor)
        }
        recordingMonitor = nil
        recordingIndex = nil
        recordingModifiers = []
        recordingHeldKeyCodes = []
    }

    private func refreshChordRows() {
        guard chordLabels.count == items.count else { return }

        for index in items.indices {
            if recordingIndex == index {
                let pendingChord = EntryChord(
                    modifiers: recordingModifiers,
                    heldKeyCodes: recordingHeldKeyCodes
                )
                chordLabels[index].stringValue = pendingChord.isEmpty
                    ? "Hold chord, then Enter"
                    : pendingChord.displayNameWithEnter
                chordLabels[index].textColor = .labelColor
                recordButtons[index].title = "Cancel"
            } else {
                chordLabels[index].stringValue = editedPreferences[
                    keyPath: items[index].keyPath
                ].displayNameWithEnter
                chordLabels[index].textColor = .labelColor
                recordButtons[index].title = "Record"
            }
        }
    }

    private func setInstructions(_ text: String, color: NSColor) {
        instructionLabel.stringValue = text
        instructionLabel.textColor = color
    }

    // MARK: - Actions

    @objc private func savePreferences() {
        stopRecording()

        do {
            try EntryModifierPreferencesManager.shared.saveModifiers(editedPreferences)
            hasUnsavedChanges = false
            saveButton.isEnabled = false
            refreshChordRows()
            showAlert(title: "Preferences Saved", message: "Entry chords have been updated.")
        } catch {
            showAlert(title: "Invalid Configuration", message: error.localizedDescription)
        }
    }

    @objc private func cancelChanges() {
        stopRecording()

        if hasUnsavedChanges {
            let alert = NSAlert()
            alert.messageText = "Discard Changes?"
            alert.informativeText = "You have unsaved Entry Chord changes."
            alert.addButton(withTitle: "Discard")
            alert.addButton(withTitle: "Keep Editing")
            alert.alertStyle = .warning

            guard alert.runModal() == .alertFirstButtonReturn else {
                refreshChordRows()
                return
            }

            editedPreferences = EntryModifierPreferencesManager.shared.loadModifiers()
            hasUnsavedChanges = false
            saveButton.isEnabled = false
            setInstructions(defaultInstructions, color: .secondaryLabelColor)
            refreshChordRows()
        }

        view.window?.close()
    }

    @objc private func restoreDefaults() {
        stopRecording()

        let defaults = EntryModifierPreferences.defaults()
        let alert = NSAlert()
        alert.messageText = "Restore Default Entry Chords?"
        alert.informativeText = "This resets the chords to:\n• Child: \(defaults.childChord.displayNameWithEnter)\n• Sibling: \(defaults.siblingChord.displayNameWithEnter)\n• New Parent: \(defaults.newParentChord.displayNameWithEnter)\n• Switch: \(defaults.switchChord.displayNameWithEnter)"
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        guard alert.runModal() == .alertFirstButtonReturn else {
            refreshChordRows()
            return
        }

        EntryModifierPreferencesManager.shared.resetToDefaults()
        editedPreferences = defaults
        hasUnsavedChanges = false
        saveButton.isEnabled = false
        setInstructions(defaultInstructions, color: .secondaryLabelColor)
        refreshChordRows()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
