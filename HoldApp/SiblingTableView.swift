//
//  SiblingTableView.swift
//  HoldApp
//
//  Custom NSTableView subclass that forwards keyboard events to delegate
//  NSTableView intercepts keyboard events internally, so we override keyDown()
//  to handle arrow keys, Enter, and Escape before NSTableView processes them
//

import Cocoa

protocol SiblingTableViewDelegate: AnyObject {
    func siblingTableViewDidPressEnter(_ tableView: SiblingTableView)
    func siblingTableViewDidPressEscape(_ tableView: SiblingTableView)
}

class SiblingTableView: NSTableView {

    weak var keyboardDelegate: SiblingTableViewDelegate?

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        print("🔴 SiblingTableView.keyDown called - keyCode: \(event.keyCode)")

        // Handle Escape key
        if event.keyCode == 53 {
            keyboardDelegate?.siblingTableViewDidPressEscape(self)
            return
        }

        // Handle Enter key
        if event.keyCode == 36 {
            keyboardDelegate?.siblingTableViewDidPressEnter(self)
            return
        }

        // Let NSTableView handle arrow keys naturally (it already does row selection)
        // This includes: Up (126), Down (125), Page Up, Page Down, Home, End
        print("🔴 Calling super.keyDown for keyCode: \(event.keyCode)")
        super.keyDown(with: event)
    }
}
