import Foundation

// MARK: - v2.9 transparent outputs

public struct UrgeRiskState: Equatable, Sendable {
    public var sleepRecovery: Double
    public var explicitContent: Double
    public var riskyEnvironment: Double
    public var postReleaseRebound: Double
    public var score: Int
    public var dataCoverage: Double

    public init(
        sleepRecovery: Double,
        explicitContent: Double,
        riskyEnvironment: Double,
        postReleaseRebound: Double,
        dataCoverage: Double
    ) {
        self.sleepRecovery = min(40, max(0, sleepRecovery))
        self.explicitContent = min(25, max(0, explicitContent))
        self.riskyEnvironment = min(20, max(0, riskyEnvironment))
        self.postReleaseRebound = min(15, max(0, postReleaseRebound))
        score = Int(min(100, max(0,
            self.sleepRecovery + self.explicitContent + self.riskyEnvironment + self.postReleaseRebound
        )).rounded())
        self.dataCoverage = min(1, max(0, dataCoverage))
    }
}

public struct SexualVigourState: Equatable, Sendable {
    public var erectionHealth: Double?
    public var healthyDesire: Double?
    public var score: Double?
    public var erectionDays: Int
    public var desireDays: Int
    public var windowDays: Int
    public var dataCoverage: Double

    public init(
        erectionHealth: Double?,
        healthyDesire: Double?,
        erectionDays: Int,
        desireDays: Int,
        windowDays: Int = 14,
        minimumDaysPerComponent: Int = 4
    ) {
        self.erectionHealth = erectionHealth.map { min(100, max(0, $0)) }
        self.healthyDesire = healthyDesire.map { min(100, max(0, $0)) }
        self.erectionDays = max(0, erectionDays)
        self.desireDays = max(0, desireDays)
        self.windowDays = max(1, windowDays)
        dataCoverage = min(1, Double(self.erectionDays + self.desireDays) / Double(self.windowDays * 2))
        if self.erectionDays >= minimumDaysPerComponent,
           self.desireDays >= minimumDaysPerComponent,
           let erection = self.erectionHealth,
           let desire = self.healthyDesire {
            score = min(100, max(0, erection * 0.60 + desire * 0.40))
        } else {
            score = nil
        }
    }
}

public struct RecoveryCompositeState: Equatable, Sendable {
    public var score: Double?
    public var sleep: Double?
    public var hrv: Double?
    public var restingHeartRate: Double?
    public var trainingBalance: Double?
    public var dataCoverage: Double

    public init(
        score: Double?, sleep: Double?, hrv: Double?, restingHeartRate: Double?,
        trainingBalance: Double?, dataCoverage: Double
    ) {
        self.score = score.map { min(100, max(0, $0)) }
        self.sleep = sleep
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.trainingBalance = trainingBalance
        self.dataCoverage = min(1, max(0, dataCoverage))
    }
}

public struct VigourRoutineState: Equatable, Sendable {
    public var cardio: Double?
    public var recovery: Double?
    public var foodPlan: Double?
    public var strength: Double?
    public var score: Double?
    public var dataCoverage: Double
    public var weeklyModerateEquivalentMinutes: Double
    public var weeklyStrengthSessions: Int

    public init(
        cardio: Double?, recovery: Double?, foodPlan: Double?, strength: Double?,
        weeklyModerateEquivalentMinutes: Double, weeklyStrengthSessions: Int
    ) {
        self.cardio = cardio.map { min(100, max(0, $0)) }
        self.recovery = recovery.map { min(100, max(0, $0)) }
        self.foodPlan = foodPlan.map { min(100, max(0, $0)) }
        self.strength = strength.map { min(100, max(0, $0)) }
        self.weeklyModerateEquivalentMinutes = max(0, weeklyModerateEquivalentMinutes)
        self.weeklyStrengthSessions = max(0, weeklyStrengthSessions)

        let components: [(Double?, Double)] = [
            (self.cardio, 0.40),
            (self.recovery, 0.30),
            (self.foodPlan, 0.20),
            (self.strength, 0.10)
        ]
        let observed = components.compactMap { component -> (Double, Double)? in
            component.0.map { ($0, component.1) }
        }
        let observedWeight = observed.map { $0.1 }.reduce(0, +)
        dataCoverage = observedWeight
        score = observedWeight > 0
            ? observed.reduce(0) { $0 + $1.0 * $1.1 } / observedWeight
            : nil
    }
}

