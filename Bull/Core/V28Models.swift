import Foundation

// MARK: - Evidence and provenance

/// Evidence is always tied to the narrow outcome named by a factor. None of these
/// labels validates Bull's numerical Risk weights.
public enum FactorEvidenceStatus: String, Codable, CaseIterable, Sendable {
    case establishedForStatedOutcome
    case directButLimitedPMO
    case indirectPlausible
    case religiouslyGrounded
    case personalExperiment
    case contextOrOutcome
    case productPolicy

    public var label: String {
        switch self {
        case .establishedForStatedOutcome: return "Established for stated outcome"
        case .directButLimitedPMO: return "Direct but limited PMO evidence"
        case .indirectPlausible: return "Indirect"
        case .religiouslyGrounded: return "Religiously grounded"
        case .personalExperiment: return "Personal experiment"
        case .contextOrOutcome: return "Context or outcome"
        case .productPolicy: return "Product policy"
        }
    }
}

public enum ObservationSource: String, Codable, CaseIterable, Hashable, Sendable {
    case live
    case delayedRecall
    case prospectiveEdit
    case retrospectiveBackfill
    case migratedLegacy
    case automaticHealthKit
}

public enum FieldConfidence: String, Codable, CaseIterable, Sendable {
    case exact
    case approximate
    case unknown
}

// MARK: - Explicit adherence

public enum CompletionState: String, Codable, CaseIterable, Sendable {
    case done
    case notDone
    case excused
    case unknown

    public var label: String {
        switch self {
        case .done: return "Done"
        case .notDone: return "Not Done"
        case .excused: return "Excused"
        case .unknown: return "Unknown"
        }
    }
}

public enum CompletionExcuse: String, Codable, CaseIterable, Sendable {
    case sick
    case travelling
    case fasting
    case other

    public var label: String {
        switch self {
        case .sick: return "Sick"
        case .travelling: return "Travelling"
        case .fasting: return "Fasting"
        case .other: return "Other"
        }
    }
}

public struct CompletionRecord: Codable, Equatable, Sendable {
    public var state: CompletionState
    public var excuse: CompletionExcuse?
    public var loggedTs: Double?
    public var source: ObservationSource
    /// Links a completion to the factor definition the user actually observed.
    /// Nil is retained for migrated history that predates definition versioning.
    public var definitionVersion: Int?

    public init(
        state: CompletionState = .unknown,
        excuse: CompletionExcuse? = nil,
        loggedTs: Double? = nil,
        source: ObservationSource = .live,
        definitionVersion: Int? = nil
    ) {
        self.state = state
        self.excuse = state == .excused ? excuse : nil
        self.loggedTs = loggedTs
        self.source = source
        self.definitionVersion = definitionVersion.map { max(1, $0) }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = (try? c.decode(CompletionState.self, forKey: .state)) ?? .unknown
        let decodedExcuse = try? c.decodeIfPresent(CompletionExcuse.self, forKey: .excuse)
        excuse = state == .excused ? decodedExcuse : nil
        loggedTs = try? c.decodeIfPresent(Double.self, forKey: .loggedTs)
        source = (try? c.decode(ObservationSource.self, forKey: .source)) ?? .migratedLegacy
        definitionVersion = (try? c.decodeIfPresent(Int.self, forKey: .definitionVersion))
            .map { max(1, $0) }
    }
}

// MARK: - Morning commitment

