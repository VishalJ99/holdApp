//
//  ContentView.swift
//  HoldApp-iOS
//
//  Created by Vishal Jain on 04/11/2025.
//

import SwiftUI
import os

private let logger = Logger(subsystem: "com.vishaljain.HoldApp", category: "iOS-ContentView")
private let standalonePlaceholderText = "what are you holding?"
private let foregroundPointerRefreshInterval: TimeInterval = 3

private enum CurrentTaskFetchTrigger: String {
    case appear
    case foregroundNotification
    case sceneActive
    case timer
    case push
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var rootTask: String?
    @State private var parentTask: String?
    @State private var currentTask: String?
    @State private var showEllipsis: Bool = false
    @State private var siblingPosition: Int?
    @State private var siblingTotal: Int?
    @State private var isLoading: Bool = true
    @State private var isFetchingCurrentTask: Bool = false
    @State private var pendingFetchTrigger: CurrentTaskFetchTrigger?
    @State private var isSettingUpCloudKitSubscription: Bool = false
    @State private var hasSetUpCloudKitSubscription: Bool = false
    @State private var hasMacPointerRecord: Bool = false
    @State private var hasResolvedInitialMacConnectionState: Bool = false
    @State private var isMacConnectedConfirmationVisible: Bool = false
    @State private var macConnectedConfirmationToken = UUID()
    @State private var isEditingStandaloneTask: Bool = false
    @State private var standaloneDraftText: String = ""
    @State private var isConnectionHelpPresented: Bool = false
    @AppStorage("standaloneHoldText") private var standaloneHoldText: String = ""
    @AppStorage("hasShownMacConnectionHelpOnboarding") private var hasShownMacConnectionHelpOnboarding: Bool = false
    @FocusState private var isStandaloneInputFocused: Bool

    private static let appStoreURL = URL(string: "https://apps.apple.com/app/id6755408368")!

