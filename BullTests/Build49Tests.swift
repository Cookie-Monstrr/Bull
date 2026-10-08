import Foundation
import XCTest
import CloudKit
@testable import Bull

final class Build49ComponentTests: XCTestCase {
    private func state(sleep: Double? = 50) -> FourScoreState {
        FourScoreState(
            urgeRoutine: UrgeRoutineState(sleepProtection: sleep, stressPlan: 100, environmentProtection: 100),
            urgeState: UrgeState(score: 20, meanPeak: 2, observedDays: 1, windowDays: 1),
            bullRoutine: BullRoutineState(cardio: 100, sleep: 50, foodPlan: 100, strength: 50,
                                          weeklyModerateEquivalentMinutes: 160, weeklyStrengthSessions: 1),
            bullState: BullState(erectionHealth: 80, healthyDesire: 80, erectionDays: 1, desireDays: 1)
        )
    }
    private func snapshot(_ state: FourScoreState, components: Bool = false) -> FourScoreSnapshot {
        FourScoreSnapshot(urgeRoutine: state.urgeRoutine.score, urgeState: state.urgeState.score,
                          bullRoutine: state.bullRoutine.score, bullState: state.bullState.score,
                          isFinal: true,
                          routineComponents: components ? RoutineComponentSnapshot(urge: state.urgeRoutine, bull: state.bullRoutine) : nil)
    }
    func testWeightsStillSumToOneHundredPerRoutine() {
        XCTAssertEqual(RoutineMetric.urge.reduce(0) { $0 + $1.weight }, 100)
        XCTAssertEqual(RoutineMetric.bull.reduce(0) { $0 + $1.weight }, 100)
    }
    func testComponentsRoundTripWithoutChangingScores() throws {
        let source = snapshot(state(), components: true)
        let decoded = try JSONDecoder().decode(FourScoreSnapshot.self, from: JSONEncoder().encode(source))
        XCTAssertEqual(source, decoded)
        XCTAssertEqual(decoded.urgeRoutine, 80)
        XCTAssertEqual(decoded.bullRoutine, 80)
        XCTAssertEqual(decoded.routineComponents?.preventionSleep, 50)
    }
    func testOldSnapshotWithoutComponentsStillDecodes() throws {
        let source = snapshot(state())
        let decoded = try JSONDecoder().decode(FourScoreSnapshot.self, from: JSONEncoder().encode(source))
        XCTAssertNil(decoded.routineComponents)
        XCTAssertEqual(decoded.urgeRoutine, 80)
    }
    func testMalformedOptionalComponentsDoNotDiscardTotal() throws {
        let raw = try JSONEncoder().encode(snapshot(state()))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        object["routineComponents"] = "invalid"
        let decoded = try JSONDecoder().decode(FourScoreSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.urgeRoutine, 80)
        XCTAssertNil(decoded.routineComponents)
    }
    func testHistoricalReconstructionRejectsChangedTotalAndEarlierEra() {
        let state = state()
        var frozen = snapshot(state)
        frozen.urgeRoutine = 10
        let reconstructed = MinimalStats.compatibleComponents(snapshot: frozen, state: state)
        XCTAssertNil(reconstructed?.preventionSleep)
        XCTAssertEqual(reconstructed?.cardio, 100)
        frozen.scoringVersion = 8
        XCTAssertNil(MinimalStats.compatibleComponents(snapshot: frozen, state: state))
    }
    func testWeightedShortfallUsesComparableObservedDates() throws {
        let state = state()
        let component = RoutineComponentSnapshot(urge: state.urgeRoutine, bull: state.bullRoutine)
        var days = (0..<3).map { offset in
            StatsHistoryDay(date: BullDates.addingDays(offset, to: Date()), snapshot: nil,
                            components: component, reconstructed: false, sleepHours: nil,
                            hrv: nil, hrvBaseline: nil, relapseCount: 0)
        }
        var partial = component
        partial.vigourSleep = nil
        partial.strength = 0
        days.append(StatsHistoryDay(date: Date(), snapshot: nil, components: partial, reconstructed: false,
                                   sleepHours: nil, hrv: nil, hrvBaseline: nil, relapseCount: 0))
        let biggest = try XCTUnwrap(MinimalStats.shortfalls(metrics: RoutineMetric.bull, days: days).first)
        XCTAssertEqual(biggest.metric, .vigourSleep)
        XCTAssertEqual(biggest.missingPoints, 15)
        XCTAssertEqual(biggest.observedDays, 3)
        XCTAssertTrue(MinimalStats.shortfalls(metrics: RoutineMetric.bull, days: Array(days.prefix(2))).isEmpty)
    }
    func testMissingDoesNotBecomeZeroInAverage() {
        XCTAssertEqual(MinimalStats.average([nil, 50, nil, 100]), 75)
        XCTAssertNil(MinimalStats.average([nil, .nan]))
        XCTAssertEqual(MinimalStats.average([0]), 0)
    }
    func testTherapistProjectionNeverContainsComponentBreakdown() throws {
        var data = BullData()
        data.fourScoreSnapshots[BullDates.key(for: Date())] = snapshot(state(), components: true)
        let projection = makeTherapistProjection(from: data, monitoring: TherapistMonitoringStatus())
        let raw = String(decoding: try JSONEncoder().encode(projection), as: UTF8.self)
        for key in ["routineComponents", "preventionSleep", "cardio", "vigourSleep", "bullFuel", "strength"] {
            XCTAssertFalse(raw.contains("\"\(key)\""), key)
        }
    }
}

