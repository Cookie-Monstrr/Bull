import Foundation

// MARK: - Timestamped events

/// All timestamps in Bull's exported JSON are milliseconds since epoch,
/// matching JavaScript's `Date.now()`. Kept as `Double` (not `Date`) at the
/// model layer so encode/decode round-trips byte-for-byte against real
/// exports — converting eagerly to `Date` and back risks sub-millisecond or
/// timezone-adjacent drift that would make imported files not re-export
/// identically. Each type exposes a computed `date` for convenience.
public protocol TimestampedEvent {
    var ts: Double { get }
}

public extension TimestampedEvent {
    var date: Date { Date(timeIntervalSince1970: ts / 1000) }
}

public enum RelapseType: String, Codable, Sendable {
    case orgasm
    case edge
}

/// One tap of the Urge button. `triggers`/`responses` are filled in later via
/// the optional tagging sheet. A bare urge with neither is still meaningful as
/// an urge event, but it does not imply that a particular intervention was completed.
public struct UrgeEvent: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    /// Native Bull freezes the civil date on which the event was logged. Legacy PWA
    /// backups do not contain this field; the app backfills it once on first native load.
    public var dayKey: String?
    public var triggers: [String]
    public var responses: [String]
    public var triggerIDs: [String]
    public var intensity: UrgeIntensity?
    public var stress: Int?
    public var matchedPlanID: String?

    public init(
        id: String = UUID().uuidString,
        ts: Double,
        dayKey: String? = nil,
        triggers: [String] = [],
        responses: [String] = [],
        triggerIDs: [String] = [],
        intensity: UrgeIntensity? = nil,
        stress: Int? = nil,
        matchedPlanID: String? = nil
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.triggers = triggers
        self.responses = responses
        self.triggerIDs = triggerIDs
        self.intensity = intensity
        self.stress = stress.map { min(10, max(0, $0)) }
        self.matchedPlanID = matchedPlanID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        ts = try c.decode(Double.self, forKey: .ts)
        dayKey = try? c.decodeIfPresent(String.self, forKey: .dayKey)
        triggers = (try? c.decode([String].self, forKey: .triggers)) ?? []
        responses = (try? c.decode([String].self, forKey: .responses)) ?? []
        triggerIDs = (try? c.decode([String].self, forKey: .triggerIDs)) ?? []
        intensity = try? c.decodeIfPresent(UrgeIntensity.self, forKey: .intensity)
        stress = (try? c.decodeIfPresent(Int.self, forKey: .stress)).map { min(10, max(0, $0)) }
        matchedPlanID = try? c.decodeIfPresent(String.self, forKey: .matchedPlanID)
    }
}

