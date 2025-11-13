//
//  SiblingSelectorPanel.swift
//  HoldApp
//
//  Floating panel for sibling selector (Cmd+Shift+S)
//  Minimal, terminal-inspired aesthetic matching SpotlightPanel
//

import Cocoa

class SiblingSelectorPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
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

    /// Show the panel with sibling list
    func show(siblings: [(id: String, text: String)], currentIndex: Int) {
        // Adjust height based on sibling count
        let rowHeight: CGFloat = 36  // 32px row + 4px spacing
        let minHeight: CGFloat = 100
        let maxHeight: CGFloat = 500
        let calculatedHeight = CGFloat(siblings.count) * rowHeight + 40  // +40 for padding

        let newHeight = min(max(calculatedHeight, minHeight), maxHeight)
        let currentFrame = self.frame
        self.setFrame(NSRect(x: currentFrame.origin.x, y: currentFrame.origin.y, width: 500, height: newHeight), display: false)

        // Center on screen with new height
        self.center()

        // Update view controller with siblings
        if let viewController = self.contentViewController as? SiblingSelectorViewController {
            viewController.updateSiblings(siblings, currentIndex: currentIndex)
            viewController.focusTableView()
        }

        // Show panel
        self.orderFrontRegardless()
        self.makeKey()
    }

    /// Hide the panel
    func hide() {
        self.orderOut(nil)
    }
}
