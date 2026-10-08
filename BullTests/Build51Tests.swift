import Foundation
import XCTest
@testable import Bull

final class Build51FastingTests: XCTestCase {
    func testFastingAddsTenPointsAndCapsUrgeRoutine() {
        let normal = v31UrgeRoutineState(
            sleepScore: 70,
            stressRegulationScore: 70,
            environmentProtectionScore: 70
        )
        let fasting = v31UrgeRoutineState(
            sleepScore: 70,
            stressRegulationScore: 70,
            environmentProtectionScore: 70,
            fasting: true
        )
        let capped = v31UrgeRoutineState(
            sleepScore: 100,
            stressRegulationScore: 100,
            environmentProtectionScore: 100,
            fasting: true
        )

        XCTAssertEqual(normal.score, 70)
        XCTAssertNil(normal.fastingProtection)
        XCTAssertEqual(fasting.score, 80)
        XCTAssertEqual(fasting.fastingProtection, 100)
        XCTAssertEqual(capped.score, 100)
    }

    func testFastingRestDaySuppressesExercisePriorities() {
        let context = BullPriorityContext(
            plannedCardio: 45,
            plannedSets: 9,
            morningLogged: true,
            fuelPercent: 100,
            fasting: true
        )
        let ids = BullPriorityBuilder.actions(context).map(\.id)
        XCTAssertFalse(ids.contains("cardio"))
        XCTAssertFalse(ids.contains("strength"))
    }
}

final class Build51BullStateTests: XCTestCase {
    func testMorningAndLaterDesireCombineWithoutScoringDuration() {
        let morning = BullStateObservation(
            id: "morning",
            ts: 100,
            dayKey: "d",
            wakeLabel: "Dawn",
            erection: .yes,
            erectionHardnessScore: 3,
            erectionDurationSeconds: 60,
            kind: .morningErection
        )
        let later = BullStateObservation(
            id: "desire",
            ts: 200,
            dayKey: "d",
            wakeLabel: "Later Today",
            erection: .notObserved,
            healthyDesire: 8,
            kind: .naturalDesire
        )
        var longer = morning
        longer.erectionDurationSeconds = 1_800

        let state = v31BullState(observations: [morning, later], dayKey: "d")
        let longerState = v31BullState(observations: [longer, later], dayKey: "d")
        XCTAssertEqual(state.erectionHealth, 87.5)
        XCTAssertEqual(state.healthyDesire, 80)
        XCTAssertEqual(state.score, 85.25)
        XCTAssertEqual(state, longerState)
    }

    func testBuild50CombinedEntryStillDecodes() throws {
        let json = #"{"id":"old","ts":100,"dayKey":"d","wakeLabel":"Dawn","erection":"yes","erectionHardnessScore":4,"healthyDesire":7,"source":"live"}"#
        let decoded = try JSONDecoder().decode(BullStateObservation.self, from: Data(json.utf8))
        XCTAssertNil(decoded.kind)
        XCTAssertNil(decoded.erectionDurationSeconds)
        XCTAssertEqual(decoded.healthyDesire, 7)
        XCTAssertEqual(v31BullState(observations: [decoded], dayKey: "d").score, 91)
    }
}

final class Build51WidgetPrivacyTests: XCTestCase {
    func testChartPayloadContainsOnlyDerivedAllowlistedFields() throws {
        let payload = BullWidgetChartsSnapshot(
            points: [BullWidgetChartPoint(
                date: Date(timeIntervalSince1970: 100),
                urgeRoutine: 80,
                urgeState: 20,
                preventionSleep: 75,
                stressRegulation: 85,
                environmentProtection: 100
            )],
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let raw = String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
        for forbidden in ["relapse", "note", "sleepHours", "hrv", "zone"] {
            XCTAssertFalse(raw.localizedCaseInsensitiveContains(forbidden))
        }
    }
}

@MainActor
final class Build51HistoryCompatibilityTests: XCTestCase {
    func testBuild50ScoreHistoryRemainsFrozenWhenBuild51EraStarts() throws {
        let yesterday = BullDates.addingDays(-1, to: BullDates.startOfDay(Date()))
        let key = BullDates.key(for: yesterday)
        let frozen = FourScoreSnapshot(
            urgeRoutine: 63,
            urgeState: 24,
            bullRoutine: 71,
            bullState: 82,
            scoringVersion: 9,
            recordedTs: 123,
            isFinal: true
        )
        var settings = Settings()
        settings.fourScoreV9StartDayKey = key
        settings.fourScoreV10StartDayKey = nil
        var data = BullData(settings: settings)
        data.fourScoreSnapshots[key] = frozen
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Bull-Build51-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try JSONEncoder().encode(data).write(to: directory.appendingPathComponent("bull-data-v15.json"))

        let store = BullStore(directoryURL: directory, publishesWidgets: false)

        XCTAssertEqual(store.data.fourScoreSnapshots[key], frozen)
        XCTAssertEqual(store.data.settings.fourScoreV10StartDayKey, BullDates.key(for: Date()))
    }
}
