import Foundation

// MARK: - Lapse policy

public enum LapseComponent: String, Codable, CaseIterable, Hashable, Sendable {
    case porn
    case masturbation
    case orgasm

    public var label: String {
        switch self {
        case .porn: return "Porn"
        case .masturbation: return "Masturbation"
        case .orgasm: return "Deliberate orgasm"
        }
    }
}

public struct LapsePolicy: Codable, Equatable, Sendable {
    public var pornCounts: Bool
    public var masturbationCounts: Bool
    public var orgasmCounts: Bool

    public init(pornCounts: Bool = true, masturbationCounts: Bool = true, orgasmCounts: Bool = true) {
        self.pornCounts = pornCounts
        self.masturbationCounts = masturbationCounts
        self.orgasmCounts = orgasmCounts
    }

    public func counts(_ components: Set<LapseComponent>) -> Bool {
        (pornCounts && components.contains(.porn)) ||
        (masturbationCounts && components.contains(.masturbation)) ||
        (orgasmCounts && components.contains(.orgasm))
    }
}

// MARK: - Stable Trigger and Response libraries

public struct TriggerDefinition: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var archived: Bool
    public var aliases: [String]
    public var createdTs: Double

    public init(
        id: String = UUID().uuidString,
        name: String,
        archived: Bool = false,
        aliases: [String] = [],
        createdTs: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.name = name
        self.archived = archived
        self.aliases = aliases
        self.createdTs = createdTs
    }
}

public enum ResponseEvidence: String, Codable, CaseIterable, Sendable {
    case personal
    case indirect
    case established

    public var label: String {
        switch self {
        case .personal: return "Personal hypothesis"
        case .indirect: return "Indirect evidence"
        case .established: return "Evidence supported"
        }
    }
}

/// v2.9 separates actions taken during elevated risk from actions used after a lapse.
/// Nil is the lossless meaning for a legacy/custom response that has not been classified.
public enum ProtectiveActionLane: String, Codable, CaseIterable, Sendable {
    case prevention
    case countermove
    case damageControl
}

public enum InterventionHelpfulness: String, Codable, CaseIterable, Sendable {
    case notReally
    case somewhat
    case clearly

    public var label: String {
        switch self {
        case .notReally: return "Not really"
        case .somewhat: return "Somewhat"
        case .clearly: return "Clearly"
        }
    }
}

public struct ResponseDefinition: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var archived: Bool
    public var aliases: [String]
    public var evidence: ResponseEvidence
    public var protectionWeight: Weight
    public var protectionMinutes: Int
    public var lane: ProtectiveActionLane?
    public var createdTs: Double

    public init(
        id: String = UUID().uuidString,
        name: String,
        archived: Bool = false,
        aliases: [String] = [],
        evidence: ResponseEvidence = .personal,
        protectionWeight: Weight = .med,
        protectionMinutes: Int = 120,
        lane: ProtectiveActionLane? = nil,
        createdTs: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.name = name
        self.archived = archived
        self.aliases = aliases
        self.evidence = evidence
        self.protectionWeight = protectionWeight
        self.protectionMinutes = max(15, protectionMinutes)
        self.lane = lane
        self.createdTs = createdTs
    }
}

public enum UrgeIntensity: Int, Codable, CaseIterable, Comparable, Sendable {
    case low = 1
    case medium = 2
    case high = 3

