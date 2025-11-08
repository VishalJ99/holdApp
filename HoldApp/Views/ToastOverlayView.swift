import SwiftUI

/// Global toast overlay that displays success/error messages
struct ToastOverlayView: View {
    @ObservedObject var toastManager = ToastManager.shared

    var body: some View {
        ZStack {
            if let toast = toastManager.currentToast {
                VStack {
                    Spacer()
                        .frame(height: 100)

                    ToastView(toast: toast)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: UIConstants.toastFadeIn), value: toastManager.currentToast)

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false) // Don't block clicks
    }
}

/// Toast window that floats above all other windows
class ToastWindow: NSPanel {
    private var hostingView: NSHostingView<ToastOverlayView>?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: NSScreen.main?.frame.width ?? 800, height: NSScreen.main?.frame.height ?? 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating + 1 // Above Spotlight
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true

        let overlayView = ToastOverlayView()
        hostingView = NSHostingView(rootView: overlayView)
        self.contentView = hostingView

        // Position to cover full screen
        if let screen = NSScreen.main {
            self.setFrame(screen.frame, display: true)
        }

        self.orderFront(nil)
    }

    func updatePosition() {
        if let screen = NSScreen.main {
            self.setFrame(screen.frame, display: true)
        }
    }
}
