import Cocoa

/// Window controller for the preferences window
class PreferencesWindowController: NSWindowController {

    private var hotkeyViewController: HotkeyRecorderViewController!

    init() {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
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

        // Create and set the content view controller
        hotkeyViewController = HotkeyRecorderViewController()
        window.contentViewController = hotkeyViewController
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
