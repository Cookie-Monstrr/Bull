import XCTest
@testable import Bull

final class V30Tests: XCTestCase {
    func testV12MigrationIsAdditiveAndDoesNotRewriteLegacySnapshot() {
        let frozen = ScoreSnapshot(
            risk: 73,
            vigour: 61,
            scoringVersion: 6,
            recordedTs: 123,
            vigourObserved: true,
            peakRisk: 81,
            isFinal: true
        )
        var source = BullData(version: 11)
        source.days["2026-08-20"] = DayRecord(access: .high, stressLevel: 7)
        source.scoreSnapshots["2026-08-20"] = frozen

        let migrated = migratedBullDataToV12(source, timeZone: TimeZone(secondsFromGMT: 0)!)

        XCTAssertEqual(migrated.version, 12)
        XCTAssertEqual(migrated.days["2026-08-20"]?.access?.rawValue, AccessLevel.high.rawValue)
        XCTAssertEqual(migrated.scoreSnapshots["2026-08-20"], frozen)
        XCTAssertTrue(migrated.fourScoreSnapshots.isEmpty)
        XCTAssertEqual(migrated.stressReadings.filter { $0.dayKey == "2026-08-20" }.map(\.value), [7])
        XCTAssertEqual(migrated.items.first { $0.id == "contentAccess" }?.archived, true)
    }

    func testMigrationIsIdempotent() {
        var source = BullData(version: 11)
        source.days["2026-08-20"] = DayRecord(stressLevel: 6)
        let once = migratedBullDataToV12(source, timeZone: TimeZone(secondsFromGMT: 0)!)
        let twice = migratedBullDataToV12(once, timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertEqual(once, twice)
    }

    func testStressAverageIsTimeWeightedAndDoesNotBackfillBeforeFirstReading() {
        let day = "2026-08-20"
        let hour = 3_600_000.0
        let readings = [
            StressReading(id: "a", ts: 8 * hour, dayKey: day, value: 9),
            StressReading(id: "b", ts: 20 * hour, dayKey: day, value: 3)
        ]
        let state = v30TimeWeightedStress(readings: readings, dayStartTs: 0, dayEndTs: 24 * hour)
        XCTAssertEqual(state.average!, 7.5, accuracy: 0.0001)
        XCTAssertEqual(state.observedHours, 16, accuracy: 0.0001)
        XCTAssertEqual(state.readingCount, 2)
    }

    func testUrgeStateUsesDailyPeakAndLeavesMissingDaysOut() {
        let observations = [
            PornUrgeObservation(dayKey: "d1", intensity: 2),
            PornUrgeObservation(dayKey: "d1", intensity: 8),
            PornUrgeObservation(dayKey: "d3", intensity: 0, context: .explicitNoUrge)
        ]
        let state = v30UrgeState(observations: observations, orderedDayKeys: ["d1", "d2", "d3"])
        XCTAssertEqual(state.observedDays, 2)
        XCTAssertEqual(state.meanPeak, 4)
        XCTAssertEqual(state.score, 40)
    }

    func testBullStateAggregatesMultipleWakesOncePerDay() {
        let wakes = [
            WakeErectionObservation(dayKey: "d1", wakeLabel: "Fajr", erection: .no),
            WakeErectionObservation(dayKey: "d1", wakeLabel: "Final", erection: .yes, erectionHardnessScore: 4),
            WakeErectionObservation(dayKey: "d2", wakeLabel: "Final", erection: .no)
        ]
        let daily = [
            DailySexualObservation(dayKey: "d1", morningErection: .notObserved, healthyDesire: 8),
            DailySexualObservation(dayKey: "d2", morningErection: .notObserved, healthyDesire: 6)
        ]
        let state = v30BullState(
            wakeObservations: wakes,
            dailyObservations: daily,
            orderedDayKeys: ["d1", "d2"]
        )
        // Frequency 50 and best positive-day hardness 100 combine to Erection Health 75.
        XCTAssertEqual(state.erectionHealth!, 75, accuracy: 0.0001)
        XCTAssertEqual(state.healthyDesire!, 70, accuracy: 0.0001)
        XCTAssertEqual(state.score!, 73, accuracy: 0.0001)
        XCTAssertEqual(state.erectionDays, 2)
    }

    func testStressLeaderboardUsesMedianDropAndShowsStartingStress() {
        let activity = StressActivityDefinition(id: "walk", name: "Walk", kind: .natureWalk)
        let readings = [
            StressReading(id: "b1", ts: 1, dayKey: "d", value: 8, context: .activityBefore),
            StressReading(id: "a1", ts: 2, dayKey: "d", value: 4, context: .activityAfter),
            StressReading(id: "b2", ts: 3, dayKey: "d", value: 6, context: .activityBefore),
            StressReading(id: "a2", ts: 4, dayKey: "d", value: 5, context: .activityAfter)
        ]
        let logs = [
            StressReliefLog(ts: 2, dayKey: "d", activityID: "walk", beforeReadingID: "b1", afterReadingID: "a1"),
            StressReliefLog(ts: 4, dayKey: "d", activityID: "walk", beforeReadingID: "b2", afterReadingID: "a2")
        ]
        let effect = v30StressActivityLeaderboard(logs: logs, readings: readings, activities: [activity]).first!
        XCTAssertEqual(effect.medianDrop, 2.5, accuracy: 0.0001)
        XCTAssertEqual(effect.typicalStartingStress, 7, accuracy: 0.0001)
        XCTAssertEqual(effect.pairedCount, 2)
    }

    func testAsNeededStressActivitiesNeverCreateAComplianceTarget() {
        let activity = StressActivityDefinition(
            id: "sigh", name: "Sigh", kind: .physiologicalSigh, weeklyTarget: 0
        )
        XCTAssertNil(v30StressPlanScore(activities: [activity], logs: []))
    }
}
