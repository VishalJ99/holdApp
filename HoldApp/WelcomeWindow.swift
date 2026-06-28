//
//  WelcomeWindow.swift
//  HoldApp
//
//  First-launch onboarding window with paginated walkthrough
//  Visual style matches Spotlight pill (dark frosted glass, white border)
//

import Cocoa
import SwiftUI

// MARK: - Onboarding Page Data

struct OnboardingPage {
    let title: String
    let content: [ContentLine]
    let isLastPage: Bool

    enum ContentLine {
        case text(String)
        case command(cmd: String, suffix: String? = nil, description: String)  // • cmd (suffix) → description
        case spacer
    }

    init(title: String, lines: [ContentLine] = [], isLastPage: Bool = false) {
        self.title = title
        self.content = lines
        self.isLastPage = isLastPage
    }
}

// MARK: - SwiftUI Onboarding View

struct WelcomeView: View {
    @Binding var currentPage: Int
    let onComplete: () -> Void
    let onHeightChange: (CGFloat) -> Void

    // Two preset heights
    private let smallHeight: CGFloat = 260
    private let largeHeight: CGFloat = 420

    private func heightForPage(_ page: Int) -> CGFloat {
        // Page 2 (index 2) is "Build task trees" - needs more space
        return page == 2 ? largeHeight : smallHeight
    }

    let pages: [OnboardingPage] = [
        // Page 1: Philosophy
        OnboardingPage(
            title: "Hold frees your mind.",
            lines: [
                .text("Capture what you're working on."),
                .text("Your iPhone displays it."),
                .text("Your brain doesn't have to hold it.")
            ]
        ),

        // Page 2: Capture
        OnboardingPage(
            title: "Capture",
            lines: [
                .command(cmd: "Cmd+Shift+Space", description: "opens Spotlight"),
                .spacer,
                .text("Type and press Enter to display your first task.")
            ]
        ),

        // Page 3: Build task trees
        OnboardingPage(
            title: "Build task trees",
            lines: [
                .command(cmd: "Enter", description: "creates a new independent task (root)"),
                .spacer,
                .text("To maintain a relationship:"),
                .command(cmd: "Shift+Enter", description: "Child of current"),
                .command(cmd: "Cmd+Enter", description: "Sibling of current"),
                .command(cmd: "Cmd+Shift+Enter", description: "New parent of current"),
                .spacer,
                .text("Hold Ctrl to also switch,"),
                .command(cmd: "Ctrl+Cmd+Enter", description: "Sibling + switch"),
                .spacer,
                .text("To choose a specific task as parent:"),
                .command(cmd: "Cmd+P", description: "opens parent selector")
            ]
        ),

        // Page 4: Navigate
        OnboardingPage(
            title: "Navigate",
            lines: [
                .text("Switch between leaves in your tree,"),
                .text("or jump to another tree entirely."),
                .spacer,
                .command(cmd: "Cmd+Shift+S", description: "Leaf selector"),
                .command(cmd: "Cmd+Shift+R", description: "Root selector")
            ]
        ),

        // Page 5: Quick Edit
        OnboardingPage(
            title: "Quick Edit",
            lines: [
                .text("Need to fix a typo or restructure?"),
                .spacer,
                .command(cmd: "↑", suffix: "(Up Arrow)", description: "Edit current task"),
                .command(cmd: "Cmd+P", suffix: "(in edit)", description: "Re-parent task"),
                .spacer,
                .text("Press Enter to save, Escape to cancel.")
            ]
        ),

        // Page 6: Complete tasks
        OnboardingPage(
            title: "Complete tasks",
            lines: [
                .command(cmd: "Cmd+Shift+D", description: "Dismiss current task"),
                .command(cmd: "Cmd+Shift+Backspace", suffix: "(x2)", description: "Nuke all tasks")
            ]
        ),

        // Page 7: Customize
        OnboardingPage(
            title: "Make it yours",
            lines: [
                .text("Open Preferences from the menu bar"),
                .text("to customize hotkeys and modifiers.")
            ]
        ),

        // Page 8: Get Started
        OnboardingPage(
            title: "Your iPhone is waiting.",
            isLastPage: true
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            pageContent
                .padding(.top, 28)
                .padding(.bottom, 32)

            Spacer()

            // Navigation
            HStack {
                // Back button (hidden on first page)
                Button(action: previousPage) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .opacity(currentPage > 0 ? 1 : 0)
                .disabled(currentPage == 0)

                Spacer()

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.white.opacity(0.9) : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                // Next/Get Started button
                if pages[currentPage].isLastPage {
                    Button(action: onComplete) {
                        Text("Get Started")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: nextPage) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 420, height: heightForPage(currentPage))
        .onAppear {
            onHeightChange(heightForPage(currentPage))
        }
        .onChange(of: currentPage) { newPage in
            onHeightChange(heightForPage(newPage))
        }
    }

    // Check if page has any commands (vs just text)
    private func hasCommands(_ page: OnboardingPage) -> Bool {
        page.content.contains { line in
            if case .command = line { return true }
            return false
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        let page = pages[currentPage]

        // Center content if no commands (text-only or empty pages)
        if page.content.isEmpty || !hasCommands(page) {
            VStack(spacing: 6) {
                Spacer()

                Text(page.title)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white)

                if !page.content.isEmpty {
                    Spacer().frame(height: 12)

                    ForEach(Array(page.content.enumerated()), id: \.offset) { _, line in
                        if case .text(let text) = line {
                            Text(text)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        } else if case .spacer = line {
                            Spacer().frame(height: 8)
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(page.title)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white)

                Spacer().frame(height: 12)

                // Content lines
                ForEach(Array(page.content.enumerated()), id: \.offset) { _, line in
                    switch line {
                    case .text(let text):
                        Text(text)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))

                    case .command(let cmd, let suffix, let description):
                        HStack(alignment: .center, spacing: 6) {
                            Text(cmd)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.95))
                                .padding(.vertical, 3)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(4)

                            if let suffix = suffix {
                                Text(suffix)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Text("→")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.5))

                            Text(description)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }

                    case .spacer:
                        Spacer().frame(height: 8)
                    }
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private func nextPage() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if currentPage < pages.count - 1 {
                currentPage += 1
            }
        }
    }

    private func previousPage() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if currentPage > 0 {
                currentPage -= 1
            }
        }
    }
}

