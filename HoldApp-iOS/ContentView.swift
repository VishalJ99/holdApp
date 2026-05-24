//
//  ContentView.swift
//  HoldApp-iOS
//
//  Created by Vishal Jain on 04/11/2025.
//

import SwiftUI
import CloudKit
import os

private let logger = Logger(subsystem: "com.vishaljain.HoldApp", category: "iOS-ContentView")

private let onboardingPages = [
    OnboardingPage(
        index: 0,
        title: "Hold",
        body: "A home for your current task. A steady anchor in a sea of distraction."
    ),
    OnboardingPage(
        index: 1,
        title: "Simple on iPhone",
        body: "Type one thing and keep it visible. Clean, quiet, and always ready."
    ),
    OnboardingPage(
        index: 2,
        title: "Full on Mac",
        body: "Install Hold for macOS to create child tasks, sibling tasks, multiple roots, and capture quickly with a keyboard shortcut."
    )
]

struct ContentView: View {
    // Hierarchy display state
    @State private var rootTask: String?
    @State private var parentTask: String?
    @State private var currentTask: String?
    @State private var showEllipsis: Bool = false
    @State private var siblingPosition: Int?
    @State private var siblingTotal: Int?
    @State private var isLoading: Bool = true
    @State private var macPresenceStatus: MacPresenceStatus?
    @State private var standaloneTaskText: String = ""
    @State private var isSavingStandaloneTask: Bool = false
    @State private var standaloneError: String?
    @State private var onboardingStep: Int = 0
    @AppStorage("hasCompletedMacCompanionOnboarding") private var hasCompletedMacCompanionOnboarding: Bool = false
    @FocusState private var isStandaloneInputFocused: Bool

    private var shouldShowStandaloneInput: Bool {
        !isLoading && currentTask == nil && macPresenceStatus?.isFresh == false
    }

