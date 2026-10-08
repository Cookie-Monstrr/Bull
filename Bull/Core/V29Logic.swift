import Foundation

// MARK: - v2.9 migration

/// Pure v10→v11 migration. It only adds/classifies v2.9 data and archives retired live
/// controls; it never deletes an item, event, snapshot, private-context session, plan or log.
public func migratedBullDataToV11(
    _ source: BullData,
    timeZone: TimeZone = .current
) -> BullData {
    var data = migratedBullDataToV10(source, timeZone: timeZone)

    let isV11Upgrade = data.version < 11
    if isV11Upgrade {
        for index in data.items.indices {
            switch data.items[index].id {
            case "accountabilityGap", "fasting":
                data.items[index].archived = true
            default:
                break
            }
        }
    }

    func classify(
        _ id: String,
        name: String? = nil,
        lane: ProtectiveActionLane,
        archived: Bool = false,
        aliases: [String] = []
    ) {
        guard let index = data.responseLibrary.firstIndex(where: { $0.id == id }) else { return }
        if let name, data.responseLibrary[index].name != name {
            let previous = data.responseLibrary[index].name
            data.responseLibrary[index].name = name
            data.responseLibrary[index].aliases = Array(Set(
                data.responseLibrary[index].aliases + aliases + [previous]
            ))
        }
        data.responseLibrary[index].lane = lane
        data.responseLibrary[index].archived = archived
    }

    if isV11Upgrade {
        classify("response.sigh", lane: .countermove)
        classify("response.leave", name: "Leave the risky environment", lane: .countermove)
        classify("response.block", name: "Block explicit-content access", lane: .countermove)
        classify(
            "response.connection",
            name: "Uplifting connection",
            lane: .countermove,
            aliases: ["Heart-warming laughter with friends"]
        )
        classify("response.cold-plunge", lane: .damageControl)
        classify("response.contact", lane: .countermove, archived: true)
        classify("response.if-then", lane: .countermove, archived: true)
    }

    if !data.responseLibrary.contains(where: { $0.id == "response.boxing" }) {
        data.responseLibrary.append(ResponseDefinition(
            id: "response.boxing",
            name: "Boxing",
            evidence: .personal,
            protectionWeight: .med,
            protectionMinutes: 180,
            lane: .countermove
        ))
    }
    if data.exercisePlans.isEmpty { data.exercisePlans = [V29Defaults.exercisePlan] }

    // Preserve every old accountability field and row, but make explicit that it is no
    // longer an active Risk input. Future Lapse Oversight can read this history opt-in.
    if isV11Upgrade { data.version = 11 }
    return data
}

// MARK: - Urge Risk v6

private func v29Clamp01(_ value: Double) -> Double { min(1, max(0, value)) }

/// Converts the current four-component score into an alert tier. Consecutive whole-score
/// days are deliberately absent: persistence is already represented inside the factors
/// that have a justified time course, so a Watch score cannot become Emergency merely by
/// surviving for three days.
public func v29RiskTier(
    score: Int,
    thresholds: PressureThresholds = PressureThresholds(watch: 55, warning: 65, emergency: 78)
) -> PressureTier {
    let bounded = min(100, max(0, score))
    if bounded >= Int(thresholds.emergency) { return .emergency }
    if bounded >= Int(thresholds.warning) { return .warning }
    if bounded >= Int(thresholds.watch) { return .watch }
    return .normal
}

