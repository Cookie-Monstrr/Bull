import Foundation
import XCTest
@testable import Bull

final class V31MigrationTests: XCTestCase {
    private let utc = TimeZone(secondsFromGMT: 0)!

    func testV13MigrationStartsNewEraWithoutRewritingHistoryOrPairingLegacyRows() throws {
        let frozen = FourScoreSnapshot(
            urgeRoutine: 62,
            urgeState: 80,
            bullRoutine: 71,
            bullState: 55,
            scoringVersion: 7,
            recordedTs: 123,
            isFinal: true
        )
        let planDay = ExercisePlanDay(
            id: "strength-a",
            dayNumber: 1,
            title: "Strength A",
            kind: .strength,
            prescription: ["Bench Press · 3 × 6–10"],
            plannedStrengthSession: true
        )
        let plan = ExercisePlanVersion(
            versionNumber: 1,
            startDayKey: "2026-08-01",
            phase: .build,
            days: [planDay],
            rationale: "Fixture"
        )
        var source = BullData(version: 12, exercisePlans: [plan])
        source.fourScoreSnapshots["2026-08-27"] = frozen
        source.wakeErectionObservations = [
            WakeErectionObservation(dayKey: "2026-08-27", wakeLabel: "Fajr", erection: .yes, erectionHardnessScore: 3)
        ]
        source.dailySexualObservations = [
            DailySexualObservation(dayKey: "2026-08-27", morningErection: .notObserved, healthyDesire: 7)
        ]
        source.stressActivities = [
            StressActivityDefinition(id: "stress.nature-walk", name: "Riverside / nature walk", kind: .natureWalk, weeklyTarget: 5)
        ]
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-28T12:00:00Z"))

        let migrated = migratedBullDataToV13(source, timeZone: utc, now: now)

        XCTAssertEqual(migrated.version, 13)
        XCTAssertEqual(migrated.settings.fourScoreV8StartDayKey, "2026-08-28")
        XCTAssertEqual(migrated.settings.foodPlanLabel, "Bull Fuel")
        XCTAssertEqual(migrated.fourScoreSnapshots["2026-08-27"], frozen)
        XCTAssertTrue(migrated.bullStateObservations.isEmpty, "Legacy wake and desire streams must never be guessed into atomic v3.1 entries")
        XCTAssertEqual(migrated.wakeErectionObservations, source.wakeErectionObservations)
        XCTAssertEqual(migrated.dailySexualObservations, source.dailySexualObservations)
        XCTAssertEqual(migrated.stressActivities.first?.weeklyTarget, 0)
        XCTAssertEqual(migrated.stressActivities.first?.name, "Nature Walk")
        XCTAssertEqual(migrated.exercisePlans.first?.days.first?.strengthExercises?.first?.targetSets, 3)
        XCTAssertEqual(migrated.exercisePlans.first?.days.first?.strengthExercises?.first?.minimumReps, 6)
        XCTAssertEqual(migrated.exercisePlans.first?.days.first?.strengthExercises?.first?.maximumReps, 10)
    }

    func testV13MigrationIsIdempotent() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-28T12:00:00Z"))
        let once = migratedBullDataToV13(BullData(version: 12), timeZone: utc, now: now)
        let twice = migratedBullDataToV13(once, timeZone: utc, now: now)
        XCTAssertEqual(once, twice)
    }
}

final class V31StateTests: XCTestCase {
    func testUrgeStateUsesLatestTimestampRatherThanDailyPeak() {
        let observations = [
            PornUrgeObservation(id: "peak", ts: 100, dayKey: "d", intensity: 9),
            PornUrgeObservation(id: "latest", ts: 200, dayKey: "d", intensity: 3)
        ]
        let state = v31UrgeState(observations: observations, dayKey: "d")
        XCTAssertEqual(state.score, 30)
        XCTAssertEqual(state.meanPeak, 3)
        XCTAssertEqual(state.observedDays, 1)
        XCTAssertNil(v31UrgeState(observations: observations, dayKey: "missing").score)
    }

