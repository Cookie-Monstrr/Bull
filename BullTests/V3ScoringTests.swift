import XCTest
@testable import Bull

final class V3ScoringTests: XCTestCase {
    private let tz = TimeZone(identifier: "Europe/London")!

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testVigourBalancesBucketsBeforeItems() {
        let items = [
            Item(id: "h1", label: "Heart 1", list: .prime, kind: .habit, weight: .vhigh, bucket: .heart, freq: .daily),
            Item(id: "h2", label: "Heart 2", list: .prime, kind: .habit, weight: .vhigh, bucket: .heart, freq: .daily),
            Item(id: "p1", label: "Pelvic", list: .prime, kind: .habit, weight: .vhigh, bucket: .pelvic, freq: .daily)
        ]
        let day = DayRecord(checks: ["h1": false, "h2": false, "p1": true])
        let result = vigourForDay(day: day, date: date(2026, 8, 22), items: items,
                                  settings: Settings(supplements: [], sleepWeight: .low, recoveryWeight: .low),
                                  calendars: ScoringCalendars(timeZone: tz))
        XCTAssertEqual(result.total, 8, accuracy: 0.0001)
        XCTAssertEqual(result.done, 4, accuracy: 0.0001)
        XCTAssertEqual(result.percent, 50, accuracy: 0.0001)
    }

    func testTwoVeryHighItemsInDifferentBucketsEachRepresentHalfWhenTheyAreTheOnlyComponents() {
        let items = [
            Item(id: "hiit", label: "HIIT", list: .prime, kind: .habit, weight: .vhigh, bucket: .heart, freq: .daily),
            Item(id: "kegel", label: "Kegel", list: .prime, kind: .habit, weight: .vhigh, bucket: .pelvic, freq: .daily)
        ]
        let oneDone = DayRecord(checks: ["hiit": true, "kegel": false])
        let result = vigourForDay(day: oneDone, date: date(2026, 8, 22), items: items,
                                  settings: Settings(supplements: []), calendars: ScoringCalendars(timeZone: tz))
        XCTAssertEqual(result.percent, 50, accuracy: 0.0001)
    }

    func testRiskCapsCorrelatedPhysiologyButDistinctExposureStillStacks() {
        let physiology = (1...4).map {
            Item(id: "phys\($0)", label: "P\($0)", list: .prev, kind: .risk,
                 weight: .vhigh, riskDomain: .physiology, freq: .daily)
        }
        let exposure = Item(id: "exp", label: "Exposure", list: .prev, kind: .risk,
                            weight: .vhigh, riskDomain: .exposure, freq: .daily)
        var checks = Dictionary(uniqueKeysWithValues: physiology.map { ($0.id, true) })
        checks[exposure.id] = true
        let breakdown = riskBreakdown(day: DayRecord(checks: checks), items: physiology + [exposure])
        XCTAssertEqual(breakdown.rawDomains[.physiology], 120)
        XCTAssertEqual(breakdown.cappedDomains[.physiology], 25)
        XCTAssertEqual(breakdown.cappedDomains[.exposure], 30)
        XCTAssertEqual(breakdown.total, 70)
    }

    func testPressureCompoundsConsecutiveHighDays() {
        let state = bullPressureState(todayRisk: 80, todayVigour: 30, recentDailyPressures: [75, 75])
        XCTAssertGreaterThan(state.compounded, state.daily)
        XCTAssertEqual(state.consecutiveHighDays, 3)
        XCTAssertGreaterThanOrEqual(state.tier, .warning)
    }


    func testPressureHonorsCustomEmergencyThreshold() {
        let thresholds = PressureThresholds(watch: 50, warning: 60, emergency: 70, warningDays: 2, emergencyDays: 3)
        let state = bullPressureState(
            todayRisk: 90, todayVigour: 40, recentDailyPressures: [], thresholds: thresholds
        )
        XCTAssertGreaterThanOrEqual(state.daily, 70)
        XCTAssertEqual(state.tier, .emergency)
    }

    func testWarningRequiresConfiguredPersistence() {
        let thresholds = PressureThresholds(watch: 50, warning: 60, emergency: 95, warningDays: 2, emergencyDays: 3)
        let first = bullPressureState(
            todayRisk: 80, todayVigour: 40, recentDailyPressures: [], thresholds: thresholds
        )
        XCTAssertEqual(first.tier, .watch)

        let second = bullPressureState(
            todayRisk: 80, todayVigour: 40, recentDailyPressures: [70], thresholds: thresholds
        )
        XCTAssertGreaterThanOrEqual(second.consecutiveHighDays, 2)
        XCTAssertEqual(second.tier, .warning)
    }

    func testLowPressureDayBreaksCarryover() {
        XCTAssertEqual(compoundedBullPressure(today: 75, recentDailyPressures: [40, 95]), 75, accuracy: 0.0001)
    }

    func testFastingNotExpectedOutsideConfiguredLunarDays() {
        let calendars = ScoringCalendars(timeZone: tz)
        let fasting = DefaultItems.all.first { $0.id == "fasting" }!
        let d = date(2026, 8, 22)
        XCTAssertFalse(fastingSuggested(d, mode: .lunar, calendars: calendars))
        XCTAssertFalse(adherenceExpected(fasting, on: d, settings: Settings(fastMode: .lunar), calendars: calendars))
    }
}
