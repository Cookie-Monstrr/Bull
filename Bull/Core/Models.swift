import Foundation

// MARK: - Item taxonomy

/// Which score(s) an item feeds. `both` is the "Double Horns" case: the item
/// scores on Prevention and Vigour independently, at two separate weights.
public enum ItemList: String, Codable, Sendable {
    case prev
    case prime
    case both

    /// Matches `isPrev()` in app.js.
    public var feedsPrevention: Bool { self == .prev || self == .both }
    /// Matches `isPrime()` in app.js.
    public var feedsVigour: Bool { self == .prime || self == .both }
}

/// How an item behaves when scored.
/// - `risk`: doing it RAISES Risk (and, if dual, costs Vigour)
/// - `habit`: doing it LOWERS Risk (and, if dual, earns Vigour)
/// - `tier`: a graded three-way choice, scored by its own bespoke rule (Content
///   Access, Checking Out Women) rather than the generic loop
/// - `derived`: not user-toggled at all — computed from another field. Carries
///   only a weight, which the bespoke rule for that factor reads.
public enum ItemKind: String, Codable, Sendable {
    case risk
    case habit
    case tier
    case derived

    /// Only risk/habit items participate in the generic scoring loops.
    public var isToggleable: Bool { self == .risk || self == .habit }
}

/// Risk-side domains used to keep clusters of closely related vulnerabilities from
/// being counted as fully independent. Domains cap net contribution, while distinct
/// domains can still stack into genuinely compounded vulnerability.
public enum RiskDomain: String, Codable, CaseIterable, Hashable, Sendable {
    case exposure
    case physiology
    case structure
    case protection

    public var label: String {
        switch self {
        case .exposure: return "Exposure"
        case .physiology: return "Physiology"
        case .structure: return "Structure"
        case .protection: return "Protection"
        }
    }
}

/// Vigour mechanism buckets. Version 3 balances adherence within these buckets.
public enum Bucket: String, Codable, CaseIterable, Hashable, Sendable {
    case test
    case heart
    case no
    case pelvic

    public var label: String {
        switch self {
        case .test: return "Testosterone"
        case .heart: return "Heart Power"
        case .no: return "Nitric Oxide"
        case .pelvic: return "Pelvic Floor"
        }
    }
}

/// Scheduling. `daily` is every day; `days` is a set of weekday indices using
/// JavaScript's convention (0 = Sunday ... 6 = Saturday). An EMPTY days array
/// means "every day", matching `scheduledOn()` in app.js — a subtle case that
/// is easy to lose in a port.
public enum Frequency: Codable, Equatable, Sendable {
    case daily
    case days([Int])

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .daily: try c.encode("daily")
        case .days(let d): try c.encode(d)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self), s == "daily" {
            self = .daily
        } else if let d = try? c.decode([Int].self) {
            self = .days(d)
        } else {
            // app.js treats anything unrecognised as "always scheduled".
            self = .daily
        }
    }
}

// MARK: - Item

public struct Item: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var sub: String?
    public var list: ItemList
    public var kind: ItemKind
    /// Prevention-side weight. Also the fallback for `vigourWeight`.
    public var weight: Weight
    /// Vigour-side weight for dual items. When nil, `weight` is used.
    public var vigourWeight: Weight?
    public var bucket: Bucket?
    /// Optional explicit Risk domain. Older backups omit this; scoring then falls back
    /// to Bull's built-in mapping so migrations remain lossless.
    public var riskDomain: RiskDomain?
    public var freq: Frequency?
    /// When true, the item is ignored entirely on a Sick/Travelling day —
    /// no credit and no penalty.
    public var excusable: Bool?
    /// When true, scheduling comes from the fasting calendar rather than `freq`.
    public var fastingAuto: Bool?
    /// Archived items retain every historical check but disappear from active logging and
    /// all current-model scoring. Older backups omit this field and therefore remain active.
    public var archived: Bool?
    /// v2.8 makes the basis and definition of every active factor explicit. These are
    /// optional so old backups remain byte-for-byte representable.
    public var evidenceStatus: FactorEvidenceStatus?
    public var intendedOutcome: String?
    public var definitionVersion: Int?

    public init(
        id: String, label: String, sub: String? = nil, list: ItemList, kind: ItemKind,
        weight: Weight, vigourWeight: Weight? = nil, bucket: Bucket? = nil,
        riskDomain: RiskDomain? = nil, freq: Frequency? = nil,
        excusable: Bool? = nil, fastingAuto: Bool? = nil, archived: Bool? = nil,
        evidenceStatus: FactorEvidenceStatus? = nil, intendedOutcome: String? = nil,
        definitionVersion: Int? = nil
    ) {
        self.id = id; self.label = label; self.sub = sub
        self.list = list; self.kind = kind
        self.weight = weight; self.vigourWeight = vigourWeight
        self.bucket = bucket; self.riskDomain = riskDomain; self.freq = freq
        self.excusable = excusable; self.fastingAuto = fastingAuto; self.archived = archived
        self.evidenceStatus = evidenceStatus
        self.intendedOutcome = intendedOutcome
        self.definitionVersion = definitionVersion
    }

    /// The weight this item contributes on the Vigour side.
    /// Mirrors `W_ADH[it.vigourWeight || it.weight]`.
    public var effectiveVigourWeight: Weight { vigourWeight ?? weight }

    public var isExcusable: Bool { excusable == true }
    public var isFastingAuto: Bool { fastingAuto == true }
    public var isArchived: Bool { archived == true }
}

