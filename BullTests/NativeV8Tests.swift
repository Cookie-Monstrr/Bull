import XCTest
@testable import Bull

final class NativeV8Tests: XCTestCase {
    func testFullIntentionShapeRoundTrips() throws {
        let d = DayRecord(intentions: [
            Intention(id: "i1", text: "Work in library", when: "After Dhuhr", whereText: "Library", met: true, repeatDaily: true)
        ])
        let data = BullData(days: ["2026-08-21": d])
        let raw = try BackupImporter.exportData(data)
        let decoded = try JSONDecoder().decode(BullData.self, from: raw)
        let i = try XCTUnwrap(decoded.days["2026-08-21"]?.intentions.first)
        XCTAssertEqual(i.id, "i1")
        XCTAssertEqual(i.text, "Work in library")
        XCTAssertEqual(i.when, "After Dhuhr")
        XCTAssertEqual(i.whereText, "Library")
        XCTAssertTrue(i.met)
        XCTAssertTrue(i.repeatDaily)
    }

    func testNativePlansSnapshotsAndNextActionRoundTrip() throws {
        let plan = ImplementationPlan(id: "p1", trigger: "Home alone", action: "Go outside", enabled: true, rehearsed: true, createdTs: 1)
        let relapse = RelapseEvent(ts: 2, type: .edge, triggers: ["Tired"], nextAction: "Shower")
        let snap = ScoreSnapshot(risk: 32, vigour: 81, scoringVersion: 2, recordedTs: 3)
        let data = BullData(relapses: [relapse], plans: [plan], scoreSnapshots: ["2026-08-20": snap])
        let raw = try BackupImporter.exportData(data)
        let decoded = try JSONDecoder().decode(BullData.self, from: raw)
        XCTAssertEqual(decoded.plans, [plan])
        XCTAssertEqual(decoded.scoreSnapshots["2026-08-20"], snap)
        XCTAssertEqual(decoded.relapses.first?.nextAction, "Shower")
    }

    func testAccountabilityDefaultsOffForLegacySettings() throws {
        let raw = #"{"settings":{"purposeText":"x"},"days":{}}"#.data(using: .utf8)!
        let result = BackupImporter.importBackup(from: raw)
        guard case .success(let value) = result else { return XCTFail("import failed") }
        XCTAssertFalse(value.0.settings.accountabilityEnabled)
    }

    func testNativeImportReportCountsNativeCollections() throws {
        let data = BullData(
            plans: [ImplementationPlan(trigger: "A", action: "B")],
            scoreSnapshots: ["2026-08-20": ScoreSnapshot(risk: 20, vigour: 70)]
        )
        let raw = try BackupImporter.exportData(data)
        let result = BackupImporter.importBackup(from: raw)
        guard case .success(let value) = result else { return XCTFail("import failed") }
        XCTAssertEqual(value.1.plansImported, 1)
        XCTAssertEqual(value.1.scoreSnapshotsImported, 1)
    }
    func testNativeEventDayKeysRoundTrip() throws {
        let data = BullData(
            urges: [UrgeEvent(ts: 1, dayKey: "2026-08-21", triggers: ["Tired"])],
            relapses: [RelapseEvent(ts: 2, dayKey: "2026-08-20", type: .edge)],
            wetDreams: [WetDreamEvent(ts: 3, dayKey: "2026-08-19")]
        )
        let raw = try BackupImporter.exportData(data)
        let decoded = try JSONDecoder().decode(BullData.self, from: raw)
        XCTAssertEqual(decoded.urges.first?.dayKey, "2026-08-21")
        XCTAssertEqual(decoded.relapses.first?.dayKey, "2026-08-20")
        XCTAssertEqual(decoded.wetDreams.first?.dayKey, "2026-08-19")
    }

    func testLegacyEventsDecodeWithoutDayKeys() throws {
        let raw = #"{"settings":{},"urges":[{"ts":1}],"relapses":[{"ts":2,"type":"orgasm"}],"wetDreams":[{"ts":3}],"days":{}}"#.data(using: .utf8)!
        let result = BackupImporter.importBackup(from: raw)
        guard case .success(let value) = result else { return XCTFail("import failed") }
        XCTAssertNil(value.0.urges.first?.dayKey)
        XCTAssertNil(value.0.relapses.first?.dayKey)
        XCTAssertNil(value.0.wetDreams.first?.dayKey)
    }