// MARK: - Versioned exercise prescription

public enum ExercisePlanPhase: String, Codable, CaseIterable, Sendable {
    case calibration
    case build
    case consolidate
    case maintain

    public var label: String { rawValue.capitalized }
}

public enum ExerciseProgressionFocus: String, Codable, CaseIterable, Sendable {
    case strengthLoad
    case zone2Efficiency
    case boxingRound

    public var label: String {
        switch self {
        case .strengthLoad: return "Eligible strength loads"
        case .zone2Efficiency: return "Zone 2 pace at the same effort"
        case .boxingRound: return "One boxing round"
        }
    }
}

public enum ExerciseDayKind: String, Codable, CaseIterable, Sendable {
    case strength
    case aerobic
    case boxing
    case recovery
}

public struct ExercisePlanDay: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var dayNumber: Int
    /// Calendar weekday (1 = Sunday ... 7 = Saturday). Nil preserves the v2.9
    /// programme-relative Day 1...7 schedule.
    public var weekday: Int?
    public var title: String
    public var kind: ExerciseDayKind
    public var prescription: [String]
    public var plannedAerobicMinutes: Int
    public var plannedStrengthSession: Bool
    /// v3.0 structured prescription. Optional keeps every v2.9 plan decodable without
    /// rewriting its original free-text prescription.
    public var strengthExercises: [StrengthExercisePrescription]?

    public init(
        id: String,
        dayNumber: Int,
        weekday: Int? = nil,
        title: String,
        kind: ExerciseDayKind,
        prescription: [String],
        plannedAerobicMinutes: Int = 0,
        plannedStrengthSession: Bool = false,
        strengthExercises: [StrengthExercisePrescription]? = nil
    ) {
        self.id = id
        self.dayNumber = min(7, max(1, dayNumber))
        self.weekday = weekday.map { min(7, max(1, $0)) }
        self.title = title
        self.kind = kind
        self.prescription = prescription
        self.plannedAerobicMinutes = max(0, plannedAerobicMinutes)
        self.plannedStrengthSession = plannedStrengthSession
        self.strengthExercises = strengthExercises
    }
}

public struct ExercisePlanVersion: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var versionNumber: Int
    public var startDayKey: String
    /// Stable origin of the overall programme. Weekly plan versions change `startDayKey`
    /// but retain this value so calibration, consolidation and 12-week outcome reviews do
    /// not restart after every human-approved decision. Optional decodes early v11 rows.
    public var programStartDayKey: String?
    public var endDayKey: String?
    public var phase: ExercisePlanPhase
    public var weeklyModerateEquivalentTarget: Int
    public var weeklyStrengthTarget: Int
    public var days: [ExercisePlanDay]
    public var rationale: String
    public var createdTs: Double
    /// Optional so the earliest v11 plan rows remain decodable without rewrite.
    public var boxingRounds: Int?
    public var lastProgressionFocus: ExerciseProgressionFocus?

    public init(
        id: String = UUID().uuidString,
        versionNumber: Int,
        startDayKey: String,
        programStartDayKey: String? = nil,
        endDayKey: String? = nil,
        phase: ExercisePlanPhase,
        weeklyModerateEquivalentTarget: Int = 160,
        weeklyStrengthTarget: Int = 3,
        days: [ExercisePlanDay],
        rationale: String,
        createdTs: Double = Date().timeIntervalSince1970 * 1_000,
        boxingRounds: Int? = nil,
        lastProgressionFocus: ExerciseProgressionFocus? = nil
    ) {
        self.id = id
        self.versionNumber = max(1, versionNumber)
        self.startDayKey = startDayKey
        self.programStartDayKey = programStartDayKey
        self.endDayKey = endDayKey
        self.phase = phase
        self.weeklyModerateEquivalentTarget = max(1, weeklyModerateEquivalentTarget)
        self.weeklyStrengthTarget = max(1, weeklyStrengthTarget)
        self.days = days.sorted { $0.dayNumber < $1.dayNumber }
        self.rationale = rationale
        self.createdTs = createdTs
        self.boxingRounds = boxingRounds.map { max(1, $0) }
        self.lastProgressionFocus = lastProgressionFocus
    }
}