    private var shouldShowOnboarding: Bool {
        shouldShowStandaloneInput && !hasCompletedMacCompanionOnboarding
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if shouldShowOnboarding {
                MacCompanionOnboardingView(
                    currentStep: $onboardingStep,
                    onComplete: completeOnboarding
                )
            } else if shouldShowStandaloneInput {
                StandaloneHoldEntryView(
                    text: $standaloneTaskText,
                    isSaving: isSavingStandaloneTask,
                    errorMessage: standaloneError,
                    isFocused: $isStandaloneInputFocused,
                    onSubmit: saveStandaloneHold
                )
            } else if currentTask == nil {
                Text("what are you holding?")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            } else {
                // Centered hierarchy display with max contrast
                HierarchyView_MaxContrast(
                    rootTask: rootTask,
                    parentTask: parentTask,
                    currentTask: currentTask,
                    showEllipsis: showEllipsis,
                    siblingPosition: siblingPosition,
                    siblingTotal: siblingTotal
                )
            }
        }
        .onAppear {
            logger.error("[VIEW] onAppear - starting init")
            print("📲 [ContentView] View appeared - initializing...")

            // Keep screen on while displaying task (like YouTube)
            UIApplication.shared.isIdleTimerDisabled = true
            print("📲 [ContentView] Screen auto-lock disabled")

            setupCloudKitSubscription()
            refreshMacPresence()
            fetchCurrentTask()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshMacPresence()
            fetchCurrentTask()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            refreshMacPresence()
        }
        .persistentSystemOverlays(.hidden) // Hide home indicator
        .statusBarHidden(true) // Hide status bar for fully immersive black
    }

    func completeOnboarding() {
        hasCompletedMacCompanionOnboarding = true
        isStandaloneInputFocused = true
    }

    func fetchCurrentTask() {
        logger.error("[FETCH] fetchCurrentTask called")
        let fetchRequestTime = Date()
        print("📲 [ContentView] Fetch requested at \(fetchRequestTime)")

        // Fetch pointer - contains ALL display info in one request
        CloudKitManager.shared.fetchCurrentTask { result in
            switch result {
            case .success(let taskData):
                let totalTime = Date().timeIntervalSince(fetchRequestTime)

                // Extract all fields from pointer (no additional fetches needed!)
                let currentText = taskData.text
                let parentText = taskData.parentTaskText
                let rootText = taskData.rootTaskText
                let showEllipsis = taskData.showEllipsis
                let siblingPos = taskData.siblingPosition
                let siblingCnt = taskData.siblingCount

                // Update UI on main thread
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.currentTask = currentText
                    self.parentTask = parentText
                    self.rootTask = rootText
                    self.showEllipsis = showEllipsis
                    self.siblingPosition = siblingPos
                    self.siblingTotal = siblingCnt

                    logger.error("[FETCH] SUCCESS - taskId=\(taskData.taskId ?? "nil") text=\(String(describing: currentText?.prefix(30)))")
                    print("✅ [ContentView] UI updated in \(String(format: "%.2f", totalTime))s")
                    print("📲 [ContentView] Hierarchy:")
                    print("   Root: \(rootText ?? "nil")")
                    print("   Ellipsis: \(showEllipsis ? "YES" : "NO")")
                    print("   Parent: \(parentText ?? "nil")")
                    print("   Current: \(currentText ?? "nil")")
                    print("📊 [ContentView] Leaves (DFS): \(siblingPos?.description ?? "nil")/\(siblingCnt?.description ?? "nil")")
                }

            case .failure(let error):
                let totalTime = Date().timeIntervalSince(fetchRequestTime)
                DispatchQueue.main.async {
                    self.isLoading = false
                    logger.error("[FETCH] FAILED - \(error.localizedDescription)")
                    print("❌ [ContentView] Error fetching task after \(String(format: "%.2f", totalTime))s: \(error)")
                }
            }
        }
    }

    func refreshMacPresence() {
        CloudKitManager.shared.fetchMacPresence { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let status):
                    self.macPresenceStatus = status
                    logger.error("[MAC_PRESENCE] fresh=\(status.isFresh)")
                    if status.isFresh {
                        self.standaloneError = nil
                        self.isStandaloneInputFocused = false
                    }
                case .failure(let error):
                    self.macPresenceStatus = MacPresenceStatus(lastSeenAt: nil, isFresh: false)
                    logger.error("[MAC_PRESENCE] failed - \(error.localizedDescription)")
                }
            }
        }
    }

    func saveStandaloneHold() {
        let trimmedText = standaloneTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !isSavingStandaloneTask else { return }

        standaloneError = nil
        isSavingStandaloneTask = true
        let taskId = "ios-\(UUID().uuidString)"

        CloudKitManager.shared.updateCurrentTaskPointer(
            taskId: taskId,
            text: trimmedText,
            parentId: nil,
            rootId: nil,
            parentTaskText: nil,
            rootTaskText: nil,
            showEllipsis: false,
            siblingPosition: nil,
            siblingCount: nil,
            sourcePlatform: "iOS"
        ) { error in
            DispatchQueue.main.async {
                self.isSavingStandaloneTask = false
                if let error = error {
                    self.standaloneError = "Could not save"
                    logger.error("[STANDALONE] save failed - \(error.localizedDescription)")
                    return
                }

                self.currentTask = trimmedText
                self.parentTask = nil
                self.rootTask = nil
                self.showEllipsis = false
                self.siblingPosition = nil
                self.siblingTotal = nil
                self.standaloneTaskText = ""
                self.isStandaloneInputFocused = false
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                logger.error("[STANDALONE] iOS hold saved")
            }
        }
    }

    func setupCloudKitSubscription() {
        logger.error("[SUB] setupCloudKitSubscription called")
        print("🔔 [ContentView] Setting up CloudKit subscription and notification observer...")

        // Subscribe to task changes
        CloudKitManager.shared.subscribeToTaskChanges { error in
            logger.error("[SUB] Result - error=\(error?.localizedDescription ?? "none")")
            if let error = error {
                print("❌ [ContentView] Subscription setup failed: \(error)")
            } else {
                print("✅ [ContentView] Subscription setup completed successfully")
            }
        }

        // Listen for CloudKit notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudKitTaskUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            print("🔔 [ContentView] Received CloudKitTaskUpdated notification!")
            print("🔔 [ContentView] Notification object: \(String(describing: notification.object))")
            print("🔔 [ContentView] Triggering fetch...")
            fetchCurrentTask()
        }

        print("✅ [ContentView] NotificationCenter observer registered for CloudKitTaskUpdated")
    }
}

