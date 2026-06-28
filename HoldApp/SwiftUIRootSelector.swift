//
//  SwiftUIRootSelector.swift
//  HoldApp
//
//  Root Selector using native SwiftUI List with flat list rendering
//  Uses stable dark floating-panel styling so text stays readable over light backgrounds.
//

import SwiftUI
import Cocoa

// MARK: - Root Item Model

struct RootItem: Hashable, Identifiable {
    let id: String
    let text: String
    let isCurrent: Bool
}

// MARK: - SwiftUI Root Selector View

struct RootSelectorView: View {
    @Binding var selection: RootItem?
    let roots: [RootItem]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(HoldFloatingPanelStyle.divider)

            // Flat list
            ScrollViewReader { proxy in
                List {
                    ForEach(roots) { item in
                        RootRowView(item: item, isSelected: selection?.id == item.id)
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
        HStack(spacing: 8) {
            Text("Select Root")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(HoldFloatingPanelStyle.secondaryText)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Root Row View

struct RootRowView: View {
    let item: RootItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Bullet icon
            Text("●")
                .font(.system(size: 6))
                .foregroundColor(isSelected ? HoldFloatingPanelStyle.primaryText : HoldFloatingPanelStyle.tertiaryText)
                .frame(width: 14)

            // Text
            Text(item.text)
                .font(.system(size: 14, weight: (item.isCurrent || isSelected) ? .semibold : .regular))
                .foregroundColor((item.isCurrent || isSelected) ? HoldFloatingPanelStyle.primaryText : HoldFloatingPanelStyle.secondaryText)
                .lineLimit(1)

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
        .frame(height: 32)
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

class RootSelectorModel: ObservableObject {
    @Published var roots: [RootItem] = []
    @Published var selection: RootItem?

    var onRootSelected: ((String, String) -> Void)?
    var onCancel: (() -> Void)?
}

// MARK: - Content View

struct RootSelectorContentView: View {
    @ObservedObject var model: RootSelectorModel

    var body: some View {
        RootSelectorView(
            selection: $model.selection,
            roots: model.roots
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(HoldFloatingPanelStyle.border, lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - NSPanel Wrapper

class SwiftUIRootSelectorPanel: NSPanel {
    private var hostingView: NSHostingView<RootSelectorContentView>!
    private var contentModel = RootSelectorModel()
    private var localEventMonitor: Any?

    var onRootSelected: ((String, String) -> Void)?
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
                onRootSelected?(selected.id, selected.text)
                return true
            }

        case 126: // Up arrow
            if let current = contentModel.selection,
               let currentIndex = contentModel.roots.firstIndex(of: current),
               currentIndex > 0 {
                contentModel.selection = contentModel.roots[currentIndex - 1]
            } else if contentModel.selection == nil && !contentModel.roots.isEmpty {
                contentModel.selection = contentModel.roots.last
            }
            return true

        case 125: // Down arrow
            if let current = contentModel.selection,
               let currentIndex = contentModel.roots.firstIndex(of: current),
               currentIndex < contentModel.roots.count - 1 {
                contentModel.selection = contentModel.roots[currentIndex + 1]
            } else if contentModel.selection == nil && !contentModel.roots.isEmpty {
                contentModel.selection = contentModel.roots.first
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
        let contentView = RootSelectorContentView(model: contentModel)
        hostingView = NSHostingView(rootView: contentView)
        HoldFloatingPanelStyle.configureHostingView(hostingView)
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        HoldFloatingPanelStyle.configureRoundedContentView(self.contentView)

        self.contentView?.addSubview(hostingView)

        // Setup callbacks
        contentModel.onRootSelected = { [weak self] id, text in
            self?.onRootSelected?(id, text)
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

    func show(roots: [(id: String, text: String)], currentRootId: String?) {
        // Build root items
        let rootItems = roots.map { root in
            RootItem(
                id: root.id,
                text: root.text,
                isCurrent: root.id == currentRootId
            )
        }

        // Update model
        contentModel.roots = rootItems
        contentModel.selection = nil

        // Find and select current root
        if let currentRootId = currentRootId,
           let currentItem = rootItems.first(where: { $0.id == currentRootId }) {
            contentModel.selection = currentItem
        } else if let first = rootItems.first {
            contentModel.selection = first
        }

        // Calculate height based on root count
        let rowHeight: CGFloat = 36
        let headerHeight: CGFloat = 50
        let minHeight: CGFloat = 150
        let maxHeight: CGFloat = 500
        let calculatedHeight = CGFloat(roots.count) * rowHeight + headerHeight + 20
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

#Preview("Root Selector") {
    RootSelectorContentView(model: {
        let model = RootSelectorModel()
        model.roots = [
            RootItem(id: "1", text: "Project Phoenix", isCurrent: true),
            RootItem(id: "2", text: "Work Tasks", isCurrent: false),
            RootItem(id: "3", text: "Personal Goals", isCurrent: false),
            RootItem(id: "4", text: "Learning & Development", isCurrent: false),
            RootItem(id: "5", text: "Health & Fitness", isCurrent: false)
        ]
        model.selection = model.roots.first
        return model
    }())
    .frame(width: 550, height: 300)
    .preferredColorScheme(.dark)
}
