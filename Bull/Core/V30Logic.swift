import Foundation

// MARK: - Additive v11 -> v12 migration

/// Adds v3.0 observation streams and archives the retired explicit-access control. All
/// legacy fields, events and v1...v6 score snapshots remain byte-for-byte representable.
public func migratedBullDataToV12(
    _ source: BullData,
    timeZone: TimeZone = .current
) -> BullData {
    var data = migratedBullDataToV11(source, timeZone: timeZone)
    let upgrading = data.version < 12

    // Also repair a brand-new v12 container. Defaults must not depend on pretending a new
    // install is an old-version migration.
    if data.settings.fourScoreStartDayKey == nil {
        var startCalendar = Calendar(identifier: .gregorian)
        startCalendar.timeZone = timeZone
        let parts = startCalendar.dateComponents([.year, .month, .day], from: Date())
        data.settings.fourScoreStartDayKey = String(
            format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1
        )
    }
    for index in data.items.indices where ["contentAccess", "nasalclear"].contains(data.items[index].id) {
        data.items[index].archived = true
    }
    let defaultActivityIDs = Set(data.stressActivities.map(\.id))
    data.stressActivities.append(contentsOf: V30Defaults.stressActivities.filter {
        !defaultActivityIDs.contains($0.id)
    })
    let defaultExperiments = [
        PersonalFactor(
            id: "nasalclear", name: "Nasal cleaning", kind: .action,
            intendedOutcome: .wellbeing,
            hypothesis: "Track whether nasal cleaning coincides with better sleep or comfort.",
            scheduleDescription: "Optional",
            startDayKey: data.settings.fourScoreStartDayKey ?? ""
        ),
        PersonalFactor(
            id: "experiment.accountability-support", name: "Accountability", kind: .action,
            intendedOutcome: .highUrge,
            hypothesis: "Track whether meaningful support coincides with lower perceived urge.",
            scheduleDescription: "When it happens",
            startDayKey: data.settings.fourScoreStartDayKey ?? ""
        )
    ]
    for factor in defaultExperiments where
        !data.personalFactors.contains(where: { $0.id == factor.id }) {
        data.personalFactors.append(factor)
    }

    if upgrading {
        // A legacy daily stress value becomes one honest noon observation. It is not
        // duplicated when a v12 reading already exists for that civil day.
        let existingStressDays = Set(data.stressReadings.map(\.dayKey))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        for (key, day) in data.days where !existingStressDays.contains(key) {
            guard let stress = day.stressLevel else { continue }
            let pieces = key.split(separator: "-").compactMap { Int($0) }
            guard pieces.count == 3,
                  let date = calendar.date(from: DateComponents(
                    year: pieces[0], month: pieces[1], day: pieces[2], hour: 12
                  )) else { continue }
            data.stressReadings.append(StressReading(
                ts: date.timeIntervalSince1970 * 1_000,
                dayKey: key,
                value: stress,
                context: .checkIn,
                source: .migratedLegacy
            ))
        }
        data.version = 12
    }
    return data
}

// MARK: - Stress

/// Every rating holds until the next rating. Time before the first reading is left missing,
/// preventing one late-night check-in from pretending to describe the whole day.
public func v30TimeWeightedStress(
    readings: [StressReading],
    dayStartTs: Double,
    dayEndTs: Double
) -> TimeWeightedStressState {
    guard dayEndTs > dayStartTs else {
        return TimeWeightedStressState(average: nil, observedHours: 0, readingCount: 0)
    }
    let sorted = readings
        .filter { $0.ts >= dayStartTs && $0.ts < dayEndTs }
        .sorted { lhs, rhs in lhs.ts == rhs.ts ? lhs.id < rhs.id : lhs.ts < rhs.ts }
    guard !sorted.isEmpty else {
        return TimeWeightedStressState(average: nil, observedHours: 0, readingCount: 0)
    }
    var weighted = 0.0
    var duration = 0.0
    for index in sorted.indices {
        let start = max(dayStartTs, sorted[index].ts)
        let end = index + 1 < sorted.count ? min(dayEndTs, sorted[index + 1].ts) : dayEndTs
        let span = max(0, end - start)
        weighted += Double(sorted[index].value) * span
        duration += span
    }
    return TimeWeightedStressState(
        average: duration > 0 ? weighted / duration : Double(sorted.last!.value),
        observedHours: duration / 3_600_000,
        readingCount: sorted.count
    )
}

