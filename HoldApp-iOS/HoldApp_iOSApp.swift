//
//  HoldApp_iOSApp.swift
//  HoldApp-iOS
//
//  Created by Vishal Jain on 04/11/2025.
//

import SwiftUI
import CloudKit
import os

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
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        LatencyDiagnostics.log("launch appState=\(applicationStateDescription(application.applicationState)) backgroundModes=\(backgroundModes.joined(separator: ","))")

        // Avoid touching CloudKit in didFinishLaunching; App Review's crash log
        // trapped inside CloudKit during this launch delegate path.
        DispatchQueue.main.async { [weak self] in
            self?.registerForRemoteNotifications(application: application)
        }
        logger.error("[ICLOUD] CloudKit sync starts after SwiftUI renders")

        // Check if launched from notification
        if let notification = launchOptions?[.remoteNotification] {
            print("📱 [AppDelegate] App launched from notification: \(notification)")
            LatencyDiagnostics.log("launch remoteNotification keys=\(remoteNotificationKeys(from: notification))")
        }

        return true
    }

    func registerForRemoteNotifications(application: UIApplication) {
        logger.error("[APNS] Registering for remote notifications")
        print("📱 [AppDelegate] Registering for silent CloudKit remote notifications...")
        LatencyDiagnostics.log("apns register requested appState=\(applicationStateDescription(application.applicationState))")
        application.registerForRemoteNotifications()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        logger.error("[APNS] Token received - length=\(deviceToken.count)")
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ [AppDelegate] Successfully registered for remote notifications")
        print("📱 [AppDelegate] APNs device token: \(token)")
        LatencyDiagnostics.log("apns token received length=\(deviceToken.count) prefix=\(String(token.prefix(12)))")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("[APNS] Registration FAILED - \(error.localizedDescription)")
        print("❌ [AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
        print("❌ [AppDelegate] Error details: \(error)")
        LatencyDiagnostics.log("apns registration failed error=\"\(error.localizedDescription)\"")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.error("[PUSH] Remote notification received")
        print("📬 [AppDelegate] Remote notification received!")
        print("📬 [AppDelegate] Notification payload: \(userInfo)")
        print("📬 [AppDelegate] App state: \(application.applicationState.rawValue) (0=active, 1=inactive, 2=background)")
        let cloudKitNotification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        let notificationType = cloudKitNotification.map { String(describing: $0.notificationType) } ?? "nil"
        let subscriptionID = cloudKitNotification?.subscriptionID ?? "nil"
        let keys = userInfo.keys.map { String(describing: $0) }.sorted().joined(separator: ",")
        LatencyDiagnostics.log("push received appState=\(applicationStateDescription(application.applicationState)) type=\(notificationType) subscriptionID=\(subscriptionID) keys=\(keys)")

        // CloudKit notification received - refresh the display
        NotificationCenter.default.post(name: NSNotification.Name("CloudKitTaskUpdated"), object: nil)
        print("📬 [AppDelegate] Posted CloudKitTaskUpdated notification")
        LatencyDiagnostics.log("push posted CloudKitTaskUpdated")

        completionHandler(.newData)
    }

    private func applicationStateDescription(_ state: UIApplication.State) -> String {
        switch state {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }

    private func remoteNotificationKeys(from notification: Any) -> String {
        guard let payload = notification as? [AnyHashable: Any] else {
            return "unreadable"
        }

        return payload.keys.map { String(describing: $0) }.sorted().joined(separator: ",")
    }
}
