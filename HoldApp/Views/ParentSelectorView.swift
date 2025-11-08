import SwiftUI

struct ParentSelectorView: View {
    let taskManager: TaskManager
    let onSelect: (Task?) -> Void
    let excludeTaskId: UUID? // Task that can't be selected (self or has children)

    @State private var filterText: String = ""
    @State private var selectedTaskId: UUID?

    var filteredTasks: [Task] {
        let allTasks = taskManager.fetchActiveTasks()
        let filtered = filterText.isEmpty
            ? allTasks
            : taskManager.searchTasks(query: filterText)

        // Exclude the task being edited (can't self-parent)
        return filtered.filter { task in
            if let excludeId = excludeTaskId {
                // Can't select self or any of its children
                return task.id != excludeId && !task.children.contains(where: { $0.id == excludeId })
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Select Parent Task")
                .font(.headline)
                .padding()

            // Filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Filter...", text: $filterText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Task list
            List(selection: $selectedTaskId) {
                ForEach(filteredTasks, id: \.id) { task in
                    TaskRow(task: task, level: 0)
                        .tag(task.id)
                        .onTapGesture(count: 1) {
                            // Single click selects and closes
                            onSelect(task)
                        }
                }
            }
            .listStyle(.plain)

            Divider()

            // Buttons
            HStack {
                Button("Clear Parent") {
                    onSelect(nil)
                }

                Spacer()

                Button("Cancel") {
                    onSelect(nil)
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Select") {
                    if let id = selectedTaskId,
                       let task = taskManager.fetchTask(id: id) {
                        onSelect(task)
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(selectedTaskId == nil)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }
}
