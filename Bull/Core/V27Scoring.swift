import Foundation

// MARK: - Compounded Risk (independent of Vigour)

public struct CompoundedRiskState: Equatable, Sendable {
    public var baseRisk: Int
    public var carryover: Double
    public var protection: Double
    public var currentRisk: Int
    public var consecutiveElevatedDays: Int
    public var tier: PressureTier

    public init(
        baseRisk: Int,
        carryover: Double,
        protection: Double,
        currentRisk: Int,
        consecutiveElevatedDays: Int,
        tier: PressureTier
    ) {
        self.baseRisk = baseRisk
        self.carryover = carryover
        self.protection = protection
        self.currentRisk = currentRisk
        self.consecutiveElevatedDays = consecutiveElevatedDays
        self.tier = tier
    }
}

/// Multi-day vulnerability remains useful, but v2.7 compounds Risk only—never depleted
/// Vigour. Carry-over is intentionally capped and decays across four prior civil days.
public func compoundedRiskState(
    baseRisk: Int,
    recentBaseRisks: [Int],
    activeProtection: Double,
    thresholds: PressureThresholds = PressureThresholds(watch: 55, warning: 65, emergency: 78)
) -> CompoundedRiskState {
    let weights = [0.30, 0.18, 0.10, 0.05]
    var carryover = 0.0
    for (index, value) in recentBaseRisks.prefix(weights.count).enumerated() {
        // A genuinely low-risk day breaks the accumulated chain.
        if value < 35 { break }
        carryover += max(0, Double(value - 45)) * weights[index]
    }
    carryover = min(20, max(0, carryover))
    let protection = min(15, max(0, activeProtection))
    let current = max(0, min(100, Int((Double(baseRisk) + carryover - protection).rounded())))

    var streak = baseRisk >= Int(thresholds.watch) ? 1 : 0
    if streak > 0 {
        for risk in recentBaseRisks {
            if risk >= Int(thresholds.watch) { streak += 1 }
            else { break }
        }
    }

    let tier: PressureTier
    if current >= Int(thresholds.emergency) && streak >= thresholds.emergencyDays {
        tier = .emergency
    } else if current >= Int(thresholds.warning) && streak >= thresholds.warningDays {
        tier = .warning
    } else if current >= Int(thresholds.watch) {
        tier = .watch
    } else {
        tier = .normal
    }
    return CompoundedRiskState(
        baseRisk: baseRisk,
        carryover: carryover,
        protection: protection,
        currentRisk: current,
        consecutiveElevatedDays: streak,
        tier: tier
    )
}

/// A small, symmetric, provisional modifier for nightly HRV relative to the user's own
/// rolling baseline. A 20% deviation reaches the ±10-point cap; absolute HRV is irrelevant.
public func hrvRiskModifier(hrv: Double?, baseline: Double?) -> Int {
    guard let hrv, let baseline, hrv > 0, baseline > 0 else { return 0 }
    let deviation = max(-0.20, min(0.20, hrv / baseline - 1))
    return Int((-deviation * 50).rounded())
}

/// Time-aware modifier for the user's repeated post-wet-dream surge. The event is logged on
/// the waking civil day. Risk begins rising two hours after waking (or 10:00 when no wake
/// timestamp is available) and ramps toward the user's provisional High cap by midnight.
public func wetDreamRiskModifier(
    now: Date,
    hadWetDreamOnWakingDay: Bool,
    wakeTimestampMS: Double?,
    calendar: Calendar = .current
) -> Int {
    guard hadWetDreamOnWakingDay else { return 0 }
    let activeFrom: Date
    if let wakeTimestampMS {
        activeFrom = Date(timeIntervalSince1970: wakeTimestampMS / 1000).addingTimeInterval(2 * 3600)
    } else {
        activeFrom = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
    }
    guard now >= activeFrom else { return 0 }
    let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        ?? now.addingTimeInterval(12 * 3600)
    let duration = max(1, dayEnd.timeIntervalSince(activeFrom))
    let progress = max(0, min(1, now.timeIntervalSince(activeFrom) / duration))
    return Int((Double(Weight.high.riskPoints) * progress).rounded())
}