    private var trimmedStandaloneHold: String {
        standaloneHoldText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasStandaloneHold: Bool {
        !trimmedStandaloneHold.isEmpty
    }

    private var shouldShowStandaloneEditor: Bool {
        !hasMacPointerRecord && isEditingStandaloneTask
    }

    var body: some View {
        GeometryReader { geometry in
            let shouldIgnoreKeyboard = geometry.size.height >= geometry.size.width

            content
                .ignoresKeyboardSafeArea(shouldIgnoreKeyboard)
        }
    }

    private var content: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if hasMacPointerRecord {
                ReadOnlyCurrentTaskView(
                    rootTask: rootTask,
                    parentTask: parentTask,
                    currentTask: currentTask,
                    showEllipsis: showEllipsis,
                    siblingPosition: siblingPosition,
                    siblingTotal: siblingTotal
                )
            } else if shouldShowStandaloneEditor {
                StandaloneCursorInputView(
                    text: $standaloneDraftText,
                    isFocused: $isStandaloneInputFocused,
                    onSubmit: commitStandaloneDraft
                )
            } else if hasStandaloneHold {
                StandaloneHoldDisplayView(text: trimmedStandaloneHold) {
                    beginStandaloneEdit()
                }
            } else {
                StandalonePlaceholderView {
                    beginStandaloneEdit()
                }
            }

            if isMacConnectedConfirmationVisible {
                MacConnectionBadge(
                    dotColor: .green,
                    text: "mac connected"
                )
                    .padding(.top, 18)
                    .padding(.trailing, 18)
            } else if !hasMacPointerRecord {
                MacConnectionBadge(
                    dotColor: .red,
                    text: "mac not connected"
                ) {
                    isStandaloneInputFocused = false
                    isConnectionHelpPresented = true
                }
                    .padding(.top, 18)
                    .padding(.trailing, 18)
            }
        }
        .overlay {
            if isConnectionHelpPresented {
                MacConnectionHelpModal(appStoreURL: Self.appStoreURL) {
                    closeConnectionHelp()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !hasMacPointerRecord, !hasStandaloneHold, !isEditingStandaloneTask, !isConnectionHelpPresented else { return }
            beginStandaloneEdit()
        }
        .onAppear {
            logger.error("[VIEW] onAppear - starting init")
            UIApplication.shared.isIdleTimerDisabled = true
            setupCloudKitSubscription()
            fetchCurrentTask(trigger: .appear)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            fetchCurrentTask(trigger: .foregroundNotification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloudKitTaskUpdated"))) { _ in
            fetchCurrentTask(trigger: .push)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                fetchCurrentTask(trigger: .sceneActive)
            }
        }
        .onReceive(Timer.publish(every: foregroundPointerRefreshInterval, on: .main, in: .common).autoconnect()) { _ in
            guard scenePhase == .active else { return }
            fetchCurrentTask(trigger: .timer)
        }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
    }

    private func fetchCurrentTask(trigger: CurrentTaskFetchTrigger) {
        guard !isFetchingCurrentTask else {
            let shouldQueueRefresh = trigger == .push
            if shouldQueueRefresh {
                pendingFetchTrigger = trigger
            }
            LatencyDiagnostics.log("fetch skipped trigger=\(trigger.rawValue) queued=\(shouldQueueRefresh) reason=in-flight")
            return
        }

        isFetchingCurrentTask = true
        let fetchStartTime = Date()
        logger.error("[FETCH] fetchCurrentTask called trigger=\(trigger.rawValue, privacy: .public)")
        LatencyDiagnostics.log("fetch started trigger=\(trigger.rawValue) at=\(fetchStartTime)")

        CloudKitManager.shared.fetchCurrentTask { result in
            DispatchQueue.main.async {
                let fetchElapsed = Date().timeIntervalSince(fetchStartTime)
                self.isFetchingCurrentTask = false
                self.isLoading = false

                switch result {
                case .success(let pointer):
                    let hadResolvedConnectionState = self.hasResolvedInitialMacConnectionState
                    let wasMacConnected = self.hasMacPointerRecord

                    self.hasMacPointerRecord = pointer.recordExists
                    self.currentTask = pointer.text
                    self.parentTask = pointer.parentTaskText
                    self.rootTask = pointer.rootTaskText
                    self.showEllipsis = pointer.showEllipsis
                    self.siblingPosition = pointer.siblingPosition
                    self.siblingTotal = pointer.siblingCount
                    self.hasResolvedInitialMacConnectionState = true

                    if pointer.recordExists {
                        self.cancelStandaloneEditing()
                        self.isConnectionHelpPresented = false
                        if hadResolvedConnectionState && !wasMacConnected {
                            self.showMacConnectedConfirmation()
                        }
                    } else {
                        self.presentConnectionHelpIfNeeded()
                    }

                    let pointerAge = pointer.timestamp.map { Date().timeIntervalSince($0) }
                    let pointerAgeText = pointerAge.map { String(format: "%.2f", $0) } ?? "nil"
                    let fetchElapsedText = String(format: "%.2f", fetchElapsed)
                    let taskId = pointer.taskId ?? "nil"
                    let text = pointer.text ?? "nil"

                    logger.error("[FETCH] SUCCESS - recordExists=\(pointer.recordExists) taskId=\(taskId, privacy: .public)")
                    LatencyDiagnostics.log("trigger=\(trigger.rawValue) fetchElapsed=\(fetchElapsedText)s pointerAge=\(pointerAgeText)s recordExists=\(pointer.recordExists) taskId=\(taskId) text=\"\(text)\"")

                case .failure(let error):
                    self.hasMacPointerRecord = false
                    self.hasResolvedInitialMacConnectionState = true
                    self.presentConnectionHelpIfNeeded()
                    logger.error("[FETCH] FAILED - \(error.localizedDescription)")
                    LatencyDiagnostics.log("trigger=\(trigger.rawValue) fetchElapsed=\(String(format: "%.2f", fetchElapsed))s failed=\"\(error.localizedDescription)\"")
                }

                if let pendingFetchTrigger = self.pendingFetchTrigger {
                    self.pendingFetchTrigger = nil
                    LatencyDiagnostics.log("fetch queued trigger=\(pendingFetchTrigger.rawValue) starting-after=\(trigger.rawValue)")
                    self.fetchCurrentTask(trigger: pendingFetchTrigger)
                }
            }
        }
    }

    private func beginStandaloneEdit() {
        guard !hasMacPointerRecord else { return }
        standaloneDraftText = trimmedStandaloneHold
        isEditingStandaloneTask = true

        DispatchQueue.main.async {
            isStandaloneInputFocused = true
        }
    }

    private func cancelStandaloneEditing() {
        isEditingStandaloneTask = false
        standaloneDraftText = ""
        isStandaloneInputFocused = false
    }

    private func closeConnectionHelp() {
        hasShownMacConnectionHelpOnboarding = true
        isConnectionHelpPresented = false
    }

    private func presentConnectionHelpIfNeeded() {
        guard !hasShownMacConnectionHelpOnboarding,
              !isConnectionHelpPresented,
              !hasMacPointerRecord else {
            return
        }

        isStandaloneInputFocused = false
        isConnectionHelpPresented = true
        logger.error("[ONBOARDING] showing Mac connection help")
    }

    private func showMacConnectedConfirmation() {
        let token = UUID()
        macConnectedConfirmationToken = token
        isMacConnectedConfirmationVisible = true
        logger.error("[CONNECTION] showing mac connected confirmation")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard macConnectedConfirmationToken == token else { return }
            isMacConnectedConfirmationVisible = false
        }
    }