public enum ExercisePlanDecision: String, Codable, CaseIterable, Sendable {
    case progress
    case hold
    case recover

    public var label: String { rawValue.capitalized }
}

public struct ExerciseWeekReview: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var planID: String
    public var weekStartDayKey: String
    public var proposedDecision: ExercisePlanDecision
    public var acceptedDecision: ExercisePlanDecision?
    public var rationale: String
    public var decidedTs: Double?
    public var note: String?
    /// A Progress decision is incomplete until the person chooses the one variable to
    /// change. Optional keeps early v11 review rows additive.
    public var acceptedProgressionFocus: ExerciseProgressionFocus?

    public init(
        id: String = UUID().uuidString,
        planID: String,
        weekStartDayKey: String,
        proposedDecision: ExercisePlanDecision,
        acceptedDecision: ExercisePlanDecision? = nil,
        rationale: String,
        decidedTs: Double? = nil,
        note: String? = nil,
        acceptedProgressionFocus: ExerciseProgressionFocus? = nil
    ) {
        self.id = id
        self.planID = planID
        self.weekStartDayKey = weekStartDayKey
        self.proposedDecision = proposedDecision
        self.acceptedDecision = acceptedDecision
        self.rationale = rationale
        self.decidedTs = decidedTs
        self.note = note
        self.acceptedProgressionFocus = acceptedProgressionFocus
    }
}

/// Manual correction is explicit. Nil means "use Apple Health"; a supplied value replaces
/// that day's imported total rather than silently adding to it. Strength is manual-first.
public struct ManualExerciseLog: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var dayKey: String
    public var aerobicMinutesOverride: Double?
    public var vigorousMinutesOverride: Double?
    public var strengthSessionCompleted: Bool?
    public var planDayID: String?
    public var notes: String?
    public var loggedTs: Double

    public init(
        id: String = UUID().uuidString,
        dayKey: String,
        aerobicMinutesOverride: Double? = nil,
        vigorousMinutesOverride: Double? = nil,
        strengthSessionCompleted: Bool? = nil,
        planDayID: String? = nil,
        notes: String? = nil,
        loggedTs: Double = Date().timeIntervalSince1970 * 1_000
    ) {
        self.id = id
        self.dayKey = dayKey
        self.aerobicMinutesOverride = aerobicMinutesOverride.map { max(0, $0) }
        self.vigorousMinutesOverride = vigorousMinutesOverride.map { max(0, $0) }
        self.strengthSessionCompleted = strengthSessionCompleted
        self.planDayID = planDayID
        self.notes = notes
        self.loggedTs = loggedTs
    }
}

// MARK: - Corrective lanes and event-only outcomes

public enum DamageControlStep: String, Codable, CaseIterable, Hashable, Sendable {
    case stopEpisode
    case secureAccess
    case lapseStatement
    case coldPlunge
    case fastIfSuitable
    case restoreStructure
    case minimalChainLog
    case monitorRebound

    public var label: String {
        switch self {
        case .stopEpisode: return "Stop the episode"
        case .secureAccess: return "Secure explicit-content access"
        case .lapseStatement: return "Read my lapse statement"
        case .coldPlunge: return "Cold plunge"
        case .fastIfSuitable: return "Fast if suitable"
        case .restoreStructure: return "Restore normal structure"
        case .minimalChainLog: return "Log the shortest useful chain"
        case .monitorRebound: return "Monitor the 48-hour rebound"
        }
    }
}

