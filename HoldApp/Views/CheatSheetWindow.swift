import Cocoa
import SwiftUI

class CheatSheetWindow: NSPanel {
    private var hostingView: NSHostingView<CheatSheetView>?

    init(onClose: @escaping () -> Void) {
        super.init(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1000, height: 800),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating + 2 // Above everything
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false

        let cheatSheetView = CheatSheetView(onClose: onClose)
        hostingView = NSHostingView(rootView: cheatSheetView)
        self.contentView = hostingView

        // Cover full screen
        if let screen = NSScreen.main {
            self.setFrame(screen.frame, display: true)
        }
    }

    override var canBecomeKey: Bool {
        return true
    }

    func show() {
        self.orderFrontRegardless()
        self.makeKey()
    }
}
