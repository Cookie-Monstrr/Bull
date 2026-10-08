import Foundation

// MARK: - Therapist safeguard oversight

public enum TherapistOversightRole: String, Codable, Sendable {
    case owner
    case therapist
}

public enum TherapistOversightState: String, Codable, Sendable {
    case off
    case invitationReady
    case active
    case ended
}

public enum TherapistTransportState: String, Codable, Sendable {
    case notConfigured
    case preparing
    case ready
    case syncing
    case error
}

/// Consent and transport metadata only. The shared clinical projection is deliberately
/// separate from Bull's full backup so unrelated sexual-health and HealthKit data can never
/// be exposed by adding a new screen to the therapist client.
public struct TherapistOversightConfiguration: Codable, Equatable, Sendable {
    public var role: TherapistOversightRole
    public var state: TherapistOversightState
    public var transportState: TherapistTransportState
    public var consentVersion: Int
    public var consentedTs: Double?
    public var endedTs: Double?
    public var cloudZoneName: String?
    public var cloudShareRecordName: String?
    public var lastSyncTs: Double?
    public var lastRemoteEventTs: Double?
    public var lastTransportError: String?

    public init(
        role: TherapistOversightRole = .owner,
        state: TherapistOversightState = .off,
        transportState: TherapistTransportState = .notConfigured,
        consentVersion: Int = 0,
        consentedTs: Double? = nil,
        endedTs: Double? = nil,
        cloudZoneName: String? = nil,
        cloudShareRecordName: String? = nil,
        lastSyncTs: Double? = nil,
        lastRemoteEventTs: Double? = nil,
        lastTransportError: String? = nil
    ) {
        self.role = role
        self.state = state
        self.transportState = transportState
        self.consentVersion = max(0, consentVersion)
        self.consentedTs = consentedTs
        self.endedTs = endedTs
        self.cloudZoneName = cloudZoneName
        self.cloudShareRecordName = cloudShareRecordName
        self.lastSyncTs = lastSyncTs
        self.lastRemoteEventTs = lastRemoteEventTs
        self.lastTransportError = lastTransportError
    }

    public var protectsRiskControls: Bool {
        role == .owner && (state == .invitationReady || state == .active)
    }
}

public enum TherapistEventKind: String, Codable, CaseIterable, Sendable {
    case zoneEntered
    case zoneStillActive
    case zoneExited
    case relapseLogged
    case riskControlChangeRequested
    case monitoringUnavailable
    case oversightEnded
}

public enum TherapistEventDeliveryState: String, Codable, Sendable {
    case queued
    case published
    case failed
}

/// A minimal, notification-safe event. It never contains coordinates, notes, HealthKit
/// samples, Bull/Vigour scores, or free-form relapse detail.
public struct TherapistOversightEvent: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var kind: TherapistEventKind
    public var ts: Double
    public var dayKey: String
    public var zoneID: String?
    public var zoneName: String?
    public var relapseID: String?
    public var changeRequestID: String?
    public var message: String
    public var requiresAttention: Bool
    public var deduplicationKey: String
    public var deliveryState: TherapistEventDeliveryState
    public var deliveryAttempts: Int
    public var lastDeliveryTs: Double?
    public var lastDeliveryError: String?

    public init(
        id: String = UUID().uuidString,
        kind: TherapistEventKind,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        zoneID: String? = nil,
        zoneName: String? = nil,
        relapseID: String? = nil,
        changeRequestID: String? = nil,
        message: String,
        requiresAttention: Bool,
        deduplicationKey: String,
        deliveryState: TherapistEventDeliveryState = .queued,
        deliveryAttempts: Int = 0,
        lastDeliveryTs: Double? = nil,
        lastDeliveryError: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.ts = ts
        self.dayKey = dayKey
        self.zoneID = zoneID
        self.zoneName = zoneName
        self.relapseID = relapseID
        self.changeRequestID = changeRequestID
        self.message = message
        self.requiresAttention = requiresAttention
        self.deduplicationKey = deduplicationKey
        self.deliveryState = deliveryState
        self.deliveryAttempts = max(0, deliveryAttempts)
        self.lastDeliveryTs = lastDeliveryTs
        self.lastDeliveryError = lastDeliveryError
    }
}

public enum RiskControlChangeKind: String, Codable, Sendable {
    case updateZone
    case deleteZone
    case alertRepeatMinutes
    case timeSensitiveAlerts
}

