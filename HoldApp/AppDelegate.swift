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
    private var siblingSelectorPanel: SiblingSelectorPanel!
    private var siblingSelectorViewController: SiblingSelectorViewController!
    private var rootSelectorPanel: RootSelectorPanel!
    private var rootSelectorViewController: RootSelectorViewController!
    private var hotkeyManager: HotkeyManager!
    private var logManager: LogManager!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize components
        logManager = LogManager()

        // Create Spotlight UI
        spotlightViewController = SpotlightViewController()
        spotlightPanel = SpotlightPanel()
        spotlightPanel.contentViewController = spotlightViewController

        // Setup callbacks
        spotlightViewController.onTaskSubmit = { [weak self] text, type in
            self?.handleTaskCreation(text: text, type: type)
        }

        spotlightViewController.onCancel = { [weak self] in
            self?.spotlightPanel.hide()
        }

        // Create Sibling Selector UI
        siblingSelectorViewController = SiblingSelectorViewController()
        siblingSelectorPanel = SiblingSelectorPanel()
        siblingSelectorPanel.contentViewController = siblingSelectorViewController

        // Setup sibling selector callbacks
        siblingSelectorViewController.onSiblingSelected = { [weak self] taskId, taskText in
            self?.handleSiblingSelection(taskId: taskId, taskText: taskText)
        }

        siblingSelectorViewController.onCancel = { [weak self] in
            self?.siblingSelectorPanel.hide()
        }

        // Create Root Selector UI
        rootSelectorViewController = RootSelectorViewController()
        rootSelectorPanel = RootSelectorPanel()
        rootSelectorPanel.contentViewController = rootSelectorViewController

        // Setup root selector callbacks
        rootSelectorViewController.onRootSelected = { [weak self] rootId, rootText in
            self?.handleRootSelection(rootId: rootId, rootText: rootText)
        }

        rootSelectorViewController.onCancel = { [weak self] in
            self?.rootSelectorPanel.hide()
        }

        // Setup hotkeys
        hotkeyManager = HotkeyManager()
        hotkeyManager.onShowHotkey = { [weak self] in
            self?.spotlightPanel.show()
        }
        // Note: Escape is handled locally by each panel's keyDown() method
        hotkeyManager.onSiblingSelector = { [weak self] in
            self?.showSiblingSelector()
        }
        hotkeyManager.onRootSelector = { [weak self] in
            self?.showRootSelector()
        }
        hotkeyManager.registerHotkeys()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
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

        CloudKitManager.shared.saveTask(text: text, parentId: parentId, rootId: rootId, isCurrent: switchTo) { [weak self] result in
            switch result {
            case .success(let record):
                let taskId = record.recordID.recordName

                // Update current task if switching
                if switchTo {
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
                self?.logManager.log(text: text, id: taskId, parentId: parentId)

            case .failure(let error):
                ToastManager.shared.show("❌ Error: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func createChildTask(text: String, parent: TaskReference) {
        // Calculate root_id: inherit from parent, or use parent's ID if parent is root
        let rootId = parent.rootId ?? parent.id

        print("📝 [Task Creation] Type: child")
        print("📊 [Task Creation] Current task: id=\(parent.id) | root_id=\(parent.rootId ?? "nil")")
        print("🌲 [Task Creation] Calculated root_id: \(rootId)")
        print("🧮 [Task Creation] Logic: parent.rootId ?? parent.id = \"\(parent.rootId ?? "nil")\" ?? \"\(parent.id)\" = \"\(rootId)\"")

        CloudKitManager.shared.saveTask(text: text, parentId: parent.id, rootId: rootId, isCurrent: true) { [weak self] result in
            switch result {
            case .success(let record):
                let taskId = record.recordID.recordName

                // Child tasks always become current
                AppState.shared.setCurrent(id: taskId, text: text, parentId: parent.id, rootId: rootId)

                // Fetch all display info for pointer update
                let dispatchGroup = DispatchGroup()
                var parentTaskText: String?
                var rootTaskText: String?
                var showEllipsis = false
                var siblingPosition: Int?
                var siblingCount: Int?
                var fetchErrors: [Error] = []

                // Fetch parent task text
                dispatchGroup.enter()
                CloudKitManager.shared.fetchTaskById(parent.id) { result in
                    defer { dispatchGroup.leave() }
                    switch result {
                    case .success(let parentRecord):
                        parentTaskText = parentRecord["text"] as? String
                        print("✅ [Child Creation] Fetched parent text: \(parentTaskText ?? "nil")")
                    case .failure(let error):
                        print("⚠️ [Child Creation] Failed to fetch parent text: \(error.localizedDescription)")
                        fetchErrors.append(error)
                    }
                }

                // Fetch root task text if root exists and is different from parent
                if rootId != parent.id {
                    dispatchGroup.enter()
                    CloudKitManager.shared.fetchTaskById(rootId) { result in
                        defer { dispatchGroup.leave() }
                        switch result {
                        case .success(let rootRecord):
                            rootTaskText = rootRecord["text"] as? String
                            print("✅ [Child Creation] Fetched root text: \(rootTaskText ?? "nil")")
                        case .failure(let error):
                            print("⚠️ [Child Creation] Failed to fetch root text: \(error.localizedDescription)")
                            fetchErrors.append(error)
                        }
                    }
                }

                // Calculate showEllipsis: need to check if parent's parent != root
                if let parentParentId = parent.parentId, parentParentId != rootId {
                    showEllipsis = true
                    print("📊 [Child Creation] showEllipsis=true (parent's parent exists and != root)")
                } else {
                    print("📊 [Child Creation] showEllipsis=false (parent's parent is root or doesn't exist)")
                }

                // Fetch siblings (children of same parent)
                dispatchGroup.enter()
                CloudKitManager.shared.fetchSiblings(parentId: parent.id) { result in
                    defer { dispatchGroup.leave() }
                    switch result {
                    case .success(let siblings):
                        siblingCount = siblings.count + 1  // +1 for the newly created task
                        // Find position (new task will be last since sorted by timestamp)
                        siblingPosition = siblingCount
                        print("✅ [Child Creation] Sibling info: position=\(siblingPosition ?? 0)/\(siblingCount ?? 0)")
                    case .failure(let error):
                        print("⚠️ [Child Creation] Failed to fetch siblings: \(error.localizedDescription)")
                        fetchErrors.append(error)
                    }
                }

                // Wait for all fetches to complete
                dispatchGroup.notify(queue: .main) {
                    // Update pointer with complete display info
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
                }

                // Log to file for backup
                self?.logManager.log(text: text, id: taskId, parentId: parent.id)

            case .failure(let error):
                ToastManager.shared.show("❌ Error: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func createSiblingTask(text: String, reference: TaskReference, switchTo: Bool) {
        // Sibling = same parent and same root as reference task
        let rootId = reference.rootId

        print("📝 [Task Creation] Type: sibling")
        print("📊 [Task Creation] Reference task: id=\(reference.id) | parent_id=\(reference.parentId ?? "nil") | root_id=\(reference.rootId ?? "nil")")
        print("🌲 [Task Creation] Inherited root_id: \(rootId ?? "nil")")

        CloudKitManager.shared.saveTask(text: text, parentId: reference.parentId, rootId: rootId, isCurrent: switchTo) { [weak self] result in
            switch result {
            case .success(let record):
                let taskId = record.recordID.recordName

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

                // Unified pointer update logic (works for both switchTo cases)
                // This ensures iPhone gets updated sibling count even when not switching
                let dispatchGroup = DispatchGroup()
                var parentTaskText: String?
                var rootTaskText: String?
                var showEllipsis = false
                var siblingPosition: Int?
                var siblingCount: Int?

                // Fetch parent task text if parent exists
                if let parentId = displayParentId {
                    dispatchGroup.enter()
                    CloudKitManager.shared.fetchTaskById(parentId) { result in
                        defer { dispatchGroup.leave() }
                        switch result {
                        case .success(let parentRecord):
                            parentTaskText = parentRecord["text"] as? String
                            print("✅ [Sibling Creation] Fetched parent text: \(parentTaskText ?? "nil")")

                            // Calculate showEllipsis: check if parent's parent != root
                            if let parentParentId = parentRecord["parent_id"] as? String,
                               let rootId = displayRootId,
                               parentParentId != rootId {
                                showEllipsis = true
                                print("📊 [Sibling Creation] showEllipsis=true (parent's parent exists and != root)")
                            } else {
                                print("📊 [Sibling Creation] showEllipsis=false (parent's parent is root or doesn't exist)")
                            }
                        case .failure(let error):
                            print("⚠️ [Sibling Creation] Failed to fetch parent text: \(error.localizedDescription)")
                        }
                    }

                    // Fetch root task text if root exists and is different from parent
                    if let rootId = displayRootId, rootId != parentId {
                        dispatchGroup.enter()
                        CloudKitManager.shared.fetchTaskById(rootId) { result in
                            defer { dispatchGroup.leave() }
                            switch result {
                            case .success(let rootRecord):
                                rootTaskText = rootRecord["text"] as? String
                                print("✅ [Sibling Creation] Fetched root text: \(rootTaskText ?? "nil")")
                            case .failure(let error):
                                print("⚠️ [Sibling Creation] Failed to fetch root text: \(error.localizedDescription)")
                            }
                        }
                    }

                    // Fetch siblings - automatically includes newly created sibling!
                    dispatchGroup.enter()
                    CloudKitManager.shared.fetchSiblings(parentId: parentId) { result in
                        defer { dispatchGroup.leave() }
                        switch result {
                        case .success(let siblings):
                            siblingCount = siblings.count + 1  // +1 for newly created sibling (accounts for index lag)

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
                        case .failure(let error):
                            print("⚠️ [Sibling Creation] Failed to fetch siblings: \(error.localizedDescription)")
                        }
                    }
                }

                // Wait for all fetches to complete
                dispatchGroup.notify(queue: .main) {
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
                }

                // Log to file for backup
                self?.logManager.log(text: text, id: taskId, parentId: reference.parentId)

            case .failure(let error):
                ToastManager.shared.show("❌ Error: \(error.localizedDescription)", type: .error)
            }
        }
    }

    // MARK: - Sibling Selection

    private func showSiblingSelector() {
        print("🔍 [Sibling Selector] Triggered via Cmd+Shift+S")

        // Check if current task exists
        guard let current = AppState.shared.currentTask else {
            ToastManager.shared.show("⚠️ No current task. Switch to a task first.", type: .error)
            print("⚠️ [Sibling Selector] No current task in AppState")
            return
        }

        // Check if current task has a parent
        guard let parentId = current.parentId else {
            ToastManager.shared.show("⚠️ Current task has no parent. Cannot show siblings.", type: .error)
            print("⚠️ [Sibling Selector] Current task is top-level (no parent)")
            return
        }

        print("📊 [Sibling Selector] Current task: \(current.text)")
        print("🔗 [Sibling Selector] Parent ID: \(parentId)")

        // Fetch siblings from CloudKit
        CloudKitManager.shared.fetchSiblings(parentId: parentId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let siblings):
                    // Include the current task in the list if it's not already present
                    var allSiblings = siblings.map { (id: $0.id, text: $0.text) }

                    // Check if current task is in the list, add if missing
                    if !allSiblings.contains(where: { $0.id == current.id }) {
                        allSiblings.append((id: current.id, text: current.text))
                        // Re-sort by timestamp (current task added at end)
                        print("ℹ️ [Sibling Selector] Current task added to sibling list")
                    }

                    // Find current task's index
                    let currentIndex = allSiblings.firstIndex(where: { $0.id == current.id }) ?? 0

                    print("✅ [Sibling Selector] Found \(allSiblings.count) siblings")
                    print("📊 [Sibling Selector] Current index: \(currentIndex + 1)/\(allSiblings.count)")

                    // Show panel with siblings
                    self?.siblingSelectorPanel.show(siblings: allSiblings, currentIndex: currentIndex)

                case .failure(let error):
                    ToastManager.shared.show("❌ Failed to fetch siblings: \(error.localizedDescription)", type: .error)
                    print("❌ [Sibling Selector] Fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleSiblingSelection(taskId: String, taskText: String) {
        print("🔄 [Sibling Switch] Selected sibling: \(taskText) (ID: \(taskId))")

        // Hide the panel first
        siblingSelectorPanel.hide()

        // Fetch the full task record to get all metadata
        CloudKitManager.shared.fetchTaskById(taskId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let record):
                    let text = record["text"] as? String ?? taskText
                    let parentId = record["parent_id"] as? String
                    let rootId = record["root_id"] as? String

                    print("📝 [Sibling Switch] Task metadata: parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")

                    // Update AppState
                    AppState.shared.setCurrent(id: taskId, text: text, parentId: parentId, rootId: rootId)

                    // Fetch all display info for pointer update
                    let dispatchGroup = DispatchGroup()
                    var parentTaskText: String?
                    var rootTaskText: String?
                    var showEllipsis = false
                    var siblingPosition: Int?
                    var siblingCount: Int?

                    // Fetch parent task text
                    if let parentId = parentId {
                        dispatchGroup.enter()
                        CloudKitManager.shared.fetchTaskById(parentId) { result in
                            defer { dispatchGroup.leave() }
                            switch result {
                            case .success(let parentRecord):
                                parentTaskText = parentRecord["text"] as? String
                                print("✅ [Sibling Switch] Fetched parent text: \(parentTaskText ?? "nil")")

                                // Calculate showEllipsis: check if parent's parent != root
                                if let parentParentId = parentRecord["parent_id"] as? String,
                                   let rootId = rootId,
                                   parentParentId != rootId {
                                    showEllipsis = true
                                    print("📊 [Sibling Switch] showEllipsis=true (parent's parent exists and != root)")
                                } else {
                                    print("📊 [Sibling Switch] showEllipsis=false")
                                }
                            case .failure(let error):
                                print("⚠️ [Sibling Switch] Failed to fetch parent text: \(error.localizedDescription)")
                            }
                        }

                        // Fetch root task text if root exists and is different from parent
                        if let rootId = rootId, rootId != parentId {
                            dispatchGroup.enter()
                            CloudKitManager.shared.fetchTaskById(rootId) { result in
                                defer { dispatchGroup.leave() }
                                switch result {
                                case .success(let rootRecord):
                                    rootTaskText = rootRecord["text"] as? String
                                    print("✅ [Sibling Switch] Fetched root text: \(rootTaskText ?? "nil")")
                                case .failure(let error):
                                    print("⚠️ [Sibling Switch] Failed to fetch root text: \(error.localizedDescription)")
                                }
                            }
                        }

                        // Fetch siblings to get position/count
                        dispatchGroup.enter()
                        CloudKitManager.shared.fetchSiblings(parentId: parentId) { result in
                            defer { dispatchGroup.leave() }
                            switch result {
                            case .success(let siblings):
                                // Find position in sorted list
                                var allSiblings = siblings
                                if !allSiblings.contains(where: { $0.id == taskId }) {
                                    // Add current task if not in list (edge case)
                                    allSiblings.append((id: taskId, text: text, timestamp: Date()))
                                }
                                siblingCount = allSiblings.count
                                siblingPosition = allSiblings.firstIndex(where: { $0.id == taskId }).map { $0 + 1 }
                                print("✅ [Sibling Switch] Sibling info: position=\(siblingPosition ?? 0)/\(siblingCount ?? 0)")
                            case .failure(let error):
                                print("⚠️ [Sibling Switch] Failed to fetch siblings: \(error.localizedDescription)")
                            }
                        }
                    }

                    // Wait for all fetches to complete
                    dispatchGroup.notify(queue: .main) {
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
                                print("⚠️ [Sibling Switch] Pointer update failed: \(error.localizedDescription)")
                            }
                        }

                        // Show success toast
                        if let position = siblingPosition, let count = siblingCount {
                            ToastManager.shared.show("✓ Switched to sibling \(position)/\(count)", type: .success)
                        } else {
                            ToastManager.shared.show("✓ Switched to sibling", type: .success)
                        }
                    }

                case .failure(let error):
                    ToastManager.shared.show("❌ Failed to load task: \(error.localizedDescription)", type: .error)
                    print("❌ [Sibling Switch] Task fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Root Selector

    private func showRootSelector() {
        print("🌳 [Root Selector] Triggered via Cmd+Shift+R")

        // Fetch all root tasks from CloudKit
        CloudKitManager.shared.fetchRoots { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let roots):
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
                    self?.rootSelectorPanel.show(roots: rootList, currentRootId: currentRootId)

                case .failure(let error):
                    ToastManager.shared.show("❌ Failed to fetch roots: \(error.localizedDescription)", type: .error)
                    print("❌ [Root Selector] Fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleRootSelection(rootId: String, rootText: String) {
        print("🔄 [Root Switch] Selected root: \(rootText) (ID: \(rootId))")

        // Hide the panel first
        rootSelectorPanel.hide()

        // Fetch the latest task in this tree
        CloudKitManager.shared.fetchLatestTaskInTree(rootId: rootId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let latestTaskRecord):
                    let taskId = latestTaskRecord.recordID.recordName
                    let text = latestTaskRecord["text"] as? String ?? rootText
                    let parentId = latestTaskRecord["parent_id"] as? String
                    let rootIdFromRecord = latestTaskRecord["root_id"] as? String

                    print("📝 [Root Switch] Latest task in tree: \(text)")
                    print("📝 [Root Switch] Task metadata: taskId=\(taskId) | parentId=\(parentId ?? "nil") | rootId=\(rootIdFromRecord ?? "nil")")

                    // Update AppState
                    AppState.shared.setCurrent(id: taskId, text: text, parentId: parentId, rootId: rootIdFromRecord)

                    // Fetch all display info for pointer update
                    let dispatchGroup = DispatchGroup()
                    var parentTaskText: String?
                    var rootTaskText: String?
                    var showEllipsis = false
                    var siblingPosition: Int?
                    var siblingCount: Int?

                    // Fetch parent task text if it exists
                    if let parentId = parentId {
                        dispatchGroup.enter()
                        CloudKitManager.shared.fetchTaskById(parentId) { result in
                            defer { dispatchGroup.leave() }
                            switch result {
                            case .success(let parentRecord):
                                parentTaskText = parentRecord["text"] as? String
                                print("✅ [Root Switch] Fetched parent text: \(parentTaskText ?? "nil")")

                                // Calculate showEllipsis: check if parent's parent != root
                                if let parentParentId = parentRecord["parent_id"] as? String,
                                   let rootId = rootIdFromRecord,
                                   parentParentId != rootId {
                                    showEllipsis = true
                                    print("📊 [Root Switch] showEllipsis=true (parent's parent exists and != root)")
                                } else {
                                    print("📊 [Root Switch] showEllipsis=false")
                                }
                            case .failure(let error):
                                print("⚠️ [Root Switch] Parent fetch failed: \(error.localizedDescription)")
                            }
                        }

                        // Fetch siblings
                        dispatchGroup.enter()
                        CloudKitManager.shared.fetchSiblings(parentId: parentId) { result in
                            defer { dispatchGroup.leave() }
                            switch result {
                            case .success(let siblings):
                                // Use smart check pattern to handle index lag
                                var allSiblings = siblings
                                if !allSiblings.contains(where: { $0.id == taskId }) {
                                    // Task not in list (index lag) - add it manually
                                    allSiblings.append((id: taskId, text: text, timestamp: Date()))
                                }
                                siblingCount = allSiblings.count
                                siblingPosition = allSiblings.firstIndex(where: { $0.id == taskId }).map { $0 + 1 }
                                print("✅ [Root Switch] Sibling position: \(siblingPosition ?? 0)/\(siblingCount ?? 0)")
                            case .failure(let error):
                                print("⚠️ [Root Switch] Sibling fetch failed: \(error.localizedDescription)")
                            }
                        }
                    }

                    // Fetch root task text if it exists and is different from parent
                    if let rootId = rootIdFromRecord, rootId != parentId {
                        dispatchGroup.enter()
                        CloudKitManager.shared.fetchTaskById(rootId) { result in
                            defer { dispatchGroup.leave() }
                            switch result {
                            case .success(let rootRecord):
                                rootTaskText = rootRecord["text"] as? String
                                print("✅ [Root Switch] Fetched root text: \(rootTaskText ?? "nil")")
                            case .failure(let error):
                                print("⚠️ [Root Switch] Root fetch failed: \(error.localizedDescription)")
                            }
                        }
                    }

                    // Wait for all fetches to complete, then update pointer
                    dispatchGroup.notify(queue: .main) {
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

                case .failure(let error):
                    ToastManager.shared.show("❌ Failed to load latest task: \(error.localizedDescription)", type: .error)
                    print("❌ [Root Switch] Latest task fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

