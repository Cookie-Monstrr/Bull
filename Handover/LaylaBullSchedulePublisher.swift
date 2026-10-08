import Foundation

/// Copy this file into the Layla app target. Call `publish` whenever Layla changes the
/// current sleep plan or observes a sleep-state transition. Bull never receives raw sleep
/// samples, HealthKit identifiers, location, notes, or Risk Zone configuration.
public enum BullSharedSleepState: String, Codable, Sendable {
    case sleeping
    case plannedBriefWake
    case upForDay
    case unexpectedlyAwake
}

public enum BullSleepSchedulePublisherError: LocalizedError, Equatable {
    case appGroupUnavailable
    case invalidPlan
    case missingActualWake
    case missingReturnDeadline
    case missingBundleIdentifier
    case invalidConsistencyDeviation
    case sequenceExhausted
    case encodingFailed
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "Enable group.com.ahmed.Bull for the Layla target and its signing profile."
        case .invalidPlan:
            return "The final-wake, bedtime, state, or time-zone values are not a valid schedule."
        case .missingActualWake:
            return "A final or unexpected wake update must include the actual wake time."
        case .missingReturnDeadline:
            return "A planned brief wake must include its expected return-to-sleep deadline."
        case .missingBundleIdentifier:
            return "Layla has no bundle identifier, so the shared update cannot identify its source."
        case .invalidConsistencyDeviation:
            return "Sleep consistency deviation must be between 0 and 720 minutes."
        case .sequenceExhausted:
            return "The Layla-to-Bull update sequence is exhausted."
        case .encodingFailed:
            return "Layla could not encode the Bull schedule update."
        case .writeFailed(let message):
            return "Layla could not share the schedule with Bull: \(message)"
        }
    }
}

public enum BullSleepSchedulePublisher {
    public static let appGroupIdentifier = "group.com.ahmed.Bull"
    public static let payloadFilename = "layla-bull-sleep-schedule-v1.json"
    public static let schemaVersion = 1

    private static let sequenceDefaultsKey = "layla-bull-sleep-schedule-sequence-v1"
    private static let maximumPlanSpan: TimeInterval = 36 * 3_600

