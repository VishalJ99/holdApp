//
//  AppState.swift
//  HoldApp
//
//  Global application state
//

import Foundation
import CloudKit

/// Holds the current task that iPhone is displaying
/// Used as reference point for child/sibling creation
class AppState {
    static let shared = AppState()

    private init() {}

    /// The task currently displayed on iPhone
    /// - Child tasks are created under this task (Shift+Enter)
    /// - Sibling tasks share the same parent as this task (Cmd+Enter)
    var currentTask: TaskReference?

    /// Clears the current task reference
    func clearCurrent() {
        currentTask = nil
    }

    /// Sets a new current task
    func setCurrent(id: String, text: String, parentId: String?, rootId: String?) {
        currentTask = TaskReference(id: id, text: text, parentId: parentId, rootId: rootId)
        print("📱 [AppState] Current task set: id=\(id) | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")
    }
}

/// Lightweight reference to a task (avoids holding full CKRecord)
struct TaskReference {
    let id: String           // CloudKit record ID
    let text: String         // Task text (for display)
    let parentId: String?    // Parent task ID (nil if top-level)
    let rootId: String?      // Root task ID (nil if this is root or legacy task)
}
