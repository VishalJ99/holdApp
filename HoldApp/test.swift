//
//  test.swift
//  HoldApp
//
//  Created by Vishal Jain on 28/11/2025.
//

import SwiftUI

// MARK: - 1. Data Model
struct TaskItem: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var children: [TaskItem]?
}

// A flattened representation of the tree for easy rendering
struct DisplayRow: Identifiable, Equatable {
    let id: UUID
    let title: String
    let depth: Int
    let isLastChild: Bool
    let parentPath: [Bool] // true = parent has more siblings (draw vertical line), false = parent is last (draw blank)
}

// MARK: - 2. Mock Data
class TaskStore: ObservableObject {
    @Published var flatTasks: [DisplayRow] = []
    
    init() {
        let hierarchy = [
            TaskItem(title: "Project Phoenix (Root)", children: [
                TaskItem(title: "Backend API", children: [
                    TaskItem(title: "User Authentication", children: nil),
                    TaskItem(title: "Stripe Integration", children: [
                        TaskItem(title: "Webhook Handler", children: nil),
                        TaskItem(title: "Payment Intent Logic", children: nil)
                    ])
                ]),
                TaskItem(title: "Frontend Interface", children: [
                    TaskItem(title: "Dashboard Layout", children: nil),
                    TaskItem(title: "Settings Page", children: nil)
                ]),
                TaskItem(title: "Documentation", children: nil)
            ])
        ]
        
        self.flatTasks = flatten(nodes: hierarchy)
    }
    
    // Recursive function to flatten the tree for the UI
    private func flatten(nodes: [TaskItem], depth: Int = 0, parentPath: [Bool] = []) -> [DisplayRow] {
        var result: [DisplayRow] = []
        
        for (index, node) in nodes.enumerated() {
            let isLast = index == nodes.count - 1
            
            // Add current node
            result.append(DisplayRow(
                id: node.id,
                title: node.title,
                depth: depth,
                isLastChild: isLast,
                parentPath: parentPath
            ))
            
            // Add children if they exist
            if let children = node.children {
                let newPath = parentPath + [!isLast]
                result.append(contentsOf: flatten(nodes: children, depth: depth + 1, parentPath: newPath))
            }
        }
        return result
    }
}

// MARK: - 3. Design Constants (The "Hold" Vibe)
struct Theme {
    static let background = Color.black.opacity(0.8)
    static let surface = Color(white: 0.15)
    static let accent = Color(red: 1.0, green: 0.8, blue: 0.4) // The Amber/Gold
    static let textMain = Color.white.opacity(0.9)
    static let textDim = Color.white.opacity(0.4)
    static let line = Color.white.opacity(0.15)
    static let cornerRadius: CGFloat = 12
}

// MARK: - 4. The Main View
struct ParentSelectorView: View {
    @StateObject var store = TaskStore()
    @State private var selectedIndex: Int = 0
    
    // Simulating the task being edited
    let currentTaskName = "Fix webhook timeout"
    
    var body: some View {
        ZStack {
            // Background blur
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                
                // --- Header / Search Bar ---
                HStack(spacing: 12) {
                    Image(systemName: "arrow.turn.right.up") // Icon indicating reparenting
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.accent)
                    
                    Text("Select Parent for ")
                        .foregroundColor(Theme.textDim)
                    + Text("\"\(currentTaskName)\"")
                        .foregroundColor(Theme.textMain)
                    + Text("...")
                        .foregroundColor(Theme.textDim)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.2))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Theme.line),
                    alignment: .bottom
                )
                
                // --- The Tree List ---
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(store.flatTasks.enumerated()), id: \.element.id) { index, row in
                                TreeRowView(row: row, isSelected: index == selectedIndex)
                                    .id(index)
                                    .onTapGesture {
                                        selectedIndex = index
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 400) // Constrain height like a dropdown
                    // Keyboard Navigation Logic
                    .background(KeyHandler(selectedIndex: $selectedIndex, maxIndex: store.flatTasks.count - 1))
                    .onChange(of: selectedIndex) { newIndex in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 600)
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
    }
}

// MARK: - 5. Row Component (The "Clean Lines" Logic)
struct TreeRowView: View {
    let row: DisplayRow
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            
            // 1. Draw Indentation and Vertical Lines
            HStack(spacing: 0) {
                // Draw ancestor lines
                ForEach(0..<row.depth, id: \.self) { i in
                    if i < row.parentPath.count && row.parentPath[i] {
                        // Draw vertical line passing through
                        Rectangle()
                            .fill(Theme.line)
                            .frame(width: 1)
                            .padding(.horizontal, 12)
                    } else {
                        // Empty space
                        Spacer().frame(width: 25)
                    }
                }
            }
            
            // 2. Draw Connector (The L or T shape)
            if row.depth > 0 {
                ConnectorShape(isLast: row.isLastChild)
                    .stroke(Theme.line, lineWidth: 1)
                    .frame(width: 12, height: 24) // Height must match row height
                    .padding(.trailing, 8)
                    .offset(x: 4) // Nudge to align with ancestor lines
            } else {
                Spacer().frame(width: 16)
            }
            
            // 3. Task Content
            HStack(spacing: 8) {
                // Icon (No folders, just subtle dots/circles)
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundColor(isSelected ? Theme.accent : Theme.textDim)
                    .opacity(row.depth == 0 ? 0 : 1) // Hide dot for root if preferred, or keep it
                
                Text(row.title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? Theme.textMain : Theme.textDim)
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .frame(height: 32)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.line.opacity(isSelected ? 1 : 0)) // Highlight bg
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.accent.opacity(0.5), lineWidth: isSelected ? 1 : 0) // Glow border
                )
                .padding(.horizontal, 8)
        )
    }
}

// MARK: - 6. Custom Shapes for Tree Lines
struct ConnectorShape: Shape {
    let isLast: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Start top middle
        path.move(to: CGPoint(x: 0, y: 0))
        // Go down to middle vertical center
        path.addLine(to: CGPoint(x: 0, y: rect.midY))
        // Go right to end
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        
        // If not last, line continues down
        if !isLast {
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        }
        
        return path
    }
}

// MARK: - 7. Helpers (Blur & Key Handling)

// Keyboard Event Handler (Invisible View)
struct KeyHandler: NSViewRepresentable {
    @Binding var selectedIndex: Int
    let maxIndex: Int
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onUp = {
            if selectedIndex > 0 { selectedIndex -= 1 }
        }
        view.onDown = {
            if selectedIndex < maxIndex { selectedIndex += 1 }
        }
        view.onEnter = {
            print("Selected Index: \(selectedIndex)")
            // Action triggers here
        }
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class KeyView: NSView {
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onEnter: (() -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 126: onUp?() // Up Arrow
            case 125: onDown?() // Down Arrow
            case 36: onEnter?() // Enter
            default: super.keyDown(with: event)
            }
        }
    }
}

// Visual Effect View for Blur
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Preview
struct ParentSelector_Previews: PreviewProvider {
    static var previews: some View {
        ParentSelectorView()
            .padding(50)
            .background(Color.black) // Context background
    }
}
