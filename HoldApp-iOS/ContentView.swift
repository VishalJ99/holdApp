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
    @State private var siblingPosition: Int?
    @State private var siblingTotal: Int?
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
                    showEllipsis: showEllipsis,
                    siblingPosition: siblingPosition,
                    siblingTotal: siblingTotal
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

                    print("✅ [ContentView] UI updated in \(String(format: "%.2f", totalTime))s")
                    print("📲 [ContentView] Hierarchy:")
                    print("   Root: \(rootText ?? "nil")")
                    print("   Ellipsis: \(showEllipsis ? "YES" : "NO")")
                    print("   Parent: \(parentText ?? "nil")")
                    print("   Current: \(currentText ?? "nil")")
                    print("📊 [ContentView] Siblings: \(siblingPos?.description ?? "nil")/\(siblingCnt?.description ?? "nil")")
                }

            case .failure(let error):
                let totalTime = Date().timeIntervalSince(fetchRequestTime)
                DispatchQueue.main.async {
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

                // SIBLING INDICATOR (only if has siblings)
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
