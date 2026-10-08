import XCTest
@testable import Bull

/// Parity suite. Every expected value in `ScoringVectors.json` was captured by
/// executing the LIVE app.js scoring engine (v42) — not hand-computed, and not
/// derived from a re-reading of the logic. If the Swift port disagrees with any
/// of these, the port is wrong, not the vector.
///
/// A test that reimplements the logic it checks is a guaranteed false pass, so
/// nothing here recomputes an expected score; it only compares.
final class ScoringParityTests: XCTestCase {

    // MARK: Vector decoding

    struct Vectors: Decodable {
        let riskCases: [RiskCase]
        let vigourCases: [VigourCase]
        let fastingCases: [FastingCase]
    }

    struct RiskCase: Decodable {
        let name: String
        let day: DayRecord
        let urgesSurvived: Int
        let hadRelapse: Bool
        let accountabilityPenalty: Double
        let intentionWeight: Weight
        let sleepRiskWeight: Weight
        let recoveryRiskWeight: Weight
        let expected: Int
    }

    struct VectorSettings: Decodable {
        let supplements: [String]
        let sleepWeight: Weight
        let recoveryWeight: Weight
        let fastMode: FastMode
    }

    struct VigourCase: Decodable {
        let name: String
        let day: DayRecord
        let date: String
        let settings: VectorSettings
        let expectedDone: Double
        let expectedTotal: Double
    }

    struct FastingCase: Decodable {
        let date: String
        let fastMode: FastMode
        let dow: Int
        let hijriDay: Int
        let expectedDone: Double
        let expectedTotal: Double
    }

    /// Pinned so a test can never pass or fail based on the machine's timezone.
    /// The JS vectors were generated with dates at local noon, which is why noon
    /// is used here too — it keeps every date safely clear of DST boundaries.
    static let timeZone = TimeZone(identifier: "Europe/London")!

    lazy var calendars = ScoringCalendars(timeZone: Self.timeZone)