public struct RelapseEvent: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    /// Frozen civil date for timezone-safe history. Nil only on legacy imports until backfilled.
    public var dayKey: String?
    public var type: RelapseType
    public var triggers: [String]
    public var triggerIDs: [String]
    public var components: [LapseComponent]
    /// Immediate next useful action chosen in the native post-lapse recovery flow.
    public var nextAction: String?
    /// Immutable audit timestamp for when Bull received the record. `ts` remains the
    /// legacy compatibility timestamp; occurrence precision lives in `occurrence`.
    public var loggedTs: Double
    public var occurrence: LapseOccurrenceMetadata

    public init(
        id: String = UUID().uuidString,
        ts: Double,
        dayKey: String? = nil,
        type: RelapseType = .orgasm,
        triggers: [String] = [],
        triggerIDs: [String] = [],
        components: [LapseComponent]? = nil,
        nextAction: String? = nil,
        loggedTs: Double? = nil,
        occurrence: LapseOccurrenceMetadata? = nil
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.type = type
        self.triggers = triggers
        self.triggerIDs = triggerIDs
        self.components = components ?? (type == .edge ? [.masturbation] : [.orgasm])
        self.nextAction = nextAction
        self.loggedTs = loggedTs ?? Date().timeIntervalSince1970 * 1_000
        self.occurrence = occurrence ?? LapseOccurrenceMetadata(
            occurrenceDayKey: dayKey ?? "",
            occurrenceTs: dayKey == nil ? ts : nil,
            timePrecision: dayKey == nil ? .exact : .unknown,
            locationPrecision: .unknown,
            source: .live,
            timeConfidence: dayKey == nil ? .exact : .unknown,
            locationConfidence: .unknown
        )
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        ts = try c.decode(Double.self, forKey: .ts)
        dayKey = try? c.decodeIfPresent(String.self, forKey: .dayKey)
        // app.js defaults a missing/unrecognised type to "orgasm".
        type = (try? c.decode(RelapseType.self, forKey: .type)) ?? .orgasm
        triggers = (try? c.decode([String].self, forKey: .triggers)) ?? []
        triggerIDs = (try? c.decode([String].self, forKey: .triggerIDs)) ?? []
        components = (try? c.decode([LapseComponent].self, forKey: .components)) ??
            (type == .edge ? [.masturbation] : [.orgasm])
        nextAction = try? c.decodeIfPresent(String.self, forKey: .nextAction)
        loggedTs = (try? c.decode(Double.self, forKey: .loggedTs)) ?? ts
        occurrence = (try? c.decode(LapseOccurrenceMetadata.self, forKey: .occurrence)) ??
            LapseOccurrenceMetadata(
                occurrenceDayKey: dayKey ?? "",
                occurrenceTs: nil,
                timePrecision: .unknown,
                locationPrecision: .unknown,
                source: .migratedLegacy,
                timeConfidence: .unknown,
                locationConfidence: .unknown
            )
    }
}

public struct WetDreamEvent: Codable, Equatable, Sendable, TimestampedEvent {
    public var ts: Double
    /// Frozen civil date for timezone-safe history. Nil only on legacy imports until backfilled.
    public var dayKey: String?

    public init(ts: Double, dayKey: String? = nil) {
        self.ts = ts; self.dayKey = dayKey
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ts = try c.decode(Double.self, forKey: .ts)
        dayKey = try? c.decodeIfPresent(String.self, forKey: .dayKey)
    }
}

/// A remembered if-then pattern, built backwards from what actually happened
/// rather than planned in advance. Keyed by SETS of triggers/responses — an
/// urge is often multi-causal, and one tag per field would lose that. A rule
/// with an empty `responses` array is a real, meaningful outcome (breathing
/// alone was enough), not missing data.
public struct Rule: Codable, Equatable, Sendable, TimestampedEvent {
    public var triggers: [String]
    public var responses: [String]
    public var count: Int
    public var ts: Double

    public init(triggers: [String], responses: [String], count: Int = 1, ts: Double) {
        self.triggers = triggers; self.responses = responses
        self.count = count; self.ts = ts
    }

    /// Tolerates the legacy singular `trigger`/`response` string shape from
    /// before rules were pluralised into sets — the same fallback app.js
    /// itself still applies on read (`r.trigger ? [r.trigger] : []`), so an
    /// old export decodes with no data loss.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let arr = try? c.decode([String].self, forKey: .triggers) {
            triggers = arr
        } else if let single = try? c.decode(String.self, forKey: .trigger) {
            triggers = [single]
        } else {
            triggers = []
        }
        if let arr = try? c.decode([String].self, forKey: .responses) {
            responses = arr
        } else if let single = try? c.decode(String.self, forKey: .response) {
            responses = [single]
        } else {
            responses = []
        }
        count = (try? c.decode(Int.self, forKey: .count)) ?? 1
        ts = (try? c.decode(Double.self, forKey: .ts)) ?? Date().timeIntervalSince1970 * 1000
    }

    private enum CodingKeys: String, CodingKey {
        case triggers, responses, count, ts, trigger, response
    }

    // Legacy singular keys are read-only compatibility — always ENCODE in the
    // current plural shape, so a decode-then-encode round-trip normalises an
    // old-format rule rather than perpetuating it.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(triggers, forKey: .triggers)
        try c.encode(responses, forKey: .responses)
        try c.encode(count, forKey: .count)
        try c.encode(ts, forKey: .ts)
    }
}


// MARK: - Native v8 additions