    /// Publishes the complete current truth in one atomic replacement. `plannedBedtime`
    /// means the next intended bedtime after `plannedFinalWake`, and all dates are encoded
    /// as milliseconds since Unix epoch. The day key is derived in `timeZone`.
    @discardableResult
    public static func publish(
        plannedFinalWake: Date,
        plannedBedtime: Date,
        actualFinalWake: Date? = nil,
        expectedReturnToSleepBy: Date? = nil,
        sleepConsistencyDeviationMinutes: Double? = nil,
        state: BullSharedSleepState,
        stateObservedAt: Date = Date(),
        timeZone: TimeZone = .autoupdatingCurrent,
        sourceVersion: Int = 1,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> Int64 {
        guard plannedBedtime > plannedFinalWake,
              plannedBedtime.timeIntervalSince(plannedFinalWake) <= maximumPlanSpan,
              sourceVersion >= 1 else {
            throw BullSleepSchedulePublisherError.invalidPlan
        }
        let earliestRelevantWake = plannedFinalWake.addingTimeInterval(-12 * 3_600)
        guard stateObservedAt >= earliestRelevantWake, stateObservedAt <= plannedBedtime,
              stateObservedAt <= now.addingTimeInterval(5 * 60),
              actualFinalWake.map({
                  $0 >= earliestRelevantWake && $0 <= plannedBedtime &&
                      $0 <= now.addingTimeInterval(5 * 60)
              }) ?? true else {
            throw BullSleepSchedulePublisherError.invalidPlan
        }
        if let deviation = sleepConsistencyDeviationMinutes,
           !(deviation.isFinite && deviation >= 0 && deviation <= 720) {
            throw BullSleepSchedulePublisherError.invalidConsistencyDeviation
        }
        switch state {
        case .sleeping:
            break
        case .plannedBriefWake:
            guard let deadline = expectedReturnToSleepBy else {
                throw BullSleepSchedulePublisherError.missingReturnDeadline
            }
            guard deadline >= stateObservedAt, deadline <= plannedFinalWake else {
                throw BullSleepSchedulePublisherError.invalidPlan
            }
        case .upForDay, .unexpectedlyAwake:
            guard actualFinalWake != nil else {
                throw BullSleepSchedulePublisherError.missingActualWake
            }
        }

        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ), let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            throw BullSleepSchedulePublisherError.appGroupUnavailable
        }
        let url = container.appendingPathComponent(payloadFilename, isDirectory: false)
        let sequence = try nextSequence(defaults: defaults, existingFileURL: url)
        let nowMS = now.timeIntervalSince1970 * 1_000
        guard let writerBundleIdentifier = Bundle.main.bundleIdentifier,
              !writerBundleIdentifier.isEmpty else {
            throw BullSleepSchedulePublisherError.missingBundleIdentifier
        }
        let payload = Snapshot(
            id: "\(dayKey(for: plannedFinalWake, timeZone: timeZone))-\(sequence)",
            dayKey: dayKey(for: plannedFinalWake, timeZone: timeZone),
            plannedFinalWakeTs: plannedFinalWake.timeIntervalSince1970 * 1_000,
            plannedBedtimeTs: plannedBedtime.timeIntervalSince1970 * 1_000,
            actualFinalWakeTs: actualFinalWake.map { $0.timeIntervalSince1970 * 1_000 },
            expectedReturnToSleepByTs: expectedReturnToSleepBy.map {
                $0.timeIntervalSince1970 * 1_000
            },
            sleepConsistencyDeviationMinutes: sleepConsistencyDeviationMinutes,
            state: state,
            stateObservedTs: stateObservedAt.timeIntervalSince1970 * 1_000,
            updatedTs: nowMS,
            timeZoneIdentifier: timeZone.identifier,
            sourceSequence: sequence,
            sourceBundleIdentifier: writerBundleIdentifier,
            sourceIdentifier: "layla",
            sourceVersion: sourceVersion
        )
        let envelope = Envelope(
            schemaVersion: schemaVersion,
            sequence: sequence,
            writtenTs: nowMS,
            writerBundleIdentifier: writerBundleIdentifier,
            snapshot: payload
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let raw = try? encoder.encode(envelope) else {
            throw BullSleepSchedulePublisherError.encodingFailed
        }
        do {
            try raw.write(to: url, options: [.atomic])
            #if os(iOS)
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            #endif
            defaults.set(NSNumber(value: sequence), forKey: sequenceDefaultsKey)
            return sequence
        } catch {
            throw BullSleepSchedulePublisherError.writeFailed(error.localizedDescription)
        }
    }

    private static func nextSequence(
        defaults: UserDefaults,
        existingFileURL: URL
    ) throws -> Int64 {
        var current = (defaults.object(forKey: sequenceDefaultsKey) as? NSNumber)?.int64Value ?? 0
        if let raw = try? Data(contentsOf: existingFileURL),
           let existing = try? JSONDecoder().decode(Envelope.self, from: raw) {
            current = max(current, existing.sequence)
        }
        guard current < Int64.max else {
            throw BullSleepSchedulePublisherError.sequenceExhausted
        }
        return current + 1
    }

    private static func dayKey(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }

    private struct Envelope: Codable {
        var schemaVersion: Int
        var sequence: Int64
        var writtenTs: Double
        var writerBundleIdentifier: String
        var snapshot: Snapshot
    }

    private struct Snapshot: Codable {
        var id: String
        var dayKey: String
        var plannedFinalWakeTs: Double
        var plannedBedtimeTs: Double
        var actualFinalWakeTs: Double?
        var expectedReturnToSleepByTs: Double?
        var sleepConsistencyDeviationMinutes: Double?
        var state: BullSharedSleepState
        var stateObservedTs: Double?
        var updatedTs: Double
        var timeZoneIdentifier: String?
        var sourceSequence: Int64?
        var sourceBundleIdentifier: String?
        var sourceIdentifier: String
        var sourceVersion: Int
    }
}
