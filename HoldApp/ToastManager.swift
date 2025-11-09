//
//  ToastManager.swift
//  HoldApp
//
//  Displays temporary toast messages for confirmations and errors
//

import Cocoa

class ToastManager {
    static let shared = ToastManager()

    private init() {}

    private var currentToast: NSPanel?

    /// Show a toast message
    /// - Parameters:
    ///   - message: Message text
    ///   - type: success or error
    ///   - duration: How long to show (default 2 seconds)
    func show(_ message: String, type: ToastType, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async { [weak self] in
            self?.dismissCurrent()
            self?.showToast(message, type: type, duration: duration)
        }
    }

    private func showToast(_ message: String, type: ToastType, duration: TimeInterval) {
        // Create panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        // Create container view with background
        let containerView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        containerView.wantsLayer = true

        let backgroundColor: NSColor = type == .success ? NSColor.systemGreen : NSColor.systemRed
        containerView.layer?.backgroundColor = backgroundColor.withAlphaComponent(0.9).cgColor
        containerView.layer?.cornerRadius = 8

        // Create label
        let label = NSTextField(labelWithString: message)
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.alignment = .center
        label.frame = NSRect(x: 20, y: 15, width: 360, height: 30)

        containerView.addSubview(label)
        panel.contentView = containerView

        // Position at top center
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - panel.frame.width / 2
            let y = screenFrame.maxY - 100  // 100 pixels from top
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Show panel
        panel.orderFrontRegardless()
        currentToast = panel

        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak panel] in
            guard let panel = panel, self?.currentToast === panel else { return }
            self?.dismissCurrent()
        }
    }

    private func dismissCurrent() {
        currentToast?.orderOut(nil)
        currentToast = nil
    }
}

enum ToastType {
    case success
    case error
}
