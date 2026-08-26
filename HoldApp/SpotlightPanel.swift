import Cocoa
import ApplicationServices
import CoreGraphics

class SpotlightPanel: NSPanel {

    private var entryChordEventTap: CFMachPort?
    private var entryChordEventTapSource: CFRunLoopSource?

    private static let entryChordEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let panel = Unmanaged<SpotlightPanel>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
        return panel.handleEntryChordEventTap(type: type, event: event)
    }

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

    deinit {
        stopEntryChordEventTap()
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
        stopEntryChordEventTap()
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
            startEntryChordEventTapIfNeeded(for: viewController)
        }
    }

    func hide() {
        stopEntryChordEventTap()
        (contentViewController as? SpotlightViewController)?.resetHeldEntryChordKeys()
        self.orderOut(nil)
    }

    private func startEntryChordEventTapIfNeeded(for viewController: SpotlightViewController) {
        stopEntryChordEventTap()
        guard viewController.hasReservedEntryChordKeys else { return }

        guard AXIsProcessTrusted() else {
            ToastManager.shared.show(
                "Allow Hold in Accessibility to use system Entry Chords",
                level: .warning
            )
            return
        }

        let eventTypes: [CGEventType] = [.keyDown, .keyUp]
        let eventMask = eventTypes.reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << type.rawValue)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.entryChordEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            ToastManager.shared.show(
                "System Entry Chord capture is unavailable",
                level: .warning
            )
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            return
        }

        entryChordEventTap = eventTap
        entryChordEventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handleEntryChordEventTap(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if isVisible, isKeyWindow, let entryChordEventTap {
                CGEvent.tapEnable(tap: entryChordEventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard isVisible,
              isKeyWindow,
              let viewController = contentViewController as? SpotlightViewController else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let consumed: Bool
        switch type {
        case .keyDown:
            consumed = viewController.handleHeldEntryChordKey(
                keyCode,
                isKeyDown: true
            )
        case .keyUp:
            consumed = viewController.handleHeldEntryChordKey(
                keyCode,
                isKeyDown: false
            )
        default:
            consumed = false
        }

        return consumed ? nil : Unmanaged.passUnretained(event)
    }

    private func stopEntryChordEventTap() {
        if let entryChordEventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), entryChordEventTapSource, .commonModes)
        }
        if let entryChordEventTap {
            CGEvent.tapEnable(tap: entryChordEventTap, enable: false)
            CFMachPortInvalidate(entryChordEventTap)
        }
        entryChordEventTapSource = nil
        entryChordEventTap = nil
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
