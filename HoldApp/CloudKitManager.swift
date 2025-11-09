import Foundation
import CloudKit

class CloudKitManager {
    static let shared = CloudKitManager()

    private let container: CKContainer
    private let database: CKDatabase

    private init() {
        container = CKContainer.default()
        database = container.publicCloudDatabase
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

    // Fetch the current task (marked with isCurrent = true)
    func fetchCurrentTask(completion: @escaping (Result<String?, Error>) -> Void) {
        let fetchStartTime = Date()
        print("⏱️ [CloudKit] Starting fetch for current task at \(fetchStartTime)")

        // Query for tasks marked as current
        let predicate = NSPredicate(format: "isCurrent == %@", NSNumber(value: true))
        let query = CKQuery(recordType: "Task", predicate: predicate)
        // Sort by timestamp descending to get the most recent current task
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        database.perform(query, inZoneWith: nil) { records, error in
            let fetchTime = Date().timeIntervalSince(fetchStartTime)
            if let error = error {
                print("❌ [CloudKit] Fetch failed after \(String(format: "%.2f", fetchTime))s: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let record = records?.first {
                let text = record["text"] as? String
                print("✅ [CloudKit] Current task fetched in \(String(format: "%.2f", fetchTime))s: \(text ?? "nil")")
                print("📝 [CloudKit] Record ID: \(record.recordID.recordName)")
                completion(.success(text))
            } else {
                print("ℹ️ [CloudKit] Fetch completed in \(String(format: "%.2f", fetchTime))s: No current task set")
                completion(.success(nil)) // No current task
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