public struct DamageControlCheckIn: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var ts: Double
    /// Personal pull toward repeating the lapse, 0...10. This is an outcome check and never
    /// enters the predictive Urge Risk formula.
    public var repeatPull: Int
    /// Current felt recovery / mood, 0...10.
    public var recoveryMood: Int
    public var feelsRecovered: Bool

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        repeatPull: Int,
        recoveryMood: Int,
        feelsRecovered: Bool
    ) {
        self.id = id
        self.ts = ts
        self.repeatPull = min(10, max(0, repeatPull))
        self.recoveryMood = min(10, max(0, recoveryMood))
        self.feelsRecovered = feelsRecovered
    }
}

public struct DamageControlLog: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var relapseID: String
    public var dayKey: String
    public var completedSteps: [DamageControlStep]
    public var updatedTs: Double
    /// Optional for additive decoding of early v11 builds.
    public var stepCompletionTs: [String: Double]?
    /// Repeated checks preserve the trajectory instead of overwriting one before/after value.
    /// Optional for additive decoding of early v11 builds.
    public var checkIns: [DamageControlCheckIn]?

    public init(
        id: String = UUID().uuidString,
        relapseID: String,
        dayKey: String,
        completedSteps: [DamageControlStep] = [],
        updatedTs: Double = Date().timeIntervalSince1970 * 1_000,
        stepCompletionTs: [String: Double]? = nil,
        checkIns: [DamageControlCheckIn]? = nil
    ) {
        self.id = id
        self.relapseID = relapseID
        self.dayKey = dayKey
        self.completedSteps = Array(Set(completedSteps))
        self.updatedTs = updatedTs
        self.stepCompletionTs = stepCompletionTs
        self.checkIns = checkIns
    }
}

public struct EjaculatoryControlObservation: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var ts: Double
    public var dayKey: String
    public var perceivedControl: Int
    public var soonerThanDesired: Bool
    public var bother: Int
    public var note: String?
    /// Set only when an existing observation is corrected. `ts` remains the original
    /// occurrence/log timestamp so an edit never changes the event's ordering.
    public var modifiedTs: Double?
    /// Distinguishes a live observation from one reconstructed for an earlier civil day.
    public var source: ObservationSource

    private enum CodingKeys: String, CodingKey {
        case id, ts, dayKey, perceivedControl, soonerThanDesired, bother, note, modifiedTs, source
    }

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        perceivedControl: Int,
        soonerThanDesired: Bool,
        bother: Int,
        note: String? = nil,
        modifiedTs: Double? = nil,
        source: ObservationSource = .live
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.perceivedControl = min(10, max(0, perceivedControl))
        self.soonerThanDesired = soonerThanDesired
        self.bother = min(10, max(0, bother))
        self.note = note
        self.modifiedTs = modifiedTs
        self.source = source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        ts = try c.decode(Double.self, forKey: .ts)
        dayKey = try c.decode(String.self, forKey: .dayKey)
        perceivedControl = min(10, max(0, try c.decode(Int.self, forKey: .perceivedControl)))
        soonerThanDesired = try c.decode(Bool.self, forKey: .soonerThanDesired)
        bother = min(10, max(0, try c.decode(Int.self, forKey: .bother)))
        note = try c.decodeIfPresent(String.self, forKey: .note)
        modifiedTs = try c.decodeIfPresent(Double.self, forKey: .modifiedTs)
        source = try c.decodeIfPresent(ObservationSource.self, forKey: .source) ?? .migratedLegacy
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ts, forKey: .ts)
        try c.encode(dayKey, forKey: .dayKey)
        try c.encode(perceivedControl, forKey: .perceivedControl)
        try c.encode(soonerThanDesired, forKey: .soonerThanDesired)
        try c.encode(bother, forKey: .bother)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encodeIfPresent(modifiedTs, forKey: .modifiedTs)
        try c.encode(source, forKey: .source)
    }
}

