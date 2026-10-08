import Foundation
import XCTest
@testable import Bull

final class Build52TherapistReviewTests: XCTestCase {
    private func request() -> TherapistRiskChangeRecord {
        therapistRiskChangeRecord(RiskControlChangeRequest(
            kind: .alertRepeatMinutes,
            currentIntegerValue: 30,
            proposedIntegerValue: 60,
            summary: "Repeat Every 60 Minutes"
        ))
    }

    func testSavedDecisionSurvivesPendingOwnerSnapshot() {
        let pending = request()
        var decision = pending
        decision.status = .approved
        decision.reviewedTs = pending.requestedTs + 1_000
        decision.reviewerDecision = "Approved"
        XCTAssertEqual(mergingTherapistDecisions([decision], into: [pending]), [decision])
        var applied = pending
        applied.status = .applied
        XCTAssertEqual(mergingTherapistDecisions([decision], into: [applied]), [applied])
        var cancelled = pending
        cancelled.status = .cancelled
        XCTAssertEqual(mergingTherapistDecisions([decision], into: [cancelled]), [cancelled])
    }

    func testDecisionCannotApproveDifferentProposalWithSameID() {
        let pending = request()
        var decision = pending
        decision.status = .approved
        decision.reviewedTs = pending.requestedTs + 1_000
        decision.proposedIntegerValue = 180
        XCTAssertFalse(therapistDecisionMatches(decision, request: pending))
        XCTAssertEqual(mergingTherapistDecisions([decision], into: [pending]), [pending])
    }

    func testUnreviewedOrEarlierDecisionDoesNotReplacePendingRequest() {
        let pending = request()
        var decision = pending
        decision.status = .rejected
        XCTAssertFalse(therapistDecisionMatches(decision, request: pending))
        decision.reviewedTs = pending.requestedTs - 1
        XCTAssertFalse(therapistDecisionMatches(decision, request: pending))
        decision.reviewedTs = pending.requestedTs + 1
        XCTAssertTrue(therapistDecisionMatches(decision, request: pending))
    }
}