/// Four independent, bounded components. `sleepScoresTodayFirst` is [today, yesterday,
/// two days ago]. Missing observations contribute neither points nor fake reassurance;
/// `dataCoverage` exposes how much of the 100-point model was actually observed.
public func v29UrgeRiskState(
    sleepScoresTodayFirst: [Double?],
    access: AccessLevel?,
    riskyEnvironmentPoints: Double,
    environmentObserved: Bool,
    hoursSinceLapse: Double?,
    hoursSinceWetDream: Double?
) -> UrgeRiskState {
    let sleepWeights = [20.0, 12.0, 8.0] // 50/30/20% of the 40-point component
    var sleep = 0.0
    var observedModelWeight = 0.0
    for index in sleepWeights.indices {
        guard sleepScoresTodayFirst.indices.contains(index),
              let score = sleepScoresTodayFirst[index], score.isFinite else { continue }
        let deficit = v29Clamp01((85 - score) / 55)
        sleep += deficit * sleepWeights[index]
        observedModelWeight += sleepWeights[index]
    }

    let content: Double
    switch access {
    case .high: content = 25
    case .med: content = 12.5
    case .low: content = 0
    case nil: content = 0
    }
    if access != nil { observedModelWeight += 25 }

    let environment = min(20, max(0, riskyEnvironmentPoints))
    if environmentObserved { observedModelWeight += 20 }

    let lapseRebound: Double = hoursSinceLapse.map { hours in
        guard hours >= 0, hours < 48 else { return 0 }
        return 15 * (1 - hours / 48)
    } ?? 0
    let wetDreamRebound: Double = hoursSinceWetDream.map { hours in
        // Personal pattern: little/no immediate pull after waking, then a gradual rise
        // through the waking day. Keep it materially milder than a lapse and let it clear.
        guard hours >= 2, hours < 48 else { return 0 }
        if hours < 12 { return 6 * ((hours - 2) / 10) }
        return 6 * (1 - (hours - 12) / 36)
    } ?? 0
    // Release events are explicit logs: absence is observed absence, and overlapping events
    // use the larger estimate rather than stacking two hypotheses.
    let rebound = max(lapseRebound, wetDreamRebound)
    observedModelWeight += 15

    return UrgeRiskState(
        sleepRecovery: sleep,
        explicitContent: content,
        riskyEnvironment: environment,
        postReleaseRebound: rebound,
        dataCoverage: observedModelWeight / 100
    )
}

// MARK: - Sexual Vigour v6

/// Rolling output-only Sexual Vigour. Morning frequency and EHS are combined inside the
/// erection component; healthy desire is kept distinct from urge intensity. At least four
/// observed days per component are required, otherwise the overall value remains missing.
public func v29SexualVigourState(
    observations: [DailySexualObservation],
    legacyLibidoSpots: [LibidoSpot] = [],
    dayKeys: Set<String>,
    minimumDaysPerComponent: Int = 4
) -> SexualVigourState {
    let latest = observations
        .filter { dayKeys.contains($0.dayKey) }
        .reduce(into: [String: DailySexualObservation]()) { result, observation in
            if result[observation.dayKey].map({ $0.ts < observation.ts }) ?? true {
                result[observation.dayKey] = observation
            }
        }

    let observedMornings = latest.values.filter { $0.morningErection != .notObserved }
    let yesMornings = observedMornings.filter { $0.morningErection == .yes }
    let frequency = observedMornings.isEmpty ? nil :
        Double(yesMornings.count) / Double(observedMornings.count) * 100
    let hardnessValues = yesMornings.compactMap { value -> Double? in
        if let ehs = value.erectionHardnessScore { return Double(ehs) / 4 * 100 }
        if let legacy = value.erectionQuality { return Double(legacy) / 10 * 100 }
        return nil
    }
    let hardness = hardnessValues.isEmpty ? nil :
        hardnessValues.reduce(0, +) / Double(hardnessValues.count)
    let erectionHealth: Double?
    if let frequency, let hardness { erectionHealth = frequency * 0.5 + hardness * 0.5 }
    else { erectionHealth = frequency ?? hardness }

    let spotsByDay = Dictionary(grouping: legacyLibidoSpots.filter { dayKeys.contains($0.dayKey) }) {
        $0.dayKey
    }
    var desireByDay: [String: Double] = [:]
    for key in dayKeys {
        if let direct = latest[key]?.healthyDesire {
            desireByDay[key] = Double(direct)
        } else if let spots = spotsByDay[key], !spots.isEmpty {
            desireByDay[key] = Double(spots.map(\.rating).reduce(0, +)) / Double(spots.count)
        }
    }
    let desire = desireByDay.isEmpty ? nil :
        desireByDay.values.reduce(0, +) / Double(desireByDay.count) * 10

    return SexualVigourState(
        erectionHealth: erectionHealth,
        healthyDesire: desire,
        erectionDays: observedMornings.count,
        desireDays: desireByDay.count,
        windowDays: max(1, dayKeys.count),
        minimumDaysPerComponent: minimumDaysPerComponent
    )
}

// MARK: - Recovery and Vigour Routine v6

public func v29PersonalBaselineScore(
    current: Double?,
    baseline: Double?,
    higherIsBetter: Bool,
    sensitivity: Double
) -> Double? {
    guard let current, let baseline, current.isFinite, baseline.isFinite,
          current > 0, baseline > 0 else { return nil }
    let direction = higherIsBetter ? 1.0 : -1.0
    let deviationPercent = (current / baseline - 1) * 100 * direction
    return min(100, max(0, 70 + deviationPercent * sensitivity))
}