    private func commitStandaloneDraft() {
        guard !hasMacPointerRecord else {
            cancelStandaloneEditing()
            return
        }

        let trimmedText = standaloneDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            standaloneHoldText = ""
            cancelStandaloneEditing()
            return
        }

        standaloneHoldText = trimmedText
        isEditingStandaloneTask = false
        isStandaloneInputFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        logger.error("[STANDALONE] local hold saved")
    }

    private func setupCloudKitSubscription() {
        guard !isSettingUpCloudKitSubscription, !hasSetUpCloudKitSubscription else {
            logger.error("[SUB] setupCloudKitSubscription skipped - already configured")
            return
        }

        isSettingUpCloudKitSubscription = true
        logger.error("[SUB] setupCloudKitSubscription called")

        CloudKitManager.shared.subscribeToTaskChanges { error in
            DispatchQueue.main.async {
                self.isSettingUpCloudKitSubscription = false

                if let error {
                    logger.error("[SUB] failed - \(error.localizedDescription)")
                } else {
                    self.hasSetUpCloudKitSubscription = true
                    logger.error("[SUB] ready")
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func ignoresKeyboardSafeArea(_ shouldIgnore: Bool) -> some View {
        if shouldIgnore {
            self.ignoresSafeArea(.keyboard)
        } else {
            self
        }
    }
}

private struct MacConnectionBadge: View {
    let dotColor: Color
    let text: String
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Mac not connected. Setup instructions.")
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityLabel(text)
        }
    }

    private var content: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .contentShape(Capsule())
    }
}

