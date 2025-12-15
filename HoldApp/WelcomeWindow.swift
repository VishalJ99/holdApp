//
//  WelcomeWindow.swift
//  HoldApp
//
//  First-launch onboarding window with paginated walkthrough
//  Visual style matches Spotlight pill (frosted glass, white border)
//

import Cocoa
import SwiftUI

// MARK: - Onboarding Page Data

struct OnboardingPage {
    let title: String
    let subtitle: String?
    let items: [String]?
    let isLastPage: Bool

    init(title: String, subtitle: String? = nil, items: [String]? = nil, isLastPage: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.isLastPage = isLastPage
    }
}

// MARK: - SwiftUI Onboarding View

struct WelcomeView: View {
    @Binding var currentPage: Int
    let onComplete: () -> Void

    let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Hold frees your mind.",
            subtitle: "Capture what you're working on. Your iPhone displays it. Your brain doesn't have to hold it."
        ),
        OnboardingPage(
            title: "Capture",
            subtitle: "Cmd+Shift+Space opens Spotlight\n\nType your task and press Enter."
        ),
        OnboardingPage(
            title: "Build task trees",
            items: [
                "Shift+Enter \u{2192} Child task (auto-switches)",
                "Cmd+Enter \u{2192} Sibling task",
                "Ctrl+Enter \u{2192} Task + switch to it"
            ]
        ),
        OnboardingPage(
            title: "Navigate",
            items: [
                "Cmd+Shift+S \u{2192} Leaf selector",
                "Cmd+Shift+R \u{2192} Root selector",
                "Cmd+P in Spotlight \u{2192} Pick parent"
            ]
        ),
        OnboardingPage(
            title: "Complete tasks",
            items: [
                "Cmd+Shift+D \u{2192} Dismiss task",
                "Cmd+Shift+Backspace (x2) \u{2192} Nuke all"
            ]
        ),
        OnboardingPage(
            title: "Make it yours",
            subtitle: "Open Preferences from the menu bar to customize hotkeys and modifiers."
        ),
        OnboardingPage(
            title: "Your iPhone is waiting.",
            isLastPage: true
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            pageContent
                .frame(height: 180)

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
        .frame(width: 420, height: 280)
    }

    @ViewBuilder
    private var pageContent: some View {
        let page = pages[currentPage]

        VStack(spacing: 16) {
            // Title
            Text(page.title)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Subtitle or items
            if let subtitle = page.subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            if let items = page.items {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
    }

    private func nextPage() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if currentPage < pages.count - 1 {
                currentPage += 1
            }
        }
    }

    private func previousPage() {
        withAnimation(.easeInOut(duration: 0.2)) {
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

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
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

        setupContent()
        self.center()
    }

    private func setupContent() {
        // Create container view
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 280))
        containerView.wantsLayer = true

        // Frosted glass effect (matches Spotlight)
        let visualEffectView = NSVisualEffectView(frame: containerView.bounds)
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 30
        visualEffectView.layer?.masksToBounds = true

        // Border (matches Spotlight)
        let borderLayer = CALayer()
        borderLayer.frame = visualEffectView.bounds
        borderLayer.cornerRadius = 30
        borderLayer.borderWidth = 1.0
        borderLayer.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        visualEffectView.layer?.addSublayer(borderLayer)

        containerView.addSubview(visualEffectView)

        // SwiftUI content
        let hostingView = NSHostingView(rootView: WelcomeContentWrapper(panel: self))
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(hostingView)

        self.contentView = containerView
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
        WelcomeView(currentPage: $currentPage) {
            panel.complete()
        }
        .onAppear {
            // Enable arrow key navigation
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 123 { // Left arrow
                    withAnimation { if currentPage > 0 { currentPage -= 1 } }
                    return nil
                } else if event.keyCode == 124 { // Right arrow
                    withAnimation { if currentPage < 6 { currentPage += 1 } }
                    return nil
                }
                return event
            }
        }
    }
}
