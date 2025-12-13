//
//  ParentSelectorMockups.swift
//  HoldApp
//
//  Design mockups for Parent Selector redesign
//  Open in Xcode and use Canvas (Cmd+Option+Enter) to preview
//

import SwiftUI

// MARK: - Mock Data

struct MockTask: Identifiable, Hashable {
    let id: String
    let text: String
    let depth: Int
    let isRoot: Bool
    var children: [MockTask]?

    static let sampleTree: [MockTask] = [
        MockTask(id: "1", text: "Build Hold App", depth: 0, isRoot: true, children: [
            MockTask(id: "2", text: "Design parent selector", depth: 1, isRoot: false, children: [
                MockTask(id: "3", text: "Create mockups", depth: 2, isRoot: false, children: nil),
                MockTask(id: "4", text: "Get feedback", depth: 2, isRoot: false, children: nil),
            ]),
            MockTask(id: "5", text: "Fix keyboard navigation", depth: 1, isRoot: false, children: nil),
            MockTask(id: "6", text: "Write documentation", depth: 1, isRoot: false, children: nil),
        ])
    ]

    func flattened() -> [MockTask] {
        var result = [self]
        if let children = children {
            for child in children {
                result.append(contentsOf: child.flattened())
            }
        }
        return result
    }
}

// MARK: - Option A: Blur Panel with Tree List
// Matches Spotlight's popover blur aesthetic with tree inside

struct MockupOptionA: View {
    @State private var selectedId: String? = "3"
    let tree = MockTask.sampleTree

    var flatTasks: [MockTask] {
        tree.flatMap { $0.flattened() }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Parent")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            // Tree
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(flatTasks) { task in
                        OptionARow(
                            task: task,
                            isSelected: selectedId == task.id
                        )
                        .onTapGesture { selectedId = task.id }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 500, height: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct OptionARow: View {
    let task: MockTask
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Indentation
            ForEach(0..<task.depth, id: \.self) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1)
                    .padding(.horizontal, 10)
            }

            // Icon
            Text(task.isRoot ? "▼" : "●")
                .font(.system(size: task.isRoot ? 10 : 6))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .frame(width: 20)

            // Text
            Text(task.text)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
                .padding(.horizontal, 8)
        )
    }
}

// MARK: - Option B: Pill-Style Compact
// More compact, pill-like rows

struct MockupOptionB: View {
    @State private var selectedId: String? = "3"
    let tree = MockTask.sampleTree

    var flatTasks: [MockTask] {
        tree.flatMap { $0.flattened() }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(flatTasks) { task in
                OptionBRow(
                    task: task,
                    isSelected: selectedId == task.id
                )
                .onTapGesture { selectedId = task.id }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .frame(width: 500)
    }
}

struct OptionBRow: View {
    let task: MockTask
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Depth indicator (subtle dots)
            if task.depth > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<task.depth, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(width: CGFloat(task.depth) * 8)
            }

            Text(task.text)
                .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.7))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
        )
    }
}

// MARK: - Option C: Breadcrumb + Selection
// Shows path at top, selection below

struct MockupOptionC: View {
    @State private var selectedId: String? = "3"
    let tree = MockTask.sampleTree

    var flatTasks: [MockTask] {
        tree.flatMap { $0.flattened() }
    }

    var selectedTask: MockTask? {
        flatTasks.first { $0.id == selectedId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Current selection (pill style like Spotlight)
            if let task = selectedTask {
                HStack {
                    Text("→")
                        .foregroundColor(.white.opacity(0.4))
                    Text(task.text)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.bottom, 12)
            }

            // Tree list
            VStack(alignment: .leading, spacing: 2) {
                ForEach(flatTasks) { task in
                    OptionCRow(
                        task: task,
                        isSelected: selectedId == task.id
                    )
                    .onTapGesture { selectedId = task.id }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .frame(width: 480)
    }
}

struct OptionCRow: View {
    let task: MockTask
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(String(repeating: "  ", count: task.depth))
                .font(.system(size: 14, design: .monospaced))

            Text(task.isRoot ? "◆" : "○")
                .font(.system(size: 8))
                .foregroundColor(isSelected ? .white : .white.opacity(0.4))

            Text(task.text)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
        )
    }
}

// MARK: - Option D: Minimal Tree Lines
// Clean tree with subtle connecting lines

struct MockupOptionD: View {
    @State private var selectedId: String? = "3"
    let tree = MockTask.sampleTree

    var flatTasks: [MockTask] {
        tree.flatMap { $0.flattened() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(flatTasks) { task in
                OptionDRow(
                    task: task,
                    isSelected: selectedId == task.id
                )
                .onTapGesture { selectedId = task.id }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .frame(width: 450)
    }
}

struct OptionDRow: View {
    let task: MockTask
    let isSelected: Bool

    private let indentWidth: CGFloat = 24

    var body: some View {
        HStack(spacing: 0) {
            // Tree structure
            HStack(spacing: 0) {
                ForEach(0..<task.depth, id: \.self) { i in
                    if i == task.depth - 1 {
                        // Connector
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 1, height: 16)
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 8, height: 1)
                        }
                        .frame(width: indentWidth, height: 32)
                    } else {
                        // Vertical line
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 1)
                            .frame(width: indentWidth, height: 32)
                    }
                }
            }

            // Content
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 6, height: 6)

                Text(task.text)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
            )
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Previews

#Preview("Option A: Blur Panel") {
    ZStack {
        Color.black.opacity(0.8)
        MockupOptionA()
    }
    .preferredColorScheme(.dark)
}

#Preview("Option B: Pill Rows") {
    ZStack {
        Color.black.opacity(0.8)
        MockupOptionB()
    }
    .preferredColorScheme(.dark)
}

#Preview("Option C: Breadcrumb + List") {
    ZStack {
        Color.black.opacity(0.8)
        MockupOptionC()
    }
    .preferredColorScheme(.dark)
}

#Preview("Option D: Tree Lines") {
    ZStack {
        Color.black.opacity(0.8)
        MockupOptionD()
    }
    .preferredColorScheme(.dark)
}

// All options side by side
#Preview("All Options") {
    ScrollView(.horizontal) {
        HStack(spacing: 40) {
            VStack {
                Text("A: Blur Panel").foregroundColor(.white.opacity(0.5))
                MockupOptionA()
            }
            VStack {
                Text("B: Pill Rows").foregroundColor(.white.opacity(0.5))
                MockupOptionB()
            }
            VStack {
                Text("C: Breadcrumb").foregroundColor(.white.opacity(0.5))
                MockupOptionC()
            }
            VStack {
                Text("D: Tree Lines").foregroundColor(.white.opacity(0.5))
                MockupOptionD()
            }
        }
        .padding(40)
    }
    .background(Color.black.opacity(0.9))
    .preferredColorScheme(.dark)
}
