import Cocoa
import SwiftUI

class SpotlightPanel: NSPanel {
    private var hostingView: NSHostingView<SpotlightView>?

    init(appState: AppState, taskManager: TaskManager) {
        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: UIConstants.spotlightWidth,
                height: UIConstants.spotlightHeight
            ),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true

        // Create SwiftUI view
        let spotlightView = SpotlightView(
            appState: appState,
            taskManager: taskManager,
            onClose: { [weak self] in
                self?.hide()
            }
        )

        hostingView = NSHostingView(rootView: spotlightView)
        self.contentView = hostingView

        centerOnScreen()
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return false
    }

    func show() {
        centerOnScreen()
        orderFrontRegardless()
        makeKey()
    }

    func hide() {
        orderOut(nil)
    }

    private func centerOnScreen() {
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - frame.width / 2
            let y = screenRect.midY + screenRect.height / 4 // Top third
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
