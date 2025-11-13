//
//  RootSelectorViewController.swift
//  HoldApp
//
//  Displays list of root tasks for selection (Cmd+Shift+R)
//  Minimal, terminal-inspired aesthetic matching Hold's vision
//

import Cocoa

class RootSelectorViewController: NSViewController {

    // MARK: - Properties

    private var tableView: RootTableView!
    private var scrollView: NSScrollView!
    private var roots: [(id: String, text: String)] = []
    private var currentRootId: String?

    /// Called when user selects a root (presses Enter)
    var onRootSelected: ((String, String) -> Void)?

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
        tableView = RootTableView(frame: scrollView.bounds)
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
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("RootColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        view.addSubview(scrollView)
    }

    // MARK: - Public Methods

    /// Update the list of roots and current root ID
    func updateRoots(_ roots: [(id: String, text: String)], currentRootId: String?) {
        self.roots = roots
        self.currentRootId = currentRootId

        tableView.reloadData()

        // Select current root if it exists
        if let currentRootId = currentRootId,
           let currentIndex = roots.firstIndex(where: { $0.id == currentRootId }) {
            tableView.selectRowIndexes(IndexSet(integer: currentIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(currentIndex)
        } else if !roots.isEmpty {
            // Select first root if no current root
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    /// Focus the table view for keyboard navigation
    func focusTableView() {
        let success = view.window?.makeFirstResponder(tableView)
        print("🌳 focusTableView called - success: \(success ?? false)")
        print("🌳 Current first responder: \(view.window?.firstResponder?.className ?? "nil")")
        print("🌳 Table view acceptsFirstResponder: \(tableView.acceptsFirstResponder)")
    }

    override func keyDown(with event: NSEvent) {
        // Handle Escape key (same as Spotlight)
        if event.keyCode == 53 { // Escape key
            print("⎋ [RootViewController] Escape pressed - calling onCancel")
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - Actions

    @objc private func handleDoubleClick() {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < roots.count {
            let root = roots[selectedRow]
            onRootSelected?(root.id, root.text)
        }
    }
}

// MARK: - RootTableViewDelegate

extension RootSelectorViewController: RootTableViewDelegate {
    func rootTableViewDidPressEnter(_ tableView: RootTableView) {
        print("⏎ Enter pressed on row: \(tableView.selectedRow)")
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < roots.count {
            let root = roots[selectedRow]
            print("⏎ Selecting root: \(root.text)")
            onRootSelected?(root.id, root.text)
        }
    }

    func rootTableViewDidPressEscape(_ tableView: RootTableView) {
        print("⎋ Escape pressed - calling onCancel")
        onCancel?()
    }
}

// MARK: - NSTableViewDataSource

extension RootSelectorViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return roots.count
    }
}

// MARK: - NSTableViewDelegate

extension RootSelectorViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < roots.count else { return nil }

        let root = roots[row]
        let isCurrent = (root.id == currentRootId)

        // Create cell view
        let cellView = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 32))

        // Create label
        let label = NSTextField(labelWithString: root.text)
        label.font = isCurrent ? NSFont.systemFont(ofSize: 14, weight: .semibold) : NSFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = isCurrent ? .white : NSColor.white.withAlphaComponent(0.7)
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 20, y: 6, width: tableView.bounds.width - 40, height: 20)
        label.refusesFirstResponder = true

        cellView.addSubview(label)

        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        print("🌳 shouldSelectRow called - row: \(row)")
        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        print("🌳 Selection changed to row: \(selectedRow)")
        if selectedRow >= 0 && selectedRow < roots.count {
            print("🌳 Selected root: \(roots[selectedRow].text)")
        }
    }
}