private struct StandaloneCursorInputView: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        TextField("", text: $text)
            .focused(isFocused)
            .submitLabel(.done)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .multilineTextAlignment(.center)
            .font(.system(size: 52, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .tint(.white.opacity(0.84))
            .lineLimit(1)
            .contentShape(Rectangle())
            .onSubmit(onSubmit)
            .accessibilityLabel("Current hold")
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StandalonePlaceholderView: View {
    let onEdit: () -> Void

    var body: some View {
        Text(standalonePlaceholderText)
            .font(.system(size: 40, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.26))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
            .accessibilityLabel(standalonePlaceholderText)
    }
}

private struct StandaloneHoldDisplayView: View {
    let text: String
    let onEdit: () -> Void

    var body: some View {
        Text(text)
            .font(.system(size: 52, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .minimumScaleFactor(0.45)
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
            .accessibilityLabel(text)
    }
}

private struct MacConnectionHelpModal: View {
    let appStoreURL: URL
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let isCompactHeight = geometry.size.height < 520

            ZStack {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {}

                if isCompactHeight {
                    compactCard(availableSize: geometry.size)
                } else {
                    regularCard
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(10)
    }

    private var regularCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Connect your Mac")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("Hold is designed to capture tasks on your Mac and display them on your phone. Connect your Mac to complete the experience:")
                .font(.body)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            setupSteps(spacing: 16)

            shareLink(font: .headline)
        }
        .padding(.top, 48)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: 360)
        .background(cardBackground)
        .overlay(cardBorder)
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding(14)
        }
        .padding(.horizontal, 24)
        .contentShape(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    private func compactCard(availableSize: CGSize) -> some View {
        let horizontalMargin: CGFloat = 24
        let verticalMargin: CGFloat = 18
        let maxWidth = min(availableSize.width - horizontalMargin * 2, 560)
        let maxHeight = max(availableSize.height - verticalMargin * 2, 220)

        return VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Text("Connect your Mac")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack {
                    Spacer()
                    closeButton
                }
            }
            .frame(height: 34)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hold is designed to capture tasks on your Mac and display them on your phone. Connect your Mac to complete the experience:")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 18)

                    setupSteps(spacing: 20, isCompact: true)
                }
                .padding(.bottom, 2)
            }

            shareLink(font: .callout.weight(.semibold), maxWidth: 280)
        }
        .padding(.top, 14)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .background(cardBackground)
        .overlay(cardBorder)
        .padding(.horizontal, horizontalMargin)
        .padding(.vertical, verticalMargin)
        .contentShape(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    private func setupSteps(spacing: CGFloat, isCompact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            SetupStep(number: 1, text: "Open this link on your Mac (ensure it's signed into the same iCloud account as this iPhone).", isCompact: isCompact)
            SetupStep(number: 2, text: "Download Hold.", isCompact: isCompact)
            SetupStep(number: 3, text: "Enter a new task and watch it show up on your phone!", isCompact: isCompact)
        }
    }

    private func shareLink(font: Font, maxWidth: CGFloat? = nil) -> some View {
        ShareLink(item: appStoreURL) {
            Text("Share or Copy Link")
                .font(font)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: maxWidth ?? .infinity)
        .frame(maxWidth: .infinity)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(Color.white.opacity(0.16), lineWidth: 1)
    }
}

private struct SetupStep: View {
    let number: Int
    let text: String
    var isCompact: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: isCompact ? 10 : 12) {
            Text("\(number)")
                .font((isCompact ? Font.caption2 : Font.caption).weight(.bold))
                .foregroundStyle(.black)
                .frame(width: isCompact ? 20 : 22, height: isCompact ? 20 : 22)
                .background(Circle().fill(Color.white))

            Text(text)
                .font(isCompact ? .callout : .body)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ReadOnlyCurrentTaskView: View {
    let rootTask: String?
    let parentTask: String?
    let currentTask: String?
    let showEllipsis: Bool
    let siblingPosition: Int?
    let siblingTotal: Int?

    var body: some View {
        if currentTask == nil {
            Text("what are you holding?")
                .font(.largeTitle)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
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

                if let root = rootTask {
                    Text(root)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if showEllipsis {
                        Spacer().frame(height: 4)
                        Text("⋯")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer().frame(height: 0)
                    }

                    Spacer().frame(height: showEllipsis ? 0 : 10)
                }

                if let parent = parentTask {
                    Text(parent)
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 8)

                    Text("↓")
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))

                    Spacer().frame(height: 4)
                }

                if let current = currentTask {
                    Text(current)
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

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