/// A deliberately pre-committed implementation intention. This is separate from
/// `Rule`, which is learned retrospectively from what happened after an urge.
public struct ImplementationPlan: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var trigger: String
    public var triggerID: String?
    public var action: String
    public var enabled: Bool
    public var rehearsed: Bool
    public var createdTs: Double

    public init(
        id: String = UUID().uuidString, trigger: String, triggerID: String? = nil, action: String,
        enabled: Bool = true, rehearsed: Bool = false,
        createdTs: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.trigger = trigger
        self.triggerID = triggerID
        self.action = action
        self.enabled = enabled
        self.rehearsed = rehearsed
        self.createdTs = createdTs
    }

    /// v2.6 plans predate `triggerID`. Decode them without dropping the plan; v2.7's
    /// migration resolves the saved trigger text to a stable library identifier.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        trigger = (try? c.decode(String.self, forKey: .trigger)) ?? ""
        triggerID = try? c.decodeIfPresent(String.self, forKey: .triggerID)
        action = (try? c.decode(String.self, forKey: .action)) ?? ""
        enabled = (try? c.decode(Bool.self, forKey: .enabled)) ?? true
        rehearsed = (try? c.decode(Bool.self, forKey: .rehearsed)) ?? false
        createdTs = (try? c.decode(Double.self, forKey: .createdTs)) ??
            Date().timeIntervalSince1970 * 1000
    }
}

/// Freezes the score that was shown for a historical day so later weight changes
/// do not rewrite the user's past. New days use the latest scoring version.
public struct ScoreSnapshot: Codable, Equatable, Sendable {
    public var risk: Int
    public var vigour: Double
    public var scoringVersion: Int
    public var recordedTs: Double
    /// v2.9 leaves Sexual Vigour missing until minimum coverage is met. Legacy snapshots
    /// decode nil and retain their exact numerical vigour value.
    public var vigourObserved: Bool?
    /// Highest predictive Risk observed during that civil day. Older snapshots decode nil
    /// and continue to use their frozen end-of-day `risk` value without being rewritten.
    public var peakRisk: Int?
    /// Only v2.9's in-progress current-day snapshot writes false. Nil is treated as a
    /// finalized legacy snapshot so migration never reopens or recalculates old history.
    public var isFinal: Bool?

    public init(
        risk: Int, vigour: Double, scoringVersion: Int = 2,
        recordedTs: Double = Date().timeIntervalSince1970 * 1000,
        vigourObserved: Bool? = nil,
        peakRisk: Int? = nil,
        isFinal: Bool? = nil
    ) {
        self.risk = risk
        self.vigour = vigour
        self.scoringVersion = scoringVersion
        self.recordedTs = recordedTs
        self.vigourObserved = vigourObserved
        self.peakRisk = peakRisk.map { min(100, max(0, $0)) }
        self.isFinal = isFinal
    }
}

// MARK: - Top-level backup container