final class V33ExitRequiredZoneTests: XCTestCase {
    func testLegacyZoneDefaultsToSafeguardResolution() throws {
        let raw = Data(#"""
        {
          "id":"legacy-zone",
          "name":"Home",
          "latitude":51.5,
          "longitude":-0.1,
          "radiusMetres":150,
          "riskLevel":"high",
          "enabled":true,
          "activeDays":[],
          "startMinute":0,
          "endMinute":0,
          "safeguard":{"id":"s","instruction":"Move rooms","definitionVersion":1}
        }
        """#.utf8)

        let zone = try JSONDecoder().decode(HighRiskZone.self, from: raw)

        XCTAssertEqual(zone.resolutionMode, .safeguard)
    }

    func testExitRequiredZoneRoundTrips() throws {
        let zone = HighRiskZone(
            name: "No safe room",
            latitude: 51.5,
            longitude: -0.1,
            resolutionMode: .exitRequired
        )

        let decoded = try JSONDecoder().decode(
            HighRiskZone.self,
            from: JSONEncoder().encode(zone)
        )

        XCTAssertEqual(decoded, zone)
        XCTAssertEqual(decoded.resolutionMode, .exitRequired)
    }

    func testExitRequiredNotificationNeverOffersFakeSafeguardCopy() {
        let copy = riskZoneNotificationCopy(
            zoneName: "Home",
            safeguardInstruction: "Stay in bed",
            resolutionMode: .exitRequired,
            showDetails: true
        )

        XCTAssertEqual(copy.title, "Bull · Home")
        XCTAssertEqual(copy.body, "Take action before you regret it! Leave this Risk Zone.")
        XCTAssertFalse(copy.body.contains("Stay in bed"))
    }

    func testLegacySafeguardEventDefaultsToSafeguardMode() throws {
        let raw = Data(#"""
        {
          "id":"prompt",
          "zoneID":"zone",
          "safeguardID":"safe",
          "kind":"promptIssued",
          "ts":100,
          "occurrenceTs":100,
          "loggedTs":100,
          "dayKey":"2026-08-30",
          "source":"live"
        }
        """#.utf8)

        let event = try JSONDecoder().decode(SafeguardEvent.self, from: raw)

        XCTAssertNil(event.resolutionMode)
        XCTAssertEqual(event.effectiveResolutionMode, .safeguard)
    }

    func testExitRequiredPromptCannotReceiveSafeguardCredit() {
        let prompt = SafeguardEvent(
            id: "prompt",
            zoneID: "zone",
            safeguardID: "safe",
            kind: .promptIssued,
            occurrenceTs: 100,
            loggedTs: 100,
            dayKey: "2026-08-30",
            resolutionMode: .exitRequired
        )
        let completion = SafeguardEvent(
            id: "completion",
            zoneID: "zone",
            safeguardID: "safe",
            kind: .completed,
            occurrenceTs: 200,
            loggedTs: 200,
            dayKey: "2026-08-30"
        )

        XCTAssertFalse(safeguardPromptWasResolved(prompt, among: [prompt, completion]))
    }
}

final class V33ProtectedRiskControlTests: XCTestCase {
    private func zone(
        radius: Double = 150,
        enabled: Bool = true,
        resolution: ZoneResolutionMode = .safeguard
    ) -> HighRiskZone {
        HighRiskZone(
            id: "zone",
            name: "Home",
            latitude: 51.5,
            longitude: -0.1,
            radiusMetres: radius,
            enabled: enabled,
            resolutionMode: resolution,
            safeguard: ZoneSafeguardDefinition(id: "safe", instruction: "Leave room")
        )
    }

    func testWeakeningZoneChangesRequireReview() {
        XCTAssertEqual(
            classifyRiskZoneChange(current: zone(), proposed: zone(radius: 75)),
            .therapistReviewRequired
        )
        XCTAssertEqual(
            classifyRiskZoneChange(current: zone(), proposed: zone(enabled: false)),
            .therapistReviewRequired
        )
        XCTAssertEqual(
            classifyRiskZoneChange(
                current: zone(resolution: .exitRequired),
                proposed: zone(resolution: .safeguard)
            ),
            .therapistReviewRequired
        )
        var renamed = zone()
        renamed.name = "Not Home"
        XCTAssertEqual(
            classifyRiskZoneChange(current: zone(), proposed: renamed),
            .therapistReviewRequired
        )
    }

    func testClearlyStrongerChangesApplyImmediately() {
        XCTAssertEqual(
            classifyRiskZoneChange(current: zone(radius: 100), proposed: zone(radius: 200)),
            .protectionIncreasing
        )
        XCTAssertEqual(
            classifyRiskZoneChange(
                current: zone(resolution: .safeguard),
                proposed: zone(resolution: .exitRequired)
            ),
            .protectionIncreasing
        )
        var exitWithPlaceholder = zone(resolution: .exitRequired)
        exitWithPlaceholder.safeguard = ZoneSafeguardDefinition(
            id: "safe",
            instruction: "Leave this Risk Zone",
            definitionVersion: 2
        )
        XCTAssertEqual(
            classifyRiskZoneChange(current: zone(), proposed: exitWithPlaceholder),
            .protectionIncreasing
        )
        XCTAssertEqual(
            classifyAlertRepeatChange(currentMinutes: 30, proposedMinutes: 15),
            .protectionIncreasing
        )
        XCTAssertEqual(
            classifyAlertRepeatChange(currentMinutes: 30, proposedMinutes: 60),
            .therapistReviewRequired
        )
    }

    func testCentreShiftCanBeReviewedWithoutSharingCoordinates() {
        let current = zone()
        var proposed = current
        proposed.latitude += 0.01

        let shift = riskZoneCentreShiftMetres(from: current, to: proposed)

        XCTAssertGreaterThan(shift, 1_000)
        XCTAssertLessThan(shift, 1_200)
    }
}

final class V33TherapistProjectionTests: XCTestCase {
    func testProjectionContainsOnlyApprovedScopeAndSanitizesRiskControls() throws {
        let now = try XCTUnwrap(BullDates.date(from: "2026-08-30"))
        let zone = HighRiskZone(
            id: "home",
            name: "Home",
            latitude: 51.50123,
            longitude: -0.10987,
            resolutionMode: .exitRequired,
            safeguard: ZoneSafeguardDefinition(
                id: "safe.home",
                instruction: "PRIVATE_SAFEGUARD",
                note: "PRIVATE_ZONE_NOTE"
            )
        )
        var proposed = zone
        proposed.radiusMetres = 75
        var data = BullData(
            settings: Settings(therapyNote: "PRIVATE_THERAPY_NOTE"),
            relapses: [RelapseEvent(
                id: "lapse",
                ts: now.timeIntervalSince1970 * 1_000,
                dayKey: "2026-08-30",
                components: [.porn],
                nextAction: "PRIVATE_NEXT_ACTION"
            )],
            highRiskZones: [zone],
            dailySexualObservations: [DailySexualObservation(
                dayKey: "2026-08-30",
                morningErection: .yes,
                erectionHardnessScore: 4,
                healthyDesire: 9
            )],
            strengthWorkoutLogs: [StrengthWorkoutLog(
                dayKey: "2026-08-30",
                note: "PRIVATE_WORKOUT_NOTE"
            )],
            pornUrgeObservations: [PornUrgeObservation(
                ts: now.timeIntervalSince1970 * 1_000,
                dayKey: "2026-08-30",
                intensity: 8
            )],
            fourScoreSnapshots: [
                "2026-08-30": FourScoreSnapshot(
                    urgeRoutine: 60,
                    urgeState: 80,
                    bullRoutine: 99,
                    bullState: 98,
                    recordedTs: now.timeIntervalSince1970 * 1_000,
                    isFinal: false
                )
            ]
        )
        data.riskControlChangeRequests = [RiskControlChangeRequest(
            kind: .updateZone,
            zoneID: zone.id,
            currentZone: zone,
            proposedZone: proposed,
            summary: "Reduce radius"
        )]
        data.zoneEvents = [ZoneEvent(
            id: "zone-entry",
            zoneID: zone.id,
            kind: .entered,
            ts: now.timeIntervalSince1970 * 1_000,
            dayKey: "2026-08-30",
            baseRiskAtEvent: 99
        )]
        data.riskAlertEvents = [
            RiskAlertEvent(
                id: "general-risk",
                ts: now.timeIntervalSince1970 * 1_000,
                dayKey: "2026-08-30",
                source: .compoundedRisk,
                tier: .emergency,
                route: "bull://risk/general-risk",
                scoringVersion: 8
            ),
            RiskAlertEvent(
                id: "zone-risk",
                ts: now.timeIntervalSince1970 * 1_000,
                dayKey: "2026-08-30",
                source: .riskZoneEntry,
                tier: .warning,
                zoneID: zone.id,
                route: "bull://zone/home/safe.home/zone-risk",
                scoringVersion: 8
            )
        ]

        let projection = makeTherapistProjection(
            from: data,
            monitoring: TherapistMonitoringStatus(locationStatus: "Always allowed"),
            now: now
        )
        let raw = try JSONEncoder().encode(projection)
        let text = try XCTUnwrap(String(data: raw, encoding: .utf8))
        let keys = try recursiveKeys(in: raw)

        XCTAssertEqual(projection.urgeScores.first?.urgeRoutine, 60)
        XCTAssertEqual(projection.urgeScores.first?.urgeState, 80)
        XCTAssertEqual(projection.relapses.map(\.id), ["lapse"])
        XCTAssertEqual(projection.riskZones.first?.resolutionMode, .exitRequired)
        XCTAssertNil(projection.riskZones.first?.safeguardInstruction)
        XCTAssertEqual(projection.zoneEvents.map(\.id), ["zone-entry"])
        XCTAssertEqual(projection.riskAlerts.map(\.id), ["zone-risk"])
        XCTAssertFalse(keys.contains("bullRoutine"))
        XCTAssertFalse(keys.contains("bullState"))
        XCTAssertFalse(keys.contains("baseRiskAtEvent"))
        XCTAssertFalse(keys.contains("latitude"))
        XCTAssertFalse(keys.contains("longitude"))
        XCTAssertFalse(keys.contains("note"))
        XCTAssertFalse(text.contains("PRIVATE_"))
        XCTAssertFalse(text.contains("sexual"))
        XCTAssertFalse(text.contains("workout"))
    }

    func testOversightEventDeduplicationIsDurable() {
        let event = TherapistOversightEvent(
            kind: .zoneEntered,
            dayKey: "2026-08-30",
            message: "Risk Zone",
            requiresAttention: true,
            deduplicationKey: "visit-1"
        )

        XCTAssertTrue(shouldQueueTherapistEvent(
            deduplicationKey: event.deduplicationKey,
            existing: []
        ))
        XCTAssertFalse(shouldQueueTherapistEvent(
            deduplicationKey: event.deduplicationKey,
            existing: [event]
        ))
        var failed = event
        failed.deliveryState = .failed
        XCTAssertFalse(shouldQueueTherapistEvent(
            deduplicationKey: failed.deduplicationKey,
            existing: [failed]
        ))
    }

    func testTherapistRiskZoneWarningUsesSanitizedResolutionMessage() {
        let event = TherapistOversightEvent(
            kind: .zoneEntered,
            dayKey: "2026-08-30",
            zoneID: "home",
            zoneName: "Home",
            message: "Take action before you regret it! Your client entered an active Risk Zone that can only be resolved by leaving.",
            requiresAttention: true,
            deduplicationKey: "visit-1"
        )

        let copy = therapistNotificationCopy(for: event)

        XCTAssertEqual(copy.title, "Bull · Risk Zone")
        XCTAssertEqual(copy.body, event.message)
        XCTAssertTrue(copy.body.contains("Take action before you regret it!"))
        XCTAssertFalse(copy.body.contains("latitude"))
        XCTAssertFalse(copy.body.contains("safeguard instruction"))
    }

    func testCurrentZonePresenceSurvivesHistoryCutoff() throws {
        let now = try XCTUnwrap(BullDates.date(from: "2026-08-30"))
        let entered = now.addingTimeInterval(-100 * 86_400)
        let zone = HighRiskZone(
            id: "home",
            name: "Home",
            latitude: 51.5,
            longitude: -0.1
        )
        let data = BullData(
            highRiskZones: [zone],
            zoneEvents: [ZoneEvent(
                id: "old-open-entry",
                zoneID: zone.id,
                kind: .entered,
                ts: entered.timeIntervalSince1970 * 1_000,
                dayKey: BullDates.key(for: entered)
            )]
        )

        let projection = makeTherapistProjection(
            from: data,
            monitoring: TherapistMonitoringStatus(),
            now: now
        )

        XCTAssertEqual(projection.zoneEvents.map(\.id), ["old-open-entry"])
    }

    private func recursiveKeys(in data: Data) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: data)
        var keys: Set<String> = []
        func visit(_ value: Any) {
            if let dictionary = value as? [String: Any] {
                for (key, child) in dictionary {
                    keys.insert(key)
                    visit(child)
                }
            } else if let array = value as? [Any] {
                array.forEach(visit)
            }
        }
        visit(object)
        return keys
    }
}

final class V33MigrationTests: XCTestCase {
    func testV14MigrationIsAdditiveAndIdempotent() {
        var source = BullData(version: 14)
        source.urges = [UrgeEvent(id: "urge", ts: 1)]

        let once = migratedBullDataToV15(source)
        let twice = migratedBullDataToV15(once)

        XCTAssertEqual(once.version, 15)
        XCTAssertEqual(once.urges.map(\.id), ["urge"])
        XCTAssertEqual(twice, once)
    }

    func testNewOversightCollectionsReportMalformedImportRows() throws {
        let source = try BackupImporter.exportData(BullData())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: source) as? [String: Any])
        let keys = [
            "riskControlChangeRequests",
            "therapistOutboxEvents",
            "therapistInboxEvents",
            "therapistAccessAudit"
        ]
        for key in keys { object[key] = ["malformed"] }
        let corrupted = try JSONSerialization.data(withJSONObject: object)

        guard case .success((_, let report)) = BackupImporter.importBackup(from: corrupted) else {
            return XCTFail("Expected lenient import with explicit skip reporting")
        }
        for key in keys { XCTAssertEqual(report.skipped[key], 1) }
    }

    func testV14SettingsDefaultNewAlertPriorityOff() throws {
        let raw = Data(#"{"zoneNudgeRepeatMinutes":30}"#.utf8)
        let settings = try JSONDecoder().decode(Settings.self, from: raw)

        XCTAssertFalse(settings.zoneTimeSensitiveAlerts)
    }

    func testFullBackupImportCannotRestoreCloudTransportOrPendingApproval() {
        var source = BullData()
        source.therapistOversight = TherapistOversightConfiguration(
            role: .therapist,
            state: .active,
            transportState: .ready,
            consentVersion: 1
        )
        source.therapistProjectionCache = TherapistProjection()
        source.therapistInboxEvents = [TherapistOversightEvent(
            kind: .zoneEntered,
            dayKey: "2026-08-30",
            message: "Risk Zone",
            requiresAttention: true,
            deduplicationKey: "entry"
        )]
        source.riskControlChangeRequests = [RiskControlChangeRequest(
            kind: .deleteZone,
            zoneID: "home",
            summary: "Delete Home"
        )]

        let cleared = clearedTherapistTransportForImport(source)

        XCTAssertEqual(cleared.therapistOversight.state, .off)
        XCTAssertEqual(cleared.therapistOversight.role, .owner)
        XCTAssertNil(cleared.therapistProjectionCache)
        XCTAssertTrue(cleared.therapistInboxEvents.isEmpty)
        XCTAssertEqual(cleared.riskControlChangeRequests.first?.status, .cancelled)
        XCTAssertTrue(cleared.therapistAccessAudit.contains { $0.kind == .oversightEnded })
    }
}
