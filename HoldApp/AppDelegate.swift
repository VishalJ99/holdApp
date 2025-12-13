//
//  AppDelegate.swift
//  HoldApp
//
//  Created by Vishal Jain on 03/11/2025.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var spotlightPanel: SpotlightPanel!
    private var spotlightViewController: SpotlightViewController!
    private var leafSelectorPanel: SwiftUILeafSelectorPanel!
    private var rootSelectorPanel: SwiftUIRootSelectorPanel!
    private var outlineParentSelectorPanel: OutlineParentSelectorPanel!
    private var hotkeyManager: HotkeyManager!
    private var logManager: LogManager!
    private var statusItem: NSStatusItem!
    private var preferencesWindowController: PreferencesWindowController?

    // Nuke confirmation state
    private var nukeConfirmationPending: Bool = false
    private var nukeConfirmationTimer: Timer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Close the default storyboard window (LSUIElement app doesn't need main window)
        for window in NSApplication.shared.windows {
            window.close()
        }

        // Initialize components
        logManager = LogManager()

        // Setup menu bar
        setupMenuBar()

        // Create Spotlight UI
        spotlightViewController = SpotlightViewController()
        spotlightPanel = SpotlightPanel()
        spotlightPanel.contentViewController = spotlightViewController

        // Setup callbacks
        spotlightViewController.onTaskSubmit = { [weak self] text, type in
            self?.handleTaskCreation(text: text, type: type)
        }

        spotlightViewController.onTaskUpdate = { [weak self] taskId, newText in
            self?.handleTaskUpdate(taskId: taskId, newText: newText)
        }

        spotlightViewController.onCancel = { [weak self] in
            self?.spotlightViewController.resetEditMode()
            self?.spotlightPanel.hide()
        }

        spotlightViewController.onParentSelectorRequested = { [weak self] text in
            self?.showParentSelector(taskText: text)
        }

        // Create Leaf Selector UI (SwiftUI-based)
        leafSelectorPanel = SwiftUILeafSelectorPanel()
        leafSelectorPanel.onLeafSelected = { [weak self] taskId, taskText in
            self?.handleLeafSelection(taskId: taskId, taskText: taskText)
        }
        leafSelectorPanel.onCancel = { [weak self] in
            self?.leafSelectorPanel.hide()
        }

        // Create Root Selector UI (SwiftUI-based)
        rootSelectorPanel = SwiftUIRootSelectorPanel()
        rootSelectorPanel.onRootSelected = { [weak self] rootId, rootText in
            self?.handleRootSelection(rootId: rootId, rootText: rootText)
        }
        rootSelectorPanel.onCancel = { [weak self] in
            self?.rootSelectorPanel.hide()
        }

        // Create Parent Selector UI (OutlineView-based)
        outlineParentSelectorPanel = OutlineParentSelectorPanel()
        outlineParentSelectorPanel.onParentSelected = { [weak self] parentId, parentText, shouldSwitch in
            self?.handleParentSelection(parentId: parentId, parentText: parentText, shouldSwitch: shouldSwitch)
        }
        outlineParentSelectorPanel.onCancel = { [weak self] in
            self?.handleParentSelectorCancelled()
        }

        // Setup hotkeys
        hotkeyManager = HotkeyManager()
        hotkeyManager.onShowHotkey = { [weak self] in
            self?.spotlightPanel.show()
        }
        // Note: Escape is handled locally by each panel's keyDown() method
        hotkeyManager.onSiblingSelector = { [weak self] in
            self?.showLeafSelector()
        }
        hotkeyManager.onRootSelector = { [weak self] in
            self?.showRootSelector()
        }
        hotkeyManager.onDismiss = { [weak self] in
            self?.dismissCurrentTask()
        }
        hotkeyManager.onNuke = { [weak self] in
            self?.handleNuke()
        }

        // Listen for hotkey preference changes
        NotificationCenter.default.addObserver(
            forName: .hotkeyPreferencesChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hotkeyManager?.reloadHotkeys()
        }

        hotkeyManager.registerHotkeys()

        // Initialize app state by syncing local storage with CloudKit
        initializeAppState()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // Load custom icon from Assets.xcassets
            if let icon = NSImage(named: "hold_icon") {
                icon.size = NSSize(width: 44, height: 44)  // Testing full size
                icon.isTemplate = true  // Adapts to light/dark mode
                button.image = icon
            }
        }

        // Create menu
        let menu = NSMenu()

        menu.addItem(NSMenuItem(
            title: "Show Spotlight",
            action: #selector(showSpotlightFromMenu),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Hold",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    @objc private func showSpotlightFromMenu() {
        spotlightPanel.show()
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showWindow(nil)
    }

    // MARK: - Task Creation

    private func handleTaskCreation(text: String, type: TaskCreationType) {
        switch type {
        case .topLevel:
            createTopLevelTask(text: text, switchTo: false)

        case .topLevelAndSwitch:
            createTopLevelTask(text: text, switchTo: true)

        case .child:
            guard let current = AppState.shared.currentTask else {
                ToastManager.shared.show("⚠️ No parent task. Create a top-level task first.", type: .error)
                return
            }
            createChildTask(text: text, parent: current)

        case .sibling:
            guard let current = AppState.shared.currentTask else {
                ToastManager.shared.show("⚠️ No reference task. Create a task first.", type: .error)
                return
            }
            createSiblingTask(text: text, reference: current, switchTo: false)

        case .siblingAndSwitch:
            guard let current = AppState.shared.currentTask else {
                ToastManager.shared.show("⚠️ No reference task. Create a task first.", type: .error)
                return
            }
            createSiblingTask(text: text, reference: current, switchTo: true)
        }

        spotlightPanel.hide()
    }

    private func createTopLevelTask(text: String, switchTo: Bool) {
        let parentId: String? = nil
        let rootId: String? = nil  // Top-level task IS the root

        print("📝 [Task Creation] Type: topLevel")
        print("🌲 [Task Creation] root_id: nil (this task IS the root)")

        // Generate task ID
        let taskId = UUID().uuidString
        let timestamp = Date()

        // Save to local storage (instant, no network)
        LocalTaskStore.shared.saveTask(
            id: taskId,
            text: text,
            timestamp: timestamp,
            parent_id: parentId,
            root_id: rootId,
            isCompleted: false
        )

        // Auto-set as current if: explicitly requested OR no current task exists (empty state)
        let shouldSetAsCurrent = switchTo || AppState.shared.currentTask == nil

        if shouldSetAsCurrent {
            AppState.shared.setCurrent(id: taskId, text: text, parentId: parentId, rootId: rootId)

            // Update pointer with display info (top-level has no hierarchy)
            CloudKitManager.shared.updateCurrentTaskPointer(
                taskId: taskId,
                text: text,
                parentId: nil,
                rootId: nil,
                parentTaskText: nil,
                rootTaskText: nil,
                showEllipsis: false,
                siblingPosition: nil,
                siblingCount: nil
            ) { error in
                if let error = error {
                    print("⚠️ [AppDelegate] Pointer update failed: \(error.localizedDescription)")
                }
            }

            ToastManager.shared.show("✓ Task created (current)", type: .success)
        } else {
            ToastManager.shared.show("✓ Task created", type: .success)
        }

        // Log to file for backup
        logManager.log(text: text, id: taskId, parentId: parentId, rootId: rootId)
    }

    private func createChildTask(text: String, parent: TaskReference) {
        // Calculate root_id: inherit from parent, or use parent's ID if parent is root
        let rootId = parent.rootId ?? parent.id

        print("📝 [Task Creation] Type: child")
        print("📊 [Task Creation] Current task: id=\(parent.id) | root_id=\(parent.rootId ?? "nil")")
        print("🌲 [Task Creation] Calculated root_id: \(rootId)")
        print("🧮 [Task Creation] Logic: parent.rootId ?? parent.id = \"\(parent.rootId ?? "nil")\" ?? \"\(parent.id)\" = \"\(rootId)\"")

        // PRE-QUERY: Fetch siblings BEFORE saving (no index lag!)
        let siblings = LocalTaskStore.shared.fetchSiblings(parentId: parent.id)
        let siblingCount = siblings.count + 1  // +1 for the task we're about to create
        let siblingPosition = siblingCount  // New child goes last (sorted by timestamp)
        print("✅ [Child Creation] Pre-calculated sibling info: position=\(siblingPosition)/\(siblingCount)")

        // Fetch parent task text
        let parentTask = LocalTaskStore.shared.fetchTaskById(parent.id)
        let parentTaskText = parentTask?.text
        print("✅ [Child Creation] Fetched parent text: \(parentTaskText ?? "nil")")

        // Fetch root task text if root exists and is different from parent
        var rootTaskText: String? = nil
        if rootId != parent.id {
            let rootTask = LocalTaskStore.shared.fetchTaskById(rootId)
            rootTaskText = rootTask?.text
            print("✅ [Child Creation] Fetched root text: \(rootTaskText ?? "nil")")
        }

        // Calculate showEllipsis: check if parent's parent != root
        let showEllipsis = (parent.parentId != nil && parent.parentId != rootId)
        print("📊 [Child Creation] showEllipsis=\(showEllipsis) (parent's parent exists and != root)")

        // Generate task ID and save to local storage
        let taskId = UUID().uuidString
        let timestamp = Date()

        LocalTaskStore.shared.saveTask(
            id: taskId,
            text: text,
            timestamp: timestamp,
            parent_id: parent.id,
            root_id: rootId,
            isCompleted: false
        )

        // Child tasks always become current
        AppState.shared.setCurrent(id: taskId, text: text, parentId: parent.id, rootId: rootId)

        // Update pointer with all pre-calculated display info
        CloudKitManager.shared.updateCurrentTaskPointer(
            taskId: taskId,
            text: text,
            parentId: parent.id,
            rootId: rootId,
            parentTaskText: parentTaskText,
            rootTaskText: rootTaskText,
            showEllipsis: showEllipsis,
            siblingPosition: siblingPosition,
            siblingCount: siblingCount
        ) { error in
            if let error = error {
                print("⚠️ [AppDelegate] Pointer update failed: \(error.localizedDescription)")
            }
        }

        ToastManager.shared.show("✓ Child created under \(parent.text) (current)", type: .success)

        // Log to file for backup
        logManager.log(text: text, id: taskId, parentId: parent.id, rootId: rootId)
    }

    private func createSiblingTask(text: String, reference: TaskReference, switchTo: Bool) {
        // Sibling = same parent and same root as reference task
        let rootId = reference.rootId

        print("📝 [Task Creation] Type: sibling")
        print("📊 [Task Creation] Reference task: id=\(reference.id) | parent_id=\(reference.parentId ?? "nil") | root_id=\(reference.rootId ?? "nil")")
        print("🌲 [Task Creation] Inherited root_id: \(rootId ?? "nil")")

        // Generate task ID and save to local storage
        let taskId = UUID().uuidString
        let timestamp = Date()

        LocalTaskStore.shared.saveTask(
            id: taskId,
            text: text,
            timestamp: timestamp,
            parent_id: reference.parentId,
            root_id: rootId,
            isCompleted: false
        )

        // Determine which task to display on iPhone
        let displayTaskId: String
        let displayText: String
        let displayParentId: String?
        let displayRootId: String?

        if switchTo {
            // Switch to new sibling
            AppState.shared.setCurrent(id: taskId, text: text, parentId: reference.parentId, rootId: rootId)
            displayTaskId = taskId
            displayText = text
            displayParentId = reference.parentId
            displayRootId = rootId
        } else {
            // Keep current task, but refresh pointer with updated sibling count
            guard let current = AppState.shared.currentTask else {
                ToastManager.shared.show("✓ Sibling created", type: .success)
                return
            }
            displayTaskId = current.id
            displayText = current.text
            displayParentId = current.parentId
            displayRootId = current.rootId
        }

        // Fetch all display info from local storage
        var parentTaskText: String? = nil
        var rootTaskText: String? = nil
        var showEllipsis = false
        var siblingPosition: Int? = nil
        var siblingCount: Int? = nil

        // Fetch parent task text if parent exists
        if let parentId = displayParentId {
            let parentTask = LocalTaskStore.shared.fetchTaskById(parentId)
            parentTaskText = parentTask?.text
            print("✅ [Sibling Creation] Fetched parent text: \(parentTaskText ?? "nil")")

            // Calculate showEllipsis: check if parent's parent != root
            if let parentParentId = parentTask?.parent_id,
               let rootId = displayRootId,
               parentParentId != rootId {
                showEllipsis = true
                print("📊 [Sibling Creation] showEllipsis=true (parent's parent exists and != root)")
            } else {
                print("📊 [Sibling Creation] showEllipsis=false (parent's parent is root or doesn't exist)")
            }

            // Fetch root task text if root exists and is different from parent
            if let rootId = displayRootId, rootId != parentId {
                let rootTask = LocalTaskStore.shared.fetchTaskById(rootId)
                rootTaskText = rootTask?.text
                print("✅ [Sibling Creation] Fetched root text: \(rootTaskText ?? "nil")")
            }

            // Fetch siblings (now includes the newly created sibling)
            let siblings = LocalTaskStore.shared.fetchSiblings(parentId: parentId)
            siblingCount = siblings.count

            if switchTo {
                // Display task is the new sibling (goes last by timestamp)
                siblingPosition = siblingCount
            } else {
                // Display task is current task (find its position)
                if let idx = siblings.firstIndex(where: { $0.id == displayTaskId }) {
                    siblingPosition = idx + 1  // 1-based index
                } else {
                    siblingPosition = 1  // Fallback
                }
            }

            print("✅ [Sibling Creation] Sibling info: position=\(siblingPosition ?? 0)/\(siblingCount ?? 0)")
        }

        // Update pointer with complete display info
        CloudKitManager.shared.updateCurrentTaskPointer(
            taskId: displayTaskId,
            text: displayText,
            parentId: displayParentId,
            rootId: displayRootId,
            parentTaskText: parentTaskText,
            rootTaskText: rootTaskText,
            showEllipsis: showEllipsis,
            siblingPosition: siblingPosition,
            siblingCount: siblingCount
        ) { error in
            if let error = error {
                print("⚠️ [AppDelegate] Pointer update failed: \(error.localizedDescription)")
            }
        }

        let message = switchTo ? "✓ Sibling created (current)" : "✓ Sibling created"
        ToastManager.shared.show(message, type: .success)

        // Log to file for backup
        logManager.log(text: text, id: taskId, parentId: reference.parentId, rootId: rootId)
    }

    private func createTaskWithCustomParent(text: String, customParentId: String, switchToTask: Bool) {
        print("📝 [Task Creation] Type: custom parent")
        print("📝 [Task Creation] Text: \(text)")
        print("📝 [Task Creation] Custom parent ID: \(customParentId)")
        print("📝 [Task Creation] Switch: \(switchToTask)")

        // Generate new task ID
        let taskId = UUID().uuidString
        let timestamp = Date()

        // Fetch parent to get root_id
        guard let parentTask = LocalTaskStore.shared.fetchTaskById(customParentId) else {
            ToastManager.shared.show("❌ Parent task not found", type: .error)
            print("❌ [Task Creation] Parent task not found: \(customParentId)")
            return
        }

        // Task is child of selected parent
        let parent_id = customParentId
        let root_id = parentTask.root_id ?? customParentId  // Use parent's root, or parent itself if it's the root

        print("📊 [Task Creation] Calculated: parent_id=\(parent_id) | root_id=\(root_id)")

        // Save task to local storage (instant!)
        LocalTaskStore.shared.saveTask(
            id: taskId,
            text: text,
            timestamp: timestamp,
            parent_id: parent_id,
            root_id: root_id,
            isCompleted: false
        )

        print("✅ [Task Creation] Saved to local storage")

        // Determine what to display
        let displayTaskId: String
        let displayText: String
        let displayParentId: String?
        let displayRootId: String?

        if switchToTask {
            // Switch to new task
            displayTaskId = taskId
            displayText = text
            displayParentId = parent_id
            displayRootId = root_id

            // Update AppState
            AppState.shared.setCurrent(id: taskId, text: text, parentId: parent_id, rootId: root_id)
        } else {
            // Keep current task (don't switch)
            if let current = AppState.shared.currentTask {
                displayTaskId = current.id
                displayText = current.text
                displayParentId = current.parentId
                displayRootId = current.rootId
            } else {
                // Fallback: no current task, use new task
                displayTaskId = taskId
                displayText = text
                displayParentId = parent_id
                displayRootId = root_id
                AppState.shared.setCurrent(id: taskId, text: text, parentId: parent_id, rootId: root_id)
            }
        }

        // Fetch display metadata
        var parentTaskText: String? = nil
        var rootTaskText: String? = nil
        var showEllipsis = false
        var siblingPosition: Int? = nil
        var siblingCount: Int? = nil

        if let displayParentId = displayParentId {
            let displayParentTask = LocalTaskStore.shared.fetchTaskById(displayParentId)
            parentTaskText = displayParentTask?.text

            // Calculate ellipsis
            if let parentParentId = displayParentTask?.parent_id,
               let displayRootId = displayRootId,
               parentParentId != displayRootId {
                showEllipsis = true
            }

            // Fetch root text
            if let displayRootId = displayRootId, displayRootId != displayParentId {
                rootTaskText = LocalTaskStore.shared.fetchTaskById(displayRootId)?.text
            }

            // Fetch sibling position/count
            let siblings = LocalTaskStore.shared.fetchSiblings(parentId: displayParentId)
            siblingCount = siblings.count
            siblingPosition = siblings.firstIndex(where: { $0.id == displayTaskId }).map { $0 + 1 }
        }

        // Update CloudKit pointer
        CloudKitManager.shared.updateCurrentTaskPointer(
            taskId: displayTaskId,
            text: displayText,
            parentId: displayParentId,
            rootId: displayRootId,
            parentTaskText: parentTaskText,
            rootTaskText: rootTaskText,
            showEllipsis: showEllipsis,
            siblingPosition: siblingPosition,
            siblingCount: siblingCount
        ) { error in
            if let error = error {
                print("⚠️ [Task Creation] Pointer update failed: \(error.localizedDescription)")
            }
        }

        let message = switchToTask ? "✓ Task created (current)" : "✓ Task created"
        ToastManager.shared.show(message, type: .success)

        // Log to file
        logManager.log(text: text, id: taskId, parentId: parent_id, rootId: root_id)
    }

    // MARK: - Leaf Selection

    private func showLeafSelector() {
        print("🔍 [Leaf Selector] Triggered via Cmd+Shift+S")

        // Check if current task exists
        guard let current = AppState.shared.currentTask else {
            ToastManager.shared.show("⚠️ No current task. Switch to a task first.", type: .error)
            print("⚠️ [Leaf Selector] No current task in AppState")
            return
        }

        // Get root ID (use current task ID if it's a root)
        let rootId = current.rootId ?? current.id
        print("📊 [Leaf Selector] Current task: \(current.text)")
        print("🔗 [Leaf Selector] Root ID: \(rootId)")

        // Fetch all leaves in this root from local storage (instant!)
        let leaves = LocalTaskStore.shared.fetchLeaves(rootId: rootId)
        let allLeaves = leaves.map { (id: $0.id, text: $0.text) }

        // Find current task's index among leaves
        let currentIndex = allLeaves.firstIndex(where: { $0.id == current.id }) ?? 0

        print("✅ [Leaf Selector] Found \(allLeaves.count) leaves in root")
        print("📊 [Leaf Selector] Current index: \(currentIndex + 1)/\(allLeaves.count)")

        // Show panel with leaves
        leafSelectorPanel.show(leaves: allLeaves, currentIndex: currentIndex)
    }

    private func handleLeafSelection(taskId: String, taskText: String) {
        print("🔄 [Leaf Switch] Selected leaf: \(taskText) (ID: \(taskId))")

        // Hide the panel first
        leafSelectorPanel.hide()

        // Fetch the full task record from local storage
        guard let task = LocalTaskStore.shared.fetchTaskById(taskId) else {
            ToastManager.shared.show("❌ Failed to load task", type: .error)
            print("❌ [Leaf Switch] Task not found")
            return
        }

        let text = task.text
        let parentId = task.parent_id
        let rootId = task.root_id

        print("📝 [Leaf Switch] Task metadata: parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")

        // Update AppState
        AppState.shared.setCurrent(id: taskId, text: text, parentId: parentId, rootId: rootId)

        // Fetch all display info from local storage
        var parentTaskText: String? = nil
        var rootTaskText: String? = nil
        var showEllipsis = false
        var siblingPosition: Int? = nil
        var siblingCount: Int? = nil

        // Fetch parent task text
        if let parentId = parentId {
            let parentTask = LocalTaskStore.shared.fetchTaskById(parentId)
            parentTaskText = parentTask?.text
            print("✅ [Leaf Switch] Fetched parent text: \(parentTaskText ?? "nil")")

            // Calculate showEllipsis: check if parent's parent != root
            if let parentParentId = parentTask?.parent_id,
               let rootId = rootId,
               parentParentId != rootId {
                showEllipsis = true
                print("📊 [Leaf Switch] showEllipsis=true (parent's parent exists and != root)")
            } else {
                print("📊 [Leaf Switch] showEllipsis=false")
            }

            // Fetch root task text if root exists and is different from parent
            if let rootId = rootId, rootId != parentId {
                let rootTask = LocalTaskStore.shared.fetchTaskById(rootId)
                rootTaskText = rootTask?.text
                print("✅ [Leaf Switch] Fetched root text: \(rootTaskText ?? "nil")")
            }

            // Fetch siblings to get position/count
            let siblings = LocalTaskStore.shared.fetchSiblings(parentId: parentId)
            siblingCount = siblings.count
            siblingPosition = siblings.firstIndex(where: { $0.id == taskId }).map { $0 + 1 }
            print("✅ [Leaf Switch] Sibling info: position=\(siblingPosition ?? 0)/\(siblingCount ?? 0)")
        }

        // Update pointer with complete display info
        CloudKitManager.shared.updateCurrentTaskPointer(
            taskId: taskId,
            text: text,
            parentId: parentId,
            rootId: rootId,
            parentTaskText: parentTaskText,
            rootTaskText: rootTaskText,
            showEllipsis: showEllipsis,
            siblingPosition: siblingPosition,
            siblingCount: siblingCount
        ) { error in
            if let error = error {
                print("⚠️ [Leaf Switch] Pointer update failed: \(error.localizedDescription)")
            }
        }

        // Show success toast
        ToastManager.shared.show("✓ Switched to leaf task", type: .success)
    }

    // MARK: - Root Selector

    private func showRootSelector() {
        print("🌳 [Root Selector] Triggered via Cmd+Shift+R")

        // Fetch all root tasks from local storage (instant!)
        let roots = LocalTaskStore.shared.fetchRoots()

        if roots.isEmpty {
            ToastManager.shared.show("⚠️ No root tasks found", type: .error)
            print("⚠️ [Root Selector] No root tasks in database")
            return
        }

        // Get current task's root_id to highlight current root
        let currentRootId = AppState.shared.currentTask?.rootId

        let rootList = roots.map { (id: $0.id, text: $0.text) }

        print("✅ [Root Selector] Found \(rootList.count) roots")
        print("📊 [Root Selector] Current root ID: \(currentRootId ?? "nil")")  

        // Show panel with roots
        rootSelectorPanel.show(roots: rootList, currentRootId: currentRootId)
    }

    private func handleRootSelection(rootId: String, rootText: String) {
        print("🔄 [Root Switch] Selected root: \(rootText) (ID: \(rootId))")

        // Hide the panel first
        rootSelectorPanel.hide()

        // Fetch the latest task in this tree from local storage
        guard let latestTask = LocalTaskStore.shared.fetchLatestInTree(rootId: rootId) else {
            ToastManager.shared.show("❌ Failed to load latest task", type: .error)
            print("❌ [Root Switch] No tasks found in tree")
            return
        }

        let taskId = latestTask.id
        let text = latestTask.text
        let parentId = latestTask.parent_id
        let rootIdFromRecord = latestTask.root_id

        print("📝 [Root Switch] Latest task in tree: \(text)")
        print("📝 [Root Switch] Task metadata: taskId=\(taskId) | parentId=\(parentId ?? "nil") | rootId=\(rootIdFromRecord ?? "nil")")

        // Update AppState
        AppState.shared.setCurrent(id: taskId, text: text, parentId: parentId, rootId: rootIdFromRecord)

        // Fetch all display info from local storage
        var parentTaskText: String? = nil
        var rootTaskText: String? = nil
        var showEllipsis = false
        var siblingPosition: Int? = nil
        var siblingCount: Int? = nil

        // Fetch parent task text if it exists
        if let parentId = parentId {
            let parentTask = LocalTaskStore.shared.fetchTaskById(parentId)
            parentTaskText = parentTask?.text
            print("✅ [Root Switch] Fetched parent text: \(parentTaskText ?? "nil")")

            // Calculate showEllipsis: check if parent's parent != root
            if let parentParentId = parentTask?.parent_id,
               let rootId = rootIdFromRecord,
               parentParentId != rootId {
                showEllipsis = true
                print("📊 [Root Switch] showEllipsis=true (parent's parent exists and != root)")
            } else {
                print("📊 [Root Switch] showEllipsis=false")
            }

            // Fetch siblings (no index lag!)
            let siblings = LocalTaskStore.shared.fetchSiblings(parentId: parentId)
            siblingCount = siblings.count
            siblingPosition = siblings.firstIndex(where: { $0.id == taskId }).map { $0 + 1 }
            print("✅ [Root Switch] Sibling position: \(siblingPosition ?? 0)/\(siblingCount ?? 0)")
        }

        // Fetch root task text if it exists and is different from parent
        if let rootId = rootIdFromRecord, rootId != parentId {
            let rootTask = LocalTaskStore.shared.fetchTaskById(rootId)
            rootTaskText = rootTask?.text
            print("✅ [Root Switch] Fetched root text: \(rootTaskText ?? "nil")")
        }

        print("📊 [Root Switch] All fetches complete - updating pointer")

        // Update CurrentTaskPointer with all display metadata
        CloudKitManager.shared.updateCurrentTaskPointer(
            taskId: taskId,
            text: text,
            parentId: parentId,
            rootId: rootIdFromRecord,
            parentTaskText: parentTaskText,
            rootTaskText: rootTaskText,
            showEllipsis: showEllipsis,
            siblingPosition: siblingPosition,
            siblingCount: siblingCount
        ) { error in
            if let error = error {
                print("⚠️ [Root Switch] Pointer update failed: \(error.localizedDescription)")
            }
        }

        // Show success toast
        ToastManager.shared.show("✓ Switched to \(rootText) tree", type: .success)
    }

    // MARK: - Parent Selection

    private func showParentSelector(taskText: String) {
        print("🔍 [Parent Selector] Triggered via Cmd+P")
        print("📝 [Parent Selector] Task text: \(taskText)")

        // Check if current task exists
        guard let current = AppState.shared.currentTask else {
            ToastManager.shared.show("⚠️ No current task. Create a task first.", type: .error)
            print("⚠️ [Parent Selector] No current task in AppState")
            return
        }

        // Fetch all tasks in hierarchy (sorted by DFS tree order)
        let (tasksInHierarchy, _) = LocalTaskStore.shared.fetchAllTasksInHierarchy(taskId: current.id)

        print("✅ [Parent Selector] Found \(tasksInHierarchy.count) tasks in hierarchy")

        // Hide Spotlight panel
        spotlightPanel.hide()

        // Show OutlineView parent selector panel
        outlineParentSelectorPanel.show(
            treeTasks: tasksInHierarchy,
            currentTaskId: current.id,
            currentTaskName: taskText.isEmpty ? current.text : taskText
        )
    }

    private func handleParentSelection(parentId: String, parentText: String, shouldSwitch: Bool) {
        print("🔄 [Parent Selection] Selected parent: \(parentText) (ID: \(parentId), switch: \(shouldSwitch))")

        // Get preserved text from Spotlight
        guard let taskText = spotlightViewController.preservedText else {
            print("❌ [Parent Selection] No preserved text found")
            outlineParentSelectorPanel.hide()
            return
        }

        // Check if we're re-parenting an existing task
        if spotlightViewController.isReparentMode, let taskId = spotlightViewController.reparentTaskId {
            // Prevent task from being its own parent - stay in selector
            if taskId == parentId {
                ToastManager.shared.show("⚠️ Task cannot be its own parent", type: .error)
                return  // Don't hide panel, let user pick another
            }

            // Valid selection - hide panel and proceed
            outlineParentSelectorPanel.hide()

            reparentExistingTask(
                taskId: taskId,
                newText: taskText,
                newParentId: parentId,
                newParentText: parentText
            )
        } else {
            // Normal flow - hide panel and create new task
            outlineParentSelectorPanel.hide()

            // Store parent selection in Spotlight
            spotlightViewController.setSelectedParent(parentId: parentId, parentText: parentText)

            // Create task immediately as child of selected parent
            createTaskWithCustomParent(
                text: taskText,
                customParentId: parentId,
                switchToTask: shouldSwitch
            )
        }

        // Clear parent selection for next task
        spotlightViewController.clearParentSelection()
    }

    private func reparentExistingTask(taskId: String, newText: String, newParentId: String, newParentText: String) {
        print("🔄 [Re-parent] Moving task \(taskId) to parent \(newParentId)")

        // Get the new parent's root_id
        guard let newParent = LocalTaskStore.shared.fetchTaskById(newParentId) else {
            ToastManager.shared.show("❌ Failed to find parent task", type: .error)
            return
        }
        let newRootId = newParent.root_id ?? newParentId  // If parent is root, use its ID

        // Update task in local storage
        let success = LocalTaskStore.shared.updateTaskParent(
            id: taskId,
            newParentId: newParentId,
            newRootId: newRootId,
            newText: newText
        )

        guard success else {
            ToastManager.shared.show("❌ Failed to re-parent task", type: .error)
            return
        }

        // Update AppState with new parent info
        AppState.shared.setCurrent(
            id: taskId,
            text: newText,
            parentId: newParentId,
            rootId: newRootId
        )

        // Fetch display info for CloudKit pointer
        var rootTaskText: String? = nil
        var showEllipsis = false
        var siblingPosition: Int? = nil
        var siblingCount: Int? = nil

        // Fetch root task text if root is different from parent
        if newRootId != newParentId {
            let rootTask = LocalTaskStore.shared.fetchTaskById(newRootId)
            rootTaskText = rootTask?.text
        }

        // Check if parent's parent != root (for ellipsis)
        if let parentParentId = newParent.parent_id,
           parentParentId != newRootId {
            showEllipsis = true
        }

        // Fetch siblings for position/count
        let siblings = LocalTaskStore.shared.fetchSiblings(parentId: newParentId)
        siblingCount = siblings.count
        siblingPosition = siblings.firstIndex(where: { $0.id == taskId }).map { $0 + 1 }

        // Update CloudKit pointer
        CloudKitManager.shared.updateCurrentTaskPointer(
            taskId: taskId,
            text: newText,
            parentId: newParentId,
            rootId: newRootId,
            parentTaskText: newParentText,
            rootTaskText: rootTaskText,
            showEllipsis: showEllipsis,
            siblingPosition: siblingPosition,
            siblingCount: siblingCount
        ) { error in
            if let error = error {
                print("⚠️ [Re-parent] CloudKit pointer update failed: \(error.localizedDescription)")
            }
        }

        ToastManager.shared.show("✓ Task re-parented", type: .success)
        print("✅ [Re-parent] Task moved to new parent: \(newParentText)")
    }

    private func handleParentSelectorCancelled() {
        print("⎋ [Parent Selector] Cancelled")

        // Hide parent selector
        outlineParentSelectorPanel.hide()

        // Show Spotlight again with preserved text
        spotlightPanel.show()
        spotlightViewController.restorePreservedText()
    }

    // MARK: - Task Dismissal

    private func dismissCurrentTask() {
        print("🗑️ [Dismiss] Triggered")

        // Validate: Current task exists
        guard let current = AppState.shared.currentTask else {
            ToastManager.shared.show("⚠️ No current task to dismiss", type: .error)
            print("⚠️ [Dismiss] No current task in AppState")
            return
        }

        // Validate: Task has no children (leaf node check)
        if LocalTaskStore.shared.hasChildren(taskId: current.id) {
            ToastManager.shared.show("⚠️ Cannot dismiss task with children", type: .error)
            print("⚠️ [Dismiss] Task \(current.id) has children - operation blocked")
            return
        }

        // Fetch full task record BEFORE deletion (need timestamp for fallback)
        guard let taskRecord = LocalTaskStore.shared.fetchTaskById(current.id) else {
            ToastManager.shared.show("❌ Task not found", type: .error)
            print("❌ [Dismiss] Task record not found")
            return
        }

        let taskText = taskRecord.text
        let taskTimestamp = taskRecord.timestamp
        let parentId = taskRecord.parent_id
        let rootId = taskRecord.root_id

        print("📝 [Dismiss] Task to delete: \(taskText)")
        print("📊 [Dismiss] Task metadata: parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil") | timestamp=\(taskTimestamp)")

        // Delete task from local storage
        guard LocalTaskStore.shared.deleteTask(id: current.id) else {
            ToastManager.shared.show("❌ Failed to delete task", type: .error)
            return
        }

        print("✅ [Dismiss] Task deleted from storage")

        // DISMISS NAVIGATION: leaf siblings → parent (if leaf) → youngest leaf → other roots

        // Step 1: Try leaf siblings (same parent, youngest)
        if let parentId = parentId {
            let siblings = LocalTaskStore.shared.fetchSiblings(parentId: parentId)
            let leafSiblings = siblings.filter { !LocalTaskStore.shared.hasChildren(taskId: $0.id) }

            if let youngestLeafSibling = leafSiblings.last {  // sorted ASC, .last is youngest
                print("✅ [Dismiss] Found youngest leaf sibling: \(youngestLeafSibling.text)")
                navigateToTask(task: youngestLeafSibling, reason: "youngest leaf sibling")
                ToastManager.shared.show("Task cleared", type: .success)
                return
            }
        }

        // Step 2: All leaves in root - bias toward parent
        if let rootId = rootId {
            let leaves = LocalTaskStore.shared.fetchLeaves(rootId: rootId)

            // Prefer parent if it's now a leaf
            if let parentId = parentId,
               let parentLeaf = leaves.first(where: { $0.id == parentId }) {
                print("✅ [Dismiss] Parent is now a leaf: \(parentLeaf.text)")
                navigateToTask(task: parentLeaf, reason: "parent (now a leaf)")
                ToastManager.shared.show("Task cleared", type: .success)
                return
            }

            // Otherwise youngest leaf in root
            if let youngestLeaf = leaves.last {
                print("✅ [Dismiss] Found youngest leaf in root: \(youngestLeaf.text)")
                navigateToTask(task: youngestLeaf, reason: "youngest leaf in root")
                ToastManager.shared.show("Task cleared", type: .success)
                return
            }
        }

        // Step 3: Root is gone - youngest root's youngest leaf
        let allRoots = LocalTaskStore.shared.fetchRoots()
        if let youngestRoot = allRoots.last {
            let leaves = LocalTaskStore.shared.fetchLeaves(rootId: youngestRoot.id)
            if let youngestLeaf = leaves.last {
                print("✅ [Dismiss] Found youngest leaf in youngest root: \(youngestLeaf.text)")
                navigateToTask(task: youngestLeaf, reason: "youngest leaf in youngest root")
                ToastManager.shared.show("Task cleared", type: .success)
                return
            }
        }

        // Step 4: No tasks left
        print("ℹ️ [Dismiss] No tasks remaining - clearing AppState and CloudKit pointer")
        AppState.shared.clearCurrent()

        // Clear CloudKit pointer so iPhone shows "No current task"
        CloudKitManager.shared.clearCurrentTaskPointer { error in
            if let error = error {
                print("⚠️ [Dismiss] Failed to clear pointer: \(error.localizedDescription)")
            } else {
                print("✅ [Dismiss] Pointer cleared - iPhone will update")
            }
        }

        ToastManager.shared.show("Task cleared (no tasks remaining)", type: .success)
    }

    /// Navigate to a task and update CloudKit pointer
    /// Helper function used by dismissCurrentTask
    private func navigateToTask(task: LocalTaskStore.Task, reason: String) {
        print("🔄 [Navigate] Switching to task: \(task.text) (reason: \(reason))")

        let taskId = task.id
        let text = task.text
        let parentId = task.parent_id
        let rootId = task.root_id

        // Update AppState
        AppState.shared.setCurrent(id: taskId, text: text, parentId: parentId, rootId: rootId)

        // Fetch all display info from local storage (same pattern as sibling/root selection)
        var parentTaskText: String? = nil
        var rootTaskText: String? = nil
        var showEllipsis = false
        var siblingPosition: Int? = nil
        var siblingCount: Int? = nil

        if let parentId = parentId {
            let parentTask = LocalTaskStore.shared.fetchTaskById(parentId)
            parentTaskText = parentTask?.text

            // Calculate showEllipsis
            if let parentParentId = parentTask?.parent_id,
               let rootId = rootId,
               parentParentId != rootId {
                showEllipsis = true
            }

            // Fetch root task text if different from parent
            if let rootId = rootId, rootId != parentId {
                let rootTask = LocalTaskStore.shared.fetchTaskById(rootId)
                rootTaskText = rootTask?.text
            }

            // Fetch sibling position/count
            let siblings = LocalTaskStore.shared.fetchSiblings(parentId: parentId)
            siblingCount = siblings.count
            siblingPosition = siblings.firstIndex(where: { $0.id == taskId }).map { $0 + 1 }
        }

        // Update CloudKit pointer
        CloudKitManager.shared.updateCurrentTaskPointer(
            taskId: taskId,
            text: text,
            parentId: parentId,
            rootId: rootId,
            parentTaskText: parentTaskText,
            rootTaskText: rootTaskText,
            showEllipsis: showEllipsis,
            siblingPosition: siblingPosition,
            siblingCount: siblingCount
        ) { error in
            if let error = error {
                print("⚠️ [Navigate] Pointer update failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Startup Initialization

    /// Initialize app state on launch by syncing local storage with CloudKit pointer
    private func initializeAppState() {
        print("🚀 [Startup] Initializing app state...")

        let allTasks = LocalTaskStore.shared.fetchAllTasks()

        if allTasks.isEmpty {
            print("📭 [Startup] Local storage is empty - clearing CloudKit pointer")
            CloudKitManager.shared.clearCurrentTaskPointer { error in
                if let error = error {
                    print("⚠️ [Startup] Failed to clear pointer: \(error.localizedDescription)")
                } else {
                    print("✅ [Startup] Pointer cleared - iPhone will show placeholder")
                }
            }
            // Clear AppState as well
            AppState.shared.clearCurrent()
            return
        }

        print("📚 [Startup] Found \(allTasks.count) tasks in local storage")

        // Find latest root (last in ASC-sorted array = newest)
        let roots = LocalTaskStore.shared.fetchRoots()
        guard let latestRoot = roots.last else {
            print("⚠️ [Startup] No root tasks found despite having tasks (data inconsistency)")
            AppState.shared.clearCurrent()
            return
        }

        print("🌳 [Startup] Latest root: \(latestRoot.text)")

        // Get deepest task in that root's tree
        guard let latestInTree = LocalTaskStore.shared.fetchLatestInTree(rootId: latestRoot.id) else {
            print("⚠️ [Startup] Could not find latest task in tree")
            AppState.shared.clearCurrent()
            return
        }

        print("🎯 [Startup] Latest task in tree: \(latestInTree.text)")

        // Update AppState
        AppState.shared.setCurrent(
            id: latestInTree.id,
            text: latestInTree.text,
            parentId: latestInTree.parent_id,
            rootId: latestInTree.root_id
        )

        // Fetch all display metadata
        var parentTaskText: String? = nil
        var rootTaskText: String? = nil
        var showEllipsis = false
        var siblingPosition: Int? = nil
        var siblingCount: Int? = nil

        if let parentId = latestInTree.parent_id {
            let parentTask = LocalTaskStore.shared.fetchTaskById(parentId)
            parentTaskText = parentTask?.text

            // Calculate showEllipsis
            if let parentParentId = parentTask?.parent_id,
               let rootId = latestInTree.root_id,
               parentParentId != rootId {
                showEllipsis = true
            }

            // Fetch root task text if different from parent
            if let rootId = latestInTree.root_id, rootId != parentId {
                let rootTask = LocalTaskStore.shared.fetchTaskById(rootId)
                rootTaskText = rootTask?.text
            }

            // Fetch sibling position/count
            let siblings = LocalTaskStore.shared.fetchSiblings(parentId: parentId)
            siblingCount = siblings.count
            siblingPosition = siblings.firstIndex(where: { $0.id == latestInTree.id }).map { $0 + 1 }
        }

        // Update CloudKit pointer
        print("☁️ [Startup] Syncing pointer to CloudKit...")
        CloudKitManager.shared.updateCurrentTaskPointer(
            taskId: latestInTree.id,
            text: latestInTree.text,
            parentId: latestInTree.parent_id,
            rootId: latestInTree.root_id,
            parentTaskText: parentTaskText,
            rootTaskText: rootTaskText,
            showEllipsis: showEllipsis,
            siblingPosition: siblingPosition,
            siblingCount: siblingCount
        ) { error in
            if let error = error {
                print("⚠️ [Startup] Pointer update failed: \(error.localizedDescription)")
            } else {
                print("✅ [Startup] App state initialized and synced to CloudKit")
                print("📱 [Startup] iPhone will now show: \(latestInTree.text)")
            }
        }
    }

    // MARK: - Task Update

    private func handleTaskUpdate(taskId: String, newText: String) {
        print("✏️ [Task Update] taskId=\(taskId) | newText=\"\(newText)\"")

        // Update in local storage
        guard LocalTaskStore.shared.updateTaskText(id: taskId, newText: newText) else {
            ToastManager.shared.show("❌ Failed to update task", type: .error)
            return
        }

        // Update AppState if this is the current task
        if let current = AppState.shared.currentTask, current.id == taskId {
            AppState.shared.setCurrent(
                id: current.id,
                text: newText,  // Updated text
                parentId: current.parentId,
                rootId: current.rootId
            )

            // Update CloudKit pointer with new text (preserving all other display info)
            updateCurrentTaskPointerAfterEdit(taskId: taskId, newText: newText)
        }

        spotlightViewController.resetEditMode()
        spotlightPanel.hide()
        ToastManager.shared.show("✓ Task updated", type: .success)
    }

    private func updateCurrentTaskPointerAfterEdit(taskId: String, newText: String) {
        // Fetch existing display metadata
        guard let task = LocalTaskStore.shared.fetchTaskById(taskId) else {
            print("❌ [Task Update] Task not found for pointer update")
            return
        }

        let parentId = task.parent_id
        let rootId = task.root_id

        var parentTaskText: String? = nil
        var rootTaskText: String? = nil
        var showEllipsis = false
        var siblingPosition: Int? = nil
        var siblingCount: Int? = nil

        if let parentId = parentId {
            let parentTask = LocalTaskStore.shared.fetchTaskById(parentId)
            parentTaskText = parentTask?.text

            // Calculate showEllipsis
            if let parentParentId = parentTask?.parent_id,
               let rootId = rootId,
               parentParentId != rootId {
                showEllipsis = true
            }

            // Fetch root text if different from parent
            if let rootId = rootId, rootId != parentId {
                let rootTask = LocalTaskStore.shared.fetchTaskById(rootId)
                rootTaskText = rootTask?.text
            }

            // Fetch sibling position/count
            let siblings = LocalTaskStore.shared.fetchSiblings(parentId: parentId)
            siblingCount = siblings.count
            siblingPosition = siblings.firstIndex(where: { $0.id == taskId }).map { $0 + 1 }
        }

        // Update pointer with new text + existing metadata
        CloudKitManager.shared.updateCurrentTaskPointer(
            taskId: taskId,
            text: newText,  // Updated text
            parentId: parentId,
            rootId: rootId,
            parentTaskText: parentTaskText,
            rootTaskText: rootTaskText,
            showEllipsis: showEllipsis,
            siblingPosition: siblingPosition,
            siblingCount: siblingCount
        ) { error in
            if let error = error {
                print("⚠️ [Task Update] Pointer update failed: \(error.localizedDescription)")
            } else {
                print("✅ [Task Update] CloudKit pointer updated with new text")
            }
        }
    }

    // MARK: - Nuke All Tasks

    private func handleNuke() {
        if nukeConfirmationPending {
            // Second press - execute nuke
            print("💣 [Nuke] Confirmation received - nuking all tasks")

            nukeConfirmationTimer?.invalidate()
            nukeConfirmationTimer = nil
            nukeConfirmationPending = false

            // Clear tasks.json
            LocalTaskStore.shared.clearAllTasks()
            print("✅ [Nuke] Cleared tasks.json")

            // Clear AppState
            AppState.shared.clearCurrent()
            print("✅ [Nuke] Cleared AppState")

            // Clear CloudKit pointer
            CloudKitManager.shared.clearCurrentTaskPointer { error in
                if let error = error {
                    print("⚠️ [Nuke] Failed to clear pointer: \(error.localizedDescription)")
                } else {
                    print("✅ [Nuke] Cleared CloudKit pointer - iPhone will update")
                }
            }

            ToastManager.shared.show("💣 All tasks nuked - fresh state", type: .success)
        } else {
            // First press - request confirmation
            print("⚠️ [Nuke] First press - requesting confirmation")
            nukeConfirmationPending = true

            // Reset confirmation after 3 seconds
            nukeConfirmationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                print("⏱️ [Nuke] Confirmation timeout - reset")
                self?.nukeConfirmationPending = false
                self?.nukeConfirmationTimer = nil
            }

            ToastManager.shared.show("⚠️ Press Cmd+Shift+Backspace again to confirm nuke", type: .error)
        }
    }
}

