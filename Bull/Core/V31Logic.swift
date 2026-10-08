import Foundation

// MARK: - Cardio heart-rate zones

public struct CardioHeartRatePoint: Equatable, Sendable {
    public var secondsFromWorkoutStart: Double
    public var beatsPerMinute: Double

    public init(secondsFromWorkoutStart: Double, beatsPerMinute: Double) {
        self.secondsFromWorkoutStart = secondsFromWorkoutStart
        self.beatsPerMinute = beatsPerMinute
    }
}

public struct CardioHeartRateZoneSummary: Equatable, Sendable {
    public var zoneMinutes: [Double]
    public var observedMinutes: Double
    public var moderateMinutes: Double
    public var vigorousMinutes: Double

    public init(zoneMinutes: [Double], observedMinutes: Double) {
        let normalized = Array((zoneMinutes + Array(repeating: 0, count: 5)).prefix(5))
            .map { max(0, $0) }
        self.zoneMinutes = normalized
        self.observedMinutes = max(0, observedMinutes)
        moderateMinutes = normalized[1] + normalized[2]
        vigorousMinutes = normalized[3] + normalized[4]
    }
}

/// Classifies covered workout minutes using five conventional percentages of estimated
/// maximum heart rate: <60%, 60–69%, 70–79%, 80–89% and >=90%. Zone 1 is retained for
/// transparency but does not earn moderate-equivalent credit; Zones 2–3 are moderate and
/// Zones 4–5 are vigorous. One mean BPM per elapsed workout minute prevents dense HealthKit
/// sampling from creating duplicate time.
public func cardioHeartRateZoneSummary(
    points: [CardioHeartRatePoint],
    workoutDurationSeconds: Double,
    estimatedMaximumHeartRate: Double
) -> CardioHeartRateZoneSummary? {
    guard workoutDurationSeconds > 0,
          workoutDurationSeconds.isFinite,
          estimatedMaximumHeartRate >= 100,
          estimatedMaximumHeartRate.isFinite else { return nil }

    let minuteCount = max(1, Int(ceil(workoutDurationSeconds / 60)))
    var buckets = Array(repeating: [Double](), count: minuteCount)
    for point in points where point.secondsFromWorkoutStart >= 0 &&
        point.secondsFromWorkoutStart < workoutDurationSeconds &&
        point.beatsPerMinute > 0 && point.beatsPerMinute.isFinite {
        let index = min(minuteCount - 1, Int(point.secondsFromWorkoutStart / 60))
        buckets[index].append(point.beatsPerMinute)
    }

    var zones = Array(repeating: 0.0, count: 5)
    var observed = 0.0
    for (index, samples) in buckets.enumerated() where !samples.isEmpty {
        let start = Double(index) * 60
        let coveredSeconds = min(60, workoutDurationSeconds - start)
        guard coveredSeconds > 0 else { continue }
        let mean = samples.reduce(0, +) / Double(samples.count)
        let fraction = mean / estimatedMaximumHeartRate
        let zone: Int
        switch fraction {
        case ..<0.60: zone = 0
        case ..<0.70: zone = 1
        case ..<0.80: zone = 2
        case ..<0.90: zone = 3
        default: zone = 4
        }
        let minutes = coveredSeconds / 60
        zones[zone] += minutes
        observed += minutes
    }
    guard observed > 0 else { return nil }
    return CardioHeartRateZoneSummary(zoneMinutes: zones, observedMinutes: observed)
}

public enum LaylaSnapshotIngestionDecision: Equatable, Sendable {
    case accept
    case idempotent
    case rejectStale
    case rejectConflict
}

/// Strict total ordering for selecting one authoritative snapshot. New bridge records use
/// their monotonic sequence before wall-clock time, so a legitimate clock correction does
/// not make Bull revive an older schedule.
public func laylaSnapshotPrecedes(
    _ lhs: LaylaSleepScheduleSnapshot,
    _ rhs: LaylaSleepScheduleSnapshot
) -> Bool {
    switch (lhs.sourceSequence, rhs.sourceSequence) {
    case let (left?, right?) where left != right:
        return left < right
    case (nil, _?):
        return true
    case (_?, nil):
        return false
    default:
        if lhs.updatedTs != rhs.updatedTs { return lhs.updatedTs < rhs.updatedTs }
        return lhs.id < rhs.id
    }
}

