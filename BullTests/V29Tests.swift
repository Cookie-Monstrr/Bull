import XCTest
@testable import Bull

final class V29MigrationTests: XCTestCase {
    func testMigrationPreservesEveryLegacyCollectionAndSnapshot() {
        let snapshot = ScoreSnapshot(risk: 71, vigour: 44, scoringVersion: 5, recordedTs: 123)
        let session = PrivateContextSession(id: "private", ts: 10, endedTs: 20, dayKey: "2026-08-20")
        let checkIn = AccountabilityCheckIn(id: "check", ts: 30, scheduledTs: 25, attended: false, dayKey: "2026-08-20")
        let plan = ImplementationPlan(id: "ifthen", trigger: "Tired", action: "Leave", createdTs: 40)
        var source = BullData(
            version: 10,
            plans: [plan],
            scoreSnapshots: ["2026-08-20": snapshot],
            accountabilityCheckIns: [checkIn],
            privateContextSessions: [session],
            exercisePlans: []
        )
        source.settings.accountabilityEnabled = true

        let migrated = migratedBullDataToV11(source, timeZone: TimeZone(secondsFromGMT: 0)!)

        XCTAssertEqual(migrated.version, 11)
        XCTAssertEqual(migrated.plans, [plan])
        XCTAssertEqual(migrated.scoreSnapshots["2026-08-20"], snapshot)
        XCTAssertEqual(migrated.accountabilityCheckIns, [checkIn])
        XCTAssertEqual(migrated.privateContextSessions, [session])
        XCTAssertTrue(migrated.settings.accountabilityEnabled, "Historical user setting is retained even though live Risk ignores it")
        XCTAssertEqual(migrated.exercisePlans.count, 1)
    }

    func testMigrationIsIdempotent() {
        var source = BullData(version: 10, exercisePlans: [])
        source.items.append(Item(id: "custom", label: "Keep me", list: .prev, kind: .habit, weight: .low))
        let once = migratedBullDataToV11(source)
        let twice = migratedBullDataToV11(once)
        XCTAssertEqual(once, twice)
        XCTAssertEqual(twice.items.filter { $0.id == "custom" }.count, 1)
        XCTAssertEqual(twice.responseLibrary.filter { $0.id == "response.boxing" }.count, 1)

        let earlyV11 = BullData(version: 11, responseLibrary: [], exercisePlans: [])
        let repaired = migratedBullDataToV11(earlyV11)
        XCTAssertEqual(repaired.exercisePlans.count, 1)
        XCTAssertEqual(repaired.responseLibrary.filter { $0.id == "response.boxing" }.count, 1)
    }

    func testRetiredLiveControlsAreArchivedNotDeleted() {
        let migrated = migratedBullDataToV11(BullData(version: 10))
        XCTAssertEqual(migrated.items.first { $0.id == "accountabilityGap" }?.archived, true)
        XCTAssertEqual(migrated.items.first { $0.id == "fasting" }?.archived, true)
        XCTAssertNotNil(migrated.items.first { $0.id == "accountabilityGap" })
        XCTAssertNotNil(migrated.items.first { $0.id == "fasting" })
    }

    func testResponseLanesMatchApprovedModel() {
        let migrated = migratedBullDataToV11(BullData(version: 10))
        let byID = Dictionary(uniqueKeysWithValues: migrated.responseLibrary.map { ($0.id, $0) })
        XCTAssertEqual(byID["response.boxing"]?.lane, .countermove)
        XCTAssertEqual(byID["response.connection"]?.name, "Uplifting connection")
        XCTAssertEqual(byID["response.cold-plunge"]?.lane, .damageControl)
        XCTAssertEqual(byID["response.contact"]?.archived, true)
        XCTAssertEqual(byID["response.if-then"]?.archived, true)
    }

    func testV10JSONDecodesWithEmptyV29ArraysThenMigrates() throws {
        let json = Data("""
        {"version":10,"settings":{},"items":[],"days":{},"urges":[],"relapses":[],"wetDreams":[],"rules":[],"firstUse":1}
        """.utf8)
        let decoded = try JSONDecoder().decode(BullData.self, from: json)
        XCTAssertTrue(decoded.exercisePlans.isEmpty)
        XCTAssertTrue(decoded.damageControlLogs.isEmpty)
        XCTAssertEqual(migratedBullDataToV11(decoded).exercisePlans.count, 1)
    }

