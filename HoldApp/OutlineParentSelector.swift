//
//  OutlineParentSelector.swift
//  HoldApp
//
//  Parent Selector using native SwiftUI List with recursive tree rendering
//

import SwiftUI
import Cocoa

// MARK: - Tree Item Model

struct ParentItem: Hashable, Identifiable {
    let id: String
    let text: String
    let depth: Int
    let isRoot: Bool
    let isCurrent: Bool
    var children: [ParentItem]?

    /// Build nested tree from flat TreeTask array (DFS ordered)
    static func buildTree(from treeTasks: [LocalTaskStore.TreeTask], currentTaskId: String) -> [ParentItem] {
        guard !treeTasks.isEmpty else { return [] }

        // Recursive function to build nested children
        func buildChildren(parentId: String) -> [ParentItem]? {
            let childTasks = treeTasks.filter {
                $0.task.parent_id == parentId
            }.sorted { $0.task.timestamp < $1.task.timestamp }

            if childTasks.isEmpty { return nil }

            return childTasks.map { treeTask in
                ParentItem(
                    id: treeTask.task.id,
                    text: treeTask.task.text,
                    depth: treeTask.depth,
                    isRoot: false,
                    isCurrent: treeTask.task.id == currentTaskId,
                    children: buildChildren(parentId: treeTask.task.id)
                )
            }
        }

        // Find root (depth 0)
        guard let rootTask = treeTasks.first(where: { $0.depth == 0 }) else {
            return []
        }

        let rootItem = ParentItem(
            id: rootTask.task.id,
            text: rootTask.task.text,
            depth: 0,
            isRoot: true,
            isCurrent: rootTask.task.id == currentTaskId,
            children: buildChildren(parentId: rootTask.task.id)
        )

        return [rootItem]
    }

    /// Flatten tree to array for easy iteration
    func flattened() -> [ParentItem] {
        var result = [self]
        if let children = children {
            for child in children {
                result.append(contentsOf: child.flattened())
            }
        }
        return result
    }
}

// MARK: - SwiftUI Parent Selector View

struct OutlineParentSelectorView: View {
    @Binding var selection: ParentItem?
    let treeData: [ParentItem]
    let currentTaskName: String

    // Flatten for keyboard navigation
    private var flatItems: [ParentItem] {
        treeData.flatMap { $0.flattened() }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Color.white.opacity(0.1))

