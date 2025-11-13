//
//  RootSelectorPanel.swift
//  HoldApp
//
//  Floating panel for root selector (Cmd+Shift+R)
//  Minimal, terminal-inspired aesthetic matching SpotlightPanel
//

import Cocoa

class RootSelectorPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel for floating behavior (similar to Spotlight)
        self.level = .floating
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = NSColor.black.withAlphaComponent(0.95)
        self.hasShadow = true
        self.isOpaque = false

        // Round corners (terminal-like aesthetic)
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

    override func cancelOperation(_ sender: Any?) {
        // NSPanel intercepts Escape key and calls this instead of keyDown
        print("🌳 [RootPanel] cancelOperation called - Escape intercepted!")
        hide()
    }

    override func keyDown(with event: NSEvent) {
        print("🌳 [RootPanel] keyDown - keyCode: \(event.keyCode)")
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        print("🌳 [RootPanel] performKeyEquivalent - keyCode: \(event.keyCode)")
        if event.keyCode == 53 {
            print("🌳 [RootPanel] Escape caught in performKeyEquivalent!")
            hide()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Show the panel with root list
    func show(roots: [(id: String, text: String)], currentRootId: String?) {
        print("🌳 [RootPanel.show] Called with \(roots.count) roots, currentRootId: \(currentRootId ?? "nil")")

        // Adjust height based on root count
        let rowHeight: CGFloat = 36  // 32px row + 4px spacing
        let minHeight: CGFloat = 100
        let maxHeight: CGFloat = 500
        let calculatedHeight = CGFloat(roots.count) * rowHeight + 40  // +40 for padding

        let newHeight = min(max(calculatedHeight, minHeight), maxHeight)
        let currentFrame = self.frame
        self.setFrame(NSRect(x: currentFrame.origin.x, y: currentFrame.origin.y, width: 500, height: newHeight), display: false)

        // Center on screen with new height
        self.center()

        // Update view controller with roots
        print("🌳 [RootPanel.show] contentViewController: \(self.contentViewController != nil ? "exists" : "nil")")
        if let viewController = self.contentViewController as? RootSelectorViewController {
            print("🌳 [RootPanel.show] Casting to RootSelectorViewController succeeded")
            viewController.updateRoots(roots, currentRootId: currentRootId)
        } else {
            print("❌ [RootPanel.show] contentViewController is nil or wrong type!")
        }

        // Show panel
        print("🌳 [RootPanel.show] Activating app and showing panel...")
        NSApp.activate(ignoringOtherApps: true)
        self.orderFrontRegardless()
        self.makeKey()

        print("🌳 [RootPanel.show] isKeyWindow (immediate): \(self.isKeyWindow), canBecomeKey: \(self.canBecomeKey)")

        // Delay focus until next run loop - makeKey() is asynchronous
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("🌳 [RootPanel.show] isKeyWindow (async): \(self.isKeyWindow)")

            // Make table view first responder after panel becomes key
            if let viewController = self.contentViewController as? RootSelectorViewController {
                print("🌳 [RootPanel.show] Calling focusTableView() in async block...")
                viewController.focusTableView()
            } else {
                print("❌ [RootPanel.show] Can't call focusTableView - no view controller!")
            }
        }
    }

    /// Hide the panel
    func hide() {
        print("🌳 [RootPanel.hide] Hiding panel")
        self.orderOut(nil)
    }
}