    func testLegacySnapshotDecodesWithoutInventingPeakOrFinalizationState() throws {
        let json = Data("""
        {"risk":71,"vigour":44,"scoringVersion":5,"recordedTs":123}
        """.utf8)
        let snapshot = try JSONDecoder().decode(ScoreSnapshot.self, from: json)
        XCTAssertEqual(snapshot.risk, 71)
        XCTAssertNil(snapshot.peakRisk)
        XCTAssertNil(snapshot.isFinal)
    }

    func testV29PeakSnapshotRoundTrips() throws {
        let snapshot = ScoreSnapshot(
            risk: 52, vigour: 68, scoringVersion: 6, recordedTs: 123,
            vigourObserved: true, peakRisk: 77, isFinal: true
        )
        let decoded = try JSONDecoder().decode(
            ScoreSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        XCTAssertEqual(decoded, snapshot)
    }

    func testDamageControlTrajectoryRoundTripsWithoutChangingRiskInputs() throws {
        let check = DamageControlCheckIn(
            id: "check", ts: 200, repeatPull: 8, recoveryMood: 3, feelsRecovered: false
        )
        let log = DamageControlLog(
            id: "log", relapseID: "lapse", dayKey: "2026-08-27",
            completedSteps: [.coldPlunge], updatedTs: 201,
            stepCompletionTs: [DamageControlStep.coldPlunge.rawValue: 150],
            checkIns: [check]
        )
        let decoded = try JSONDecoder().decode(
            DamageControlLog.self,
            from: JSONEncoder().encode(log)
        )
        XCTAssertEqual(decoded, log)
        XCTAssertEqual(decoded.checkIns?.first?.repeatPull, 8)
    }
}

final class V29UrgeRiskTests: XCTestCase {
    func testSleepCompoundsOnlyWithinItsOwnComponent() {
        let one = v29UrgeRiskState(
            sleepScoresTodayFirst: [30, nil, nil], access: .low,
            riskyEnvironmentPoints: 0, environmentObserved: true,
            hoursSinceLapse: nil, hoursSinceWetDream: nil
        )
        let two = v29UrgeRiskState(
            sleepScoresTodayFirst: [30, 30, nil], access: .low,
            riskyEnvironmentPoints: 0, environmentObserved: true,
            hoursSinceLapse: nil, hoursSinceWetDream: nil
        )
        let three = v29UrgeRiskState(
            sleepScoresTodayFirst: [30, 30, 30], access: .low,
            riskyEnvironmentPoints: 0, environmentObserved: true,
            hoursSinceLapse: nil, hoursSinceWetDream: nil
        )
        XCTAssertEqual(one.sleepRecovery, 20, accuracy: 0.001)
        XCTAssertEqual(two.sleepRecovery, 32, accuracy: 0.001)
        XCTAssertEqual(three.sleepRecovery, 40, accuracy: 0.001)
        XCTAssertEqual(three.explicitContent, 0)
    }

    func testFourComponentsRespectApprovedCaps() {
        let state = v29UrgeRiskState(
            sleepScoresTodayFirst: [0, 0, 0], access: .high,
            riskyEnvironmentPoints: 999, environmentObserved: true,
            hoursSinceLapse: 0, hoursSinceWetDream: 2
        )
        XCTAssertEqual(state.sleepRecovery, 40)
        XCTAssertEqual(state.explicitContent, 25)
        XCTAssertEqual(state.riskyEnvironment, 20)
        XCTAssertEqual(state.postReleaseRebound, 15)
        XCTAssertEqual(state.score, 100)
    }

    func testLapseReboundDecaysOver48Hours() {
        let now = v29UrgeRiskState(
            sleepScoresTodayFirst: [], access: nil, riskyEnvironmentPoints: 0,
            environmentObserved: false, hoursSinceLapse: 0, hoursSinceWetDream: nil
        )
        let halfway = v29UrgeRiskState(
            sleepScoresTodayFirst: [], access: nil, riskyEnvironmentPoints: 0,
            environmentObserved: false, hoursSinceLapse: 24, hoursSinceWetDream: nil
        )
        let ended = v29UrgeRiskState(
            sleepScoresTodayFirst: [], access: nil, riskyEnvironmentPoints: 0,
            environmentObserved: false, hoursSinceLapse: 48, hoursSinceWetDream: nil
        )
        XCTAssertEqual(now.postReleaseRebound, 15, accuracy: 0.001)
        XCTAssertEqual(halfway.postReleaseRebound, 7.5, accuracy: 0.001)
        XCTAssertEqual(ended.postReleaseRebound, 0, accuracy: 0.001)
    }