// MARK: - Day record

public enum AccessLevel: String, Codable, Sendable {
    case low, med, high
}

public enum CheckoutLevel: String, Codable, Sendable {
    /// Raw value stays `"none"` for JSON compatibility with existing exports,
    /// but the case is deliberately NOT named `none`: on an Optional
    /// (`CheckoutLevel?`), writing `checkout == .none` would silently resolve to
    /// `Optional.none` — i.e. "not logged" — instead of "None logged". Those are
    /// different states and the bug would be invisible.
    case zero = "none"
    case few
    case lot
}

public struct Intention: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String
    public var when: String
    public var whereText: String
    public var met: Bool
    public var repeatDaily: Bool

    public init(
        id: String = UUID().uuidString, text: String = "", when: String = "",
        whereText: String = "", met: Bool = false, repeatDaily: Bool = false
    ) {
        self.id = id; self.text = text; self.when = when; self.whereText = whereText
        self.met = met; self.repeatDaily = repeatDaily
    }

    private enum CodingKeys: String, CodingKey { case id, text, when, whereText = "where", met, repeatDaily = "repeat" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        when = (try? c.decode(String.self, forKey: .when)) ?? ""
        whereText = (try? c.decode(String.self, forKey: .whereText)) ?? ""
        met = (try? c.decode(Bool.self, forKey: .met)) ?? false
        repeatDaily = (try? c.decode(Bool.self, forKey: .repeatDaily)) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(text, forKey: .text)
        try c.encode(when, forKey: .when); try c.encode(whereText, forKey: .whereText)
        try c.encode(met, forKey: .met); try c.encode(repeatDaily, forKey: .repeatDaily)
    }
}

public struct IntentionTemplate: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String
    public var when: String
    public var whereText: String

    public init(id: String = UUID().uuidString, text: String, when: String = "", whereText: String = "") {
        self.id = id; self.text = text; self.when = when; self.whereText = whereText
    }

    private enum CodingKeys: String, CodingKey { case id, text, when, whereText = "where" }
}

/// One day's log. Every scored field is optional, and "not logged" is a
/// meaningful third state distinct from true/false — notably for risk-kind
/// items, where unlogged is NEUTRAL, avoided EARNS, and happened COSTS.
public struct DayRecord: Codable, Equatable, Sendable {
    /// Tri-state per item: `true` happened/done, `false` avoided/skipped,
    /// absent (nil) not logged.
    public var checks: [String: Bool]
    /// Explicit v2.8 adherence. Legacy `checks` stay intact for history/parity, while
    /// unanswered due actions remain `.unknown` instead of becoming failures.
    public var completionStates: [String: CompletionRecord]
    public var access: AccessLevel?
    public var checkout: CheckoutLevel?
    public var intentions: [Intention]
    public var purposeRating: Int?
    /// One serious what/when/where commitment. The legacy intentions array is retained
    /// losslessly but no longer earns Risk credit or drives the v2.8 UI.
    public var morningCommitment: MorningCommitment?
    public var recovery: Double?
    /// Identifies how the Recovery Score was produced (for example `manual`, `bull-hrv`,
    /// or a future Layla source).
    public var recoveryScoreSource: String?
    public var recoveryScoreVersion: Int?
    /// Personal HRV baseline used when Bull derived the Recovery Score.
    public var recoveryHRVBaseline: Double?
    public var sleep: Double?
    /// Purpose-specific scores derived from the same underlying night. `sleep` remains the
    /// legacy generic score so older backups and frozen score models retain their meaning.
    public var preventionSleepScore: Double?
    public var vigourSleepScore: Double?
    public var sleepPurposeScoreSource: String?
    public var sleepPurposeScoreVersion: Int?
    /// Optional raw sleep duration imported from HealthKit. The scored `sleep` field remains
    /// the 0-100 Bull Sleep Score for backward compatibility.
    public var sleepHours: Double?
    /// Apple-aligned Bull Sleep Score components captured at import time. Apple exposes
    /// sleep-analysis samples through HealthKit but not its first-party Sleep Score itself,
    /// so Bull stores the transparent component inputs used for its own estimate.
    public var sleepDurationPoints: Double?
    public var sleepConsistencyPoints: Double?
    public var sleepInterruptionsPoints: Double?
    public var sleepBedtimeDeviationMinutes: Double?
    /// Total explicit awake minutes observed by HealthKit inside the sleep episode, before
    /// Bull excludes an expected Fajr wake window.
    public var sleepTotalAwakeMinutes: Double?
    /// Detected split-sleep gap that Bull treats as the planned Fajr wake. The score exempts
    /// up to 90 minutes; any excess remains part of the interruption penalty.
    public var sleepFajrWakeMinutes: Double?
    /// Unplanned awake minutes after the Fajr allowance has been removed. This is the value
    /// used by the interruption component and pattern analysis.
    public var sleepAwakeMinutes: Double?
    /// Unplanned interruption count after the detected Fajr gap has been removed.
    public var sleepInterruptionCount: Int?
    /// Identifies how a sleep score was produced (for example `manual`, `bull-fajr-aware`,
    /// or a future Layla source) so algorithm upgrades never overwrite the wrong history.
    public var sleepScoreSource: String?
    public var sleepScoreVersion: Int?
    public var hrv: Double?
    /// Resting heart rate imported from Apple Health for recovery context. It is compared
    /// with the user's own rolling baseline and is never treated as a diagnosis.
    public var restingHeartRate: Double?
    public var strain: Double?
    /// End of the detected primary sleep episode, used for time-aware personal hypotheses
    /// such as the user's post-wet-dream libido ramp.
    public var sleepWakeTs: Double?
    /// Apple Health workout totals attributed to this civil day.
    public var aerobicMinutes: Double?
    public var vigorousMinutes: Double?
    /// Apple Health active-energy estimate from recognised cardio workouts only.
    public var cardioActiveCalories: Double?
    /// Explains whether cardio intensity came from covered HR-zone minutes, the legacy
    /// workout-type fallback, or a mixture across the day.
    public var cardioIntensitySource: String?
    public var strengthMinutes: Double?
    /// A deliberately broad dietary-pattern check, replacing isolated food claims.
    public var heartHealthyEating: Bool?
    /// v3.1's realistic three-level Bull Fuel check. Nil preserves older Done/Not Done
    /// history through `heartHealthyEating` and `completionStates` without rewriting it.
    public var bullFuelPercent: Int?
    /// Optional current stress/anxiety check (0...10). This is context, not a diagnosis.
    public var stressLevel: Int?
    public var supplementsTaken: [String: Bool]
    public var sick: Bool
    public var travelling: Bool
    /// Excludes the day from period AVERAGES only. Never affects the day's own
    /// live score, relapses, Clean%, or correlations.
    public var excluded: Bool

