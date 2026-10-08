import XCTest
@testable import Bull

final class V27ScoringTests: XCTestCase {
    func testCompoundedRiskUsesOnlyBaseRiskHistoryAndProtection() {
        let state = compoundedRiskState(
            baseRisk: 70,
            recentBaseRisks: [80, 70],
            activeProtection: 5
        )

        XCTAssertEqual(state.carryover, 15, accuracy: 0.0001)
        XCTAssertEqual(state.protection, 5, accuracy: 0.0001)
        XCTAssertEqual(state.currentRisk, 80)
    }

    func testCompoundingCapsAndLowRiskDayBreaksChain() {
        let capped = compoundedRiskState(
            baseRisk: 95,
            recentBaseRisks: [100, 100, 100, 100],
            activeProtection: 40
        )
        XCTAssertEqual(capped.carryover, 20, accuracy: 0.0001)
        XCTAssertEqual(capped.protection, 15, accuracy: 0.0001)
        XCTAssertEqual(capped.currentRisk, 100)

        let broken = compoundedRiskState(
            baseRisk: 50,
            recentBaseRisks: [80, 20, 100],
            activeProtection: 0
        )
        XCTAssertEqual(broken.carryover, 10.5, accuracy: 0.0001)
        XCTAssertEqual(broken.currentRisk, 61)
    }

    func testProtectionRequiresCompletionAndObservedImprovementThenDecays() {
        let definition = ResponseDefinition(
            id: "response.test",
            name: "Test",
            protectionWeight: .high,
            protectionMinutes: 120
        )
        let improved = ResponseAttempt(
            responseID: definition.id,
            ts: 1_000,
            completedTs: 1_000,
            intensityBefore: .high,
            intensityAfter: .medium
        )
        let unchanged = ResponseAttempt(
            responseID: definition.id,
            ts: 1_000,
            completedTs: 1_000,
            intensityBefore: .medium,
            intensityAfter: .medium,
            stressBefore: 5,
            stressAfter: 5
        )
        let incomplete = ResponseAttempt(
            responseID: definition.id,
            ts: 1_000,
            intensityBefore: .high,
            intensityAfter: .low
        )

        XCTAssertEqual(
            activeProtectionPoints(attempts: [improved, unchanged, incomplete], definitions: [definition], nowMS: 1_000),
            8,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            activeProtectionPoints(
                attempts: [improved], definitions: [definition],
                nowMS: 1_000 + 60 * 60 * 1_000
            ),
            4,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            activeProtectionPoints(
                attempts: [improved], definitions: [definition],
                nowMS: 1_000 + 120 * 60 * 1_000
            ),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            activeProtectionPoints(attempts: [improved], definitions: [definition], nowMS: 999),
            0,
            accuracy: 0.0001
        )
    }

    func testHRVUsesRelativePersonalBaselineAndCaps() {
        XCTAssertEqual(hrvRiskModifier(hrv: nil, baseline: 80), 0)
        XCTAssertEqual(hrvRiskModifier(hrv: 96, baseline: 80), -10)
        XCTAssertEqual(hrvRiskModifier(hrv: 64, baseline: 80), 10)
        XCTAssertEqual(hrvRiskModifier(hrv: 88, baseline: 80), -5)
    }