    func testWetDreamIsDelayedAndMilderAndDoesNotStack() {
        let early = v29UrgeRiskState(
            sleepScoresTodayFirst: [], access: nil, riskyEnvironmentPoints: 0,
            environmentObserved: false, hoursSinceLapse: nil, hoursSinceWetDream: 1.9
        )
        let active = v29UrgeRiskState(
            sleepScoresTodayFirst: [], access: nil, riskyEnvironmentPoints: 0,
            environmentObserved: false, hoursSinceLapse: 20, hoursSinceWetDream: 2
        )
        XCTAssertEqual(early.postReleaseRebound, 0)
        XCTAssertEqual(active.postReleaseRebound, 8.75, accuracy: 0.001, "Uses the larger lapse estimate, not 8.75 + 6")

        let rising = v29UrgeRiskState(
            sleepScoresTodayFirst: [], access: nil, riskyEnvironmentPoints: 0,
            environmentObserved: false, hoursSinceLapse: nil, hoursSinceWetDream: 7
        )
        let peak = v29UrgeRiskState(
            sleepScoresTodayFirst: [], access: nil, riskyEnvironmentPoints: 0,
            environmentObserved: false, hoursSinceLapse: nil, hoursSinceWetDream: 12
        )
        let clearing = v29UrgeRiskState(
            sleepScoresTodayFirst: [], access: nil, riskyEnvironmentPoints: 0,
            environmentObserved: false, hoursSinceLapse: nil, hoursSinceWetDream: 30
        )
        XCTAssertEqual(rising.postReleaseRebound, 3, accuracy: 0.001)
        XCTAssertEqual(peak.postReleaseRebound, 6, accuracy: 0.001)
        XCTAssertEqual(clearing.postReleaseRebound, 3, accuracy: 0.001)
    }

    func testMissingInputsStayVisibleAsMissingCoverage() {
        let state = v29UrgeRiskState(
            sleepScoresTodayFirst: [], access: nil, riskyEnvironmentPoints: 0,
            environmentObserved: false, hoursSinceLapse: nil, hoursSinceWetDream: nil
        )
        XCTAssertEqual(state.score, 0)
        XCTAssertEqual(state.dataCoverage, 0.15, accuracy: 0.001, "Only explicit release-event absence is observed")
    }

    func testWholeScorePersistenceCannotEscalateAlertTier() {
        let thresholds = PressureThresholds(watch: 55, warning: 65, emergency: 78)
        XCTAssertEqual(v29RiskTier(score: 55, thresholds: thresholds), .watch)
        XCTAssertEqual(v29RiskTier(score: 64, thresholds: thresholds), .watch)
        XCTAssertEqual(v29RiskTier(score: 65, thresholds: thresholds), .warning)
        XCTAssertEqual(v29RiskTier(score: 78, thresholds: thresholds), .emergency)
    }
}

final class V29SexualVigourTests: XCTestCase {
    private func observation(
        _ day: Int,
        erection: MorningErectionObservation,
        ehs: Int?,
        desire: Int?
    ) -> DailySexualObservation {
        DailySexualObservation(
            ts: Double(day),
            dayKey: "2026-08-\(String(format: "%02d", day))",
            morningErection: erection,
            erectionHardnessScore: ehs,
            healthyDesire: desire
        )
    }

    func testMinimumCoverageKeepsOverallVigourMissing() {
        let rows = [
            observation(1, erection: .yes, ehs: 4, desire: 8),
            observation(2, erection: .yes, ehs: 4, desire: 8),
            observation(3, erection: .yes, ehs: 4, desire: 8)
        ]
        let state = v29SexualVigourState(
            observations: rows,
            dayKeys: Set(rows.map(\.dayKey))
        )
        XCTAssertNil(state.score)
        XCTAssertEqual(state.erectionHealth, 100)
        XCTAssertEqual(state.healthyDesire, 80)
    }