    public init(
        checks: [String: Bool] = [:], completionStates: [String: CompletionRecord] = [:],
        access: AccessLevel? = nil, checkout: CheckoutLevel? = nil,
        intentions: [Intention] = [], purposeRating: Int? = nil,
        morningCommitment: MorningCommitment? = nil,
        recovery: Double? = nil, recoveryScoreSource: String? = nil, recoveryScoreVersion: Int? = nil,
        recoveryHRVBaseline: Double? = nil, sleep: Double? = nil,
        preventionSleepScore: Double? = nil, vigourSleepScore: Double? = nil,
        sleepPurposeScoreSource: String? = nil, sleepPurposeScoreVersion: Int? = nil,
        sleepHours: Double? = nil,
        sleepDurationPoints: Double? = nil, sleepConsistencyPoints: Double? = nil,
        sleepInterruptionsPoints: Double? = nil, sleepBedtimeDeviationMinutes: Double? = nil,
        sleepTotalAwakeMinutes: Double? = nil, sleepFajrWakeMinutes: Double? = nil,
        sleepAwakeMinutes: Double? = nil, sleepInterruptionCount: Int? = nil,
        sleepScoreSource: String? = nil, sleepScoreVersion: Int? = nil,
        hrv: Double? = nil, restingHeartRate: Double? = nil, strain: Double? = nil,
        sleepWakeTs: Double? = nil,
        aerobicMinutes: Double? = nil, vigorousMinutes: Double? = nil,
        cardioActiveCalories: Double? = nil,
        cardioIntensitySource: String? = nil,
        strengthMinutes: Double? = nil, heartHealthyEating: Bool? = nil,
        bullFuelPercent: Int? = nil,
        stressLevel: Int? = nil,
        supplementsTaken: [String: Bool] = [:],
        sick: Bool = false, travelling: Bool = false, excluded: Bool = false
    ) {
        self.checks = checks; self.completionStates = completionStates
        self.access = access; self.checkout = checkout
        self.intentions = intentions; self.purposeRating = purposeRating
        self.morningCommitment = morningCommitment
        self.recovery = recovery
        self.recoveryScoreSource = recoveryScoreSource
        self.recoveryScoreVersion = recoveryScoreVersion
        self.recoveryHRVBaseline = recoveryHRVBaseline
        self.sleep = sleep
        self.preventionSleepScore = preventionSleepScore
        self.vigourSleepScore = vigourSleepScore
        self.sleepPurposeScoreSource = sleepPurposeScoreSource
        self.sleepPurposeScoreVersion = sleepPurposeScoreVersion
        self.sleepHours = sleepHours
        self.sleepDurationPoints = sleepDurationPoints
        self.sleepConsistencyPoints = sleepConsistencyPoints
        self.sleepInterruptionsPoints = sleepInterruptionsPoints
        self.sleepBedtimeDeviationMinutes = sleepBedtimeDeviationMinutes
        self.sleepTotalAwakeMinutes = sleepTotalAwakeMinutes
        self.sleepFajrWakeMinutes = sleepFajrWakeMinutes
        self.sleepAwakeMinutes = sleepAwakeMinutes
        self.sleepInterruptionCount = sleepInterruptionCount
        self.sleepScoreSource = sleepScoreSource
        self.sleepScoreVersion = sleepScoreVersion
        self.hrv = hrv; self.restingHeartRate = restingHeartRate; self.strain = strain
        self.sleepWakeTs = sleepWakeTs
        self.aerobicMinutes = aerobicMinutes
        self.vigorousMinutes = vigorousMinutes
        self.cardioActiveCalories = cardioActiveCalories.map { max(0, $0) }
        self.cardioIntensitySource = cardioIntensitySource
        self.strengthMinutes = strengthMinutes
        self.heartHealthyEating = heartHealthyEating
        self.bullFuelPercent = bullFuelPercent.map { min(100, max(0, $0)) }
        self.stressLevel = stressLevel.map { min(10, max(0, $0)) }
        self.supplementsTaken = supplementsTaken
        self.sick = sick; self.travelling = travelling; self.excluded = excluded
    }