/// Pins the first bridge writer identity without guessing Layla's bundle identifier. Legacy
/// pre-bridge snapshots have no bundle field; once a signed App Group writer is observed,
/// later records cannot silently switch to another app identity.
public func laylaSnapshotSourceIdentityIsConsistent(
    incoming: LaylaSleepScheduleSnapshot,
    existing: [LaylaSleepScheduleSnapshot]
) -> Bool {
    guard let incomingBundle = incoming.sourceBundleIdentifier else { return true }
    let knownBundles = Set(existing.compactMap { snapshot in
        snapshot.sourceIdentifier == incoming.sourceIdentifier
            ? snapshot.sourceBundleIdentifier
            : nil
    })
    return knownBundles.isEmpty || knownBundles == Set([incomingBundle])
}

/// Enforces one monotonic Layla authority. Arrival order must never let an older schedule
/// rewrite fields already derived from a newer snapshot.
public func laylaSnapshotIngestionDecision(
    incoming: LaylaSleepScheduleSnapshot,
    existing: [LaylaSleepScheduleSnapshot]
) -> LaylaSnapshotIngestionDecision {
    // New App Group records carry a global monotonic sequence. It is authoritative across
    // civil-day and clock changes, so replaying yesterday's file can never supersede a
    // later update merely because the device clock or time zone changed.
    let sequenced = existing.enumerated().compactMap { item -> (Int, LaylaSleepScheduleSnapshot, Int64)? in
        guard item.element.sourceIdentifier == incoming.sourceIdentifier,
              let sequence = item.element.sourceSequence else { return nil }
        return (item.offset, item.element, sequence)
    }
    if let incomingSequence = incoming.sourceSequence {
        guard let latest = sequenced.max(by: { lhs, rhs in
            lhs.2 == rhs.2 ? lhs.0 < rhs.0 : lhs.2 < rhs.2
        }) else {
            return .accept
        }
        if incomingSequence < latest.2 { return .rejectStale }
        if incomingSequence == latest.2 {
            return incoming == latest.1 ? .idempotent : .rejectConflict
        }
        return .accept
    }
    if !sequenced.isEmpty { return .rejectStale }

    let matching = existing.enumerated().filter {
        $0.element.dayKey == incoming.dayKey &&
            $0.element.sourceIdentifier == incoming.sourceIdentifier
    }
    guard let latest = matching.max(by: { lhs, rhs in
        lhs.element.updatedTs == rhs.element.updatedTs
            ? lhs.offset < rhs.offset
            : lhs.element.updatedTs < rhs.element.updatedTs
    })?.element else {
        return .accept
    }
    if incoming.updatedTs < latest.updatedTs { return .rejectStale }
    if incoming.updatedTs == latest.updatedTs {
        return incoming == latest ? .idempotent : .rejectConflict
    }
    return .accept
}

// MARK: - Additive v12 -> v13 migration