    func testCountedCheckinRoundTripsAndDefaultsNil() throws {
        let settings = Settings(nextCheckin: 1234, countedCheckin: 1234, therapySessions: 7)
        let raw = try BackupImporter.exportData(BullData(settings: settings))
        let decoded = try JSONDecoder().decode(BullData.self, from: raw)
        XCTAssertEqual(decoded.settings.countedCheckin, 1234)
        XCTAssertEqual(decoded.settings.therapySessions, 7)

        let legacy = #"{"settings":{"nextCheckin":1234,"therapySessions":2},"days":{}}"#.data(using: .utf8)!
        let result = BackupImporter.importBackup(from: legacy)
        guard case .success(let value) = result else { return XCTFail("legacy import failed") }
        XCTAssertNil(value.0.settings.countedCheckin)
        XCTAssertEqual(value.0.settings.therapySessions, 2)
    }

    func testSleepAnalysisComponentsRoundTripAndLegacyDefaults() throws {
        let day = DayRecord(
            recovery: 44, recoveryScoreSource: BullRecoveryScore.sourceIdentifier,
            recoveryScoreVersion: BullRecoveryScore.sourceVersion, recoveryHRVBaseline: 50,
            sleep: 84, sleepHours: 7.6,
            sleepDurationPoints: 49, sleepConsistencyPoints: 22,
            sleepInterruptionsPoints: 13, sleepBedtimeDeviationMinutes: 52,
            sleepTotalAwakeMinutes: 62, sleepFajrWakeMinutes: 34,
            sleepAwakeMinutes: 28, sleepInterruptionCount: 3,
            sleepScoreSource: BullSleepScore.sourceIdentifier,
            sleepScoreVersion: BullSleepScore.sourceVersion, hrv: 47
        )
        let raw = try BackupImporter.exportData(BullData(days: ["2026-08-21": day]))
        let decoded = try JSONDecoder().decode(BullData.self, from: raw)
        let roundTrip = try XCTUnwrap(decoded.days["2026-08-21"])
        XCTAssertEqual(roundTrip.recovery, 44)
        XCTAssertEqual(roundTrip.recoveryScoreSource, "bull-hrv")
        XCTAssertEqual(roundTrip.recoveryScoreVersion, 1)
        XCTAssertEqual(roundTrip.recoveryHRVBaseline, 50)
        XCTAssertEqual(roundTrip.sleep, 84)
        XCTAssertEqual(roundTrip.sleepHours, 7.6)
        XCTAssertEqual(roundTrip.sleepDurationPoints, 49)
        XCTAssertEqual(roundTrip.sleepConsistencyPoints, 22)
        XCTAssertEqual(roundTrip.sleepInterruptionsPoints, 13)
        XCTAssertEqual(roundTrip.sleepBedtimeDeviationMinutes, 52)
        XCTAssertEqual(roundTrip.sleepTotalAwakeMinutes, 62)
        XCTAssertEqual(roundTrip.sleepFajrWakeMinutes, 34)
        XCTAssertEqual(roundTrip.sleepAwakeMinutes, 28)
        XCTAssertEqual(roundTrip.sleepInterruptionCount, 3)
        XCTAssertEqual(roundTrip.sleepScoreSource, "bull-fajr-aware")
        XCTAssertEqual(roundTrip.sleepScoreVersion, 2)

        let legacyRaw = #"{"settings":{},"days":{"2026-08-20":{"sleep":72,"sleepHours":6.8}}}"#.data(using: .utf8)!
        let result = BackupImporter.importBackup(from: legacyRaw)
        guard case .success(let value) = result else { return XCTFail("legacy import failed") }
        let legacyDay = try XCTUnwrap(value.0.days["2026-08-20"])
        XCTAssertEqual(legacyDay.sleep, 72)
        XCTAssertNil(legacyDay.sleepTotalAwakeMinutes)
        XCTAssertNil(legacyDay.sleepFajrWakeMinutes)
        XCTAssertNil(legacyDay.sleepAwakeMinutes)
        XCTAssertNil(legacyDay.sleepInterruptionCount)
        XCTAssertNil(legacyDay.sleepScoreSource)
        XCTAssertNil(legacyDay.sleepScoreVersion)
        XCTAssertNil(legacyDay.recoveryScoreSource)
        XCTAssertNil(legacyDay.recoveryScoreVersion)
        XCTAssertNil(legacyDay.recoveryHRVBaseline)
    }