    /// Sick OR Travelling. Drives excusable-item handling.
    public var isFlagged: Bool { sick || travelling }

    // Tolerate missing keys from older exports.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        checks = (try? c.decode([String: Bool].self, forKey: .checks)) ?? [:]
        completionStates = (try? c.decode([String: CompletionRecord].self, forKey: .completionStates)) ?? [:]
        access = try? c.decodeIfPresent(AccessLevel.self, forKey: .access)
        checkout = try? c.decodeIfPresent(CheckoutLevel.self, forKey: .checkout)
        intentions = (try? c.decode([Intention].self, forKey: .intentions)) ?? []
        purposeRating = try? c.decodeIfPresent(Int.self, forKey: .purposeRating)
        morningCommitment = try? c.decodeIfPresent(MorningCommitment.self, forKey: .morningCommitment)
        recovery = try? c.decodeIfPresent(Double.self, forKey: .recovery)
        recoveryScoreSource = try? c.decodeIfPresent(String.self, forKey: .recoveryScoreSource)
        recoveryScoreVersion = try? c.decodeIfPresent(Int.self, forKey: .recoveryScoreVersion)
        recoveryHRVBaseline = try? c.decodeIfPresent(Double.self, forKey: .recoveryHRVBaseline)
        sleep = try? c.decodeIfPresent(Double.self, forKey: .sleep)
        preventionSleepScore = try? c.decodeIfPresent(Double.self, forKey: .preventionSleepScore)
        vigourSleepScore = try? c.decodeIfPresent(Double.self, forKey: .vigourSleepScore)
        sleepPurposeScoreSource = try? c.decodeIfPresent(String.self, forKey: .sleepPurposeScoreSource)
        sleepPurposeScoreVersion = try? c.decodeIfPresent(Int.self, forKey: .sleepPurposeScoreVersion)
        sleepHours = try? c.decodeIfPresent(Double.self, forKey: .sleepHours)
        sleepDurationPoints = try? c.decodeIfPresent(Double.self, forKey: .sleepDurationPoints)
        sleepConsistencyPoints = try? c.decodeIfPresent(Double.self, forKey: .sleepConsistencyPoints)
        sleepInterruptionsPoints = try? c.decodeIfPresent(Double.self, forKey: .sleepInterruptionsPoints)
        sleepBedtimeDeviationMinutes = try? c.decodeIfPresent(Double.self, forKey: .sleepBedtimeDeviationMinutes)
        sleepTotalAwakeMinutes = try? c.decodeIfPresent(Double.self, forKey: .sleepTotalAwakeMinutes)
        sleepFajrWakeMinutes = try? c.decodeIfPresent(Double.self, forKey: .sleepFajrWakeMinutes)
        sleepAwakeMinutes = try? c.decodeIfPresent(Double.self, forKey: .sleepAwakeMinutes)
        sleepInterruptionCount = try? c.decodeIfPresent(Int.self, forKey: .sleepInterruptionCount)
        sleepScoreSource = try? c.decodeIfPresent(String.self, forKey: .sleepScoreSource)
        sleepScoreVersion = try? c.decodeIfPresent(Int.self, forKey: .sleepScoreVersion)
        hrv = try? c.decodeIfPresent(Double.self, forKey: .hrv)
        restingHeartRate = try? c.decodeIfPresent(Double.self, forKey: .restingHeartRate)
        strain = try? c.decodeIfPresent(Double.self, forKey: .strain)
        sleepWakeTs = try? c.decodeIfPresent(Double.self, forKey: .sleepWakeTs)
        aerobicMinutes = try? c.decodeIfPresent(Double.self, forKey: .aerobicMinutes)
        vigorousMinutes = try? c.decodeIfPresent(Double.self, forKey: .vigorousMinutes)
        cardioActiveCalories = (try? c.decodeIfPresent(Double.self, forKey: .cardioActiveCalories))
            .map { max(0, $0) }
        cardioIntensitySource = try? c.decodeIfPresent(String.self, forKey: .cardioIntensitySource)
        strengthMinutes = try? c.decodeIfPresent(Double.self, forKey: .strengthMinutes)
        heartHealthyEating = try? c.decodeIfPresent(Bool.self, forKey: .heartHealthyEating)
        bullFuelPercent = (try? c.decodeIfPresent(Int.self, forKey: .bullFuelPercent))
            .map { min(100, max(0, $0)) }
        stressLevel = (try? c.decodeIfPresent(Int.self, forKey: .stressLevel)).map { min(10, max(0, $0)) }
        supplementsTaken = (try? c.decode([String: Bool].self, forKey: .supplementsTaken)) ?? [:]
        sick = (try? c.decode(Bool.self, forKey: .sick)) ?? false
        travelling = (try? c.decode(Bool.self, forKey: .travelling)) ?? false
        excluded = (try? c.decode(Bool.self, forKey: .excluded)) ?? false
    }

    /// v3.2 uses purpose-specific values when present. A legacy/manual generic score remains
    /// a deliberate fallback rather than making an existing day suddenly unscorable.
    public var preventionSleepForScoring: Double? { preventionSleepScore ?? sleep }
    public var vigourSleepForScoring: Double? { vigourSleepScore ?? sleep }
}