    func testBullStateUsesStrongestWakeAndLatestDesireOncePerDay() {
        let observations = [
            BullStateObservation(
                id: "dawn", ts: 100, dayKey: "d", wakeLabel: "Dawn",
                erection: .yes, erectionHardnessScore: 4, healthyDesire: 8
            ),
            BullStateObservation(
                id: "final", ts: 200, dayKey: "d", wakeLabel: "Final Wake",
                erection: .no, healthyDesire: 5
            )
        ]
        let state = v31BullState(observations: observations, dayKey: "d")
        XCTAssertEqual(state.erectionHealth, 100)
        XCTAssertEqual(state.healthyDesire, 50)
        XCTAssertEqual(state.score, 85)
        XCTAssertEqual(state.windowDays, 1)
    }

    func testNotObservedErectionKeepsBullStateMissing() {
        let observation = BullStateObservation(
            dayKey: "d", wakeLabel: "Dawn", erection: .notObserved, healthyDesire: 7
        )
        let state = v31BullState(observations: [observation], dayKey: "d")
        XCTAssertNil(state.erectionHealth)
        XCTAssertEqual(state.healthyDesire, 70)
        XCTAssertNil(state.score)
    }
}

final class V31StressRegulationTests: XCTestCase {
    private func finalState(morning: Int, evening: Int) -> StressRegulationState {
        v31StressRegulationState(
            readings: [
                StressReading(id: "m", ts: 100, dayKey: "d", value: morning, context: .morning),
                StressReading(id: "e", ts: 200, dayKey: "d", value: evening, context: .evening)
            ],
            dayKey: "d",
            allowProvisional: false
        )
    }

    func testLockedStressScoreTable() {
        XCTAssertEqual(finalState(morning: 8, evening: 5).score, 85)
        XCTAssertEqual(finalState(morning: 8, evening: 6).score, 70)
        XCTAssertEqual(finalState(morning: 8, evening: 7).score, 55)
        XCTAssertEqual(finalState(morning: 8, evening: 8).score, 35)
        XCTAssertEqual(finalState(morning: 8, evening: 9).score, 20)
        XCTAssertEqual(finalState(morning: 8, evening: 10).score, 0)
        XCTAssertEqual(finalState(morning: 5, evening: 3).score, 100)
    }

    func testMissingHistoricalEndpointStaysMissing() {
        let state = v31StressRegulationState(
            readings: [StressReading(ts: 100, dayKey: "d", value: 8, context: .morning)],
            dayKey: "d",
            allowProvisional: false
        )
        XCTAssertNil(state.score)
        XCTAssertFalse(state.isFinal)
    }

    func testLatestLiveReadingProvidesOnlyAProvisionalEndpoint() {
        let state = v31StressRegulationState(
            readings: [
                StressReading(ts: 100, dayKey: "d", value: 8, context: .morning),
                StressReading(ts: 200, dayKey: "d", value: 6, context: .checkIn, source: .live)
            ],
            dayKey: "d",
            allowProvisional: true
        )
        XCTAssertEqual(state.score, 70)
        XCTAssertFalse(state.isFinal)
    }

    func testExplicitMorningAndEveningContextsDoNotDependOnLoggingOrder() {
        let state = v31StressRegulationState(
            readings: [
                StressReading(ts: 200, dayKey: "d", value: 8, context: .morning),
                StressReading(ts: 100, dayKey: "d", value: 6, context: .evening)
            ],
            dayKey: "d",
            allowProvisional: false
        )
        XCTAssertEqual(state.score, 70)
        XCTAssertTrue(state.isFinal)
    }

    func testProspectiveEvidenceRanksAheadOfEstimateOnlyEvidence() {
        let activities = [
            StressActivityDefinition(id: "prospective", name: "Prospective", kind: .custom),
            StressActivityDefinition(id: "estimate", name: "Estimate", kind: .custom)
        ]
        let readings = [
            StressReading(id: "pb", ts: 1, dayKey: "d", value: 8, context: .activityBefore),
            StressReading(id: "pa", ts: 2, dayKey: "d", value: 7, context: .activityAfter),
            StressReading(id: "eb", ts: 3, dayKey: "d", value: 9, context: .activityBefore),
            StressReading(id: "ea", ts: 4, dayKey: "d", value: 1, context: .activityAfter)
        ]
        let logs = [
            StressReliefLog(dayKey: "d", activityID: "prospective", beforeReadingID: "pb", afterReadingID: "pa", timing: .prospective),
            StressReliefLog(dayKey: "d", activityID: "estimate", beforeReadingID: "eb", afterReadingID: "ea", timing: .estimatedAfterwards)
        ]
        let ranked = v30StressActivityLeaderboard(logs: logs, readings: readings, activities: activities)
        XCTAssertEqual(ranked.map(\.activityID), ["prospective", "estimate"])
        XCTAssertEqual(ranked.first?.prospectiveMedianDrop, 1)
        XCTAssertNil(ranked.last?.prospectiveMedianDrop)
    }
}