/// Recovery is a multi-input readiness context, not HRV alone. Missing components are
/// omitted and surfaced through coverage; no missing value is converted to an invented 50.
public func v29RecoveryComposite(
    sleepScore: Double?,
    hrv: Double?,
    hrvBaseline: Double?,
    restingHeartRate: Double?,
    restingHeartRateBaseline: Double?,
    recentModerateEquivalentMinutes: Double?,
    recentStrengthSessions: Int?
) -> RecoveryCompositeState {
    let sleep = sleepScore.map { min(100, max(0, $0)) }
    let hrvScore = v29PersonalBaselineScore(
        current: hrv, baseline: hrvBaseline, higherIsBetter: true, sensitivity: 2
    )
    let rhrScore = v29PersonalBaselineScore(
        current: restingHeartRate,
        baseline: restingHeartRateBaseline,
        higherIsBetter: false,
        sensitivity: 4
    )
    let training: Double? = recentModerateEquivalentMinutes.map { minutes in
        let strength = recentStrengthSessions ?? 0
        if minutes > 300 || strength >= 3 { return 40 }
        if minutes > 220 || strength == 2 { return 65 }
        return 85
    }
    let pieces: [(Double?, Double)] = [
        (sleep, 0.50), (hrvScore, 0.25), (rhrScore, 0.15), (training, 0.10)
    ]
    let observed = pieces.compactMap { piece -> (Double, Double)? in
        piece.0.map { ($0, piece.1) }
    }
    let weight = observed.map { $0.1 }.reduce(0, +)
    let score = weight > 0 ? observed.reduce(0) { $0 + $1.0 * $1.1 } / weight : nil
    return RecoveryCompositeState(
        score: score,
        sleep: sleep,
        hrv: hrvScore,
        restingHeartRate: rhrScore,
        trainingBalance: training,
        dataCoverage: weight
    )
}

/// Seven civil days are summed into one cumulative weekly exercise dose. HealthKit stores
/// vigorous minutes as a subset of aerobic minutes, so `aerobic + vigorous` intentionally
/// counts moderate minutes once and vigorous minutes twice (moderate-equivalent minutes).
public func v29VigourRoutineState(
    daysByKey: [(key: String, day: DayRecord)],
    manualExerciseLogs: [ManualExerciseLog],
    recovery: RecoveryCompositeState,
    cardioTarget: Double = 160,
    strengthTarget: Int = 3
) -> VigourRoutineState {
    let latestManual = manualExerciseLogs.reduce(into: [String: ManualExerciseLog]()) { result, log in
        if result[log.dayKey].map({ $0.loggedTs < log.loggedTs }) ?? true { result[log.dayKey] = log }
    }
    var moderateEquivalent = 0.0
    var workoutObserved = false
    var strengthSessions = 0
    var strengthObserved = false

    for pair in daysByKey {
        let manual = latestManual[pair.key]
        let aerobic = manual?.aerobicMinutesOverride ?? pair.day.aerobicMinutes
        let vigorous = manual?.vigorousMinutesOverride ?? pair.day.vigorousMinutes
        if aerobic != nil || vigorous != nil {
            workoutObserved = true
            moderateEquivalent += max(0, aerobic ?? 0) + max(0, vigorous ?? 0)
        }
        if let completed = manual?.strengthSessionCompleted {
            strengthObserved = true
            if completed { strengthSessions += 1 }
        } else if let minutes = pair.day.strengthMinutes {
            // Historical/import fallback only; v2.9's live strength control is manual-first.
            strengthObserved = true
            if minutes >= 15 { strengthSessions += 1 }
        }
    }

    let cardio = workoutObserved
        ? min(100, moderateEquivalent / max(1, cardioTarget) * 100)
        : nil
    let strength = strengthObserved
        ? min(100, Double(strengthSessions) / Double(max(1, strengthTarget)) * 100)
        : nil

    let foodRecords = daysByKey.compactMap { pair -> CompletionState? in
        if let record = pair.day.completionStates["heartHealthyEating"] { return record.state }
        if let legacy = pair.day.heartHealthyEating { return legacy ? .done : .notDone }
        return nil
    }
    let foodObserved = foodRecords.filter { $0 == .done || $0 == .notDone }
    let food = foodObserved.isEmpty ? nil :
        Double(foodObserved.filter { $0 == .done }.count) / Double(foodObserved.count) * 100

    return VigourRoutineState(
        cardio: cardio,
        recovery: recovery.score,
        foodPlan: food,
        strength: strength,
        weeklyModerateEquivalentMinutes: moderateEquivalent,
        weeklyStrengthSessions: strengthSessions
    )
}

// MARK: - Human-approved progression