// MARK: - Settings

public enum FastMode: String, Codable, Sendable {
    /// Mon/Thu plus the lunar white days.
    case both
    /// Mon/Thu only.
    case weekly
    /// Lunar white days only (hijri 13-15).
    case lunar
}

public struct Settings: Codable, Equatable, Sendable {
    public var purposeText: String
    public var supplements: [String]
    /// Therapy/accountability is opt-in. A user who has not chosen this support is never
    /// penalised simply for not having an appointment.
    public var accountabilityEnabled: Bool
    public var therapistEveryWeeks: Int
    public var nextCheckin: Double?
    /// The specific booked check-in timestamp most recently auto-counted as a completed
    /// session. This mirrors the original Bull behaviour while preventing duplicate counts.
    public var countedCheckin: Double?
    public var therapySessions: Int
    public var therapyNote: String
    public var lapsePlan: String
    public var fastMode: FastMode
    /// Vigour-side weight for the Sleep Score (proportional credit).
    public var sleepWeight: Weight
    /// Prevention-side weight for v2.7's continuous Sleep deficit. Independent of
    /// the legacy Vigour-side `sleepWeight` retained for backup compatibility.
    public var sleepRiskWeight: Weight
    /// Vigour-side weight for the Recovery Score (proportional credit).
    public var recoveryWeight: Weight
    /// Legacy Recovery Risk setting retained losslessly. v2.7 scores personal-baseline
    /// raw HRV directly and does not use the old Recovery-below-40 switch.
    public var recoveryRiskWeight: Weight
    public var intentionTemplates: [IntentionTemplate]
    public var intentionWeight: Weight
    public var breathFirstInhale: Double
    public var morningReminderTime: String
    public var eveningReminderTime: String
    /// Timestamp (ms since epoch) of the last time the app was opened. Drives
    /// away-period gap detection: on load, if the gap since this exceeds two
    /// days, unlogged days in between get offered as a bulk Sick/Travelling
    /// flag. Stamped on every load, so it was easy to miss porting — it isn't
    /// in `DEFAULT_SETTINGS` in app.js at all, it's written at runtime on
    /// first open, which is exactly the kind of field a port can silently drop.
    public var lastOpenedTs: Double?
    /// Which deliberately chosen behaviours count as a lapse. The user's v2.7 default is
    /// all three; wet dreams never enter this policy.
    public var lapsePolicy: LapsePolicy
    /// v2.9 zone nudges repeat only while the person remains inside an active, unsafeguarded
    /// Risk Zone. The value is user configurable and clamped to a non-spammy range.
    public var zoneNudgeRepeatMinutes: Int
    /// v3.3 moves the Risk Zone priority choice into the protected data model so a
    /// protection-reducing change can wait for therapist approval.
    public var zoneTimeSensitiveAlerts: Bool
    /// A Countermove is selected now and evaluated later. Immediate "after" questions are
    /// deliberately avoided because most interventions need time to be implemented.
    public var interventionFollowUpMinutes: Int
    /// The food plan is intentionally configurable while the separate nutrition work is
    /// being finalised. Historical heart-healthy-eating rows remain the underlying log.
    public var foodPlanLabel: String
    /// First civil day governed by the separate v3.0 four-score model. Earlier v1...v6
    /// snapshots stay frozen and are never backfilled or reinterpreted.
    public var fourScoreStartDayKey: String?
    /// First day scored with v3.1's Today/Today/7-day/Today semantics. v3.0 snapshots
    /// before this date remain frozen under scoring version 7.
    public var fourScoreV8StartDayKey: String?
    /// First day scored with v3.2's purpose-specific Prevention/Vigour sleep inputs.
    /// Earlier v3.1 snapshots remain frozen under scoring version 8.
    public var fourScoreV9StartDayKey: String?
    /// First day scored with Build 51's fasting bonus and 70/30 Bull State weights.
    /// Earlier version-9 snapshots remain frozen and are never recomputed.
    public var fourScoreV10StartDayKey: String?
    /// Suggested times for lightweight stress check-ins. These are tracking prompts only;
    /// coaching and automatic plan calibration remain parked.
    public var stressCheckInTimes: [String]