/// The full shape of a `bull-backup-*.json` export — the entire persisted
/// `localStorage` blob from app.js, one JSON object.
public struct BullData: Codable, Equatable, Sendable {
    public var version: Int
    public var settings: Settings
    public var items: [Item]
    /// Keyed by `dateKey`: `"YYYY-MM-DD"`.
    public var days: [String: DayRecord]
    public var urges: [UrgeEvent]
    public var relapses: [RelapseEvent]
    public var wetDreams: [WetDreamEvent]
    public var rules: [Rule]
    /// Pre-committed if-then plans used prospectively.
    public var plans: [ImplementationPlan]
    /// Frozen historical scores, keyed by local civil date (YYYY-MM-DD).
    public var scoreSnapshots: [String: ScoreSnapshot]
    public var triggerLibrary: [TriggerDefinition]
    public var responseLibrary: [ResponseDefinition]
    public var responseAttempts: [ResponseAttempt]
    public var accountabilityCheckIns: [AccountabilityCheckIn]
    public var sexualCheckIns: [SexualCheckIn]
    public var dailySexualObservations: [DailySexualObservation]
    public var libidoSpots: [LibidoSpot]
    public var highRiskZones: [HighRiskZone]
    /// Versioned schedule-state handoff records supplied by Layla. Usually only the most
    /// recent few are needed, but retaining them makes zone decisions auditable.
    public var laylaSleepSchedules: [LaylaSleepScheduleSnapshot]
    public var zoneEvents: [ZoneEvent]
    public var safeguardEvents: [SafeguardEvent]
    public var riskAlertEvents: [RiskAlertEvent]
    public var privateContextSessions: [PrivateContextSession]
    public var weeklyGoals: [WeeklyGoal]
    public var weeklyGoalReviews: [WeeklyGoalReview]
    public var personalFactors: [PersonalFactor]
    /// v2.9 additions. Every array is additive and leniently decoded so a v10 backup keeps
    /// its complete history while receiving an empty/default v2.9 layer during migration.
    public var exercisePlans: [ExercisePlanVersion]
    public var exerciseWeekReviews: [ExerciseWeekReview]
    public var manualExerciseLogs: [ManualExerciseLog]
    public var damageControlLogs: [DamageControlLog]
    public var ejaculatoryControlObservations: [EjaculatoryControlObservation]
    /// v3.0 is an additive layer. Legacy daily stress/access/sexual fields and v1...v6
    /// snapshots remain intact for history, import parity and auditability.
    public var stressReadings: [StressReading]
    public var stressActivities: [StressActivityDefinition]
    public var stressReliefLogs: [StressReliefLog]
    public var pornUrgeObservations: [PornUrgeObservation]
    public var wakeErectionObservations: [WakeErectionObservation]
    public var bullStateObservations: [BullStateObservation]
    public var strengthWorkoutLogs: [StrengthWorkoutLog]
    public var fourScoreSnapshots: [String: FourScoreSnapshot]
    /// v3.3 therapist sharing is additive and strictly narrower than the complete backup.
    public var therapistOversight: TherapistOversightConfiguration
    public var riskControlChangeRequests: [RiskControlChangeRequest]
    public var therapistOutboxEvents: [TherapistOversightEvent]
    public var therapistInboxEvents: [TherapistOversightEvent]
    public var therapistAccessAudit: [TherapistAccessAuditEvent]
    /// Populated only on a therapist-role installation from the explicit shared projection.
    public var therapistProjectionCache: TherapistProjection?
    /// ms since epoch. Anchors the clean-streak/Clean% window when there is
    /// no relapse yet to anchor it instead.
    public var firstUse: Double

