import Cocoa
import SwiftUI

class SettingsWindow: NSWindow {
    private var hostingView: NSHostingView<SettingsView>?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Hold Settings"
        self.isReleasedWhenClosed = false

        let settingsView = SettingsView()
        hostingView = NSHostingView(rootView: settingsView)
        self.contentView = hostingView

        self.center()
    }
}
