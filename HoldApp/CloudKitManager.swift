import Foundation
import CloudKit

class CloudKitManager {
    static let shared = CloudKitManager()

    private let container: CKContainer
    private let database: CKDatabase

    private init() {
        container = CKContainer.default()
        database = container.privateCloudDatabase

        // Log CloudKit configuration
        print("☁️ [CloudKit] Initialized")
        print("📦 [CloudKit] Container: \(container.containerIdentifier ?? "unknown")")
        print("🌍 [CloudKit] Database: Private")

        // Detect environment from entitlements (production vs development)
        #if DEBUG
        if let path = Bundle.main.path(forResource: "HoldApp", ofType: "entitlements"),
           let entitlements = NSDictionary(contentsOfFile: path),
           let apsEnv = entitlements["com.apple.developer.aps-environment"] as? String {
            let emoji = apsEnv == "production" ? "🔴" : "🔵"
            print("\(emoji) [CloudKit] Environment: \(apsEnv.uppercased())")
        }
        #endif
    }

    // MARK: - CurrentTaskPointer Operations (iPhone Sync)

    // Fetch the current task from pointer record (bypasses query index lag)
    // Returns all display info: task texts, hierarchy info, sibling info
    func fetchCurrentTask(completion: @escaping (Result<(
        taskId: String?,
        text: String?,
        parentId: String?,
        rootId: String?,
        parentTaskText: String?,
        rootTaskText: String?,
        showEllipsis: Bool,
        siblingPosition: Int?,
        siblingCount: Int?
    ), Error>) -> Void) {
        let fetchStartTime = Date()
        print("⏱️ [CloudKit] Starting fetch for current task at \(fetchStartTime)")

        // Fetch pointer by hardcoded ID (no query, no index lag!)
        let pointerID = CKRecord.ID(recordName: "CURRENT_TASK_POINTER")

        database.fetch(withRecordID: pointerID) { record, error in
            let fetchTime = Date().timeIntervalSince(fetchStartTime)

            if let record = record {
                let taskId = record["currentTaskId"] as? String
                let text = record["currentTaskText"] as? String
                let parentId = record["parentId"] as? String
                let rootId = record["rootId"] as? String
                let parentTaskText = record["parentTaskText"] as? String
                let rootTaskText = record["rootTaskText"] as? String
                let showEllipsis = (record["showEllipsis"] as? Int == 1) // CloudKit stores Bool as Int
                let siblingPosition = record["siblingPosition"] as? Int
                let siblingCount = record["siblingCount"] as? Int

                print("✅ [CloudKit] Current task fetched in \(String(format: "%.2f", fetchTime))s")
                print("📝 [CloudKit] Fetched from pointer (instant, no index lag)")
                print("🔗 [Fetch Summary] text=\"\(text ?? "nil")\" | taskId=\(taskId ?? "nil") | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")
                print("📊 [Sibling Info] position=\(siblingPosition?.description ?? "nil")/\(siblingCount?.description ?? "nil") | ellipsis=\(showEllipsis)")
                completion(.success((
                    taskId: taskId,
                    text: text,
                    parentId: parentId,
                    rootId: rootId,
                    parentTaskText: parentTaskText,
                    rootTaskText: rootTaskText,
                    showEllipsis: showEllipsis,
                    siblingPosition: siblingPosition,
                    siblingCount: siblingCount
                )))
            } else if let fetchError = error as? CKError, fetchError.code == .unknownItem {
                // Pointer doesn't exist yet (no current task set)
                print("ℹ️ [CloudKit] Fetch completed in \(String(format: "%.2f", fetchTime))s: No current task pointer found")
                completion(.success((
                    taskId: nil,
                    text: nil,
                    parentId: nil,
                    rootId: nil,
                    parentTaskText: nil,
                    rootTaskText: nil,
                    showEllipsis: false,
                    siblingPosition: nil,
                    siblingCount: nil
                )))
            } else {
                // Unexpected error
                print("❌ [CloudKit] Fetch failed after \(String(format: "%.2f", fetchTime))s: \(error?.localizedDescription ?? "unknown")")
                completion(.failure(error ?? NSError(domain: "CloudKitManager", code: -1, userInfo: nil)))
            }
        }
    }

