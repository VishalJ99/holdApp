//
//  LocalTaskStore.swift
//  HoldApp
//
//  Local-first task storage using JSON file
//

import Foundation

class LocalTaskStore {
    static let shared = LocalTaskStore()

    private let fileURL: URL

    // MARK: - Data Models

    struct Task: Codable {
        let id: String
        let text: String
        let timestamp: Date
        let parent_id: String?
        let root_id: String?
        let isCompleted: Bool
    }

    struct TasksFile: Codable {
        var tasks: [Task]
    }

    // MARK: - Initialization

    private init() {
        // Store in Application Support directory
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let holdAppDir = appSupportURL.appendingPathComponent("HoldApp", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: holdAppDir.path) {
            try? FileManager.default.createDirectory(at: holdAppDir, withIntermediateDirectories: true)
        }

        fileURL = holdAppDir.appendingPathComponent("tasks.json")

        // Initialize empty file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let emptyFile = TasksFile(tasks: [])
            try? saveToFile(emptyFile)
        }
    }

    // MARK: - File I/O

    private func loadFromFile() -> TasksFile {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return TasksFile(tasks: [])
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TasksFile.self, from: data)
        } catch {
            print("Error loading tasks from file: \(error)")
            return TasksFile(tasks: [])
        }
    }

    private func saveToFile(_ tasksFile: TasksFile) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(tasksFile)

        // Atomic write - write to temp file then rename
        let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent("tasks.tmp.json")
        try data.write(to: tempURL, options: .atomic)

        // Replace old file with new one atomically
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
    }

    // MARK: - Public API

    /// Save a new task to local storage
    func saveTask(id: String, text: String, timestamp: Date, parent_id: String?, root_id: String?, isCompleted: Bool = false) {
        var tasksFile = loadFromFile()

        let newTask = Task(
            id: id,
            text: text,
            timestamp: timestamp,
            parent_id: parent_id,
            root_id: root_id,
            isCompleted: isCompleted
        )

        tasksFile.tasks.append(newTask)

        do {
            try saveToFile(tasksFile)
        } catch {
            print("Error saving task: \(error)")
        }
    }

    /// Fetch all tasks from local storage
    func fetchAllTasks() -> [Task] {
        return loadFromFile().tasks
    }

    /// Fetch all root tasks (tasks with no parent)
    /// Sorted by timestamp ASC (oldest first, creation order)
    func fetchRoots() -> [Task] {
        let allTasks = fetchAllTasks()
        return allTasks
            .filter { $0.parent_id == nil }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Fetch all siblings of a given parent
    /// Sorted by timestamp ASC (oldest first, creation order)
    func fetchSiblings(parentId: String) -> [Task] {
        let allTasks = fetchAllTasks()
        return allTasks
            .filter { $0.parent_id == parentId }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Fetch a task by ID
    func fetchTaskById(_ id: String) -> Task? {
        let allTasks = fetchAllTasks()
        return allTasks.first { $0.id == id }
    }

    /// Fetch the latest task in a tree (most recent timestamp)
    /// Useful for root selection - switches to the deepest/newest task in a tree
    func fetchLatestInTree(rootId: String) -> Task? {
        let allTasks = fetchAllTasks()

        // First try to find descendants of this root
        let descendants = allTasks
            .filter { $0.root_id == rootId }
            .sorted { $0.timestamp > $1.timestamp }

        if let latest = descendants.first {
            return latest
        }

        // Fallback: fetch the root itself (if no descendants exist yet)
        return allTasks.first { $0.id == rootId }
    }

    /// Find the oldest leaf task at the deepest level in a tree
    /// Used for hierarchical queue navigation when switching roots
    /// Returns the leaf task at maximum depth, preferring oldest by creation time
    func fetchDeepestOldestLeaf(rootId: String) -> Task? {
        let allTasks = fetchAllTasks()
        let treeTasks = allTasks.filter { $0.root_id == rootId }

        // If tree is empty, return the root itself
        if treeTasks.isEmpty {
            return allTasks.first { $0.id == rootId }
        }

        // Calculate depth for each task by walking up parent chain
        var taskDepths: [String: Int] = [:]
        for task in treeTasks {
            var depth = 0
            var currentId = task.parent_id

            // Walk up to root, counting levels
            while let parentId = currentId {
                depth += 1
                if let parentTask = allTasks.first(where: { $0.id == parentId }) {
                    currentId = parentTask.parent_id
                } else {
                    break
                }
            }

            taskDepths[task.id] = depth
        }

        // Find maximum depth in the tree
        guard let maxDepth = taskDepths.values.max() else {
            return allTasks.first { $0.id == rootId }
        }

        // Filter for tasks at max depth that are leaves (no children)
        let leavesAtMaxDepth = treeTasks.filter { task in
            taskDepths[task.id] == maxDepth && !hasChildren(taskId: task.id)
        }

        // Return oldest leaf by creation time (timestamp ASC)
        return leavesAtMaxDepth.sorted { $0.timestamp < $1.timestamp }.first
    }

    /// Clear all tasks (dev utility for fresh start)
    func clearAllTasks() {
        let emptyFile = TasksFile(tasks: [])
        do {
            try saveToFile(emptyFile)
            print("✅ Cleared all tasks from local storage")
        } catch {
            print("Error clearing tasks: \(error)")
        }
    }

    /// Delete a task by ID
    /// Returns true if task was found and deleted, false otherwise
    func deleteTask(id: String) -> Bool {
        var tasksFile = loadFromFile()

        // Find index of task to delete
        guard let index = tasksFile.tasks.firstIndex(where: { $0.id == id }) else {
            print("⚠️ [LocalTaskStore] Task not found: \(id)")
            return false
        }

        // Remove task from array
        let deletedTask = tasksFile.tasks.remove(at: index)
        print("🗑️ [LocalTaskStore] Deleted task: \(deletedTask.text) (id: \(id))")

        // Save updated file
        do {
            try saveToFile(tasksFile)
            print("✅ [LocalTaskStore] File saved after deletion")
            return true
        } catch {
            print("❌ [LocalTaskStore] Error saving after deletion: \(error)")
            return false
        }
    }

    /// Check if a task has any children
    func hasChildren(taskId: String) -> Bool {
        let allTasks = fetchAllTasks()
        return allTasks.contains { $0.parent_id == taskId }
    }

    /// Update the parent (and optionally text) of an existing task
    /// Returns true if task was found and updated, false otherwise
    func updateTaskParent(id: String, newParentId: String, newRootId: String, newText: String? = nil) -> Bool {
        var tasksFile = loadFromFile()

        // Find task by ID
        guard let index = tasksFile.tasks.firstIndex(where: { $0.id == id }) else {
            print("⚠️ [LocalTaskStore] Task not found for re-parent: \(id)")
            return false
        }

        let oldTask = tasksFile.tasks[index]

        // Create updated task with new parent
        let updatedTask = Task(
            id: oldTask.id,
            text: newText ?? oldTask.text,
            timestamp: oldTask.timestamp,
            parent_id: newParentId,
            root_id: newRootId,
            isCompleted: oldTask.isCompleted
        )

        // Replace in array
        tasksFile.tasks[index] = updatedTask
        print("🔄 [LocalTaskStore] Re-parented task: \"\(oldTask.text)\" → parent: \(newParentId)")

        // Save to file
        do {
            try saveToFile(tasksFile)
            print("✅ [LocalTaskStore] File saved after re-parent")
            return true
        } catch {
            print("❌ [LocalTaskStore] Error saving after re-parent: \(error)")
            return false
        }
    }

    /// Update the text of an existing task
    /// Returns true if task was found and updated, false otherwise
    func updateTaskText(id: String, newText: String) -> Bool {
        var tasksFile = loadFromFile()

        // Find task by ID
        guard let index = tasksFile.tasks.firstIndex(where: { $0.id == id }) else {
            print("⚠️ [LocalTaskStore] Task not found for update: \(id)")
            return false
        }

        let oldTask = tasksFile.tasks[index]

        // Create updated task (preserving all other fields)
        let updatedTask = Task(
            id: oldTask.id,
            text: newText,
            timestamp: oldTask.timestamp,
            parent_id: oldTask.parent_id,
            root_id: oldTask.root_id,
            isCompleted: oldTask.isCompleted
        )

        // Replace in array
        tasksFile.tasks[index] = updatedTask
        print("✏️ [LocalTaskStore] Updated task text: \"\(oldTask.text)\" → \"\(newText)\"")

        // Save to file
        do {
            try saveToFile(tasksFile)
            print("✅ [LocalTaskStore] File saved after update")
            return true
        } catch {
            print("❌ [LocalTaskStore] Error saving after update: \(error)")
            return false
        }
    }

    /// Fetch all leaf tasks (tasks with no children) in a given root
    /// Sorted by timestamp ASC (oldest first, creation order)
    /// Used for Leaf Selector (Cmd+Shift+S) - shows all actionable tasks in current tree
    func fetchLeaves(rootId: String) -> [Task] {
        let allTasks = fetchAllTasks()
        let tasksInRoot = allTasks.filter { $0.root_id == rootId || $0.id == rootId }

        // Filter for tasks that have no children
        let leaves = tasksInRoot.filter { task in
            !hasChildren(taskId: task.id)
        }

        return leaves.sorted { $0.timestamp < $1.timestamp }
    }

    /// Fetch all leaf tasks in DFS (depth-first) tree traversal order
    /// Used for leaf indicator - shows position of current leaf among all leaves in root
    /// Position follows tree structure: top-left leaves first, bottom-right last
    func fetchLeavesDFS(rootId: String) -> [Task] {
        let allTasks = fetchAllTasks()
        let tasksInRoot = allTasks.filter { $0.root_id == rootId || $0.id == rootId }

        // Find the root task
        guard let rootTask = tasksInRoot.first(where: { $0.parent_id == nil }) else {
            // If no root found, check if rootId itself is the only task (root with no children)
            if let singleRoot = allTasks.first(where: { $0.id == rootId && $0.parent_id == nil }) {
                // Root itself is a leaf if it has no children
                if !hasChildren(taskId: singleRoot.id) {
                    return [singleRoot]
                }
            }
            return []
        }

        var leaves: [Task] = []

        // DFS traversal collecting only leaves
        func collectLeaves(current: Task) {
            let children = tasksInRoot
                .filter { $0.parent_id == current.id }
                .sorted { $0.timestamp < $1.timestamp }

            if children.isEmpty {
                // Current task is a leaf
                leaves.append(current)
            } else {
                // Recurse into children (DFS order)
                for child in children {
                    collectLeaves(current: child)
                }
            }
        }

        collectLeaves(current: rootTask)
        return leaves
    }

    /// Structure to hold task with tree metadata for rendering
    struct TreeTask {
        let task: Task
        let depth: Int
        let isLast: Bool
        let ancestorsAreLast: [Bool] // Tracks if ancestor at each depth was the last child
        let hasChildren: Bool
    }

    /// Fetch all tasks in the same root hierarchy as the given task
    /// Returns array ordered by DFS (tree order)
    /// Used for Parent Selector (Cmd+P in Spotlight) - shows all possible parents in tree structure
    func fetchAllTasksInHierarchy(taskId: String) -> (tasks: [TreeTask], currentIndex: Int) {
        let allTasks = fetchAllTasks()

        // Find the current task
        guard let currentTask = allTasks.first(where: { $0.id == taskId }) else {
            return ([], -1)
        }

        // Get the root ID
        let rootId = currentTask.root_id ?? currentTask.id

        // Fetch all tasks in this root (including the root itself)
        let tasksInRoot = allTasks.filter { $0.root_id == rootId || $0.id == rootId }
        
        // Find the root task
        guard let rootTask = tasksInRoot.first(where: { $0.parent_id == nil }) else {
            return ([], -1)
        }

        var treeTasks: [TreeTask] = []
        
        // Recursive function to build tree
        func buildTree(current: Task, depth: Int, isLast: Bool, ancestorsAreLast: [Bool]) {
            // Find children
            let children = tasksInRoot
                .filter { $0.parent_id == current.id }
                .sorted { $0.timestamp < $1.timestamp }
            
            // Add current task
            treeTasks.append(TreeTask(
                task: current,
                depth: depth,
                isLast: isLast,
                ancestorsAreLast: ancestorsAreLast,
                hasChildren: !children.isEmpty
            ))
            
            // Recurse for children
            for (index, child) in children.enumerated() {
                let isLastChild = index == children.count - 1
                var newAncestors = ancestorsAreLast
                newAncestors.append(isLast) // Add current node's status for its children
                
                buildTree(
                    current: child,
                    depth: depth + 1,
                    isLast: isLastChild,
                    ancestorsAreLast: newAncestors
                )
            }
        }
        
        // Start building from root
        // Root is technically the last (and only) item at its level (top level)
        buildTree(current: rootTask, depth: 0, isLast: true, ancestorsAreLast: [])

        // Find current task index in the flattened tree list
        let currentIndex = treeTasks.firstIndex(where: { $0.task.id == taskId }) ?? -1

        return (treeTasks, currentIndex)
    }
}