public func v30StressActivityLeaderboard(
    logs: [StressReliefLog],
    readings: [StressReading],
    activities: [StressActivityDefinition]
) -> [StressActivityEffect] {
    let readingByID = readings.reduce(into: [String: StressReading]()) { $0[$1.id] = $1 }
    let nameByID = activities.reduce(into: [String: String]()) { $0[$1.id] = $1.name }
    var pairs: [String: [(start: Double, drop: Double, delayed: Bool, timing: StressReliefTiming?)]] = [:]
    for log in logs {
        guard let beforeID = log.beforeReadingID,
              let before = readingByID[beforeID] else { continue }
        let after = log.afterReadingID.flatMap { readingByID[$0] }
            ?? log.laterReadingID.flatMap { readingByID[$0] }
        guard let after else { continue }
        pairs[log.activityID, default: []].append((
            start: Double(before.value),
            drop: Double(before.value - after.value),
            delayed: log.afterReadingID == nil && log.laterReadingID != nil,
            timing: log.timing
        ))
    }
    return pairs.map { activityID, values in
        let prospective = values.filter { $0.timing == .prospective }
        let estimated = values.filter { $0.timing == .estimatedAfterwards }
        let legacy = values.filter { $0.timing == nil || $0.timing == .migratedLegacy }
        let prospectiveMedian = v30Median(prospective.map { $0.drop })
        let estimatedMedian = v30Median(estimated.map { $0.drop })
        return StressActivityEffect(
            activityID: activityID,
            name: nameByID[activityID] ?? "Archived Activity",
            medianDrop: prospectiveMedian ?? estimatedMedian ?? v30Median(legacy.map { $0.drop }) ?? 0,
            typicalStartingStress: v30Median(values.map { $0.start }) ?? 0,
            pairedCount: values.count,
            delayedCount: values.filter { $0.delayed }.count,
            prospectiveCount: prospective.count,
            estimatedCount: estimated.count,
            prospectiveMedianDrop: prospectiveMedian,
            estimatedMedianDrop: estimatedMedian
        )
    }
    .sorted {
        let lhsTier = $0.prospectiveCount > 0 ? 2 : ($0.estimatedCount > 0 ? 1 : 0)
        let rhsTier = $1.prospectiveCount > 0 ? 2 : ($1.estimatedCount > 0 ? 1 : 0)
        if lhsTier != rhsTier { return lhsTier > rhsTier }
        if $0.medianDrop != $1.medianDrop { return $0.medianDrop > $1.medianDrop }
        if $0.pairedCount != $1.pairedCount { return $0.pairedCount > $1.pairedCount }
        return $0.name < $1.name
    }
}

// MARK: - Four scores

public func v30UrgeState(
    observations: [PornUrgeObservation],
    orderedDayKeys: [String]
) -> UrgeState {
    let keySet = Set(orderedDayKeys)
    let grouped = Dictionary(grouping: observations.filter { keySet.contains($0.dayKey) }, by: \.dayKey)
    let peaks = orderedDayKeys.compactMap { key in grouped[key]?.map(\.intensity).max() }
    let mean = peaks.isEmpty ? nil : Double(peaks.reduce(0, +)) / Double(peaks.count)
    return UrgeState(
        score: mean.map { $0 * 10 },
        meanPeak: mean,
        observedDays: peaks.count,
        windowDays: max(1, orderedDayKeys.count)
    )
}

public func v30BullState(
    wakeObservations: [WakeErectionObservation],
    dailyObservations: [DailySexualObservation],
    legacyLibidoSpots: [LibidoSpot] = [],
    orderedDayKeys: [String]
) -> BullState {
    let keySet = Set(orderedDayKeys)
    let wakesByDay = Dictionary(grouping: wakeObservations.filter {
        keySet.contains($0.dayKey) && $0.erection != .notObserved
    }, by: \.dayKey)
    let latestDaily = dailyObservations.filter { keySet.contains($0.dayKey) }
        .reduce(into: [String: DailySexualObservation]()) { result, observation in
            if result[observation.dayKey].map({ $0.ts < observation.ts }) ?? true {
                result[observation.dayKey] = observation
            }
        }

    var dayErections: [(yes: Bool, hardness: Double?)] = []
    for key in orderedDayKeys {
        if let wakes = wakesByDay[key], !wakes.isEmpty {
            let yes = wakes.filter { $0.erection == .yes }
            dayErections.append((
                !yes.isEmpty,
                yes.compactMap(\.erectionHardnessScore).max().map { Double($0) / 4 * 100 }
            ))
        } else if let legacy = latestDaily[key], legacy.morningErection != .notObserved {
            let hardness: Double?
            if let ehs = legacy.erectionHardnessScore { hardness = Double(ehs) / 4 * 100 }
            else if let quality = legacy.erectionQuality { hardness = Double(quality) / 10 * 100 }
            else { hardness = nil }
            dayErections.append((legacy.morningErection == .yes, hardness))
        }
    }
    let frequency = dayErections.isEmpty ? nil :
        Double(dayErections.filter { $0.yes }.count) / Double(dayErections.count) * 100
    let hardnesses = dayErections.filter { $0.yes }.compactMap { $0.hardness }
    let hardness = hardnesses.isEmpty ? nil : hardnesses.reduce(0, +) / Double(hardnesses.count)
    let erectionHealth: Double?
    if let frequency, let hardness { erectionHealth = frequency * 0.5 + hardness * 0.5 }
    else { erectionHealth = frequency ?? hardness }

    let spotsByDay = Dictionary(grouping: legacyLibidoSpots.filter { keySet.contains($0.dayKey) }, by: \.dayKey)
    var desireValues: [Double] = []
    for key in orderedDayKeys {
        if let direct = latestDaily[key]?.healthyDesire { desireValues.append(Double(direct)) }
        else if let spots = spotsByDay[key], !spots.isEmpty {
            desireValues.append(Double(spots.map(\.rating).reduce(0, +)) / Double(spots.count))
        }
    }
    let desire = desireValues.isEmpty ? nil : desireValues.reduce(0, +) / Double(desireValues.count) * 10
    return BullState(
        erectionHealth: erectionHealth,
        healthyDesire: desire,
        erectionDays: dayErections.count,
        desireDays: desireValues.count,
        windowDays: max(1, orderedDayKeys.count)
    )
}

