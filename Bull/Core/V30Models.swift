import Foundation

// MARK: - v3.0 raw observations

/// Where a stress reading came from. Retrospective values remain usable while being
/// visibly distinguishable from a live check-in.
public enum StressReadingSource: String, Codable, CaseIterable, Sendable {
    case live
    case retrospective
    case migratedLegacy
}

public enum StressReadingContext: String, Codable, CaseIterable, Sendable {
    case morning
    case evening
    case checkIn
    case activityBefore
    case activityAfter
    case activityLater
}

/// One genuine, timestamped perception of current stress (0...10). Activity readings and
/// standalone check-ins share this stream because both describe the user's actual state.
public struct StressReading: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var dayKey: String
    public var value: Int
    public var context: StressReadingContext
    public var source: StressReadingSource
    public var activityLogID: String?

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        value: Int,
        context: StressReadingContext = .checkIn,
        source: StressReadingSource = .live,
        activityLogID: String? = nil
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.value = min(10, max(0, value))
        self.context = context
        self.source = source
        self.activityLogID = activityLogID
    }
}

public enum StressActivityKind: String, Codable, CaseIterable, Sendable {
    case physiologicalSigh
    case sauna
    case coldPlunge
    case saunaAndCold
    case boxing
    case natureWalk
    case mindfulness
    case socialConnection
    case custom
}

/// Editable activity catalogue. `weeklyTarget == 0` means as-needed: using it is recorded,
/// but not using it can never reduce Urge Routine.
public struct StressActivityDefinition: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var kind: StressActivityKind
    public var weeklyTarget: Int
    public var enabled: Bool
    public var archived: Bool

    public init(
        id: String,
        name: String,
        kind: StressActivityKind,
        weeklyTarget: Int = 0,
        enabled: Bool = true,
        archived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.weeklyTarget = min(14, max(0, weeklyTarget))
        self.enabled = enabled
        self.archived = archived
    }
}

public enum StressReliefLogSource: String, Codable, Sendable {
    case manual
    case urgeFlow
}

/// Prospective sessions separate a genuine before reading from a later after reading.
/// Retrospective estimates remain useful, but Stats can keep them visibly distinct.
public enum StressReliefTiming: String, Codable, Sendable {
    case prospective
    case estimatedAfterwards
    case migratedLegacy
}

/// A completed stress-management activity. Reading identifiers link the same observations
/// used by the daily stress trend to the paired before/after effectiveness analysis.
public struct StressReliefLog: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var dayKey: String
    public var activityID: String
    public var urgeEventID: String?
    public var durationMinutes: Int?
    public var beforeReadingID: String?
    public var afterReadingID: String?
    public var laterReadingID: String?
    public var source: StressReliefLogSource
    public var timing: StressReliefTiming?
    public var startedTs: Double?
    public var completedTs: Double?
    /// Optional manual Muse / mindfulness-session score (0...100). It is retained as an
    /// unweighted personal-experiment observation and never enters a fixed score.
    public var mindfulnessScore: Double?
    public var note: String?

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        activityID: String,
        urgeEventID: String? = nil,
        durationMinutes: Int? = nil,
        beforeReadingID: String? = nil,
        afterReadingID: String? = nil,
        laterReadingID: String? = nil,
        source: StressReliefLogSource = .manual,
        timing: StressReliefTiming? = nil,
        startedTs: Double? = nil,
        completedTs: Double? = nil,
        mindfulnessScore: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.activityID = activityID
        self.urgeEventID = urgeEventID
        self.durationMinutes = durationMinutes.map { min(600, max(0, $0)) }
        self.beforeReadingID = beforeReadingID
        self.afterReadingID = afterReadingID
        self.laterReadingID = laterReadingID
        self.source = source
        self.timing = timing
        self.startedTs = startedTs
        self.completedTs = completedTs
        self.mindfulnessScore = mindfulnessScore.map { min(100, max(0, $0)) }
        self.note = note
    }

    public var isPending: Bool {
        source == .manual && timing == .prospective && beforeReadingID != nil &&
            afterReadingID == nil && laterReadingID == nil && completedTs == nil
    }
}

