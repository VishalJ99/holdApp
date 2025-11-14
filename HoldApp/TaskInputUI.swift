//
//  TaskInputUI.swift
//  HoldApp
//
//  Protocol for task input interfaces (spotlight-like UI)
//

import Foundation

/// Protocol for task input interfaces
/// Implementations can be custom views, third-party wrappers, etc.
protocol TaskInputUI {

    // MARK: - Visibility

    /// Show the task input UI
    func show()

    /// Hide the task input UI
    func hide()

    /// Whether the UI is currently visible
    var isVisible: Bool { get }

    // MARK: - Callbacks

    /// Called when user submits a task with modifier keys
    /// - Parameters:
    ///   - text: The task text entered
    ///   - type: The creation type based on modifier keys pressed
    var onTaskSubmit: ((String, TaskCreationType) -> Void)? { get set }

    /// Called when user updates a task in edit mode
    /// - Parameters:
    ///   - taskId: The ID of the task being updated
    ///   - newText: The updated task text
    var onTaskUpdate: ((String, String) -> Void)? { get set }

    /// Called when user cancels (presses Escape)
    var onCancel: (() -> Void)? { get set }
}

/// Types of task creation based on modifier keys
enum TaskCreationType {
    case topLevel              // Enter - create at root
    case topLevelAndSwitch     // Ctrl+Enter - create at root and switch to it
    case child                 // Shift+Enter - create as child of current
    case sibling               // Cmd+Enter - create as sibling of current
    case siblingAndSwitch      // Cmd+Ctrl+Enter - create sibling and switch
}