// MARK: - NSPanel Wrapper

class WelcomePanel: NSPanel {

    private var currentPage: Int = 0
    var onComplete: (() -> Void)?
    private var hostingView: NSHostingView<WelcomeContentWrapper>?
    private var visualEffectView: NSVisualEffectView?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.hasShadow = true
        self.appearance = NSAppearance(named: .darkAqua)

        setupContent()
        self.center()
    }

    private func setupContent() {
        // Create container view
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 200))
        containerView.wantsLayer = true
        containerView.autoresizingMask = [.width, .height]
        containerView.appearance = NSAppearance(named: .darkAqua)

        // Frosted glass effect (matches Spotlight)
        let visualEffect = NSVisualEffectView(frame: containerView.bounds)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.appearance = NSAppearance(named: .darkAqua)
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 30
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 1.0
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        visualEffect.autoresizingMask = [.width, .height]
        self.visualEffectView = visualEffect

        containerView.addSubview(visualEffect)

        // SwiftUI content
        let hosting = NSHostingView(rootView: WelcomeContentWrapper(panel: self))
        hosting.frame = containerView.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.appearance = NSAppearance(named: .darkAqua)
        visualEffect.addSubview(hosting)
        self.hostingView = hosting

        self.contentView = containerView
    }

    func updateHeight(_ newHeight: CGFloat) {
        guard newHeight > 0 else { return }

        let currentFrame = self.frame
        let heightDiff = newHeight - currentFrame.height

        // Keep window centered vertically as it resizes
        let newY = currentFrame.origin.y - heightDiff / 2
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: newHeight)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: true)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        // Escape key dismisses
        complete()
    }

    override func keyDown(with event: NSEvent) {
        // Arrow key navigation handled by SwiftUI
        super.keyDown(with: event)
    }

    func show() {
        self.center()
        self.orderFrontRegardless()
        self.makeKey()
    }

    func hide() {
        self.orderOut(nil)
    }

    func complete() {
        hide()
        onComplete?()
    }
}

// MARK: - SwiftUI Wrapper for Panel Reference

struct WelcomeContentWrapper: View {
    let panel: WelcomePanel
    @State private var currentPage: Int = 0

    var body: some View {
        WelcomeView(currentPage: $currentPage, onComplete: {
            panel.complete()
        }, onHeightChange: { height in
            panel.updateHeight(height)
        })
        .onAppear {
            // Enable arrow key navigation
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 123 { // Left arrow
                    withAnimation { if currentPage > 0 { currentPage -= 1 } }
                    return nil
                } else if event.keyCode == 124 { // Right arrow
                    withAnimation { if currentPage < 7 { currentPage += 1 } }
                    return nil
                }
                return event
            }
        }
    }
}