public enum PornUrgeObservationContext: String, Codable, CaseIterable, Sendable {
    case checkIn
    case urgeBefore
    case urgeAfter
    case explicitNoUrge
}

/// Continuous perceived urge. This is an outcome, never a routine input.
public struct PornUrgeObservation: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var dayKey: String
    public var intensity: Int
    public var context: PornUrgeObservationContext
    public var urgeEventID: String?
    public var source: ObservationSource

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        intensity: Int,
        context: PornUrgeObservationContext = .checkIn,
        urgeEventID: String? = nil,
        source: ObservationSource = .live
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.intensity = min(10, max(0, intensity))
        self.context = context
        self.urgeEventID = urgeEventID
        self.source = source
    }
}

/// Multiple wake observations may exist on one civil day (for example Dawn and final wake).
/// Scoring first aggregates these into one day so extra wakes never receive extra weight.
public struct WakeErectionObservation: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var dayKey: String
    public var wakeLabel: String
    public var erection: MorningErectionObservation
    public var erectionHardnessScore: Int?
    public var source: ObservationSource

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        wakeLabel: String,
        erection: MorningErectionObservation,
        erectionHardnessScore: Int? = nil,
        source: ObservationSource = .live
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.wakeLabel = wakeLabel
        self.erection = erection
        self.erectionHardnessScore = erection == .yes
            ? erectionHardnessScore.map { min(4, max(1, $0)) }
            : nil
        self.source = source
    }
}

/// New entries separate the after-waking erection observation from natural desire later
/// in the day. A nil kind is a preserved v3.1 combined entry and remains readable.
public enum BullStateObservationKind: String, Codable, Sendable {
    case morningErection
    case naturalDesire
}

public struct BullStateObservation: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var dayKey: String
    public var wakeLabel: String
    public var erection: MorningErectionObservation
    public var erectionHardnessScore: Int?
    public var healthyDesire: Int?
    /// Optional after-waking observation. It is tracked for personal review and does not
    /// affect Bull State until enough observations support an explicit future decision.
    public var erectionDurationSeconds: Double?
    public var kind: BullStateObservationKind?
    public var source: ObservationSource

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        wakeLabel: String,
        erection: MorningErectionObservation,
        erectionHardnessScore: Int? = nil,
        healthyDesire: Int? = nil,
        erectionDurationSeconds: Double? = nil,
        kind: BullStateObservationKind? = nil,
        source: ObservationSource = .live
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.wakeLabel = wakeLabel
        self.erection = erection
        self.erectionHardnessScore = erection == .yes
            ? erectionHardnessScore.map { min(4, max(1, $0)) }
            : nil
        self.healthyDesire = healthyDesire.map { min(10, max(0, $0)) }
        self.erectionDurationSeconds = erection == .yes
            ? erectionDurationSeconds.map { min(4 * 3_600, max(0, $0)) }
            : nil
        self.kind = kind
        self.source = source
    }
}

// MARK: - Editable strength prescription and logs

public struct StrengthExercisePrescription: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var targetSets: Int
    public var minimumReps: Int
    public var maximumReps: Int
    public var targetWeightKg: Double?
    public var note: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        targetSets: Int = 3,
        minimumReps: Int = 6,
        maximumReps: Int = 10,
        targetWeightKg: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.targetSets = min(20, max(1, targetSets))
        self.minimumReps = min(100, max(1, minimumReps))
        self.maximumReps = min(100, max(self.minimumReps, maximumReps))
        self.targetWeightKg = targetWeightKg.map { min(1_000, max(0, $0)) }
        self.note = note
    }
}

public struct StrengthSetLog: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var exerciseID: String
    public var exerciseName: String
    public var setNumber: Int
    public var weightKg: Double
    public var reps: Int
    public var completed: Bool

    public init(
        id: String = UUID().uuidString,
        exerciseID: String,
        exerciseName: String,
        setNumber: Int,
        weightKg: Double,
        reps: Int,
        completed: Bool = false
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.setNumber = min(50, max(1, setNumber))
        self.weightKg = min(1_000, max(0, weightKg))
        self.reps = min(1_000, max(0, reps))
        self.completed = completed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        exerciseID = (try? c.decode(String.self, forKey: .exerciseID)) ?? id
        exerciseName = (try? c.decode(String.self, forKey: .exerciseName)) ?? "Exercise"
        setNumber = min(50, max(1, (try? c.decode(Int.self, forKey: .setNumber)) ?? 1))
        weightKg = min(1_000, max(0, (try? c.decode(Double.self, forKey: .weightKg)) ?? 0))
        reps = min(1_000, max(0, (try? c.decode(Int.self, forKey: .reps)) ?? 0))
        // v3.0 had one whole-workout toggle. A legacy set with entered reps is the only
        // honest per-set completion we can infer without inventing work.
        completed = (try? c.decode(Bool.self, forKey: .completed)) ?? (reps > 0)
    }
}

