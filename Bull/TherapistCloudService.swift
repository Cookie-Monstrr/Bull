import Foundation
@preconcurrency import CloudKit
import Combine
import SwiftUI
import UIKit

enum OversightEndError: LocalizedError {
    case busy, timedOut
    var errorDescription: String? {
        switch self {
        case .busy: return "iCloud is still busy. Access has not been confirmed ended. Please try End Access again."
        case .timedOut: return "iCloud did not confirm revocation in time. Risk Controls remain protected. Check your connection and retry End Access."
        }
    }
}

@MainActor
enum OversightEndFlow {
    static func waitUntilIdle(timeout: TimeInterval = 20, isBusy: () -> Bool) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while isBusy() {
            try Task.checkCancellation()
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw OversightEndError.busy }
            try await Task<Never, Never>.sleep(for: .milliseconds(100))
        }
    }

    static func run(
        wait: () async throws -> Void,
        revoke: () async throws -> Void,
        finish: () -> Void
    ) async throws {
        try await wait()
        try Task.checkCancellation()
        try await revoke()
        // Once remote revocation is confirmed, finalize even if the UI task was cancelled.
        finish()
    }
}

/// CloudKit completion and a wall-clock timeout can race; resume exactly once.
private final class RevocationCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    init(_ continuation: CheckedContinuation<Void, Error>) { self.continuation = continuation }
    @discardableResult
    func finish(_ result: Result<Void, Error>) -> Bool {
        lock.lock()
        let current = continuation
        continuation = nil
        lock.unlock()
        guard let current else { return false }
        current.resume(with: result)
        return true
    }
}

extension Notification.Name {
    static let bullCloudKitChanged = Notification.Name("bull.cloudkit.changed")
    static let bullCloudShareAccepted = Notification.Name("bull.cloudkit.share-accepted")
    static let bullTherapistOutboxChanged = Notification.Name("bull.therapist.outbox-changed")
}

@MainActor
final class CloudKitBackgroundFetchCompletion {
    private var handler: ((UIBackgroundFetchResult) -> Void)?

    init(_ handler: @escaping (UIBackgroundFetchResult) -> Void) {
        self.handler = handler
        Task { [self] in
            try? await Task<Never, Never>.sleep(for: .seconds(25))
            finish(.failed)
        }
    }

    func finish(_ result: UIBackgroundFetchResult) {
        guard let handler else { return }
        self.handler = nil
        handler(result)
    }
}

@MainActor
final class BullAppDelegate: NSObject, UIApplicationDelegate {
    static var pendingShareMetadata: CKShare.Metadata?

    static func receiveShare(_ metadata: CKShare.Metadata) {
        pendingShareMetadata = metadata
        NotificationCenter.default.post(name: .bullCloudShareAccepted, object: nil)
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = BullShareSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Self.receiveShare(cloudKitShareMetadata)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }
        let completion = CloudKitBackgroundFetchCompletion(completionHandler)
        NotificationCenter.default.post(name: .bullCloudKitChanged, object: completion)
    }
}

/// SwiftUI delivers invitations to the scene, including connection options on cold launch.
@MainActor
final class BullShareSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            BullAppDelegate.receiveShare(metadata)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
        BullAppDelegate.receiveShare(metadata)
    }
}

struct TherapistCloudShare: Identifiable {
    var id: String { share.recordID.recordName }
    let share: CKShare
    let container: CKContainer
}

private struct TherapistSharedPayload: Codable {
    var schemaVersion: Int
    var projection: TherapistProjection
    var events: [TherapistOversightEvent]

    init(
        schemaVersion: Int = 1,
        projection: TherapistProjection,
        events: [TherapistOversightEvent]
    ) {
        self.schemaVersion = schemaVersion
        self.projection = projection
        self.events = events
    }
}

private struct TherapistDecisionPayload: Codable {
    var schemaVersion: Int
    var decisions: [TherapistRiskChangeRecord]

    init(schemaVersion: Int = 1, decisions: [TherapistRiskChangeRecord]) {
        self.schemaVersion = schemaVersion
        self.decisions = decisions
    }
}

@MainActor
final class TherapistCloudService: ObservableObject {
    @Published private(set) var accountLabel = "Not checked"
    @Published private(set) var isSyncing = false
    @Published private(set) var isEndingAccess = false
    @Published private(set) var endAccessStatus: String?
    @Published private(set) var accessLabel = "Not Invited"
    @Published private(set) var shareStatusMessage: String?
    @Published var lastError: String?
    @Published var preparedShare: TherapistCloudShare?

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    /// Incremented when an unfinished owner setup is cancelled. CloudKit async calls can
    /// return after the user has cancelled, so every setup/sync operation captures this
    /// value and refuses to resurrect ended oversight when its result arrives late.
    private var cancellationGeneration: UInt = 0