public struct MorningCommitment: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var what: String
    public var when: String
    public var whereText: String
    public var committedTs: Double?
    public var completion: CompletionRecord
    public var perceivedPurpose: Int?
    public var source: ObservationSource

    public init(
        id: String = UUID().uuidString,
        what: String,
        when: String = "",
        whereText: String = "",
        committedTs: Double? = Date().timeIntervalSince1970 * 1_000,
        completion: CompletionRecord = CompletionRecord(),
        perceivedPurpose: Int? = nil,
        source: ObservationSource = .live
    ) {
        self.id = id
        self.what = what
        self.when = when
        self.whereText = whereText
        self.committedTs = committedTs
        self.completion = completion
        self.perceivedPurpose = perceivedPurpose.map { min(5, max(1, $0)) }
        self.source = source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        what = (try? c.decode(String.self, forKey: .what)) ?? ""
        when = (try? c.decode(String.self, forKey: .when)) ?? ""
        whereText = (try? c.decode(String.self, forKey: .whereText)) ?? ""
        committedTs = try? c.decodeIfPresent(Double.self, forKey: .committedTs)
        completion = (try? c.decode(CompletionRecord.self, forKey: .completion)) ?? CompletionRecord(
            source: .migratedLegacy
        )
        perceivedPurpose = (try? c.decodeIfPresent(Int.self, forKey: .perceivedPurpose))
            .map { min(5, max(1, $0)) }
        source = (try? c.decode(ObservationSource.self, forKey: .source)) ?? .migratedLegacy
    }
}

// MARK: - Lapse occurrence metadata

public enum LapseTimePrecision: String, Codable, CaseIterable, Sendable {
    case exact
    case approximate
    case partOfDay
    case unknown

    public var label: String {
        switch self {
        case .exact: return "Exact"
        case .approximate: return "Approximate"
        case .partOfDay: return "Part of day"
        case .unknown: return "I don't remember"
        }
    }
}

public enum LapseDayPart: String, Codable, CaseIterable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    public var label: String { rawValue.capitalized }
}

public enum LapseLocationPrecision: String, Codable, CaseIterable, Sendable {
    case riskZone
    case namedPlace
    case approximatePlace
    case elsewhere
    case unknown

    public var label: String {
        switch self {
        case .riskZone: return "Linked Risk Zone"
        case .namedPlace: return "Other named place"
        case .approximatePlace: return "Approximate place"
        case .elsewhere: return "Elsewhere"
        case .unknown: return "I don't remember"
        }
    }
}

public struct LapseOccurrenceMetadata: Codable, Equatable, Sendable {
    public var occurrenceDayKey: String
    public var occurrenceTs: Double?
    public var occurrenceEndTs: Double?
    public var timePrecision: LapseTimePrecision
    public var dayPart: LapseDayPart?
    public var locationPrecision: LapseLocationPrecision
    public var zoneID: String?
    public var placeName: String?
    public var timeZoneIdentifier: String?
    public var utcOffsetMinutes: Int?
    public var source: ObservationSource
    public var timeConfidence: FieldConfidence
    public var locationConfidence: FieldConfidence

