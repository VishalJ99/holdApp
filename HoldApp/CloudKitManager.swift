import Foundation
import CloudKit

class CloudKitManager {
    static let shared = CloudKitManager()

    private let container: CKContainer
    private let database: CKDatabase

    private init() {
        container = CKContainer.default()
        database = container.privateCloudDatabase
    }

    // Save a task to CloudKit
    func saveTask(text: String, parentId: String? = nil, isCurrent: Bool = false, completion: @escaping (Result<CKRecord, Error>) -> Void) {
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
                completion(.success(savedRecord))
            }
        }
    }

    // Fetch the current task from pointer record (bypasses query index lag)
    func fetchCurrentTask(completion: @escaping (Result<String?, Error>) -> Void) {
        let fetchStartTime = Date()
        print("⏱️ [CloudKit] Starting fetch for current task at \(fetchStartTime)")

        // Fetch pointer by hardcoded ID (no query, no index lag!)
        let pointerID = CKRecord.ID(recordName: "CURRENT_TASK_POINTER")

        database.fetch(withRecordID: pointerID) { record, error in
            let fetchTime = Date().timeIntervalSince(fetchStartTime)

            if let record = record {
                let text = record["currentTaskText"] as? String
                print("✅ [CloudKit] Current task fetched in \(String(format: "%.2f", fetchTime))s: \(text ?? "nil")")
                print("📝 [CloudKit] Fetched from pointer (instant, no index lag)")
                completion(.success(text))
            } else if let fetchError = error as? CKError, fetchError.code == .unknownItem {
                // Pointer doesn't exist yet (no current task set)
                print("ℹ️ [CloudKit] Fetch completed in \(String(format: "%.2f", fetchTime))s: No current task pointer found")
                completion(.success(nil))
            } else {
                // Unexpected error
                print("❌ [CloudKit] Fetch failed after \(String(format: "%.2f", fetchTime))s: \(error?.localizedDescription ?? "unknown")")
                completion(.failure(error ?? NSError(domain: "CloudKitManager", code: -1, userInfo: nil)))
            }
        }
    }

    // Update the current task pointer record (bypasses query index lag)
    func updateCurrentTaskPointer(text: String, completion: @escaping (Error?) -> Void) {
        let pointerStartTime = Date()
        print("🎯 [CloudKit] Updating current task pointer at \(pointerStartTime)")

        // Use hardcoded record ID so both macOS and iPhone know where to look
        let pointerID = CKRecord.ID(recordName: "CURRENT_TASK_POINTER")

        // Try to fetch existing pointer record
        database.fetch(withRecordID: pointerID) { [weak self] record, error in
            guard let self = self else { return }

            if let existingRecord = record {
                // Pointer exists - update it
                print("📝 [CloudKit] Found existing pointer, updating...")
                existingRecord["currentTaskText"] = text as CKRecordValue
                existingRecord["timestamp"] = Date() as CKRecordValue

                self.database.save(existingRecord) { savedRecord, saveError in
                    let pointerTime = Date().timeIntervalSince(pointerStartTime)
                    if let saveError = saveError {
                        print("❌ [CloudKit] Pointer update failed after \(String(format: "%.2f", pointerTime))s: \(saveError.localizedDescription)")
                        completion(saveError)
                    } else {
                        print("✅ [CloudKit] Pointer updated in \(String(format: "%.2f", pointerTime))s: \(text)")
                        completion(nil)
                    }
                }
            } else if let fetchError = error as? CKError, fetchError.code == .unknownItem {
                // Pointer doesn't exist - create it
                print("📝 [CloudKit] Pointer doesn't exist, creating new one...")
                let newRecord = CKRecord(recordType: "CurrentTaskPointer", recordID: pointerID)
                newRecord["currentTaskText"] = text as CKRecordValue
                newRecord["timestamp"] = Date() as CKRecordValue

                self.database.save(newRecord) { savedRecord, saveError in
                    let pointerTime = Date().timeIntervalSince(pointerStartTime)
                    if let saveError = saveError {
                        print("❌ [CloudKit] Pointer creation failed after \(String(format: "%.2f", pointerTime))s: \(saveError.localizedDescription)")
                        completion(saveError)
                    } else {
                        print("✅ [CloudKit] Pointer created in \(String(format: "%.2f", pointerTime))s: \(text)")
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

    // Subscribe to task changes (for real-time updates on iPhone)
    func subscribeToTaskChanges(completion: @escaping (Error?) -> Void) {
        print("🔔 [CloudKit] Setting up subscription...")

        let subscription = CKQuerySubscription(
            recordType: "Task",
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )

        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        subscription.notificationInfo = notification

        print("🔔 [CloudKit] Subscription configured - fires on: creation, update")
        print("🔔 [CloudKit] Silent notification: \(notification.shouldSendContentAvailable)")

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
