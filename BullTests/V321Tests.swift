import Foundation
import XCTest
@testable import Bull

final class V321HistoricalCorrectionTests: XCTestCase {
    func testBuiltInControlLabelsAreConciseAndLegacyTriggerAliasesRemain() throws {
        let triggers = Dictionary(uniqueKeysWithValues: V27Defaults.triggers.map { ($0.id, $0) })
        XCTAssertEqual(triggers["trigger.anxiety"]?.name, "Stress")
        XCTAssertTrue(triggers["trigger.anxiety"]?.aliases.contains("Anxiety / stress") == true)
        XCTAssertFalse(V30Defaults.stressActivities.contains { $0.name.contains(" / ") })
        XCTAssertEqual(WeeklyGoalCategory.healthRoutine.label, "Health")
        XCTAssertEqual(WeeklyGoalCategory.preventionSafeguard.label, "Prevention")
    }

    func testLegacyEjaculatoryObservationDecodesWithMigrationProvenance() throws {
        let raw = Data(#"""
        {
            "id":"legacy-entry",
            "ts":1234,
            "dayKey":"2026-08-29",
            "perceivedControl":7,
            "soonerThanDesired":true,
            "bother":4,
            "note":"private"
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(EjaculatoryControlObservation.self, from: raw)

        XCTAssertEqual(decoded.id, "legacy-entry")
        XCTAssertEqual(decoded.ts, 1234)
        XCTAssertEqual(decoded.source, .migratedLegacy)
        XCTAssertNil(decoded.modifiedTs)
        XCTAssertEqual(
            try JSONDecoder().decode(
                EjaculatoryControlObservation.self,
                from: JSONEncoder().encode(decoded)
            ),
            decoded
        )
    }

    func testLegacyFourScoreSnapshotDefaultsToOriginalRevision() throws {
        let raw = Data(#"""
        {
            "urgeRoutine":150,
            "urgeState":40,
            "bullRoutine":70,
            "bullState":80,
            "scoringVersion":9,
            "recordedTs":1234,
            "isFinal":true
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(FourScoreSnapshot.self, from: raw)

        XCTAssertEqual(decoded.urgeRoutine, 100)
        XCTAssertEqual(decoded.revision, 0)
        XCTAssertNil(decoded.originalRecordedTs)
        XCTAssertTrue(decoded.isFinal)
    }

    func testRevisedFourScoreSnapshotRoundTripsCorrectionMetadata() throws {
        let revised = FourScoreSnapshot(
            urgeRoutine: 60,
            urgeState: 30,
            bullRoutine: 75,
            bullState: 80,
            scoringVersion: 9,
            recordedTs: 2_000,
            isFinal: true,
            revision: 2,
            originalRecordedTs: 1_000
        )

        let decoded = try JSONDecoder().decode(
            FourScoreSnapshot.self,
            from: JSONEncoder().encode(revised)
        )

        XCTAssertEqual(decoded, revised)
    }

    func testEqualTimestampUrgeRowsUseDurableIngestionOrder() {
        let state = v31UrgeState(
            observations: [
                PornUrgeObservation(id: "z-first", ts: 100, dayKey: "d", intensity: 2),
                PornUrgeObservation(id: "a-later", ts: 100, dayKey: "d", intensity: 8)
            ],
            dayKey: "d"
        )

        XCTAssertEqual(state.score, 80)
    }

    func testEqualTimestampBullStateRowsUseDurableIngestionOrder() {
        let state = v31BullState(
            observations: [
                BullStateObservation(
                    id: "z-first", ts: 100, dayKey: "d", wakeLabel: "Dawn",
                    erection: .no, healthyDesire: 1
                ),
                BullStateObservation(
                    id: "a-later", ts: 100, dayKey: "d", wakeLabel: "Final Wake",
                    erection: .yes, erectionHardnessScore: 4, healthyDesire: 9
                )
            ],
            dayKey: "d"
        )

        XCTAssertEqual(state.erectionHealth, 100)
        XCTAssertEqual(state.healthyDesire, 90)
        XCTAssertEqual(state.score, 97)
    }
}

final class V321LaylaIngestionTests: XCTestCase {
    private func snapshot(
        id: String = "layla-1",
        dayKey: String = "2026-08-30",
        updatedTs: Double,
        plannedBedtimeTs: Double = 30_000
    ) -> LaylaSleepScheduleSnapshot {
        LaylaSleepScheduleSnapshot(
            id: id,
            dayKey: dayKey,
            plannedFinalWakeTs: 10_000,
            plannedBedtimeTs: plannedBedtimeTs,
            actualFinalWakeTs: 10_000,
            state: .upForDay,
            updatedTs: updatedTs
        )
    }

    func testFirstSnapshotIsAcceptedAndExactReplayIsIdempotent() {
        let incoming = snapshot(updatedTs: 100)
        XCTAssertEqual(
            laylaSnapshotIngestionDecision(incoming: incoming, existing: []),
            .accept
        )
        XCTAssertEqual(
            laylaSnapshotIngestionDecision(incoming: incoming, existing: [incoming]),
            .idempotent
        )
    }

    func testStaleAndEqualTimestampConflictsAreRejected() {
        let current = snapshot(updatedTs: 200)
        XCTAssertEqual(
            laylaSnapshotIngestionDecision(
                incoming: snapshot(id: "older", updatedTs: 199),
                existing: [current]
            ),
            .rejectStale
        )
        XCTAssertEqual(
            laylaSnapshotIngestionDecision(
                incoming: snapshot(id: "conflict", updatedTs: 200, plannedBedtimeTs: 31_000),
                existing: [current]
            ),
            .rejectConflict
        )
        XCTAssertEqual(
            laylaSnapshotIngestionDecision(
                incoming: snapshot(id: "newer", updatedTs: 201),
                existing: [current]
            ),
            .accept
        )
    }

    func testSequencedUpdatesAreMonotonicAcrossCivilDays() {
        var current = snapshot(dayKey: "2026-08-30", updatedTs: 200)
        current.sourceSequence = 9
        current.sourceBundleIdentifier = "com.ahmed.Layla"
        var replay = snapshot(id: "replay", dayKey: "2026-08-29", updatedTs: 300)
        replay.sourceSequence = 8
        var next = snapshot(id: "next", dayKey: "2026-08-31", updatedTs: 201)
        next.sourceSequence = 10
        next.sourceBundleIdentifier = "com.ahmed.Layla"

        XCTAssertEqual(
            laylaSnapshotIngestionDecision(incoming: replay, existing: [current]),
            .rejectStale
        )
        XCTAssertEqual(
            laylaSnapshotIngestionDecision(incoming: next, existing: [current]),
            .accept
        )
        XCTAssertEqual([current, next].max(by: laylaSnapshotPrecedes)?.sourceSequence, 10)

        var otherWriter = next
        otherWriter.sourceBundleIdentifier = "com.example.NotLayla"
        XCTAssertFalse(laylaSnapshotSourceIdentityIsConsistent(
            incoming: otherWriter,
            existing: [current]
        ))
    }
}

final class V34LaylaScheduleBridgeTests: XCTestCase {
    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }

    private func envelope(
        state: LaylaSleepState = .upForDay,
        timeZoneIdentifier: String = "UTC",
        actualFinalWakeTs: Double? = nil,
        expectedReturnToSleepByTs: Double? = nil,
        stateObservedTs: Double? = nil
    ) throws -> LaylaSleepScheduleTransportEnvelope {
        let wake = try date("2026-09-05T06:00:00Z").timeIntervalSince1970 * 1_000
        let updated = try date("2026-09-05T06:05:00Z").timeIntervalSince1970 * 1_000
        return LaylaSleepScheduleTransportEnvelope(
            schemaVersion: 1,
            sequence: 42,
            writtenTs: updated,
            writerBundleIdentifier: "com.ahmed.Layla",
            snapshot: LaylaSleepScheduleSnapshot(
                id: "2026-09-05-42",
                dayKey: "2026-09-05",
                plannedFinalWakeTs: wake,
                plannedBedtimeTs: try date("2026-09-05T22:30:00Z")
                    .timeIntervalSince1970 * 1_000,
                actualFinalWakeTs: actualFinalWakeTs ?? (state == .upForDay ? wake : nil),
                expectedReturnToSleepByTs: expectedReturnToSleepByTs,
                sleepConsistencyDeviationMinutes: 20,
                state: state,
                stateObservedTs: stateObservedTs ?? wake,
                updatedTs: updated,
                timeZoneIdentifier: timeZoneIdentifier,
                sourceSequence: 42,
                sourceBundleIdentifier: "com.ahmed.Layla"
            )
        )
    }

    func testValidAtomicEnvelopeDecodesAndCarriesSequence() throws {
        let source = try envelope()
        let decoded = try LaylaScheduleBridge.validatedEnvelope(
            from: JSONEncoder().encode(source),
            now: try date("2026-09-05T06:10:00Z")
        )

        XCTAssertEqual(decoded, source)
        XCTAssertEqual(decoded.snapshot.sourceSequence, 42)
        XCTAssertEqual(decoded.snapshot.sourceBundleIdentifier, "com.ahmed.Layla")
        XCTAssertEqual(decoded.snapshot.timeZoneIdentifier, "UTC")
    }

    func testTransportRejectsInvalidTimeZoneAndMismatchedDayKey() throws {
        var invalidZone = try envelope(timeZoneIdentifier: "Not/A_Time_Zone")
        XCTAssertThrowsError(try LaylaScheduleBridge.validatedEnvelope(
            from: JSONEncoder().encode(invalidZone),
            now: try date("2026-09-05T06:10:00Z")
        )) { error in
            XCTAssertEqual(error as? LaylaScheduleTransportFailure, .invalidTimeZone)
        }

        invalidZone = try envelope()
        invalidZone.snapshot.dayKey = "2026-09-04"
        XCTAssertThrowsError(try LaylaScheduleBridge.validatedEnvelope(
            from: JSONEncoder().encode(invalidZone),
            now: try date("2026-09-05T06:10:00Z")
        )) { error in
            XCTAssertEqual(error as? LaylaScheduleTransportFailure, .invalidDayKey)
        }
    }

    func testBriefWakeBeforeFinalWakeIsAcceptedThenFailsSafeAtDeadline() throws {
        let observed = try date("2026-09-05T04:45:00Z").timeIntervalSince1970 * 1_000
        let deadline = try date("2026-09-05T05:15:00Z").timeIntervalSince1970 * 1_000
        var source = try envelope(
            state: .plannedBriefWake,
            expectedReturnToSleepByTs: deadline,
            stateObservedTs: observed
        )
        let updated = try date("2026-09-05T04:50:00Z").timeIntervalSince1970 * 1_000
        source.writtenTs = updated
        source.snapshot.updatedTs = updated
        let decoded = try LaylaScheduleBridge.validatedEnvelope(
            from: JSONEncoder().encode(source),
            now: try date("2026-09-05T05:00:00Z")
        )
        let zone = HighRiskZone(
            name: "Home",
            latitude: 0,
            longitude: 0,
            scheduleMode: .sleepAnchored,
            activateWhenUnexpectedlyAwake: true,
            timeZoneIdentifier: "UTC"
        )

        XCTAssertFalse(zone.isActive(
            at: try date("2026-09-05T05:00:00Z"),
            sleepSchedule: decoded.snapshot
        ))
        XCTAssertTrue(zone.isActive(
            at: try date("2026-09-05T05:16:00Z"),
            sleepSchedule: decoded.snapshot
        ))
    }

    func testLiveTransportRequiresActualWakeForFinalAndUnexpectedStates() throws {
        var source = try envelope(state: .unexpectedlyAwake)
        source.snapshot.actualFinalWakeTs = nil

        XCTAssertThrowsError(try LaylaScheduleBridge.validatedEnvelope(
            from: JSONEncoder().encode(source),
            now: try date("2026-09-05T06:10:00Z")
        )) { error in
            XCTAssertEqual(error as? LaylaScheduleTransportFailure, .invalidState)
        }
    }
}

final class V321NotificationBoundaryTests: XCTestCase {
    func testRiskZoneCopyUsesRequestedPromptInPrivateAndDetailedModes() {
        let privateCopy = riskZoneNotificationCopy(
            zoneName: "Private Place",
            safeguardInstruction: "Leave now",
            showDetails: false
        )
        XCTAssertEqual(privateCopy.title, "Private reminder")
        XCTAssertEqual(privateCopy.body, "Take action before you regret it!")
        XCTAssertFalse(privateCopy.title.contains("Bull"))
        XCTAssertFalse(privateCopy.body.contains("Private Place"))
        XCTAssertFalse(privateCopy.body.contains("Leave now"))

        let detailed = riskZoneNotificationCopy(
            zoneName: "Home",
            safeguardInstruction: "Move to the office",
            showDetails: true
        )
        XCTAssertEqual(detailed.title, "Bull · Home")
        XCTAssertEqual(
            detailed.body,
            "Take action before you regret it! Move to the office"
        )
    }

    func testFollowUpsAreClampedAndStopBeforeSafeWindow() {
        let start = Date(timeIntervalSince1970: 0)
        let end = start.addingTimeInterval(50 * 60)

        let dates = boundedZoneFollowUpDates(
            firstFireDate: start,
            repeatMinutes: 10,
            activeUntil: end
        )

        XCTAssertEqual(
            dates.map { Int($0.timeIntervalSince(start) / 60) },
            [15, 30, 45]
        )
    }

    func testFollowUpAtExactSafeBoundaryIsExcludedAndCountIsBounded() {
        let start = Date(timeIntervalSince1970: 0)
        let boundary = start.addingTimeInterval(45 * 60)
        XCTAssertEqual(
            boundedZoneFollowUpDates(
                firstFireDate: start,
                repeatMinutes: 15,
                activeUntil: boundary
            ).count,
            2
        )

        XCTAssertEqual(
            boundedZoneFollowUpDates(
                firstFireDate: start,
                repeatMinutes: 15,
                activeUntil: start.addingTimeInterval(24 * 3_600),
                maximumCount: 100
            ).count,
            8
        )
    }
}

final class V321BackupHardeningTests: XCTestCase {
    func testOversizedBackupIsRejectedBeforeDecode() {
        let oversized = Data(count: BackupImporter.maximumBackupBytes + 1)

        guard case .failure(.tooLarge(let maximum)) = BackupImporter.importBackup(from: oversized) else {
            return XCTFail("Expected the backup size guard to reject the document")
        }
        XCTAssertEqual(maximum, BackupImporter.maximumBackupBytes)
    }

    func testEveryNewCollectionReportsMalformedRows() throws {
        let source = try BackupImporter.exportData(BullData())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: source) as? [String: Any]
        )
        let arrayKeys = [
            "stressReadings", "stressActivities", "stressReliefLogs",
            "pornUrgeObservations", "wakeErectionObservations",
            "bullStateObservations", "strengthWorkoutLogs",
            "ejaculatoryControlObservations"
        ]
        for key in arrayKeys { object[key] = ["malformed"] }
        object["fourScoreSnapshots"] = ["bad": "malformed"]
        let corrupted = try JSONSerialization.data(withJSONObject: object)

        guard case .success((_, let report)) = BackupImporter.importBackup(from: corrupted) else {
            return XCTFail("Expected a recoverable import with explicit skips")
        }
        for key in arrayKeys + ["fourScoreSnapshots"] {
            XCTAssertEqual(report.skipped[key], 1, "Missing skip report for \(key)")
        }
    }

    func testRedactedExportContainsOnlyFinalScoreTrends() throws {
        var data = BullData()
        data.settings.therapyNote = "THERAPY_SECRET"
        data.ejaculatoryControlObservations = [
            EjaculatoryControlObservation(
                dayKey: "2026-08-29",
                perceivedControl: 2,
                soonerThanDesired: true,
                bother: 8,
                note: "SEXUAL_NOTE_SECRET"
            )
        ]
        data.highRiskZones = [
            HighRiskZone(name: "PRIVATE_PLACE", latitude: 51.5, longitude: -0.1)
        ]
        data.fourScoreSnapshots = [
            "2026-08-28": FourScoreSnapshot(
                urgeRoutine: 60, urgeState: 40, bullRoutine: 70, bullState: 80,
                recordedTs: 100, isFinal: true
            ),
            "2026-08-29": FourScoreSnapshot(
                urgeRoutine: 65, urgeState: 35, bullRoutine: 75, bullState: 85,
                recordedTs: 200, isFinal: false
            )
        ]

        let raw = try BackupImporter.exportRedactedTrends(data)
        let text = try XCTUnwrap(String(data: raw, encoding: .utf8))
        let decoded = try JSONDecoder().decode(RedactedTrendExport.self, from: raw)

        XCTAssertFalse(text.contains("THERAPY_SECRET"))
        XCTAssertFalse(text.contains("SEXUAL_NOTE_SECRET"))
        XCTAssertFalse(text.contains("PRIVATE_PLACE"))
        XCTAssertFalse(text.contains("highRiskZones"))
        XCTAssertEqual(Set(decoded.finalFourScoreSnapshots.keys), ["2026-08-28"])
    }
}

final class V321PatternWindowTests: XCTestCase {
    func testAllTimeIncludesHistoryOlderThanTenYears() throws {
        let firstUse = try XCTUnwrap(BullDates.date(from: "2010-01-01"))
        let now = try XCTUnwrap(BullDates.date(from: "2026-08-30"))

        let dates = PatternWindow.all.completedDates(
            firstUseMS: firstUse.timeIntervalSince1970 * 1_000,
            now: now
        )

        XCTAssertGreaterThan(dates.count, 3_650)
        XCTAssertEqual(dates.first.map(BullDates.key), "2010-01-01")
        XCTAssertEqual(dates.last.map(BullDates.key), "2026-08-29")
    }
}
