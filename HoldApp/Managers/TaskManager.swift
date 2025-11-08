import Foundation
import SwiftData
import Observation

@Observable
final class TaskManager {
    private let modelContext: ModelContext
    private let appState: AppState

    init(modelContext: ModelContext, appState: AppState) {
        self.modelContext = modelContext
        self.appState = appState
    }

    // MARK: - Task Creation

    func createTask(
        text: String,
        parent: Task? = nil,
        setCurrent: Bool = false
    ) -> Task {
        let task = Task(
            text: text,
            parent: parent,
            sortOrder: calculateSortOrder(parent: parent),
            isCurrent: setCurrent
        )

        modelContext.insert(task)

        if setCurrent {
            setCurrentTask(task)
        }

        do {
            try modelContext.save()
            print("✅ Task created: \"\(text)\" (parent: \(parent?.text ?? "nil"), setCurrent: \(setCurrent))")
        } catch {
            print("❌ Failed to save task: \(error)")
        }

        return task
    }

    private func calculateSortOrder(parent: Task?) -> Int {
        if let parent = parent {
            return (parent.children.map(\.sortOrder).max() ?? -1) + 1
        } else {
            // Top-level tasks
            let descriptor = FetchDescriptor<Task>(
                predicate: #Predicate { $0.parent == nil }
            )
            let topLevelTasks = (try? modelContext.fetch(descriptor)) ?? []
            return (topLevelTasks.map(\.sortOrder).max() ?? -1) + 1
        }
    }

    // MARK: - Current Task Management

    func setCurrentTask(_ task: Task) {
        // Clear old current
        if let currentId = appState.currentTaskId,
           let oldCurrent = fetchTask(id: currentId) {
            oldCurrent.isCurrent = false
        }

        // Set new current
        task.isCurrent = true
        appState.currentTaskId = task.id

        do {
            try modelContext.save()
            print("✅ Current task set to: \"\(task.text)\"")
        } catch {
            print("❌ Failed to set current task: \(error)")
        }
    }

    func getCurrentTask() -> Task? {
        guard let currentId = appState.currentTaskId else { return nil }
        return fetchTask(id: currentId)
    }

    // MARK: - Task Actions

    func completeTask(_ task: Task) {
        task.isCompleted = true
        task.completedAt = Date()

        print("✅ Task completed: \"\(task.text)\"")

        if task.isCurrent {
            advanceToNextTask()
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save completed task: \(error)")
        }
    }

    func dismissTask(_ task: Task) {
        task.dismissedAt = Date()

        print("✅ Task dismissed: \"\(task.text)\"")

        if task.isCurrent {
            advanceToNextTask()
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save dismissed task: \(error)")
        }
    }

    // MARK: - Next Task Selection Algorithm

    @discardableResult
    func advanceToNextTask() -> Task? {
        guard let current = getCurrentTask() else {
            appState.currentTaskId = nil
            print("DEBUG: No current task to advance from")
            return nil
        }

        current.isCurrent = false
        print("DEBUG: Advancing from task: \"\(current.text)\"")

        // Algorithm from Hold State Diagrams.md lines 583-604

        // 1. Check for next sibling
        if let nextSibling = current.nextSibling, nextSibling.isActive {
            setCurrentTask(nextSibling)
            print("DEBUG: Step 1 - Advancing to next sibling: \"\(nextSibling.text)\"")
            return nextSibling
        }

        // 2. If no next sibling, return to parent
        if let parent = current.parent, parent.isActive {
            setCurrentTask(parent)
            print("DEBUG: Step 2 - Returning to parent: \"\(parent.text)\"")
            return parent
        }

        // 3. If no parent, check for previous sibling
        if let previousSibling = current.previousSibling, previousSibling.isActive {
            setCurrentTask(previousSibling)
            print("DEBUG: Step 3 - Advancing to previous sibling: \"\(previousSibling.text)\"")
            return previousSibling
        }

        // 4. If none of above, get next from queue (oldest waiting)
        if let nextInQueue = getNextInQueue() {
            setCurrentTask(nextInQueue)
            print("DEBUG: Step 4 - Advancing to next in queue: \"\(nextInQueue.text)\"")
            return nextInQueue
        }

        // 5. Empty state
        appState.currentTaskId = nil
        print("DEBUG: Step 5 - Empty state (no more tasks)")
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save empty state: \(error)")
        }
        return nil
    }

    private func getNextInQueue() -> Task? {
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { task in
                task.isActive && !task.isCurrent
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Queries

    func fetchTask(id: UUID) -> Task? {
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func fetchActiveTasks() -> [Task] {
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchAllTasks() -> [Task] {
        let descriptor = FetchDescriptor<Task>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func searchTasks(query: String) -> [Task] {
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { task in
                task.isActive && task.text.localizedStandardContains(query)
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