    // Update the current task pointer record (bypasses query index lag)
    func updateCurrentTaskPointer(
        taskId: String,
        text: String,
        parentId: String?,
        rootId: String?,
        parentTaskText: String?,
        rootTaskText: String?,
        showEllipsis: Bool,
        siblingPosition: Int?,
        siblingCount: Int?,
        completion: @escaping (Error?) -> Void
    ) {
        let pointerStartTime = Date()
        print("🎯 [CloudKit] Updating current task pointer at \(pointerStartTime)")
        print("🔗 [Pointer Update] taskId=\(taskId) | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")
        print("📊 [Sibling Update] position=\(siblingPosition?.description ?? "nil")/\(siblingCount?.description ?? "nil") | ellipsis=\(showEllipsis)")

        // Use hardcoded record ID so both macOS and iPhone know where to look
        let pointerID = CKRecord.ID(recordName: "CURRENT_TASK_POINTER")

        // Try to fetch existing pointer record
        database.fetch(withRecordID: pointerID) { [weak self] record, error in
            guard let self = self else { return }

            if let existingRecord = record {
                // Pointer exists - update it
                print("📝 [CloudKit] Found existing pointer, updating...")
                existingRecord["currentTaskId"] = taskId as CKRecordValue
                existingRecord["currentTaskText"] = text as CKRecordValue
                existingRecord["parentId"] = parentId as CKRecordValue?
                existingRecord["rootId"] = rootId as CKRecordValue?
                existingRecord["parentTaskText"] = parentTaskText as CKRecordValue?
                existingRecord["rootTaskText"] = rootTaskText as CKRecordValue?
                existingRecord["showEllipsis"] = (showEllipsis ? 1 : 0) as CKRecordValue
                existingRecord["siblingPosition"] = siblingPosition as CKRecordValue?
                existingRecord["siblingCount"] = siblingCount as CKRecordValue?
                existingRecord["timestamp"] = Date() as CKRecordValue

                self.database.save(existingRecord) { savedRecord, saveError in
                    let pointerTime = Date().timeIntervalSince(pointerStartTime)
                    if let saveError = saveError {
                        print("❌ [CloudKit] Pointer update failed after \(String(format: "%.2f", pointerTime))s: \(saveError.localizedDescription)")
                        completion(saveError)
                    } else {
                        print("✅ [CloudKit] Pointer updated in \(String(format: "%.2f", pointerTime))s")
                        print("🔗 [Pointer Summary] text=\"\(text)\" | taskId=\(taskId) | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")
                        completion(nil)
                    }
                }
            } else if let fetchError = error as? CKError, fetchError.code == .unknownItem {
                // Pointer doesn't exist - create it
                print("📝 [CloudKit] Pointer doesn't exist, creating new one...")
                let newRecord = CKRecord(recordType: "CurrentTaskPointer", recordID: pointerID)
                newRecord["currentTaskId"] = taskId as CKRecordValue
                newRecord["currentTaskText"] = text as CKRecordValue
                newRecord["parentId"] = parentId as CKRecordValue?
                newRecord["rootId"] = rootId as CKRecordValue?
                newRecord["parentTaskText"] = parentTaskText as CKRecordValue?
                newRecord["rootTaskText"] = rootTaskText as CKRecordValue?
                newRecord["showEllipsis"] = (showEllipsis ? 1 : 0) as CKRecordValue
                newRecord["siblingPosition"] = siblingPosition as CKRecordValue?
                newRecord["siblingCount"] = siblingCount as CKRecordValue?
                newRecord["timestamp"] = Date() as CKRecordValue

                self.database.save(newRecord) { savedRecord, saveError in
                    let pointerTime = Date().timeIntervalSince(pointerStartTime)
                    if let saveError = saveError {
                        print("❌ [CloudKit] Pointer creation failed after \(String(format: "%.2f", pointerTime))s: \(saveError.localizedDescription)")
                        completion(saveError)
                    } else {
                        print("✅ [CloudKit] Pointer created in \(String(format: "%.2f", pointerTime))s")
                        print("🔗 [Pointer Summary] text=\"\(text)\" | taskId=\(taskId) | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")
                        completion(nil)
                    }
                }
            } else {
                // Unexpected error
                let pointerTime = Date().timeIntervalSince(pointerStartTime)
                print("❌ [CloudKit] Pointer fetch error after \(String(format: "%.2f", pointerTime))s: \(error?.localizedDescription ?? "unknown")")
                completion(error)
            }
        }
    }