public enum RiskControlChangeStatus: String, Codable, Sendable {
    case pending
    case approved
    case rejected
    case cancelled
    case applied
}

public struct RiskControlChangeRequest: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: RiskControlChangeKind
    public var zoneID: String?
    public var currentZone: HighRiskZone?
    public var proposedZone: HighRiskZone?
    public var currentIntegerValue: Int?
    public var proposedIntegerValue: Int?
    public var currentBooleanValue: Bool?
    public var proposedBooleanValue: Bool?
    public var summary: String
    public var requestedTs: Double
    public var status: RiskControlChangeStatus
    public var reviewedTs: Double?
    public var appliedTs: Double?
    /// A short structured choice such as "Approved" or "Discuss first". Free-form
    /// therapy notes are intentionally outside the shared data contract.
    public var reviewerDecision: String?

    public init(
        id: String = UUID().uuidString,
        kind: RiskControlChangeKind,
        zoneID: String? = nil,
        currentZone: HighRiskZone? = nil,
        proposedZone: HighRiskZone? = nil,
        currentIntegerValue: Int? = nil,
        proposedIntegerValue: Int? = nil,
        currentBooleanValue: Bool? = nil,
        proposedBooleanValue: Bool? = nil,
        summary: String,
        requestedTs: Double = Date().timeIntervalSince1970 * 1_000,
        status: RiskControlChangeStatus = .pending,
        reviewedTs: Double? = nil,
        appliedTs: Double? = nil,
        reviewerDecision: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.zoneID = zoneID
        self.currentZone = currentZone
        self.proposedZone = proposedZone
        self.currentIntegerValue = currentIntegerValue
        self.proposedIntegerValue = proposedIntegerValue
        self.currentBooleanValue = currentBooleanValue
        self.proposedBooleanValue = proposedBooleanValue
        self.summary = summary
        self.requestedTs = requestedTs
        self.status = status
        self.reviewedTs = reviewedTs
        self.appliedTs = appliedTs
        self.reviewerDecision = reviewerDecision
    }
}

public enum RiskControlChangeClassification: String, Codable, Sendable {
    case protectionIncreasing
    case noProtectionChange
    case therapistReviewRequired
}

public enum RiskControlMutationResult: Equatable, Sendable {
    case applied
    case pendingApproval(requestID: String)
    case rejected(reason: String)
}

public enum TherapistAccessAuditKind: String, Codable, Sendable {
    case consentGranted
    case sharePrepared
    case shareAccepted
    case projectionPublished
    case riskChangeReviewed
    case oversightEnded
    case transportFailed
}

public struct TherapistAccessAuditEvent: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var kind: TherapistAccessAuditKind
    public var ts: Double
    public var detail: String?

    public init(
        id: String = UUID().uuidString,
        kind: TherapistAccessAuditKind,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        detail: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.ts = ts
        self.detail = detail
    }
}

// MARK: - Explicit therapist projection

public struct TherapistUrgeScore: Codable, Equatable, Sendable, Identifiable {
    public var id: String { dayKey }
    public var dayKey: String
    public var urgeRoutine: Double?
    public var urgeState: Double?
    public var recordedTs: Double
    public var isFinal: Bool
    public var revision: Int
}

public struct TherapistRelapseRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var dayKey: String
    public var occurrenceTs: Double?
    public var loggedTs: Double
    public var components: [LapseComponent]
    public var riskZoneID: String?
}

public struct TherapistRiskAlertRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var ts: Double
    public var dayKey: String
    public var source: RiskAlertSource
    public var tier: PressureTier
    public var zoneID: String?
    public var deliveryState: AlertDeliveryState
    public var acknowledgedTs: Double?
    public var action: AlertUserAction?
    public var completedTs: Double?
    public var laterOutcomes: [RiskAlertOutcome]
}

/// A coordinate-free Risk Zone transition. Bull's internal ZoneEvent also carries a
/// legacy base-risk field; that field is deliberately absent from therapist sharing.
public struct TherapistZoneEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var zoneID: String
    public var kind: ZoneEventKind
    public var ts: Double
    public var dayKey: String
}

