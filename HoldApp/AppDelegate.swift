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

        // Setup hotkeys
        hotkeyManager = HotkeyManager()
        hotkeyManager.onShowHotkey = { [weak self] in
            self?.spotlightPanel.show()
        }
        hotkeyManager.onHideHotkey = { [weak self] in
            self?.spotlightPanel.hide()
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

                    // Update pointer for instant iPhone sync
                    CloudKitManager.shared.updateCurrentTaskPointer(taskId: taskId, text: text, parentId: parentId, rootId: rootId) { error in
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

                // Update pointer for instant iPhone sync
                CloudKitManager.shared.updateCurrentTaskPointer(taskId: taskId, text: text, parentId: parent.id, rootId: rootId) { error in
                    if let error = error {
                        print("⚠️ [AppDelegate] Pointer update failed: \(error.localizedDescription)")
                    }
                }

                ToastManager.shared.show("✓ Child created under \(parent.text) (current)", type: .success)

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

                // Update current task if switching
                if switchTo {
                    AppState.shared.setCurrent(id: taskId, text: text, parentId: reference.parentId, rootId: rootId)

                    // Update pointer for instant iPhone sync
                    CloudKitManager.shared.updateCurrentTaskPointer(taskId: taskId, text: text, parentId: reference.parentId, rootId: rootId) { error in
                        if let error = error {
                            print("⚠️ [AppDelegate] Pointer update failed: \(error.localizedDescription)")
                        }
                    }

                    ToastManager.shared.show("✓ Sibling created (current)", type: .success)
                } else {
                    ToastManager.shared.show("✓ Sibling created", type: .success)
                }

                // Log to file for backup
                self?.logManager.log(text: text, id: taskId, parentId: reference.parentId)

            case .failure(let error):
                ToastManager.shared.show("❌ Error: \(error.localizedDescription)", type: .error)
            }
        }
    }
}

