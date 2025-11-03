import Cocoa

class SpotlightViewController: NSViewController {

    private var textField: NSTextField!

    var onEnterPressed: ((String) -> Void)?
    var onEscapePressed: (() -> Void)?

    override func loadView() {
        // Create the main view
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 60))

        // Create text field
        textField = NSTextField(frame: NSRect(x: 20, y: 15, width: 560, height: 30))
        textField.placeholderString = "Type something..."
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
            onEscapePressed?()
            return
        }
        super.keyDown(with: event)
    }
}

extension SpotlightViewController: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Enter key pressed
            let text = textField.stringValue
            if !text.isEmpty {
                onEnterPressed?(text)
            }
            return true
        }
        return false
    }
}
