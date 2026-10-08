import Foundation
import XCTest
@testable import Bull

final class Build50FigureTests: XCTestCase {
    func testEveryBoundarySelectsTheExpectedStage() {
        let cases: [(Double, Int)] = [
            (-1, 1), (0, 1), (19.999, 1), (20, 2), (39.999, 2),
            (40, 3), (59.999, 3), (60, 4), (79.999, 4), (80, 5), (100, 5), (101, 5)
        ]
        for (value, expected) in cases {
            XCTAssertEqual(BullFigureScore.stage(for: value), expected, "Score \(value)")
        }
    }
    func testMissingAndNonFiniteScoresHaveNoCharacterStage() {
        for value: Double? in [nil, .nan, .infinity, -.infinity] {
            XCTAssertNil(BullFigureScore.stage(for: value))
            XCTAssertEqual(BullFigureScore.text(value), "—")
        }
    }
    func testAllTwentyNamesAreUnique() {
        let names = BullFigureCharacter.allCases.flatMap { character in
            (1...5).map { character.assetName(stage: $0) }
        }
        XCTAssertEqual(Set(names).count, 20)
    }
    func testOldTwoScorePayloadDecodesWithoutInventingRoutineScores() throws {
        let data = Data(#"{"bullState":68,"urgeState":10,"updatedAt":0}"#.utf8)
        let snapshot = try JSONDecoder().decode(BullFigureSnapshot.self, from: data)
        XCTAssertEqual(snapshot.score(for: .bull), 68)
        XCTAssertEqual(snapshot.score(for: .devil), 10)
        XCTAssertNil(snapshot.score(for: .provider))
        XCTAssertNil(snapshot.score(for: .angel))
    }
    func testRoutineOnlyChangesTriggerNewPayload() {
        let old = BullFigureSnapshot(bullState: 68, urgeState: 10, bullRoutine: 20, urgeRoutine: 30, updatedAt: Date())
        var new = old
        new.bullRoutine = 80
        XCTAssertFalse(old.hasSameScores(as: new))
        new = old
        new.urgeRoutine = 90
        XCTAssertFalse(old.hasSameScores(as: new))
    }
    func testAllFourScoresRoundTripAndMapToTheirOwnCharacters() throws {
        let original = BullFigureSnapshot(bullState: 11, urgeState: 22, bullRoutine: 33, urgeRoutine: 44, updatedAt: Date())
        let decoded = try JSONDecoder().decode(BullFigureSnapshot.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.score(for: .bull), 11)
        XCTAssertEqual(decoded.score(for: .devil), 22)
        XCTAssertEqual(decoded.score(for: .provider), 33)
        XCTAssertEqual(decoded.score(for: .angel), 44)
    }
    func testYesterdayAndFuturePayloadsDoNotPresentAsCurrent() {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now)
        let old = BullFigureSnapshot(bullState: 100, urgeState: 100, bullRoutine: 100, urgeRoutine: 100,
                                     updatedAt: midnight.addingTimeInterval(-1))
        for character in BullFigureCharacter.allCases {
            XCTAssertNil(old.current(on: now).score(for: character))
        }
        var future = old
        future.updatedAt = now.addingTimeInterval(120)
        XCTAssertNil(future.current(on: now).score(for: .bull))
        future.updatedAt = now
        XCTAssertEqual(future.current(on: now).score(for: .bull), 100)
    }
}