private struct OnboardingPage: Identifiable {
    let index: Int
    let title: String
    let body: String

    var id: Int { index }
}

private struct MacCompanionOnboardingView: View {
    @Binding var currentStep: Int
    let onComplete: () -> Void

    private var isLastStep: Bool {
        currentStep == onboardingPages.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            TabView(selection: $currentStep) {
                ForEach(onboardingPages) { page in
                    VStack(spacing: 18) {
                        Text(page.title)
                            .font(.largeTitle.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text(page.body)
                            .font(.title3.weight(.regular))
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 30)
                    .tag(page.index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: 360)

            OnboardingDots(currentStep: currentStep, count: onboardingPages.count)
                .padding(.top, 16)

            Spacer(minLength: 40)

            VStack(spacing: 12) {
                Button(action: primaryAction) {
                    Text(isLastStep ? "Start holding" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .accessibilityLabel(isLastStep ? "Start holding" : "Continue onboarding")

                Button(action: onComplete) {
                    Text("Use iPhone only")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Use iPhone only")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
    }

    private func primaryAction() {
        if isLastStep {
            onComplete()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                currentStep += 1
            }
        }
    }
}

private struct OnboardingDots: View {
    let currentStep: Int
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == currentStep ? Color.white : Color.white.opacity(0.28))
                    .frame(width: index == currentStep ? 24 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentStep)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding step \(currentStep + 1) of \(count)")
    }
}

private struct StandaloneHoldEntryView: View {
    @Binding var text: String
    let isSaving: Bool
    let errorMessage: String?
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Text("what are you currently holding?")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                TextField("current task", text: $text, axis: .vertical)
                    .focused(isFocused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .frame(minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .onSubmit(onSubmit)
                    .accessibilityLabel("Current hold")

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Button(action: onSubmit) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(isSaving ? "Saving" : "Hold")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            .accessibilityLabel("Hold current task")
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }
}

struct HierarchyView_MaxContrast: View {
    let rootTask: String?
    let parentTask: String?
    let currentTask: String?
    let showEllipsis: Bool
    let siblingPosition: Int?
    let siblingTotal: Int?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 4)

                // ROOT SECTION (only if level 3+)
                if let root = rootTask {
                    Text(root)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    // ELLIPSIS (only if level 4+)
                    if showEllipsis {
                        Spacer().frame(height: 4)
                        Text("⋯")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer().frame(height: 0)
                    }

                    Spacer().frame(height: showEllipsis ? 0 : 10)

                }

                // PARENT SECTION (only if level 2+)
                if let parent = parentTask {
                    Text(parent)
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 8)

                    // Arrow after parent
                    Text("↓")
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))

                    Spacer().frame(height: 4)
                }

                // CURRENT TASK (always shown if exists)
                if let current = currentTask {
                    Text(current)
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                // LEAF INDICATOR (shows position among all leaves in root, DFS order)
                if let position = siblingPosition,
                   let total = siblingTotal,
                   total > 1 {
                    Spacer().frame(height: 18)

                    HStack(spacing: 9) {
                        ForEach(1...total, id: \.self) { index in
                            Circle()
                                .fill(index == position ? Color.white.opacity(0.8) : Color.white.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 36)
        }
    }
}

#Preview {
    ContentView()
}