    func testWetDreamRiskRampsAfterWakeAndNeverExceedsHigh() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 15)))
        let wake = try XCTUnwrap(calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day))
        let before = try XCTUnwrap(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day))
        let middle = try XCTUnwrap(calendar.date(bySettingHour: 14, minute: 0, second: 0, of: day))
        let late = try XCTUnwrap(calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day))

        XCTAssertEqual(wetDreamRiskModifier(
            now: before, hadWetDreamOnWakingDay: true,
            wakeTimestampMS: wake.timeIntervalSince1970 * 1_000,
            calendar: calendar
        ), 0)
        let middleValue = wetDreamRiskModifier(
            now: middle, hadWetDreamOnWakingDay: true,
            wakeTimestampMS: wake.timeIntervalSince1970 * 1_000,
            calendar: calendar
        )
        let lateValue = wetDreamRiskModifier(
            now: late, hadWetDreamOnWakingDay: true,
            wakeTimestampMS: wake.timeIntervalSince1970 * 1_000,
            calendar: calendar
        )
        XCTAssertGreaterThan(middleValue, 0)
        XCTAssertGreaterThan(lateValue, middleValue)
        XCTAssertLessThanOrEqual(lateValue, Weight.high.riskPoints)
        XCTAssertEqual(wetDreamRiskModifier(
            now: late, hadWetDreamOnWakingDay: false,
            wakeTimestampMS: wake.timeIntervalSince1970 * 1_000,
            calendar: calendar
        ), 0)
    }

    func testOvernightZoneUsesTheStartDaysSchedule() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        // 2026-01-05 is Monday. Bull uses 1 for Monday.
        let zone = HighRiskZone(
            name: "Test",
            latitude: 0,
            longitude: 0,
            activeDays: [1],
            startMinute: 22 * 60,
            endMinute: 2 * 60
        )
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 5)))
        let monday2300 = try XCTUnwrap(calendar.date(bySettingHour: 23, minute: 0, second: 0, of: monday))
        let tuesday0100 = try XCTUnwrap(calendar.date(byAdding: .hour, value: 2, to: monday2300))
        let tuesday0300 = try XCTUnwrap(calendar.date(byAdding: .hour, value: 4, to: monday2300))

        XCTAssertTrue(zone.isScheduled(at: monday2300, calendar: calendar))
        XCTAssertTrue(zone.isScheduled(at: tuesday0100, calendar: calendar))
        XCTAssertFalse(zone.isScheduled(at: tuesday0300, calendar: calendar))
    }

    func testBullStrengthIsIndependentOfRiskFields() {
        var days = Array(repeating: DayRecord(sleep: 80, heartHealthyEating: true), count: 7)
        days[0].aerobicMinutes = 150
        days[1].strengthMinutes = 20
        let baseline = v27VigourState(recentDays: days, latestCheckIn: nil)

        for index in days.indices {
            days[index].access = .high
            days[index].checkout = .lot
            days[index].stressLevel = 10
        }
        let exposed = v27VigourState(recentDays: days, latestCheckIn: nil)

        XCTAssertEqual(baseline, exposed)
        XCTAssertGreaterThan(baseline.bullStrength, 50)
    }

    func testLapsePolicyCountsSelectedComponentsButNeverWetDreams() {
        let policy = LapsePolicy(pornCounts: true, masturbationCounts: false, orgasmCounts: true)
        XCTAssertTrue(policy.counts([.porn]))
        XCTAssertFalse(policy.counts([.masturbation]))
        XCTAssertTrue(policy.counts([.masturbation, .orgasm]))
        XCTAssertFalse(policy.counts([]))
    }

    func testLegacyPlanWithoutTriggerIDDecodesForMigration() throws {
        let json = #"{"id":"plan-1","trigger":"Alone","action":"Leave","enabled":true,"rehearsed":false,"createdTs":1}"#.data(using: .utf8)!
        let plan = try JSONDecoder().decode(ImplementationPlan.self, from: json)
        XCTAssertEqual(plan.id, "plan-1")
        XCTAssertEqual(plan.trigger, "Alone")
        XCTAssertNil(plan.triggerID)
    }

    func testOldDayRecordDefaultsNewV27Fields() throws {
        let day = try JSONDecoder().decode(DayRecord.self, from: Data("{}".utf8))
        XCTAssertNil(day.sleepWakeTs)
        XCTAssertNil(day.aerobicMinutes)
        XCTAssertNil(day.heartHealthyEating)
        XCTAssertNil(day.stressLevel)
    }
}
