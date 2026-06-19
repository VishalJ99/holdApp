import Foundation
import CloudKit
import os

private let logger = Logger(subsystem: "com.vishaljain.HoldApp", category: "CloudKitManager")

struct CurrentTaskPointer: Equatable {
    let recordExists: Bool
    let taskId: String?
    let text: String?
    let parentId: String?
    let rootId: String?
    let parentTaskText: String?
    let rootTaskText: String?
    let showEllipsis: Bool
    let siblingPosition: Int?
    let siblingCount: Int?
    let timestamp: Date?
}

class CloudKitManager {
    static let shared = CloudKitManager()
    private static let requiredContainerIdentifier = "iCloud.com.vishaljain.HoldApp"

    private let container: CKContainer
    private let database: CKDatabase
    private var heartbeatTimer: Timer?
    private let currentTaskRecordType = "CurrentTaskPointer"
    private let currentTaskSubscriptionID = "current-task-pointer-changes"
    private let pointerSaveQueue = DispatchQueue(label: "com.vishaljain.HoldApp.current-task-pointer-save")
    private var pointerSaveInFlight = false
    private var pendingPointerSave: PointerSaveRequest?

    private struct PointerSaveRequest {
        let action: String
        let startTime: Date
        let applyFields: (CKRecord) -> Void
        let completion: (Error?) -> Void
    }

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

    private func logIOSLatencyDiagnostic(_ message: String) {
        #if os(iOS)
        LatencyDiagnostics.log(message)
        #endif
    }

    // MARK: - Connection Warmup (Heartbeat)

