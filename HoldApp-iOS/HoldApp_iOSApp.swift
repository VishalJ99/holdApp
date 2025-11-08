//
//  HoldApp_iOSApp.swift
//  HoldApp-iOS
//
//  Created by Vishal Jain on 04/11/2025.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct HoldApp_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // SwiftData container with CloudKit sync
    var modelContainer: ModelContainer = {
        do {
            let schema = Schema([Task.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.vishaljain.HoldApp")
            )
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("✅ [iOS] SwiftData + CloudKit initialized (private database)")
            return container
        } catch {
            fatalError("Failed to initialize SwiftData: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

// Handle CloudKit remote notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("📱 [AppDelegate] App launched")

        // Request notification permission first
        requestNotificationPermission(application: application)

        // Check if launched from notification
        if let notification = launchOptions?[.remoteNotification] {
            print("📱 [AppDelegate] App launched from notification: \(notification)")
        }

        return true
    }

    func requestNotificationPermission(application: UIApplication) {
        print("🔔 [AppDelegate] Requesting notification permission...")

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ [AppDelegate] Permission request error: \(error.localizedDescription)")
                return
            }

            if granted {
                print("✅ [AppDelegate] Notification permission granted")
                print("📱 [AppDelegate] Registering for remote notifications...")

                // Must register on main thread
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ [AppDelegate] Notification permission denied by user")
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ [AppDelegate] Successfully registered for remote notifications")
        print("📱 [AppDelegate] APNs device token: \(token)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ [AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
        print("❌ [AppDelegate] Error details: \(error)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📬 [AppDelegate] Remote notification received!")
        print("📬 [AppDelegate] Notification payload: \(userInfo)")
        print("📬 [AppDelegate] App state: \(application.applicationState.rawValue) (0=active, 1=inactive, 2=background)")

        // CloudKit notification received - refresh the display
        NotificationCenter.default.post(name: NSNotification.Name("CloudKitTaskUpdated"), object: nil)
        print("📬 [AppDelegate] Posted CloudKitTaskUpdated notification")

        completionHandler(.newData)
    }
}