/// v3.1 changes only the active score model. Every v1...v7 frozen snapshot and every
/// legacy observation remains available exactly as history; new combined observations are
/// never manufactured by pairing old rows that happened near one another.
public func migratedBullDataToV13(
    _ source: BullData,
    timeZone: TimeZone = .current,
    now: Date = Date()
) -> BullData {
    var data = migratedBullDataToV12(source, timeZone: timeZone)
    let upgrading = data.version < 13

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.year, .month, .day], from: now)
    let todayKey = String(
        format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1
    )

    if data.settings.fourScoreV8StartDayKey == nil {
        data.settings.fourScoreV8StartDayKey = todayKey
    }
    data.settings.foodPlanLabel = "Bull Fuel"
    if data.settings.stressCheckInTimes.count >= 2 {
        data.settings.stressCheckInTimes = [
            data.settings.stressCheckInTimes.first ?? "08:00",
            data.settings.stressCheckInTimes.last ?? "21:00"
        ]
    } else {
        data.settings.stressCheckInTimes = ["08:00", "21:00"]
    }
    let builtInNames: [String: (canonical: String, legacy: [String])] = [
        "stress.physiological-sigh": ("Physiological Sigh", []),
        "stress.sauna": ("Sauna", []),
        "stress.cold-plunge": ("Cold Plunge", []),
        "stress.sauna-cold": ("Sauna + Cold", []),
        "stress.boxing": ("Boxing", []),
        "stress.nature-walk": ("Nature Walk", ["Riverside / Nature Walk"]),
        "stress.mindfulness": ("Mindfulness", ["Muse / Mindfulness"]),
        "stress.social": ("Social Connection", ["Social Connection / Laughter"])
    ]
    for index in data.stressActivities.indices {
        data.stressActivities[index].weeklyTarget = 0
        if upgrading,
           let names = builtInNames[data.stressActivities[index].id],
           ([names.canonical] + names.legacy).contains(where: {
               data.stressActivities[index].name.caseInsensitiveCompare($0) == .orderedSame
           }) {
            data.stressActivities[index].name = names.canonical
        }
    }

    // The v2.9 default plan was readable prose. v3.1 keeps that prose and adds the exact
    // set structure needed by the execution screen. The parser also helps user-edited
    // strength days; anything ambiguous remains untouched for an explicit human edit.
    if upgrading {
        for planIndex in data.exercisePlans.indices {
            for dayIndex in data.exercisePlans[planIndex].days.indices {
                var day = data.exercisePlans[planIndex].days[dayIndex]
                if day.kind == .strength && (day.strengthExercises?.isEmpty ?? true) {
                    let parsed = v31StructuredExercises(from: day)
                    if !parsed.isEmpty {
                        day.strengthExercises = parsed
                        day.plannedStrengthSession = true
                        data.exercisePlans[planIndex].days[dayIndex] = day
                    }
                }
            }
        }
    }

    if upgrading {
        for index in data.stressReliefLogs.indices where data.stressReliefLogs[index].timing == nil {
            data.stressReliefLogs[index].timing = .migratedLegacy
            if let readingID = data.stressReliefLogs[index].afterReadingID ??
                data.stressReliefLogs[index].laterReadingID,
               let reading = data.stressReadings.first(where: { $0.id == readingID }) {
                data.stressReliefLogs[index].completedTs = reading.ts
            }
        }
        data.version = 13
    }
    return data
}

// MARK: - Additive v13 -> v14 migration

/// v3.2 introduces purpose-specific sleep views without rewriting the generic sleep score
/// or any finalized v3.1 snapshot. Existing days fall back to `sleep` until they are
/// refreshed from HealthKit or explicitly edited.
public func migratedBullDataToV14(
    _ source: BullData,
    timeZone: TimeZone = .current,
    now: Date = Date()
) -> BullData {
    var data = migratedBullDataToV13(source, timeZone: timeZone, now: now)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.year, .month, .day], from: now)
    let todayKey = String(
        format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1
    )
    if data.settings.fourScoreV9StartDayKey == nil {
        data.settings.fourScoreV9StartDayKey = todayKey
    }
    if data.version < 14 { data.version = 14 }
    return data
}