public func v30StressPlanScore(
    activities: [StressActivityDefinition],
    logs: [StressReliefLog]
) -> Double? {
    let planned = activities.filter { $0.enabled && !$0.archived && $0.weeklyTarget > 0 }
    let target = planned.reduce(0) { $0 + $1.weeklyTarget }
    guard target > 0 else { return nil }
    let plannedIDs = Set(planned.map(\.id))
    let completed = logs.filter { plannedIDs.contains($0.activityID) }.count
    return min(100, Double(completed) / Double(target) * 100)
}

public func v30EnvironmentProtectionScore(
    exposedZoneDays: Set<String>,
    safeguardedZoneDays: Set<String>,
    orderedDayKeys: [String]
) -> Double {
    guard !orderedDayKeys.isEmpty else { return 100 }
    let successfulDays = orderedDayKeys.filter { key in
        !exposedZoneDays.contains(key) || safeguardedZoneDays.contains(key)
    }.count
    return Double(successfulDays) / Double(orderedDayKeys.count) * 100
}

public func v30UrgeRoutineState(
    sleepScores: [Double],
    stressPlanScore: Double?,
    environmentProtectionScore: Double?
) -> UrgeRoutineState {
    let sleep = sleepScores.isEmpty ? nil :
        sleepScores.map { min(100, max(0, $0)) }.reduce(0, +) / Double(sleepScores.count)
    return UrgeRoutineState(
        sleepProtection: sleep,
        stressPlan: stressPlanScore,
        environmentProtection: environmentProtectionScore
    )
}

public func v30BullRoutineState(
    daysByKey: [(key: String, day: DayRecord)],
    manualExerciseLogs: [ManualExerciseLog],
    strengthWorkoutLogs: [StrengthWorkoutLog] = [],
    cardioTarget: Double = 160,
    strengthTarget: Int = 3
) -> BullRoutineState {
    let latestManual = manualExerciseLogs.reduce(into: [String: ManualExerciseLog]()) { result, log in
        if result[log.dayKey].map({ $0.loggedTs < log.loggedTs }) ?? true { result[log.dayKey] = log }
    }
    var moderateEquivalent = 0.0
    var cardioObserved = false
    var strengthSessions = 0
    var strengthObserved = false
    let latestStructured = strengthWorkoutLogs.reduce(into: [String: StrengthWorkoutLog]()) { result, log in
        if result[log.dayKey].map({ $0.ts < log.ts }) ?? true { result[log.dayKey] = log }
    }
    for pair in daysByKey {
        let manual = latestManual[pair.key]
        let aerobic = manual?.aerobicMinutesOverride ?? pair.day.aerobicMinutes
        let vigorous = manual?.vigorousMinutesOverride ?? pair.day.vigorousMinutes
        if aerobic != nil || vigorous != nil {
            cardioObserved = true
            moderateEquivalent += max(0, aerobic ?? 0) + max(0, vigorous ?? 0)
        }
        if let structured = latestStructured[pair.key] {
            strengthObserved = true
            if structured.completed { strengthSessions += 1 }
        } else if let completed = manual?.strengthSessionCompleted {
            strengthObserved = true
            if completed { strengthSessions += 1 }
        } else if let minutes = pair.day.strengthMinutes {
            strengthObserved = true
            if minutes >= 15 { strengthSessions += 1 }
        }
    }
    let cardio = cardioObserved ? min(100, moderateEquivalent / max(1, cardioTarget) * 100) : nil
    let strength = strengthObserved
        ? min(100, Double(strengthSessions) / Double(max(1, strengthTarget)) * 100)
        : nil
    let sleeps = daysByKey.compactMap { $0.day.sleep }
    let sleep = sleeps.isEmpty ? nil : sleeps.reduce(0, +) / Double(sleeps.count)
    let foods = daysByKey.compactMap { pair -> CompletionState? in
        if let record = pair.day.completionStates["heartHealthyEating"] { return record.state }
        if let legacy = pair.day.heartHealthyEating { return legacy ? .done : .notDone }
        return nil
    }.filter { $0 == .done || $0 == .notDone }
    let food = foods.isEmpty ? nil : Double(foods.filter { $0 == .done }.count) / Double(foods.count) * 100
    return BullRoutineState(
        cardio: cardio, sleep: sleep, foodPlan: food, strength: strength,
        weeklyModerateEquivalentMinutes: moderateEquivalent,
        weeklyStrengthSessions: strengthSessions
    )
}

private func v30Median(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2)
        ? (sorted[middle - 1] + sorted[middle]) / 2
        : sorted[middle]
}