public struct StrengthWorkoutLog: Codable, Equatable, Sendable, Identifiable, TimestampedEvent {
    public var id: String
    public var ts: Double
    public var dayKey: String
    public var planID: String?
    public var planDayID: String?
    public var sets: [StrengthSetLog]
    public var completed: Bool
    public var completedTs: Double?
    public var note: String?

    public init(
        id: String = UUID().uuidString,
        ts: Double = Date().timeIntervalSince1970 * 1_000,
        dayKey: String,
        planID: String? = nil,
        planDayID: String? = nil,
        sets: [StrengthSetLog] = [],
        completed: Bool = false,
        completedTs: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.ts = ts
        self.dayKey = dayKey
        self.planID = planID
        self.planDayID = planDayID
        self.sets = sets
        self.completed = completed
        self.completedTs = completedTs
        self.note = note
    }
}

// MARK: - Four-score outputs and frozen v3 history

public struct UrgeRoutineState: Equatable, Sendable {
    public var sleepProtection: Double?
    public var stressPlan: Double?
    public var environmentProtection: Double?
    public var fastingProtection: Double?
    public var score: Double?

    public var stressRegulation: Double? {
        get { stressPlan }
        set { stressPlan = newValue }
    }

    public init(
        sleepProtection: Double?, stressPlan: Double?, environmentProtection: Double?,
        fastingProtection: Double? = nil
    ) {
        self.sleepProtection = sleepProtection.map(Self.clamp)
        self.stressPlan = stressPlan.map(Self.clamp)
        self.environmentProtection = environmentProtection.map(Self.clamp)
        self.fastingProtection = fastingProtection.map(Self.clamp)
        if let sleep = self.sleepProtection,
           let stress = self.stressPlan,
           let environment = self.environmentProtection {
            let base = sleep * 0.40 + stress * 0.35 + environment * 0.25
            score = min(100, base + (self.fastingProtection == nil ? 0 : 10))
        } else {
            score = nil
        }
    }

    private static func clamp(_ value: Double) -> Double { min(100, max(0, value)) }
}

public struct UrgeState: Equatable, Sendable {
    public var score: Double?
    public var meanPeak: Double?
    public var observedDays: Int
    public var windowDays: Int
}

public struct BullRoutineState: Equatable, Sendable {
    public var cardio: Double?
    public var sleep: Double?
    public var foodPlan: Double?
    public var strength: Double?
    public var score: Double?
    public var weeklyModerateEquivalentMinutes: Double
    public var weeklyCardioActiveCalories: Double?
    public var weeklyStrengthSessions: Int
    public var weeklyStrengthCompletedSets: Int
    public var weeklyStrengthScheduledSets: Int

    public init(
        cardio: Double?, sleep: Double?, foodPlan: Double?, strength: Double?,
        weeklyModerateEquivalentMinutes: Double, weeklyStrengthSessions: Int,
        weeklyCardioActiveCalories: Double? = nil,
        weeklyStrengthCompletedSets: Int = 0, weeklyStrengthScheduledSets: Int = 0
    ) {
        self.cardio = cardio.map { min(100, max(0, $0)) }
        self.sleep = sleep.map { min(100, max(0, $0)) }
        self.foodPlan = foodPlan.map { min(100, max(0, $0)) }
        self.strength = strength.map { min(100, max(0, $0)) }
        self.weeklyModerateEquivalentMinutes = max(0, weeklyModerateEquivalentMinutes)
        self.weeklyCardioActiveCalories = weeklyCardioActiveCalories.map { max(0, $0) }
        self.weeklyStrengthSessions = max(0, weeklyStrengthSessions)
        self.weeklyStrengthCompletedSets = max(0, weeklyStrengthCompletedSets)
        self.weeklyStrengthScheduledSets = max(0, weeklyStrengthScheduledSets)
        if let cardio = self.cardio, let sleep = self.sleep,
           let food = self.foodPlan, let strength = self.strength {
            score = cardio * 0.40 + sleep * 0.30 + food * 0.20 + strength * 0.10
        } else {
            score = nil
        }
    }
}

