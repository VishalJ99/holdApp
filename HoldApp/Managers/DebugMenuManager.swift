import SwiftUI
import AppKit

final class DebugMenuManager {
    private weak var taskManager: TaskManager?
    private weak var appState: AppState?

    init(taskManager: TaskManager, appState: AppState) {
        self.taskManager = taskManager
        self.appState = appState
    }

    func setupDebugMenu() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }

        // Create Debug menu
        let debugMenu = NSMenu(title: "Debug")
        let debugMenuItem = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        debugMenuItem.submenu = debugMenu

        // Add menu items
        let printTreeItem = NSMenuItem(title: "Print Task Tree", action: #selector(printTaskTree), keyEquivalent: "")
        printTreeItem.target = self
        debugMenu.addItem(printTreeItem)

        let printCurrentItem = NSMenuItem(title: "Print Current Task", action: #selector(printCurrentTask), keyEquivalent: "")
        printCurrentItem.target = self
        debugMenu.addItem(printCurrentItem)

        let printAllItem = NSMenuItem(title: "Print All Tasks", action: #selector(printAllTasks), keyEquivalent: "")
        printAllItem.target = self
        debugMenu.addItem(printAllItem)

        let printStateItem = NSMenuItem(title: "Print App State", action: #selector(printAppState), keyEquivalent: "")
        printStateItem.target = self
        debugMenu.addItem(printStateItem)

        debugMenu.addItem(NSMenuItem.separator())

        let advanceItem = NSMenuItem(title: "Manually Advance to Next Task", action: #selector(manuallyAdvanceTask), keyEquivalent: "")
        advanceItem.target = self
        debugMenu.addItem(advanceItem)

        debugMenu.addItem(NSMenuItem.separator())

        let logsItem = NSMenuItem(title: "Open Logs Folder", action: #selector(openLogsFolder), keyEquivalent: "")
        logsItem.target = self
        debugMenu.addItem(logsItem)

        // Insert before Window menu (or append)
        mainMenu.insertItem(debugMenuItem, at: mainMenu.items.count - 1)
    }

    @objc private func printTaskTree() {
        guard let taskManager = taskManager else { return }

        print("\n=== TASK TREE ===")
        let allTasks = taskManager.fetchActiveTasks()
        let topLevel = allTasks.filter { $0.parent == nil }

        for task in topLevel.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            printTask(task, indent: 0)
        }
        print("=================\n")
    }

    private func printTask(_ task: Task, indent: Int) {
        let prefix = String(repeating: "  ", count: indent)
        let indicator = task.isCurrent ? "★ " : ""
        print("\(prefix)\(indicator)\(task.text)")

        for child in task.children.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            printTask(child, indent: indent + 1)
        }
    }

    @objc private func printCurrentTask() {
        guard let taskManager = taskManager else { return }

        print("\n=== CURRENT TASK ===")
        if let current = taskManager.getCurrentTask() {
            print("ID: \(current.id)")
            print("Text: \(current.text)")
            print("Created: \(current.createdAt)")
            print("Parent: \(current.parent?.text ?? "nil")")
            print("Children: \(current.children.count)")
            print("Sort Order: \(current.sortOrder)")
        } else {
            print("No current task")
        }
        print("====================\n")
    }

    @objc private func printAllTasks() {
        guard let taskManager = taskManager else { return }

        print("\n=== ALL TASKS (JSON) ===")
        let tasks = taskManager.fetchAllTasks()
        for task in tasks {
            let json = """
            {
                "id": "\(task.id)",
                "text": "\(task.text)",
                "isCurrent": \(task.isCurrent),
                "isCompleted": \(task.isCompleted),
                "isDismissed": \(task.isDismissed),
                "parent": "\(task.parent?.text ?? "null")",
                "sortOrder": \(task.sortOrder)
            }
            """
            print(json)
        }
        print("========================\n")
    }

    @objc private func printAppState() {
        guard let appState = appState else { return }

        print("\n=== APP STATE ===")
        print("Current Task ID: \(appState.currentTaskId?.uuidString ?? "nil")")
        print("Spotlight Open: \(appState.isSpotlightOpen)")
        print("Editor Open: \(appState.isEditorOpen)")
        print("Parent Selector Open: \(appState.isParentSelectorOpen)")
        print("Filter Text: \"\(appState.filterText)\"")
        print("Editor Mode: \(appState.editorMode)")
        print("=================\n")
    }

    @objc private func manuallyAdvanceTask() {
        guard let taskManager = taskManager else { return }

        print("\n=== MANUALLY ADVANCING TASK ===")
        guard let current = taskManager.getCurrentTask() else {
            print("DEBUG: No current task to advance from")
            print("================================\n")
            return
        }

        print("DEBUG: Advancing from task: \"\(current.text)\"")

        if let next = taskManager.advanceToNextTask() {
            print("DEBUG: Advanced to: \"\(next.text)\"")
        } else {
            print("DEBUG: No more tasks (empty state)")
        }
        print("================================\n")
    }

    @objc private func openLogsFolder() {
        let logsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        NSWorkspace.shared.open(logsURL)
    }
}
