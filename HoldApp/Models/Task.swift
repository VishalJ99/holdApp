import Foundation
import SwiftData

@Model
final class Task {
    // Identity
    @Attribute(.unique) var id: UUID

    // Content
    var text: String

    // Timestamps
    var createdAt: Date
    var timestamp: Date // For legacy compatibility with existing CloudKit records

    // Hierarchy
    var parent: Task?
    @Relationship(deleteRule: .cascade, inverse: \Task.parent)
    var children: [Task] = []
    var sortOrder: Int // For sibling ordering

    // State
    var isCurrent: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date?
    var dismissedAt: Date?

    // Computed properties
    var isDismissed: Bool {
        dismissedAt != nil
    }

    var isActive: Bool {
        !isCompleted && !isDismissed
    }

    var nextSibling: Task? {
        guard let parent = parent else {
            // Top-level task: find next top-level sibling
            // Will implement in TaskManager
            return nil
        }

        return parent.children
            .filter { $0.sortOrder > self.sortOrder }
            .sorted { $0.sortOrder < $1.sortOrder }
            .first
    }

    var previousSibling: Task? {
        guard let parent = parent else { return nil }

        return parent.children
            .filter { $0.sortOrder < self.sortOrder }
            .sorted { $0.sortOrder > $1.sortOrder }
            .first
    }

    // Initializer
    init(
        text: String,
        parent: Task? = nil,
        sortOrder: Int? = nil,
        isCurrent: Bool = false
    ) {
        self.id = UUID()
        self.text = text
        self.createdAt = Date()
        self.timestamp = Date() // Legacy field
        self.parent = parent

        // Auto-calculate sortOrder if not provided
        if let sortOrder = sortOrder {
            self.sortOrder = sortOrder
        } else if let parent = parent {
            self.sortOrder = (parent.children.map(\.sortOrder).max() ?? -1) + 1
        } else {
            self.sortOrder = 0 // Will be calculated by TaskManager for top-level
        }

        self.isCurrent = isCurrent
    }
}
