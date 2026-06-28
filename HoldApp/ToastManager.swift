//
//  ToastManager.swift
//  HoldApp
//
//  Displays temporary toast notifications with frosted glass aesthetic
//  Matches app's dark floating-panel visual language with stable contrast.
//

import Cocoa

// MARK: - Toast Level

enum ToastLevel {
    case success
    case info
    case warning
    case error

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .success, .info: return 3.0
        case .warning, .error: return 4.0
        }
    }

    var accessibilityPrefix: String {
        switch self {
        case .success: return "Success"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
}

// MARK: - Toast Manager

class ToastManager {
    static let shared = ToastManager()

    private init() {}

    private var currentToast: NSPanel?
    private var dismissTimer: Timer?

    /// Show a toast message with semantic level
    /// - Parameters:
    ///   - message: Message text (will be truncated to ~40 chars)
    ///   - level: Semantic level (success, info, warning, error)
    ///   - duration: Override default duration (optional)
    func show(_ message: String, level: ToastLevel, duration: TimeInterval? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.dismissCurrent(animated: false)
            self?.showToast(message, level: level, duration: duration ?? level.duration)
        }
    }

    private func showToast(_ message: String, level: ToastLevel, duration: TimeInterval) {
        // Truncate message to ~40 characters
        let truncatedMessage = message.count > 40
            ? String(message.prefix(37)) + "..."
            : message

        // Create panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        HoldFloatingPanelStyle.configurePanel(panel)

        // Create container with visual effect (frosted glass)
        let containerView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        containerView.wantsLayer = true
        containerView.appearance = HoldFloatingPanelStyle.darkAppearance

        // Frosted glass effect
        let visualEffectView = NSVisualEffectView(frame: containerView.bounds)
        HoldFloatingPanelStyle.configureDarkVisualEffect(
            visualEffectView,
            cornerRadius: 12
        )

        // Border overlay
        let borderLayer = CALayer()
        borderLayer.frame = visualEffectView.bounds
        borderLayer.cornerRadius = 12
        borderLayer.borderWidth = 1.0
        borderLayer.borderColor = HoldFloatingPanelStyle.appKitBorderColor.cgColor
        visualEffectView.layer?.addSublayer(borderLayer)

        // Red tint overlay for errors (8% opacity)
        if level == .error {
            let errorTintLayer = CALayer()
            errorTintLayer.frame = visualEffectView.bounds
            errorTintLayer.cornerRadius = 12
            errorTintLayer.backgroundColor = NSColor.systemRed.withAlphaComponent(0.08).cgColor
            visualEffectView.layer?.insertSublayer(errorTintLayer, at: 0)
        }

        containerView.addSubview(visualEffectView)

        // Create SF Symbol icon
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let iconImage = NSImage(systemSymbolName: level.iconName, accessibilityDescription: level.accessibilityPrefix)?
            .withSymbolConfiguration(iconConfig)

        let iconView = NSImageView()
        iconView.image = iconImage
        iconView.contentTintColor = NSColor.white.withAlphaComponent(0.9)

        // Create label
        let label = NSTextField(labelWithString: truncatedMessage)
        label.textColor = NSColor.white.withAlphaComponent(0.94)
        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.sizeToFit()

        // Center the icon+text group
        let iconSize: CGFloat = 20
        let spacing: CGFloat = 8
        let textWidth = min(label.frame.width, 340)  // Cap text width
        let totalContentWidth = iconSize + spacing + textWidth
        let startX = (400 - totalContentWidth) / 2

        iconView.frame = NSRect(x: startX, y: 16, width: iconSize, height: iconSize)
        label.frame = NSRect(x: startX + iconSize + spacing, y: 16, width: textWidth, height: 20)

        visualEffectView.addSubview(iconView)
        visualEffectView.addSubview(label)

        panel.contentView = containerView

        // Position at top center (80px from top)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - panel.frame.width / 2
            let y = screenFrame.maxY - 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Start hidden for animation
        panel.alphaValue = 0.0
        containerView.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)

        // Show panel
        panel.orderFrontRegardless()
        currentToast = panel

        // Animate in (respect Reduce Motion)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let animationDuration = reduceMotion ? 0.1 : 0.2

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0

            if !reduceMotion {
                containerView.layer?.transform = CATransform3DIdentity
            }
        }

        // Post accessibility announcement
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: "\(level.accessibilityPrefix), \(truncatedMessage)"]
        )

        // Schedule auto-dismiss
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self, weak panel] _ in
            guard let panel = panel, self?.currentToast === panel else { return }
            self?.dismissCurrent(animated: true)
        }
    }

    private func dismissCurrent(animated: Bool) {
        dismissTimer?.invalidate()
        dismissTimer = nil

        guard let panel = currentToast else { return }

        if animated {
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            let animationDuration = reduceMotion ? 0.15 : 0.3

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0.0

                if !reduceMotion, let containerView = panel.contentView {
                    containerView.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
                }
            }, completionHandler: { [weak self] in
                panel.orderOut(nil)
                if self?.currentToast === panel {
                    self?.currentToast = nil
                }
            })
        } else {
            panel.orderOut(nil)
            currentToast = nil
        }
    }
}
