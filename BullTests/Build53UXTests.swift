import XCTest
@testable import Bull

final class Build53PresentationTests: XCTestCase {
    func testDomainSelectionKeepsExistingPriorityOrder() {
        var context = BullPriorityContext()
        context.missingSleep = true
        context.plannedCardio = 30
        let actions = BullPriorityBuilder.actions(context)
        XCTAssertEqual(BullTodayDomain.urge.nextAction(in: actions)?.id, "syncSleep")
        XCTAssertEqual(BullTodayDomain.bull.nextAction(in: actions)?.id, "cardio")
        XCTAssertEqual(BullTodayDomain.urge.scoreTitle(state: false), "Urge Fuel")
        XCTAssertEqual(BullTodayDomain.bull.scoreTitle(state: true), "Bull State")
    }

    func testActiveRiskZoneRemainsFirstInBothViews() {
        var context = BullPriorityContext()
        context.unsafeZone = true
        context.sleeping = true
        context.fasting = true
        let actions = BullPriorityBuilder.actions(context)
        for domain in BullTodayDomain.allCases {
            XCTAssertEqual(domain.nextAction(in: actions)?.id, "environment")
        }
    }

    func testFastingStillExcludesExerciseFromNextStep() {
        var context = BullPriorityContext()
        context.fasting = true
        context.plannedCardio = 45
        context.plannedSets = 12
        context.morningLogged = true
        let actions = BullPriorityBuilder.actions(context)
        XCTAssertFalse(actions.contains { ["cardio", "strength"].contains($0.id) })
        XCTAssertEqual(BullTodayDomain.bull.nextAction(in: actions)?.id, "fuel")
        XCTAssertNil(BullTodayDomain.urge.nextAction(in: actions))
    }

    func testMissingDoesNotTurnARecordedZeroIntoMissingData() {
        XCTAssertEqual(BullRecordingStatus.score(nil, isFinal: true), "Not Recorded")
        XCTAssertEqual(BullRecordingStatus.score(.nan, isFinal: false), "Not Recorded")
        XCTAssertEqual(BullRecordingStatus.score(0, isFinal: true), "Recorded")
        XCTAssertEqual(BullRecordingStatus.score(0, isFinal: false), "Recorded")
    }

    func testYesterdayStatusUsesCalendarDays() throws {
        let now = try XCTUnwrap(BullDates.date(from: "2026-09-09")).addingTimeInterval(12 * 3_600)
        XCTAssertEqual(BullRecordingStatus.updated(nil, now: now), "Not Synced")
        XCTAssertEqual(BullRecordingStatus.updated(BullDates.addingDays(-1, to: now), now: now), "Updated Yesterday")
        XCTAssertTrue(BullRecordingStatus.updated(now, now: now).hasPrefix("Updated Today"))
    }

    func testNutritionUndoPreservesUnrelatedEditsAndLegacyValues() {
        var original = DayRecord()
        original.heartHealthyEating = true
        original.completionStates["heartHealthyEating"] = CompletionRecord(state: .done, loggedTs: 123)
        let snapshot = BullNutritionSnapshot(original)
        var changed = original
        changed.bullFuelPercent = 50
        changed.heartHealthyEating = nil
        changed.checks["fasting"] = true
        changed.sick = true
        changed.sleepHours = 8.5
        changed.checks["custom-experiment"] = true
        XCTAssertNotEqual(snapshot, BullNutritionSnapshot(changed))
        snapshot.restore(&changed)
        XCTAssertEqual(snapshot, BullNutritionSnapshot(changed))
        XCTAssertNil(changed.bullFuelPercent)
        XCTAssertEqual(changed.completionStates["heartHealthyEating"]?.loggedTs, 123)
        XCTAssertTrue(changed.sick)
        XCTAssertEqual(changed.sleepHours, 8.5)
        XCTAssertEqual(changed.checks["custom-experiment"], true)
    }
}

@MainActor
final class Build53SaveFeedbackTests: XCTestCase {
    func testCombinedNutritionSavesOnceOnTheChosenDay() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Bull-Build53-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BullStore(directoryURL: directory, publishesWidgets: false)
        let date = BullDates.addingDays(-2, to: Date())
        let before = store.revision
        let feedback = BullFeedbackCenter()
        XCTAssertTrue(feedback.save(store) { store.setBullFuel(50, on: date, fasting: true) })
        XCTAssertEqual(store.revision, before + 1)
        XCTAssertEqual(store.lastPersistedRevision, store.revision)
        XCTAssertEqual(store.bullFuelPercent(on: date), 50)
        XCTAssertTrue(store.isFasting(on: date))
        let restored = BullStore(directoryURL: directory, publishesWidgets: false)
        XCTAssertEqual(restored.bullFuelPercent(on: date), 50)
        XCTAssertTrue(restored.isFasting(on: date))
    }

    func testFailedDiskWriteIsNotReportedAsSavedAndRetryDoesNotDuplicate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Bull-Build53-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BullStore(directoryURL: directory, publishesWidgets: false)
        let feedback = BullFeedbackCenter()
        let date = Date()
        // Replace only this test's temporary directory with a file to force ENOTDIR.
        try FileManager.default.removeItem(at: directory)
        try Data("blocked".utf8).write(to: directory)
        XCTAssertFalse(feedback.save(store) { store.logUrgeState(4, on: date) })
        XCTAssertEqual(feedback.message?.isError, true)
        XCTAssertNotEqual(store.lastPersistedRevision, store.revision)
        let ids = store.pornUrgeObservations(on: date).map(\.id)
        XCTAssertEqual(ids.count, 1)
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        XCTAssertTrue(feedback.save(store) { store.retryPendingWrite() })
        XCTAssertEqual(store.pornUrgeObservations(on: date).map(\.id), ids)
        let restored = BullStore(directoryURL: directory, publishesWidgets: false)
        XCTAssertEqual(restored.pornUrgeObservations(on: date).map(\.id), ids)
    }
}