    public static func < (lhs: UrgeIntensity, rhs: UrgeIntensity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

/// One completed or abandoned attempt to use a protective Response. Merely selecting
/// an action never earns Protection; `completedTs` and an observed intensity reduction
/// are both required by the scoring layer.
public struct ResponseAttempt: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var urgeID: String?
    public var responseID: String
    public var ts: Double
    public var completedTs: Double?
    public var intensityBefore: UrgeIntensity?
    public var intensityAfter: UrgeIntensity?
    public var stressBefore: Int?
    public var stressAfter: Int?
    public var dayKey: String?
    /// When set, this was a plan selected before the action had time to work. Completion and
    /// helpfulness are captured only in the later follow-up.
    public var followUpDueTs: Double?
    public var followUpRecordedTs: Double?
    public var helpfulness: InterventionHelpfulness?
    public var actionLane: ProtectiveActionLane?

    public init(
        id: String = UUID().uuidString,
        urgeID: String? = nil,
        responseID: String,
        ts: Double = Date().timeIntervalSince1970 * 1000,
        completedTs: Double? = nil,
        intensityBefore: UrgeIntensity? = nil,
        intensityAfter: UrgeIntensity? = nil,
        stressBefore: Int? = nil,
        stressAfter: Int? = nil,
        dayKey: String? = nil,
        followUpDueTs: Double? = nil,
        followUpRecordedTs: Double? = nil,
        helpfulness: InterventionHelpfulness? = nil,
        actionLane: ProtectiveActionLane? = nil
    ) {
        self.id = id
        self.urgeID = urgeID
        self.responseID = responseID
        self.ts = ts
        self.completedTs = completedTs
        self.intensityBefore = intensityBefore
        self.intensityAfter = intensityAfter
        self.stressBefore = stressBefore.map { min(10, max(0, $0)) }
        self.stressAfter = stressAfter.map { min(10, max(0, $0)) }
        self.dayKey = dayKey
        self.followUpDueTs = followUpDueTs
        self.followUpRecordedTs = followUpRecordedTs
        self.helpfulness = helpfulness
        self.actionLane = actionLane
    }

    public var reducedUrge: Bool {
        guard let before = intensityBefore, let after = intensityAfter else { return false }
        return after < before
    }
}

// MARK: - Sexual-health outcomes

public struct AccountabilityCheckIn: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var scheduledTs: Double
    public var attended: Bool
    public var dayKey: String

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        scheduledTs: Double,
        attended: Bool,
        dayKey: String
    ) {
        self.id = id
        self.ts = ts
        self.scheduledTs = scheduledTs
        self.attended = attended
        self.dayKey = dayKey
    }
}

public struct SexualCheckIn: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var dayKey: String
    /// 0...7 mornings with a spontaneous erection in the preceding week.
    public var morningErections: Int
    /// Optional 0...10 erection quality when there was an observable erection.
    public var erectionQuality: Int?
    public var libido: Int
    public var readiness: Int
    public var confidence: Int

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1000,
        dayKey: String,
        morningErections: Int,
        erectionQuality: Int?,
        libido: Int,
        readiness: Int,
        confidence: Int
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.morningErections = min(7, max(0, morningErections))
        self.erectionQuality = erectionQuality.map { min(10, max(0, $0)) }
        self.libido = min(10, max(0, libido))
        self.readiness = min(10, max(0, readiness))
        self.confidence = min(10, max(0, confidence))
    }

    public var erectionHealth: Double {
        let morning = Double(morningErections) / 7 * 100
        guard let erectionQuality else { return morning }
        return (morning + Double(erectionQuality) * 10) / 2
    }

    public var libidoReadiness: Double {
        Double(libido + readiness + confidence) / 3 * 10
    }
}

// MARK: - High-risk contexts

public enum ZoneRiskLevel: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high

    public var label: String { rawValue.capitalized }
    public var points: Int {
        switch self {
        case .low: return 5
        case .medium: return 10
        case .high: return 20
        }
    }
}

public enum ZoneScheduleMode: String, Codable, CaseIterable, Sendable {
    case fixed
    case sleepAnchored

    public var label: String {
        switch self {
        case .fixed: return "Fixed Hours"
        case .sleepAnchored: return "Layla Sleep Schedule"
        }
    }
}

/// How an active Risk Zone can be resolved while the person remains inside it.
/// Legacy zones default to a concrete safeguard. `exitRequired` is intentionally
/// stricter: no in-app action can mark the place safe; only a recorded zone exit ends it.
public enum ZoneResolutionMode: String, Codable, CaseIterable, Sendable {
    case safeguard
    case exitRequired

    public var label: String {
        switch self {
        case .safeguard: return "Complete Safeguard"
        case .exitRequired: return "Leave Zone"
        }
    }
}

/// Trusted, versioned schedule state supplied by Layla. Bull stores each accepted snapshot
/// in its protected backup model. Live snapshots arrive through the narrow App Group bridge
/// in `LaylaScheduleBridge.swift`; no raw HealthKit samples or Risk Zone details cross it.
public enum LaylaSleepState: String, Codable, Sendable {
    case sleeping
    case plannedBriefWake
    case upForDay
    case unexpectedlyAwake
}

