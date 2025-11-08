import SwiftUI

struct SpotlightView: View {
    @Environment(\.dismiss) var dismiss
    @State private var text: String = ""
    @State private var selectedParent: Task?

    let appState: AppState
    let taskManager: TaskManager
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Type your task...", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: UIConstants.spotlightFontSize))
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        // Default Enter without modifiers
                        handleSubmit(modifiers: [])
                    }

                if let parent = selectedParent {
                    Text("→ \(parent.text)")
                        .foregroundColor(UIConstants.systemGray)
                        .font(.system(size: 14))
                }

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(UIConstants.systemGray)
                }
                .buttonStyle(.plain)
            }
            .padding(UIConstants.spotlightPadding)
        }
        .frame(width: UIConstants.spotlightWidth, height: UIConstants.spotlightHeight)
        .background(Color.white.opacity(0.95))
        .cornerRadius(UIConstants.spotlightBorderRadius)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onAppear {
            isTextFieldFocused = true
        }
        // Handle keyboard events with custom responder
        .background(KeyboardEventHandler(
            onUpArrow: loadCurrentTask,
            onDownArrow: clearText,
            onEscape: onClose,
            onEnter: { modifiers in handleSubmit(modifiers: modifiers) },
            onCmdP: openParentSelector
        ))
    }

    @FocusState private var isTextFieldFocused: Bool

    private func handleSubmit(modifiers: EventModifiers) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ToastManager.shared.showError("⚠️ Task name required")
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if we have a selected parent from Cmd+P
        if let parent = selectedParent {
            // Creating with explicit parent
            let setCurrent = modifiers.contains(.option)
            _ = taskManager.createTask(text: trimmedText, parent: parent, setCurrent: setCurrent)

            let message = setCurrent
                ? "✓ Task created under \(parent.text) (current)"
                : "✓ Task created under \(parent.text)"
            ToastManager.shared.showSuccess(message)

            text = ""
            selectedParent = nil
            onClose()
            return
        }

        // Shift+Enter: Create child of current
        if modifiers.contains(.shift) && !modifiers.contains(.command) && !modifiers.contains(.option) {
            guard let current = taskManager.getCurrentTask() else {
                ToastManager.shared.showError("⚠️ No parent task. Create a top-level task first.")
                return
            }
            _ = taskManager.createTask(text: trimmedText, parent: current, setCurrent: true)
            ToastManager.shared.showSuccess("✓ Child created under \(current.text) (current)")
            text = ""
            onClose()
            return
        }

        // Cmd+Option+Enter: Create sibling and switch
        if modifiers.contains(.command) && modifiers.contains(.option) && !modifiers.contains(.shift) {
            guard let current = taskManager.getCurrentTask() else {
                ToastManager.shared.showError("⚠️ No reference task. Create a task first.")
                return
            }
            _ = taskManager.createTask(text: trimmedText, parent: current.parent, setCurrent: true)
            ToastManager.shared.showSuccess("✓ Sibling created (current)")
            text = ""
            onClose()
            return
        }

        // Cmd+Enter: Create sibling without switching
        if modifiers.contains(.command) && !modifiers.contains(.option) && !modifiers.contains(.shift) {
            guard let current = taskManager.getCurrentTask() else {
                ToastManager.shared.showError("⚠️ No reference task. Create a task first.")
                return
            }
            _ = taskManager.createTask(text: trimmedText, parent: current.parent, setCurrent: false)
            ToastManager.shared.showSuccess("✓ Sibling created")
            text = ""
            onClose()
            return
        }

        // Option+Enter: Create top-level and switch
        if modifiers.contains(.option) && !modifiers.contains(.shift) && !modifiers.contains(.command) {
            _ = taskManager.createTask(text: trimmedText, parent: nil, setCurrent: true)
            ToastManager.shared.showSuccess("✓ Task created (current)")
            text = ""
            onClose()
            return
        }

        // Plain Enter: Create top-level without switching
        _ = taskManager.createTask(text: trimmedText, parent: nil, setCurrent: false)
        ToastManager.shared.showSuccess("✓ Task created")
        text = ""
        onClose()
    }

    private func loadCurrentTask() {
        // Up arrow: Load current task for editing (idempotent)
        if let current = taskManager.getCurrentTask() {
            text = current.text
        }
        // If already loaded or no current, do nothing (idempotent)
    }

    private func clearText() {
        // Down arrow: Clear text (idempotent)
        text = ""
    }

    private func openParentSelector() {
        // Cmd+P: Open parent selector (Phase 5 implementation)
        ToastManager.shared.showError("⚠️ Parent selection coming in Phase 5")
    }
}

// Custom keyboard event handler using NSEvent monitoring
struct KeyboardEventHandler: NSViewRepresentable {
    let onUpArrow: () -> Void
    let onDownArrow: () -> Void
    let onEscape: () -> Void
    let onEnter: (EventModifiers) -> Void
    let onCmdP: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyEventView()
        view.onUpArrow = onUpArrow
        view.onDownArrow = onDownArrow
        view.onEscape = onEscape
        view.onEnter = onEnter
        view.onCmdP = onCmdP
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyEventView: NSView {
        var onUpArrow: (() -> Void)?
        var onDownArrow: (() -> Void)?
        var onEscape: (() -> Void)?
        var onEnter: ((EventModifiers) -> Void)?
        var onCmdP: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 126: // Up arrow
                onUpArrow?()
            case 125: // Down arrow
                onDownArrow?()
            case 53: // Escape
                onEscape?()
            case 36: // Return/Enter
                var modifiers = EventModifiers()
                if event.modifierFlags.contains(.shift) {
                    modifiers.insert(.shift)
                }
                if event.modifierFlags.contains(.command) {
                    modifiers.insert(.command)
                }
                if event.modifierFlags.contains(.option) {
                    modifiers.insert(.option)
                }
                onEnter?(modifiers)
            case 35: // P key
                if event.modifierFlags.contains(.command) {
                    onCmdP?()
                } else {
                    super.keyDown(with: event)
                }
            default:
                super.keyDown(with: event)
            }
        }
    }
}