    func testBullRecoveryScoreUsesPersonalHRVBaseline() throws {
        XCTAssertEqual(BullRecoveryScore.sourceIdentifier, "bull-hrv")
        XCTAssertEqual(BullRecoveryScore.sourceVersion, 1)
        XCTAssertEqual(try XCTUnwrap(BullRecoveryScore.score(hrv: 50, baseline: 50)), 70, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(BullRecoveryScore.score(hrv: 42.5, baseline: 50)), 40, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(BullRecoveryScore.score(hrv: 57.5, baseline: 50)), 100, accuracy: 0.001)
        XCTAssertNil(BullRecoveryScore.score(hrv: 0, baseline: 50))
        XCTAssertEqual(BullRecoveryScore.classification(39), "Suppressed")
        XCTAssertEqual(BullRecoveryScore.classification(70), "Normal")
    }

    func testBullSleepScoreFajrModelMetadata() {
        XCTAssertEqual(BullSleepScore.plannedFajrWakeAllowanceMinutes, 90)
        XCTAssertEqual(BullSleepScore.sourceIdentifier, "bull-fajr-aware")
        XCTAssertEqual(BullSleepScore.sourceVersion, 2)
    }

    func testBullSleepScoreDetectsLikelyFajrSplit() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func makeDate(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute))!
        }

        let intervals = [
            BullSleepInterval(start: makeDate(21, 22), end: makeDate(22, 4)),
            BullSleepInterval(start: makeDate(22, 4, 42), end: makeDate(22, 7, 5))
        ]
        let gap = try XCTUnwrap(BullSleepScore.likelyFajrGap(asleepIntervals: intervals, calendar: calendar))
        XCTAssertEqual(gap.minutes, 42, accuracy: 0.001)

        let daytimeSplit = [
            BullSleepInterval(start: makeDate(22, 10), end: makeDate(22, 12)),
            BullSleepInterval(start: makeDate(22, 12, 30), end: makeDate(22, 14))
        ]
        XCTAssertNil(BullSleepScore.likelyFajrGap(asleepIntervals: daytimeSplit, calendar: calendar))
    }

    func testBullSleepScoreExemptsOnlyFirstNinetyMinutesOfFajrGap() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func makeDate(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 22, hour: hour, minute: minute))!
        }

        let gap = BullSleepInterval(start: makeDate(4), end: makeDate(6))
        let adjusted = BullSleepScore.removingPlannedFajrAllowance(from: [gap], fajrGap: gap)
        XCTAssertEqual(adjusted.count, 1)
        XCTAssertEqual(adjusted[0].start, makeDate(5, 30))
        XCTAssertEqual(adjusted[0].end, makeDate(6))
        XCTAssertEqual(adjusted[0].minutes, 30, accuracy: 0.001)
    }

    func testBullSleepScoreUsesPublicComponentWeights() {
        XCTAssertEqual(BullSleepScore.durationPoints(hours: 8), 50, accuracy: 0.001)
        XCTAssertEqual(BullSleepScore.consistencyPoints(deviationMinutes: 0), 30, accuracy: 0.001)
        XCTAssertEqual(BullSleepScore.interruptionPoints(awakeMinutes: 0, interruptionCount: 0), 20, accuracy: 0.001)
        let perfect = BullSleepScore.total(
            hours: 8, bedtimeDeviationMinutes: 0, awakeMinutes: 0,
            interruptionCount: 0, hasEnoughBedtimeHistory: true
        )
        XCTAssertEqual(perfect.score, 100)
        XCTAssertEqual(BullSleepScore.classification(100), "Very High")
    }

    func testBullSleepScorePenalizesInconsistentInterruptedShortSleep() {
        let strong = BullSleepScore.total(
            hours: 8, bedtimeDeviationMinutes: 15, awakeMinutes: 8,
            interruptionCount: 1, hasEnoughBedtimeHistory: true
        )
        let weak = BullSleepScore.total(
            hours: 5.5, bedtimeDeviationMinutes: 120, awakeMinutes: 55,
            interruptionCount: 5, hasEnoughBedtimeHistory: true
        )
        XCTAssertGreaterThan(strong.score, weak.score)
        XCTAssertLessThan(weak.duration, strong.duration)
        XCTAssertLessThan(weak.consistency, strong.consistency)
        XCTAssertLessThan(weak.interruptions, strong.interruptions)
    }

}
