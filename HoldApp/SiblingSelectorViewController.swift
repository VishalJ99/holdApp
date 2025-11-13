//
//  SiblingSelectorViewController.swift
//  HoldApp
//
//  Displays list of sibling tasks for selection (Cmd+Shift+S)
//  Minimal, terminal-inspired aesthetic matching Hold's vision
//

import Cocoa

class SiblingSelectorViewController: NSViewController {

    // MARK: - Properties

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var siblings: [(id: String, text: String)] = []
    private var currentIndex: Int = 0

    /// Called when user selects a sibling (presses Enter)
    var onSiblingSelected: ((String, String) -> Void)?

    /// Called when user cancels (presses Escape)
    var onCancel: (() -> Void)?

    // MARK: - Lifecycle

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        self.view.wantsLayer = true

        setupTableView()
    }

    private func setupTableView() {
        // Create scroll view
        scrollView = NSScrollView(frame: view.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear

        // Create table view
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = []
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.rowHeight = 32
        tableView.selectionHighlightStyle = .none
        tableView.allowsEmptySelection = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.focusRingType = .none

        // Add single column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SiblingColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        view.addSubview(scrollView)
    }

    // MARK: - Public Methods

    /// Update the list of siblings and current index
    func updateSiblings(_ siblings: [(id: String, text: String)], currentIndex: Int) {
        self.siblings = siblings
        self.currentIndex = currentIndex

        tableView.reloadData()

        // Select current sibling
        if currentIndex >= 0 && currentIndex < siblings.count {
            tableView.selectRowIndexes(IndexSet(integer: currentIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(currentIndex)
        }
    }

    /// Focus the table view for keyboard navigation
    func focusTableView() {
        view.window?.makeFirstResponder(tableView)
    }

    // MARK: - Keyboard Handling

    override func keyDown(with event: NSEvent) {
        // Handle Escape key
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        // Handle Enter key
        if event.keyCode == 36 {
            let selectedRow = tableView.selectedRow
            if selectedRow >= 0 && selectedRow < siblings.count {
                let sibling = siblings[selectedRow]
                onSiblingSelected?(sibling.id, sibling.text)
            }
            return
        }

        // Handle Arrow keys - Up
        if event.keyCode == 126 {
            let selectedRow = tableView.selectedRow
            if selectedRow > 0 {
                tableView.selectRowIndexes(IndexSet(integer: selectedRow - 1), byExtendingSelection: false)
                tableView.scrollRowToVisible(selectedRow - 1)
            }
            return
        }

        // Handle Arrow keys - Down
        if event.keyCode == 125 {
            let selectedRow = tableView.selectedRow
            if selectedRow < siblings.count - 1 {
                tableView.selectRowIndexes(IndexSet(integer: selectedRow + 1), byExtendingSelection: false)
                tableView.scrollRowToVisible(selectedRow + 1)
            }
            return
        }

        super.keyDown(with: event)
    }
}

// MARK: - NSTableViewDataSource

extension SiblingSelectorViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return siblings.count
    }
}

// MARK: - NSTableViewDelegate

extension SiblingSelectorViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < siblings.count else { return nil }

        let sibling = siblings[row]
        let isCurrent = (row == currentIndex)
        let position = row + 1
        let total = siblings.count

        // Create cell view
        let cellView = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 32))

        // Create label with position indicator
        let label = NSTextField(labelWithString: "[\(position)/\(total)] \(sibling.text)")
        label.font = isCurrent ? NSFont.systemFont(ofSize: 14, weight: .semibold) : NSFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = isCurrent ? .white : NSColor.white.withAlphaComponent(0.7)
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 20, y: 6, width: tableView.bounds.width - 40, height: 20)

        cellView.addSubview(label)

        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
}
