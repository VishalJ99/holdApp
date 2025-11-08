import Cocoa
import SwiftUI

class EditorWindow: NSWindow {
    private var hostingView: NSHostingView<EditorView>?

    init(appState: AppState, taskManager: TaskManager) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        self.title = "Hold - Task Editor"
        self.minSize = NSSize(width: 400, height: 600)
        self.level = .normal
        self.isReleasedWhenClosed = false

        let editorView = EditorView(
            appState: appState,
            taskManager: taskManager,
            onClose: { [weak self] in
                self?.close()
            }
        )

        hostingView = NSHostingView(rootView: editorView)
        self.contentView = hostingView

        self.center()
    }

    override func close() {
        super.close()
    }
}
