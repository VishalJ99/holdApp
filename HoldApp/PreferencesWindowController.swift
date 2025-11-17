import Cocoa

/// Window controller for the preferences window with tabbed interface
class PreferencesWindowController: NSWindowController {

    private var tabViewController: NSTabViewController!
    private var hotkeyViewController: HotkeyRecorderViewController!
    private var entryModifierViewController: EntryModifierViewController!

    init() {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Preferences"
        window.center()

        // Set window appearance
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false

        // Initialize with the window
        super.init(window: window)

        // Create tab view controller
        tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar

        // Create hotkey preferences tab
        hotkeyViewController = HotkeyRecorderViewController()
        let hotkeyTabItem = NSTabViewItem(viewController: hotkeyViewController)
        hotkeyTabItem.label = "Global Hotkeys"
        hotkeyTabItem.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Global Hotkeys")
        tabViewController.addTabViewItem(hotkeyTabItem)

        // Create entry modifier preferences tab
        entryModifierViewController = EntryModifierViewController()
        let modifierTabItem = NSTabViewItem(viewController: entryModifierViewController)
        modifierTabItem.label = "Entry Modifiers"
        modifierTabItem.image = NSImage(systemSymbolName: "return", accessibilityDescription: "Entry Modifiers")
        tabViewController.addTabViewItem(modifierTabItem)

        // Set tab view controller as content
        window.contentViewController = tabViewController
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)

        // Bring window to front
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
