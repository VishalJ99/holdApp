import AppKit

final class MenuBarManager {
    private var statusItem: NSStatusItem?

    func setupMenuBar(
        onShowSpotlight: @escaping () -> Void,
        onShowEditor: @escaping () -> Void,
        onShowSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Use SF Symbol for menu bar icon
            if let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Hold") {
                button.image = image
            } else {
                button.title = "H"
            }
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Show Spotlight", action: #selector(MenuBarTarget.showSpotlight), keyEquivalent: " "))
        menu.addItem(NSMenuItem(title: "Show Editor", action: #selector(MenuBarTarget.showEditor), keyEquivalent: "\\"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(MenuBarTarget.showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Hold", action: #selector(MenuBarTarget.quit), keyEquivalent: "q"))

        // Set up target for menu items
        let target = MenuBarTarget(
            onShowSpotlight: onShowSpotlight,
            onShowEditor: onShowEditor,
            onShowSettings: onShowSettings,
            onQuit: onQuit
        )

        for item in menu.items {
            item.target = target
        }

        statusItem?.menu = menu

        // Keep target alive
        self.target = target
    }

    private var target: MenuBarTarget?
}

// Helper class to handle menu actions
private class MenuBarTarget: NSObject {
    let onShowSpotlight: () -> Void
    let onShowEditor: () -> Void
    let onShowSettings: () -> Void
    let onQuit: () -> Void

    init(
        onShowSpotlight: @escaping () -> Void,
        onShowEditor: @escaping () -> Void,
        onShowSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onShowSpotlight = onShowSpotlight
        self.onShowEditor = onShowEditor
        self.onShowSettings = onShowSettings
        self.onQuit = onQuit
    }

    @objc func showSpotlight() {
        onShowSpotlight()
    }

    @objc func showEditor() {
        onShowEditor()
    }

    @objc func showSettings() {
        onShowSettings()
    }

    @objc func quit() {
        onQuit()
    }
}