    private enum CloudContract {
        static let zoneName = "BullTherapistOversight"
        static let snapshotRecordType = "BullTherapistSnapshot"
        static let snapshotRecordName = "current"
        static let decisionsRecordType = "BullTherapistDecisions"
        static let decisionsRecordName = "current-decisions"
        static let encryptedPayloadKey = "payload"
        static let schemaVersionKey = "schemaVersion"
        static let updatedAtKey = "updatedAt"
        static let sharedSubscriptionID = "bull.therapist.shared-database.v1"
        static let ownerSubscriptionID = "bull.therapist.owner-zone.v1"
    }

    init(container: CKContainer = CKContainer(identifier: "iCloud.com.ahmed.Bull")) {
        self.container = container
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
    }

    func refreshAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available: accountLabel = "iCloud Ready"
            case .noAccount: accountLabel = "Sign in to iCloud"
            case .restricted: accountLabel = "iCloud Restricted"
            case .couldNotDetermine: accountLabel = "iCloud Unavailable"
            case .temporarilyUnavailable: accountLabel = "iCloud Temporarily Unavailable"
            @unknown default: accountLabel = "iCloud Unavailable"
            }
        } catch {
            accountLabel = "iCloud Unavailable"
            lastError = error.localizedDescription
        }
    }

    func recoverExistingAccess(store: BullStore) async {
        guard !isSyncing, !isEndingAccess else { return }
        isSyncing = true
        defer { isSyncing = false }
        let state = store.data.therapistOversight.state
        guard state == .off || state == .ended else { return }
        if state == .ended,
           let endedTs = store.data.therapistOversight.endedTs,
           Date().timeIntervalSince1970 * 1_000 - endedTs < 24 * 60 * 60 * 1_000 {
            return
        }
        do {
            try await requireAvailableAccount()
            let sharedZones = try await sharedZoneIDs()
            if sharedZones.count > 1 {
                throw TherapistCloudError.multipleClientShares(sharedZones.count)
            }
            if let zoneID = sharedZones.first {
                store.enterTherapistRole(
                    zoneName: zoneID.zoneName,
                    shareRecordName: CKRecordNameZoneWideShare
                )
                lastError = nil
                return
            }

            let zoneID = CKRecordZone.ID(
                zoneName: CloudContract.zoneName,
                ownerName: CKCurrentUserDefaultName
            )
            let shareID = CKRecord.ID(
                recordName: CKRecordNameZoneWideShare,
                zoneID: zoneID
            )
            guard let share = try await privateDatabase.record(for: shareID) as? CKShare else {
                return
            }
            let invited = share.participants.filter {
                $0.role != .owner && $0.acceptanceStatus != .removed
            }
            if invited.count > 1 {
                store.recoverOwnerTherapistOversight(
                    zoneName: zoneID.zoneName,
                    shareRecordName: share.recordID.recordName,
                    connected: invited.contains { $0.acceptanceStatus == .accepted }
                )
                let error = TherapistCloudError.multipleTherapists(invited.count)
                store.setTherapistTransport(.error, error: error.localizedDescription)
                lastError = error.localizedDescription
                return
            }
            store.recoverOwnerTherapistOversight(
                zoneName: zoneID.zoneName,
                shareRecordName: share.recordID.recordName,
                connected: invited.first?.acceptanceStatus == .accepted
            )
            lastError = nil
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            // No server-side Bull share exists for this iCloud account.
        } catch {
            lastError = error.localizedDescription
        }
    }

    func prepareShare(for store: BullStore) async {
        guard !isSyncing, !isEndingAccess else { return }
        endAccessStatus = nil
        isSyncing = true
        defer { isSyncing = false }
        if store.data.therapistOversight.state == .off ||
            store.data.therapistOversight.state == .ended {
            store.beginTherapistOversight()
        }
        let generation = cancellationGeneration
        lastError = nil
        shareStatusMessage = "Preparing Private Invite…"
        store.setTherapistTransport(.preparing)
        do {
            try await requireAvailableAccount()
            let zoneID = ownerZoneID(for: store)
            try await ensureOwnerZone(zoneID)
            guard operationIsCurrent(generation, store: store) else {
                await discardUnconfirmedOwnerZone(zoneID)
                return
            }
            try await ensureOwnerZoneSubscription(zoneID)
            guard operationIsCurrent(generation, store: store) else {
                await discardUnconfirmedOwnerZone(zoneID)
                return
            }
            try await publishOwnerPayload(store: store, zoneID: zoneID)
            guard operationIsCurrent(generation, store: store) else {
                await discardUnconfirmedOwnerZone(zoneID)
                return
            }
            let share = try await existingOrNewShare(zoneID: zoneID)
            guard operationIsCurrent(generation, store: store) else {
                await discardUnconfirmedOwnerZone(zoneID)
                return
            }
            if !isEndingAccess {
                preparedShare = TherapistCloudShare(share: share, container: container)
            }
            updateAccessLabel(from: share)
            shareStatusMessage = accessLabel == "Not Invited"
                ? "Invite Sheet Ready"
                : "Access Settings Ready"
            store.markTherapistSharePrepared(
                zoneName: zoneID.zoneName,
                shareRecordName: share.recordID.recordName
            )
            lastError = nil
        } catch {
            guard operationIsCurrent(generation, store: store) else { return }
            markOwnerOutboxFailed(error, store: store)
            fail(error, store: store)
            shareStatusMessage = "Could Not Open the Invite"
        }
    }

    @discardableResult
    func sync(store: BullStore, notifications: NotificationService) async -> Bool {
        guard !isSyncing, !isEndingAccess else { return false }
        let oversight = store.data.therapistOversight
        guard oversight.state == .invitationReady || oversight.state == .active else { return false }
        let generation = cancellationGeneration
        isSyncing = true
        store.setTherapistTransport(.syncing)
        defer { isSyncing = false }
        do {
            try await requireAvailableAccount()
            guard operationIsCurrent(generation, store: store) else { return false }
            if oversight.role == .owner {
                let zoneID = ownerZoneID(for: store)
                try await ensureOwnerZone(zoneID)
                guard operationIsCurrent(generation, store: store) else {
                    await discardUnconfirmedOwnerZone(zoneID)
                    return false
                }
                try await ensureOwnerZoneSubscription(zoneID)
                guard operationIsCurrent(generation, store: store) else {
                    await discardUnconfirmedOwnerZone(zoneID)
                    return false
                }
                try await publishOwnerPayload(store: store, zoneID: zoneID)
                guard operationIsCurrent(generation, store: store) else {
                    await discardUnconfirmedOwnerZone(zoneID)
                    return false
                }
                let appliedDecisions = try await receiveTherapistDecisions(store: store, zoneID: zoneID)
                if appliedDecisions {
                    guard operationIsCurrent(generation, store: store) else {
                        await discardUnconfirmedOwnerZone(zoneID)
                        return false
                    }
                    // A second publish reflects the applied or superseded decision without
                    // letting a bad decision record block urgent owner warnings.
                    try await publishOwnerPayload(store: store, zoneID: zoneID)
                }
                guard operationIsCurrent(generation, store: store) else {
                    await discardUnconfirmedOwnerZone(zoneID)
                    return false
                }
                try await updateAcceptedParticipantState(store: store, zoneID: zoneID)
            } else {
                // Fetch first: a push-subscription failure must not hide readable client data.
                try await receiveSharedPayload(store: store, notifications: notifications)
                guard operationIsCurrent(generation, store: store) else { return false }
                try await ensureSharedDatabaseSubscription()
            }
            guard operationIsCurrent(generation, store: store) else { return false }
            store.setTherapistTransport(.ready, syncedAt: Date().timeIntervalSince1970 * 1_000)
            lastError = nil
            return true
        } catch let error as TherapistCloudError {
            guard operationIsCurrent(generation, store: store) else { return false }
            if case .noSharedOversight = error, oversight.role == .therapist {
                // Deleting a CloudKit share is the authoritative revocation. Surface that
                // state instead of leaving a stale cached client dashboard on screen.
                store.markTherapistAccessEndedByOwner()
                lastError = nil
                return true
            }
            if oversight.role == .owner { markOwnerOutboxFailed(error, store: store) }
            fail(error, store: store)
            return false
        } catch {
            guard operationIsCurrent(generation, store: store) else { return false }
            if oversight.role == .owner { markOwnerOutboxFailed(error, store: store) }
            fail(error, store: store)
            return false
        }
    }

    func acceptPendingShare(
        store: BullStore,
        notifications: NotificationService
    ) async {
        guard let metadata = BullAppDelegate.pendingShareMetadata else { return }
        do {
            try await OversightEndFlow.waitUntilIdle {
                self.isSyncing || self.isEndingAccess
            }
        } catch {
            lastError = "The invitation is waiting for iCloud. Reopen the invite or return to Bull to retry."
            return
        }
        // Concurrent lifecycle callbacks may have already claimed this invitation.
        guard BullAppDelegate.pendingShareMetadata === metadata else { return }
        BullAppDelegate.pendingShareMetadata = nil
        isSyncing = true
        defer { isSyncing = false }
        var accepted = false
        do {
            guard metadata.containerIdentifier == "iCloud.com.ahmed.Bull",
                  metadata.share.recordID.zoneID.zoneName == CloudContract.zoneName,
                  metadata.share.recordID.recordName == CKRecordNameZoneWideShare else {
                throw TherapistCloudError.invalidShare
            }
            let current = store.data.therapistOversight
            if current.role == .owner && current.protectsRiskControls {
                throw TherapistCloudError.roleConflict
            }
            try await requireAvailableAccount()
            let pendingZoneID = metadata.share.recordID.zoneID
            let existingZones = try await sharedZoneIDs()
            if existingZones.isEmpty {
                _ = try await container.accept(metadata)
            } else if existingZones.count != 1 || existingZones[0] != pendingZoneID {
                throw TherapistCloudError.multipleClientShares(existingZones.count + 1)
            }
            accepted = true
            if current.role != .therapist || current.state != .active {
                store.enterTherapistRole(
                    zoneName: pendingZoneID.zoneName,
                    shareRecordName: metadata.share.recordID.recordName
                )
            }
            _ = await notifications.requestAuthorization()
            try await receiveSharedPayload(store: store, notifications: notifications)
            try await ensureSharedDatabaseSubscription()
            store.setTherapistTransport(.ready, syncedAt: Date().timeIntervalSince1970 * 1_000)
            lastError = nil
        } catch {
            if !accepted { BullAppDelegate.pendingShareMetadata = metadata }
            fail(error, store: store)
        }
    }

    func reviewRiskChange(
        id: String,
        approve: Bool,
        store: BullStore
    ) async {
        guard !isSyncing, !isEndingAccess,
              store.data.therapistOversight.role == .therapist,
              store.data.therapistOversight.state == .active,
              var projection = store.data.therapistProjectionCache,
              let index = projection.pendingRiskChanges.firstIndex(where: {
                  $0.id == id && $0.status == .pending
              }) else {
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        let reviewedTs = Date().timeIntervalSince1970 * 1_000
        projection.pendingRiskChanges[index].status = approve ? .approved : .rejected
        projection.pendingRiskChanges[index].reviewedTs = reviewedTs
        projection.pendingRiskChanges[index].reviewerDecision = approve ? "Approved" : "Discuss first"
        do {
            try await requireAvailableAccount()
            let zoneIDs = try await sharedZoneIDs()
            guard let zoneID = zoneIDs.first else {
                throw TherapistCloudError.noSharedOversight
            }
            guard zoneIDs.count == 1 else {
                throw TherapistCloudError.multipleClientShares(zoneIDs.count)
            }
            var decisions = try await fetchDecisions(database: sharedDatabase, zoneID: zoneID)
            decisions.removeAll { $0.id == id }
            decisions.append(projection.pendingRiskChanges[index])
            try await saveDecisions(decisions, database: sharedDatabase, zoneID: zoneID)
            store.cacheTherapistProjection(projection, events: [])
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func stopSharing(store: BullStore) async -> Bool {
        guard !isEndingAccess else { return false }
        let oversight = store.data.therapistOversight
        guard oversight.role == .owner else {
            lastError = "Only the Bull owner can revoke an owner share."
            return false
        }
        guard oversight.state == .invitationReady || oversight.state == .active else {
            preparedShare = nil
            lastError = nil
            return true
        }
        isEndingAccess = true
        endAccessStatus = "Waiting for the current iCloud operation…"
        lastError = nil
        preparedShare = nil
        defer { isEndingAccess = false }
        do {
            try await OversightEndFlow.run(
                wait: { try await OversightEndFlow.waitUntilIdle(isBusy: { self.isSyncing }) },
                revoke: {
                    // Re-read after the prior operation finishes: it may just have created a share.
                    let current = store.data.therapistOversight
                    let zoneID = CKRecordZone.ID(
                        zoneName: current.cloudZoneName ?? CloudContract.zoneName,
                        ownerName: CKCurrentUserDefaultName
                    )
                    let shareID = CKRecord.ID(
                        recordName: current.cloudShareRecordName ?? CKRecordNameZoneWideShare,
                        zoneID: zoneID
                    )
                    self.endAccessStatus = "Revoking therapist access…"
                    self.isSyncing = true
                    defer { self.isSyncing = false }
                    // Verify server absence even for incomplete setup: lack of local metadata
                    // alone is not proof that an in-flight save never created a share.
                    try await self.revokeOwnerShare(shareID)
                },
                finish: {
                    self.cancellationGeneration &+= 1
                    store.endTherapistOversight(queueRemoteNotice: false)
                    store.setTherapistTransport(.notConfigured)
                    self.preparedShare = nil
                    self.lastError = nil
                    self.accessLabel = "Not Invited"
                    self.shareStatusMessage = "Access Ended"
                    self.endAccessStatus = "Access ended. Your Bull history is unchanged."
                }
            )
            return true
        } catch {
            let message = error is OversightEndError
                ? error.localizedDescription
                : "Could not confirm that access ended. Risk Controls remain protected. " + userFacingMessage(for: error)
            lastError = message
            endAccessStatus = message
            store.setTherapistTransport(.error, error: message)
            return false
        }
    }

    private func revokeOwnerShare(_ shareID: CKRecord.ID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let completion = RevocationCompletion(continuation)
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [shareID])
            let configuration = CKOperation.Configuration()
            configuration.qualityOfService = .userInitiated
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 25
            operation.configuration = configuration
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    completion.finish(.success(Void()))
                case .failure(let error):
                    if Self.confirmsMissingShare(error, shareID: shareID) {
                        completion.finish(.success(Void()))
                    } else { completion.finish(.failure(error)) }
                }
            }
            privateDatabase.add(operation)
            // The resource timer begins on execution; also bound time spent queued.
            Task {
                try? await Task<Never, Never>.sleep(for: .seconds(30))
                if completion.finish(.failure(OversightEndError.timedOut)) {
                    operation.cancel()
                }
            }
        }
    }

    nonisolated static func confirmsMissingShare(_ error: Error, shareID: CKRecord.ID) -> Bool {
        guard let error = error as? CKError else { return false }
        if error.code == .unknownItem || error.code == .zoneNotFound { return true }
        // A partial failure is success only when the exact requested share is absent.
        guard error.code == .partialFailure,
              let failures = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
              failures.count == 1,
              let targetError = failures[shareID] as? CKError else { return false }
        return targetError.code == .unknownItem || targetError.code == .zoneNotFound
    }

    func sharingControllerSaved(store: BullStore) {
        guard !isEndingAccess, store.therapistOversightIsEnabled else { return }
        if let share = preparedShare?.share { updateAccessLabel(from: share) }
        store.setTherapistTransport(.ready)
        shareStatusMessage = accessLabel == "Active"
            ? "Therapist Access Is Active"
            : "Invite Saved · Waiting for Acceptance"
    }

    func sharingControllerDismissed() {
        preparedShare = nil
    }

    func sharingControllerFailed(_ error: Error) {
        lastError = userFacingMessage(for: error)
        shareStatusMessage = "Invite Not Sent"
    }

    func sharingControllerStopped(store: BullStore) {
        guard !isEndingAccess else { return }
        // UICloudSharingController has already revoked the share at this point.
        cancellationGeneration &+= 1
        store.endTherapistOversight(queueRemoteNotice: false)
        preparedShare = nil
        accessLabel = "Not Invited"
        shareStatusMessage = "Access Ended"
    }

    @discardableResult
    func stopReceiving(store: BullStore) async -> Bool {
        guard !isSyncing, store.data.therapistOversight.role == .therapist else { return false }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await requireAvailableAccount()
            let zoneIDs = try await sharedZoneIDs()
            guard zoneIDs.count <= 1 else {
                throw TherapistCloudError.multipleClientShares(zoneIDs.count)
            }
            if let zoneID = zoneIDs.first {
                let shareID = CKRecord.ID(
                    recordName: CKRecordNameZoneWideShare,
                    zoneID: zoneID
                )
                _ = try await sharedDatabase.deleteRecord(withID: shareID)
            }
            _ = try? await sharedDatabase.deleteSubscription(
                withID: CloudContract.sharedSubscriptionID
            )
            store.clearTherapistRole()
            lastError = nil
            return true
        } catch let error as CKError where error.code == .unknownItem {
            _ = try? await sharedDatabase.deleteSubscription(
                withID: CloudContract.sharedSubscriptionID
            )
            store.clearTherapistRole()
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func requireAvailableAccount() async throws {
        let status = try await container.accountStatus()
        guard status == .available else {
            await refreshAccountStatus()
            throw TherapistCloudError.iCloudUnavailable(accountLabel)
        }
        accountLabel = "iCloud Ready"
    }

    private func operationIsCurrent(_ generation: UInt, store: BullStore) -> Bool {
        guard generation == cancellationGeneration else { return false }
        let state = store.data.therapistOversight.state
        return state == .invitationReady || state == .active
    }

    private func discardUnconfirmedOwnerZone(_ zoneID: CKRecordZone.ID) async {
        _ = try? await privateDatabase.deleteSubscription(
            withID: CloudContract.ownerSubscriptionID
        )
        _ = try? await privateDatabase.deleteRecordZone(withID: zoneID)
    }

    private func ownerZoneID(for store: BullStore) -> CKRecordZone.ID {
        CKRecordZone.ID(
            zoneName: store.data.therapistOversight.cloudZoneName ?? CloudContract.zoneName,
            ownerName: CKCurrentUserDefaultName
        )
    }

    private func ensureOwnerZone(_ zoneID: CKRecordZone.ID) async throws {
        do {
            _ = try await privateDatabase.recordZone(for: zoneID)
        } catch let error as CKError where error.code == .zoneNotFound {
            _ = try await privateDatabase.save(CKRecordZone(zoneID: zoneID))
        }
    }

    private func existingOrNewShare(zoneID: CKRecordZone.ID) async throws -> CKShare {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        do {
            guard let existing = try await privateDatabase.record(for: shareID) as? CKShare else {
                throw TherapistCloudError.invalidShare
            }
            return existing
        } catch let error as CKError where error.code == .unknownItem {
            // Create below.
        }
        let share = CKShare(recordZoneID: zoneID)
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.title] = "Bull Therapist Oversight" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "com.ahmed.bull.therapist-oversight" as CKRecordValue
        guard let saved = try await privateDatabase.save(share) as? CKShare else {
            throw TherapistCloudError.invalidShare
        }
        return saved
    }

    private func publishOwnerPayload(
        store: BullStore,
        zoneID: CKRecordZone.ID
    ) async throws {
        let queued = store.data.therapistOutboxEvents
            .filter { $0.deliveryState != .published }
            .sorted { $0.ts > $1.ts }
        let publishedRecent = store.data.therapistOutboxEvents
            .filter { $0.deliveryState == .published }
            .sorted { $0.ts > $1.ts }
        let events = Array((queued + publishedRecent).prefix(300))
        let payload = TherapistSharedPayload(
            projection: store.therapistProjection(),
            events: events.map(sanitizedSharedEvent)
        )
        let bytes = try encoder.encode(payload)
        try validateSharedPayload(bytes)
        guard bytes.count <= 900_000 else { throw TherapistCloudError.payloadTooLarge }
        let recordID = CKRecord.ID(
            recordName: CloudContract.snapshotRecordName,
            zoneID: zoneID
        )
        let record = try await fetchOrCreate(
            database: privateDatabase,
            recordType: CloudContract.snapshotRecordType,
            recordID: recordID
        )
        record.encryptedValues[CloudContract.encryptedPayloadKey] = bytes as NSData
        record[CloudContract.schemaVersionKey] = 1 as CKRecordValue
        record[CloudContract.updatedAtKey] = Date() as CKRecordValue
        _ = try await privateDatabase.save(record)
        store.markTherapistOutboxPublished(eventIDs: Set(
            events.filter { $0.deliveryState != .published }.map(\.id)
        ))
    }

    private func receiveTherapistDecisions(
        store: BullStore,
        zoneID: CKRecordZone.ID
    ) async throws -> Bool {
        let decisions = try await fetchDecisions(database: privateDatabase, zoneID: zoneID)
        return store.applyTherapistRiskDecisions(decisions)
    }

    private func updateAcceptedParticipantState(
        store: BullStore,
        zoneID: CKRecordZone.ID
    ) async throws {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        guard let share = try await privateDatabase.record(for: shareID) as? CKShare else { return }
        let invited = share.participants.filter {
            $0.role != .owner && $0.acceptanceStatus != .removed
        }
        guard invited.count <= 1 else {
            throw TherapistCloudError.multipleTherapists(invited.count)
        }
        updateAccessLabel(from: share)
        if invited.first?.acceptanceStatus == .accepted {
            store.markTherapistConnectionActive()
        } else {
            store.markTherapistConnectionPending()
        }
    }

    private func updateAccessLabel(from share: CKShare) {
        let invited = share.participants.filter {
            $0.role != .owner && $0.acceptanceStatus != .removed
        }
        if invited.contains(where: { $0.acceptanceStatus == .accepted }) {
            accessLabel = "Active"
        } else if invited.isEmpty {
            accessLabel = "Not Invited"
        } else {
            accessLabel = "Pending"
        }
    }

    private func receiveSharedPayload(
        store: BullStore,
        notifications: NotificationService
    ) async throws {
        let zoneIDs = try await sharedZoneIDs()
        guard !zoneIDs.isEmpty else { throw TherapistCloudError.noSharedOversight }
        guard zoneIDs.count == 1 else {
            throw TherapistCloudError.multipleClientShares(zoneIDs.count)
        }
        let zoneID = zoneIDs[0]
        let recordID = CKRecord.ID(
            recordName: CloudContract.snapshotRecordName,
            zoneID: zoneID
        )
        let record: CKRecord
        do {
            record = try await sharedDatabase.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            throw TherapistCloudError.sharedPayloadUnavailable
        }
        guard let bytes = encryptedData(record, key: CloudContract.encryptedPayloadKey) else {
            throw TherapistCloudError.invalidSharedPayload
        }
        var payload: TherapistSharedPayload
        do {
            guard bytes.count <= 900_000 else { throw TherapistCloudError.payloadTooLarge }
            payload = try decoder.decode(TherapistSharedPayload.self, from: bytes)
            guard payload.schemaVersion == 1, payload.projection.schemaVersion == 1 else {
                throw TherapistCloudError.invalidSharedPayload
            }
        } catch {
            throw TherapistCloudError.invalidSharedPayload
        }
        // A saved review remains reviewed while the owner's next snapshot catches up.
        // Match the whole proposal, and never override an applied/cancelled owner result.
        let decisions = try await fetchDecisions(database: sharedDatabase, zoneID: zoneID)
        payload.projection.pendingRiskChanges = mergingTherapistDecisions(
            decisions, into: payload.projection.pendingRiskChanges
        )
        let storedWatermark = store.data.therapistOversight.lastRemoteEventTs
        let initialBaseline = store.data.therapistOversight.consentedTs ??
            Date().timeIntervalSince1970 * 1_000
        var unseen: [TherapistOversightEvent]
        if let storedWatermark {
            unseen = payload.events.filter { $0.ts > storedWatermark }
        } else {
            // First sync shows the 90-day history in the dashboard but must not turn that
            // history into a burst of old lock-screen notifications. Current zone presence
            // is the exception: it always receives one warning.
            unseen = payload.events.filter { $0.ts >= initialBaseline }
            for zone in payload.projection.riskZones where zone.enabled {
                guard let entry = payload.projection.zoneEvents
                    .filter({ $0.zoneID == zone.id })
                    .max(by: { $0.ts < $1.ts }),
                    entry.kind == .entered else { continue }
                if let currentWarning = payload.events
                    .filter({
                        $0.zoneID == zone.id &&
                            ($0.kind == .zoneEntered || $0.kind == .zoneStillActive)
                    })
                    .max(by: { $0.ts < $1.ts }) {
                    unseen.append(currentWarning)
                } else {
                    unseen.append(TherapistOversightEvent(
                        id: "current-zone.\(entry.id)",
                        kind: .zoneStillActive,
                        ts: Date().timeIntervalSince1970 * 1_000,
                        dayKey: entry.dayKey,
                        zoneID: zone.id,
                        zoneName: zone.name,
                        message: zone.resolutionMode == .exitRequired
                            ? "Take action before you regret it! Your client is in a Risk Zone that can only be resolved by leaving."
                            : "Take action before you regret it! Your client is in a configured Risk Zone.",
                        requiresAttention: true,
                        deduplicationKey: "current-zone.\(entry.id)"
                    ))
                }
            }
            unseen = Array(Dictionary(grouping: unseen, by: \.id).values.compactMap(\.first))
        }
        unseen.sort { $0.ts < $1.ts }
        var notificationWatermark = storedWatermark ?? 0
        var deliveredAll = true
        for event in unseen {
            if event.requiresAttention {
                guard await notifications.scheduleTherapistAlert(event) else {
                    deliveredAll = false
                    break
                }
            }
            notificationWatermark = max(notificationWatermark, event.ts)
        }
        let savedWatermark: Double?
        if storedWatermark == nil {
            savedWatermark = deliveredAll
                ? max(initialBaseline, payload.events.map(\.ts).max() ?? 0)
                : nil
        } else {
            savedWatermark = notificationWatermark
        }
        store.cacheTherapistProjection(
            payload.projection,
            events: payload.events,
            remoteEventTs: savedWatermark
        )
    }

    private func sharedZoneIDs() async throws -> [CKRecordZone.ID] {
        try await sharedDatabase.allRecordZones()
            .map(\.zoneID)
            .filter { $0.zoneName == CloudContract.zoneName }
    }

    private func ensureSharedDatabaseSubscription() async throws {
        let subscriptions = try await sharedDatabase.allSubscriptions()
        guard !subscriptions.contains(where: { $0.subscriptionID == CloudContract.sharedSubscriptionID }) else {
            return
        }
        let subscription = CKDatabaseSubscription(subscriptionID: CloudContract.sharedSubscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        _ = try await sharedDatabase.save(subscription)
    }

    private func ensureOwnerZoneSubscription(_ zoneID: CKRecordZone.ID) async throws {
        let subscriptions = try await privateDatabase.allSubscriptions()
        guard !subscriptions.contains(where: { $0.subscriptionID == CloudContract.ownerSubscriptionID }) else {
            return
        }
        let subscription = CKRecordZoneSubscription(
            zoneID: zoneID,
            subscriptionID: CloudContract.ownerSubscriptionID
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        _ = try await privateDatabase.save(subscription)
    }

    private func fetchDecisions(
        database: CKDatabase,
        zoneID: CKRecordZone.ID
    ) async throws -> [TherapistRiskChangeRecord] {
        let recordID = CKRecord.ID(
            recordName: CloudContract.decisionsRecordName,
            zoneID: zoneID
        )
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return []
        }
        guard let bytes = encryptedData(record, key: CloudContract.encryptedPayloadKey) else {
            throw TherapistCloudError.invalidDecisionPayload
        }
        do {
            guard bytes.count <= 900_000 else { throw TherapistCloudError.invalidDecisionPayload }
            let payload = try decoder.decode(TherapistDecisionPayload.self, from: bytes)
            guard payload.schemaVersion == 1 else { throw TherapistCloudError.invalidDecisionPayload }
            return payload.decisions
        } catch {
            throw TherapistCloudError.invalidDecisionPayload
        }
    }

    private func saveDecisions(
        _ decisions: [TherapistRiskChangeRecord],
        database: CKDatabase,
        zoneID: CKRecordZone.ID
    ) async throws {
        let recordID = CKRecord.ID(
            recordName: CloudContract.decisionsRecordName,
            zoneID: zoneID
        )
        let record = try await fetchOrCreate(
            database: database,
            recordType: CloudContract.decisionsRecordType,
            recordID: recordID
        )
        let retained = Array(decisions.sorted { lhs, rhs in
            (lhs.reviewedTs ?? lhs.requestedTs) > (rhs.reviewedTs ?? rhs.requestedTs)
        }.prefix(300))
        let payload = TherapistDecisionPayload(decisions: retained)
        let bytes = try encoder.encode(payload)
        try validateSharedPayload(bytes)
        guard bytes.count <= 900_000 else { throw TherapistCloudError.payloadTooLarge }
        record.encryptedValues[CloudContract.encryptedPayloadKey] = bytes as NSData
        record[CloudContract.schemaVersionKey] = 1 as CKRecordValue
        record[CloudContract.updatedAtKey] = Date() as CKRecordValue
        _ = try await database.save(record)
    }

    private func fetchOrCreate(
        database: CKDatabase,
        recordType: CKRecord.RecordType,
        recordID: CKRecord.ID
    ) async throws -> CKRecord {
        do {
            return try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return CKRecord(recordType: recordType, recordID: recordID)
        }
    }

    private func encryptedData(_ record: CKRecord, key: String) -> Data? {
        if let data = record.encryptedValues[key] as? Data { return data }
        if let data = record.encryptedValues[key] as? NSData { return data as Data }
        return nil
    }

    private func sanitizedSharedEvent(_ source: TherapistOversightEvent) -> TherapistOversightEvent {
        var event = source
        event.deliveryState = .published
        event.deliveryAttempts = 0
        event.lastDeliveryTs = nil
        event.lastDeliveryError = nil
        return event
    }

    private func validateSharedPayload(_ data: Data) throws {
        let forbidden: Set<String> = [
            "latitude", "longitude", "note", "therapyNote", "nextAction",
            "triggerIDs", "triggers", "bullRoutine", "bullState", "vigour",
            "dailySexualObservations", "wakeErectionObservations",
            "ejaculatoryControlObservations", "manualExerciseLogs",
            "strengthWorkoutLogs", "healthSamples"
        ]
        let object = try JSONSerialization.jsonObject(with: data)
        var discovered = Set<String>()
        func visit(_ value: Any) {
            if let dictionary = value as? [String: Any] {
                for (key, child) in dictionary {
                    if forbidden.contains(key) { discovered.insert(key) }
                    visit(child)
                }
            } else if let array = value as? [Any] {
                array.forEach(visit)
            }
        }
        visit(object)
        guard discovered.isEmpty else {
            throw TherapistCloudError.scopeViolation(discovered.sorted().joined(separator: ", "))
        }
    }

    private func fail(_ error: Error, store: BullStore) {
        let message = userFacingMessage(for: error)
        lastError = message
        store.setTherapistTransport(.error, error: message)
    }

    private func markOwnerOutboxFailed(_ error: Error, store: BullStore) {
        let ids = Set(store.data.therapistOutboxEvents
            .filter { $0.deliveryState != .published }
            .map(\.id))
        guard !ids.isEmpty else { return }
        store.markTherapistOutboxFailed(
            eventIDs: ids,
            error: userFacingMessage(for: error)
        )
    }

    private func userFacingMessage(for error: Error) -> String {
        if let cloudError = error as? CKError, cloudError.code == .quotaExceeded {
            return "iCloud still reports that storage is full. Confirm that free space is visible in Settings, wait a few minutes for iCloud to update, then try again."
        }
        return error.localizedDescription
    }
}

