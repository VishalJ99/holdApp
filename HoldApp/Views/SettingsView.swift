import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            KeyboardShortcutsSettings()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            AboutSettings()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 600, height: 500)
    }
}

struct GeneralSettings: View {
    var body: some View {
        Form {
            Section("Appearance") {
                Text("General settings coming in Phase 10")
                    .foregroundColor(.gray)
            }
        }
        .padding(20)
    }
}

struct KeyboardShortcutsSettings: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Keyboard Shortcuts")
                    .font(.headline)

                GroupBox("Global") {
                    ShortcutRow(name: "Show Spotlight", shortcut: "⌘⇧Space")
                    ShortcutRow(name: "Show Editor", shortcut: "⌘⇧\\")
                    ShortcutRow(name: "Complete Current Task", shortcut: "⌘⇧Return")
                    ShortcutRow(name: "Dismiss Current Task", shortcut: "⌘⇧Delete")
                    ShortcutRow(name: "Show Cheat Sheet", shortcut: "⌘?")
                }

                GroupBox("Spotlight") {
                    ShortcutRow(name: "Create top-level task", shortcut: "Return")
                    ShortcutRow(name: "Create + set current", shortcut: "⌥Return")
                    ShortcutRow(name: "Create child of current", shortcut: "⇧Return")
                    ShortcutRow(name: "Create sibling", shortcut: "⌘Return")
                    ShortcutRow(name: "Create sibling + set current", shortcut: "⌘⌥Return")
                    ShortcutRow(name: "Select parent", shortcut: "⌘P")
                    ShortcutRow(name: "Load current task", shortcut: "↑")
                    ShortcutRow(name: "Clear text", shortcut: "↓")
                }

                GroupBox("Editor") {
                    ShortcutRow(name: "Set task as current", shortcut: "Space")
                    ShortcutRow(name: "Dismiss task", shortcut: "Backspace")
                    ShortcutRow(name: "Change parent", shortcut: "⌘P")
                    ShortcutRow(name: "Clear filter", shortcut: "Esc")
                }

                Text("Note: Keyboard shortcut customization coming in Phase 8")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top)
            }
            .padding(20)
        }
    }
}

struct ShortcutRow: View {
    let name: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
        }
    }
}

struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Hold")
                .font(.largeTitle)
                .bold()

            Text("Version 1.0")
                .foregroundColor(.gray)

            Text("Focus on one task at a time")
                .font(.headline)

            Spacer()

            Text("© 2025 Vishal Jain")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(40)
    }
}
