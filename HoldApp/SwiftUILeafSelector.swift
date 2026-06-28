//
//  SwiftUILeafSelector.swift
//  HoldApp
//
//  Leaf Selector using native SwiftUI List with flat list rendering
//  Uses stable dark floating-panel styling so text stays readable over light backgrounds.
//

import SwiftUI
import Cocoa

// MARK: - Leaf Selector Preferences

private enum LeafSelectorScopePreference {
    private static let userDefaultsKey = "com.holdapp.leafSelector.showsAllRoots"

    static var showsAllRoots: Bool {
        UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    static func setShowsAllRoots(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: userDefaultsKey)
    }
}

// MARK: - Leaf Item Model

struct LeafItem: Hashable, Identifiable {
    let id: String
    let text: String
    let rootText: String?
    let isCurrent: Bool
    let isCurrentRoot: Bool

    init(
        id: String,
        text: String,
        rootText: String? = nil,
        isCurrent: Bool,
        isCurrentRoot: Bool = true
    ) {
        self.id = id
        self.text = text
        self.rootText = rootText
        self.isCurrent = isCurrent
        self.isCurrentRoot = isCurrentRoot
    }
}

// MARK: - SwiftUI Leaf Selector View

struct LeafSelectorView: View {
    @Binding var selection: LeafItem?
    @Binding var showsAllRoots: Bool
    let leaves: [LeafItem]
    let onLeafActivated: (LeafItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(HoldFloatingPanelStyle.divider)

            // Flat list
            ScrollViewReader { proxy in
                List {
                    ForEach(leaves) { item in
                        LeafRowView(
                            item: item,
                            isSelected: selection?.id == item.id,
                            showsRootContext: showsAllRoots
                        )
                            .onTapGesture {
                                selection = item
                            }
                            .onTapGesture(count: 2) {
                                selection = item
                                onLeafActivated(item)
                            }
                            .tag(item)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
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
        .background(HoldFloatingPanelBackdrop())
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            Text("Select Leaf")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(HoldFloatingPanelStyle.secondaryText)

            Text("\(leaves.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(HoldFloatingPanelStyle.tertiaryText)

            Spacer()

            LeafScopeToggle(showsAllRoots: $showsAllRoots)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Scope Toggle

private struct LeafScopeToggle: View {
    @Binding var showsAllRoots: Bool

    var body: some View {
        HStack(spacing: 2) {
            scopeButton(title: "Current root", isSelected: !showsAllRoots) {
                showsAllRoots = false
            }

            scopeButton(title: "All roots", isSelected: showsAllRoots) {
                showsAllRoots = true
            }
        }
        .padding(2)
        .background(
            Capsule(style: .continuous)
                .fill(HoldFloatingPanelStyle.controlFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(HoldFloatingPanelStyle.border, lineWidth: 1)
        )
    }

    private func scopeButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? HoldFloatingPanelStyle.primaryText : HoldFloatingPanelStyle.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? HoldFloatingPanelStyle.selectedControlFill : Color.clear)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? HoldFloatingPanelStyle.selectedControlStroke : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }
}

// MARK: - Leaf Row View

struct LeafRowView: View {
    let item: LeafItem
    let isSelected: Bool
    let showsRootContext: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Bullet icon
            Text("●")
                .font(.system(size: 6))
                .foregroundColor(isSelected ? HoldFloatingPanelStyle.primaryText : HoldFloatingPanelStyle.tertiaryText)
                .frame(width: 14)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(.system(size: 14, weight: (item.isCurrent || isSelected) ? .semibold : .regular))
                    .foregroundColor((item.isCurrent || isSelected) ? HoldFloatingPanelStyle.primaryText : HoldFloatingPanelStyle.secondaryText)
                    .lineLimit(1)

                if showsRootContext, let rootText = item.rootText {
                    Text(item.isCurrentRoot ? "current root: \(rootText)" : "root: \(rootText)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(HoldFloatingPanelStyle.tertiaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Current indicator badge
            if item.isCurrent {
                Text("current")
                    .font(.system(size: 10))
                    .foregroundColor(HoldFloatingPanelStyle.tertiaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HoldFloatingPanelStyle.controlFill)
                    .cornerRadius(4)
            }
        }
        .frame(height: showsRootContext ? 42 : 32)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? HoldFloatingPanelStyle.rowHighlight : Color.clear)
        )
        .contentShape(Rectangle())
        .id(item.id)
    }
}

// MARK: - Observable Model

class LeafSelectorModel: ObservableObject {
    @Published private(set) var currentRootLeaves: [LeafItem] = []
    @Published private(set) var allRootLeaves: [LeafItem] = []
    @Published var selection: LeafItem?
    @Published private(set) var showsAllRoots: Bool = LeafSelectorScopePreference.showsAllRoots

    private var currentTaskId: String?

    var onLeafSelected: ((String, String) -> Void)?
    var onCancel: (() -> Void)?
    var onScopeChanged: (() -> Void)?

    var visibleLeaves: [LeafItem] {
        showsAllRoots ? allRootLeaves : currentRootLeaves
    }

    func configure(
        currentRootLeaves: [LeafItem],
        allRootLeaves: [LeafItem],
        currentTaskId: String
    ) {
        self.currentRootLeaves = currentRootLeaves
        self.allRootLeaves = allRootLeaves.isEmpty ? currentRootLeaves : allRootLeaves
        self.currentTaskId = currentTaskId
        self.showsAllRoots = LeafSelectorScopePreference.showsAllRoots
        selectCurrentOrFirst()
    }

    func setShowsAllRoots(_ showsAllRoots: Bool) {
        guard self.showsAllRoots != showsAllRoots else { return }

        let previousSelectionId = selection?.id
        self.showsAllRoots = showsAllRoots
        LeafSelectorScopePreference.setShowsAllRoots(showsAllRoots)
        selectCurrentOrFirst(preferredTaskId: previousSelectionId)
        onScopeChanged?()
    }

    func activateLeaf(_ leaf: LeafItem) {
        selection = leaf
        onLeafSelected?(leaf.id, leaf.text)
    }

    private func selectCurrentOrFirst(preferredTaskId: String? = nil) {
        let leaves = visibleLeaves

        if let preferredTaskId,
           let preferred = leaves.first(where: { $0.id == preferredTaskId }) {
            selection = preferred
        } else if let currentTaskId,
                  let current = leaves.first(where: { $0.id == currentTaskId }) {
            selection = current
        } else {
            selection = leaves.first
        }
    }
}

// MARK: - Content View

struct LeafSelectorContentView: View {
    @ObservedObject var model: LeafSelectorModel

    var body: some View {
        LeafSelectorView(
            selection: $model.selection,
            showsAllRoots: Binding(
                get: { model.showsAllRoots },
                set: { model.setShowsAllRoots($0) }
            ),
            leaves: model.visibleLeaves,
            onLeafActivated: { model.activateLeaf($0) }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(HoldFloatingPanelStyle.border, lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }
}

private final class DraggableLeafSelectorHostingView: NSHostingView<LeafSelectorContentView> {
    override var mouseDownCanMoveWindow: Bool { true }
}

// MARK: - NSPanel Wrapper

class SwiftUILeafSelectorPanel: NSPanel {
    private var hostingView: NSHostingView<LeafSelectorContentView>!
    private var contentModel = LeafSelectorModel()
    private var localEventMonitor: Any?

    var onLeafSelected: ((String, String) -> Void)?
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        HoldFloatingPanelStyle.configurePanel(self)

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
        switch event.keyCode {
        case 53: // Escape
            hide()
            onCancel?()
            return true

        case 36: // Enter
            if let selected = contentModel.selection {
                hide()
                onLeafSelected?(selected.id, selected.text)
                return true
            }

        case 126: // Up arrow
            let leaves = contentModel.visibleLeaves
            if let current = contentModel.selection,
               let currentIndex = leaves.firstIndex(of: current),
               currentIndex > 0 {
                contentModel.selection = leaves[currentIndex - 1]
            } else if contentModel.selection == nil && !leaves.isEmpty {
                contentModel.selection = leaves.last
            }
            return true

        case 125: // Down arrow
            let leaves = contentModel.visibleLeaves
            if let current = contentModel.selection,
               let currentIndex = leaves.firstIndex(of: current),
               currentIndex < leaves.count - 1 {
                contentModel.selection = leaves[currentIndex + 1]
            } else if contentModel.selection == nil && !leaves.isEmpty {
                contentModel.selection = leaves.first
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
        let contentView = LeafSelectorContentView(model: contentModel)
        hostingView = DraggableLeafSelectorHostingView(rootView: contentView)
        HoldFloatingPanelStyle.configureHostingView(hostingView)
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        HoldFloatingPanelStyle.configureRoundedContentView(self.contentView)

        self.contentView?.addSubview(hostingView)

        // Setup callbacks
        contentModel.onLeafSelected = { [weak self] id, text in
            self?.onLeafSelected?(id, text)
        }
        contentModel.onCancel = { [weak self] in
            self?.onCancel?()
        }
        contentModel.onScopeChanged = { [weak self] in
            self?.resizeForVisibleLeaves()
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        hide()
        onCancel?()
    }

    func show(
        currentRootLeaves: [LeafItem],
        allRootLeaves: [LeafItem],
        currentTaskId: String
    ) {
        contentModel.configure(
            currentRootLeaves: currentRootLeaves,
            allRootLeaves: allRootLeaves,
            currentTaskId: currentTaskId
        )
        resizeForVisibleLeaves(display: false, animate: false)

        // Show panel (matches SpotlightPanel pattern)
        self.center()
        self.orderFrontRegardless()
        self.makeKey()
    }

    private func resizeForVisibleLeaves(display: Bool = true, animate: Bool = true) {
        let rowHeight: CGFloat = contentModel.showsAllRoots ? 46 : 36
        let headerHeight: CGFloat = 52
        let minHeight: CGFloat = 150
        let maxHeight: CGFloat = 500
        let calculatedHeight = CGFloat(contentModel.visibleLeaves.count) * rowHeight + headerHeight + 20
        let newHeight = min(max(calculatedHeight, minHeight), maxHeight)

        var frame = self.frame
        let maxY = frame.maxY
        let midX = frame.midX
        frame.size = NSSize(width: 550, height: newHeight)
        frame.origin = NSPoint(x: midX - frame.width / 2, y: maxY - frame.height)

        self.setFrame(frame, display: display, animate: animate)
    }

    func hide() {
        self.orderOut(nil)
    }
}

// MARK: - Preview

#Preview("Leaf Selector") {
    LeafSelectorContentView(model: {
        let model = LeafSelectorModel()
        model.configure(
            currentRootLeaves: [
                LeafItem(id: "1", text: "Implement user authentication", rootText: "Product launch", isCurrent: false),
                LeafItem(id: "2", text: "Fix webhook timeout bug", rootText: "Product launch", isCurrent: true),
                LeafItem(id: "3", text: "Write unit tests for API", rootText: "Product launch", isCurrent: false)
            ],
            allRootLeaves: [
                LeafItem(id: "1", text: "Implement user authentication", rootText: "Product launch", isCurrent: false, isCurrentRoot: true),
                LeafItem(id: "2", text: "Fix webhook timeout bug", rootText: "Product launch", isCurrent: true, isCurrentRoot: true),
                LeafItem(id: "3", text: "Write unit tests for API", rootText: "Product launch", isCurrent: false, isCurrentRoot: true),
                LeafItem(id: "4", text: "Update documentation", rootText: "Release prep", isCurrent: false, isCurrentRoot: false),
                LeafItem(id: "5", text: "Review pull request #42", rootText: "Release prep", isCurrent: false, isCurrentRoot: false)
            ],
            currentTaskId: "2"
        )
        return model
    }())
    .frame(width: 550, height: 300)
    .preferredColorScheme(.dark)
}