            // Tree list
            ScrollViewReader { proxy in
                List(selection: $selection) {
                    ForEach(treeData) { item in
                        TreeRowRecursive(item: item, selection: $selection)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .onChange(of: selection) { newSelection in
                    if let sel = newSelection {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(sel.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Color.black.opacity(0.95))
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.turn.right.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.4))

            Text("Select Parent for ")
                .foregroundColor(.white.opacity(0.5))
            + Text("\"\(currentTaskName)\"")
                .foregroundColor(.white)

            Spacer()

            // Keyboard hints
            HStack(spacing: 16) {
                KeyHint(key: "↵", label: "Select")
                KeyHint(key: "⌃↵", label: "Select & Switch")
                KeyHint(key: "esc", label: "Cancel")
            }
            .font(.system(size: 11))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Recursive Tree Row

struct TreeRowRecursive: View {
    let item: ParentItem
    @Binding var selection: ParentItem?

    var body: some View {
        if let children = item.children, !children.isEmpty {
            DisclosureGroup(isExpanded: .constant(true)) {
                ForEach(children) { child in
                    TreeRowRecursive(item: child, selection: $selection)
                }
            } label: {
                rowContent
            }
            .disclosureGroupStyle(TreeDisclosureStyle())
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            // Icon
            Group {
                if item.isRoot {
                    Text("▼")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white)
                } else {
                    Text("●")
                        .font(.system(size: 6))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(width: 14)

            // Text
            Text(item.text)
                .font(.system(size: 14, weight: item.isCurrent ? .semibold : .regular))
                .foregroundColor(item.isCurrent ? .white : .white.opacity(0.8))
                .lineLimit(1)

            Spacer()

            // Current indicator
            if item.isCurrent {
                Text("current")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .id(item.id)
        .tag(item)
        .onTapGesture {
            selection = item
        }
    }
}

// MARK: - Custom Disclosure Style (always expanded, no chevron)

struct TreeDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.label
            configuration.content
                .padding(.leading, 20)
        }
    }
}

// MARK: - Keyboard Hint

struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.15))
                .cornerRadius(3)
            Text(label)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - NSPanel Wrapper

class OutlineParentSelectorPanel: NSPanel {
    private var hostingView: NSHostingView<OutlineParentSelectorContentView>!
    private var contentModel = OutlineParentSelectorModel()
    private var localEventMonitor: Any?

    var onParentSelected: ((String, String, Bool) -> Void)?
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel
        self.level = .floating
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isOpaque = false

        setupHostingView()
        setupKeyboardMonitor()
    }

    private func setupKeyboardMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isKeyWindow else { return event }

            if self.handleKeyEvent(event) {
                return nil  // Consume the event
            }
            return event  // Pass it through
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flatItems = contentModel.treeData.flatMap { $0.flattened() }

        switch event.keyCode {
        case 53: // Escape
            hide()
            onCancel?()
            return true

        case 36: // Enter
            if let selected = contentModel.selection {
                let shouldSwitch = event.modifierFlags.contains(.control)
                hide()
                onParentSelected?(selected.id, selected.text, shouldSwitch)
                return true
            }

        case 126: // Up arrow
            if let current = contentModel.selection,
               let currentIndex = flatItems.firstIndex(of: current),
               currentIndex > 0 {
                contentModel.selection = flatItems[currentIndex - 1]
            } else if contentModel.selection == nil && !flatItems.isEmpty {
                contentModel.selection = flatItems.last
            }
            return true

        case 125: // Down arrow
            if let current = contentModel.selection,
               let currentIndex = flatItems.firstIndex(of: current),
               currentIndex < flatItems.count - 1 {
                contentModel.selection = flatItems[currentIndex + 1]
            } else if contentModel.selection == nil && !flatItems.isEmpty {
                contentModel.selection = flatItems.first
            }
            return true

        default:
            break
        }
        return false
    }

    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupHostingView() {
        let contentView = OutlineParentSelectorContentView(model: contentModel)
        hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        // Round corners
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 12
        self.contentView?.layer?.masksToBounds = true

        self.contentView?.addSubview(hostingView)

        // Setup callbacks
        contentModel.onParentSelected = { [weak self] id, text, shouldSwitch in
            self?.onParentSelected?(id, text, shouldSwitch)
        }
        contentModel.onCancel = { [weak self] in
            self?.onCancel?()
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        hide()
        onCancel?()
    }

    func show(treeTasks: [LocalTaskStore.TreeTask], currentTaskId: String, currentTaskName: String) {
        // Build tree data
        let treeData = ParentItem.buildTree(from: treeTasks, currentTaskId: currentTaskId)

        // Update model
        contentModel.currentTaskName = currentTaskName
        contentModel.treeData = treeData
        contentModel.selection = nil

        // Find and select current task
        if let currentItem = findItem(id: currentTaskId, in: treeData) {
            contentModel.selection = currentItem
        }

        // Calculate height based on flattened task count
        let flatCount = treeData.flatMap { $0.flattened() }.count
        let rowHeight: CGFloat = 32
        let headerHeight: CGFloat = 50
        let minHeight: CGFloat = 150
        let maxHeight: CGFloat = 500
        let calculatedHeight = CGFloat(flatCount) * rowHeight + headerHeight + 20
        let newHeight = min(max(calculatedHeight, minHeight), maxHeight)

        self.setFrame(NSRect(x: 0, y: 0, width: 550, height: newHeight), display: false)
        self.center()

        // Show panel
        NSApp.activate(ignoringOtherApps: true)
        self.orderFrontRegardless()
        self.makeKey()

        // Focus for keyboard events
        DispatchQueue.main.async { [weak self] in
            self?.makeFirstResponder(self?.hostingView)
        }
    }

    func hide() {
        self.orderOut(nil)
    }

    private func findItem(id: String, in items: [ParentItem]) -> ParentItem? {
        for item in items {
            if item.id == id { return item }
            if let children = item.children, let found = findItem(id: id, in: children) {
                return found
            }
        }
        return nil
    }

}

// MARK: - Observable Model

class OutlineParentSelectorModel: ObservableObject {
    @Published var treeData: [ParentItem] = []
    @Published var selection: ParentItem?
    @Published var currentTaskName: String = ""

    var onParentSelected: ((String, String, Bool) -> Void)?
    var onCancel: (() -> Void)?
}

// MARK: - Content View

struct OutlineParentSelectorContentView: View {
    @ObservedObject var model: OutlineParentSelectorModel

    var body: some View {
        OutlineParentSelectorView(
            selection: $model.selection,
            treeData: model.treeData,
            currentTaskName: model.currentTaskName
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Parent Selector") {
    OutlineParentSelectorContentView(model: {
        let model = OutlineParentSelectorModel()
        model.treeData = [
            ParentItem(
                id: "root",
                text: "Project Phoenix",
                depth: 0,
                isRoot: true,
                isCurrent: false,
                children: [
                    ParentItem(
                        id: "backend",
                        text: "Backend API",
                        depth: 1,
                        isRoot: false,
                        isCurrent: false,
                        children: [
                            ParentItem(id: "auth", text: "User Authentication", depth: 2, isRoot: false, isCurrent: false, children: nil),
                            ParentItem(
                                id: "stripe",
                                text: "Stripe Integration",
                                depth: 2,
                                isRoot: false,
                                isCurrent: true,
                                children: [
                                    ParentItem(id: "webhook", text: "Webhook Handler", depth: 3, isRoot: false, isCurrent: false, children: nil),
                                    ParentItem(id: "payment", text: "Payment Intent Logic", depth: 3, isRoot: false, isCurrent: false, children: nil)
                                ]
                            )
                        ]
                    ),
                    ParentItem(
                        id: "frontend",
                        text: "Frontend Interface",
                        depth: 1,
                        isRoot: false,
                        isCurrent: false,
                        children: [
                            ParentItem(id: "dashboard", text: "Dashboard Layout", depth: 2, isRoot: false, isCurrent: false, children: nil),
                            ParentItem(id: "settings", text: "Settings Page", depth: 2, isRoot: false, isCurrent: false, children: nil)
                        ]
                    ),
                    ParentItem(id: "docs", text: "Documentation", depth: 1, isRoot: false, isCurrent: false, children: nil)
                ]
            )
        ]
        model.currentTaskName = "Fix webhook timeout"
        return model
    }())
    .frame(width: 550, height: 400)
    .preferredColorScheme(.dark)
}
