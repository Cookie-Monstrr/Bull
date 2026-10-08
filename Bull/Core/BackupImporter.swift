import Foundation

/// What the import actually did, surfaced to the user rather than staying
/// silent. A script (or an importer) reporting bare "success" is not evidence
/// it did what was asked — this exists specifically so partial data loss is
/// visible instead of quietly happening.
public struct ImportReport: Equatable, Sendable {
    public var daysImported: Int
    public var itemsImported: Int
    public var urgesImported: Int
    public var relapsesImported: Int
    public var wetDreamsImported: Int
    public var rulesImported: Int
    public var plansImported: Int
    public var scoreSnapshotsImported: Int
    public var sexualCheckInsImported: Int
    public var dailySexualObservationsImported: Int
    public var libidoSpotsImported: Int
    public var highRiskZonesImported: Int
    public var laylaSleepSchedulesImported: Int
    public var zoneEventsImported: Int
    public var safeguardEventsImported: Int
    public var riskAlertEventsImported: Int
    public var privateContextSessionsImported: Int
    public var weeklyGoalsImported: Int
    public var weeklyGoalReviewsImported: Int
    public var personalFactorsImported: Int
    public var exercisePlansImported: Int
    public var exerciseWeekReviewsImported: Int
    public var manualExerciseLogsImported: Int
    public var damageControlLogsImported: Int
    public var ejaculatoryControlObservationsImported: Int
    public var stressReadingsImported: Int
    public var stressActivitiesImported: Int
    public var stressReliefLogsImported: Int
    public var pornUrgeObservationsImported: Int
    public var wakeErectionObservationsImported: Int
    public var bullStateObservationsImported: Int
    public var strengthWorkoutLogsImported: Int
    public var fourScoreSnapshotsImported: Int
    public var riskControlChangeRequestsImported: Int
    public var therapistOutboxEventsImported: Int
    public var therapistInboxEventsImported: Int
    public var therapistAccessAuditImported: Int
    /// Count of elements that existed in the source file but failed to decode
    /// and were skipped, keyed by collection name. Empty means nothing was
    /// lost. Non-empty is surfaced to the user, never swallowed.
    public var skipped: [String: Int]
    public var dateRange: ClosedRange<Date>?

    public var hadSkips: Bool { skipped.values.contains { $0 > 0 } }
}

public enum BackupImportError: LocalizedError, Equatable, Sendable {
    /// The file wasn't valid JSON at all.
    case notJSON
    /// Valid JSON, but not shaped like a Bull backup — e.g. an array, or an
    /// object missing the fields that make it recognisable as one.
    case notABullBackup
    /// Prevent an unbounded document from being decoded on the main actor.
    case tooLarge(maximumBytes: Int)

    public var errorDescription: String? {
        switch self {
        case .notJSON: return "The selected file is not valid JSON."
        case .notABullBackup: return "The selected JSON is not a recognised Bull backup."
        case .tooLarge(let maximumBytes):
            return "The selected backup is larger than Bull's \(maximumBytes / 1_048_576) MB safety limit."
        }
    }
}

/// Deliberately contains trends only: no notes, exact locations, zone history, raw sexual
/// observations, triggers, safeguards or Layla timestamps. It is a safer review foundation,
/// not a recovery backup and not yet a remote therapist-access system.
public struct RedactedTrendExport: Codable, Equatable, Sendable {
    public var format: String
    public var generatedTs: Double
    public var finalFourScoreSnapshots: [String: FourScoreSnapshot]

    public init(
        format: String = "bull-redacted-trends-v1",
        generatedTs: Double = Date().timeIntervalSince1970 * 1_000,
        finalFourScoreSnapshots: [String: FourScoreSnapshot]
    ) {
        self.format = format
        self.generatedTs = generatedTs
        self.finalFourScoreSnapshots = finalFourScoreSnapshots
    }
}

public enum BackupImporter {

    public static let maximumBackupBytes = 25 * 1_048_576

