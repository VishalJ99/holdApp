//
//  ContentView.swift
//  HoldApp-iOS
//
//  Created by Vishal Jain on 04/11/2025.
//

import SwiftUI
import CloudKit

struct ContentView: View {
    @State private var currentTask: String = ""
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if currentTask.isEmpty {
                Text("No current task")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            } else {
                Text(currentTask)
                    .font(.system(size: 48, weight: .regular))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(40)
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

        CloudKitManager.shared.fetchCurrentTask { result in
            let totalTime = Date().timeIntervalSince(fetchRequestTime)

            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let text):
                    print("✅ [ContentView] UI updated in \(String(format: "%.2f", totalTime))s")
                    print("📲 [ContentView] Displaying: \(text ?? "empty")")
                    currentTask = text ?? ""
                case .failure(let error):
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

#Preview {
    ContentView()
}
