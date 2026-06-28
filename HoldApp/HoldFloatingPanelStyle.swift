import Cocoa
import SwiftUI

enum HoldFloatingPanelStyle {
    static let cornerRadius: CGFloat = 16
    static let darkAppearance = NSAppearance(named: .darkAqua)

    static let primaryText = Color.white.opacity(0.96)
    static let secondaryText = Color.white.opacity(0.80)
    static let tertiaryText = Color.white.opacity(0.68)
    static let divider = Color.white.opacity(0.16)
    static let rowHighlight = Color.white.opacity(0.18)
    static let controlFill = Color.white.opacity(0.14)
    static let selectedControlFill = Color.white.opacity(0.26)
    static let selectedControlStroke = Color.white.opacity(0.36)
    static let border = Color.white.opacity(0.24)

    static let appKitBackingColor = NSColor(calibratedWhite: 0.04, alpha: 0.86)
    static let appKitBorderColor = NSColor.white.withAlphaComponent(0.24)

    static func configurePanel(_ panel: NSPanel) {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.appearance = darkAppearance
    }

    static func configureRoundedContentView(_ view: NSView?, cornerRadius: CGFloat = Self.cornerRadius) {
        guard let view else { return }

        view.wantsLayer = true
        view.appearance = darkAppearance
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = appKitBackingColor.cgColor
    }

    static func configureHostingView<Content: View>(_ hostingView: NSHostingView<Content>) {
        hostingView.appearance = darkAppearance
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
    }

    static func configureDarkVisualEffect(
        _ visualEffectView: NSVisualEffectView,
        material: NSVisualEffectView.Material = .hudWindow,
        cornerRadius: CGFloat
    ) {
        visualEffectView.material = material
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.appearance = darkAppearance
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = cornerRadius
        visualEffectView.layer?.cornerCurve = .continuous
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.backgroundColor = appKitBackingColor.cgColor
    }
}

struct HoldFloatingPanelBackdrop: View {
    var cornerRadius: CGFloat = HoldFloatingPanelStyle.cornerRadius

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.74))
        }
    }
}