    public init(
        occurrenceDayKey: String,
        occurrenceTs: Double? = nil,
        occurrenceEndTs: Double? = nil,
        timePrecision: LapseTimePrecision = .unknown,
        dayPart: LapseDayPart? = nil,
        locationPrecision: LapseLocationPrecision = .unknown,
        zoneID: String? = nil,
        placeName: String? = nil,
        timeZoneIdentifier: String? = nil,
        utcOffsetMinutes: Int? = nil,
        source: ObservationSource = .live,
        timeConfidence: FieldConfidence = .unknown,
        locationConfidence: FieldConfidence = .unknown
    ) {
        self.occurrenceDayKey = occurrenceDayKey
        self.occurrenceTs = occurrenceTs
        self.occurrenceEndTs = occurrenceEndTs
        self.timePrecision = timePrecision
        self.dayPart = timePrecision == .partOfDay ? dayPart : nil
        self.locationPrecision = locationPrecision
        self.zoneID = locationPrecision == .riskZone ? zoneID : nil
        self.placeName = [.namedPlace, .approximatePlace].contains(locationPrecision) ? placeName : nil
        self.timeZoneIdentifier = timeZoneIdentifier
        self.utcOffsetMinutes = utcOffsetMinutes
        self.source = source
        self.timeConfidence = timeConfidence
        self.locationConfidence = locationConfidence
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        occurrenceDayKey = (try? c.decode(String.self, forKey: .occurrenceDayKey)) ?? ""
        occurrenceTs = try? c.decodeIfPresent(Double.self, forKey: .occurrenceTs)
        occurrenceEndTs = try? c.decodeIfPresent(Double.self, forKey: .occurrenceEndTs)
        timePrecision = (try? c.decode(LapseTimePrecision.self, forKey: .timePrecision)) ?? .unknown
        let decodedPart = try? c.decodeIfPresent(LapseDayPart.self, forKey: .dayPart)
        dayPart = timePrecision == .partOfDay ? decodedPart : nil
        locationPrecision = (try? c.decode(LapseLocationPrecision.self, forKey: .locationPrecision)) ?? .unknown
        let decodedZoneID = try? c.decodeIfPresent(String.self, forKey: .zoneID)
        zoneID = locationPrecision == .riskZone ? decodedZoneID : nil
        let decodedPlace = try? c.decodeIfPresent(String.self, forKey: .placeName)
        placeName = [.namedPlace, .approximatePlace].contains(locationPrecision) ? decodedPlace : nil
        timeZoneIdentifier = try? c.decodeIfPresent(String.self, forKey: .timeZoneIdentifier)
        utcOffsetMinutes = try? c.decodeIfPresent(Int.self, forKey: .utcOffsetMinutes)
        source = (try? c.decode(ObservationSource.self, forKey: .source)) ?? .migratedLegacy
        timeConfidence = (try? c.decode(FieldConfidence.self, forKey: .timeConfidence)) ?? .unknown
        locationConfidence = (try? c.decode(FieldConfidence.self, forKey: .locationConfidence)) ?? .unknown
    }
}

// MARK: - Daily sexual-health observations

public enum MorningErectionObservation: String, Codable, CaseIterable, Sendable {
    case yes
    case no
    case notObserved

    public var label: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        case .notObserved: return "Not observed"
        }
    }
}

public struct DailySexualObservation: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var dayKey: String
    public var morningErection: MorningErectionObservation
    public var erectionQuality: Int?
    /// Erection Hardness Score (EHS), 1...4. This is the v2.9 observation. The legacy
    /// 0...10 `erectionQuality` field remains intact for lossless v2.8 history.
    public var erectionHardnessScore: Int?
    /// Healthy sexual desire, 0...10, explicitly separate from porn-specific urge.
    public var healthyDesire: Int?
    public var source: ObservationSource

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        morningErection: MorningErectionObservation,
        erectionQuality: Int? = nil,
        erectionHardnessScore: Int? = nil,
        healthyDesire: Int? = nil,
        source: ObservationSource = .live
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.morningErection = morningErection
        self.erectionQuality = erectionQuality.map { min(10, max(0, $0)) }
        self.erectionHardnessScore = morningErection == .yes
            ? erectionHardnessScore.map { min(4, max(1, $0)) }
            : nil
        self.healthyDesire = healthyDesire.map { min(10, max(0, $0)) }
        self.source = source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        ts = (try? c.decode(Double.self, forKey: .ts)) ?? Date().timeIntervalSince1970 * 1_000
        dayKey = (try? c.decode(String.self, forKey: .dayKey)) ?? ""
        morningErection = (try? c.decode(MorningErectionObservation.self, forKey: .morningErection)) ?? .notObserved
        erectionQuality = (try? c.decodeIfPresent(Int.self, forKey: .erectionQuality))
            .map { min(10, max(0, $0)) }
        erectionHardnessScore = morningErection == .yes
            ? (try? c.decodeIfPresent(Int.self, forKey: .erectionHardnessScore))
                .map { min(4, max(1, $0)) }
            : nil
        healthyDesire = (try? c.decodeIfPresent(Int.self, forKey: .healthyDesire))
            .map { min(10, max(0, $0)) }
        source = (try? c.decode(ObservationSource.self, forKey: .source)) ?? .migratedLegacy
    }
}