/// Risk-control settings without the geofence centre. A therapist can see and review every
/// weakening change while exact coordinates remain owner-only.
public struct TherapistRiskZoneRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var radiusMetres: Double
    public var riskLevel: ZoneRiskLevel
    public var enabled: Bool
    public var activeDays: [Int]
    public var startMinute: Int
    public var endMinute: Int
    public var scheduleMode: ZoneScheduleMode
    public var minutesAllowedAfterFinalWake: Int
    public var minutesAllowedBeforeBed: Int
    public var activateWhenUnexpectedlyAwake: Bool
    public var resolutionMode: ZoneResolutionMode
    public var safeguardInstruction: String?
    public var safeguardDefinitionVersion: Int
    public var timeZoneIdentifier: String?
}

public struct TherapistMonitoringStatus: Codable, Equatable, Sendable {
    public var locationStatus: String
    public var notificationsAllowed: Bool
    public var timeSensitiveEnabled: Bool
    public var monitoredZoneCount: Int
    public var expectedZoneCount: Int
    public var failedZoneCount: Int
    public var updatedTs: Double

    public init(
        locationStatus: String = "Unknown",
        notificationsAllowed: Bool = false,
        timeSensitiveEnabled: Bool = false,
        monitoredZoneCount: Int = 0,
        expectedZoneCount: Int = 0,
        failedZoneCount: Int = 0,
        updatedTs: Double = Date().timeIntervalSince1970 * 1_000
    ) {
        self.locationStatus = locationStatus
        self.notificationsAllowed = notificationsAllowed
        self.timeSensitiveEnabled = timeSensitiveEnabled
        self.monitoredZoneCount = max(0, monitoredZoneCount)
        self.expectedZoneCount = max(0, expectedZoneCount)
        self.failedZoneCount = max(0, failedZoneCount)
        self.updatedTs = updatedTs
    }
}

public struct TherapistRiskChangeRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: RiskControlChangeKind
    public var zoneID: String?
    public var currentZone: TherapistRiskZoneRecord?
    public var proposedZone: TherapistRiskZoneRecord?
    public var currentIntegerValue: Int?
    public var proposedIntegerValue: Int?
    public var currentBooleanValue: Bool?
    public var proposedBooleanValue: Bool?
    public var summary: String
    public var requestedTs: Double
    public var status: RiskControlChangeStatus
    public var reviewedTs: Double?
    public var reviewerDecision: String?
}

/// The only Bull payload written to the shared CloudKit zone. The type has no fields for
/// Bull Routine, Bull State, Vigour, sexual health, workouts, HealthKit samples or notes.
public struct TherapistProjection: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var generatedTs: Double
    public var urgeScores: [TherapistUrgeScore]
    public var urgeObservations: [PornUrgeObservation]
    public var relapses: [TherapistRelapseRecord]
    public var riskZones: [TherapistRiskZoneRecord]
    public var zoneEvents: [TherapistZoneEvent]
    public var riskAlerts: [TherapistRiskAlertRecord]
    public var pendingRiskChanges: [TherapistRiskChangeRecord]
    public var zoneAlertRepeatMinutes: Int
    public var timeSensitiveAlerts: Bool
    public var monitoring: TherapistMonitoringStatus

    public init(
        schemaVersion: Int = 1,
        generatedTs: Double = Date().timeIntervalSince1970 * 1_000,
        urgeScores: [TherapistUrgeScore] = [],
        urgeObservations: [PornUrgeObservation] = [],
        relapses: [TherapistRelapseRecord] = [],
        riskZones: [TherapistRiskZoneRecord] = [],
        zoneEvents: [TherapistZoneEvent] = [],
        riskAlerts: [TherapistRiskAlertRecord] = [],
        pendingRiskChanges: [TherapistRiskChangeRecord] = [],
        zoneAlertRepeatMinutes: Int = 30,
        timeSensitiveAlerts: Bool = false,
        monitoring: TherapistMonitoringStatus = TherapistMonitoringStatus()
    ) {
        self.schemaVersion = max(1, schemaVersion)
        self.generatedTs = generatedTs
        self.urgeScores = urgeScores
        self.urgeObservations = urgeObservations
        self.relapses = relapses
        self.riskZones = riskZones
        self.zoneEvents = zoneEvents
        self.riskAlerts = riskAlerts
        self.pendingRiskChanges = pendingRiskChanges
        self.zoneAlertRepeatMinutes = min(180, max(15, zoneAlertRepeatMinutes))
        self.timeSensitiveAlerts = timeSensitiveAlerts
        self.monitoring = monitoring
    }
}
