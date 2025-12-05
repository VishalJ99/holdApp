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
    private var parents: [LocalTaskStore.TreeTask] = []
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
        tableView.intercellSpacing = NSSize(width: 0, height: 0) // No gap between cells for continuous lines
        tableView.rowHeight = 36 // Increased height to maintain breathing room
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
    /// parents array should be ordered by DFS tree traversal
    func updateParents(_ parents: [LocalTaskStore.TreeTask], currentIndex: Int) {
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
            onParentSelected?(parent.task.id, parent.task.text, false)
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
                print("⏎ Enter pressed (Ctrl: \(hasCtrl)) - selecting parent: \(parent.task.text)")
                // Ctrl+Enter = create and switch, plain Enter = create only
                onParentSelected?(parent.task.id, parent.task.text, hasCtrl)
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
            print("⏎ Enter pressed - selecting parent: \(parent.task.text)")
            onParentSelected?(parent.task.id, parent.task.text, false)
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

        let treeTask = parents[row]
        let isCurrent = (row == currentIndex)
        
        // 1. Create Cell View
        // Use rowHeight from tableView (36)
        let cellView = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 36))

        // 2. Tree Line View (Custom Drawing)
        // Width needed: depth * indent. If depth=0, width=0.
        // Let's give it enough width to cover the indentation.
        let indent: CGFloat = 20
        // Shift x to 10 so the vertical line (at indent/2 = 10) aligns with the parent's icon (at 20)
        // Width: depth * indent + extra to reach near the icon
        // Also need width for the descender line of the current node (if it has children)
        // The descender line is at x = depth * indent + halfIndent
        let treeWidth = CGFloat(max(1, treeTask.depth + 1)) * indent + 10
        let treeView = TreeLineView(frame: NSRect(x: 10, y: 0, width: treeWidth, height: 36))
        treeView.treeTask = treeTask
        treeView.indent = indent
        cellView.addSubview(treeView)
        
        // 3. Determine Icon
        let iconString = (treeTask.depth == 0) ? "▼" : "●"
        
        // 4. Icon Label
        let iconLabel = NSTextField(labelWithString: iconString)
        iconLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        iconLabel.textColor = (treeTask.depth == 0) ? NSColor.white : NSColor.white.withAlphaComponent(0.5)
        iconLabel.sizeToFit()
        
        // Position icon:
        // Root (depth 0): x = 20.
        // Child (depth 1): x = 20 + 20 = 40.
        let iconX: CGFloat = 20 + CGFloat(treeTask.depth) * indent
        
        // Center vertically.
        // For root "▼" (height ~12), y should be ~12 (in 36 height).
        // For bullet "●" (height ~10), y should be ~13.
        let iconY: CGFloat = (treeTask.depth == 0) ? 12 : 13
        iconLabel.frame.origin = CGPoint(x: iconX, y: iconY)
        cellView.addSubview(iconLabel)
        
        // 5. Text Label
        let textLabel = NSTextField(labelWithString: treeTask.task.text)
        textLabel.font = isCurrent ? NSFont.systemFont(ofSize: 14, weight: .semibold) : NSFont.systemFont(ofSize: 14, weight: .regular)
        textLabel.textColor = isCurrent ? .white : NSColor.white.withAlphaComponent(0.7)
        textLabel.lineBreakMode = .byTruncatingTail
        
        let textX = iconLabel.frame.maxX + 8
        let remainingWidth = tableView.bounds.width - textX - 20
        textLabel.frame = NSRect(x: textX, y: 8, width: remainingWidth, height: 20)
        textLabel.refusesFirstResponder = true
        
        cellView.addSubview(textLabel)

        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < parents.count {
            print("🔵 Selected parent: \(parents[selectedRow].task.text)")
        }
    }
}

// MARK: - Custom Views

class TreeLineView: NSView {
    var treeTask: LocalTaskStore.TreeTask?
    var indent: CGFloat = 20
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let treeTask = treeTask else { return }
        
        let path = NSBezierPath()
        path.lineWidth = 1.0
        NSColor.white.withAlphaComponent(0.3).setStroke()
        
        // Center of a column
        let halfIndent = indent / 2
        
        // 1. Draw Ancestor Lines
        if treeTask.depth > 0 {
            // Iterate columns 0 to depth-2
            for i in 0..<(treeTask.depth - 1) {
                if i + 1 < treeTask.ancestorsAreLast.count {
                    let isLast = treeTask.ancestorsAreLast[i + 1]
                    if !isLast {
                        // Draw full vertical line
                        let x = CGFloat(i) * indent + halfIndent
                        path.move(to: NSPoint(x: x, y: 0))
                        path.line(to: NSPoint(x: x, y: bounds.height))
                    }
                }
            }
            
            // 2. Draw Current Node Connector (L or T shape)
            // This is at column index = depth - 1
            let col = treeTask.depth - 1
            let x = CGFloat(col) * indent + halfIndent
            let centerY = bounds.height / 2
            
            // Horizontal line: from center to right edge
            path.move(to: NSPoint(x: x, y: centerY))
            
            // Calculate end point (center of icon - gap)
            // Icon is at: halfIndent + depth * indent relative to this view
            let iconCenterX = halfIndent + CGFloat(treeTask.depth) * indent
            let gap: CGFloat = 6.0
            path.line(to: NSPoint(x: iconCenterX - gap, y: centerY))
            
            // Vertical line
            path.move(to: NSPoint(x: x, y: 0)) // Start from top
            if treeTask.isLast {
                // Stop at center
                path.line(to: NSPoint(x: x, y: centerY))
            } else {
                // Go all the way down
                path.line(to: NSPoint(x: x, y: bounds.height))
            }
        }
        
        // 3. Draw Descender Line (if has children)
        // This connects this node to its first child
        if treeTask.hasChildren {
            // Descender is at the NEXT column index
            let col = treeTask.depth
            let x = CGFloat(col) * indent + halfIndent
            let centerY = bounds.height / 2
            
            // Draw from center downwards
            path.move(to: NSPoint(x: x, y: centerY))
            path.line(to: NSPoint(x: x, y: bounds.height))
        }
        
        path.stroke()
    }
    
    // Ensure view is transparent
    override var isOpaque: Bool { false }
}