public struct LaylaSleepScheduleSnapshot: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var dayKey: String
    public var plannedFinalWakeTs: Double
    public var plannedBedtimeTs: Double
    public var actualFinalWakeTs: Double?
    public var expectedReturnToSleepByTs: Double?
    /// Layla-owned deviation from the user's planned bed/wake schedule for the night that
    /// ended on `dayKey`. Bull converts it into the versioned consistency component.
    public var sleepConsistencyDeviationMinutes: Double?
    public var state: LaylaSleepState
    /// When Layla most recently observed the state transition represented by `state`.
    /// This is especially important for a planned brief wake before the final-wake time.
    public var stateObservedTs: Double?
    public var updatedTs: Double
    /// Civil-time authority used by Layla when it produced `dayKey` and the plan.
    public var timeZoneIdentifier: String?
    /// Monotonic writer sequence copied from the shared transport envelope. Older Bull
    /// backups legitimately omit it; all new bridge-delivered records include it.
    public var sourceSequence: Int64?
    /// Bundle that wrote the shared envelope. Optional only for pre-bridge backups.
    public var sourceBundleIdentifier: String?
    public var sourceIdentifier: String
    public var sourceVersion: Int

    public init(
        id: String = UUID().uuidString,
        dayKey: String,
        plannedFinalWakeTs: Double,
        plannedBedtimeTs: Double,
        actualFinalWakeTs: Double? = nil,
        expectedReturnToSleepByTs: Double? = nil,
        sleepConsistencyDeviationMinutes: Double? = nil,
        state: LaylaSleepState,
        stateObservedTs: Double? = nil,
        updatedTs: Double = Date().timeIntervalSince1970 * 1_000,
        timeZoneIdentifier: String? = nil,
        sourceSequence: Int64? = nil,
        sourceBundleIdentifier: String? = nil,
        sourceIdentifier: String = "layla",
        sourceVersion: Int = 1
    ) {
        self.id = id
        self.dayKey = dayKey
        self.plannedFinalWakeTs = plannedFinalWakeTs
        self.plannedBedtimeTs = plannedBedtimeTs
        self.actualFinalWakeTs = actualFinalWakeTs
        self.expectedReturnToSleepByTs = expectedReturnToSleepByTs
        self.sleepConsistencyDeviationMinutes = sleepConsistencyDeviationMinutes.map {
            min(720, max(0, $0))
        }
        self.state = state
        self.stateObservedTs = stateObservedTs
        self.updatedTs = updatedTs
        self.timeZoneIdentifier = timeZoneIdentifier
        self.sourceSequence = sourceSequence
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceIdentifier = sourceIdentifier
        self.sourceVersion = sourceVersion
    }

    public func isTrustedAndCurrent(at date: Date) -> Bool {
        guard sourceIdentifier == "layla", sourceVersion >= 1,
              sourceSequence.map({ $0 >= 1 }) ?? true,
              timeZoneIdentifier.map({ TimeZone(identifier: $0) != nil }) ?? true,
              plannedBedtimeTs > plannedFinalWakeTs else { return false }
        let nowMS = date.timeIntervalSince1970 * 1_000
        guard updatedTs <= nowMS + 5 * 60_000,
              nowMS - updatedTs <= 36 * 3_600_000 else { return false }
        // One schedule can cover the preceding sleep episode through the next bedtime.
        return nowMS >= plannedFinalWakeTs - 12 * 3_600_000 &&
            nowMS <= plannedBedtimeTs + 6 * 3_600_000
    }
}

