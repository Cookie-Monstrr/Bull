import Foundation
import HealthKit
import Combine

struct HealthImportResult: Equatable {
    var sleepHours: Double?
    var estimatedSleepScore: Double?
    var preventionSleepScore: Double? = nil
    var vigourSleepScore: Double? = nil
    var sleepPurposeScoreSource: String? = nil
    var sleepPurposeScoreVersion: Int? = nil
    var sleepDurationPoints: Double?
    var sleepConsistencyPoints: Double?
    var sleepInterruptionsPoints: Double?
    var sleepBedtimeDeviationMinutes: Double?
    var sleepTotalAwakeMinutes: Double?
    var sleepFajrWakeMinutes: Double?
    var sleepAwakeMinutes: Double?
    var sleepInterruptionCount: Int?
    var sleepScoreSource: String?
    var sleepScoreVersion: Int?
    var hrvMilliseconds: Double?
    var restingHeartRate: Double? = nil
    var sleepWakeTimestampMS: Double?
    var aerobicMinutes: Double?
    var vigorousMinutes: Double?
    /// Active energy attributed by Apple Health to recognised cardio workouts only.
    /// This is an estimate, not the device's whole-day Move-ring total.
    var cardioActiveCalories: Double?
    var cardioIntensitySource: String?
    var strengthMinutes: Double?
}

struct DatedHealthImportResult: Equatable {
    var date: Date
    var result: HealthImportResult
}

private struct NightSleepMetrics {
    var sleepHours: Double
    var sleepStart: Date
    var sleepEnd: Date
    var totalAwakeMinutes: Double
    var fajrWakeMinutes: Double?
    var awakeMinutes: Double
    var interruptionCount: Int
}

