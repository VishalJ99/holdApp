import SwiftUI

struct CheatSheetView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            // Cheat sheet content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Keyboard Shortcuts")
                        .font(.title)
                        .bold()

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Shortcuts content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ShortcutSection(title: "Global Shortcuts", shortcuts: [
                            ("Show Spotlight", "⌘⇧Space"),
                            ("Show Editor", "⌘⇧\\"),
                            ("Complete Current Task", "⌘⇧Return"),
                            ("Dismiss Current Task", "⌘⇧Delete"),
                            ("Show this Cheat Sheet", "⌘?")
                        ])

                        Divider()

                        ShortcutSection(title: "Spotlight (Entry Bar)", shortcuts: [
                            ("Create top-level task", "Return"),
                            ("Create top-level + set as current", "⌥Return"),
                            ("Create child of current", "⇧Return"),
                            ("Create sibling of current", "⌘Return"),
                            ("Create sibling + set as current", "⌘⌥Return"),
                            ("Select parent task", "⌘P"),
                            ("Load current task for editing", "↑"),
                            ("Clear text", "↓"),
                            ("Close without creating", "Esc")
                        ])

                        Divider()

                        ShortcutSection(title: "Editor", shortcuts: [
                            ("Type to filter tasks", "Any text"),
                            ("Navigate filtered results", "Tab / Arrows"),
                            ("Set task as current", "Space"),
                            ("Dismiss task", "Backspace"),
                            ("Change parent", "⌘P"),
                            ("Clear filter / return to tree", "Esc")
                        ])

                        Divider()

                        ShortcutSection(title: "Parent Selector", shortcuts: [
                            ("Navigate tasks", "↑↓ / Tab"),
                            ("Filter tasks", "Type text"),
                            ("Select parent", "Return / Click"),
                            ("Cancel", "Esc")
                        ])
                    }
                    .padding(24)
                }

                Divider()

                // Footer buttons
                HStack {
                    Button("Customize Shortcuts...") {
                        // Open Settings window
                        onClose()
                    }

                    Spacer()

                    Button("Close") {
                        onClose()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(width: 700, height: 600)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 20)
        }
    }
}

struct ShortcutSection: View {
    let title: String
    let shortcuts: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(shortcuts, id: \.0) { shortcut in
                    HStack {
                        Text(shortcut.0)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(shortcut.1)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
}
