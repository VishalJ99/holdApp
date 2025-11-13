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

    // Fetch all siblings of a given parent (for sibling selection UI)
    func fetchSiblings(parentId: String, completion: @escaping (Result<[(id: String, text: String, timestamp: Date)], Error>) -> Void) {
        let fetchStartTime = Date()
        print("👥 [CloudKit] Fetching siblings with parentId: \(parentId)")

        // Query for all tasks with matching parent_id
        let predicate = NSPredicate(format: "parent_id == %@", parentId)
        let query = CKQuery(recordType: "Task", predicate: predicate)

        // Sort by creation time for stable ordering
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        database.perform(query, inZoneWith: nil) { records, error in
            let fetchTime = Date().timeIntervalSince(fetchStartTime)

            if let error = error {
                print("❌ [CloudKit] Sibling fetch failed after \(String(format: "%.2f", fetchTime))s: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let records = records {
                let siblings = records.compactMap { record -> (id: String, text: String, timestamp: Date)? in
                    guard let text = record["text"] as? String,
                          let timestamp = record["timestamp"] as? Date else {
                        return nil
                    }
                    return (id: record.recordID.recordName, text: text, timestamp: timestamp)
                }
                print("✅ [CloudKit] Fetched \(siblings.count) siblings in \(String(format: "%.2f", fetchTime))s")
                completion(.success(siblings))
            }
        }
    }

    // Fetch all root tasks (tasks with no parent)
    func fetchRoots(completion: @escaping (Result<[(id: String, text: String, timestamp: Date)], Error>) -> Void) {
        let fetchStartTime = Date()
        print("🌳 [CloudKit] Fetching root tasks (parent_id NOT set)")

        // Query for all tasks where parent_id is NOT set
        // CloudKit syntax: NOT (field != nil) means "field is nil or doesn't exist"
        let predicate = NSPredicate(format: "NOT (parent_id != nil)")
        let query = CKQuery(recordType: "Task", predicate: predicate)

        // Sort by creation time for stable ordering (newest first)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        database.perform(query, inZoneWith: nil) { records, error in
            let fetchTime = Date().timeIntervalSince(fetchStartTime)

            if let error = error {
                print("❌ [CloudKit] Root fetch failed after \(String(format: "%.2f", fetchTime))s: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let records = records {
                let roots = records.compactMap { record -> (id: String, text: String, timestamp: Date)? in
                    guard let text = record["text"] as? String,
                          let timestamp = record["timestamp"] as? Date else {
                        return nil
                    }
                    return (id: record.recordID.recordName, text: text, timestamp: timestamp)
                }
                print("✅ [CloudKit] Fetched \(roots.count) root tasks in \(String(format: "%.2f", fetchTime))s")
                completion(.success(roots))
            }
        }
    }

    // Fetch the latest (most recently created) task in a given tree
    func fetchLatestTaskInTree(rootId: String, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let fetchStartTime = Date()
        print("🌳 [CloudKit] Fetching latest task in tree with rootId: \(rootId)")

        // Query for all tasks with this root_id OR tasks that ARE this root (for single-task trees)
        let predicate = NSPredicate(format: "root_id == %@ OR SELF == %@",
                                   rootId,
                                   CKRecord.ID(recordName: rootId))
        let query = CKQuery(recordType: "Task", predicate: predicate)

        // Sort by timestamp descending (newest first)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        database.perform(query, inZoneWith: nil) { records, error in
            let fetchTime = Date().timeIntervalSince(fetchStartTime)

            if let error = error {
                print("❌ [CloudKit] Latest task fetch failed after \(String(format: "%.2f", fetchTime))s: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let records = records, let latestTask = records.first {
                let taskText = latestTask["text"] as? String ?? "Unknown"
                print("✅ [CloudKit] Found latest task in tree: \(taskText) in \(String(format: "%.2f", fetchTime))s")
                completion(.success(latestTask))
            } else {
                print("❌ [CloudKit] No tasks found in tree after \(String(format: "%.2f", fetchTime))s")
                let error = NSError(domain: "HoldApp", code: 404, userInfo: [NSLocalizedDescriptionKey: "No tasks found in tree"])
                completion(.failure(error))
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
