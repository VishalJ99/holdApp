//
//  ParentSelectorViewController.swift
//  HoldApp
//
//  Displays list of ancestor tasks for parent selection (Cmd+P in Spotlight)
//  Minimal, terminal-inspired aesthetic matching Hold's vision
//

import Cocoa

class ParentSelectorViewController: NSViewController {

    // MARK: - Properties

    private var tableView: LeafTableView!  // Reuse LeafTableView for keyboard handling
    private var scrollView: NSScrollView!
    private var parents: [(id: String, text: String)] = []
    private var currentIndex: Int = -1  // Index of current task in the list

    /// Called when user selects a parent (presses Enter or Ctrl+Enter)
    var onParentSelected: ((String, String, Bool) -> Void)?  // (parentId, parentText, shouldSwitch)

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

        // Create custom table view (reuse LeafTableView)
        tableView = LeafTableView(frame: scrollView.bounds)
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = []
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.rowHeight = 32
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.keyboardDelegate = self
        tableView.focusRingType = .none
        tableView.target = self
        tableView.doubleAction = #selector(handleDoubleClick)

        // Add single column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ParentColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        view.addSubview(scrollView)
    }

    // MARK: - Public Methods

    /// Update the list of parents and current task index
    /// parents array should be ordered: [root, ..., parent, current]
    func updateParents(_ parents: [(id: String, text: String)], currentIndex: Int) {
        self.parents = parents
        self.currentIndex = currentIndex

        tableView.reloadData()

        // Select current task by default (last in list)
        if currentIndex >= 0 && currentIndex < parents.count {
            tableView.selectRowIndexes(IndexSet(integer: currentIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(currentIndex)
        }
    }

    /// Focus the table view for keyboard navigation
    func focusTableView() {
        let success = view.window?.makeFirstResponder(tableView)
        print("🔍 focusTableView called - success: \(success ?? false)")
    }

    override func keyDown(with event: NSEvent) {
        // Handle Escape key
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
        if selectedRow >= 0 && selectedRow < parents.count {
            let parent = parents[selectedRow]
            // Double-click = Enter (no switch)
            onParentSelected?(parent.id, parent.text, false)
        }
    }

    // Override to handle Ctrl+Enter for "create and switch"
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Check for Enter key with Ctrl modifier
        if event.keyCode == 36 {  // Enter key
            let hasCtrl = event.modifierFlags.contains(.control)
            let selectedRow = tableView.selectedRow

            if selectedRow >= 0 && selectedRow < parents.count {
                let parent = parents[selectedRow]
                print("⏎ Enter pressed (Ctrl: \(hasCtrl)) - selecting parent: \(parent.text)")
                // Ctrl+Enter = create and switch, plain Enter = create only
                onParentSelected?(parent.id, parent.text, hasCtrl)
                return true
            }
        }

        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - LeafTableViewDelegate

extension ParentSelectorViewController: LeafTableViewDelegate {
    func leafTableViewDidPressEnter(_ tableView: LeafTableView) {
        // Plain Enter = create child without switching (shouldSwitch: false)
        // Ctrl+Enter is handled by performKeyEquivalent (shouldSwitch: true)
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < parents.count {
            let parent = parents[selectedRow]
            print("⏎ Enter pressed - selecting parent: \(parent.text)")
            onParentSelected?(parent.id, parent.text, false)
        }
    }

    func leafTableViewDidPressEscape(_ tableView: LeafTableView) {
        print("⎋ Escape pressed - calling onCancel")
        onCancel?()
    }
}

// MARK: - NSTableViewDataSource

extension ParentSelectorViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return parents.count
    }
}

// MARK: - NSTableViewDelegate

extension ParentSelectorViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < parents.count else { return nil }

        let parent = parents[row]
        let isCurrent = (row == currentIndex)
        let position = row + 1
        let total = parents.count

        // Create cell view
        let cellView = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 32))

        // Create label with position indicator
        let label = NSTextField(labelWithString: "[\(position)/\(total)] \(parent.text)")
        label.font = isCurrent ? NSFont.systemFont(ofSize: 14, weight: .semibold) : NSFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = isCurrent ? .white : NSColor.white.withAlphaComponent(0.7)
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 20, y: 6, width: tableView.bounds.width - 40, height: 20)
        label.refusesFirstResponder = true  // Prevent label from stealing keyboard focus from table view

        cellView.addSubview(label)

        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < parents.count {
            print("🔵 Selected parent: \(parents[selectedRow].text)")
        }
    }
}
