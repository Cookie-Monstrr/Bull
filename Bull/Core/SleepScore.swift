import Foundation

/// Transparent approximation of Apple's public Sleep Score component structure.
///
/// Apple documents a 100-point score made from sleep duration (50 points), bedtime
/// consistency (30) and interruptions (20), but does not expose the first-party score
/// through HealthKit or publish the private scoring curves. Bull therefore uses the same
/// component weights with explicit, testable curves of its own.

public struct BullSleepInterval: Equatable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public var minutes: Double { max(0, end.timeIntervalSince(start) / 60) }
}

/// Purpose-specific views of one underlying night. Prevention gives more weight to
/// regularity because disrupted timing is an acute vulnerability signal; Vigour gives
/// more weight to duration because Bull Routine already evaluates it across seven nights.
public struct BullPurposeSleepScores: Equatable, Sendable {
    public var prevention: Double
    public var vigour: Double

    public init(prevention: Double, vigour: Double) {
        self.prevention = prevention
        self.vigour = vigour
    }
}

public enum BullSleepScore {
    /// Bull v2 sleep scoring deliberately treats one planned Fajr split as part of the
    /// intended night rather than ordinary fragmentation. Until Layla can provide exact
    /// prayer-plan metadata, Bull uses a simple 90-minute allowance (roughly Fajr→Shorouk).
    public static let plannedFajrWakeAllowanceMinutes: Double = 90
    public static let sourceIdentifier = "bull-fajr-aware"
    public static let sourceVersion = 2
    public static let purposeSourceIdentifier = "bull-purpose-sleep"
    public static let purposeSourceVersion = 1
    public static let laylaPurposeSourceIdentifier = "layla-consistency+bull-purpose-sleep"

    /// Finds one early-morning split-sleep gap that is plausibly an intentional Fajr wake.
    /// The heuristic is deliberately conservative: at least 60 minutes of sleep before the
    /// gap, at least 20 minutes after it, a 10–180 minute gap, and a midpoint between 02:00
    /// and 09:00 in the supplied calendar. Layla can replace this heuristic later with exact
    /// prayer-plan metadata while historical Bull scores retain their source/version.
    public static func likelyFajrGap(
        asleepIntervals: [BullSleepInterval],
        calendar: Calendar
    ) -> BullSleepInterval? {
        let asleep = asleepIntervals
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }
        guard asleep.count >= 2 else { return nil }

        var candidates: [BullSleepInterval] = []
        for index in 0..<(asleep.count - 1) {
            let gap = BullSleepInterval(start: asleep[index].end, end: asleep[index + 1].start)
            guard gap.minutes >= 10, gap.minutes <= 180 else { continue }

            let sleepBefore = asleep[0...index].reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
            let sleepAfter = asleep[(index + 1)...].reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
            guard sleepBefore >= 60 * 60, sleepAfter >= 20 * 60 else { continue }

            let midpoint = gap.start.addingTimeInterval(gap.end.timeIntervalSince(gap.start) / 2)
            let hour = calendar.component(.hour, from: midpoint)
            guard hour >= 2 && hour < 9 else { continue }
            candidates.append(gap)
        }