public func v29ExerciseDecision(
    weeksSincePlanStart: Int,
    routine: VigourRoutineState,
    recovery: RecoveryCompositeState,
    erectionChangeFrom28DayBaseline: Double?
) -> (decision: ExercisePlanDecision, rationale: String) {
    if recovery.score.map({ $0 < 55 }) == true ||
        erectionChangeFrom28DayBaseline.map({ $0 <= -10 }) == true {
        return (
            .recover,
            "Recovery or the lagging erection-health trend is below baseline. Reduce one load variable, restore recovery, and reassess; do not chase more intensity."
        )
    }
    if weeksSincePlanStart < 2 {
        return (.hold, "Weeks 1–2 calibrate loads and technique. Keep the plan stable while Bull gathers comparable data.")
    }
    if weeksSincePlanStart >= 5, weeksSincePlanStart % 6 == 5 {
        return (.hold, "The next week consolidates this six-week block. Hold the effective dose and review the next version instead of adding load automatically.")
    }
    if weeksSincePlanStart >= 12 {
        guard let erectionChangeFrom28DayBaseline else {
            return (
                .hold,
                "The 12-week outcome review needs enough observed mornings in both 28-day windows. Hold the effective dose instead of progressing from adherence alone."
            )
        }
        if erectionChangeFrom28DayBaseline < 5 {
            return (
                .hold,
                "The current 28-day erection-health trend has not improved meaningfully from the original baseline. Hold the effective exercise dose and review sleep, diet, stress and medical factors rather than adding more work."
            )
        }
    }
    guard routine.dataCoverage >= 0.60, recovery.dataCoverage >= 0.50 else {
        return (.hold, "There is not enough observed routine and recovery data to justify a progression.")
    }
    guard routine.score.map({ $0 >= 75 }) == true,
          recovery.score.map({ $0 >= 65 }) == true else {
        return (.hold, "Adherence or recovery is still adapting. Repeat the current prescription before changing one variable.")
    }
    return (
        .progress,
        "Performance and recovery support one small change: add load after two clean top-of-range completions, improve Zone 2 pace at the same effort, or add one boxing round—never all three at once."
    )
}

public func v29PlanVersion(
    from current: ExercisePlanVersion,
    applying decision: ExercisePlanDecision,
    startDayKey: String,
    progressionFocus: ExerciseProgressionFocus? = nil,
    phaseOverride: ExercisePlanPhase? = nil
) -> ExercisePlanVersion {
    // Progress is deliberately incomplete until the person selects the one variable that
    // actually met its criterion. Never invent a default focus in the data layer.
    if decision == .progress, progressionFocus == nil { return current }
    var next = current
    next.id = UUID().uuidString
    next.versionNumber = current.versionNumber + 1
    next.startDayKey = startDayKey
    next.programStartDayKey = current.programStartDayKey ?? current.startDayKey
    next.endDayKey = nil
    next.createdTs = Date().timeIntervalSince1970 * 1_000
    switch decision {
    case .progress:
        next.phase = .build
        guard let focus = progressionFocus else { return current }
        next.lastProgressionFocus = focus
        switch focus {
        case .strengthLoad:
            next.rationale = "Progress accepted for eligible strength loads only: after two clean top-of-range completions with about two reps in reserve, add roughly 2.5% upper-body or 2.5–5% lower-body load. Keep cardio and boxing unchanged."
        case .zone2Efficiency:
            next.rationale = "Progress accepted for Zone 2 efficiency only: keep the weekly duration and effort broadly stable, and aim for slightly more pace or distance at the same heart rate. Keep strength and boxing unchanged."
        case .boxingRound:
            let oldRounds = current.boxingRounds ?? 10
            let newRounds = oldRounds + 1
            next.boxingRounds = newRounds
            for index in next.days.indices where next.days[index].kind == .boxing {
                next.days[index].prescription = next.days[index].prescription.map { line in
                    line.replacingOccurrences(of: "\(oldRounds) rounds", with: "\(newRounds) rounds")
                }
            }
            next.rationale = "Progress accepted for boxing only: add one round while keeping round intensity, recovery, strength and Zone 2 dose unchanged."
        }
    case .hold:
        next.phase = current.phase == .calibration ? .calibration : .maintain
        next.lastProgressionFocus = nil
        next.rationale = "Hold accepted: repeat the effective dose while more comparable performance, recovery and erection-health data accumulate."
    case .recover:
        next.phase = .consolidate
        next.lastProgressionFocus = nil
        next.rationale = "Recover accepted: reduce one load variable and prioritise sleep and recovery. Excess work earns no extra routine credit."
    }
    if let phaseOverride { next.phase = phaseOverride }
    return next
}
