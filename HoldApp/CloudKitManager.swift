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

    // Save a task to CloudKit
    func saveTask(text: String, parentId: String? = nil, rootId: String? = nil, isCurrent: Bool = false, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let saveStartTime = Date()
        print("⏱️ [CloudKit] Starting save at \(saveStartTime)")

        let record = CKRecord(recordType: "Task")
        record["text"] = text as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue
        record["isCompleted"] = false as CKRecordValue
        record["isCurrent"] = isCurrent as CKRecordValue

        // Add parent_id if provided
        if let parentId = parentId {
            record["parent_id"] = parentId as CKRecordValue
            print("🔗 [CloudKit] Task has parent: \(parentId)")
        } else {
            print("🌳 [CloudKit] Task is top-level (no parent)")
        }

        // Add root_id if provided
        if let rootId = rootId {
            record["root_id"] = rootId as CKRecordValue
            print("🌲 [CloudKit] Task has root: \(rootId)")
        } else {
            print("🌲 [CloudKit] Task root_id: nil (is root or legacy)")
        }

        // Log if this is the current task
        if isCurrent {
            print("⭐ [CloudKit] Task marked as CURRENT (will display on iPhone)")
        }

        database.save(record) { savedRecord, error in
            let saveTime = Date().timeIntervalSince(saveStartTime)
            if let error = error {
                print("❌ [CloudKit] Save failed after \(String(format: "%.2f", saveTime))s: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let savedRecord = savedRecord {
                print("✅ [CloudKit] Task saved in \(String(format: "%.2f", saveTime))s: \(text)")
                print("📝 [CloudKit] Record ID: \(savedRecord.recordID.recordName)")
                print("☁️ [CloudKit Save Summary] text=\"\(text)\" | parent_id=\(parentId ?? "nil") | root_id=\(rootId ?? "nil")")
                completion(.success(savedRecord))
            }
        }
    }

    // Fetch a specific task by ID
    func fetchTaskById(_ id: String, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let fetchStartTime = Date()
        print("🔍 [CloudKit] Fetching task by ID: \(id)")

        let recordID = CKRecord.ID(recordName: id)

        database.fetch(withRecordID: recordID) { record, error in
            let fetchTime = Date().timeIntervalSince(fetchStartTime)

            if let error = error {
                print("❌ [CloudKit] Fetch by ID failed after \(String(format: "%.2f", fetchTime))s: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let record = record {
                let text = record["text"] as? String ?? "unknown"
                let parentId = record["parent_id"] as? String
                let rootId = record["root_id"] as? String
                print("✅ [CloudKit] Task fetched in \(String(format: "%.2f", fetchTime))s")
                print("📝 [CloudKit] text=\"\(text)\" | parent_id=\(parentId ?? "nil") | root_id=\(rootId ?? "nil")")
                completion(.success(record))
            }
        }
    }

    // Fetch the current task from pointer record (bypasses query index lag)
    // Returns: (taskId, text, parentId, rootId)
    func fetchCurrentTask(completion: @escaping (Result<(taskId: String?, text: String?, parentId: String?, rootId: String?), Error>) -> Void) {
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

                print("✅ [CloudKit] Current task fetched in \(String(format: "%.2f", fetchTime))s")
                print("📝 [CloudKit] Fetched from pointer (instant, no index lag)")
                print("🔗 [Fetch Summary] text=\"\(text ?? "nil")\" | taskId=\(taskId ?? "nil") | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")
                completion(.success((taskId: taskId, text: text, parentId: parentId, rootId: rootId)))
            } else if let fetchError = error as? CKError, fetchError.code == .unknownItem {
                // Pointer doesn't exist yet (no current task set)
                print("ℹ️ [CloudKit] Fetch completed in \(String(format: "%.2f", fetchTime))s: No current task pointer found")
                completion(.success((taskId: nil, text: nil, parentId: nil, rootId: nil)))
            } else {
                // Unexpected error
                print("❌ [CloudKit] Fetch failed after \(String(format: "%.2f", fetchTime))s: \(error?.localizedDescription ?? "unknown")")
                completion(.failure(error ?? NSError(domain: "CloudKitManager", code: -1, userInfo: nil)))
            }
        }
    }

    // Update the current task pointer record (bypasses query index lag)
    func updateCurrentTaskPointer(taskId: String, text: String, parentId: String?, rootId: String?, completion: @escaping (Error?) -> Void) {
        let pointerStartTime = Date()
        print("🎯 [CloudKit] Updating current task pointer at \(pointerStartTime)")
        print("🔗 [Pointer Update] taskId=\(taskId) | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")

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
