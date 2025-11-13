//
//  ContentView.swift
//  HoldApp-iOS
//
//  Created by Vishal Jain on 04/11/2025.
//

import SwiftUI
import CloudKit

struct ContentView: View {
    // Hierarchy display state
    @State private var rootTask: String?
    @State private var parentTask: String?
    @State private var currentTask: String?
    @State private var showEllipsis: Bool = false
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if currentTask == nil {
                Text("No current task")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            } else {
                // Centered hierarchy display with max contrast
                HierarchyView_MaxContrast(
                    rootTask: rootTask,
                    parentTask: parentTask,
                    currentTask: currentTask,
                    showEllipsis: showEllipsis
                )
            }
        }
        .onAppear {
            print("📲 [ContentView] View appeared - initializing...")

            // Keep screen on while displaying task (like YouTube)
            UIApplication.shared.isIdleTimerDisabled = true
            print("📲 [ContentView] Screen auto-lock disabled")

            setupCloudKitSubscription()
            fetchCurrentTask()
        }
    }

    func fetchCurrentTask() {
        let fetchRequestTime = Date()
        print("📲 [ContentView] Fetch requested at \(fetchRequestTime)")

        // Step 1: Fetch pointer to get IDs
        CloudKitManager.shared.fetchCurrentTask { result in
            switch result {
            case .success(let taskData):
                print("📲 [ContentView] Pointer fetched: taskId=\(taskData.taskId ?? "nil") | parentId=\(taskData.parentId ?? "nil") | rootId=\(taskData.rootId ?? "nil")")

                // We already have current task text from pointer
                let currentText = taskData.text
                let parentId = taskData.parentId
                let rootId = taskData.rootId

                // Dispatch group to coordinate parallel fetches
                let fetchGroup = DispatchGroup()
                var fetchedParent: String?
                var fetchedRoot: String?
                var shouldShowEllipsis = false

                // Step 2: Fetch parent task if parentId exists
                if let parentId = parentId {
                    fetchGroup.enter()
                    print("🔍 [ContentView] Fetching parent task: \(parentId)")
                    CloudKitManager.shared.fetchTaskById(parentId) { parentResult in
                        switch parentResult {
                        case .success(let parentRecord):
                            fetchedParent = parentRecord["text"] as? String
                            let parentOfParent = parentRecord["parent_id"] as? String

                            // Check if we need ellipsis: parent is not a direct child of root
                            if let parentOfParent = parentOfParent, let rootId = rootId, parentOfParent != rootId {
                                shouldShowEllipsis = true
                                print("🔹 [ContentView] Ellipsis needed: parent.parent_id(\(parentOfParent)) ≠ rootId(\(rootId))")
                            }

                            print("✅ [ContentView] Parent fetched: \(fetchedParent ?? "nil") | parent.parent_id: \(parentOfParent ?? "nil")")
                        case .failure(let error):
                            print("❌ [ContentView] Parent fetch failed: \(error.localizedDescription)")
                        }
                        fetchGroup.leave()
                    }
                }

                // Step 3: Fetch root task if rootId exists AND is different from parentId
                if let rootId = rootId, rootId != parentId {
                    fetchGroup.enter()
                    print("🔍 [ContentView] Fetching root task: \(rootId)")
                    CloudKitManager.shared.fetchTaskById(rootId) { rootResult in
                        switch rootResult {
                        case .success(let rootRecord):
                            fetchedRoot = rootRecord["text"] as? String
                            print("✅ [ContentView] Root fetched: \(fetchedRoot ?? "nil")")
                        case .failure(let error):
                            print("❌ [ContentView] Root fetch failed: \(error.localizedDescription)")
                        }
                        fetchGroup.leave()
                    }
                }

                // Step 4: Update UI when all fetches complete
                fetchGroup.notify(queue: .main) {
                    let totalTime = Date().timeIntervalSince(fetchRequestTime)
                    self.isLoading = false
                    self.currentTask = currentText
                    self.parentTask = fetchedParent
                    self.rootTask = fetchedRoot
                    self.showEllipsis = shouldShowEllipsis

                    print("✅ [ContentView] UI updated in \(String(format: "%.2f", totalTime))s")
                    print("📲 [ContentView] Hierarchy:")
                    print("   Root: \(fetchedRoot ?? "nil")")
                    print("   Ellipsis: \(shouldShowEllipsis ? "YES" : "NO")")
                    print("   Parent: \(fetchedParent ?? "nil")")
                    print("   Current: \(currentText ?? "nil")")
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    let totalTime = Date().timeIntervalSince(fetchRequestTime)
                    self.isLoading = false
                    print("❌ [ContentView] Error fetching task after \(String(format: "%.2f", totalTime))s: \(error)")
                }
            }
        }
    }

    func setupCloudKitSubscription() {
        print("🔔 [ContentView] Setting up CloudKit subscription and notification observer...")

        // Subscribe to task changes
        CloudKitManager.shared.subscribeToTaskChanges { error in
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

struct HierarchyView_MaxContrast: View {
    let rootTask: String?
    let parentTask: String?
    let currentTask: String?
    let showEllipsis: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 2) {
                Spacer().frame(height: 20)

                // ROOT SECTION (only if level 3+)
                if let root = rootTask {
                    Text(root)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    // ELLIPSIS (only if level 4+)
                    if showEllipsis {
                        Text("···")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.60))
                            .padding(.vertical, 2)
                    }

                    // Arrow after root (only shown when root exists)
                    Text("↓")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))

                    Spacer().frame(height: 4)
                }

                // PARENT SECTION (only if level 2+)
                if let parent = parentTask {
                    Text(parent)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.80))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 12)
                }

                // CURRENT TASK (always shown if exists)
                if let current = currentTask {
                    Text(current)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    ContentView()
}