public enum V29Defaults {
    /// Personal calibration plan agreed for the gym restart on 5 September 2026. It is
    /// versioned, so later Progress/Hold/Recover decisions never rewrite this baseline.
    public static let exercisePlan = ExercisePlanVersion(
        versionNumber: 1,
        startDayKey: "2026-09-05",
        programStartDayKey: "2026-09-05",
        phase: .calibration,
        weeklyModerateEquivalentTarget: 160,
        weeklyStrengthTarget: 3,
        days: [
            ExercisePlanDay(
                id: "plan.v1.day1", dayNumber: 1, title: "Strength A + Zone 2", kind: .strength,
                prescription: [
                    "Leg press or back squat · 3 × 6–10",
                    "Bench press · 3 × 6–10",
                    "Chest-supported row · 3 × 8–12",
                    "Romanian deadlift · 3 × 8–10",
                    "Standing calf raise · 4 × 8–12",
                    "Pallof press · 3 × 10–15/side",
                    "Zone 2 · 40 minutes"
                ],
                plannedAerobicMinutes: 40,
                plannedStrengthSession: true
            ),
            ExercisePlanDay(
                id: "plan.v1.day2", dayNumber: 2, title: "Zone 2", kind: .aerobic,
                prescription: ["Continuous Zone 2 · 40–50 minutes"],
                plannedAerobicMinutes: 45
            ),
            ExercisePlanDay(
                id: "plan.v1.day3", dayNumber: 3, title: "Strength B", kind: .strength,
                prescription: [
                    "Trap-bar deadlift or hip thrust · 3 × 5–8",
                    "Pull-up or lat pulldown · 3 × 6–12",
                    "Overhead press · 3 × 6–10",
                    "Bulgarian split squat · 3 × 8–12/leg",
                    "Seated leg curl · 3 × 10–15",
                    "Seated calf raise · 4 × 12–20",
                    "Dead bug · 3 × 8–12/side"
                ],
                plannedStrengthSession: true
            ),
            ExercisePlanDay(
                id: "plan.v1.day4", dayNumber: 4, title: "Recover", kind: .recovery,
                prescription: ["Rest or easy walk", "No pelvic-floor work until clinician review"]
            ),
            ExercisePlanDay(
                id: "plan.v1.day5", dayNumber: 5, title: "Strength C + Zone 2", kind: .strength,
                prescription: [
                    "Hack squat or front squat · 3 × 8–12",
                    "Incline dumbbell press · 3 × 8–12",
                    "Cable or machine row · 3 × 8–12",
                    "Hip thrust or back extension · 3 × 8–15",
                    "Lateral raise · 3 × 12–20",
                    "Single-leg calf raise · 4 × 10–20/side",
                    "Optional arms · 2–3 × 10–15",
                    "Zone 2 · 40 minutes"
                ],
                plannedAerobicMinutes: 40,
                plannedStrengthSession: true
            ),
            ExercisePlanDay(
                id: "plan.v1.day6", dayNumber: 6, title: "Boxing intervals", kind: .boxing,
                prescription: [
                    "Warm-up · 10 minutes",
                    "10 rounds · 2 minutes hard / 1 minute easy",
                    "Moderate boxing or jog · 10 minutes",
                    "Cool-down · 5–10 minutes"
                ],
                plannedAerobicMinutes: 50
            ),
            ExercisePlanDay(
                id: "plan.v1.day7", dayNumber: 7, title: "Full recovery", kind: .recovery,
                prescription: ["Full recovery or a leisure walk"]
            )
        ],
        rationale: "A vascular-health baseline: three full-body strength sessions and four aerobic exposures. Weeks 1–2 calibrate loads; no set should be taken to failure by default.",
        boxingRounds: 10
    )
}