    public static let defaultPurpose = """
        I am preparing for her before I have met her. Every clean day is me becoming the man \
        and husband I intend to be on day one — clear-eyed, disciplined, present.

        This urge is a wave. It rises, it peaks, it passes. I do not act on it. I am building \
        something better.
        """

    public init(
        purposeText: String = Settings.defaultPurpose,
        supplements: [String] = [],
        accountabilityEnabled: Bool = false,
        therapistEveryWeeks: Int = 2,
        nextCheckin: Double? = nil,
        countedCheckin: Double? = nil,
        therapySessions: Int = 0,
        therapyNote: String = "",
        lapsePlan: String = "",
        fastMode: FastMode = .both,
        sleepWeight: Weight = .high,
        sleepRiskWeight: Weight = .vhigh,
        recoveryWeight: Weight = .med,
        recoveryRiskWeight: Weight = .med,
        intentionTemplates: [IntentionTemplate] = [],
        intentionWeight: Weight = .med,
        breathFirstInhale: Double = 4.5,
        morningReminderTime: String = "08:00",
        eveningReminderTime: String = "21:30",
        lastOpenedTs: Double? = nil,
        lapsePolicy: LapsePolicy = LapsePolicy(),
        zoneNudgeRepeatMinutes: Int = 30,
        zoneTimeSensitiveAlerts: Bool = false,
        interventionFollowUpMinutes: Int = 60,
        foodPlanLabel: String = "Bull Fuel",
        fourScoreStartDayKey: String? = nil,
        fourScoreV8StartDayKey: String? = nil,
        fourScoreV9StartDayKey: String? = nil,
        fourScoreV10StartDayKey: String? = nil,
        stressCheckInTimes: [String] = ["08:00", "21:00"]
    ) {
        self.purposeText = purposeText
        self.supplements = supplements
        self.accountabilityEnabled = accountabilityEnabled
        self.therapistEveryWeeks = therapistEveryWeeks
        self.nextCheckin = nextCheckin
        self.countedCheckin = countedCheckin
        self.therapySessions = therapySessions
        self.therapyNote = therapyNote
        self.lapsePlan = lapsePlan
        self.fastMode = fastMode
        self.sleepWeight = sleepWeight
        self.sleepRiskWeight = sleepRiskWeight
        self.recoveryWeight = recoveryWeight
        self.recoveryRiskWeight = recoveryRiskWeight
        self.intentionTemplates = intentionTemplates
        self.intentionWeight = intentionWeight
        self.breathFirstInhale = breathFirstInhale
        self.morningReminderTime = morningReminderTime
        self.eveningReminderTime = eveningReminderTime
        self.lastOpenedTs = lastOpenedTs
        self.lapsePolicy = lapsePolicy
        self.zoneNudgeRepeatMinutes = min(180, max(15, zoneNudgeRepeatMinutes))
        self.zoneTimeSensitiveAlerts = zoneTimeSensitiveAlerts
        self.interventionFollowUpMinutes = min(180, max(15, interventionFollowUpMinutes))
        self.foodPlanLabel = foodPlanLabel
        self.fourScoreStartDayKey = fourScoreStartDayKey
        self.fourScoreV8StartDayKey = fourScoreV8StartDayKey
        self.fourScoreV9StartDayKey = fourScoreV9StartDayKey
        self.fourScoreV10StartDayKey = fourScoreV10StartDayKey
        self.stressCheckInTimes = stressCheckInTimes
    }