private func v31StructuredExercises(from day: ExercisePlanDay) -> [StrengthExercisePrescription] {
    let pattern = #"([0-9]+)(?:[–-][0-9]+)?\s*[×x]\s*([0-9]+)(?:[–-]([0-9]+))?"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    var result: [StrengthExercisePrescription] = []
    for (index, line) in day.prescription.enumerated() {
        let lower = line.lowercased()
        if lower.contains("zone 2") || lower.contains("cardio") || lower.contains("minutes") ||
            lower.contains("rounds") || lower.contains("warm-up") || lower.contains("cool-down") {
            continue
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let setRange = Range(match.range(at: 1), in: line),
              let minRange = Range(match.range(at: 2), in: line),
              let sets = Int(line[setRange]),
              let minimum = Int(line[minRange]) else { continue }
        let maximum: Int
        if match.range(at: 3).location != NSNotFound,
           let maxRange = Range(match.range(at: 3), in: line),
           let parsed = Int(line[maxRange]) {
            maximum = parsed
        } else {
            maximum = minimum
        }
        let name = line.split(separator: "·", maxSplits: 1)
            .first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? line
        result.append(StrengthExercisePrescription(
            id: "\(day.id).exercise.\(index + 1)",
            name: name,
            targetSets: sets,
            minimumReps: minimum,
            maximumReps: maximum
        ))
    }
    return result
}

// MARK: - Today states

public func v31UrgeState(
    observations: [PornUrgeObservation],
    dayKey: String
) -> UrgeState {
    // Array order is the durable ingestion order. It is a deterministic tie-breaker for
    // legacy retrospective rows that were all stamped at noon; UUID lexical order is not.
    let latest = observations.enumerated()
        .filter { $0.element.dayKey == dayKey }
        .max { lhs, rhs in
            lhs.element.ts == rhs.element.ts ? lhs.offset < rhs.offset : lhs.element.ts < rhs.element.ts
        }?.element
    return UrgeState(
        score: latest.map { Double($0.intensity) * 10 },
        meanPeak: latest.map { Double($0.intensity) },
        observedDays: latest == nil ? 0 : 1,
        windowDays: 1
    )
}

public func v31BullState(
    observations: [BullStateObservation],
    dayKey: String
) -> BullState {
    let indexed = observations.enumerated().filter { $0.element.dayKey == dayKey }
    func erectionValue(_ observation: BullStateObservation) -> Double? {
        switch observation.erection {
        case .notObserved: return nil
        case .no: return 0
        case .yes: return observation.erectionHardnessScore.map { 50 + Double($0) / 4 * 50 }
        }
    }
    // Multiple wakes are one daily observation. Use the most informative/strongest wake;
    // an extra wake never adds weight. Duration is deliberately not scored.
    let erectionHealth = indexed
        .filter { $0.element.kind != .naturalDesire }
        .compactMap { item -> (value: Double, ts: Double, offset: Int)? in
            erectionValue(item.element).map { ($0, item.element.ts, item.offset) }
        }
        .max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            if lhs.ts != rhs.ts { return lhs.ts < rhs.ts }
            return lhs.offset < rhs.offset
        }?.value
    let desireEntry = indexed
        .filter { $0.element.kind != .morningErection && $0.element.healthyDesire != nil }
        .max { lhs, rhs in
            lhs.element.ts == rhs.element.ts ? lhs.offset < rhs.offset : lhs.element.ts < rhs.element.ts
        }?.element
    let healthyDesire = desireEntry.flatMap { $0.healthyDesire }.map { Double($0) * 10 }
    return BullState(
        erectionHealth: erectionHealth,
        healthyDesire: healthyDesire,
        erectionDays: erectionHealth == nil ? 0 : 1,
        desireDays: desireEntry == nil ? 0 : 1,
        windowDays: 1
    )
}

public func v31StressRegulationState(
    readings: [StressReading],
    dayKey: String,
    allowProvisional: Bool = true
) -> StressRegulationState {
    let dayReadings = readings.filter { $0.dayKey == dayKey }
    let morning = dayReadings
        .filter { $0.context == .morning }
        .max { lhs, rhs in lhs.ts == rhs.ts ? lhs.id < rhs.id : lhs.ts < rhs.ts }
    guard let morning else {
        return StressRegulationState(morning: nil, endpoint: nil, score: nil, isFinal: false)
    }

    let evening = dayReadings
        .filter { $0.context == .evening }
        .max { lhs, rhs in lhs.ts == rhs.ts ? lhs.id < rhs.id : lhs.ts < rhs.ts }
    let liveEndpoint = dayReadings
        .filter { reading in
            guard reading.source == .live else { return false }
            return [.checkIn, .activityBefore, .activityAfter, .activityLater].contains(reading.context)
        }
        .max { lhs, rhs in lhs.ts == rhs.ts ? lhs.id < rhs.id : lhs.ts < rhs.ts }
    guard let endpoint = evening ?? (allowProvisional ? (liveEndpoint ?? morning) : nil) else {
        return StressRegulationState(morning: morning, endpoint: nil, score: nil, isFinal: false)
    }

    let reduction = morning.value - endpoint.value
    let score: Double
    if endpoint.value <= 3 { score = 100 }
    else if reduction >= 3 { score = 85 }
    else if reduction == 2 { score = 70 }
    else if reduction == 1 { score = 55 }
    else if reduction == 0 { score = 35 }
    else if reduction == -1 { score = 20 }
    else { score = 0 }
    return StressRegulationState(
        morning: morning,
        endpoint: endpoint,
        score: score,
        isFinal: evening != nil
    )
}

