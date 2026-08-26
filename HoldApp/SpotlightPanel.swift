import Cocoa

class SpotlightPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 90),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel for Spotlight-like behavior
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Ensure window itself is transparent so the view's shape is visible
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.hasShadow = true
        
        // Center on screen
        self.center()
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return false
    }

    override func sendEvent(_ event: NSEvent) {
        if let viewController = contentViewController as? SpotlightViewController,
           viewController.handleEntryChordEvent(event) {
            return
        }
        super.sendEvent(event)
    }

    override func resignKey() {
        (contentViewController as? SpotlightViewController)?.resetHeldEntryChordKeys()
        super.resignKey()
    }

    override func cancelOperation(_ sender: Any?) {
        // NSPanel intercepts Escape key and calls this instead of keyDown
        print("🔍 [SpotlightPanel] cancelOperation called - Escape intercepted!")
        hide()
    }

    override func keyDown(with event: NSEvent) {
        print("🔍 [SpotlightPanel] keyDown - keyCode: \(event.keyCode)")
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        print("🔍 [SpotlightPanel] performKeyEquivalent - keyCode: \(event.keyCode)")
        if event.keyCode == 53 {
            print("🔍 [SpotlightPanel] Escape caught in performKeyEquivalent!")
            hide()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    func show() {
        self.center()
        self.orderFrontRegardless()
        self.makeKey()

        // Focus the text field if there is one
        if let viewController = self.contentViewController as? SpotlightViewController {
            viewController.resetHeldEntryChordKeys()
            viewController.focusTextField()
        }
    }

    func hide() {
        (contentViewController as? SpotlightViewController)?.resetHeldEntryChordKeys()
        self.orderOut(nil)
    }

    func updateHeight(_ newHeight: CGFloat, animated: Bool) {
        // Keep current X position, keep top edge fixed (grow downward)
        let currentTopY = frame.maxY
        let newY = currentTopY - newHeight

        let newFrame = NSRect(x: frame.origin.x, y: newY, width: frame.width, height: newHeight)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().setFrame(newFrame, display: true)
            }
        } else {
            setFrame(newFrame, display: true)
        }
    }
}
