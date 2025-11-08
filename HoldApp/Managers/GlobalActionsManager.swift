import Foundation
import AppKit

/// Handles global keyboard shortcuts for completing and dismissing tasks
final class GlobalActionsManager {
    private let taskManager: TaskManager
    private let appState: AppState

    init(taskManager: TaskManager, appState: AppState) {
        self.taskManager = taskManager
        self.appState = appState
    }

    func setupGlobalActions() {
        // Listen for notification-based hotkeys (until KeyboardShortcuts package is added)
        NotificationCenter.default.addObserver(
            forName: .completeCurrentTask,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleCompleteCurrentTask()
        }

        NotificationCenter.default.addObserver(
            forName: .dismissCurrentTask,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDismissCurrentTask()
        }
    }

    func handleCompleteCurrentTask() {
        // Check if Editor or Spotlight is open (blocking)
        if appState.isEditorOpen {
            ToastManager.shared.showError("⚠️ Close Editor to complete current task")
            print("⚠️ [GlobalActions] Blocked: Editor is open")
            return
        }

        if appState.isSpotlightOpen {
            ToastManager.shared.showError("⚠️ Close Spotlight to complete current task")
            print("⚠️ [GlobalActions] Blocked: Spotlight is open")
            return
        }

        guard let current = taskManager.getCurrentTask() else {
            ToastManager.shared.showError("⚠️ No current task to complete")
            print("⚠️ [GlobalActions] No current task")
            return
        }

        let taskName = current.text
        taskManager.completeTask(current)

        // Check if there's a next task
        if let next = taskManager.getCurrentTask() {
            ToastManager.shared.showSuccess("✓ Completed: \(taskName)\nCurrent: \(next.text)")
        } else {
            ToastManager.shared.showSuccess("✓ All tasks completed")
        }
    }

    func handleDismissCurrentTask() {
        // Check if Editor or Spotlight is open (blocking)
        if appState.isEditorOpen {
            ToastManager.shared.showError("⚠️ Close Editor to dismiss current task")
            print("⚠️ [GlobalActions] Blocked: Editor is open")
            return
        }

        if appState.isSpotlightOpen {
            ToastManager.shared.showError("⚠️ Close Spotlight to dismiss current task")
            print("⚠️ [GlobalActions] Blocked: Spotlight is open")
            return
        }

        guard let current = taskManager.getCurrentTask() else {
            ToastManager.shared.showError("⚠️ No current task to dismiss")
            print("⚠️ [GlobalActions] No current task")
            return
        }

        let taskName = current.text
        taskManager.dismissTask(current)

        // Check if there's a next task
        if let next = taskManager.getCurrentTask() {
            ToastManager.shared.showSuccess("✓ Dismissed: \(taskName)\nCurrent: \(next.text)")
        } else {
            ToastManager.shared.showSuccess("✓ All tasks dismissed")
        }
    }
}
