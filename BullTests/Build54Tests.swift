import XCTest
@testable import Bull

final class Build54FigureAndRoutingTests: XCTestCase {
    func testFigureBandsAreSteepAndMonotonic() {
        XCTAssertEqual(BullFigureScore.stage(for: 0), 1)
        XCTAssertEqual(BullFigureScore.stage(for: 39.99), 1)
        XCTAssertEqual(BullFigureScore.stage(for: 40), 2)
        XCTAssertEqual(BullFigureScore.stage(for: 59.99), 2)
        XCTAssertEqual(BullFigureScore.stage(for: 60), 3)
        XCTAssertEqual(BullFigureScore.stage(for: 74.99), 3)
        XCTAssertEqual(BullFigureScore.stage(for: 75), 4)
        XCTAssertEqual(BullFigureScore.stage(for: 89.99), 4)
        XCTAssertEqual(BullFigureScore.stage(for: 90), 5)
        XCTAssertEqual(BullFigureScore.stage(for: 100), 5)
    }

    func testSorcererAssetLookupNowMatchesVisibleProgression() {
        XCTAssertEqual(
            BullFigureCharacter.angel.assetName(stage: 1),
            "bull-figure-angel-5"
        )
        XCTAssertEqual(
            BullFigureCharacter.angel.assetName(stage: 5),
            "bull-figure-angel-1"
        )
        XCTAssertEqual(BullFigureCharacter.angel.title, "Urge Fuel")
    }

    func testDailyInputRouteRoundTrips() throws {
        let route = BullDailyInputKind.urgeCheckIn.routeValue(dayKey: "2026-09-15")
        let parsed = try XCTUnwrap(BullDailyInputKind.parse(route: route))
        XCTAssertEqual(parsed.kind.rawValue, BullDailyInputKind.urgeCheckIn.rawValue)
        XCTAssertEqual(parsed.dayKey, "2026-09-15")
        switch parsed.kind.entryKind {
        case .urge: break
        default: XCTFail("Urge check-in should open the Urge editor")
        }
    }

    func testMalformedDailyInputRouteIsIgnored() {
        XCTAssertNil(BullDailyInputKind.parse(route: "bull://input/urgeCheckIn/not-a-date"))
        XCTAssertNil(BullDailyInputKind.parse(route: "bull://input/unknown/2026-09-15"))
    }
}