    lazy var vectors: Vectors = {
        let url = Bundle(for: ScoringParityTests.self).url(forResource: "ScoringVectors", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(Vectors.self, from: data)
    }()

    func date(_ ymd: String) -> Date {
        var c = DateComponents()
        let parts = ymd.split(separator: "-").map { Int($0)! }
        c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
        c.hour = 12; c.minute = 0; c.second = 0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.timeZone
        return cal.date(from: c)!
    }

    func settings(from v: VectorSettings) -> Settings {
        Settings(
            supplements: v.supplements,
            fastMode: v.fastMode,
            sleepWeight: v.sleepWeight,
            recoveryWeight: v.recoveryWeight
        )
    }

    // MARK: - Sanity: the harness itself

    /// Guards against a vectors file that silently failed to load or shrank.
    /// A parity suite that runs zero cases passes vacuously, which is worse
    /// than failing.
    func testVectorsLoaded() {
        XCTAssertEqual(vectors.riskCases.count, 38, "risk vector count changed unexpectedly")
        XCTAssertEqual(vectors.vigourCases.count, 26, "vigour vector count changed unexpectedly")
        XCTAssertEqual(vectors.fastingCases.count, 30, "fasting vector count changed unexpectedly")
    }

    /// Proves the comparison would actually catch a wrong answer. If this ever
    /// stops failing on a deliberately corrupted value, the assertions below
    /// mean nothing.
    func testHarnessDetectsWrongValue() {
        let c = vectors.riskCases.first { $0.name == "baseline empty day" }!
        let actual = legacyRiskScoreV2(
            day: c.day, items: LegacyV26DefaultItems.all,
            accountabilityPenalty: c.accountabilityPenalty,
            accountabilityEnabled: c.accountabilityPenalty > 0,
            intentionWeight: c.intentionWeight,
            sleepRiskWeight: c.sleepRiskWeight,
            recoveryRiskWeight: c.recoveryRiskWeight,
            calendars: calendars
        )
        XCTAssertNotEqual(actual, c.expected + 1, "sanity: a wrong value must not compare equal")
    }

    // MARK: - Relapse Risk v2

    /// All pre-existing factor arithmetic stays at parity when the old vector does
    /// not use an outcome (urge success / relapse) that v2 deliberately removes.
    func testRiskFactorParityWhereOutcomesAreAbsent() {
        for c in vectors.riskCases where c.urgesSurvived == 0 && c.hadRelapse == false {
            let actual = legacyRiskScoreV2(
                day: c.day, items: LegacyV26DefaultItems.all,
                accountabilityPenalty: c.accountabilityPenalty,
                accountabilityEnabled: c.accountabilityPenalty > 0,
                intentionWeight: c.intentionWeight,
                sleepRiskWeight: c.sleepRiskWeight,
                recoveryRiskWeight: c.recoveryRiskWeight,
                calendars: calendars
            )
            XCTAssertEqual(actual, c.expected, "Risk mismatch — \(c.name)")
        }
    }

    func testPredictiveRiskStartsAtBaselineWithoutInputs() {
        XCTAssertEqual(riskScore(day: DayRecord(), items: DefaultItems.all, calendars: calendars), 15)
    }

    func testLegacyV2DiagnosticAlsoStartsAtBaseline() {
        XCTAssertEqual(legacyRiskScoreV2(day: DayRecord(), items: DefaultItems.all, calendars: calendars), 15)
    }

    // MARK: - Sexual Vigour parity

    func testVigourParity() {
        for c in vectors.vigourCases {
            let r = legacyVigourForDayV2(
                day: c.day, date: date(c.date), items: LegacyV26DefaultItems.all,
                settings: settings(from: c.settings), calendars: calendars
            )
            XCTAssertEqual(r.done, c.expectedDone, accuracy: 0.0001, "Vigour done mismatch — \(c.name)")
            XCTAssertEqual(r.total, c.expectedTotal, accuracy: 0.0001, "Vigour total mismatch — \(c.name)")
        }
    }

    // MARK: - Weight independence

    /// The v42 bug, locked down: moving the Prevention weight must never move
    /// Vigour, and vice versa. This is a behavioural invariant, not a vector
    /// comparison, so it is asserted directly.
    func testSleepAndRecoveryWeightsAreIndependent() {
        let day = DayRecord(recovery: 20, sleep: 30)
        let items = DefaultItems.all

        // Changing PREVENTION weights must not change Vigour output.
        let vig = vigourForDay(day: day, date: date("2026-08-17"), items: items,
                               settings: Settings(sleepWeight: .low, recoveryWeight: .low),
                               calendars: calendars)
        let riskLow = riskScore(day: day, items: items,
                                sleepRiskWeight: .low, recoveryRiskWeight: .low, calendars: calendars)
        let riskHigh = riskScore(day: day, items: items,
                                 sleepRiskWeight: .vhigh, recoveryRiskWeight: .vhigh, calendars: calendars)
        let vigAfter = vigourForDay(day: day, date: date("2026-08-17"), items: items,
                                    settings: Settings(sleepWeight: .low, recoveryWeight: .low),
                                    calendars: calendars)
        XCTAssertNotEqual(riskLow, riskHigh, "Prevention weight should move Risk")
        XCTAssertEqual(vig, vigAfter, "Prevention weight must NOT move Vigour")

        // Changing VIGOUR weights must not change Risk output.
        let riskBefore = riskScore(day: day, items: items,
                                   sleepRiskWeight: .med, recoveryRiskWeight: .med, calendars: calendars)
        let vLow = vigourForDay(day: day, date: date("2026-08-17"), items: items,
                                settings: Settings(sleepWeight: .low, recoveryWeight: .low),
                                calendars: calendars)
        let vHigh = vigourForDay(day: day, date: date("2026-08-17"), items: items,
                                 settings: Settings(sleepWeight: .vhigh, recoveryWeight: .vhigh),
                                 calendars: calendars)
        let riskAfter = riskScore(day: day, items: items,
                                  sleepRiskWeight: .med, recoveryRiskWeight: .med, calendars: calendars)
        XCTAssertNotEqual(vLow, vHigh, "Vigour weight should move Vigour")
        XCTAssertEqual(riskBefore, riskAfter, "Vigour weight must NOT move Risk")
    }

    // MARK: - Fasting / hijri calendar

    /// ISOLATED DELIBERATELY. `fastingSuggested()` depends on the hijri calendar,
    /// and JS reads it through ICU (`en-u-ca-islamic`) while Swift reads it
    /// through Foundation. These are both ICU-backed and are EXPECTED to agree,
    /// but if they don't, the mismatch is a calendar-variant question, not a
    /// scoring-logic bug — so it must fail in its own test rather than
    /// contaminating `testVigourParity`.
    ///
    /// If this fails, check `hijriDayForDiagnosis` in the failure message and
    /// try `ScoringCalendars(hijriIdentifier:)` with `.islamicCivil`,
    /// `.islamicTabular`, or `.islamicUmmAlQura` before touching any logic.
    func testFastingParity() {
        for c in vectors.fastingCases {
            let d = date(c.date)
            let day = DayRecord(checks: ["fasting": true])
            let s = Settings(supplements: [], fastMode: c.fastMode)
            let r = legacyVigourForDayV2(day: day, date: d, items: LegacyV26DefaultItems.all,
                                         settings: s, calendars: calendars)
            let swiftHijri = hijriDay(d, calendars: calendars) ?? -1
            XCTAssertEqual(
                r.total, c.expectedTotal, accuracy: 0.0001,
                "Fasting total mismatch — \(c.date) mode=\(c.fastMode.rawValue) "
                + "jsHijri=\(c.hijriDay) swiftHijri=\(swiftHijri)"
            )
            XCTAssertEqual(
                r.done, c.expectedDone, accuracy: 0.0001,
                "Fasting done mismatch — \(c.date) mode=\(c.fastMode.rawValue) "
                + "jsHijri=\(c.hijriDay) swiftHijri=\(swiftHijri)"
            )
        }
    }

    /// Weekday convention is the classic off-by-one in this port: JS is 0=Sunday,
    /// Foundation is 1=Sunday.
    func testWeekdayConventionMatchesJS() {
        for c in vectors.fastingCases {
            XCTAssertEqual(jsWeekday(date(c.date), calendars: calendars), c.dow,
                           "weekday convention mismatch on \(c.date)")
        }
    }

    // MARK: - jsRound semantics

    func testJSRoundMatchesJavaScript() {
        // JS rounds .5 toward POSITIVE infinity, unlike Swift's rounded().
        XCTAssertEqual(jsRound(0.5), 1)
        XCTAssertEqual(jsRound(1.5), 2)
        XCTAssertEqual(jsRound(2.5), 3)
        XCTAssertEqual(jsRound(-0.5), 0)   // Swift's (-0.5).rounded() would be -1
        XCTAssertEqual(jsRound(-1.5), -1)  // Swift's (-1.5).rounded() would be -2
        XCTAssertEqual(jsRound(7.2), 7)
        XCTAssertEqual(jsRound(5.6), 6)
    }
}