final class V31BullRoutineTests: XCTestCase {
    private let planDay = ExercisePlanDay(
        id: "strength-a",
        dayNumber: 1,
        title: "Strength A",
        kind: .strength,
        prescription: [],
        plannedStrengthSession: true,
        strengthExercises: [
            StrengthExercisePrescription(id: "bench", name: "Bench Press", targetSets: 2),
            StrengthExercisePrescription(id: "row", name: "Row", targetSets: 1)
        ]
    )

    func testStrengthCreditCountsScheduledSetsAndIgnoresExtras() {
        let sets = [
            StrengthSetLog(exerciseID: "bench", exerciseName: "Bench Press", setNumber: 1, weightKg: 50, reps: 8, completed: true),
            StrengthSetLog(exerciseID: "bench", exerciseName: "Bench Press", setNumber: 2, weightKg: 50, reps: 8, completed: false),
            StrengthSetLog(exerciseID: "row", exerciseName: "Row", setNumber: 1, weightKg: 40, reps: 10, completed: true),
            StrengthSetLog(exerciseID: "extra", exerciseName: "Curl", setNumber: 1, weightKg: 10, reps: 12, completed: true)
        ]
        let log = StrengthWorkoutLog(ts: 200, dayKey: "d", sets: sets)
        let state = v31BullRoutineState(
            daysByKey: [(key: "d", day: DayRecord(sleep: 100, aerobicMinutes: 160, bullFuelPercent: 100))],
            manualExerciseLogs: [],
            strengthWorkoutLogs: [log],
            scheduledStrengthDays: ["d": planDay]
        )
        XCTAssertEqual(state.weeklyStrengthCompletedSets, 2)
        XCTAssertEqual(state.weeklyStrengthScheduledSets, 3)
        XCTAssertEqual(state.strength!, 200.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(state.score!, 96.666_666, accuracy: 0.001)
    }

    func testPartialBullFuelEarnsHalfOfItsPillar() {
        let completedSets = [
            StrengthSetLog(exerciseID: "bench", exerciseName: "Bench Press", setNumber: 1, weightKg: 50, reps: 8, completed: true),
            StrengthSetLog(exerciseID: "bench", exerciseName: "Bench Press", setNumber: 2, weightKg: 50, reps: 8, completed: true),
            StrengthSetLog(exerciseID: "row", exerciseName: "Row", setNumber: 1, weightKg: 40, reps: 10, completed: true)
        ]
        let state = v31BullRoutineState(
            daysByKey: [(key: "d", day: DayRecord(sleep: 100, aerobicMinutes: 160, bullFuelPercent: 50))],
            manualExerciseLogs: [],
            strengthWorkoutLogs: [StrengthWorkoutLog(ts: 200, dayKey: "d", sets: completedSets)],
            scheduledStrengthDays: ["d": planDay]
        )
        XCTAssertEqual(state.foodPlan, 50)
        XCTAssertEqual(state.score, 90)
    }

    func testCardioActiveCaloriesAreSummedWithoutChangingScore() {
        let days = [
            (key: "d1", day: DayRecord(aerobicMinutes: 80, cardioActiveCalories: 420)),
            (key: "d2", day: DayRecord(aerobicMinutes: 40, vigorousMinutes: 40, cardioActiveCalories: 610))
        ]
        let state = v31BullRoutineState(
            daysByKey: days,
            manualExerciseLogs: [],
            strengthWorkoutLogs: [],
            scheduledStrengthDays: [:]
        )

        XCTAssertEqual(state.weeklyModerateEquivalentMinutes, 160)
        XCTAssertEqual(state.weeklyCardioActiveCalories, 1_030)
        XCTAssertEqual(state.cardio, 100)
        XCTAssertNil(state.score, "Calories are display-only and must not make missing pillars scoreable")
    }

    func testBullFuelRollingAverageExplainsFourAndTwoPointContributions() {
        let priorOffPlan = (1...4).map {
            (key: "d\($0)", day: DayRecord(bullFuelPercent: 0))
        }
        let onPlan = v31BullRoutineState(
            daysByKey: priorOffPlan + [(key: "today", day: DayRecord(bullFuelPercent: 100))],
            manualExerciseLogs: [],
            strengthWorkoutLogs: [],
            scheduledStrengthDays: [:]
        )
        let partly = v31BullRoutineState(
            daysByKey: priorOffPlan + [(key: "today", day: DayRecord(bullFuelPercent: 50))],
            manualExerciseLogs: [],
            strengthWorkoutLogs: [],
            scheduledStrengthDays: [:]
        )

        XCTAssertEqual(onPlan.foodPlan, 20)
        XCTAssertEqual(onPlan.foodPlan! * 0.20, 4)
        XCTAssertEqual(partly.foodPlan, 10)
        XCTAssertEqual(partly.foodPlan! * 0.20, 2)
    }
}

final class CardioHeartRateZoneTests: XCTestCase {
    func testCoveredMinutesAreClassifiedOnceAcrossFiveZones() throws {
        let summary = try XCTUnwrap(cardioHeartRateZoneSummary(
            points: [
                CardioHeartRatePoint(secondsFromWorkoutStart: 10, beatsPerMinute: 100),
                CardioHeartRatePoint(secondsFromWorkoutStart: 70, beatsPerMinute: 125),
                CardioHeartRatePoint(secondsFromWorkoutStart: 130, beatsPerMinute: 145),
                CardioHeartRatePoint(secondsFromWorkoutStart: 190, beatsPerMinute: 165),
                CardioHeartRatePoint(secondsFromWorkoutStart: 250, beatsPerMinute: 185)
            ],
            workoutDurationSeconds: 300,
            estimatedMaximumHeartRate: 200
        ))

        XCTAssertEqual(summary.zoneMinutes, [1, 1, 1, 1, 1])
        XCTAssertEqual(summary.observedMinutes, 5)
        XCTAssertEqual(summary.moderateMinutes, 2)
        XCTAssertEqual(summary.vigorousMinutes, 2)
    }