/// Completed Responses only earn Protection when an urge or stress reduction is observed.
/// Protection decays linearly to zero and is capped later when all active attempts are summed.
public func activeProtectionPoints(
    attempts: [ResponseAttempt],
    definitions: [ResponseDefinition],
    nowMS: Double
) -> Double {
    let byID = definitions.reduce(into: [String: ResponseDefinition]()) {
        $0[$1.id] = $1
    }
    return attempts.reduce(0.0) { total, attempt in
        guard let completed = attempt.completedTs,
              completed <= nowMS,
              let definition = byID[attempt.responseID],
              !definition.archived else { return total }
        let stressReduced: Bool
        if let before = attempt.stressBefore, let after = attempt.stressAfter {
            stressReduced = after < before
        } else {
            stressReduced = false
        }
        guard attempt.reducedUrge || stressReduced else { return total }
        let duration = Double(max(15, definition.protectionMinutes)) * 60 * 1000
        let elapsed = max(0, nowMS - completed)
        guard elapsed < duration else { return total }
        let remaining = 1 - elapsed / duration
        return total + Double(definition.protectionWeight.protectivePoints) * remaining
    }
}

// MARK: - Independent Bull / Vigour state

public struct VigourState: Equatable, Sendable {
    public var routineScore: Double
    public var erectionHealth: Double?
    public var libidoReadiness: Double?
    public var bullStrength: Double

    public init(
        routineScore: Double,
        erectionHealth: Double?,
        libidoReadiness: Double?,
        bullStrength: Double
    ) {
        self.routineScore = routineScore
        self.erectionHealth = erectionHealth
        self.libidoReadiness = libidoReadiness
        self.bullStrength = bullStrength
    }
}

/// Seven-day health-behaviour support plus the latest weekly self-reported outcomes.
/// This controls the motivational Bull visual only and never feeds Risk.
public func v27VigourState(
    recentDays: [DayRecord],
    latestCheckIn: SexualCheckIn?,
    nasalSupportDays: [Bool] = []
) -> VigourState {
    let days = Array(recentDays.suffix(7))
    let aerobic = days.compactMap(\.aerobicMinutes).reduce(0, +)
    let vigorous = days.compactMap(\.vigorousMinutes).reduce(0, +)
    let hasWorkoutData = days.contains {
        $0.aerobicMinutes != nil || $0.vigorousMinutes != nil || $0.strengthMinutes != nil
    }
    let aerobicEquivalent = aerobic + vigorous // vigorous minutes count twice in a 150-min target
    let aerobicScore = min(100, aerobicEquivalent / 150 * 100)

    let strengthDays = days.filter { ($0.strengthMinutes ?? 0) >= 15 }.count
    let strengthScore = min(100, Double(strengthDays) / 2 * 100)

    let dietValues = days.compactMap(\.heartHealthyEating)
    let dietScore = dietValues.isEmpty ? nil :
        Double(dietValues.filter { $0 }.count) / Double(dietValues.count) * 100

    let sleepValues = days.compactMap(\.sleep)
    let sleepScore = sleepValues.isEmpty ? nil : sleepValues.reduce(0, +) / Double(sleepValues.count)

    let nasalScore = nasalSupportDays.isEmpty ? nil :
        Double(nasalSupportDays.filter { $0 }.count) / Double(nasalSupportDays.count) * 100

    // Evidence-calibrated rolling weights: aerobic 4, sleep 3, dietary pattern 2,
    // strength 1. Nasal clearance is only a 0.5-weight indirect support. Missing
    // components are omitted rather than treated as failure.
    var weighted = 0.0
    var weight = 0.0
    if hasWorkoutData { weighted += aerobicScore * 4 + strengthScore; weight += 5 }
    if let dietScore { weighted += dietScore * 2; weight += 2 }
    if let sleepScore { weighted += sleepScore * 3; weight += 3 }
    if let nasalScore { weighted += nasalScore * 0.5; weight += 0.5 }
    let routine = weight > 0 ? max(0, min(100, weighted / weight)) : 50

    let erection = latestCheckIn?.erectionHealth
    let libido = latestCheckIn?.libidoReadiness
    let outcomes = [erection, libido].compactMap { $0 }
    let outcomeMean = outcomes.isEmpty ? nil : outcomes.reduce(0, +) / Double(outcomes.count)
    // When outcomes exist they guide the visual, while the routine still rewards consistent
    // action. This is a motivational composite, never a physiological measurement.
    let strength = outcomeMean.map { 0.60 * $0 + 0.40 * routine } ?? routine
    return VigourState(
        routineScore: routine,
        erectionHealth: erection,
        libidoReadiness: libido,
        bullStrength: max(0, min(100, strength))
    )
}