final class Build49PriorityTests: XCTestCase {
    func testSafetyFirstEvenThoughItsWeightIsLower() {
        let context = BullPriorityContext(unsafeZone: true, exitRequired: true, missingSleep: true, plannedCardio: 40)
        let actions = BullPriorityBuilder.actions(context)
        XCTAssertEqual(actions.first?.id, "environment")
        XCTAssertEqual(actions.first?.title, "Leave the risk zone")
        XCTAssertFalse(actions.first?.title.contains("safeguard") ?? true)
    }
    func testSleepSuppressesRoutineButNotAnActiveSafetyAction() {
        XCTAssertTrue(BullPriorityBuilder.actions(BullPriorityContext(sleeping: true)).isEmpty)
        let actions = BullPriorityBuilder.actions(BullPriorityContext(sleeping: true, unsafeZone: true))
        XCTAssertEqual(actions.map(\.id), ["environment"])
    }
    func testCompletedTasksDropOffAndRestDaysDoNotDemandExercise() {
        let context = BullPriorityContext(plannedCardio: 40, recordedCardio: 40, plannedSets: 3, completedSets: 3,
                                          morningLogged: true, eveningLogged: true, fuelPercent: 100)
        XCTAssertTrue(BullPriorityBuilder.actions(context).isEmpty)
        let rest = BullPriorityContext(morningLogged: true, fuelPercent: 0)
        XCTAssertTrue(BullPriorityBuilder.actions(rest).isEmpty)
    }
    func testNoEveningCheckinBeforeItIsDue() {
        let context = BullPriorityContext(morningLogged: true, eveningDue: false, fuelPercent: 100)
        XCTAssertFalse(BullPriorityBuilder.actions(context).contains { $0.id == "stress" })
    }
    func testNightPreparationDoesNotClaimToFixLastNight() throws {
        let context = BullPriorityContext(morningLogged: true, eveningLogged: true, eveningDue: true, fuelPercent: 100)
        let action = try XCTUnwrap(BullPriorityBuilder.actions(context).first)
        XCTAssertEqual(action.id, "prepareSleep")
        XCTAssertTrue(action.title.contains("tonight"))
        XCTAssertEqual(action.weightLabel, "U 40% · B 30%")
    }
    func testUnknownCardioIsPlannedNotClaimedUndone() throws {
        let context = BullPriorityContext(plannedCardio: 40, morningLogged: true, fuelPercent: 100)
        let action = try XCTUnwrap(BullPriorityBuilder.actions(context).first)
        XCTAssertTrue(action.title.contains("planned"))
        XCTAssertNil(action.progress)
        XCTAssertEqual(action.weightLabel, "B 40%")
    }
    func testProgressAndWeightAreSeparate() throws {
        let context = BullPriorityContext(plannedCardio: 40, recordedCardio: 10, morningLogged: true, fuelPercent: 100)
        let action = try XCTUnwrap(BullPriorityBuilder.actions(context).first)
        XCTAssertEqual(action.progress, 0.25)
        XCTAssertEqual(action.title, "Cardio · 30 min remaining")
        XCTAssertEqual(action.weightLabel, "B 40%")
    }
    func testWidgetJSONContainsOnlyAllowlistedKeys() throws {
        let payload = BullPrioritiesPayload(actions: BullPriorityBuilder.actions(BullPriorityContext()),
                                            updatedAt: Date(), validUntil: Date().addingTimeInterval(60))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["actions", "updatedAt", "validUntil"])
        let actions = try XCTUnwrap(object["actions"] as? [[String: Any]])
        let allowed: Set<String> = ["id", "title", "detail", "symbol", "weightLabel", "progress", "rank"]
        XCTAssertTrue(actions.allSatisfy { Set($0.keys).isSubset(of: allowed) })
    }
}