private enum TherapistCloudError: LocalizedError {
    case iCloudUnavailable(String)
    case invalidShare
    case noSharedOversight
    case payloadTooLarge
    case multipleTherapists(Int)
    case multipleClientShares(Int)
    case scopeViolation(String)
    case roleConflict
    case sharedPayloadUnavailable
    case invalidSharedPayload
    case invalidDecisionPayload

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable(let status):
            return "Therapist sharing needs an available iCloud account. Current status: \(status)."
        case .invalidShare:
            return "Bull could not create the private therapist share."
        case .noSharedOversight:
            return "No accepted Bull therapist share is available in iCloud."
        case .payloadTooLarge:
            return "The therapist projection exceeded Bull’s 900 KB safety limit."
        case .multipleTherapists(let count):
            return "Bull Therapist Oversight supports one therapist. This share has \(count) participants; remove the extra access in Manage Access."
        case .multipleClientShares(let count):
            return "This Bull install supports one client share. It found \(count); remove the extra Bull share before continuing."
        case .scopeViolation(let fields):
            return "Bull blocked therapist sync because the shared payload contained fields outside the approved scope: \(fields)."
        case .roleConflict:
            return "This Bull install is already protecting an owner account. End that oversight before accepting a client share."
        case .sharedPayloadUnavailable:
            return "The therapist share exists, but its Bull snapshot is not available yet. Keep both devices online and retry."
        case .invalidSharedPayload:
            return "Bull kept the therapist connection but could not read its encrypted snapshot. Retry before relying on oversight."
        case .invalidDecisionPayload:
            return "Bull kept current Risk Controls because it could not read the therapist decision record. Retry sync."
        }
    }
}

struct TherapistShareSheet: UIViewControllerRepresentable {
    let item: TherapistCloudShare
    let onSaved: () -> Void
    let onStopped: () -> Void
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSaved: onSaved, onStopped: onStopped, onError: onError)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: item.share, container: item.container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) { }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onSaved: () -> Void
        let onStopped: () -> Void
        let onError: (Error) -> Void

        init(
            onSaved: @escaping () -> Void,
            onStopped: @escaping () -> Void,
            onError: @escaping (Error) -> Void
        ) {
            self.onSaved = onSaved
            self.onStopped = onStopped
            self.onError = onError
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Bull Therapist Oversight"
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onSaved()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onStopped()
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            onError(error)
        }
    }
}