public struct HighRiskZone: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var radiusMetres: Double
    public var riskLevel: ZoneRiskLevel
    public var enabled: Bool
    /// JavaScript weekday convention: 0 = Sunday ... 6 = Saturday. Empty means every day.
    public var activeDays: [Int]
    /// Minutes after midnight. Equal start/end means active all day.
    public var startMinute: Int
    public var endMinute: Int
    /// v3.2 can replace fixed hours with Layla's actual final wake and planned bedtime.
    /// Fixed hours remain the safe fallback whenever no current trusted snapshot exists.
    public var scheduleMode: ZoneScheduleMode
    public var minutesAllowedAfterFinalWake: Int
    public var minutesAllowedBeforeBed: Int
    public var activateWhenUnexpectedlyAwake: Bool
    public var onlyWhenRiskAtLeast: Int?
    /// Preserved only so an old export can explain its former behaviour. v2.8 never uses
    /// this value to suppress early safeguards or place Risk.
    public var legacyOnlyWhenRiskAtLeast: Int?
    /// v3.3 supports places where there is no credible in-place safeguard.
    public var resolutionMode: ZoneResolutionMode
    public var safeguard: ZoneSafeguardDefinition
    /// When false, notification copy omits the configured place name on the lock screen.
    public var showNameOnLockScreen: Bool
    /// Schedules use the place's configured civil time rather than changing meaning when
    /// the user travels between London, Cairo, or another time zone.
    public var timeZoneIdentifier: String?
    public var createdTs: Double

    public init(
        id: String = UUID().uuidString,
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMetres: Double = 150,
        riskLevel: ZoneRiskLevel = .high,
        enabled: Bool = true,
        activeDays: [Int] = [],
        startMinute: Int = 0,
        endMinute: Int = 0,
        scheduleMode: ZoneScheduleMode = .fixed,
        minutesAllowedAfterFinalWake: Int = 90,
        minutesAllowedBeforeBed: Int = 90,
        activateWhenUnexpectedlyAwake: Bool = true,
        onlyWhenRiskAtLeast: Int? = nil,
        legacyOnlyWhenRiskAtLeast: Int? = nil,
        resolutionMode: ZoneResolutionMode = .safeguard,
        safeguard: ZoneSafeguardDefinition? = nil,
        showNameOnLockScreen: Bool = false,
        timeZoneIdentifier: String? = TimeZone.current.identifier,
        createdTs: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMetres = min(500, max(75, radiusMetres))
        self.riskLevel = riskLevel
        self.enabled = enabled
        self.activeDays = activeDays.filter { (0...6).contains($0) }
        self.startMinute = min(1_439, max(0, startMinute))
        self.endMinute = min(1_439, max(0, endMinute))
        self.scheduleMode = scheduleMode
        self.minutesAllowedAfterFinalWake = min(240, max(15, minutesAllowedAfterFinalWake))
        self.minutesAllowedBeforeBed = min(240, max(15, minutesAllowedBeforeBed))
        self.activateWhenUnexpectedlyAwake = activateWhenUnexpectedlyAwake
        self.onlyWhenRiskAtLeast = onlyWhenRiskAtLeast.map { min(100, max(0, $0)) }
        self.legacyOnlyWhenRiskAtLeast = legacyOnlyWhenRiskAtLeast
        self.resolutionMode = resolutionMode
        self.safeguard = safeguard ?? ZoneSafeguardDefinition(
            id: "safeguard.\(id)",
            instruction: "Leave the risky context and open Bull"
        )
        self.showNameOnLockScreen = showNameOnLockScreen
        self.timeZoneIdentifier = timeZoneIdentifier
        self.createdTs = createdTs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? "Risk Zone"
        latitude = (try? c.decode(Double.self, forKey: .latitude)) ?? 0
        longitude = (try? c.decode(Double.self, forKey: .longitude)) ?? 0
        radiusMetres = min(500, max(75, (try? c.decode(Double.self, forKey: .radiusMetres)) ?? 150))
        riskLevel = (try? c.decode(ZoneRiskLevel.self, forKey: .riskLevel)) ?? .high
        enabled = (try? c.decode(Bool.self, forKey: .enabled)) ?? true
        activeDays = ((try? c.decode([Int].self, forKey: .activeDays)) ?? [])
            .filter { (0...6).contains($0) }
        startMinute = min(1_439, max(0, (try? c.decode(Int.self, forKey: .startMinute)) ?? 0))
        endMinute = min(1_439, max(0, (try? c.decode(Int.self, forKey: .endMinute)) ?? 0))
        scheduleMode = (try? c.decode(ZoneScheduleMode.self, forKey: .scheduleMode)) ?? .fixed
        minutesAllowedAfterFinalWake = min(
            240,
            max(15, (try? c.decode(Int.self, forKey: .minutesAllowedAfterFinalWake)) ?? 90)
        )
        minutesAllowedBeforeBed = min(
            240,
            max(15, (try? c.decode(Int.self, forKey: .minutesAllowedBeforeBed)) ?? 90)
        )
        activateWhenUnexpectedlyAwake =
            (try? c.decode(Bool.self, forKey: .activateWhenUnexpectedlyAwake)) ?? true
        onlyWhenRiskAtLeast = (try? c.decodeIfPresent(Int.self, forKey: .onlyWhenRiskAtLeast))
            .map { min(100, max(0, $0)) }
        legacyOnlyWhenRiskAtLeast = (try? c.decodeIfPresent(Int.self, forKey: .legacyOnlyWhenRiskAtLeast))
            ?? onlyWhenRiskAtLeast
        resolutionMode = (try? c.decode(ZoneResolutionMode.self, forKey: .resolutionMode)) ?? .safeguard
        safeguard = (try? c.decode(ZoneSafeguardDefinition.self, forKey: .safeguard)) ??
            ZoneSafeguardDefinition(
                id: "safeguard.\(id)",
                instruction: "Leave the risky context and open Bull"
            )
        showNameOnLockScreen = (try? c.decode(Bool.self, forKey: .showNameOnLockScreen)) ?? false
        timeZoneIdentifier = try? c.decodeIfPresent(String.self, forKey: .timeZoneIdentifier)
        createdTs = (try? c.decode(Double.self, forKey: .createdTs)) ??
            Date().timeIntervalSince1970 * 1_000
    }

    public func isScheduled(at date: Date, calendar: Calendar = .current) -> Bool {
        scheduledIntervals(on: date, calendar: calendar).contains {
            date >= $0.start && date < $0.end
        }
    }

    /// Effective risk state for a sleep-anchored zone. Sleeping and a planned brief Fajr
    /// wake remain outside risk; an unexpected final wake starts the configured getting-
    /// ready allowance immediately. Outside the post-wake and pre-bed allowances, the zone
    /// is active. Missing/untrusted Layla data always falls back to the fixed schedule.
    public func isActive(
        at date: Date,
        sleepSchedule: LaylaSleepScheduleSnapshot?,
        calendar: Calendar = .current
    ) -> Bool {
        guard scheduleMode == .sleepAnchored,
              let sleepSchedule,
              sleepSchedule.isTrustedAndCurrent(at: date) else {
            return isScheduled(at: date, calendar: calendar)
        }

        switch sleepSchedule.state {
        case .sleeping:
            return false
        case .plannedBriefWake:
            if let deadline = sleepSchedule.expectedReturnToSleepByTs,
               date.timeIntervalSince1970 * 1_000 > deadline {
                return activateWhenUnexpectedlyAwake
            }
            return false
        case .unexpectedlyAwake:
            guard activateWhenUnexpectedlyAwake else {
                return isScheduled(at: date, calendar: calendar)
            }
        case .upForDay:
            break
        }

        let nowMS = date.timeIntervalSince1970 * 1_000
        let finalWake = sleepSchedule.actualFinalWakeTs ?? sleepSchedule.plannedFinalWakeTs
        let afterWakeEnd = finalWake + Double(minutesAllowedAfterFinalWake) * 60_000
        if nowMS >= finalWake && nowMS < afterWakeEnd { return false }

        let beforeBedStart = sleepSchedule.plannedBedtimeTs -
            Double(minutesAllowedBeforeBed) * 60_000
        if nowMS >= beforeBedStart && nowMS < sleepSchedule.plannedBedtimeTs { return false }
        return true
    }

    /// Active intervals intersecting one civil day. Overnight rules retain the weekday on
    /// which they started, so Monday 22:00–02:00 includes early Tuesday automatically.
    public func scheduledIntervals(on date: Date, calendar: Calendar = .current) -> [DateInterval] {
        var calendar = calendar
        if let timeZoneIdentifier, let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = timeZone
        }
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        func includes(_ day: Int) -> Bool { activeDays.isEmpty || activeDays.contains(day) }
        func addingMinutes(_ value: Int) -> Date {
            calendar.date(
                bySettingHour: value / 60,
                minute: value % 60,
                second: 0,
                of: dayStart
            ) ?? calendar.date(byAdding: .minute, value: value, to: dayStart) ?? dayStart
        }

        let weekday = calendar.component(.weekday, from: dayStart) - 1
        if startMinute == endMinute {
            return includes(weekday) ? [DateInterval(start: dayStart, end: dayEnd)] : []
        }
        if startMinute < endMinute {
            guard includes(weekday) else { return [] }
            return [DateInterval(start: addingMinutes(startMinute), end: addingMinutes(endMinute))]
        }

        var intervals: [DateInterval] = []
        let previousWeekday = (weekday + 6) % 7
        if includes(previousWeekday) {
            intervals.append(DateInterval(start: dayStart, end: addingMinutes(endMinute)))
        }
        if includes(weekday) {
            intervals.append(DateInterval(start: addingMinutes(startMinute), end: dayEnd))
        }
        return intervals.filter { $0.duration > 0 }
    }
}