    /// Decodes a `bull-backup-*.json` export and reports exactly what was
    /// imported, including anything that had to be skipped. Never silently
    /// discards a whole collection for one bad element (see
    /// `decodeLeniently`) and never claims success without having actually
    /// counted what landed.
    public static func importBackup(from data: Data) -> Result<(BullData, ImportReport), BackupImportError> {
        guard data.count <= maximumBackupBytes else {
            return .failure(.tooLarge(maximumBytes: maximumBackupBytes))
        }
        // Raw counts, read independently of BullData's own (safe-by-default)
        // decode, purely so a mismatch between "how many were in the file"
        // and "how many made it into BullData" can be reported truthfully.
        guard let raw = try? JSONSerialization.jsonObject(with: data) else {
            return .failure(.notJSON)
        }
        guard let obj = raw as? [String: Any] else {
            return .failure(.notABullBackup)
        }
        // A Bull backup is recognisable by having at least `days` and
        // `settings` — anything claiming to be one without those is more
        // likely an unrelated JSON file than a genuinely corrupt export.
        guard obj["days"] is [String: Any], obj["settings"] is [String: Any] else {
            return .failure(.notABullBackup)
        }

        func rawCount(_ key: String) -> Int? { (obj[key] as? [Any])?.count }
        func rawDictCount(_ key: String) -> Int? { (obj[key] as? [String: Any])?.count }

        let bull: BullData
        do {
            bull = try JSONDecoder().decode(BullData.self, from: data)
        } catch {
            // BullData's own decoder already falls back field-by-field, so
            // reaching here means the top-level structure itself couldn't be
            // read as an object at all despite passing the JSON/shape checks
            // above — vanishingly unlikely, but never silently swallowed.
            return .failure(.notABullBackup)
        }

        var skipped: [String: Int] = [:]
        func recordSkip(_ key: String, decodedCount: Int) {
            if let raw = rawCount(key) {
                let diff = max(0, raw - decodedCount)
                if diff > 0 { skipped[key] = diff }
            } else if obj[key] != nil {
                // The section exists but is not an array. Report it rather than allowing
                // BullData's safe default to make a malformed section look successful.
                skipped[key] = 1
            }
        }
        recordSkip("items", decodedCount: bull.items.count)
        recordSkip("urges", decodedCount: bull.urges.count)
        recordSkip("relapses", decodedCount: bull.relapses.count)
        recordSkip("wetDreams", decodedCount: bull.wetDreams.count)
        recordSkip("rules", decodedCount: bull.rules.count)
        recordSkip("plans", decodedCount: bull.plans.count)
        recordSkip("triggerLibrary", decodedCount: bull.triggerLibrary.count)
        recordSkip("responseLibrary", decodedCount: bull.responseLibrary.count)
        recordSkip("responseAttempts", decodedCount: bull.responseAttempts.count)
        recordSkip("accountabilityCheckIns", decodedCount: bull.accountabilityCheckIns.count)
        recordSkip("sexualCheckIns", decodedCount: bull.sexualCheckIns.count)
        recordSkip("dailySexualObservations", decodedCount: bull.dailySexualObservations.count)
        recordSkip("libidoSpots", decodedCount: bull.libidoSpots.count)
        recordSkip("highRiskZones", decodedCount: bull.highRiskZones.count)
        recordSkip("laylaSleepSchedules", decodedCount: bull.laylaSleepSchedules.count)
        recordSkip("zoneEvents", decodedCount: bull.zoneEvents.count)
        recordSkip("safeguardEvents", decodedCount: bull.safeguardEvents.count)
        recordSkip("riskAlertEvents", decodedCount: bull.riskAlertEvents.count)
        recordSkip("privateContextSessions", decodedCount: bull.privateContextSessions.count)
        recordSkip("weeklyGoals", decodedCount: bull.weeklyGoals.count)
        recordSkip("weeklyGoalReviews", decodedCount: bull.weeklyGoalReviews.count)
        recordSkip("personalFactors", decodedCount: bull.personalFactors.count)
        recordSkip("exercisePlans", decodedCount: bull.exercisePlans.count)
        recordSkip("exerciseWeekReviews", decodedCount: bull.exerciseWeekReviews.count)
        recordSkip("manualExerciseLogs", decodedCount: bull.manualExerciseLogs.count)
        recordSkip("damageControlLogs", decodedCount: bull.damageControlLogs.count)
        recordSkip("ejaculatoryControlObservations", decodedCount: bull.ejaculatoryControlObservations.count)
        recordSkip("stressReadings", decodedCount: bull.stressReadings.count)
        recordSkip("stressActivities", decodedCount: bull.stressActivities.count)
        recordSkip("stressReliefLogs", decodedCount: bull.stressReliefLogs.count)
        recordSkip("pornUrgeObservations", decodedCount: bull.pornUrgeObservations.count)
        recordSkip("wakeErectionObservations", decodedCount: bull.wakeErectionObservations.count)
        recordSkip("bullStateObservations", decodedCount: bull.bullStateObservations.count)
        recordSkip("strengthWorkoutLogs", decodedCount: bull.strengthWorkoutLogs.count)
        recordSkip("riskControlChangeRequests", decodedCount: bull.riskControlChangeRequests.count)
        recordSkip("therapistOutboxEvents", decodedCount: bull.therapistOutboxEvents.count)
        recordSkip("therapistInboxEvents", decodedCount: bull.therapistInboxEvents.count)
        recordSkip("therapistAccessAudit", decodedCount: bull.therapistAccessAudit.count)
        if let rawSnapshots = rawDictCount("scoreSnapshots") {
            let diff = max(0, rawSnapshots - bull.scoreSnapshots.count)
            if diff > 0 { skipped["scoreSnapshots"] = diff }
        } else if obj["scoreSnapshots"] != nil {
            skipped["scoreSnapshots"] = 1
        }
        if let rawDays = rawDictCount("days") {
            let diff = max(0, rawDays - bull.days.count)
            if diff > 0 { skipped["days"] = diff }
        } // `days` shape was already validated above.
        if let rawSnapshots = rawDictCount("fourScoreSnapshots") {
            let diff = max(0, rawSnapshots - bull.fourScoreSnapshots.count)
            if diff > 0 { skipped["fourScoreSnapshots"] = diff }
        } else if obj["fourScoreSnapshots"] != nil {
            skipped["fourScoreSnapshots"] = 1
        }

        let dates = bull.days.keys.compactMap { key -> Date? in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            var c = DateComponents()
            c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
            return Calendar(identifier: .gregorian).date(from: c)
        }
        let range: ClosedRange<Date>? = {
            guard let lo = dates.min(), let hi = dates.max() else { return nil }
            return lo...hi
        }()

        let report = ImportReport(
            daysImported: bull.days.count,
            itemsImported: bull.items.count,
            urgesImported: bull.urges.count,
            relapsesImported: bull.relapses.count,
            wetDreamsImported: bull.wetDreams.count,
            rulesImported: bull.rules.count,
            plansImported: bull.plans.count,
            scoreSnapshotsImported: bull.scoreSnapshots.count,
            sexualCheckInsImported: bull.sexualCheckIns.count,
            dailySexualObservationsImported: bull.dailySexualObservations.count,
            libidoSpotsImported: bull.libidoSpots.count,
            highRiskZonesImported: bull.highRiskZones.count,
            laylaSleepSchedulesImported: bull.laylaSleepSchedules.count,
            zoneEventsImported: bull.zoneEvents.count,
            safeguardEventsImported: bull.safeguardEvents.count,
            riskAlertEventsImported: bull.riskAlertEvents.count,
            privateContextSessionsImported: bull.privateContextSessions.count,
            weeklyGoalsImported: bull.weeklyGoals.count,
            weeklyGoalReviewsImported: bull.weeklyGoalReviews.count,
            personalFactorsImported: bull.personalFactors.count,
            exercisePlansImported: bull.exercisePlans.count,
            exerciseWeekReviewsImported: bull.exerciseWeekReviews.count,
            manualExerciseLogsImported: bull.manualExerciseLogs.count,
            damageControlLogsImported: bull.damageControlLogs.count,
            ejaculatoryControlObservationsImported: bull.ejaculatoryControlObservations.count,
            stressReadingsImported: bull.stressReadings.count,
            stressActivitiesImported: bull.stressActivities.count,
            stressReliefLogsImported: bull.stressReliefLogs.count,
            pornUrgeObservationsImported: bull.pornUrgeObservations.count,
            wakeErectionObservationsImported: bull.wakeErectionObservations.count,
            bullStateObservationsImported: bull.bullStateObservations.count,
            strengthWorkoutLogsImported: bull.strengthWorkoutLogs.count,
            fourScoreSnapshotsImported: bull.fourScoreSnapshots.count,
            riskControlChangeRequestsImported: bull.riskControlChangeRequests.count,
            therapistOutboxEventsImported: bull.therapistOutboxEvents.count,
            therapistInboxEventsImported: bull.therapistInboxEvents.count,
            therapistAccessAuditImported: bull.therapistAccessAudit.count,
            skipped: skipped,
            dateRange: range
        )
        return .success((bull, report))
    }

    /// Re-encodes a `BullData` back to the same shape app.js exports, for
    /// writing a fresh backup file or for the round-trip check used in tests.
    public static func exportData(_ data: BullData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(data)
    }

    public static func exportRedactedTrends(_ data: BullData) throws -> Data {
        let export = RedactedTrendExport(
            finalFourScoreSnapshots: data.fourScoreSnapshots.filter { $0.value.isFinal }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }
}
