import Cocoa

class SpotlightPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 60),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel for Spotlight-like behavior
        self.level = .floating
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        self.hasShadow = true
        self.isOpaque = false

        // Round corners
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 12
        self.contentView?.layer?.masksToBounds = true

        // Center on screen
        self.center()
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return false
    }

    func show() {
        self.center()
        self.orderFrontRegardless()
        self.makeKey()

        // Focus the text field if there is one
        if let viewController = self.contentViewController as? SpotlightViewController {
            viewController.focusTextField()
        }
    }

    func hide() {
        self.orderOut(nil)
    }
}
