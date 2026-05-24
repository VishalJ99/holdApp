import Foundation
import CloudKit
import os

private let logger = Logger(subsystem: "com.vishaljain.HoldApp", category: "CloudKitManager")

struct MacPresenceStatus {
    let lastSeenAt: Date?
    let isFresh: Bool
}

class CloudKitManager {
    static let shared = CloudKitManager()
    private static let requiredContainerIdentifier = "iCloud.com.vishaljain.HoldApp"
    static let macPresenceFreshnessInterval: TimeInterval = 5 * 60

    private let container: CKContainer
    private let database: CKDatabase
    private var heartbeatTimer: Timer?
    private var macPresenceTimer: Timer?

    private init() {
        let configuredContainer = CKContainer(identifier: Self.requiredContainerIdentifier)
        container = configuredContainer
        database = configuredContainer.privateCloudDatabase

        // Log CloudKit configuration
        logger.error("[INIT] Container=\(configuredContainer.containerIdentifier ?? "nil")")
        print("☁️ [CloudKit] Initialized")
        print("📦 [CloudKit] Container: \(configuredContainer.containerIdentifier ?? "unknown")")
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

    // MARK: - Connection Warmup (Heartbeat)

    /// Start 15-second heartbeat to keep CloudKit connection warm
    func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.heartbeat()
        }
        macPresenceTimer?.invalidate()
        macPresenceTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.publishMacPresence { _ in }
        }
        // Fire immediately to warm up connection
        heartbeat()
        publishMacPresence { _ in }
        logger.error("[HEARTBEAT] Started 15s timer")
        print("💓 [CloudKit] Heartbeat started (15s interval)")
    }

    /// Silent fetch to keep connection alive
    private func heartbeat() {
        let pointerID = CKRecord.ID(recordName: "CURRENT_TASK_POINTER")
        database.fetch(withRecordID: pointerID) { record, error in
            if record != nil {
                logger.error("[HEARTBEAT] OK - record exists")
            } else if let ckError = error as? CKError, ckError.code == .unknownItem {
                logger.error("[HEARTBEAT] MISSING - pointer record does not exist")
            } else if let error = error {
                logger.error("[HEARTBEAT] ERROR - \(error.localizedDescription, privacy: .public)")
            } else {
                logger.error("[HEARTBEAT] FAILED - unknown reason")
            }
        }
    }

    /// Stop heartbeat timer
    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        macPresenceTimer?.invalidate()
        macPresenceTimer = nil
        print("💔 [CloudKit] Heartbeat stopped")
    }

    // MARK: - MacPresence Operations

    func publishMacPresence(completion: @escaping (Error?) -> Void) {
        let presenceID = CKRecord.ID(recordName: "MAC_PRESENCE")
        let record = CKRecord(recordType: "MacPresence", recordID: presenceID)
        record["lastSeenAt"] = Date() as CKRecordValue
        record["platform"] = "macOS" as CKRecordValue
        record["appVersion"] = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown") as CKRecordValue
        record["buildNumber"] = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown") as CKRecordValue

        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        operation.qualityOfService = .utility
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                logger.error("[MAC_PRESENCE] OK - heartbeat saved")
                completion(nil)
            case .failure(let error):
                logger.error("[MAC_PRESENCE] ERROR - \(error.localizedDescription, privacy: .public)")
                completion(error)
            }
        }

        database.add(operation)
    }

    func fetchMacPresence(completion: @escaping (Result<MacPresenceStatus, Error>) -> Void) {
        let presenceID = CKRecord.ID(recordName: "MAC_PRESENCE")
        database.fetch(withRecordID: presenceID) { record, error in
            if let record = record {
                let lastSeenAt = record["lastSeenAt"] as? Date
                let age = lastSeenAt.map { Date().timeIntervalSince($0) }
                let isFresh = age.map { $0 <= Self.macPresenceFreshnessInterval } ?? false
                logger.error("[MAC_PRESENCE] FETCH OK - fresh=\(isFresh)")
                completion(.success(MacPresenceStatus(lastSeenAt: lastSeenAt, isFresh: isFresh)))
            } else if let fetchError = error as? CKError, fetchError.code == .unknownItem {
                logger.error("[MAC_PRESENCE] FETCH MISSING")
                completion(.success(MacPresenceStatus(lastSeenAt: nil, isFresh: false)))
            } else {
                logger.error("[MAC_PRESENCE] FETCH ERROR - \(error?.localizedDescription ?? "unknown", privacy: .public)")
                completion(.failure(error ?? NSError(domain: "CloudKitManager", code: -1, userInfo: nil)))
            }
        }
    }

    // MARK: - CurrentTaskPointer Operations (iPhone Sync)

    // Fetch the current task from pointer record (bypasses query index lag)
    // Returns all display info: task texts, hierarchy info, leaf position info
    // Note: siblingPosition/siblingCount fields store leaf position/count (DFS order)
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
        logger.error("[FETCH] fetchCurrentTask called")
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

                logger.error("[FETCH] OK - pointer record found")
                print("✅ [CloudKit] Current task fetched in \(String(format: "%.2f", fetchTime))s")
                print("📝 [CloudKit] Fetched from pointer (instant, no index lag)")
                print("🔗 [Fetch Summary] text=\"\(text ?? "nil")\" | taskId=\(taskId ?? "nil") | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")
                print("📊 [Leaf Info] position=\(siblingPosition?.description ?? "nil")/\(siblingCount?.description ?? "nil") | ellipsis=\(showEllipsis)")
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
                logger.error("[FETCH] MISSING - no pointer record exists")
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
                logger.error("[FETCH] ERROR - \(error?.localizedDescription ?? "unknown", privacy: .public)")
                print("❌ [CloudKit] Fetch failed after \(String(format: "%.2f", fetchTime))s: \(error?.localizedDescription ?? "unknown")")
                completion(.failure(error ?? NSError(domain: "CloudKitManager", code: -1, userInfo: nil)))
            }
        }
    }

    // Update the current task pointer record (single operation, no fetch needed)
    // Uses CKModifyRecordsOperation with .allKeys policy to overwrite without conflict check
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
        sourcePlatform: String = "macOS",
        completion: @escaping (Error?) -> Void
    ) {
        logger.error("[SAVE] updateCurrentTaskPointer called")
        let pointerStartTime = Date()
        print("🎯 [CloudKit] Updating current task pointer at \(pointerStartTime)")
        print("🔗 [Pointer Update] taskId=\(taskId) | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")
        print("📊 [Leaf Update] position=\(siblingPosition?.description ?? "nil")/\(siblingCount?.description ?? "nil") | ellipsis=\(showEllipsis)")

        // Use hardcoded record ID so both macOS and iPhone know where to look
        let pointerID = CKRecord.ID(recordName: "CURRENT_TASK_POINTER")
        let record = CKRecord(recordType: "CurrentTaskPointer", recordID: pointerID)

        // Set all fields
        record["currentTaskId"] = taskId as CKRecordValue
        record["currentTaskText"] = text as CKRecordValue
        record["parentId"] = parentId as CKRecordValue?
        record["rootId"] = rootId as CKRecordValue?
        record["parentTaskText"] = parentTaskText as CKRecordValue?
        record["rootTaskText"] = rootTaskText as CKRecordValue?
        record["showEllipsis"] = (showEllipsis ? 1 : 0) as CKRecordValue
        record["siblingPosition"] = siblingPosition as CKRecordValue?
        record["siblingCount"] = siblingCount as CKRecordValue?
        record["sourcePlatform"] = sourcePlatform as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue

        // Use CKModifyRecordsOperation with .allKeys to skip fetch and overwrite directly
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .allKeys  // Overwrite without checking recordChangeTag
        operation.qualityOfService = .userInitiated  // High priority, immediate execution

        operation.modifyRecordsResultBlock = { result in
            let pointerTime = Date().timeIntervalSince(pointerStartTime)
            switch result {
            case .success:
                logger.error("[SAVE] OK - pointer saved to CloudKit")
                print("✅ [CloudKit] Pointer updated in \(String(format: "%.2f", pointerTime))s (single operation, .userInitiated QoS)")
                print("🔗 [Pointer Summary] text=\"\(text)\" | taskId=\(taskId) | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")
                completion(nil)
            case .failure(let error):
                logger.error("[SAVE] ERROR - \(error.localizedDescription, privacy: .public)")
                print("❌ [CloudKit] Pointer update failed after \(String(format: "%.2f", pointerTime))s: \(error.localizedDescription)")
                completion(error)
            }
        }

        database.add(operation)
    }

    // Clear the current task pointer (for empty state or startup sync)
    // Uses CKModifyRecordsOperation with .allKeys policy to overwrite without conflict check
    func clearCurrentTaskPointer(completion: @escaping (Error?) -> Void) {
        logger.error("[CLEAR] clearCurrentTaskPointer called")
        let clearStartTime = Date()
        print("🗑️ [CloudKit] Clearing CurrentTaskPointer at \(clearStartTime)")

        let pointerID = CKRecord.ID(recordName: "CURRENT_TASK_POINTER")
        let record = CKRecord(recordType: "CurrentTaskPointer", recordID: pointerID)

        // Set all fields to nil/empty
        record["currentTaskId"] = nil as String?
        record["currentTaskText"] = nil as String?
        record["parentId"] = nil as String?
        record["rootId"] = nil as String?
        record["parentTaskText"] = nil as String?
        record["rootTaskText"] = nil as String?
        record["showEllipsis"] = 0 as CKRecordValue
        record["siblingPosition"] = nil as Int?
        record["siblingCount"] = nil as Int?
        record["timestamp"] = Date() as CKRecordValue

        // Use CKModifyRecordsOperation with .allKeys to skip fetch and overwrite directly
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .allKeys  // Overwrite without checking recordChangeTag
        operation.qualityOfService = .userInitiated  // High priority, immediate execution

        operation.modifyRecordsResultBlock = { result in
            let clearTime = Date().timeIntervalSince(clearStartTime)
            switch result {
            case .success:
                logger.error("[CLEAR] OK - pointer cleared")
                print("✅ [CloudKit] CurrentTaskPointer cleared in \(String(format: "%.2f", clearTime))s (single operation, .userInitiated QoS)")
                print("📱 [CloudKit] iPhone will now show 'No current task'")
                completion(nil)
            case .failure(let error):
                logger.error("[CLEAR] ERROR - \(error.localizedDescription, privacy: .public)")
                print("❌ [CloudKit] Clear pointer failed after \(String(format: "%.2f", clearTime))s: \(error.localizedDescription)")
                completion(error)
            }
        }

        database.add(operation)
    }

    // Subscribe to current task pointer changes (for real-time updates on iPhone)
    func subscribeToTaskChanges(completion: @escaping (Error?) -> Void) {
        logger.error("[SUB] subscribeToTaskChanges called")
        print("🔔 [CloudKit] Setting up subscription...")

        let subscription = CKQuerySubscription(
            recordType: "CurrentTaskPointer",
            predicate: NSPredicate(value: true),
            subscriptionID: "current-task-pointer-changes",
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
                logger.error("[SUB] ERROR - \(error.localizedDescription, privacy: .public)")
                print("❌ [CloudKit] Subscription failed: \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    print("❌ [CloudKit] CKError code: \(ckError.errorCode)")
                    print("❌ [CloudKit] CKError description: \(ckError)")
                }
                completion(error)
            } else if let savedSubscription = savedSubscription {
                logger.error("[SUB] OK - subscription created")
                print("✅ [CloudKit] Subscription created successfully!")
                print("📝 [CloudKit] Subscription ID: \(savedSubscription.subscriptionID)")
                completion(nil)
            }
        }
    }
}
