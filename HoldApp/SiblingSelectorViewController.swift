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

    private var tableView: SiblingTableView!
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

        // Create custom table view
        tableView = SiblingTableView(frame: scrollView.bounds)
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = []
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.rowHeight = 32
        tableView.selectionHighlightStyle = .regular  // Changed from .none to enable selection
        tableView.allowsEmptySelection = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.keyboardDelegate = self
        tableView.focusRingType = .none
        tableView.target = self
        tableView.doubleAction = #selector(handleDoubleClick)

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
        let success = view.window?.makeFirstResponder(tableView)
        print("🔍 focusTableView called - success: \(success ?? false)")
        print("🔍 Current first responder: \(view.window?.firstResponder?.className ?? "nil")")
        print("🔍 Table view acceptsFirstResponder: \(tableView.acceptsFirstResponder)")
    }

    override func keyDown(with event: NSEvent) {
        // Handle Escape key (same as Spotlight)
        if event.keyCode == 53 { // Escape key
            print("⎋ [ViewController] Escape pressed - calling onCancel")
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - Actions

    @objc private func handleDoubleClick() {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < siblings.count {
            let sibling = siblings[selectedRow]
            onSiblingSelected?(sibling.id, sibling.text)
        }
    }
}

// MARK: - SiblingTableViewDelegate

extension SiblingSelectorViewController: SiblingTableViewDelegate {
    func siblingTableViewDidPressEnter(_ tableView: SiblingTableView) {
        print("⏎ Enter pressed on row: \(tableView.selectedRow)")
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < siblings.count {
            let sibling = siblings[selectedRow]
            print("⏎ Selecting sibling: \(sibling.text)")
            onSiblingSelected?(sibling.id, sibling.text)
        }
    }

    func siblingTableViewDidPressEscape(_ tableView: SiblingTableView) {
        print("⎋ Escape pressed - calling onCancel")
        onCancel?()
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
        label.refusesFirstResponder = true  // Prevent label from stealing keyboard focus from table view

        cellView.addSubview(label)

        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        print("🔵 shouldSelectRow called - row: \(row)")
        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        print("🔵 Selection changed to row: \(selectedRow)")
        if selectedRow >= 0 && selectedRow < siblings.count {
            print("🔵 Selected sibling: \(siblings[selectedRow].text)")
        }
    }
}
