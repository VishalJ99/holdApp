//
//  SwiftUILeafSelector.swift
//  HoldApp
//
//  Leaf Selector using native SwiftUI List with flat list rendering
//  Matches the Spotlight design system (ultraThinMaterial, rounded corners)
//

import SwiftUI
import Cocoa

// MARK: - Leaf Item Model

struct LeafItem: Hashable, Identifiable {
    let id: String
    let text: String
    let isCurrent: Bool
}

// MARK: - SwiftUI Leaf Selector View

struct LeafSelectorView: View {
    @Binding var selection: LeafItem?
    let leaves: [LeafItem]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Color.white.opacity(0.1))

            // Flat list
            ScrollViewReader { proxy in
                List {
                    ForEach(leaves) { item in
                        LeafRowView(item: item, isSelected: selection?.id == item.id)
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
        .background(.ultraThinMaterial)
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Text("Select Leaf")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Leaf Row View

struct LeafRowView: View {
    let item: LeafItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Bullet icon
            Text("●")
                .font(.system(size: 6))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .frame(width: 14)

            // Text
            Text(item.text)
                .font(.system(size: 14, weight: (item.isCurrent || isSelected) ? .semibold : .regular))
                .foregroundColor((item.isCurrent || isSelected) ? .white : .white.opacity(0.7))
                .lineLimit(1)

            Spacer()

            // Current indicator badge
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
        .frame(height: 32)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .id(item.id)
    }
}

// MARK: - Observable Model

class LeafSelectorModel: ObservableObject {
    @Published var leaves: [LeafItem] = []
    @Published var selection: LeafItem?

    var onLeafSelected: ((String, String) -> Void)?
    var onCancel: (() -> Void)?
}

// MARK: - Content View

struct LeafSelectorContentView: View {
    @ObservedObject var model: LeafSelectorModel

    var body: some View {
        LeafSelectorView(
            selection: $model.selection,
            leaves: model.leaves
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
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
            if let current = contentModel.selection,
               let currentIndex = contentModel.leaves.firstIndex(of: current),
               currentIndex > 0 {
                contentModel.selection = contentModel.leaves[currentIndex - 1]
            } else if contentModel.selection == nil && !contentModel.leaves.isEmpty {
                contentModel.selection = contentModel.leaves.last
            }
            return true

        case 125: // Down arrow
            if let current = contentModel.selection,
               let currentIndex = contentModel.leaves.firstIndex(of: current),
               currentIndex < contentModel.leaves.count - 1 {
                contentModel.selection = contentModel.leaves[currentIndex + 1]
            } else if contentModel.selection == nil && !contentModel.leaves.isEmpty {
                contentModel.selection = contentModel.leaves.first
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
        hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        // Round corners
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 16
        self.contentView?.layer?.masksToBounds = true

        self.contentView?.addSubview(hostingView)

        // Setup callbacks
        contentModel.onLeafSelected = { [weak self] id, text in
            self?.onLeafSelected?(id, text)
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

    func show(leaves: [(id: String, text: String)], currentIndex: Int) {
        // Build leaf items
        let leafItems = leaves.enumerated().map { index, leaf in
            LeafItem(
                id: leaf.id,
                text: leaf.text,
                isCurrent: index == currentIndex
            )
        }

        // Update model
        contentModel.leaves = leafItems
        contentModel.selection = nil

        // Find and select current leaf
        if currentIndex >= 0 && currentIndex < leafItems.count {
            contentModel.selection = leafItems[currentIndex]
        } else if let first = leafItems.first {
            contentModel.selection = first
        }

        // Calculate height based on leaf count
        let rowHeight: CGFloat = 36
        let headerHeight: CGFloat = 50
        let minHeight: CGFloat = 150
        let maxHeight: CGFloat = 500
        let calculatedHeight = CGFloat(leaves.count) * rowHeight + headerHeight + 20
        let newHeight = min(max(calculatedHeight, minHeight), maxHeight)

        self.setFrame(NSRect(x: 0, y: 0, width: 550, height: newHeight), display: false)

        // Show panel (matches SpotlightPanel pattern)
        self.center()
        self.orderFrontRegardless()
        self.makeKey()
    }

    func hide() {
        self.orderOut(nil)
    }
}

// MARK: - Preview

#Preview("Leaf Selector") {
    LeafSelectorContentView(model: {
        let model = LeafSelectorModel()
        model.leaves = [
            LeafItem(id: "1", text: "Implement user authentication", isCurrent: false),
            LeafItem(id: "2", text: "Fix webhook timeout bug", isCurrent: true),
            LeafItem(id: "3", text: "Write unit tests for API", isCurrent: false),
            LeafItem(id: "4", text: "Update documentation", isCurrent: false),
            LeafItem(id: "5", text: "Review pull request #42", isCurrent: false)
        ]
        model.selection = model.leaves[1]
        return model
    }())
    .frame(width: 550, height: 300)
    .preferredColorScheme(.dark)
}