@MainActor
final class HealthKitService: ObservableObject {
    /// HealthKit intentionally does not disclose whether read access was granted. This flag
    /// means only that Bull completed an authorization request without an API error.
    @Published var authorizationRequestCompleted = false
    @Published var lastError: String?

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard isAvailable else {
            lastError = "Health data is unavailable on this device."
            return false
        }
        guard let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            lastError = "Required HealthKit types are unavailable."
            return false
        }
        do {
            var read: Set<HKObjectType> = [sleep, hrv, HKObjectType.workoutType()]
            if let resting = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
                read.insert(resting)
            }
            if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                read.insert(activeEnergy)
            }
            if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
                read.insert(heartRate)
            }
            if let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
                read.insert(dateOfBirth)
            }
            try await store.requestAuthorization(toShare: [], read: read)
            authorizationRequestCompleted = true
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Imports the night that ends on `date`.
    ///
    /// watchOS/iOS 26 introduced Apple's first-party Sleep Score (duration 50 points,
    /// bedtime consistency 30, interruptions 20), but Apple currently exposes no public
    /// HealthKit API for reading that score. Bull therefore derives a transparent estimate
    /// from the same sleep-analysis samples. The estimate intentionally uses Apple's public
    /// component weights, not a claim that Bull reproduces Apple's private scoring curves.
    func importForNightEnding(on date: Date) async -> HealthImportResult {
        let metrics = await fetchNightSleepMetrics(endingOn: date)
        let hrvValue = await fetchNightlyHRV(endingOn: date)
        let dayStart = BullDates.startOfDay(date)
        let dayEnd = BullDates.addingDays(1, to: dayStart)
        let restingHeartRate = await fetchRestingHeartRate(start: dayStart, end: dayEnd)
        var priorBedtimes: [Double] = []
        for offset in 1...13 {
            let priorDate = BullDates.addingDays(-offset, to: date)
            if let prior = await fetchNightSleepMetrics(endingOn: priorDate) {
                priorBedtimes.append(Self.nightClockMinutes(prior.sleepStart))
            }
        }
        var result = Self.makeResult(metrics: metrics, hrvValue: hrvValue, priorBedtimes: priorBedtimes)
        result.restingHeartRate = restingHeartRate
        let workouts = await fetchWorkoutTotals(start: dayStart, end: dayEnd)
        result.aerobicMinutes = workouts.aerobic
        result.vigorousMinutes = workouts.vigorous
        result.cardioActiveCalories = workouts.cardioActiveCalories
        result.cardioIntensitySource = workouts.cardioIntensitySource
        result.strengthMinutes = workouts.strength
        return result
    }

    /// Backfills up to 90 recent nights without recomputing each night's 13-night
    /// consistency history from scratch. Existing Bull data decides whether to overwrite
    /// the returned values; this method only reads HealthKit.
    func importRecentNights(days: Int, endingOn endDate: Date = Date()) async -> [DatedHealthImportResult] {
        let count = min(90, max(1, days))
        let requestedDates = BullDates.dateRange(last: count, endingAt: endDate)
        guard let firstRequested = requestedDates.first else { return [] }
        let contextStart = BullDates.addingDays(-13, to: firstRequested)
        let contextDates = (0..<(count + 13)).map { BullDates.addingDays($0, to: contextStart) }

        let firstContext = contextDates.first ?? firstRequested
        let lastContext = contextDates.last ?? endDate
        let sleepStart = nightWindow(endingOn: firstContext).0
        let sleepEnd = nightWindow(endingOn: lastContext).1
        let firstHRVEnd = nightWindow(endingOn: firstRequested).1
        let hrvStart = BullDates.calendar.date(byAdding: .hour, value: -24, to: firstHRVEnd)
            ?? firstHRVEnd.addingTimeInterval(-24 * 3600)
        let hrvEnd = nightWindow(endingOn: endDate).1
        let workoutStart = BullDates.startOfDay(firstRequested)
        let workoutEnd = BullDates.addingDays(1, to: BullDates.startOfDay(endDate))

        // Three range queries replace the former per-day query loop. Keep them sequential
        // here because HealthKit sample types are not Sendable under strict concurrency.
        let sleepSamples = await fetchSleepSamples(start: sleepStart, end: sleepEnd)
        let hrvSamples = await fetchHRVSamples(start: hrvStart, end: hrvEnd)
        let restingHeartRateSamples = await fetchRestingHeartRateSamples(
            start: workoutStart,
            end: workoutEnd
        )
        let workoutByKey = await fetchWorkoutsByDay(start: workoutStart, end: workoutEnd)

        var sleepByKey: [String: NightSleepMetrics] = [:]
        for date in contextDates {
            let window = nightWindow(endingOn: date)
            if let metrics = Self.makeNightSleepMetrics(
                samples: sleepSamples,
                windowStart: window.0,
                windowEnd: window.1
            ) {
                sleepByKey[BullDates.key(for: date)] = metrics
            }
        }

        var output: [DatedHealthImportResult] = []
        output.reserveCapacity(requestedDates.count)
        for date in requestedDates {
            let key = BullDates.key(for: date)
            let metrics = sleepByKey[key]
            let priorBedtimes = (1...13).compactMap { offset -> Double? in
                let priorDate = BullDates.addingDays(-offset, to: date)
                guard let prior = sleepByKey[BullDates.key(for: priorDate)] else { return nil }
                return Self.nightClockMinutes(prior.sleepStart)
            }
            let window = nightWindow(endingOn: date)
            let hrv = Self.nightlyHRV(
                samples: hrvSamples,
                nightStart: window.0,
                nightEnd: window.1
            )
            var result = Self.makeResult(metrics: metrics, hrvValue: hrv, priorBedtimes: priorBedtimes)
            let dayStart = BullDates.startOfDay(date)
            let dayEnd = BullDates.addingDays(1, to: dayStart)
            result.restingHeartRate = Self.restingHeartRate(
                samples: restingHeartRateSamples,
                start: dayStart,
                end: dayEnd
            )
            if let workout = workoutByKey[key] {
                result.aerobicMinutes = workout.aerobic
                result.vigorousMinutes = workout.vigorous
                result.cardioActiveCalories = workout.cardioActiveCalories
                result.cardioIntensitySource = workout.cardioIntensitySource
                result.strengthMinutes = workout.strength
            }
            if result.sleepHours != nil || result.hrvMilliseconds != nil || result.restingHeartRate != nil ||
                result.aerobicMinutes != nil || result.cardioActiveCalories != nil ||
                result.strengthMinutes != nil {
                output.append(DatedHealthImportResult(date: date, result: result))
            }
        }
        return output
    }

    private static func makeResult(
        metrics: NightSleepMetrics?,
        hrvValue: Double?,
        priorBedtimes: [Double]
    ) -> HealthImportResult {
        guard let metrics else {
            return HealthImportResult(
                sleepHours: nil,
                estimatedSleepScore: nil,
                sleepDurationPoints: nil,
                sleepConsistencyPoints: nil,
                sleepInterruptionsPoints: nil,
                sleepBedtimeDeviationMinutes: nil,
                sleepTotalAwakeMinutes: nil,
                sleepFajrWakeMinutes: nil,
                sleepAwakeMinutes: nil,
                sleepInterruptionCount: nil,
                sleepScoreSource: nil,
                sleepScoreVersion: nil,
                hrvMilliseconds: hrvValue,
                sleepWakeTimestampMS: nil,
                aerobicMinutes: nil,
                vigorousMinutes: nil,
                cardioActiveCalories: nil,
                cardioIntensitySource: nil,
                strengthMinutes: nil
            )
        }

        let currentBedtime = nightClockMinutes(metrics.sleepStart)
        let bedtimeDeviation: Double?
        if priorBedtimes.count >= 4, let typical = BullSleepScore.median(priorBedtimes) {
            let raw = abs(currentBedtime - typical)
            bedtimeDeviation = min(raw, 1440 - min(raw, 1440))
        } else {
            bedtimeDeviation = nil
        }

        let breakdown = BullSleepScore.total(
            hours: metrics.sleepHours,
            bedtimeDeviationMinutes: bedtimeDeviation,
            awakeMinutes: metrics.awakeMinutes,
            interruptionCount: metrics.interruptionCount,
            hasEnoughBedtimeHistory: priorBedtimes.count >= 4
        )
        let purposeScores = BullSleepScore.purposeScores(
            durationPoints: breakdown.duration,
            consistencyPoints: breakdown.consistency,
            interruptionPoints: breakdown.interruptions
        )

        return HealthImportResult(
            sleepHours: metrics.sleepHours,
            estimatedSleepScore: breakdown.score,
            preventionSleepScore: purposeScores.prevention,
            vigourSleepScore: purposeScores.vigour,
            sleepPurposeScoreSource: BullSleepScore.purposeSourceIdentifier,
            sleepPurposeScoreVersion: BullSleepScore.purposeSourceVersion,
            sleepDurationPoints: breakdown.duration,
            sleepConsistencyPoints: breakdown.consistency,
            sleepInterruptionsPoints: breakdown.interruptions,
            sleepBedtimeDeviationMinutes: bedtimeDeviation,
            sleepTotalAwakeMinutes: metrics.totalAwakeMinutes,
            sleepFajrWakeMinutes: metrics.fajrWakeMinutes,
            sleepAwakeMinutes: metrics.awakeMinutes,
            sleepInterruptionCount: metrics.interruptionCount,
            sleepScoreSource: BullSleepScore.sourceIdentifier,
            sleepScoreVersion: BullSleepScore.sourceVersion,
            hrvMilliseconds: hrvValue,
            sleepWakeTimestampMS: metrics.sleepEnd.timeIntervalSince1970 * 1000,
            aerobicMinutes: nil,
            vigorousMinutes: nil,
            cardioActiveCalories: nil,
            cardioIntensitySource: nil,
            strengthMinutes: nil
        )
    }

    static func sleepClassification(_ score: Double) -> String {
        BullSleepScore.classification(score)
    }

    private static func nightClockMinutes(_ date: Date) -> Double {
        let c = BullDates.calendar.dateComponents([.hour, .minute, .second], from: date)
        var minutes = Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) + Double(c.second ?? 0) / 60
        // Anchor the "night clock" at noon so 23:30 and 00:30 are one hour apart.
        if minutes < 12 * 60 { minutes += 1440 }
        return minutes
    }

    // MARK: - HealthKit queries

    private func nightWindow(endingOn date: Date) -> (Date, Date) {
        let end = BullDates.calendar.date(bySettingHour: 15, minute: 0, second: 0, of: date) ?? date
        // 7pm previous evening → 3pm ending day. Wide enough for early bedtimes without
        // routinely pulling the prior afternoon's nap into the night.
        let start = BullDates.calendar.date(byAdding: .hour, value: -20, to: end) ?? end.addingTimeInterval(-20 * 3600)
        return (start, end)
    }

    private func fetchNightSleepMetrics(endingOn date: Date) async -> NightSleepMetrics? {
        let (start, end) = nightWindow(endingOn: date)
        let samples = await fetchSleepSamples(start: start, end: end)
        return Self.makeNightSleepMetrics(samples: samples, windowStart: start, windowEnd: end)
    }

    private func fetchSleepSamples(start: Date, end: Date) async -> [HKCategorySample] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        do {
            return try await withCheckedThrowingContinuation { continuation in
                let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error { continuation.resume(throwing: error); return }
                    continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
                store.execute(q)
            }
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    private static func makeNightSleepMetrics(
        samples allSamples: [HKCategorySample],
        windowStart: Date,
        windowEnd: Date
    ) -> NightSleepMetrics? {
        let samples = allSamples.filter { $0.endDate > windowStart && $0.startDate < windowEnd }
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]

        let asleep = Self.mergeIntervals(samples
            .filter { asleepValues.contains($0.value) && $0.endDate > $0.startDate }
            .map { (max($0.startDate, windowStart), min($0.endDate, windowEnd)) }
            .filter { $0.1 > $0.0 })
        guard let first = asleep.first, let last = asleep.last else { return nil }

        let sleepStart = first.0
        let sleepEnd = last.1
        let sleepSeconds = asleep.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
        guard sleepSeconds > 0 else { return nil }

        // HealthKit's explicit awake samples are useful but a deliberate Fajr wake can
        // also appear as a gap between two sleep blocks. Build a conservative set of
        // overnight wake intervals from both sources, then remove one likely Fajr gap.
        let explicitAwake = samples
            .filter {
                $0.value == HKCategoryValueSleepAnalysis.awake.rawValue &&
                $0.endDate > sleepStart && $0.startDate < sleepEnd
            }
            .map { (max($0.startDate, sleepStart), min($0.endDate, sleepEnd)) }
            .filter { $0.1.timeIntervalSince($0.0) >= 60 }

        // Ignore tiny staging/data gaps. Ten minutes is long enough to represent a real
        // interruption without treating ordinary stage transitions as awake time.
        let meaningfulGaps = zip(asleep, asleep.dropFirst()).compactMap { pair -> (Date, Date)? in
            let previous = pair.0
            let next = pair.1
            let gap = next.0.timeIntervalSince(previous.1)
            guard gap >= 10 * 60 else { return nil }
            return (previous.1, next.0)
        }

        let allWake = Self.mergeIntervals(explicitAwake + meaningfulGaps)
        let totalAwakeSeconds = allWake.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }

        let fajrGap = BullSleepScore.likelyFajrGap(
            asleepIntervals: asleep.map { BullSleepInterval(start: $0.0, end: $0.1) },
            calendar: BullDates.calendar
        )
        let adjustedWake = BullSleepScore.removingPlannedFajrAllowance(
            from: allWake.map { BullSleepInterval(start: $0.0, end: $0.1) },
            fajrGap: fajrGap
        )
        let unplannedWake = Self.mergeIntervals(adjustedWake.map { ($0.start, $0.end) })
            .filter { $0.1.timeIntervalSince($0.0) >= 60 }

        let awakeSeconds = unplannedWake.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
        return NightSleepMetrics(
            sleepHours: sleepSeconds / 3600,
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            totalAwakeMinutes: totalAwakeSeconds / 60,
            fajrWakeMinutes: fajrGap?.minutes,
            awakeMinutes: awakeSeconds / 60,
            interruptionCount: unplannedWake.count
        )
    }

    private func fetchNightlyHRV(endingOn date: Date) async -> Double? {
        let (nightStart, nightEnd) = nightWindow(endingOn: date)
        let dayStart = BullDates.calendar.date(byAdding: .hour, value: -24, to: nightEnd)
            ?? nightEnd.addingTimeInterval(-24 * 3600)
        let samples = await fetchHRVSamples(start: dayStart, end: nightEnd)
        return Self.nightlyHRV(samples: samples, nightStart: nightStart, nightEnd: nightEnd)
    }

    private func fetchHRVSamples(start: Date, end: Date) async -> [HKQuantitySample] {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        do {
            return try await withCheckedThrowingContinuation { continuation in
                let q = HKSampleQuery(
                    sampleType: type,
                    predicate: pred,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error { continuation.resume(throwing: error); return }
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
                store.execute(q)
            }
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    private func fetchRestingHeartRate(start: Date, end: Date) async -> Double? {
        Self.restingHeartRate(
            samples: await fetchRestingHeartRateSamples(start: start, end: end),
            start: start,
            end: end
        )
    }

    private func fetchRestingHeartRateSamples(start: Date, end: Date) async -> [HKQuantitySample] {
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        do {
            return try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error { continuation.resume(throwing: error); return }
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
                store.execute(query)
            }
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    private static func restingHeartRate(
        samples: [HKQuantitySample],
        start: Date,
        end: Date
    ) -> Double? {
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let values = samples
            .filter { $0.startDate >= start && $0.endDate <= end }
            .map { $0.quantity.doubleValue(for: unit) }
            .filter { $0 > 0 && $0.isFinite }
        return BullSleepScore.median(values)
    }

    private static func nightlyHRV(
        samples: [HKQuantitySample],
        nightStart: Date,
        nightEnd: Date
    ) -> Double? {
        func values(start: Date, end: Date) -> [Double] {
            samples
                .filter { $0.startDate >= start && $0.endDate <= end }
                .map { $0.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)) }
                .filter { $0 > 0 && $0.isFinite }
                .sorted()
        }
        // Prefer sleep-window HRV. If absent, use the full 24 hours ending at 15:00.
        if let median = BullSleepScore.median(values(start: nightStart, end: nightEnd)) {
            return median
        }
        let dayStart = BullDates.calendar.date(byAdding: .hour, value: -24, to: nightEnd)
            ?? nightEnd.addingTimeInterval(-24 * 3600)
        return BullSleepScore.median(values(start: dayStart, end: nightEnd))
    }

    private typealias WorkoutTotals = (
        aerobic: Double?,
        vigorous: Double?,
        cardioActiveCalories: Double?,
        cardioIntensitySource: String?,
        strength: Double?
    )

    private func fetchWorkoutTotals(start: Date, end: Date) async -> WorkoutTotals {
        let byDay = await fetchWorkoutsByDay(start: start, end: end)
        return byDay[BullDates.key(for: start)] ?? (nil, nil, nil, nil, nil)
    }

    /// One range query replaces separate workout queries per day. Values are partitioned
    /// locally into the same civil-day keys used by Bull history.
    private func fetchWorkoutsByDay(start: Date, end: Date) async -> [String: WorkoutTotals] {
        let type = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        do {
            let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error { continuation.resume(throwing: error); return }
                    continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
                }
                store.execute(query)
            }
            let heartRateSamples = await fetchHeartRateSamples(start: start, end: end)
            let estimatedMaximumHeartRate = healthProfileMaximumHeartRate()

            var raw: [String: (
                aerobic: Double,
                vigorous: Double,
                cardioActiveCalories: Double,
                cardioEnergyObserved: Bool,
                usedHeartRateZones: Bool,
                usedWorkoutTypeEstimate: Bool,
                strength: Double
            )] = [:]
            for workout in workouts {
                let key = BullDates.key(for: workout.startDate)
                var totals = raw[key] ?? (0, 0, 0, false, false, false, 0)
                let minutes = max(0, workout.duration / 60)
                if Self.isStrength(workout.workoutActivityType) {
                    totals.strength += minutes
                } else if Self.isAerobic(workout.workoutActivityType) {
                    let workoutHeartRate = heartRateSamples
                        .filter { $0.startDate >= workout.startDate && $0.startDate < workout.endDate }
                        .map {
                            CardioHeartRatePoint(
                                secondsFromWorkoutStart: $0.startDate.timeIntervalSince(workout.startDate),
                                beatsPerMinute: $0.quantity.doubleValue(
                                    for: HKUnit.count().unitDivided(by: HKUnit.minute())
                                )
                            )
                        }
                    let zoneSummary = estimatedMaximumHeartRate.flatMap {
                        cardioHeartRateZoneSummary(
                            points: workoutHeartRate,
                            workoutDurationSeconds: workout.duration,
                            estimatedMaximumHeartRate: $0
                        )
                    }
                    if let zoneSummary,
                       zoneSummary.observedMinutes >= max(5, minutes * 0.50) {
                        totals.aerobic += zoneSummary.moderateMinutes + zoneSummary.vigorousMinutes
                        totals.vigorous += zoneSummary.vigorousMinutes
                        totals.usedHeartRateZones = true
                    } else {
                        // Honest compatibility fallback when Watch HR coverage or DOB is absent.
                        totals.aerobic += minutes
                        if Self.isVigorous(workout.workoutActivityType) {
                            totals.vigorous += minutes
                        }
                        totals.usedWorkoutTypeEstimate = true
                    }
                    if let kilocalories = Self.activeEnergyKilocalories(for: workout) {
                        totals.cardioActiveCalories += max(0, kilocalories)
                        totals.cardioEnergyObserved = true
                    }
                }
                raw[key] = totals
            }
            return raw.mapValues { value in
                (
                    value.aerobic > 0 ? value.aerobic : nil,
                    value.vigorous > 0 ? value.vigorous : nil,
                    value.cardioEnergyObserved ? value.cardioActiveCalories : nil,
                    Self.intensitySource(
                        usedHeartRateZones: value.usedHeartRateZones,
                        usedWorkoutTypeEstimate: value.usedWorkoutTypeEstimate
                    ),
                    value.strength > 0 ? value.strength : nil
                )
            }
        } catch {
            lastError = error.localizedDescription
            return [:]
        }
    }

    private func fetchHeartRateSamples(start: Date, end: Date) async -> [HKQuantitySample] {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }

    private func healthProfileMaximumHeartRate(at date: Date = Date()) -> Double? {
        guard let components = try? store.dateOfBirthComponents(),
              let birthDate = BullDates.calendar.date(from: components) else { return nil }
        let age = BullDates.calendar.dateComponents([.year], from: birthDate, to: date).year ?? 0
        guard (14...100).contains(age) else { return nil }
        return 208 - 0.7 * Double(age)
    }

    private static func intensitySource(
        usedHeartRateZones: Bool,
        usedWorkoutTypeEstimate: Bool
    ) -> String? {
        switch (usedHeartRateZones, usedWorkoutTypeEstimate) {
        case (true, true): return "heart-rate-zones-and-workout-estimate"
        case (true, false): return "heart-rate-zones"
        case (false, true): return "workout-type-estimate"
        case (false, false): return nil
        }
    }

    private static func activeEnergyKilocalories(for workout: HKWorkout) -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let quantity = workout.statistics(for: type)?.sumQuantity() else { return nil }
        let value = quantity.doubleValue(for: .kilocalorie())
        return value.isFinite ? value : nil
    }

    private static func isStrength(_ type: HKWorkoutActivityType) -> Bool {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return true
        default:
            return false
        }
    }

    private static func isAerobic(_ type: HKWorkoutActivityType) -> Bool {
        switch type {
        case .running, .walking, .cycling, .swimming, .rowing, .elliptical,
             .stairClimbing, .highIntensityIntervalTraining, .boxing, .kickboxing,
             .soccer, .basketball, .tennis, .jumpRope, .crossTraining:
            return true
        default:
            return false
        }
    }

    private static func isVigorous(_ type: HKWorkoutActivityType) -> Bool {
        switch type {
        case .running, .rowing, .stairClimbing, .highIntensityIntervalTraining,
             .boxing, .kickboxing, .soccer, .basketball, .jumpRope:
            return true
        default:
            return false
        }
    }

    private static func mergeIntervals(_ intervals: [(Date, Date)]) -> [(Date, Date)] {
        let sorted = intervals
            .filter { $0.1 > $0.0 }
            .sorted { $0.0 < $1.0 }
        guard let first = sorted.first else { return [] }

        var result: [(Date, Date)] = []
        var currentStart = first.0
        var currentEnd = first.1
        for interval in sorted.dropFirst() {
            if interval.0 <= currentEnd {
                if interval.1 > currentEnd { currentEnd = interval.1 }
            } else {
                result.append((currentStart, currentEnd))
                currentStart = interval.0
                currentEnd = interval.1
            }
        }
        result.append((currentStart, currentEnd))
        return result
    }
}