public struct BullState: Equatable, Sendable {
    public var erectionHealth: Double?
    public var healthyDesire: Double?
    public var score: Double?
    public var erectionDays: Int
    public var desireDays: Int
    public var windowDays: Int

    public init(
        erectionHealth: Double?, healthyDesire: Double?,
        erectionDays: Int, desireDays: Int, windowDays: Int = 7
    ) {
        self.erectionHealth = erectionHealth.map { min(100, max(0, $0)) }
        self.healthyDesire = healthyDesire.map { min(100, max(0, $0)) }
        self.erectionDays = max(0, erectionDays)
        self.desireDays = max(0, desireDays)
        self.windowDays = max(1, windowDays)
        if let erectionHealth = self.erectionHealth, let healthyDesire = self.healthyDesire {
            score = erectionHealth * 0.70 + healthyDesire * 0.30
        } else {
            score = nil
        }
    }
}

/// Frozen component percentages, not additional scores or therapist-shared data.
public struct RoutineComponentSnapshot: Codable, Equatable, Sendable {
    public var preventionSleep: Double?
    public var stressRegulation: Double?
    public var environmentProtection: Double?
    public var fastingProtection: Double?
    public var cardio: Double?
    public var vigourSleep: Double?
    public var bullFuel: Double?
    public var strength: Double?

    public init(urge: UrgeRoutineState, bull: BullRoutineState) {
        preventionSleep = urge.sleepProtection
        stressRegulation = urge.stressRegulation
        environmentProtection = urge.environmentProtection
        fastingProtection = urge.fastingProtection
        cardio = bull.cardio
        vigourSleep = bull.sleep
        bullFuel = bull.foodPlan
        strength = bull.strength
    }
}

public struct FourScoreSnapshot: Codable, Equatable, Sendable {
    public var urgeRoutine: Double?
    public var urgeState: Double?
    public var bullRoutine: Double?
    public var bullState: Double?
    public var scoringVersion: Int
    public var recordedTs: Double
    public var isFinal: Bool
    /// Zero is the first finalized/provisional value. Historical corrections increment the
    /// revision without changing the scoring version or reopening an earlier scoring era.
    public var revision: Int
    /// Timestamp of the first finalized value when a later correction replaces it.
    public var originalRecordedTs: Double?
    public var routineComponents: RoutineComponentSnapshot?

    private enum CodingKeys: String, CodingKey {
        case urgeRoutine, urgeState, bullRoutine, bullState, scoringVersion, recordedTs
        case isFinal, revision, originalRecordedTs, routineComponents
    }

