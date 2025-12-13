//
//  TreePreview.swift
//  HoldApp
//
//  SwiftUI Preview for iterating on Parent Selector tree UI
//  Use Xcode's Canvas (Editor > Canvas) to see live preview
//

import SwiftUI

// MARK: - Mock Data (Prefixed to avoid conflicts)

struct PreviewTreeNode: Identifiable {
    let id = UUID()
    let text: String
    let depth: Int
    let isLast: Bool
    let hasChildren: Bool
    let ancestorContinuations: [Bool]
}

// MARK: - Mock Data Builder

struct MockTreeData {
    // Build mock tree matching the target design:
    // ▼ Project Phoenix (Root)
    //  ├── Backend API
    //  │    ├── User Authentication
    //  │    └── Stripe Integration      ← selected
    //  └── Frontend Interface
    //       ├── Dashboard layout
    //       └── Landing Page

    static let nodes: [PreviewTreeNode] = [
        PreviewTreeNode(
            text: "Project Phoenix",
            depth: 0,
            isLast: true,
            hasChildren: true,
            ancestorContinuations: []
        ),
        PreviewTreeNode(
            text: "Backend API",
            depth: 1,
            isLast: false,
            hasChildren: true,
            ancestorContinuations: [true]
        ),
        PreviewTreeNode(
            text: "User Authentication",
            depth: 2,
            isLast: false,
            hasChildren: false,
            ancestorContinuations: [true, true]
        ),
        PreviewTreeNode(
            text: "Stripe Integration",
            depth: 2,
            isLast: true,
            hasChildren: false,
            ancestorContinuations: [true, false]
        ),
        PreviewTreeNode(
            text: "Frontend Interface",
            depth: 1,
            isLast: true,
            hasChildren: true,
            ancestorContinuations: [false]
        ),
        PreviewTreeNode(
            text: "Dashboard layout",
            depth: 2,
            isLast: false,
            hasChildren: false,
            ancestorContinuations: [false, true]
        ),
        PreviewTreeNode(
            text: "Landing Page",
            depth: 2,
            isLast: true,
            hasChildren: false,
            ancestorContinuations: [false, false]
        ),
    ]
}

// MARK: - Tree Lines Drawing View

struct PreviewTreeLines: View {
    let node: PreviewTreeNode
    let indent: CGFloat
    let lineColor: Color
    let lineWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            drawLines(context: context, size: size)
        }
    }

    private func drawLines(context: GraphicsContext, size: CGSize) {
        let halfIndent = indent / 2
        let centerY = size.height / 2

        // 1. Draw ancestor continuation lines
        for depthIndex in 0..<node.ancestorContinuations.count {
            let shouldContinue = node.ancestorContinuations[depthIndex]
            if shouldContinue {
                let x = CGFloat(depthIndex) * indent + halfIndent
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
            }
        }

        // 2. Draw current node connector (├── or └──)
        if node.depth > 0 {
            let connectorColumn = node.depth - 1
            let x = CGFloat(connectorColumn) * indent + halfIndent
            let endX = CGFloat(node.depth) * indent + halfIndent - 4

            var path = Path()

            // Vertical part
            path.move(to: CGPoint(x: x, y: 0))
            let verticalEndY = node.isLast ? centerY : size.height
            path.addLine(to: CGPoint(x: x, y: verticalEndY))

            // Horizontal part
            path.move(to: CGPoint(x: x, y: centerY))
            path.addLine(to: CGPoint(x: endX, y: centerY))

            context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
        }

        // 3. Draw descender line (if has children)
        if node.hasChildren {
            let x = CGFloat(node.depth) * indent + halfIndent
            var path = Path()
            path.move(to: CGPoint(x: x, y: centerY))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
        }
    }
}

// MARK: - Single Row View

struct PreviewTreeRow: View {
    let node: PreviewTreeNode
    let isSelected: Bool

    private let rowHeight: CGFloat = 36
    private let indent: CGFloat = 24
    private let lineColor = Color.white.opacity(0.25)
    private let lineWidth: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .leading) {
            selectionBackground
            rowContent
        }
        .frame(height: rowHeight)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.yellow.opacity(0.7), lineWidth: 1.5)
                )
        }
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            treeLinesArea
            iconView
            textView
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private var treeLinesArea: some View {
        let width = CGFloat(node.depth + 1) * indent
        return PreviewTreeLines(
            node: node,
            indent: indent,
            lineColor: lineColor,
            lineWidth: lineWidth
        )
        .frame(width: width)
    }

    private var iconView: some View {
        let iconText = node.depth == 0 ? "▼" : "●"
        let iconSize: CGFloat = node.depth == 0 ? 10 : 8
        let iconOpacity: Double = node.depth == 0 ? 1.0 : 0.6

        return Text(iconText)
            .font(.system(size: iconSize))
            .foregroundColor(.white.opacity(iconOpacity))
            .frame(width: 16)
    }

    private var textView: some View {
        let weight: Font.Weight = isSelected ? .semibold : .regular
        let opacity: Double = isSelected ? 1.0 : 0.8

        return Text(node.text)
            .font(.system(size: 14, weight: weight))
            .foregroundColor(.white.opacity(opacity))
    }
}

// MARK: - Full Tree Preview

struct PreviewParentSelector: View {
    @State private var selectedIndex = 3

    var body: some View {
        VStack(spacing: 0) {
            headerView
            dividerView
            treeListView
        }
        .frame(width: 400, height: 320)
        .background(Color.black.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var headerView: some View {
        Text("Select Parent Task")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    private var dividerView: some View {
        Divider()
            .background(Color.white.opacity(0.1))
    }

    private var treeListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<MockTreeData.nodes.count, id: \.self) { index in
                    let node = MockTreeData.nodes[index]
                    PreviewTreeRow(node: node, isSelected: index == selectedIndex)
                        .onTapGesture {
                            selectedIndex = index
                        }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Debug View

struct PreviewDebugRows: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<MockTreeData.nodes.count, id: \.self) { index in
                let node = MockTreeData.nodes[index]
                VStack(spacing: 0) {
                    PreviewTreeRow(node: node, isSelected: index == 3)
                    debugLabel(for: node)
                }
            }
        }
        .frame(width: 500)
        .background(Color.black.opacity(0.95))
    }

    private func debugLabel(for node: PreviewTreeNode) -> some View {
        let contStr = node.ancestorContinuations.map { $0 ? "1" : "0" }.joined()
        let lastStr = node.isLast ? "Y" : "N"
        let text = "d:\(node.depth) last:\(lastStr) cont:\(contStr)"

        return Text(text)
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.gray)
    }
}

// MARK: - Xcode Previews

#Preview("Parent Selector") {
    PreviewParentSelector()
        .preferredColorScheme(.dark)
}

#Preview("Debug Rows") {
    PreviewDebugRows()
        .preferredColorScheme(.dark)
}

#Preview("Single Row - Root") {
    PreviewTreeRow(node: MockTreeData.nodes[0], isSelected: false)
        .frame(width: 400)
        .background(Color.black.opacity(0.95))
        .preferredColorScheme(.dark)
}

#Preview("Single Row - Selected") {
    PreviewTreeRow(node: MockTreeData.nodes[3], isSelected: true)
        .frame(width: 400)
        .background(Color.black.opacity(0.95))
        .preferredColorScheme(.dark)
}