public func v31UrgeRoutineState(
    sleepScore: Double?,
    stressRegulationScore: Double?,
    environmentProtectionScore: Double?,
    fasting: Bool = false
) -> UrgeRoutineState {
    UrgeRoutineState(
        sleepProtection: sleepScore,
        stressPlan: stressRegulationScore,
        environmentProtection: environmentProtectionScore,
        fastingProtection: fasting ? 100 : nil
    )
}

// MARK: - Rolling Bull Routine

public func v31BullRoutineState(
    daysByKey: [(key: String, day: DayRecord)],
    manualExerciseLogs: [ManualExerciseLog],
    strengthWorkoutLogs: [StrengthWorkoutLog],
    scheduledStrengthDays: [String: ExercisePlanDay],
    cardioTarget: Double = 160
) -> BullRoutineState {
    let latestManual = manualExerciseLogs.reduce(into: [String: ManualExerciseLog]()) { result, log in
        if result[log.dayKey].map({ $0.loggedTs < log.loggedTs }) ?? true { result[log.dayKey] = log }
    }
    let latestStructured = strengthWorkoutLogs.reduce(into: [String: StrengthWorkoutLog]()) { result, log in
        if result[log.dayKey].map({ $0.ts < log.ts }) ?? true { result[log.dayKey] = log }
    }

    var moderateEquivalent = 0.0
    var cardioObserved = false
    var cardioActiveCalories = 0.0
    var cardioEnergyObserved = false
    var scheduledSets = 0
    var completedSets = 0
    var completeSessions = 0

    for pair in daysByKey {
        let manual = latestManual[pair.key]
        let aerobic = manual?.aerobicMinutesOverride ?? pair.day.aerobicMinutes
        let vigorous = manual?.vigorousMinutesOverride ?? pair.day.vigorousMinutes
        if aerobic != nil || vigorous != nil {
            cardioObserved = true
            moderateEquivalent += max(0, aerobic ?? 0) + max(0, vigorous ?? 0)
        }
        if let calories = pair.day.cardioActiveCalories {
            cardioActiveCalories += max(0, calories)
            cardioEnergyObserved = true
        }

        guard let planDay = scheduledStrengthDays[pair.key] else { continue }
        let planned = (planDay.strengthExercises ?? []).flatMap { exercise in
            (1...exercise.targetSets).map { "\(exercise.id)#\($0)" }
        }
        guard !planned.isEmpty else { continue }
        let plannedSet = Set(planned)
        scheduledSets += plannedSet.count
        let completed = Set((latestStructured[pair.key]?.sets ?? [])
            .filter { $0.completed }
            .map { "\($0.exerciseID)#\($0.setNumber)" })
            .intersection(plannedSet)
        completedSets += completed.count
        if completed.count == plannedSet.count { completeSessions += 1 }
    }

    let cardio = cardioObserved ? min(100, moderateEquivalent / max(1, cardioTarget) * 100) : nil
    let strength = scheduledSets > 0
        ? min(100, Double(completedSets) / Double(scheduledSets) * 100)
        : nil
    let sleeps = daysByKey.compactMap { $0.day.vigourSleepForScoring }
    let sleep = sleeps.isEmpty ? nil : sleeps.reduce(0, +) / Double(sleeps.count)
    let foods = daysByKey.compactMap { pair -> Double? in
        if let direct = pair.day.bullFuelPercent { return Double(direct) }
        if let record = pair.day.completionStates["heartHealthyEating"] {
            if record.state == .done { return 100 }
            if record.state == .notDone { return 0 }
        }
        if let legacy = pair.day.heartHealthyEating { return legacy ? 100 : 0 }
        return nil
    }
    let food = foods.isEmpty ? nil : foods.reduce(0, +) / Double(foods.count)

    return BullRoutineState(
        cardio: cardio,
        sleep: sleep,
        foodPlan: food,
        strength: strength,
        weeklyModerateEquivalentMinutes: moderateEquivalent,
        weeklyStrengthSessions: completeSessions,
        weeklyCardioActiveCalories: cardioEnergyObserved ? cardioActiveCalories : nil,
        weeklyStrengthCompletedSets: completedSets,
        weeklyStrengthScheduledSets: scheduledSets
    )
}