    /// Start 15-second heartbeat to keep CloudKit connection warm
    func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.heartbeat()
        }
        // Fire immediately to warm up connection
        heartbeat()
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
        print("💔 [CloudKit] Heartbeat stopped")
    }

    // MARK: - CurrentTaskPointer Operations (iPhone Sync)

    // Fetch the current task from pointer record (bypasses query index lag)
    // Returns all display info: task texts, hierarchy info, leaf position info
    // Note: siblingPosition/siblingCount fields store leaf position/count (DFS order)
    func fetchCurrentTask(completion: @escaping (Result<CurrentTaskPointer, Error>) -> Void) {
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
                let timestamp = record["timestamp"] as? Date

                logger.error("[FETCH] OK - pointer record found")
                print("✅ [CloudKit] Current task fetched in \(String(format: "%.2f", fetchTime))s")
                print("📝 [CloudKit] Fetched from pointer (instant, no index lag)")
                print("🔗 [Fetch Summary] text=\"\(text ?? "nil")\" | taskId=\(taskId ?? "nil") | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")
                print("📊 [Leaf Info] position=\(siblingPosition?.description ?? "nil")/\(siblingCount?.description ?? "nil") | ellipsis=\(showEllipsis)")
                completion(.success(CurrentTaskPointer(
                    recordExists: true,
                    taskId: taskId,
                    text: text,
                    parentId: parentId,
                    rootId: rootId,
                    parentTaskText: parentTaskText,
                    rootTaskText: rootTaskText,
                    showEllipsis: showEllipsis,
                    siblingPosition: siblingPosition,
                    siblingCount: siblingCount,
                    timestamp: timestamp
                )))
            } else if let fetchError = error as? CKError, fetchError.code == .unknownItem {
                // Pointer doesn't exist yet (no current task set)
                logger.error("[FETCH] MISSING - no pointer record exists")
                print("ℹ️ [CloudKit] Fetch completed in \(String(format: "%.2f", fetchTime))s: No current task pointer found")
                completion(.success(CurrentTaskPointer(
                    recordExists: false,
                    taskId: nil,
                    text: nil,
                    parentId: nil,
                    rootId: nil,
                    parentTaskText: nil,
                    rootTaskText: nil,
                    showEllipsis: false,
                    siblingPosition: nil,
                    siblingCount: nil,
                    timestamp: nil
                )))
            } else {
                // Unexpected error
                logger.error("[FETCH] ERROR - \(error?.localizedDescription ?? "unknown", privacy: .public)")
                print("❌ [CloudKit] Fetch failed after \(String(format: "%.2f", fetchTime))s: \(error?.localizedDescription ?? "unknown")")
                completion(.failure(error ?? NSError(domain: "CloudKitManager", code: -1, userInfo: nil)))
            }
        }
    }

    // Update the current task pointer record.
    // Pointer saves are serialized and pending writes are coalesced so rapid
    // Mac-side navigation eventually writes only the latest requested state.
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
        logger.error("[SAVE] updateCurrentTaskPointer called")
        let pointerStartTime = Date()
        print("🎯 [CloudKit] Updating current task pointer at \(pointerStartTime)")
        print("🔗 [Pointer Update] taskId=\(taskId) | parentId=\(parentId ?? "nil") | rootId=\(rootId ?? "nil")")
        print("📊 [Leaf Update] position=\(siblingPosition?.description ?? "nil")/\(siblingCount?.description ?? "nil") | ellipsis=\(showEllipsis)")

        let request = PointerSaveRequest(
            action: "updated",
            startTime: pointerStartTime,
            applyFields: { [weak self] pointerRecord in
                self?.applyPointerFields(
                    to: pointerRecord,
                    taskId: taskId,
                    text: text,
                    parentId: parentId,
                    rootId: rootId,
                    parentTaskText: parentTaskText,
                    rootTaskText: rootTaskText,
                    showEllipsis: showEllipsis,
                    siblingPosition: siblingPosition,
                    siblingCount: siblingCount
                )
            },
            completion: completion
        )

        enqueuePointerSave(request)
    }

    private func enqueuePointerSave(_ request: PointerSaveRequest) {
        pointerSaveQueue.async { [weak self] in
            guard let self else { return }

            if let supersededRequest = self.pendingPointerSave {
                logger.error("[SAVE] SUPERSEDED pending pointer \(supersededRequest.action, privacy: .public)")
                supersededRequest.completion(nil)
            }

            self.pendingPointerSave = request

            if !self.pointerSaveInFlight {
                self.startNextPointerSaveLocked()
            }
        }
    }

    private func startNextPointerSaveLocked() {
        guard let request = pendingPointerSave else {
            pointerSaveInFlight = false
            return
        }

        pendingPointerSave = nil
        pointerSaveInFlight = true

        performPointerSave(request) { [weak self] in
            self?.pointerSaveQueue.async {
                guard let self else { return }
                self.pointerSaveInFlight = false
                self.startNextPointerSaveLocked()
            }
        }
    }

    private func performPointerSave(_ request: PointerSaveRequest, finished: @escaping () -> Void) {
        let pointerID = CKRecord.ID(recordName: "CURRENT_TASK_POINTER")

        database.fetch(withRecordID: pointerID) { [weak self] record, error in
            guard let self else {
                finished()
                return
            }

            if let existingRecord = record {
                logger.error("[SAVE] Existing pointer found - \(request.action, privacy: .public)")
                self.savePointerRecord(
                    existingRecord,
                    startTime: request.startTime,
                    action: request.action,
                    applyFields: request.applyFields
                ) { error in
                    request.completion(error)
                    finished()
                }
            } else if let fetchError = error as? CKError, fetchError.code == .unknownItem {
                logger.error("[SAVE] Pointer missing - creating")
                let newRecord = CKRecord(recordType: currentTaskRecordType, recordID: pointerID)
                self.savePointerRecord(
                    newRecord,
                    startTime: request.startTime,
                    action: "created",
                    applyFields: request.applyFields
                ) { error in
                    request.completion(error)
                    finished()
                }
            } else {
                let pointerTime = Date().timeIntervalSince(request.startTime)
                let message = error?.localizedDescription ?? "unknown"
                logger.error("[SAVE] FETCH ERROR - \(message, privacy: .public)")
                print("❌ [CloudKit] Pointer fetch failed after \(String(format: "%.2f", pointerTime))s: \(message)")
                request.completion(error)
                finished()
            }
        }
    }

    // Clear the current task pointer (for empty state or startup sync)
    // Uses the same overwrite path as task updates so rapid clear/update races do not
    // leave iOS with a stale pointer.
    func clearCurrentTaskPointer(completion: @escaping (Error?) -> Void) {
        logger.error("[CLEAR] clearCurrentTaskPointer called")
        let clearStartTime = Date()
        print("🗑️ [CloudKit] Clearing CurrentTaskPointer at \(clearStartTime)")

        let request = PointerSaveRequest(
            action: "cleared",
            startTime: clearStartTime,
            applyFields: { [weak self] pointerRecord in
                self?.applyEmptyPointerFields(to: pointerRecord)
            },
            completion: completion
        )

        enqueuePointerSave(request)
    }

    private func applyPointerFields(
        to record: CKRecord,
        taskId: String,
        text: String,
        parentId: String?,
        rootId: String?,
        parentTaskText: String?,
        rootTaskText: String?,
        showEllipsis: Bool,
        siblingPosition: Int?,
        siblingCount: Int?
    ) {
        record["currentTaskId"] = taskId as CKRecordValue
        record["currentTaskText"] = text as CKRecordValue
        record["parentId"] = parentId as CKRecordValue?
        record["rootId"] = rootId as CKRecordValue?
        record["parentTaskText"] = parentTaskText as CKRecordValue?
        record["rootTaskText"] = rootTaskText as CKRecordValue?
        record["showEllipsis"] = (showEllipsis ? 1 : 0) as CKRecordValue
        record["siblingPosition"] = siblingPosition as CKRecordValue?
        record["siblingCount"] = siblingCount as CKRecordValue?
        record["timestamp"] = Date() as CKRecordValue
    }

    private func applyEmptyPointerFields(to record: CKRecord) {
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
    }

    private func savePointerRecord(
        _ record: CKRecord,
        startTime: Date,
        action: String,
        retryCount: Int = 0,
        applyFields: @escaping (CKRecord) -> Void,
        completion: @escaping (Error?) -> Void
    ) {
        applyFields(record)

        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        operation.qualityOfService = .userInitiated
        operation.modifyRecordsResultBlock = { [weak self] result in
            guard let self else { return }
            let pointerTime = Date().timeIntervalSince(startTime)
            switch result {
            case .failure(let saveError):
                if retryCount == 0,
                   let serverRecord = self.serverRecordChangedRecord(from: saveError) {
                    logger.error("[SAVE] CONFLICT - retrying \(action, privacy: .public) with server record")
                    print("🔁 [CloudKit] Pointer \(action) hit record conflict after \(String(format: "%.2f", pointerTime))s; retrying with server record")
                    self.savePointerRecord(
                        serverRecord,
                        startTime: startTime,
                        action: action,
                        retryCount: retryCount + 1,
                        applyFields: applyFields,
                        completion: completion
                    )
                    return
                }

                logger.error("[SAVE] ERROR - \(saveError.localizedDescription, privacy: .public)")
                print("❌ [CloudKit] Pointer \(action) failed after \(String(format: "%.2f", pointerTime))s: \(saveError.localizedDescription)")
                completion(saveError)

            case .success:
                logger.error("[SAVE] OK - pointer \(action, privacy: .public) in CloudKit")
                print("✅ [CloudKit] Pointer \(action) in \(String(format: "%.2f", pointerTime))s")
                completion(nil)
            }
        }
        database.add(operation)
    }

    private func serverRecordChangedRecord(from error: Error) -> CKRecord? {
        guard let ckError = error as? CKError else {
            return nil
        }

        if ckError.code == .serverRecordChanged {
            return ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord
        }

        if ckError.code == .partialFailure,
           let partialErrors = ckError.partialErrorsByItemID {
            for partialError in partialErrors.values {
                if let serverRecord = serverRecordChangedRecord(from: partialError) {
                    return serverRecord
                }
            }
        }

        return nil
    }

    // Subscribe to current task pointer changes (for real-time updates on iPhone)
    func subscribeToTaskChanges(completion: @escaping (Error?) -> Void) {
        logger.error("[SUB] subscribeToTaskChanges called")
        print("🔔 [CloudKit] Setting up subscription...")
        logIOSLatencyDiagnostic("subscription setup started id=\(currentTaskSubscriptionID) recordType=\(currentTaskRecordType)")

        let subscription = CKQuerySubscription(
            recordType: currentTaskRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: currentTaskSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )

        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        subscription.notificationInfo = notification

        print("🔔 [CloudKit] Subscription configured for CurrentTaskPointer - fires on: creation, update")
        print("🔔 [CloudKit] Silent notification: \(notification.shouldSendContentAvailable)")
        print("🎯 [CloudKit] This eliminates race condition: notification only fires AFTER pointer update")

        database.fetchAllSubscriptions { [weak self] subscriptions, error in
            guard let self else { return }

            if let error {
                let code = (error as? CKError).map { String(describing: $0.code) } ?? "non-CKError"
                logger.error("[SUB] fetchAllSubscriptions ERROR - \(error.localizedDescription, privacy: .public)")
                self.logIOSLatencyDiagnostic("subscription list failed code=\(code) error=\"\(error.localizedDescription)\"")
                self.saveCurrentTaskSubscription(subscription, completion: completion)
            } else {
                let existingSubscriptions = subscriptions ?? []
                let subscriptionIDs = existingSubscriptions.map(\.subscriptionID)
                let staleIDs = existingSubscriptions.compactMap { self.legacyCurrentTaskSubscriptionID(from: $0) }
                let ids = subscriptionIDs.sorted().joined(separator: ",")
                logger.error("[SUB] existing subscriptions fetched")
                self.logIOSLatencyDiagnostic("subscription list count=\(subscriptionIDs.count) ids=\(ids.isEmpty ? "none" : ids) stale=\(staleIDs.sorted().joined(separator: ","))")
                self.deleteLegacySubscriptions(staleIDs) {
                    self.saveCurrentTaskSubscription(subscription, completion: completion)
                }
            }
        }
    }

    private func saveCurrentTaskSubscription(_ subscription: CKSubscription, completion: @escaping (Error?) -> Void) {
        database.save(subscription) { [weak self] savedSubscription, error in
            if let error = error {
                let code = (error as? CKError).map { String(describing: $0.code) } ?? "non-CKError"
                logger.error("[SUB] ERROR - \(error.localizedDescription, privacy: .public)")
                print("❌ [CloudKit] Subscription failed: \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    print("❌ [CloudKit] CKError code: \(ckError.errorCode)")
                    print("❌ [CloudKit] CKError description: \(ckError)")
                }
                self?.logIOSLatencyDiagnostic("subscription save failed code=\(code) error=\"\(error.localizedDescription)\"")
                completion(error)
            } else if let savedSubscription = savedSubscription {
                logger.error("[SUB] OK - subscription created")
                print("✅ [CloudKit] Subscription created successfully!")
                print("📝 [CloudKit] Subscription ID: \(savedSubscription.subscriptionID)")
                self?.logIOSLatencyDiagnostic("subscription save succeeded id=\(savedSubscription.subscriptionID)")
                completion(nil)
            }
        }
    }

    private func legacyCurrentTaskSubscriptionID(from subscription: CKSubscription) -> String? {
        guard let querySubscription = subscription as? CKQuerySubscription,
              querySubscription.recordType == currentTaskRecordType,
              subscription.subscriptionID != currentTaskSubscriptionID,
              UUID(uuidString: subscription.subscriptionID) != nil else {
            return nil
        }

        return subscription.subscriptionID
    }

    private func deleteLegacySubscriptions(_ subscriptionIDs: [String], completion: @escaping () -> Void) {
        guard !subscriptionIDs.isEmpty else {
            completion()
            return
        }

        logger.error("[SUB] deleting legacy subscriptions count=\(subscriptionIDs.count)")
        logIOSLatencyDiagnostic("subscription cleanup deleting ids=\(subscriptionIDs.sorted().joined(separator: ","))")

        let group = DispatchGroup()

        for subscriptionID in subscriptionIDs {
            group.enter()
            database.delete(withSubscriptionID: subscriptionID) { [weak self] _, error in
                if let error {
                    let code = (error as? CKError).map { String(describing: $0.code) } ?? "non-CKError"
                    logger.error("[SUB] legacy delete failed id=\(subscriptionID, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                    self?.logIOSLatencyDiagnostic("subscription cleanup delete failed id=\(subscriptionID) code=\(code) error=\"\(error.localizedDescription)\"")
                } else {
                    logger.error("[SUB] legacy delete succeeded id=\(subscriptionID, privacy: .public)")
                    self?.logIOSLatencyDiagnostic("subscription cleanup delete succeeded id=\(subscriptionID)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }
}