    // Clear the current task pointer (for empty state or startup sync)
    func clearCurrentTaskPointer(completion: @escaping (Error?) -> Void) {
        let clearStartTime = Date()
        print("🗑️ [CloudKit] Clearing CurrentTaskPointer at \(clearStartTime)")

        let pointerID = CKRecord.ID(recordName: "CURRENT_TASK_POINTER")

        // Fetch existing pointer first (same pattern as updateCurrentTaskPointer)
        database.fetch(withRecordID: pointerID) { [weak self] record, error in
            guard let self = self else { return }

            if let existingRecord = record {
                // Pointer exists - clear all fields
                print("📝 [CloudKit] Found existing pointer, clearing fields...")
                existingRecord["currentTaskId"] = nil as String?
                existingRecord["currentTaskText"] = nil as String?
                existingRecord["parentId"] = nil as String?
                existingRecord["rootId"] = nil as String?
                existingRecord["parentTaskText"] = nil as String?
                existingRecord["rootTaskText"] = nil as String?
                existingRecord["showEllipsis"] = false
                existingRecord["siblingPosition"] = nil as Int?
                existingRecord["siblingCount"] = nil as Int?
                existingRecord["timestamp"] = Date() as CKRecordValue

                self.database.save(existingRecord) { savedRecord, saveError in
                    let clearTime = Date().timeIntervalSince(clearStartTime)
                    if let saveError = saveError {
                        print("❌ [CloudKit] Clear pointer failed after \(String(format: "%.2f", clearTime))s: \(saveError.localizedDescription)")
                        completion(saveError)
                    } else {
                        print("✅ [CloudKit] CurrentTaskPointer cleared in \(String(format: "%.2f", clearTime))s")
                        print("📱 [CloudKit] iPhone will now show 'No current task'")
                        completion(nil)
                    }
                }
            } else if let fetchError = error as? CKError, fetchError.code == .unknownItem {
                // Pointer doesn't exist - nothing to clear
                let clearTime = Date().timeIntervalSince(clearStartTime)
                print("ℹ️ [CloudKit] Pointer doesn't exist, nothing to clear (completed in \(String(format: "%.2f", clearTime))s)")
                completion(nil)
            } else {
                // Unexpected error
                let clearTime = Date().timeIntervalSince(clearStartTime)
                print("❌ [CloudKit] Pointer fetch error after \(String(format: "%.2f", clearTime))s: \(error?.localizedDescription ?? "unknown")")
                completion(error)
            }
        }
    }

    // Subscribe to current task pointer changes (for real-time updates on iPhone)
    func subscribeToTaskChanges(completion: @escaping (Error?) -> Void) {
        print("🔔 [CloudKit] Setting up subscription...")

        let subscription = CKQuerySubscription(
            recordType: "CurrentTaskPointer",
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )

        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        subscription.notificationInfo = notification

        print("🔔 [CloudKit] Subscription configured for CurrentTaskPointer - fires on: creation, update")
        print("🔔 [CloudKit] Silent notification: \(notification.shouldSendContentAvailable)")
        print("🎯 [CloudKit] This eliminates race condition: notification only fires AFTER pointer update")

        database.save(subscription) { savedSubscription, error in
            if let error = error {
                print("❌ [CloudKit] Subscription failed: \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    print("❌ [CloudKit] CKError code: \(ckError.errorCode)")
                    print("❌ [CloudKit] CKError description: \(ckError)")
                }
                completion(error)
            } else if let savedSubscription = savedSubscription {
                print("✅ [CloudKit] Subscription created successfully!")
                print("📝 [CloudKit] Subscription ID: \(savedSubscription.subscriptionID)")
                completion(nil)
            }
        }
    }
}