    // Every field falls back to its default so older exports (which predate
    // several of these keys) decode cleanly — this is the Swift equivalent of
    // migrate()'s backfill, and the same rule applies: a missing key must get a
    // default for EVERY install, not only legacy-version ones.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        purposeText = (try? c.decode(String.self, forKey: .purposeText)) ?? d.purposeText
        supplements = (try? c.decode([String].self, forKey: .supplements)) ?? d.supplements
        accountabilityEnabled = (try? c.decode(Bool.self, forKey: .accountabilityEnabled)) ?? d.accountabilityEnabled
        therapistEveryWeeks = (try? c.decode(Int.self, forKey: .therapistEveryWeeks)) ?? d.therapistEveryWeeks
        nextCheckin = try? c.decodeIfPresent(Double.self, forKey: .nextCheckin)
        countedCheckin = try? c.decodeIfPresent(Double.self, forKey: .countedCheckin)
        therapySessions = (try? c.decode(Int.self, forKey: .therapySessions)) ?? d.therapySessions
        therapyNote = (try? c.decode(String.self, forKey: .therapyNote)) ?? d.therapyNote
        lapsePlan = (try? c.decode(String.self, forKey: .lapsePlan)) ?? d.lapsePlan
        fastMode = (try? c.decode(FastMode.self, forKey: .fastMode)) ?? d.fastMode
        sleepWeight = (try? c.decode(Weight.self, forKey: .sleepWeight)) ?? d.sleepWeight
        sleepRiskWeight = (try? c.decode(Weight.self, forKey: .sleepRiskWeight)) ?? d.sleepRiskWeight
        recoveryWeight = (try? c.decode(Weight.self, forKey: .recoveryWeight)) ?? d.recoveryWeight
        recoveryRiskWeight = (try? c.decode(Weight.self, forKey: .recoveryRiskWeight)) ?? d.recoveryRiskWeight
        intentionTemplates = (try? c.decode([IntentionTemplate].self, forKey: .intentionTemplates)) ?? d.intentionTemplates
        intentionWeight = (try? c.decode(Weight.self, forKey: .intentionWeight)) ?? d.intentionWeight
        breathFirstInhale = (try? c.decode(Double.self, forKey: .breathFirstInhale)) ?? d.breathFirstInhale
        morningReminderTime = (try? c.decode(String.self, forKey: .morningReminderTime)) ?? d.morningReminderTime
        eveningReminderTime = (try? c.decode(String.self, forKey: .eveningReminderTime)) ?? d.eveningReminderTime
        lastOpenedTs = try? c.decodeIfPresent(Double.self, forKey: .lastOpenedTs)
        lapsePolicy = (try? c.decode(LapsePolicy.self, forKey: .lapsePolicy)) ?? d.lapsePolicy
        zoneNudgeRepeatMinutes = min(
            180,
            max(15, (try? c.decode(Int.self, forKey: .zoneNudgeRepeatMinutes)) ?? d.zoneNudgeRepeatMinutes)
        )
        zoneTimeSensitiveAlerts = (try? c.decode(Bool.self, forKey: .zoneTimeSensitiveAlerts))
            ?? d.zoneTimeSensitiveAlerts
        interventionFollowUpMinutes = min(
            180,
            max(15, (try? c.decode(Int.self, forKey: .interventionFollowUpMinutes)) ?? d.interventionFollowUpMinutes)
        )
        foodPlanLabel = (try? c.decode(String.self, forKey: .foodPlanLabel)) ?? d.foodPlanLabel
        fourScoreStartDayKey = try? c.decodeIfPresent(String.self, forKey: .fourScoreStartDayKey)
        fourScoreV8StartDayKey = try? c.decodeIfPresent(String.self, forKey: .fourScoreV8StartDayKey)
        fourScoreV9StartDayKey = try? c.decodeIfPresent(String.self, forKey: .fourScoreV9StartDayKey)
        fourScoreV10StartDayKey = try? c.decodeIfPresent(String.self, forKey: .fourScoreV10StartDayKey)
        stressCheckInTimes = (try? c.decode([String].self, forKey: .stressCheckInTimes))
            ?? d.stressCheckInTimes
    }
}

// MARK: - Default items

public enum DefaultItems {
    /// Compatibility catalogue carried into v2.9. Live v6 scoring reads its explicit four
    /// inputs; imports keep every legacy/custom row and archive out-of-scope rows rather
    /// than deleting their checks.
    public static let all: [Item] = [
        Item(id: "contentAccess", label: "Explicit-content access", sub: "Low, Medium or High",
             list: .prev, kind: .tier, weight: .vhigh, riskDomain: .exposure,
             evidenceStatus: .directButLimitedPMO, intendedOutcome: "PMO lapse or high urge", definitionVersion: 2),
        Item(id: "checkout", label: "Checking Out Women", sub: "None, A Few or A Lot, logged daily",
             list: .prev, kind: .tier, weight: .high, riskDomain: .exposure, archived: true,
             evidenceStatus: .personalExperiment, intendedOutcome: "Historical context", definitionVersion: 2),
        Item(id: "sleepLow", label: "Insufficient sleep", sub: "Continuous — from Sleep Score",
             list: .prev, kind: .derived, weight: .vhigh, riskDomain: .physiology,
             evidenceStatus: .indirectPlausible, intendedOutcome: "PMO lapse or high urge", definitionVersion: 2),
        Item(id: "purposeLow", label: "Low-Purpose Day (1–2)", sub: "Auto — from your Evening Review",
             list: .prev, kind: .derived, weight: .med, riskDomain: .structure, archived: true,
             evidenceStatus: .contextOrOutcome, intendedOutcome: "Perceived purpose", definitionVersion: 2),
        Item(id: "purposeHigh", label: "High-Purpose Day (4–5)", sub: "Auto — protective, from your Evening Review",
             list: .prev, kind: .derived, weight: .med, riskDomain: .structure, archived: true,
             evidenceStatus: .contextOrOutcome, intendedOutcome: "Perceived purpose", definitionVersion: 2),
        Item(id: "accountabilityGap", label: "Accountability Not On Track",
             sub: "Auto — nothing booked, overdue, or too far out",
             list: .prev, kind: .derived, weight: .low, riskDomain: .protection,
             archived: true,
             evidenceStatus: .personalExperiment, intendedOutcome: "PMO lapse or high urge", definitionVersion: 2),
        Item(id: "sickFlag", label: "Sick Day", sub: "Auto — from the Sick flag on Today",
             list: .prev, kind: .derived, weight: .med, riskDomain: .physiology,
             evidenceStatus: .contextOrOutcome, intendedOutcome: "Context or confounder", definitionVersion: 2),
        Item(id: "travelFlag", label: "Travelling Day", sub: "Auto — from the Travelling flag on Today",
             list: .prev, kind: .derived, weight: .high, riskDomain: .structure,
             evidenceStatus: .contextOrOutcome, intendedOutcome: "Context or confounder", definitionVersion: 2),
        Item(id: "nasalclear", label: "Clear Nasal Airways", sub: "Indirect sleep support",
             list: .prime, kind: .habit, weight: .low, bucket: .no, freq: .daily,
             evidenceStatus: .indirectPlausible, intendedOutcome: "Sleep or comfort", definitionVersion: 2),
        Item(id: "fasting", label: "Fasting", sub: "Optional fasting rest day",
             list: .prev, kind: .habit, weight: .med, riskDomain: .protection,
             freq: .daily, excusable: false, fastingAuto: true, archived: true,
             evidenceStatus: .religiouslyGrounded, intendedOutcome: "Personal desire experiment", definitionVersion: 2),
    ]
}