public struct LibidoSpot: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var dayKey: String
    public var rating: Int
    public var source: ObservationSource

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        rating: Int,
        source: ObservationSource = .live
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.rating = min(10, max(0, rating))
        self.source = source
    }
}

public struct SexualWeekSummary: Equatable, Sendable {
    public var observedMornings: Int
    public var yesMornings: Int
    public var unknownMornings: Int
    public var erectionHealth: Double?
    public var libidoSpotCount: Int
    public var averageLibido: Double?

    public init(
        observedMornings: Int,
        yesMornings: Int,
        unknownMornings: Int,
        erectionHealth: Double?,
        libidoSpotCount: Int,
        averageLibido: Double?
    ) {
        self.observedMornings = observedMornings
        self.yesMornings = yesMornings
        self.unknownMornings = unknownMornings
        self.erectionHealth = erectionHealth
        self.libidoSpotCount = libidoSpotCount
        self.averageLibido = averageLibido
    }
}

// MARK: - Risk Zone safeguards and events

public struct ZoneSafeguardDefinition: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var instruction: String
    public var note: String?
    public var definitionVersion: Int

    public init(
        id: String = UUID().uuidString,
        instruction: String,
        note: String? = nil,
        definitionVersion: Int = 1
    ) {
        self.id = id
        self.instruction = instruction
        self.note = note
        self.definitionVersion = max(1, definitionVersion)
    }
}

public enum SafeguardEventKind: String, Codable, CaseIterable, Sendable {
    case promptIssued
    case deliveryObserved
    case opened
    case actionSelected
    case completed
    case snoozed
    case corrected
    case reversed
    case visitEnded
}

public struct SafeguardEvent: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var zoneID: String
    public var safeguardID: String
    public var kind: SafeguardEventKind
    public var ts: Double
    public var occurrenceTs: Double
    public var loggedTs: Double
    public var dayKey: String
    public var alertEventID: String?
    public var note: String?
    public var source: ObservationSource
    /// Optional for backward-compatible decoding. New events always persist the mode that
    /// applied when the prompt or action occurred.
    public var resolutionMode: ZoneResolutionMode?

    public var effectiveResolutionMode: ZoneResolutionMode {
        resolutionMode ?? .safeguard
    }

    public init(
        id: String = UUID().uuidString,
        zoneID: String,
        safeguardID: String,
        kind: SafeguardEventKind,
        occurrenceTs: Double = Date().timeIntervalSince1970 * 1_000,
        loggedTs: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        alertEventID: String? = nil,
        note: String? = nil,
        source: ObservationSource = .live,
        resolutionMode: ZoneResolutionMode = .safeguard
    ) {
        self.id = id
        self.zoneID = zoneID
        self.safeguardID = safeguardID
        self.kind = kind
        self.ts = occurrenceTs
        self.occurrenceTs = occurrenceTs
        self.loggedTs = loggedTs
        self.dayKey = dayKey
        self.alertEventID = alertEventID
        self.note = note
        self.source = source
        self.resolutionMode = resolutionMode
    }
}

// MARK: - Shared Risk alert architecture

public enum RiskAlertSource: String, Codable, Sendable {
    case compoundedRisk
    case riskZoneEntry
    case riskZoneScheduleStart
    case riskZoneFollowUp
}

public enum AlertDeliveryState: String, Codable, Sendable {
    case attempted
    case scheduled
    case observedForeground
    case failed
    case replaced
    case cancelled
}

public enum AlertUserAction: String, Codable, Sendable {
    case opened
    case startResponse
    case openRiskPlan
    case safeguardDone
    case snooze
    case dismissed
}

public enum RiskAlertOutcome: String, Codable, Hashable, Sendable {
    case urgeLogged
    case responseImproved
    case responseNotImproved
    case lapseLogged
    case visitEnded
}