    func testOutputOnlyFormulaIsSixtyForty() throws {
        let rows = [
            observation(1, erection: .yes, ehs: 4, desire: 5),
            observation(2, erection: .yes, ehs: 4, desire: 5),
            observation(3, erection: .yes, ehs: 4, desire: 5),
            observation(4, erection: .yes, ehs: 4, desire: 5)
        ]
        let state = v29SexualVigourState(observations: rows, dayKeys: Set(rows.map(\.dayKey)))
        XCTAssertEqual(try XCTUnwrap(state.score), 80, accuracy: 0.001)
    }

    func testNotObservedDoesNotBecomeNo() {
        let rows = [
            observation(1, erection: .yes, ehs: 4, desire: 5),
            observation(2, erection: .notObserved, ehs: nil, desire: 5)
        ]
        let state = v29SexualVigourState(
            observations: rows, dayKeys: Set(rows.map(\.dayKey)), minimumDaysPerComponent: 1
        )
        XCTAssertEqual(state.erectionDays, 1)
        XCTAssertEqual(state.erectionHealth, 100)
    }

    func testLegacyQualityAndLibidoRemainUsableWithoutRewrite() throws {
        let row = DailySexualObservation(
            ts: 1, dayKey: "2026-08-01", morningErection: .yes, erectionQuality: 7
        )
        let spot = LibidoSpot(ts: 1, dayKey: "2026-08-01", rating: 6)
        let state = v29SexualVigourState(
            observations: [row], legacyLibidoSpots: [spot],
            dayKeys: ["2026-08-01"], minimumDaysPerComponent: 1
        )
        XCTAssertEqual(try XCTUnwrap(state.erectionHealth), 85, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(state.healthyDesire), 60, accuracy: 0.001)
    }
}

final class V29RoutineAndProgressionTests: XCTestCase {
    private let fullRecovery = RecoveryCompositeState(
        score: 80, sleep: 80, hrv: 80, restingHeartRate: 80, trainingBalance: 80, dataCoverage: 1
    )

    func testExerciseMinutesAreOneCumulativeWeeklyTotal() throws {
        var rows: [(key: String, day: DayRecord)] = []
        for index in 1...7 {
            var day = DayRecord()
            day.aerobicMinutes = index <= 4 ? 20 : nil
            day.vigorousMinutes = index == 4 ? 20 : nil
            rows.append(("d\(index)", day))
        }
        let state = v29VigourRoutineState(
            daysByKey: rows,
            manualExerciseLogs: [],
            recovery: fullRecovery,
            cardioTarget: 160,
            strengthTarget: 3
        )
        XCTAssertEqual(state.weeklyModerateEquivalentMinutes, 100, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(state.cardio), 62.5, accuracy: 0.001)
    }

    func testManualCardioOverridesRatherThanAddsToHealth() {
        var day = DayRecord()
        day.aerobicMinutes = 60
        day.vigorousMinutes = 20
        let manual = ManualExerciseLog(
            dayKey: "d1", aerobicMinutesOverride: 30, vigorousMinutesOverride: 0
        )
        let state = v29VigourRoutineState(
            daysByKey: [("d1", day)], manualExerciseLogs: [manual],
            recovery: fullRecovery, cardioTarget: 160, strengthTarget: 3
        )
        XCTAssertEqual(state.weeklyModerateEquivalentMinutes, 30)
    }

    func testStrengthIsManualFirstAndCappedAtThreeSessions() {
        let rows = (1...7).map { ("d\($0)", DayRecord()) }
        let logs = (1...5).map { ManualExerciseLog(dayKey: "d\($0)", strengthSessionCompleted: true) }
        let state = v29VigourRoutineState(
            daysByKey: rows, manualExerciseLogs: logs, recovery: fullRecovery,
            cardioTarget: 160, strengthTarget: 3
        )
        XCTAssertEqual(state.weeklyStrengthSessions, 5)
        XCTAssertEqual(state.strength, 100)
    }

    func testRoutineUsesFortyThirtyTwentyTenWeights() throws {
        var cardio = DayRecord()
        cardio.aerobicMinutes = 160
        cardio.completionStates["heartHealthyEating"] = CompletionRecord(state: .done)
        let strength = ManualExerciseLog(dayKey: "d1", strengthSessionCompleted: true)
        let state = v29VigourRoutineState(
            daysByKey: [("d1", cardio)], manualExerciseLogs: [strength],
            recovery: RecoveryCompositeState(
                score: 50, sleep: nil, hrv: nil, restingHeartRate: nil,
                trainingBalance: nil, dataCoverage: 0.5
            ),
            cardioTarget: 160, strengthTarget: 2
        )
        // 100×.40 + 50×.30 + 100×.20 + 50×.10
        XCTAssertEqual(try XCTUnwrap(state.score), 80, accuracy: 0.001)
    }