    public init(
        version: Int = 15,
        settings: Settings = Settings(),
        items: [Item] = DefaultItems.all,
        days: [String: DayRecord] = [:],
        urges: [UrgeEvent] = [],
        relapses: [RelapseEvent] = [],
        wetDreams: [WetDreamEvent] = [],
        rules: [Rule] = [],
        plans: [ImplementationPlan] = [],
        scoreSnapshots: [String: ScoreSnapshot] = [:],
        triggerLibrary: [TriggerDefinition] = V27Defaults.triggers,
        responseLibrary: [ResponseDefinition] = V27Defaults.responses,
        responseAttempts: [ResponseAttempt] = [],
        accountabilityCheckIns: [AccountabilityCheckIn] = [],
        sexualCheckIns: [SexualCheckIn] = [],
        dailySexualObservations: [DailySexualObservation] = [],
        libidoSpots: [LibidoSpot] = [],
        highRiskZones: [HighRiskZone] = [],
        laylaSleepSchedules: [LaylaSleepScheduleSnapshot] = [],
        zoneEvents: [ZoneEvent] = [],
        safeguardEvents: [SafeguardEvent] = [],
        riskAlertEvents: [RiskAlertEvent] = [],
        privateContextSessions: [PrivateContextSession] = [],
        weeklyGoals: [WeeklyGoal] = [],
        weeklyGoalReviews: [WeeklyGoalReview] = [],
        personalFactors: [PersonalFactor] = [],
        exercisePlans: [ExercisePlanVersion] = [V29Defaults.exercisePlan],
        exerciseWeekReviews: [ExerciseWeekReview] = [],
        manualExerciseLogs: [ManualExerciseLog] = [],
        damageControlLogs: [DamageControlLog] = [],
        ejaculatoryControlObservations: [EjaculatoryControlObservation] = [],
        stressReadings: [StressReading] = [],
        stressActivities: [StressActivityDefinition] = V30Defaults.stressActivities,
        stressReliefLogs: [StressReliefLog] = [],
        pornUrgeObservations: [PornUrgeObservation] = [],
        wakeErectionObservations: [WakeErectionObservation] = [],
        bullStateObservations: [BullStateObservation] = [],
        strengthWorkoutLogs: [StrengthWorkoutLog] = [],
        fourScoreSnapshots: [String: FourScoreSnapshot] = [:],
        therapistOversight: TherapistOversightConfiguration = TherapistOversightConfiguration(),
        riskControlChangeRequests: [RiskControlChangeRequest] = [],
        therapistOutboxEvents: [TherapistOversightEvent] = [],
        therapistInboxEvents: [TherapistOversightEvent] = [],
        therapistAccessAudit: [TherapistAccessAuditEvent] = [],
        therapistProjectionCache: TherapistProjection? = nil,
        firstUse: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.version = version; self.settings = settings; self.items = items
        self.days = days; self.urges = urges; self.relapses = relapses
        self.wetDreams = wetDreams; self.rules = rules
        self.plans = plans; self.scoreSnapshots = scoreSnapshots
        self.triggerLibrary = triggerLibrary; self.responseLibrary = responseLibrary
        self.responseAttempts = responseAttempts
        self.accountabilityCheckIns = accountabilityCheckIns
        self.sexualCheckIns = sexualCheckIns
        self.dailySexualObservations = dailySexualObservations
        self.libidoSpots = libidoSpots
        self.highRiskZones = highRiskZones
        self.laylaSleepSchedules = laylaSleepSchedules
        self.zoneEvents = zoneEvents
        self.safeguardEvents = safeguardEvents
        self.riskAlertEvents = riskAlertEvents
        self.privateContextSessions = privateContextSessions
        self.weeklyGoals = weeklyGoals
        self.weeklyGoalReviews = weeklyGoalReviews
        self.personalFactors = personalFactors
        self.exercisePlans = exercisePlans
        self.exerciseWeekReviews = exerciseWeekReviews
        self.manualExerciseLogs = manualExerciseLogs
        self.damageControlLogs = damageControlLogs
        self.ejaculatoryControlObservations = ejaculatoryControlObservations
        self.stressReadings = stressReadings
        self.stressActivities = stressActivities
        self.stressReliefLogs = stressReliefLogs
        self.pornUrgeObservations = pornUrgeObservations
        self.wakeErectionObservations = wakeErectionObservations
        self.bullStateObservations = bullStateObservations
        self.strengthWorkoutLogs = strengthWorkoutLogs
        self.fourScoreSnapshots = fourScoreSnapshots
        self.therapistOversight = therapistOversight
        self.riskControlChangeRequests = riskControlChangeRequests
        self.therapistOutboxEvents = therapistOutboxEvents
        self.therapistInboxEvents = therapistInboxEvents
        self.therapistAccessAudit = therapistAccessAudit
        self.therapistProjectionCache = therapistProjectionCache
        self.firstUse = firstUse
    }