public struct RiskAlertEvent: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var dayKey: String
    public var source: RiskAlertSource
    public var tier: PressureTier
    public var zoneID: String?
    public var safeguardID: String?
    public var route: String
    public var leadingContributors: [String]
    public var scoringVersion: Int
    public var deliveryState: AlertDeliveryState
    public var deliveryMessage: String?
    public var acknowledgedTs: Double?
    public var action: AlertUserAction?
    public var linkedUrgeID: String?
    public var selectedInterventionIDs: [String]
    public var completedTs: Double?
    public var laterOutcomes: [RiskAlertOutcome]
    public var laterOutcomeTs: Double?
    public var snoozedUntilTs: Double?
    public var cooldownUntilTs: Double?
    public var replacedByEventID: String?

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        source: RiskAlertSource,
        tier: PressureTier,
        zoneID: String? = nil,
        safeguardID: String? = nil,
        route: String,
        leadingContributors: [String] = [],
        scoringVersion: Int,
        deliveryState: AlertDeliveryState = .attempted,
        deliveryMessage: String? = nil,
        acknowledgedTs: Double? = nil,
        action: AlertUserAction? = nil,
        linkedUrgeID: String? = nil,
        selectedInterventionIDs: [String] = [],
        completedTs: Double? = nil,
        laterOutcomes: [RiskAlertOutcome] = [],
        laterOutcomeTs: Double? = nil,
        snoozedUntilTs: Double? = nil,
        cooldownUntilTs: Double? = nil,
        replacedByEventID: String? = nil
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.source = source
        self.tier = tier
        self.zoneID = zoneID
        self.safeguardID = safeguardID
        self.route = route
        self.leadingContributors = leadingContributors
        self.scoringVersion = scoringVersion
        self.deliveryState = deliveryState
        self.deliveryMessage = deliveryMessage
        self.acknowledgedTs = acknowledgedTs
        self.action = action
        self.linkedUrgeID = linkedUrgeID
        self.selectedInterventionIDs = selectedInterventionIDs
        self.completedTs = completedTs
        self.laterOutcomes = laterOutcomes
        self.laterOutcomeTs = laterOutcomeTs
        self.snoozedUntilTs = snoozedUntilTs
        self.cooldownUntilTs = cooldownUntilTs
        self.replacedByEventID = replacedByEventID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        ts = try c.decode(Double.self, forKey: .ts)
        dayKey = try c.decode(String.self, forKey: .dayKey)
        source = (try? c.decode(RiskAlertSource.self, forKey: .source)) ?? .compoundedRisk
        tier = (try? c.decode(PressureTier.self, forKey: .tier)) ?? .normal
        zoneID = try? c.decodeIfPresent(String.self, forKey: .zoneID)
        safeguardID = try? c.decodeIfPresent(String.self, forKey: .safeguardID)
        route = try c.decode(String.self, forKey: .route)
        leadingContributors = (try? c.decode([String].self, forKey: .leadingContributors)) ?? []
        scoringVersion = (try? c.decode(Int.self, forKey: .scoringVersion)) ?? 0
        deliveryState = (try? c.decode(AlertDeliveryState.self, forKey: .deliveryState)) ?? .attempted
        deliveryMessage = try? c.decodeIfPresent(String.self, forKey: .deliveryMessage)
        acknowledgedTs = try? c.decodeIfPresent(Double.self, forKey: .acknowledgedTs)
        action = try? c.decodeIfPresent(AlertUserAction.self, forKey: .action)
        linkedUrgeID = try? c.decodeIfPresent(String.self, forKey: .linkedUrgeID)
        selectedInterventionIDs = (try? c.decode([String].self, forKey: .selectedInterventionIDs)) ?? []
        completedTs = try? c.decodeIfPresent(Double.self, forKey: .completedTs)
        laterOutcomes = (try? c.decode([RiskAlertOutcome].self, forKey: .laterOutcomes)) ?? []
        laterOutcomeTs = try? c.decodeIfPresent(Double.self, forKey: .laterOutcomeTs)
        snoozedUntilTs = try? c.decodeIfPresent(Double.self, forKey: .snoozedUntilTs)
        cooldownUntilTs = try? c.decodeIfPresent(Double.self, forKey: .cooldownUntilTs)
        replacedByEventID = try? c.decodeIfPresent(String.self, forKey: .replacedByEventID)
    }
}