    func testDenseSamplesDoNotDoubleCountAMinute() throws {
        let summary = try XCTUnwrap(cardioHeartRateZoneSummary(
            points: (0..<12).map {
                CardioHeartRatePoint(secondsFromWorkoutStart: Double($0 * 5), beatsPerMinute: 140)
            },
            workoutDurationSeconds: 60,
            estimatedMaximumHeartRate: 200
        ))
        XCTAssertEqual(summary.observedMinutes, 1)
        XCTAssertEqual(summary.moderateMinutes, 1)
        XCTAssertEqual(summary.vigorousMinutes, 0)
    }
}

final class V32MigrationAndSleepTests: XCTestCase {
    private let utc = TimeZone(secondsFromGMT: 0)!

    func testV14MigrationStartsPurposeSleepEraWithoutRewritingV31Snapshot() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-30T12:00:00Z"))
        let frozen = FourScoreSnapshot(
            urgeRoutine: 61,
            urgeState: 40,
            bullRoutine: 72,
            bullState: 80,
            scoringVersion: 8,
            recordedTs: 100,
            isFinal: true
        )
        var source = BullData(version: 13)
        source.fourScoreSnapshots["2026-08-29"] = frozen

        let once = migratedBullDataToV14(source, timeZone: utc, now: now)
        let twice = migratedBullDataToV14(once, timeZone: utc, now: now)

        XCTAssertEqual(once.version, 14)
        XCTAssertEqual(once.settings.fourScoreV9StartDayKey, "2026-08-30")
        XCTAssertEqual(once.fourScoreSnapshots["2026-08-29"], frozen)
        XCTAssertEqual(once, twice)
    }

    func testPurposeScoresUseDifferentLockedWeights() {
        let longIrregularNight = BullSleepScore.purposeScores(
            durationPoints: 50,
            consistencyPoints: 0,
            interruptionPoints: 20
        )
        XCTAssertEqual(longIrregularNight.prevention, 70)
        XCTAssertEqual(longIrregularNight.vigour, 90)

        let shortRegularNight = BullSleepScore.purposeScores(
            durationPoints: 25,
            consistencyPoints: 30,
            interruptionPoints: 20
        )
        XCTAssertEqual(shortRegularNight.prevention, 78)
        XCTAssertEqual(shortRegularNight.vigour, 70)
    }