    /// Every field falls back to a sane default on decode. This is the Swift
    /// equivalent of `migrate()`'s backfill — v2.8 native exports are v10, while
    /// older native/PWA backups may omit newer
    /// fields. A hand-edited or older file should still import as much as it validly
    /// can rather than fail whole.
    ///
    /// `items`, `urges`, `relapses`, `wetDreams`, and `rules` are decoded with
    /// `decodeLeniently` rather than a plain array decode, specifically so ONE
    /// malformed element (a future field type, a hand-edit gone wrong) can
    /// never silently wipe the entire collection — only that one element is
    /// skipped. `BackupImporter` reports skip counts to the user; this
    /// initializer just guarantees they can never be silent data loss.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // A missing version is legacy, not current; the app-level migration must run.
        version = (try? c.decode(Int.self, forKey: .version)) ?? 0
        settings = (try? c.decode(Settings.self, forKey: .settings)) ?? Settings()
        // Falling back to DefaultItems.all is only correct when the `items`
        // key is genuinely ABSENT or unreadable — an empty array is a
        // legitimate state (every default item can be deleted through
        // Settings) and must be respected, not silently "undeleted".
        if c.contains(.items) {
            items = decodeLeniently(Item.self, from: c, forKey: .items).elements
        } else {
            items = DefaultItems.all
        }
        // Same reasoning as items/urges/etc: a single corrupted day entry
        // must not be able to take the rest of a real user's calendar with
        // it. `days` is potentially months of irreplaceable history.
        days = decodeLeniently(DayRecord.self, from: c, forDictKey: .days).elements
        urges = decodeLeniently(UrgeEvent.self, from: c, forKey: .urges).elements
        relapses = decodeLeniently(RelapseEvent.self, from: c, forKey: .relapses).elements
        wetDreams = decodeLeniently(WetDreamEvent.self, from: c, forKey: .wetDreams).elements
        rules = decodeLeniently(Rule.self, from: c, forKey: .rules).elements
        plans = c.contains(.plans) ? decodeLeniently(ImplementationPlan.self, from: c, forKey: .plans).elements : []
        scoreSnapshots = c.contains(.scoreSnapshots)
            ? decodeLeniently(ScoreSnapshot.self, from: c, forDictKey: .scoreSnapshots).elements
            : [:]
        triggerLibrary = c.contains(.triggerLibrary)
            ? decodeLeniently(TriggerDefinition.self, from: c, forKey: .triggerLibrary).elements
            : V27Defaults.triggers
        responseLibrary = c.contains(.responseLibrary)
            ? decodeLeniently(ResponseDefinition.self, from: c, forKey: .responseLibrary).elements
            : V27Defaults.responses
        responseAttempts = c.contains(.responseAttempts)
            ? decodeLeniently(ResponseAttempt.self, from: c, forKey: .responseAttempts).elements
            : []
        accountabilityCheckIns = c.contains(.accountabilityCheckIns)
            ? decodeLeniently(AccountabilityCheckIn.self, from: c, forKey: .accountabilityCheckIns).elements
            : []
        sexualCheckIns = c.contains(.sexualCheckIns)
            ? decodeLeniently(SexualCheckIn.self, from: c, forKey: .sexualCheckIns).elements
            : []
        dailySexualObservations = c.contains(.dailySexualObservations)
            ? decodeLeniently(DailySexualObservation.self, from: c, forKey: .dailySexualObservations).elements
            : []
        libidoSpots = c.contains(.libidoSpots)
            ? decodeLeniently(LibidoSpot.self, from: c, forKey: .libidoSpots).elements
            : []
        highRiskZones = c.contains(.highRiskZones)
            ? decodeLeniently(HighRiskZone.self, from: c, forKey: .highRiskZones).elements
            : []
        laylaSleepSchedules = c.contains(.laylaSleepSchedules)
            ? decodeLeniently(LaylaSleepScheduleSnapshot.self, from: c, forKey: .laylaSleepSchedules).elements
            : []
        zoneEvents = c.contains(.zoneEvents)
            ? decodeLeniently(ZoneEvent.self, from: c, forKey: .zoneEvents).elements
            : []
        safeguardEvents = c.contains(.safeguardEvents)
            ? decodeLeniently(SafeguardEvent.self, from: c, forKey: .safeguardEvents).elements
            : []
        riskAlertEvents = c.contains(.riskAlertEvents)
            ? decodeLeniently(RiskAlertEvent.self, from: c, forKey: .riskAlertEvents).elements
            : []
        privateContextSessions = c.contains(.privateContextSessions)
            ? decodeLeniently(PrivateContextSession.self, from: c, forKey: .privateContextSessions).elements
            : []
        weeklyGoals = c.contains(.weeklyGoals)
            ? decodeLeniently(WeeklyGoal.self, from: c, forKey: .weeklyGoals).elements
            : []
        weeklyGoalReviews = c.contains(.weeklyGoalReviews)
            ? decodeLeniently(WeeklyGoalReview.self, from: c, forKey: .weeklyGoalReviews).elements
            : []
        personalFactors = c.contains(.personalFactors)
            ? decodeLeniently(PersonalFactor.self, from: c, forKey: .personalFactors).elements
            : []
        exercisePlans = c.contains(.exercisePlans)
            ? decodeLeniently(ExercisePlanVersion.self, from: c, forKey: .exercisePlans).elements
            : []
        exerciseWeekReviews = c.contains(.exerciseWeekReviews)
            ? decodeLeniently(ExerciseWeekReview.self, from: c, forKey: .exerciseWeekReviews).elements
            : []
        manualExerciseLogs = c.contains(.manualExerciseLogs)
            ? decodeLeniently(ManualExerciseLog.self, from: c, forKey: .manualExerciseLogs).elements
            : []
        damageControlLogs = c.contains(.damageControlLogs)
            ? decodeLeniently(DamageControlLog.self, from: c, forKey: .damageControlLogs).elements
            : []
        ejaculatoryControlObservations = c.contains(.ejaculatoryControlObservations)
            ? decodeLeniently(EjaculatoryControlObservation.self, from: c, forKey: .ejaculatoryControlObservations).elements
            : []
        stressReadings = c.contains(.stressReadings)
            ? decodeLeniently(StressReading.self, from: c, forKey: .stressReadings).elements
            : []
        stressActivities = c.contains(.stressActivities)
            ? decodeLeniently(StressActivityDefinition.self, from: c, forKey: .stressActivities).elements
            : []
        stressReliefLogs = c.contains(.stressReliefLogs)
            ? decodeLeniently(StressReliefLog.self, from: c, forKey: .stressReliefLogs).elements
            : []
        pornUrgeObservations = c.contains(.pornUrgeObservations)
            ? decodeLeniently(PornUrgeObservation.self, from: c, forKey: .pornUrgeObservations).elements
            : []
        wakeErectionObservations = c.contains(.wakeErectionObservations)
            ? decodeLeniently(WakeErectionObservation.self, from: c, forKey: .wakeErectionObservations).elements
            : []
        bullStateObservations = c.contains(.bullStateObservations)
            ? decodeLeniently(BullStateObservation.self, from: c, forKey: .bullStateObservations).elements
            : []
        strengthWorkoutLogs = c.contains(.strengthWorkoutLogs)
            ? decodeLeniently(StrengthWorkoutLog.self, from: c, forKey: .strengthWorkoutLogs).elements
            : []
        fourScoreSnapshots = c.contains(.fourScoreSnapshots)
            ? decodeLeniently(FourScoreSnapshot.self, from: c, forDictKey: .fourScoreSnapshots).elements
            : [:]
        therapistOversight = (try? c.decode(TherapistOversightConfiguration.self, forKey: .therapistOversight))
            ?? TherapistOversightConfiguration()
        riskControlChangeRequests = c.contains(.riskControlChangeRequests)
            ? decodeLeniently(RiskControlChangeRequest.self, from: c, forKey: .riskControlChangeRequests).elements
            : []
        therapistOutboxEvents = c.contains(.therapistOutboxEvents)
            ? decodeLeniently(TherapistOversightEvent.self, from: c, forKey: .therapistOutboxEvents).elements
            : []
        therapistInboxEvents = c.contains(.therapistInboxEvents)
            ? decodeLeniently(TherapistOversightEvent.self, from: c, forKey: .therapistInboxEvents).elements
            : []
        therapistAccessAudit = c.contains(.therapistAccessAudit)
            ? decodeLeniently(TherapistAccessAuditEvent.self, from: c, forKey: .therapistAccessAudit).elements
            : []
        therapistProjectionCache = try? c.decodeIfPresent(TherapistProjection.self, forKey: .therapistProjectionCache)
        firstUse = (try? c.decode(Double.self, forKey: .firstUse)) ?? (Date().timeIntervalSince1970 * 1000)
    }
}