public enum AlertRoute: Equatable, Sendable, Identifiable {
    case risk(eventID: String)
    case zone(zoneID: String, safeguardID: String, eventID: String)

    public var value: String {
        switch self {
        case .risk(let eventID):
            return "bull://risk/\(eventID)"
        case .zone(let zoneID, let safeguardID, let eventID):
            return "bull://zone/\(zoneID)/\(safeguardID)/\(eventID)"
        }
    }

    public var id: String { value }

    public init?(value: String) {
        let parts = value.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.first == "bull:" else { return nil }
        if parts.count == 3, parts[1] == "risk" {
            self = .risk(eventID: parts[2])
        } else if parts.count == 5, parts[1] == "zone" {
            self = .zone(zoneID: parts[2], safeguardID: parts[3], eventID: parts[4])
        } else {
            return nil
        }
    }
}

public enum AlertPolicyDecision: Equatable, Sendable {
    case deliver
    case replace(eventID: String)
    case suppressCooldown
    case suppressAcknowledged
    case suppressDuplicate
}

// MARK: - Weekly coaching

public enum WeeklyGoalCategory: String, Codable, CaseIterable, Sendable {
    case healthRoutine
    case preventionSafeguard

    public var label: String {
        switch self {
        case .healthRoutine: return "Health"
        case .preventionSafeguard: return "Prevention"
        }
    }
}

public enum WeeklyGoalDecision: String, Codable, Sendable {
    case proposed
    case accepted
    case edited
    case rejected
}

public struct WeeklyGoal: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var category: WeeklyGoalCategory
    public var factorID: String
    public var title: String
    public var rationale: String
    public var baselineDone: Int
    public var baselineOpportunities: Int
    public var target: Int
    public var startDayKey: String
    public var endDayKey: String
    public var ifThenWhat: String
    public var ifThenWhen: String
    public var ifThenWhere: String
    public var decision: WeeklyGoalDecision
    public var decidedTs: Double?

    public init(
        id: String = UUID().uuidString,
        category: WeeklyGoalCategory,
        factorID: String,
        title: String,
        rationale: String,
        baselineDone: Int,
        baselineOpportunities: Int,
        target: Int,
        startDayKey: String,
        endDayKey: String,
        ifThenWhat: String = "",
        ifThenWhen: String = "",
        ifThenWhere: String = "",
        decision: WeeklyGoalDecision = .proposed,
        decidedTs: Double? = nil
    ) {
        self.id = id
        self.category = category
        self.factorID = factorID
        self.title = title
        self.rationale = rationale
        self.baselineDone = max(0, baselineDone)
        self.baselineOpportunities = max(0, baselineOpportunities)
        self.target = max(0, target)
        self.startDayKey = startDayKey
        self.endDayKey = endDayKey
        self.ifThenWhat = ifThenWhat
        self.ifThenWhen = ifThenWhen
        self.ifThenWhere = ifThenWhere
        self.decision = decision
        self.decidedTs = decidedTs
    }
}

public struct WeeklyGoalReview: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var goalID: String
    public var weekEndDayKey: String
    public var completed: Int
    public var opportunities: Int
    public var userNote: String?
    public var reviewedTs: Double

    public init(
        id: String = UUID().uuidString,
        goalID: String,
        weekEndDayKey: String,
        completed: Int,
        opportunities: Int,
        userNote: String? = nil,
        reviewedTs: Double = Date().timeIntervalSince1970 * 1_000
    ) {
        self.id = id
        self.goalID = goalID
        self.weekEndDayKey = weekEndDayKey
        self.opportunities = max(0, opportunities)
        self.completed = min(max(0, completed), self.opportunities)
        self.userNote = userNote
        self.reviewedTs = reviewedTs
    }
}