    public init(
        urgeRoutine: Double?, urgeState: Double?, bullRoutine: Double?, bullState: Double?,
        scoringVersion: Int = currentFourScoreVersion,
        recordedTs: Double = Date().timeIntervalSince1970 * 1_000,
        isFinal: Bool,
        revision: Int = 0,
        originalRecordedTs: Double? = nil,
        routineComponents: RoutineComponentSnapshot? = nil
    ) {
        func bounded(_ value: Double?) -> Double? { value.map { min(100, max(0, $0)) } }
        self.urgeRoutine = bounded(urgeRoutine)
        self.urgeState = bounded(urgeState)
        self.bullRoutine = bounded(bullRoutine)
        self.bullState = bounded(bullState)
        self.scoringVersion = scoringVersion
        self.recordedTs = recordedTs
        self.isFinal = isFinal
        self.revision = max(0, revision)
        self.originalRecordedTs = originalRecordedTs
        self.routineComponents = routineComponents
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func bounded(_ key: CodingKeys) throws -> Double? {
            try c.decodeIfPresent(Double.self, forKey: key).map { min(100, max(0, $0)) }
        }
        urgeRoutine = try bounded(.urgeRoutine)
        urgeState = try bounded(.urgeState)
        bullRoutine = try bounded(.bullRoutine)
        bullState = try bounded(.bullState)
        scoringVersion = try c.decode(Int.self, forKey: .scoringVersion)
        recordedTs = try c.decode(Double.self, forKey: .recordedTs)
        isFinal = try c.decode(Bool.self, forKey: .isFinal)
        revision = max(0, try c.decodeIfPresent(Int.self, forKey: .revision) ?? 0)
        originalRecordedTs = try c.decodeIfPresent(Double.self, forKey: .originalRecordedTs)
        // An absent or malformed optional breakdown must not discard a historical total.
        routineComponents = try? c.decodeIfPresent(RoutineComponentSnapshot.self, forKey: .routineComponents)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(urgeRoutine, forKey: .urgeRoutine)
        try c.encodeIfPresent(urgeState, forKey: .urgeState)
        try c.encodeIfPresent(bullRoutine, forKey: .bullRoutine)
        try c.encodeIfPresent(bullState, forKey: .bullState)
        try c.encode(scoringVersion, forKey: .scoringVersion)
        try c.encode(recordedTs, forKey: .recordedTs)
        try c.encode(isFinal, forKey: .isFinal)
        try c.encode(revision, forKey: .revision)
        try c.encodeIfPresent(originalRecordedTs, forKey: .originalRecordedTs)
        try c.encodeIfPresent(routineComponents, forKey: .routineComponents)
    }
}

public struct FourScoreState: Equatable, Sendable {
    public var urgeRoutine: UrgeRoutineState
    public var urgeState: UrgeState
    public var bullRoutine: BullRoutineState
    public var bullState: BullState

    public init(
        urgeRoutine: UrgeRoutineState,
        urgeState: UrgeState,
        bullRoutine: BullRoutineState,
        bullState: BullState
    ) {
        self.urgeRoutine = urgeRoutine
        self.urgeState = urgeState
        self.bullRoutine = bullRoutine
        self.bullState = bullState
    }
}

public struct TimeWeightedStressState: Equatable, Sendable {
    public var average: Double?
    public var observedHours: Double
    public var readingCount: Int
}

public struct StressRegulationState: Equatable, Sendable {
    public var morning: StressReading?
    public var endpoint: StressReading?
    public var score: Double?
    public var isFinal: Bool

    public init(morning: StressReading?, endpoint: StressReading?, score: Double?, isFinal: Bool) {
        self.morning = morning
        self.endpoint = endpoint
        self.score = score.map { min(100, max(0, $0)) }
        self.isFinal = isFinal
    }
}

public struct StressActivityEffect: Equatable, Sendable, Identifiable {
    public var id: String { activityID }
    public var activityID: String
    public var name: String
    public var medianDrop: Double
    public var typicalStartingStress: Double
    public var pairedCount: Int
    public var delayedCount: Int
    public var prospectiveCount: Int
    public var estimatedCount: Int
    public var prospectiveMedianDrop: Double?
    public var estimatedMedianDrop: Double?
}

public enum V30Defaults {
    public static let stressActivities: [StressActivityDefinition] = [
        .init(id: "stress.physiological-sigh", name: "Physiological Sigh", kind: .physiologicalSigh),
        .init(id: "stress.sauna", name: "Sauna", kind: .sauna),
        .init(id: "stress.cold-plunge", name: "Cold Plunge", kind: .coldPlunge),
        .init(id: "stress.sauna-cold", name: "Sauna + Cold", kind: .saunaAndCold),
        .init(id: "stress.boxing", name: "Boxing", kind: .boxing),
        .init(id: "stress.nature-walk", name: "Nature Walk", kind: .natureWalk),
        .init(id: "stress.mindfulness", name: "Mindfulness", kind: .mindfulness),
        .init(id: "stress.social", name: "Social Connection", kind: .socialConnection)
    ]
}

/// The old `currentScoringVersion` remains 6 so frozen v2.9 snapshots are never reopened.
/// v3.x writes into a separate snapshot dictionary. Build 51 uses version 10 for the
/// explicit fasting bonus and revised Bull State component weights.
public let currentFourScoreVersion = 10
