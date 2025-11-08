import SwiftUI
import SwiftData

struct EditorView: View {
    @ObservedObject var appState: AppState
    let taskManager: TaskManager
    let onClose: () -> Void

    @FocusState private var isFilterFocused: Bool
    @State private var selectedTaskId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar - always visible (sticky)
            FilterBar(
                filterText: $appState.filterText,
                isFocused: $isFilterFocused,
                mode: appState.editorMode
            )
            .frame(height: 44)
            .background(Color(NSColor.controlBackgroundColor))
            .border(Color.gray.opacity(0.2), width: 1)

            // Task list/tree
            TaskListView(
                filterText: appState.filterText,
                selectedTaskId: $selectedTaskId,
                taskManager: taskManager,
                appState: appState,
                isFilterFocused: $isFilterFocused
            )
        }
        .frame(minWidth: 400, minHeight: 600)
        .onAppear {
            // Restore filter and mode from previous session
            if !appState.filterText.isEmpty {
                isFilterFocused = true
                appState.editorMode = .filterFocused
            } else {
                appState.editorMode = .treeView
            }
        }
        .onChange(of: appState.filterText) { oldValue, newValue in
            if newValue.isEmpty {
                appState.editorMode = .treeView
                isFilterFocused = false
            } else if isFilterFocused {
                appState.editorMode = .filterFocused
            }
        }
    }
}

struct FilterBar: View {
    @Binding var filterText: String
    var isFocused: FocusState<Bool>.Binding
    let mode: AppState.EditorMode

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 12)

            TextField("Filter tasks...", text: $filterText)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .font(.system(size: 14))

            if !filterText.isEmpty {
                Button(action: { filterText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 8)
        .background(
            mode == .filterFocused
                ? Color.blue.opacity(0.1)
                : Color.clear
        )
        .overlay(
            mode == .filterFocused
                ? Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
                : nil
        )
    }
}

struct TaskListView: View {
    let filterText: String
    @Binding var selectedTaskId: UUID?
    let taskManager: TaskManager
    let appState: AppState
    var isFocused: FocusState<Bool>.Binding

    var tasks: [Task] {
        let allTasks = taskManager.fetchActiveTasks()
        if filterText.isEmpty {
            // Tree view - show only top-level
            return allTasks.filter { $0.parent == nil }.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            // Filter mode - flat list of matching tasks
            return taskManager.searchTasks(query: filterText)
        }
    }

    var body: some View {
        List(selection: $selectedTaskId) {
            if filterText.isEmpty {
                // State 1: Tree View
                ForEach(tasks, id: \.id) { task in
                    TaskRow(task: task, level: 0)
                        .tag(task.id)
                }
            } else {
                // State 2/3: Filter Mode
                ForEach(tasks, id: \.id) { task in
                    TaskRow(task: task, level: 0, showHierarchy: false)
                        .tag(task.id)
                }
            }
        }
        .listStyle(.plain)
        .onChange(of: selectedTaskId) { oldValue, newValue in
            if newValue != nil {
                appState.editorMode = .taskSelected
                isFocused.wrappedValue = false
            }
        }
        .background(TaskKeyboardHandler(
            selectedTaskId: $selectedTaskId,
            filterText: $appState.filterText,
            taskManager: taskManager,
            appState: appState,
            isFocused: isFocused,
            onClose: { /* Handle Esc */ }
        ))
    }
}

struct TaskRow: View {
    let task: Task
    let level: Int
    var showHierarchy: Bool = true

    var body: some View {
        HStack {
            if showHierarchy {
                // Indentation for hierarchy
                Spacer()
                    .frame(width: CGFloat(level) * UIConstants.hierarchyIndentation)
            }

            if task.isCurrent {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
            }

            Text(task.text)
                .font(.system(size: UIConstants.editorFontSize))

            Spacer()

            if !task.children.isEmpty {
                Text("\(task.children.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .contentShape(Rectangle())
    }
}

// Handle keyboard events in Editor
struct TaskKeyboardHandler: NSViewRepresentable {
    @Binding var selectedTaskId: UUID?
    @Binding var filterText: String
    let taskManager: TaskManager
    let appState: AppState
    var isFocused: FocusState<Bool>.Binding
    let onClose: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyEventView()
        view.onSpace = {
            // Set selected task as current
            if let id = selectedTaskId, let task = taskManager.fetchTask(id: id) {
                taskManager.setCurrentTask(task)
                ToastManager.shared.showSuccess("✓ Set as current: \(task.text)")
            }
        }
        view.onBackspace = {
            // Dismiss selected task
            if let id = selectedTaskId, let task = taskManager.fetchTask(id: id) {
                let taskName = task.text
                taskManager.dismissTask(task)
                ToastManager.shared.showSuccess("✓ Dismissed: \(taskName)")
                selectedTaskId = nil
            }
        }
        view.onEscape = {
            // Clear filter
            filterText = ""
            appState.editorMode = .treeView
        }
        view.onTyping = {
            // Return to filter mode (sticky filter)
            isFocused.wrappedValue = true
            appState.editorMode = .filterFocused
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyEventView: NSView {
        var onSpace: (() -> Void)?
        var onBackspace: (() -> Void)?
        var onEscape: (() -> Void)?
        var onTyping: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 49: // Space
                onSpace?()
            case 51: // Backspace
                onBackspace?()
            case 53: // Escape
                onEscape?()
            default:
                // Any other key = typing, return to filter
                if event.characters?.isEmpty == false {
                    onTyping?()
                }
                super.keyDown(with: event)
            }
        }
    }
}