/// Frozen v2.6 catalogue used only by the legacy parity diagnostics. New installs and
/// migrations use `DefaultItems`; keeping this fixture prevents a focused v2.7 product
/// catalogue from invalidating tests of the original PWA arithmetic.
public enum LegacyV26DefaultItems {
    public static let all: [Item] = [
        Item(id: "lonely", label: "Home Alone, Unstructured Time", list: .prev, kind: .risk,
             weight: .high, riskDomain: .exposure, freq: .daily),
        Item(id: "junk", label: "Junk Food", list: .both, kind: .risk,
             weight: .med, vigourWeight: .low, bucket: .heart, riskDomain: .physiology, freq: .daily),
        Item(id: "coldplunge", label: "Cold Plunge", list: .both, kind: .habit,
             weight: .med, vigourWeight: .low, bucket: .heart, riskDomain: .physiology, freq: .daily, excusable: true),
        Item(id: "nasalclear", label: "Nasal Rinse", list: .both, kind: .habit,
             weight: .med, vigourWeight: .med, bucket: .no, riskDomain: .physiology, freq: .daily),
        Item(id: "contentAccess", label: "Content Access", sub: "Low, Medium or High, logged daily",
             list: .prev, kind: .tier, weight: .high, riskDomain: .exposure),
        Item(id: "checkout", label: "Checking Out Women", sub: "None, A Few or A Lot, logged daily",
             list: .prev, kind: .tier, weight: .high, riskDomain: .exposure),
        Item(id: "recoveryLow", label: "Recovery Below 40%", sub: "Auto — from your Recovery Score",
             list: .prev, kind: .derived, weight: .med, riskDomain: .physiology),
        Item(id: "sleepLow", label: "Sleep Below 65%", sub: "Auto — from your Sleep Score",
             list: .prev, kind: .derived, weight: .med, riskDomain: .physiology),
        Item(id: "purposeLow", label: "Low-Purpose Day (1–2)", sub: "Auto — from your Evening Review",
             list: .prev, kind: .derived, weight: .med, riskDomain: .structure),
        Item(id: "purposeHigh", label: "High-Purpose Day (4–5)", sub: "Auto — protective, from your Evening Review",
             list: .prev, kind: .derived, weight: .med, riskDomain: .structure),
        Item(id: "accountabilityGap", label: "Accountability Not On Track",
             sub: "Auto — nothing booked, overdue, or too far out",
             list: .prev, kind: .derived, weight: .high, riskDomain: .protection),
        Item(id: "urgeSurvivalBonus", label: "Urge Day Passed",
             sub: "Historical only — a day with an urge and no lapse. Does not change live Risk.",
             list: .prev, kind: .derived, weight: .med, riskDomain: .protection),
        Item(id: "sickFlag", label: "Sick Day", sub: "Auto — from the Sick flag on Today",
             list: .prev, kind: .derived, weight: .med, riskDomain: .physiology),
        Item(id: "travelFlag", label: "Travelling Day", sub: "Auto — from the Travelling flag on Today",
             list: .prev, kind: .derived, weight: .high, riskDomain: .structure),
        Item(id: "kegels", label: "Kegels", list: .prime, kind: .habit,
             weight: .high, bucket: .pelvic, freq: .days([1, 3, 5, 0]), excusable: true),
        Item(id: "stretches", label: "Pelvic Floor Stretches", list: .prime, kind: .habit,
             weight: .med, bucket: .pelvic, freq: .days([1, 3, 5, 0]), excusable: true),
        Item(id: "cardio", label: "Cardio and Boxing", list: .prime, kind: .habit,
             weight: .high, bucket: .heart, freq: .days([1, 3, 5, 0]), excusable: true),
        Item(id: "strength", label: "Strength Training", list: .prime, kind: .habit,
             weight: .med, bucket: .test, freq: .days([2, 6]), excusable: true),
        Item(id: "breathwork", label: "Breathwork Before Isha", list: .prime, kind: .habit,
             weight: .med, bucket: .no, freq: .daily),
        Item(id: "fasting", label: "Fasting", list: .prime, kind: .habit,
             weight: .med, bucket: .test, freq: .daily, fastingAuto: true),
    ]
}