public enum ZoneEventKind: String, Codable, Sendable {
    case entered
    case exited
}

public struct ZoneEvent: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var zoneID: String
    public var kind: ZoneEventKind
    public var ts: Double
    public var dayKey: String
    public var baseRiskAtEvent: Int?

    public init(
        id: String = UUID().uuidString,
        zoneID: String,
        kind: ZoneEventKind,
        ts: Double = Date().timeIntervalSince1970 * 1000,
        dayKey: String,
        baseRiskAtEvent: Int? = nil
    ) {
        self.id = id
        self.zoneID = zoneID
        self.kind = kind
        self.ts = ts
        self.dayKey = dayKey
        self.baseRiskAtEvent = baseRiskAtEvent
    }
}

/// GPS cannot distinguish a bedroom from the rest of a home. This explicit session is the
/// honest room-level fallback and is intentionally separate from CLLocation geofences.
public struct PrivateContextSession: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var endedTs: Double?
    public var dayKey: String

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1000,
        endedTs: Double? = nil,
        dayKey: String
    ) {
        self.id = id
        self.ts = ts
        self.endedTs = endedTs
        self.dayKey = dayKey
    }
}

// MARK: - Default v2.7 libraries

public enum V27Defaults {
    public static let triggers: [TriggerDefinition] = [
        TriggerDefinition(id: "trigger.anxiety", name: "Stress", aliases: ["Anxiety / stress"]),
        TriggerDefinition(id: "trigger.lonely", name: "Lonely", aliases: ["Lonely / isolated"]),
        TriggerDefinition(id: "trigger.bored", name: "Bored", aliases: ["Bored / unstructured"]),
        TriggerDefinition(id: "trigger.tired", name: "Tired", aliases: ["Tired / underslept"]),
        TriggerDefinition(id: "trigger.explicit-access", name: "Explicit-content access"),
        TriggerDefinition(id: "trigger.private-zone", name: "Private high-risk context"),
        TriggerDefinition(id: "trigger.wet-dream", name: "Day after a wet dream")
    ]