    func testCalibrationNeverAutoProgresses() {
        let routine = VigourRoutineState(
            cardio: 100, recovery: 90, foodPlan: 100, strength: 100,
            weeklyModerateEquivalentMinutes: 160, weeklyStrengthSessions: 3
        )
        let recommendation = v29ExerciseDecision(
            weeksSincePlanStart: 1,
            routine: routine,
            recovery: fullRecovery,
            erectionChangeFrom28DayBaseline: 10
        )
        XCTAssertEqual(recommendation.decision, .hold)
    }

    func testLowRecoveryRecommendsRecover() {
        let routine = VigourRoutineState(
            cardio: 100, recovery: 40, foodPlan: 100, strength: 100,
            weeklyModerateEquivalentMinutes: 160, weeklyStrengthSessions: 3
        )
        let recovery = RecoveryCompositeState(
            score: 40, sleep: 40, hrv: 40, restingHeartRate: 40, trainingBalance: 40, dataCoverage: 1
        )
        XCTAssertEqual(v29ExerciseDecision(
            weeksSincePlanStart: 3,
            routine: routine,
            recovery: recovery,
            erectionChangeFrom28DayBaseline: nil
        ).decision, .recover)
    }

    func testTwelveWeekGateRequiresAndUsesErectionOutcome() {
        let routine = VigourRoutineState(
            cardio: 100, recovery: 90, foodPlan: 100, strength: 100,
            weeklyModerateEquivalentMinutes: 160, weeklyStrengthSessions: 3
        )
        XCTAssertEqual(v29ExerciseDecision(
            weeksSincePlanStart: 11,
            routine: routine,
            recovery: fullRecovery,
            erectionChangeFrom28DayBaseline: 10
        ).decision, .hold, "Week 12 is the recurring six-week consolidation week")
        XCTAssertEqual(v29ExerciseDecision(
            weeksSincePlanStart: 12,
            routine: routine,
            recovery: fullRecovery,
            erectionChangeFrom28DayBaseline: nil
        ).decision, .hold)
        XCTAssertEqual(v29ExerciseDecision(
            weeksSincePlanStart: 12,
            routine: routine,
            recovery: fullRecovery,
            erectionChangeFrom28DayBaseline: 4
        ).decision, .hold)
        XCTAssertEqual(v29ExerciseDecision(
            weeksSincePlanStart: 12,
            routine: routine,
            recovery: fullRecovery,
            erectionChangeFrom28DayBaseline: 5
        ).decision, .progress)
    }

    func testAcceptedDecisionCreatesNewVersionWithoutMutatingOriginal() {
        let original = V29Defaults.exercisePlan
        XCTAssertEqual(
            v29PlanVersion(from: original, applying: .progress, startDayKey: "2026-09-12"),
            original,
            "Progress without a human-selected focus must not invent a plan version"
        )
        let next = v29PlanVersion(
            from: original,
            applying: .progress,
            startDayKey: "2026-09-12",
            progressionFocus: .boxingRound
        )
        XCTAssertNotEqual(next.id, original.id)
        XCTAssertEqual(next.versionNumber, original.versionNumber + 1)
        XCTAssertEqual(original.phase, .calibration)
        XCTAssertEqual(next.phase, .build)
        XCTAssertEqual(next.programStartDayKey, original.programStartDayKey)
        XCTAssertEqual(original.boxingRounds, 10)
        XCTAssertEqual(next.boxingRounds, 11)
        XCTAssertEqual(next.lastProgressionFocus, .boxingRound)
        XCTAssertTrue(next.days.first(where: { $0.kind == .boxing })?.prescription.contains(where: {
            $0.contains("11 rounds")
        }) == true)

        let consolidation = v29PlanVersion(
            from: next,
            applying: .hold,
            startDayKey: "2026-10-10",
            phaseOverride: .consolidate
        )
        XCTAssertEqual(consolidation.phase, .consolidate)
        XCTAssertEqual(consolidation.programStartDayKey, original.programStartDayKey)
    }
}
