//
//  HoldApp_iOSApp.swift
//  HoldApp-iOS
//
//  Created by Vishal Jain on 04/11/2025.
//

import SwiftUI
import UserNotifications
import os
import CloudKit

private let logger = Logger(subsystem: "com.vishaljain.HoldApp", category: "iOS-AppDelegate")

@main
struct HoldApp_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// Handle CloudKit remote notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        logger.error("[LAUNCH] App starting")
        print("📱 [AppDelegate] App launched")

        // Request notification permission first
        requestNotificationPermission(application: application)

        // Check iCloud account status for debugging
        CKContainer.default().accountStatus { status, error in
            let statusStr: String
            switch status {
            case .available: statusStr = "available"
            case .noAccount: statusStr = "NO_ACCOUNT"
            case .restricted: statusStr = "restricted"
            case .couldNotDetermine: statusStr = "couldNotDetermine"
            case .temporarilyUnavailable: statusStr = "temporarilyUnavailable"
            @unknown default: statusStr = "unknown(\(status.rawValue))"
            }
            logger.error("[ICLOUD] Account status=\(statusStr) error=\(error?.localizedDescription ?? "none")")
        }

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
                logger.error("[NOTIF] Permission GRANTED")
                print("✅ [AppDelegate] Notification permission granted")
                print("📱 [AppDelegate] Registering for remote notifications...")

                // Must register on main thread
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                logger.error("[NOTIF] Permission DENIED by user")
                print("⚠️ [AppDelegate] Notification permission denied by user")
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        logger.error("[APNS] Token received - length=\(deviceToken.count)")
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ [AppDelegate] Successfully registered for remote notifications")
        print("📱 [AppDelegate] APNs device token: \(token)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("[APNS] Registration FAILED - \(error.localizedDescription)")
        print("❌ [AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
        print("❌ [AppDelegate] Error details: \(error)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.error("[PUSH] Remote notification received")
        print("📬 [AppDelegate] Remote notification received!")
        print("📬 [AppDelegate] Notification payload: \(userInfo)")
        print("📬 [AppDelegate] App state: \(application.applicationState.rawValue) (0=active, 1=inactive, 2=background)")

        // CloudKit notification received - refresh the display
        NotificationCenter.default.post(name: NSNotification.Name("CloudKitTaskUpdated"), object: nil)
        print("📬 [AppDelegate] Posted CloudKitTaskUpdated notification")

        completionHandler(.newData)
    }
}