// MARK: - Controlled personal experiments

public enum PersonalFactorKind: String, Codable, CaseIterable, Sendable {
    case action
    case context
    case outcome
}

public enum PersonalFactorOutcome: String, Codable, CaseIterable, Sendable {
    case lapse
    case highUrge
    case safeguardCompletion
    case bullStrength
    case sexualHealth
    case wellbeing

    public var label: String {
        switch self {
        case .lapse: return "Lapse"
        case .highUrge: return "High urge"
        case .safeguardCompletion: return "Safeguard completion"
        case .bullStrength: return "Bull strength"
        case .sexualHealth: return "Sexual-health outcome"
        case .wellbeing: return "Wellbeing"
        }
    }
}

public struct PersonalFactor: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var kind: PersonalFactorKind
    public var intendedOutcome: PersonalFactorOutcome
    public var hypothesis: String
    public var scheduleDescription: String
    public var startDayKey: String
    public var evidenceStatus: FactorEvidenceStatus
    public var definitionVersion: Int
    public var archived: Bool
    public var aliases: [String]
    /// Personal factors are deliberately unweighted in v2.8.
    public var scoringWeight: Int?

    public init(
        id: String = UUID().uuidString,
        name: String,
        kind: PersonalFactorKind,
        intendedOutcome: PersonalFactorOutcome,
        hypothesis: String,
        scheduleDescription: String,
        startDayKey: String,
        evidenceStatus: FactorEvidenceStatus = .personalExperiment,
        definitionVersion: Int = 1,
        archived: Bool = false,
        aliases: [String] = [],
        scoringWeight: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.intendedOutcome = intendedOutcome
        self.hypothesis = hypothesis
        self.scheduleDescription = scheduleDescription
        self.startDayKey = startDayKey
        self.evidenceStatus = evidenceStatus
        self.definitionVersion = max(1, definitionVersion)
        self.archived = archived
        self.aliases = aliases
        self.scoringWeight = nil
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? "Personal experiment"
        kind = (try? c.decode(PersonalFactorKind.self, forKey: .kind)) ?? .action
        intendedOutcome = (try? c.decode(PersonalFactorOutcome.self, forKey: .intendedOutcome)) ?? .highUrge
        hypothesis = (try? c.decode(String.self, forKey: .hypothesis)) ?? ""
        scheduleDescription = (try? c.decode(String.self, forKey: .scheduleDescription)) ?? ""
        startDayKey = (try? c.decode(String.self, forKey: .startDayKey)) ?? ""
        evidenceStatus = (try? c.decode(FactorEvidenceStatus.self, forKey: .evidenceStatus)) ?? .personalExperiment
        definitionVersion = max(1, (try? c.decode(Int.self, forKey: .definitionVersion)) ?? 1)
        archived = (try? c.decode(Bool.self, forKey: .archived)) ?? false
        aliases = (try? c.decode([String].self, forKey: .aliases)) ?? []
        scoringWeight = nil
    }
}

public struct AdherenceSummary: Equatable, Sendable {
    public var done: Int
    public var notDone: Int
    public var excused: Int
    public var unknown: Int

    public init(done: Int = 0, notDone: Int = 0, excused: Int = 0, unknown: Int = 0) {
        self.done = done
        self.notDone = notDone
        self.excused = excused
        self.unknown = unknown
    }

    public var answered: Int { done + notDone + excused }
    public var observedOpportunities: Int { done + notDone }
    public var adherence: Double? {
        guard observedOpportunities > 0 else { return nil }
        return Double(done) / Double(observedOpportunities)
    }
}