    func testBullRoutineUsesVigourSleepAndLegacyFallback() {
        let split = v31BullRoutineState(
            daysByKey: [(key: "d", day: DayRecord(
                sleep: 10,
                preventionSleepScore: 35,
                vigourSleepScore: 82
            ))],
            manualExerciseLogs: [],
            strengthWorkoutLogs: [],
            scheduledStrengthDays: [:]
        )
        XCTAssertEqual(split.sleep, 82)

        let legacy = v31BullRoutineState(
            daysByKey: [(key: "d", day: DayRecord(sleep: 67))],
            manualExerciseLogs: [],
            strengthWorkoutLogs: [],
            scheduledStrengthDays: [:]
        )
        XCTAssertEqual(legacy.sleep, 67)
    }

    func testPurposeSleepFieldsRoundTripAndLegacyDayFallsBack() throws {
        let day = DayRecord(
            sleep: 60,
            preventionSleepScore: 45,
            vigourSleepScore: 78,
            sleepPurposeScoreSource: BullSleepScore.purposeSourceIdentifier,
            sleepPurposeScoreVersion: BullSleepScore.purposeSourceVersion
        )
        let decoded = try JSONDecoder().decode(
            DayRecord.self,
            from: JSONEncoder().encode(day)
        )
        XCTAssertEqual(decoded, day)
        XCTAssertEqual(decoded.preventionSleepForScoring, 45)
        XCTAssertEqual(decoded.vigourSleepForScoring, 78)

        let legacy = try JSONDecoder().decode(
            DayRecord.self,
            from: Data(#"{"checks":{},"sleep":66}"#.utf8)
        )
        XCTAssertEqual(legacy.preventionSleepForScoring, 66)
        XCTAssertEqual(legacy.vigourSleepForScoring, 66)
    }

    func testCardioActiveCaloriesRoundTripAndLegacyDefault() throws {
        let day = DayRecord(
            aerobicMinutes: 45,
            vigorousMinutes: 15,
            cardioActiveCalories: 432.5,
            cardioIntensitySource: "heart-rate-zones"
        )
        let decoded = try JSONDecoder().decode(DayRecord.self, from: JSONEncoder().encode(day))
        XCTAssertEqual(decoded, day)
        XCTAssertEqual(decoded.cardioActiveCalories, 432.5)
        XCTAssertEqual(decoded.cardioIntensitySource, "heart-rate-zones")

        let legacy = try JSONDecoder().decode(
            DayRecord.self,
            from: Data(#"{"checks":{},"aerobicMinutes":45}"#.utf8)
        )
        XCTAssertNil(legacy.cardioActiveCalories)
        XCTAssertNil(legacy.cardioIntensitySource)
    }
}

final class V32SleepAnchoredZoneTests: XCTestCase {
    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }

    private func snapshot(state: LaylaSleepState = .upForDay) throws -> LaylaSleepScheduleSnapshot {
        LaylaSleepScheduleSnapshot(
            dayKey: "2026-08-30",
            plannedFinalWakeTs: try date("2026-08-30T06:00:00Z").timeIntervalSince1970 * 1_000,
            plannedBedtimeTs: try date("2026-08-30T22:30:00Z").timeIntervalSince1970 * 1_000,
            actualFinalWakeTs: try date("2026-08-30T06:00:00Z").timeIntervalSince1970 * 1_000,
            expectedReturnToSleepByTs: try date("2026-08-30T06:30:00Z").timeIntervalSince1970 * 1_000,
            state: state,
            updatedTs: try date("2026-08-30T06:00:00Z").timeIntervalSince1970 * 1_000
        )
    }

    private var zone: HighRiskZone {
        HighRiskZone(
            name: "Home",
            latitude: 0,
            longitude: 0,
            scheduleMode: .sleepAnchored,
            minutesAllowedAfterFinalWake: 90,
            minutesAllowedBeforeBed: 90,
            timeZoneIdentifier: "UTC"
        )
    }

    func testActualFinalWakeStartsNinetyMinuteAllowance() throws {
        let schedule = try snapshot()
        XCTAssertFalse(zone.isActive(
            at: try date("2026-08-30T07:29:00Z"), sleepSchedule: schedule
        ))
        XCTAssertTrue(zone.isActive(
            at: try date("2026-08-30T07:30:00Z"), sleepSchedule: schedule
        ))
        XCTAssertFalse(zone.isActive(
            at: try date("2026-08-30T21:00:00Z"), sleepSchedule: schedule
        ))
    }

    func testPlannedBriefWakeDoesNotStartFinalWakeAllowance() throws {
        let plannedBriefWake = try snapshot(state: .plannedBriefWake)
        XCTAssertFalse(zone.isActive(
            at: try date("2026-08-30T06:15:00Z"), sleepSchedule: plannedBriefWake
        ))
    }

    func testMissingLaylaSnapshotFallsBackToFixedSchedule() throws {
        let fixedFallback = HighRiskZone(
            name: "Home",
            latitude: 0,
            longitude: 0,
            startMinute: 7 * 60,
            endMinute: 9 * 60,
            scheduleMode: .sleepAnchored,
            timeZoneIdentifier: "UTC"
        )
        XCTAssertTrue(fixedFallback.isActive(
            at: try date("2026-08-30T07:30:00Z"), sleepSchedule: nil
        ))
    }

    func testLegacyZoneDecodesWithFixedSafeDefaults() throws {
        let legacy = try JSONDecoder().decode(
            HighRiskZone.self,
            from: Data(#"{"id":"home","name":"Home","latitude":0,"longitude":0,"startMinute":420,"endMinute":540}"#.utf8)
        )
        XCTAssertEqual(legacy.scheduleMode, .fixed)
        XCTAssertEqual(legacy.minutesAllowedAfterFinalWake, 90)
        XCTAssertEqual(legacy.minutesAllowedBeforeBed, 90)
        XCTAssertTrue(legacy.activateWhenUnexpectedlyAwake)
    }
}

final class V32StatsTests: XCTestCase {
    func testRangeCardsUseRecordedV31AndV32SnapshotsAndExcludeToday() throws {
        let now = try XCTUnwrap(BullDates.calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 30, hour: 12
        )))
        var data = BullData(firstUse: now.addingTimeInterval(-40 * 86_400).timeIntervalSince1970 * 1_000)
        data.fourScoreSnapshots["2026-08-28"] = FourScoreSnapshot(
            urgeRoutine: 50, urgeState: 40, bullRoutine: 60, bullState: 70,
            scoringVersion: 8, recordedTs: 1, isFinal: true
        )
        data.fourScoreSnapshots["2026-08-29"] = FourScoreSnapshot(
            urgeRoutine: 70, urgeState: 60, bullRoutine: 80, bullState: 90,
            scoringVersion: 9, recordedTs: 2, isFinal: true
        )
        data.fourScoreSnapshots["2026-08-30"] = FourScoreSnapshot(
            urgeRoutine: 100, urgeState: 100, bullRoutine: 100, bullState: 100,
            scoringVersion: 9, recordedTs: 3, isFinal: false
        )

        let summary = PatternAnalyzer.fourScoreRangeSummary(
            data: data,
            window: .month,
            now: now
        )
        XCTAssertEqual(summary.observedDays, 2)
        XCTAssertEqual(summary.urgeRoutine, 60)
        XCTAssertEqual(summary.urgeState, 50)
        XCTAssertEqual(summary.bullRoutine, 70)
        XCTAssertEqual(summary.bullState, 80)
    }

    func testArchivedExperimentsDoNotAppearInReadiness() {
        let key = BullDates.key(for: Date())
        let active = PersonalFactor(
            id: "active",
            name: "Active",
            kind: .action,
            intendedOutcome: .highUrge,
            hypothesis: "",
            scheduleDescription: "",
            startDayKey: key
        )
        let archived = PersonalFactor(
            id: "archived",
            name: "Archived",
            kind: .action,
            intendedOutcome: .highUrge,
            hypothesis: "",
            scheduleDescription: "",
            startDayKey: key,
            archived: true
        )
        let data = BullData(personalFactors: [active, archived])
        XCTAssertEqual(
            PatternAnalyzer.personalFactorPatterns(data: data, window: .all).map(\.factorID),
            ["active"]
        )
    }
}