    public static let responses: [ResponseDefinition] = [
        ResponseDefinition(
            id: "response.sigh", name: "Physiological sigh", evidence: .indirect,
            protectionWeight: .med, protectionMinutes: 120, lane: .countermove
        ),
        ResponseDefinition(
            id: "response.cold-plunge", name: "Cold plunge", evidence: .personal,
            protectionWeight: .med, protectionMinutes: 180, lane: .damageControl
        ),
        ResponseDefinition(
            id: "response.connection", name: "Uplifting connection", aliases: ["Connection & laughter", "Heart-warming laughter with friends"], evidence: .personal,
            protectionWeight: .med, protectionMinutes: 240, lane: .countermove
        ),
        ResponseDefinition(
            id: "response.leave", name: "Leave the risky environment", evidence: .indirect,
            protectionWeight: .high, protectionMinutes: 180, lane: .countermove
        ),
        ResponseDefinition(
            id: "response.block", name: "Block explicit access", evidence: .indirect,
            protectionWeight: .high, protectionMinutes: 240, lane: .countermove
        ),
        ResponseDefinition(
            id: "response.contact", name: "Contact someone", archived: true, evidence: .personal,
            protectionWeight: .med, protectionMinutes: 180, lane: .countermove
        ),
        ResponseDefinition(
            id: "response.if-then", name: "Follow matching If–Then plan", archived: true, evidence: .indirect,
            protectionWeight: .high, protectionMinutes: 240, lane: .countermove
        ),
        ResponseDefinition(
            id: "response.boxing", name: "Boxing", evidence: .personal,
            protectionWeight: .med, protectionMinutes: 180, lane: .countermove
        )
    ]
}