        return candidates.max { $0.minutes < $1.minutes }
    }

    /// Removes only the allowed portion of a detected Fajr wake from merged wake
    /// intervals. If the Fajr gap is longer than the allowance, the excess is retained and
    /// therefore still penalized by the interruption component.
    public static func removingPlannedFajrAllowance(
        from wakeIntervals: [BullSleepInterval],
        fajrGap: BullSleepInterval?,
        allowanceMinutes: Double = plannedFajrWakeAllowanceMinutes
    ) -> [BullSleepInterval] {
        guard let fajrGap, allowanceMinutes > 0 else {
            return wakeIntervals.filter { $0.end > $0.start }
        }

        let cutStart = fajrGap.start
        let cutEnd = min(fajrGap.end, fajrGap.start.addingTimeInterval(allowanceMinutes * 60))
        return wakeIntervals.flatMap { interval -> [BullSleepInterval] in
            guard interval.end > cutStart && interval.start < cutEnd else { return [interval] }
            var pieces: [BullSleepInterval] = []
            if interval.start < cutStart {
                pieces.append(BullSleepInterval(start: interval.start, end: min(interval.end, cutStart)))
            }
            if interval.end > cutEnd {
                pieces.append(BullSleepInterval(start: max(interval.start, cutEnd), end: interval.end))
            }
            return pieces.filter { $0.end > $0.start }
        }
    }

    public static func classification(_ score: Double) -> String {
        switch score {
        case ..<41: return "Very Low"
        case 41..<61: return "Low"
        case 61..<81: return "OK"
        case 81..<96: return "High"
        default: return "Very High"
        }
    }

    public static func durationPoints(hours: Double) -> Double {
        interpolate(hours, anchors: [
            (0, 0), (4, 5), (5, 18), (6, 32), (7, 44),
            (7.5, 50), (9, 50), (10, 44), (11, 34), (12, 20), (14, 0)
        ])
    }

    public static func consistencyPoints(deviationMinutes: Double) -> Double {
        interpolate(max(0, deviationMinutes), anchors: [
            (0, 30), (15, 30), (30, 28), (60, 23),
            (90, 16), (120, 9), (180, 0)
        ])
    }

    public static func interruptionPoints(awakeMinutes: Double, interruptionCount: Int) -> Double {
        let durationComponent = interpolate(max(0, awakeMinutes), anchors: [
            (0, 20), (10, 19), (20, 17), (30, 14),
            (45, 10), (60, 6), (90, 0)
        ])
        let countPenalty = min(5.0, Double(max(0, interruptionCount - 1)) * 0.8)
        return max(0, durationComponent - countPenalty)
    }

    public static func total(
        hours: Double,
        bedtimeDeviationMinutes: Double?,
        awakeMinutes: Double,
        interruptionCount: Int,
        hasEnoughBedtimeHistory: Bool
    ) -> (score: Double, duration: Double, consistency: Double, interruptions: Double) {
        let duration = durationPoints(hours: hours)
        let consistency = hasEnoughBedtimeHistory
            ? consistencyPoints(deviationMinutes: bedtimeDeviationMinutes ?? 0)
            : 24 // provisional 80% of the 30-point component
        let interruptions = interruptionPoints(awakeMinutes: awakeMinutes, interruptionCount: interruptionCount)
        let score = min(100, max(0, duration + consistency + interruptions)).rounded()
        return (score, duration, consistency, interruptions)
    }

    /// Produces two scores from the already-captured components without inventing new
    /// HealthKit measurements. The public component maxima are normalised before applying
    /// Bull's explicit purpose weights:
    /// - Prevention: duration 45%, timing consistency 30%, continuity 25%.
    /// - Vigour: duration 60%, timing consistency 10%, continuity 30%.
    ///
    /// Sleep-stage data is intentionally not included yet: HealthKit sources vary widely
    /// in whether stage coverage is complete, and a missing REM estimate must not silently
    /// become poor sleep. Layla can later replace the timing component with the user's
    /// planned bed/wake schedule while preserving this versioned history.
    public static func purposeScores(
        durationPoints: Double,
        consistencyPoints: Double,
        interruptionPoints: Double
    ) -> BullPurposeSleepScores {
        let duration = min(100, max(0, durationPoints / 50 * 100))
        let consistency = min(100, max(0, consistencyPoints / 30 * 100))
        let continuity = min(100, max(0, interruptionPoints / 20 * 100))
        let prevention = 0.45 * duration + 0.30 * consistency + 0.25 * continuity
        let vigour = 0.60 * duration + 0.10 * consistency + 0.30 * continuity
        return BullPurposeSleepScores(
            prevention: min(100, max(0, prevention)).rounded(),
            vigour: min(100, max(0, vigour)).rounded()
        )
    }

    public static func median(_ values: [Double]) -> Double? {
        let sorted = values.filter(\.isFinite).sorted()
        guard !sorted.isEmpty else { return nil }
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) { return (sorted[mid - 1] + sorted[mid]) / 2 }
        return sorted[mid]
    }

    private static func interpolate(_ value: Double, anchors: [(Double, Double)]) -> Double {
        guard let first = anchors.first, let last = anchors.last else { return 0 }
        if value <= first.0 { return first.1 }
        if value >= last.0 { return last.1 }
        for pair in zip(anchors, anchors.dropFirst()) {
            let a = pair.0, b = pair.1
            guard value >= a.0 && value <= b.0 else { continue }
            let span = b.0 - a.0
            guard span > 0 else { return b.1 }
            let t = (value - a.0) / span
            return a.1 + (b.1 - a.1) * t
        }
        return last.1
    }
}