@MainActor
final class Build49HistoryTests: XCTestCase {
    func testHistoryExcludesTodayPreservesFrozenValuesAndKeepsMarkersOnExcludedDays() throws {
        let now = Date()
        let yesterday = BullDates.addingDays(-1, to: BullDates.startOfDay(now))
        let twoDaysAgo = BullDates.addingDays(-2, to: yesterday)
        let key = BullDates.key(for: yesterday)
        let earlierKey = BullDates.key(for: twoDaysAgo)
        var data = BullData(firstUse: BullDates.addingDays(-8, to: now).timeIntervalSince1970 * 1_000)
        data.days[key] = DayRecord(sleepHours: 5, hrv: 32, excluded: true)
        data.days[earlierKey] = DayRecord(sleepHours: 7, hrv: 48)
        data.fourScoreSnapshots[earlierKey] = FourScoreSnapshot(urgeRoutine: 27, urgeState: 11,
                                                             bullRoutine: 38, bullState: 72, isFinal: true)
        data.relapses = [RelapseEvent(ts: now.timeIntervalSince1970 * 1_000, dayKey: key)]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Bull-Build49-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try JSONEncoder().encode(data).write(to: directory.appendingPathComponent("bull-data-v15.json"))
        let store = BullStore(directoryURL: directory, publishesWidgets: false)
        let before = store.data
        let days = store.statsHistory(window: .week, now: now)
        XCTAssertEqual(days.count, 7)
        XCTAssertFalse(days.contains { BullDates.sameDay($0.date, now) })
        let excluded = try XCTUnwrap(days.first { $0.id == key })
        XCTAssertNil(excluded.snapshot)
        XCTAssertNil(excluded.sleepHours)
        XCTAssertNil(excluded.hrv)
        XCTAssertEqual(excluded.relapseCount, 1)
        let frozen = try XCTUnwrap(days.first { $0.id == earlierKey })
        XCTAssertEqual(frozen.snapshot?.urgeRoutine, 27)
        XCTAssertEqual(frozen.snapshot?.bullRoutine, 38)
        XCTAssertEqual(frozen.sleepHours, 7)
        XCTAssertEqual(store.data, before, "Opening Stats must not rewrite history")
    }

    func testFreshInstallHasNoInventedCompletedHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Bull-Build49-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BullStore(directoryURL: directory, publishesWidgets: false)
        XCTAssertTrue(store.statsHistory(window: .all).isEmpty)
    }

    func testPrioritiesExpireWithinThirtyMinutesAndNoLaterThanMidnight() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Bull-Build49-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BullStore(directoryURL: directory, publishesWidgets: false)
        let midnight = BullDates.addingDays(1, to: BullDates.startOfDay(Date()))
        let now = midnight.addingTimeInterval(-60)
        let payload = store.prioritiesPayload(at: now)
        XCTAssertEqual(payload.validUntil, midnight)
        XCTAssertLessThanOrEqual(payload.validUntil.timeIntervalSince(payload.updatedAt), 1_800)
    }
}

@MainActor
final class Build49OversightTests: XCTestCase {
    func testBusyRequestWaitsThenRevokesThenFinishes() async throws {
        var events: [String] = []
        try await OversightEndFlow.run(wait: { events.append("idle") }, revoke: { events.append("revoked") }, finish: { events.append("ended") })
        XCTAssertEqual(events, ["idle", "revoked", "ended"])
    }
    func testFailedRevocationNeverEndsLocally() async {
        var protected = true
        do {
            try await OversightEndFlow.run(wait: {}, revoke: { throw OversightEndError.timedOut }, finish: { protected = false })
            XCTFail("Expected timeout")
        } catch { XCTAssertTrue(protected) }
    }
    func testBusyTimeoutNeverAttemptsRevocationOrUnlocks() async {
        var revoked = false
        var ended = false
        do {
            try await OversightEndFlow.run(
                wait: { try await OversightEndFlow.waitUntilIdle(timeout: 0, isBusy: { true }) },
                revoke: { revoked = true }, finish: { ended = true })
            XCTFail("Expected busy error")
        } catch {
            XCTAssertFalse(revoked)
            XCTAssertFalse(ended)
        }
    }
    func testIdleWaitCompletesImmediately() async throws {
        try await OversightEndFlow.waitUntilIdle(timeout: 0, isBusy: { false })
    }
    func testPartialCloudErrorOnlyAcceptsTheExactMissingShare() {
        let id = CKRecord.ID(recordName: "share")
        let absent = NSError(domain: CKErrorDomain, code: CKError.Code.unknownItem.rawValue)
        let partial = NSError(domain: CKErrorDomain, code: CKError.Code.partialFailure.rawValue,
                              userInfo: [CKPartialErrorsByItemIDKey: [id: absent]])
        XCTAssertTrue(TherapistCloudService.confirmsMissingShare(partial, shareID: id))
        XCTAssertFalse(TherapistCloudService.confirmsMissingShare(partial, shareID: CKRecord.ID(recordName: "other")))
        XCTAssertFalse(TherapistCloudService.confirmsMissingShare(NSError(domain: CKErrorDomain, code: CKError.Code.networkFailure.rawValue), shareID: id))
    }
}
