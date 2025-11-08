//
//  ContentView.swift
//  HoldApp-iOS
//
//  Created by Vishal Jain on 04/11/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // Query for current task using SwiftData
    @Query(filter: #Predicate<Task> { $0.isCurrent == true })
    private var currentTasks: [Task]

    // Legacy support - keep listening to old CloudKit notifications
    @State private var legacyTask: String = ""
    @State private var useLegacy: Bool = false

    var currentTask: Task? {
        currentTasks.first
    }

    var displayText: String {
        if let task = currentTask {
            return task.text
        } else if useLegacy && !legacyTask.isEmpty {
            return legacyTask + " (legacy)"
        } else {
            return ""
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if displayText.isEmpty {
                VStack(spacing: 20) {
                    Text("No current task")
                        .font(.system(size: 48, weight: .regular))
                        .foregroundColor(.gray)

                    Text("Create a task on Mac")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.6))
                }
            } else {
                VStack(spacing: 20) {
                    Text(displayText)
                        .font(.system(size: 48, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(40)

                    if let task = currentTask {
                        // Show task metadata (for debugging Phase 0)
                        Text("Created: \(task.createdAt.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .onAppear {
            print("📲 [ContentView] View appeared")
            print("📲 [ContentView] Current tasks count: \(currentTasks.count)")
            if let task = currentTask {
                print("📲 [ContentView] Displaying current task: \"\(task.text)\"")
            } else {
                print("📲 [ContentView] No current task found")
            }

            // Keep legacy CloudKit support for now
            setupLegacyCloudKitSubscription()
        }
        .onChange(of: currentTasks) { oldValue, newValue in
            print("📲 [ContentView] Current tasks changed!")
            print("📲 [ContentView] Old count: \(oldValue.count), New count: \(newValue.count)")
            if let task = newValue.first {
                print("📲 [ContentView] New current task: \"\(task.text)\"")
            }
        }
    }

    // Legacy support - will be removed after Phase 0 testing
    func setupLegacyCloudKitSubscription() {
        print("🔔 [ContentView] Setting up legacy CloudKit subscription...")

        // Subscribe to task changes
        CloudKitManager.shared.subscribeToTaskChanges { error in
            if let error = error {
                print("❌ [ContentView] Legacy subscription setup failed: \(error)")
            } else {
                print("✅ [ContentView] Legacy subscription setup completed")
            }
        }

        // Listen for legacy CloudKit notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudKitTaskUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            print("🔔 [ContentView] Received legacy CloudKitTaskUpdated notification")
            // Fetch legacy task as fallback
            CloudKitManager.shared.fetchCurrentTask { result in
                switch result {
                case .success(let text):
                    if let text = text {
                        legacyTask = text
                        useLegacy = true
                        print("📲 [ContentView] Legacy task: \(text)")
                    }
                case .failure(let error):
                    print("❌ [ContentView] Legacy fetch error: \(error)")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
