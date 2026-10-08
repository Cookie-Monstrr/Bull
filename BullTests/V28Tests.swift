import XCTest
@testable import Bull

final class V28Tests: XCTestCase {
    private let dayKey = "2026-08-24"

    func testLegacyV8BackupDecodesWithNeutralV28Collections() throws {
        let json = """
        {
          "version": 8,
          "settings": {},
          "days": {"2026-08-20": {"checks": {"fasting": true}}},
          "relapses": [{"id":"r1","ts":1787184000000,"dayKey":"2026-08-20","type":"orgasm"}],
          "sexualCheckIns": [{"id":"s1","ts":1787184000000,"dayKey":"2026-08-20","morningErections":3,"libido":5,"readiness":6,"confidence":7}],
          "highRiskZones": [{"id":"z1","name":"Home","latitude":51.5,"longitude":-0.1,"radiusMetres":150,"riskLevel":"high","enabled":true,"activeDays":[],"startMinute":0,"endMinute":0,"onlyWhenRiskAtLeast":65,"createdTs":1}]
        }
        """
        let decoded = try JSONDecoder().decode(BullData.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.version, 8)
        XCTAssertEqual(decoded.days.count, 1)
        XCTAssertEqual(decoded.relapses.count, 1)
        XCTAssertEqual(decoded.sexualCheckIns.count, 1)
        XCTAssertEqual(decoded.highRiskZones.count, 1)
        XCTAssertTrue(decoded.dailySexualObservations.isEmpty)
        XCTAssertTrue(decoded.libidoSpots.isEmpty)
        XCTAssertTrue(decoded.safeguardEvents.isEmpty)
        XCTAssertTrue(decoded.riskAlertEvents.isEmpty)
        XCTAssertTrue(decoded.weeklyGoals.isEmpty)
        XCTAssertTrue(decoded.personalFactors.isEmpty)
        XCTAssertEqual(decoded.relapses[0].occurrence.source, .migratedLegacy)
        XCTAssertEqual(decoded.relapses[0].occurrence.timePrecision, .unknown)
    }

    func testPureV8ToV9ToV10MigrationPreservesUserRowsAndSettings() {
        let archivedCandidate = Item(
            id: "caffeine", label: "Coffee", list: .both, kind: .habit,
            weight: .med, vigourWeight: .low, bucket: .heart, freq: .daily
        )
        let stableSnapshot = ScoreSnapshot(risk: 63, vigour: 52, scoringVersion: 3, recordedTs: 88)
        let source = BullData(
            version: 8,
            settings: Settings(supplements: ["Zinc", "Magnesium"]),
            items: [archivedCandidate],
            days: [dayKey: DayRecord(
                checks: ["caffeine": true],
                supplementsTaken: ["Zinc": true]
            )],
            urges: [UrgeEvent(id: "urge", ts: 10, dayKey: dayKey, triggers: ["Tired"])],
            relapses: [RelapseEvent(id: "lapse", ts: 20, dayKey: dayKey, type: .orgasm)],
            scoreSnapshots: [dayKey: stableSnapshot],
            firstUse: 1
        )

        let v9 = migratedBullDataToV9(source)
        XCTAssertEqual(v9.version, 9)
        XCTAssertEqual(v9.days.count, source.days.count)
        XCTAssertEqual(v9.urges.count, source.urges.count)
        XCTAssertEqual(v9.relapses.map(\.id), ["lapse"])
        XCTAssertEqual(v9.settings.supplements, ["Zinc", "Magnesium"])
        XCTAssertEqual(v9.days[dayKey]?.supplementsTaken["Zinc"], true)
        XCTAssertEqual(v9.scoreSnapshots[dayKey], stableSnapshot)
        XCTAssertTrue(v9.items.first(where: { $0.id == "caffeine" })?.isArchived == true)
        XCTAssertFalse(v9.urges[0].triggerIDs.isEmpty)

        let v10 = migratedBullDataToV10(source)
        XCTAssertEqual(v10.version, 10)
        XCTAssertEqual(v10.days.count, source.days.count)
        XCTAssertEqual(v10.relapses.map(\.id), ["lapse"])
        XCTAssertEqual(v10.settings.supplements, ["Zinc", "Magnesium"])
        XCTAssertEqual(v10.scoreSnapshots[dayKey], stableSnapshot)
    }

    func testV10MigrationIsAdditiveAndPreservesFrozenSnapshots() throws {
        let intention = Intention(
            id: "i1", text: "Work in the library", when: "09:00", whereText: "Library", met: false
        )
        let day = DayRecord(
            checks: ["fasting": true],
            intentions: [intention],
            purposeRating: 2,
            heartHealthyEating: false
        )
        let zone = HighRiskZone(
            id: "z1", name: "Home", latitude: 51.5, longitude: -0.1,
            onlyWhenRiskAtLeast: 65, timeZoneIdentifier: nil, createdTs: 1
        )
        let legacyLapse = RelapseEvent(
            id: "r1", ts: 1_787_529_600_000, dayKey: dayKey, type: .orgasm, loggedTs: 1_787_529_700_000
        )
        let frozen = ScoreSnapshot(risk: 72, vigour: 44, scoringVersion: 4, recordedTs: 99)
        let source = BullData(
            version: 9,
            days: [dayKey: day],
            relapses: [legacyLapse],
            scoreSnapshots: [dayKey: frozen],
            highRiskZones: [zone],
            firstUse: 1
        )

        let migrated = migratedBullDataToV10(
            source,
            timeZone: try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        )

        XCTAssertEqual(migrated.version, 10)
        XCTAssertEqual(migrated.scoreSnapshots[dayKey], frozen)
        XCTAssertEqual(migrated.days[dayKey]?.checks["fasting"], true)
        XCTAssertEqual(migrated.days[dayKey]?.completionStates["fasting"]?.state, .done)
        XCTAssertEqual(migrated.days[dayKey]?.completionStates["fasting"]?.definitionVersion, 2)
        XCTAssertEqual(migrated.days[dayKey]?.completionStates["heartHealthyEating"]?.state, .notDone)
        XCTAssertEqual(migrated.days[dayKey]?.morningCommitment?.id, intention.id)
        XCTAssertEqual(migrated.days[dayKey]?.morningCommitment?.completion.state, .unknown)
        XCTAssertEqual(migrated.days[dayKey]?.intentions, [intention])
        XCTAssertEqual(migrated.highRiskZones[0].legacyOnlyWhenRiskAtLeast, 65)
        XCTAssertNil(migrated.highRiskZones[0].onlyWhenRiskAtLeast)
        XCTAssertEqual(migrated.highRiskZones[0].timeZoneIdentifier, "Europe/London")
        XCTAssertEqual(migrated.relapses[0].id, "r1")
        XCTAssertEqual(migrated.relapses[0].loggedTs, 1_787_529_700_000)
        XCTAssertEqual(migrated.relapses[0].occurrence.source, .migratedLegacy)
        XCTAssertEqual(migrated.relapses[0].occurrence.timePrecision, .unknown)
        XCTAssertNil(migrated.relapses[0].occurrence.occurrenceTs)
        XCTAssertTrue(migrated.items.first(where: { $0.id == "checkout" })?.isArchived == true)
        XCTAssertTrue(migrated.items.contains(where: { $0.id == "checkout" }))
    }

    func testV10MigrationIsIdempotent() {
        let data = BullData(version: 10, firstUse: 123)
        XCTAssertEqual(migratedBullDataToV10(data), data)
    }

    func testExactLapseOccurrenceRoundTrips() throws {
        let occurrence = LapseOccurrenceMetadata(
            occurrenceDayKey: dayKey,
            occurrenceTs: 1_787_529_600_000,
            timePrecision: .exact,
            locationPrecision: .riskZone,
            zoneID: "zone-home",
            timeZoneIdentifier: "Europe/London",
            utcOffsetMinutes: 60,
            source: .live,
            timeConfidence: .exact,
            locationConfidence: .exact
        )
        let value = try roundTrip(occurrence)
        XCTAssertEqual(value, occurrence)
        XCTAssertEqual(value.zoneID, "zone-home")
        XCTAssertEqual(value.timeZoneIdentifier, "Europe/London")

        let forwardCompatibleV9 = BullData(
            version: 9,
            relapses: [RelapseEvent(
                id: "precise-v9", ts: occurrence.occurrenceTs ?? 0,
                dayKey: dayKey, type: .orgasm, occurrence: occurrence
            )],
            firstUse: 1
        )
        XCTAssertEqual(
            migratedBullDataToV10(forwardCompatibleV9).relapses[0].occurrence,
            occurrence,
            "An explicitly stored occurrence must not be neutralised merely because the container says v9."
        )
    }

    func testApproximateAndPartOfDayLapseOccurrencesPreserveRanges() throws {
        let approximate = LapseOccurrenceMetadata(
            occurrenceDayKey: dayKey,
            occurrenceTs: 1_787_529_600_000,
            timePrecision: .approximate,
            locationPrecision: .approximatePlace,
            placeName: "Near home",
            source: .retrospectiveBackfill,
            timeConfidence: .approximate,
            locationConfidence: .approximate
        )
        XCTAssertEqual(try roundTrip(approximate), approximate)

        let part = LapseOccurrenceMetadata(
            occurrenceDayKey: dayKey,
            occurrenceTs: 1_787_526_000_000,
            occurrenceEndTs: 1_787_544_000_000,
            timePrecision: .partOfDay,
            dayPart: .evening,
            locationPrecision: .namedPlace,
            placeName: "Hotel",
            source: .retrospectiveBackfill,
            timeConfidence: .approximate,
            locationConfidence: .exact
        )
        XCTAssertEqual(try roundTrip(part), part)
        XCTAssertEqual(try roundTrip(part).dayPart, .evening)
    }

    func testUnknownLapseOccurrenceDoesNotManufactureTimeOrPlace() throws {
        let value = try roundTrip(LapseOccurrenceMetadata(occurrenceDayKey: dayKey))
        XCTAssertEqual(value.timePrecision, .unknown)
        XCTAssertEqual(value.locationPrecision, .unknown)
        XCTAssertNil(value.occurrenceTs)
        XCTAssertNil(value.occurrenceEndTs)
        XCTAssertNil(value.dayPart)
        XCTAssertNil(value.zoneID)
        XCTAssertNil(value.placeName)
    }

    func testLapseEventKeepsStableIDAndSeparateLoggedTimestamp() throws {
        let occurrence = LapseOccurrenceMetadata(
            occurrenceDayKey: dayKey,
            occurrenceTs: 100,
            timePrecision: .exact,
            locationPrecision: .elsewhere,
            source: .prospectiveEdit,
            timeConfidence: .exact,
            locationConfidence: .exact
        )
        let event = RelapseEvent(
            id: "stable-lapse", ts: 100, dayKey: dayKey, type: .edge,
            components: [.porn, .masturbation], loggedTs: 900, occurrence: occurrence
        )
        let value = try roundTrip(event)
        XCTAssertEqual(value.id, "stable-lapse")
        XCTAssertEqual(value.loggedTs, 900)
        XCTAssertEqual(value.occurrence, occurrence)
    }

    func testOvernightZoneUsesConfiguredPlaceTimeZone() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let zone = HighRiskZone(
            name: "Cairo hotel", latitude: 30.0, longitude: 31.2,
            activeDays: [1], startMinute: 22 * 60, endMinute: 2 * 60,
            timeZoneIdentifier: "Africa/Cairo"
        )
        var cairo = utc
        cairo.timeZone = try XCTUnwrap(TimeZone(identifier: "Africa/Cairo"))
        let monday2300Cairo = try XCTUnwrap(cairo.date(
            from: DateComponents(year: 2026, month: 8, day: 24, hour: 23)
        ))
        let tuesday0100Cairo = try XCTUnwrap(cairo.date(
            from: DateComponents(year: 2026, month: 8, day: 25, hour: 1)
        ))
        let tuesday0300Cairo = try XCTUnwrap(cairo.date(
            from: DateComponents(year: 2026, month: 8, day: 25, hour: 3)
        ))
        XCTAssertTrue(zone.isScheduled(at: monday2300Cairo, calendar: utc))
        XCTAssertTrue(zone.isScheduled(at: tuesday0100Cairo, calendar: utc))
        XCTAssertFalse(zone.isScheduled(at: tuesday0300Cairo, calendar: utc))
    }

    func testNextZoneStartUsesZoneTimeZoneAndSupportsAlreadyInsidePrompt() throws {
        var london = Calendar(identifier: .gregorian)
        london.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let zone = HighRiskZone(
            name: "Library", latitude: 51.5, longitude: -0.1,
            activeDays: [1], startMinute: 20 * 60, endMinute: 22 * 60,
            timeZoneIdentifier: "Europe/London"
        )
        let monday1900 = try XCTUnwrap(london.date(
            from: DateComponents(year: 2026, month: 8, day: 24, hour: 19)
        ))
        let boundary = try XCTUnwrap(nextZoneScheduleStart(for: zone, after: monday1900, calendar: london))
        XCTAssertEqual(london.component(.hour, from: boundary), 20)
        XCTAssertTrue(shouldPromptAtZoneScheduleStart(
            zone: zone,
            enteredAt: monday1900,
            boundary: boundary,
            calendar: london
        ))
        XCTAssertFalse(shouldPromptAtZoneScheduleStart(
            zone: zone,
            enteredAt: monday1900,
            boundary: boundary,
            exitedAt: boundary.addingTimeInterval(-1),
            calendar: london
        ))
    }

    func testLegacyCompletionMigrationPreservesMissingness() {
        XCTAssertEqual(migratedCompletionRecord(legacyValue: true, itemKind: .habit)?.state, .done)
        XCTAssertEqual(migratedCompletionRecord(legacyValue: false, itemKind: .habit)?.state, .notDone)
        XCTAssertNil(migratedCompletionRecord(legacyValue: nil, itemKind: .habit))
        XCTAssertNil(migratedCompletionRecord(legacyValue: true, itemKind: .risk))
        XCTAssertEqual(
            migratedCompletionRecord(
                legacyValue: true,
                itemKind: .habit,
                definitionVersion: 3
            )?.definitionVersion,
            3
        )
    }

    func testCompletionRecordMissingFieldsDecodeAsUnknownMigratedHistory() throws {
        let value = try JSONDecoder().decode(CompletionRecord.self, from: Data("{}".utf8))
        XCTAssertEqual(value.state, .unknown)
        XCTAssertEqual(value.source, .migratedLegacy)
        XCTAssertNil(value.loggedTs)
        XCTAssertNil(value.excuse)
    }

    func testAdherenceSeparatesExcusedUnknownAndNotDone() {
        let summary = adherenceSummary([
            CompletionRecord(state: .done),
            CompletionRecord(state: .notDone),
            CompletionRecord(state: .excused, excuse: .sick),
            CompletionRecord(state: .unknown)
        ])
        XCTAssertEqual(summary.done, 1)
        XCTAssertEqual(summary.notDone, 1)
        XCTAssertEqual(summary.excused, 1)
        XCTAssertEqual(summary.unknown, 1)
        XCTAssertEqual(summary.observedOpportunities, 2)
        XCTAssertEqual(try XCTUnwrap(summary.adherence), 0.5, accuracy: 0.0001)
    }

    func testDailySexualSummaryUsesLatestDailyObservationAndMissingness() throws {
        let observations = [
            DailySexualObservation(id: "a", ts: 1, dayKey: "d1", morningErection: .no),
            DailySexualObservation(id: "b", ts: 2, dayKey: "d1", morningErection: .yes, erectionQuality: 8),
            DailySexualObservation(id: "c", ts: 3, dayKey: "d2", morningErection: .no),
            DailySexualObservation(id: "d", ts: 4, dayKey: "d3", morningErection: .notObserved)
        ]
        let spots = [
            LibidoSpot(id: "l1", ts: 1, dayKey: "d1", rating: 4),
            LibidoSpot(id: "l2", ts: 2, dayKey: "d2", rating: 8)
        ]
        let summary = sexualWeekSummary(
            observations: observations,
            libidoSpots: spots,
            dayKeys: ["d1", "d2", "d3"]
        )
        XCTAssertEqual(summary.observedMornings, 2)
        XCTAssertEqual(summary.yesMornings, 1)
        XCTAssertEqual(summary.unknownMornings, 1)
        XCTAssertEqual(try XCTUnwrap(summary.erectionHealth), 65, accuracy: 0.0001)
        XCTAssertEqual(summary.libidoSpotCount, 2)
        XCTAssertEqual(try XCTUnwrap(summary.averageLibido), 6, accuracy: 0.0001)
    }

    func testLegacySexualCheckInCannotLeakBackwardAcrossLogBoundary() throws {
        let old = SexualCheckIn(
            id: "old", ts: 1_000, dayKey: "2026-08-01", morningErections: 3,
            erectionQuality: 6, libido: 5, readiness: 5, confidence: 5
        )
        let future = SexualCheckIn(
            id: "future", ts: 3_000, dayKey: "2026-08-03", morningErections: 7,
            erectionQuality: 10, libido: 10, readiness: 10, confidence: 10
        )
        let boundary = Date(timeIntervalSince1970: 2)
        XCTAssertEqual(latestSexualCheckIn([old, future], loggedBefore: boundary)?.id, "old")
        XCTAssertNil(latestSexualCheckIn(
            [old, future],
            loggedBefore: boundary,
            notBefore: Date(timeIntervalSince1970: 1.5)
        ))
    }

    func testWeeklyGoalSelectionExcludesOutcomesAndLimitsEachCategory() {
        let candidates = [
            WeeklyGoalCandidate(
                category: .healthRoutine, factorID: "sleep", title: "Sleep outcome",
                rationale: "Outcome", summary: AdherenceSummary(done: 0, notDone: 6), isOutcome: true
            ),
            WeeklyGoalCandidate(
                category: .healthRoutine, factorID: "walk", title: "Walk",
                rationale: "Action", summary: AdherenceSummary(done: 2, notDone: 3)
            ),
            WeeklyGoalCandidate(
                category: .healthRoutine, factorID: "stretch", title: "Stretch",
                rationale: "Action", summary: AdherenceSummary(done: 4, notDone: 1)
            ),
            WeeklyGoalCandidate(
                category: .preventionSafeguard, factorID: "response", title: "Use response",
                rationale: "Action", summary: AdherenceSummary(done: 1, notDone: 3)
            ),
            WeeklyGoalCandidate(
                category: .preventionSafeguard, factorID: "risk", title: "Lower Risk",
                rationale: "Outcome", summary: AdherenceSummary(done: 0, notDone: 7), isOutcome: true
            )
        ]
        let goals = weeklyGoalRecommendations(
            candidates: candidates,
            startDayKey: "2026-08-24",
            endDayKey: "2026-08-30"
        )
        XCTAssertEqual(goals.count, 2)
        XCTAssertEqual(goals.filter { $0.category == .healthRoutine }.count, 1)
        XCTAssertEqual(goals.filter { $0.category == .preventionSafeguard }.count, 1)
        XCTAssertFalse(goals.contains { $0.factorID == "sleep" || $0.factorID == "risk" })
        XCTAssertEqual(goals.first(where: { $0.factorID == "walk" })?.target, 3)
        XCTAssertEqual(goals.first(where: { $0.factorID == "response" })?.target, 2)
    }

    func testWeeklyGoalDecisionPreservesUserEditsAndAllThreeChoices() {
        var goal = makeGoal()
        let accepted = applyingWeeklyGoalDecision(to: goal, decision: .accepted, decidedTs: 10)
        XCTAssertEqual(accepted.decision, .accepted)
        XCTAssertEqual(accepted.decidedTs, 10)

        goal.title = "Edited target"
        goal.target = 3
        goal.ifThenWhen = "After work"
        let edited = applyingWeeklyGoalDecision(to: goal, decision: .edited, decidedTs: 20)
        XCTAssertEqual(edited.decision, .edited)
        XCTAssertEqual(edited.title, "Edited target")
        XCTAssertEqual(edited.target, 3)
        XCTAssertEqual(edited.ifThenWhen, "After work")

        let rejected = applyingWeeklyGoalDecision(to: goal, decision: .rejected, decidedTs: 30)
        XCTAssertEqual(rejected.decision, .rejected)
        XCTAssertEqual(rejected.decidedTs, 30)
    }

    func testGoalsCommitmentPurposeAndArchivedCheckoutHaveNoV5RiskEffect() {
        var contextual = DayRecord(
            checkout: .lot,
            intentions: [Intention(text: "Task", met: true)],
            purposeRating: 1,
            morningCommitment: MorningCommitment(
                what: "Task", completion: CompletionRecord(state: .done)
            )
        )
        let baseline = riskScore(day: DayRecord(), items: DefaultItems.all)
        XCTAssertEqual(riskScore(day: contextual, items: DefaultItems.all), baseline)
        _ = applyingWeeklyGoalDecision(to: makeGoal(), decision: .accepted, decidedTs: 1)
        XCTAssertEqual(riskScore(day: contextual, items: DefaultItems.all), baseline)
        contextual.completionStates["goal"] = CompletionRecord(state: .done)
        XCTAssertEqual(riskScore(day: contextual, items: DefaultItems.all), baseline)
    }

    func testSafeguardCompletionDoesNotCreateProtection() throws {
        let event = SafeguardEvent(
            id: "sg-event", zoneID: "z1", safeguardID: "sg1", kind: .completed,
            occurrenceTs: 1_000, loggedTs: 1_100, dayKey: dayKey
        )
        XCTAssertEqual(try roundTrip(event), event)
        XCTAssertEqual(
            try roundTrip(SafeguardEvent(
                zoneID: "z1", safeguardID: "sg1", kind: .reversed,
                occurrenceTs: 1_200, loggedTs: 1_300, dayKey: dayKey
            )).kind,
            .reversed
        )
        XCTAssertEqual(
            try roundTrip(SafeguardEvent(
                zoneID: "z1", safeguardID: "sg1", kind: .corrected,
                occurrenceTs: 1_400, loggedTs: 1_500, dayKey: dayKey
            )).kind,
            .corrected
        )
        XCTAssertEqual(
            activeProtectionPoints(
                attempts: [],
                definitions: [ResponseDefinition(id: "r", name: "Response", protectionWeight: .high)],
                nowMS: 1_100
            ),
            0,
            accuracy: 0.0001
        )
    }

    func testAlertRoutesRoundTripForRiskAndZoneDestinations() {
        let risk = AlertRoute.risk(eventID: "event-1")
        let zone = AlertRoute.zone(zoneID: "zone-1", safeguardID: "safe-1", eventID: "event-2")
        XCTAssertEqual(AlertRoute(value: risk.value), risk)
        XCTAssertEqual(AlertRoute(value: zone.value), zone)
        XCTAssertNil(AlertRoute(value: "bull://unknown/value"))
    }

    func testAlertPolicyDeduplicatesAndAllowsLaterSameTier() {
        let event = makeAlert(ts: 1_000, tier: .watch, cooldownUntilTs: 2_000)
        XCTAssertEqual(
            riskAlertPolicyDecision(
                proposedTier: .watch, source: .compoundedRisk, zoneID: nil,
                nowMS: 1_500, history: [event]
            ),
            .suppressCooldown
        )
        XCTAssertEqual(
            riskAlertPolicyDecision(
                proposedTier: .watch, source: .compoundedRisk, zoneID: nil,
                nowMS: 3_000, history: [event]
            ),
            .suppressDuplicate
        )
        XCTAssertEqual(
            riskAlertPolicyDecision(
                proposedTier: .watch, source: .compoundedRisk, zoneID: nil,
                nowMS: 1_000 + 21 * 60 * 60 * 1_000, history: [event]
            ),
            .deliver
        )
    }

    func testAlertPolicyReplacesLowerTierEvenDuringCooldown() {
        let event = makeAlert(ts: 1_000, tier: .watch, cooldownUntilTs: 50_000)
        XCTAssertEqual(
            riskAlertPolicyDecision(
                proposedTier: .warning, source: .compoundedRisk, zoneID: nil,
                nowMS: 2_000, history: [event]
            ),
            .replace(eventID: event.id)
        )
    }

    func testAlertPolicyHonoursAcknowledgementAndCooldown() {
        var event = makeAlert(ts: 1_000, tier: .warning, cooldownUntilTs: 50_000)
        event.action = .openRiskPlan
        event.completedTs = 2_000
        XCTAssertEqual(
            riskAlertPolicyDecision(
                proposedTier: .warning, source: .compoundedRisk, zoneID: nil,
                nowMS: 3_000, history: [event]
            ),
            .suppressAcknowledged
        )
        XCTAssertEqual(
            riskAlertPolicyDecision(
                proposedTier: .watch, source: .compoundedRisk, zoneID: nil,
                nowMS: 3_000, history: [event]
            ),
            .suppressCooldown
        )
    }

    func testZoneFollowUpRepeatsAfterEachConfiguredCooldown() {
        let initial = makeAlert(
            ts: 1_000, tier: .watch, source: .riskZoneEntry,
            zoneID: "z1", cooldownUntilTs: 2_000
        )
        XCTAssertEqual(
            riskAlertPolicyDecision(
                proposedTier: .watch, source: .riskZoneFollowUp, zoneID: "z1",
                nowMS: 3_000, history: [initial]
            ),
            .deliver
        )
        let followUp = makeAlert(
            ts: 3_000, tier: .watch, source: .riskZoneFollowUp,
            zoneID: "z1", cooldownUntilTs: 4_000
        )
        XCTAssertEqual(
            riskAlertPolicyDecision(
                proposedTier: .watch, source: .riskZoneFollowUp, zoneID: "z1",
                nowMS: 5_000, history: [initial, followUp]
            ),
            .deliver
        )
    }

    func testDataReadinessThresholdsAndInconclusiveState() {
        XCTAssertEqual(
            personalAssociationReadiness(
                prospectiveDays: 20, exposed: 6, unexposed: 6, outcomeDays: 2, missing: 8
            ).level,
            .collecting
        )
        XCTAssertEqual(
            personalAssociationReadiness(
                prospectiveDays: 28, exposed: 8, unexposed: 8, outcomeDays: 3, missing: 12
            ).level,
            .exploratory
        )
        XCTAssertEqual(
            personalAssociationReadiness(
                prospectiveDays: 84, exposed: 16, unexposed: 16, outcomeDays: 5, missing: 52
            ).level,
            .reviewReady
        )
        XCTAssertEqual(
            personalAssociationReadiness(
                prospectiveDays: 84, exposed: 40, unexposed: 40, outcomeDays: 0, missing: 4
            ).level,
            .inconclusive
        )
    }

    func testPersonalFactorCannotImportAScoringWeight() throws {
        let json = """
        {"id":"factor","name":"Action","kind":"action","intendedOutcome":"highUrge",
         "hypothesis":"Test","scheduleDescription":"Daily","startDayKey":"2026-08-24",
         "evidenceStatus":"personalExperiment","definitionVersion":1,"archived":false,
         "aliases":[],"scoringWeight":99}
        """
        let factor = try JSONDecoder().decode(PersonalFactor.self, from: Data(json.utf8))
        XCTAssertNil(factor.scoringWeight)
    }

    func testFrozenLegacyScoreSnapshotRoundTripsUnchanged() throws {
        let snapshot = ScoreSnapshot(risk: 61, vigour: 73.5, scoringVersion: 3, recordedTs: 123)
        let data = BullData(scoreSnapshots: [dayKey: snapshot], firstUse: 1)
        let decoded = try roundTrip(data)
        XCTAssertEqual(decoded.scoreSnapshots[dayKey], snapshot)
        XCTAssertEqual(decoded.scoreSnapshots[dayKey]?.scoringVersion, 3)
    }

    func testArchivedCheckingOutHistoryIsRetainedAndExportable() throws {
        let day = DayRecord(checkout: .lot)
        let data = migratedBullDataToV10(BullData(version: 9, days: [dayKey: day], firstUse: 1))
        XCTAssertTrue(data.items.first(where: { $0.id == "checkout" })?.isArchived == true)
        XCTAssertEqual(data.days[dayKey]?.checkout, .lot)
        let decoded = try roundTrip(data)
        XCTAssertEqual(decoded.days[dayKey]?.checkout, .lot)
        XCTAssertTrue(decoded.items.contains(where: { $0.id == "checkout" }))
    }

    func testEveryNewV28TypeRoundTripsInBackup() throws {
        let completion = CompletionRecord(
            state: .excused,
            excuse: .travelling,
            loggedTs: 101,
            source: .live,
            definitionVersion: 2
        )
        let commitment = MorningCommitment(
            id: "commitment", what: "Draft proposal", when: "09:00", whereText: "Library",
            committedTs: 100, completion: completion, perceivedPurpose: 4, source: .live
        )
        let occurrence = LapseOccurrenceMetadata(
            occurrenceDayKey: dayKey, occurrenceTs: 200, timePrecision: .exact,
            locationPrecision: .namedPlace, placeName: "Hotel", timeZoneIdentifier: "Africa/Cairo",
            utcOffsetMinutes: 180, source: .retrospectiveBackfill,
            timeConfidence: .exact, locationConfidence: .exact
        )
        let safeguard = ZoneSafeguardDefinition(
            id: "safeguard", instruction: "Leave and call a friend", note: "Use the lobby", definitionVersion: 2
        )
        let zone = HighRiskZone(
            id: "zone", name: "Hotel", latitude: 30, longitude: 31, radiusMetres: 225,
            riskLevel: .high, enabled: true, activeDays: [1, 2], startMinute: 1_200,
            endMinute: 120, safeguard: safeguard, showNameOnLockScreen: false,
            timeZoneIdentifier: "Africa/Cairo", createdTs: 10
        )
        let alert = RiskAlertEvent(
            id: "alert", ts: 400, dayKey: dayKey, source: .riskZoneFollowUp,
            tier: .warning, zoneID: zone.id, safeguardID: safeguard.id,
            route: AlertRoute.zone(zoneID: zone.id, safeguardID: safeguard.id, eventID: "alert").value,
            leadingContributors: ["Risk Zone: Hotel"], scoringVersion: 5,
            deliveryState: .scheduled, acknowledgedTs: 410, action: .startResponse,
            linkedUrgeID: "urge", selectedInterventionIDs: ["response.sigh"],
            completedTs: 430, laterOutcomes: [.urgeLogged, .responseImproved],
            laterOutcomeTs: 440, cooldownUntilTs: 500
        )
        let goal = makeGoal()
        let review = WeeklyGoalReview(
            id: "review", goalID: goal.id, weekEndDayKey: goal.endDayKey,
            completed: 2, opportunities: 4, userNote: "Steady", reviewedTs: 600
        )
        let factor = PersonalFactor(
            id: "factor", name: "Phone outside bedroom", kind: .action,
            intendedOutcome: .highUrge, hypothesis: "May reduce high urges",
            scheduleDescription: "Daily", startDayKey: dayKey,
            evidenceStatus: .personalExperiment, definitionVersion: 2,
            aliases: ["Phone parked"], scoringWeight: 99
        )
        let original = BullData(
            version: 10,
            days: [dayKey: DayRecord(
                completionStates: [factor.id: completion], morningCommitment: commitment
            )],
            relapses: [RelapseEvent(
                id: "lapse", ts: 200, dayKey: dayKey, components: [.porn],
                loggedTs: 300, occurrence: occurrence
            )],
            scoreSnapshots: [dayKey: ScoreSnapshot(risk: 50, vigour: 60, scoringVersion: 5, recordedTs: 700)],
            sexualCheckIns: [SexualCheckIn(
                id: "legacy-sex", ts: 50, dayKey: dayKey, morningErections: 3,
                erectionQuality: 6, libido: 5, readiness: 6, confidence: 7
            )],
            dailySexualObservations: [DailySexualObservation(
                id: "morning", ts: 100, dayKey: dayKey,
                morningErection: .yes, erectionQuality: 8, source: .live
            )],
            libidoSpots: [LibidoSpot(id: "libido", ts: 120, dayKey: dayKey, rating: 7, source: .live)],
            highRiskZones: [zone],
            zoneEvents: [ZoneEvent(id: "entry", zoneID: zone.id, kind: .entered, ts: 350, dayKey: dayKey)],
            safeguardEvents: [SafeguardEvent(
                id: "safe-event", zoneID: zone.id, safeguardID: safeguard.id,
                kind: .completed, occurrenceTs: 450, loggedTs: 451,
                dayKey: dayKey, alertEventID: alert.id
            )],
            riskAlertEvents: [alert],
            privateContextSessions: [PrivateContextSession(id: "private", ts: 10, endedTs: 20, dayKey: dayKey)],
            weeklyGoals: [goal],
            weeklyGoalReviews: [review],
            personalFactors: [factor],
            firstUse: 1
        )

        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, original)
        XCTAssertNil(decoded.personalFactors[0].scoringWeight)
    }

    func testMalformedNewCollectionElementsAreReportedWithoutCascadingLoss() throws {
        let factor = PersonalFactor(
            id: "factor", name: "Action", kind: .action, intendedOutcome: .highUrge,
            hypothesis: "Hypothesis", scheduleDescription: "Daily", startDayKey: dayKey
        )
        let valid = BullData(
            version: 10,
            dailySexualObservations: [DailySexualObservation(dayKey: dayKey, morningErection: .yes)],
            libidoSpots: [LibidoSpot(dayKey: dayKey, rating: 5)],
            safeguardEvents: [SafeguardEvent(
                zoneID: "z", safeguardID: "s", kind: .completed, dayKey: dayKey
            )],
            riskAlertEvents: [makeAlert(ts: 1, tier: .watch, cooldownUntilTs: 2)],
            weeklyGoals: [makeGoal()],
            weeklyGoalReviews: [WeeklyGoalReview(
                goalID: "goal", weekEndDayKey: dayKey, completed: 1, opportunities: 2
            )],
            personalFactors: [factor],
            firstUse: 1
        )
        let raw = try BackupImporter.exportData(valid)
        guard var object = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
            return XCTFail("Expected object")
        }
        for key in [
            "dailySexualObservations", "libidoSpots", "safeguardEvents",
            "riskAlertEvents", "weeklyGoals", "weeklyGoalReviews", "personalFactors"
        ] {
            guard var array = object[key] as? [Any] else { return XCTFail("Missing \(key)") }
            array.append("malformed")
            object[key] = array
        }
        let corrupted = try JSONSerialization.data(withJSONObject: object)
        guard case .success(let (decoded, report)) = BackupImporter.importBackup(from: corrupted) else {
            return XCTFail("Expected recoverable import")
        }
        XCTAssertEqual(decoded.dailySexualObservations.count, 1)
        XCTAssertEqual(decoded.libidoSpots.count, 1)
        XCTAssertEqual(decoded.safeguardEvents.count, 1)
        XCTAssertEqual(decoded.riskAlertEvents.count, 1)
        XCTAssertEqual(decoded.weeklyGoals.count, 1)
        XCTAssertEqual(decoded.weeklyGoalReviews.count, 1)
        XCTAssertEqual(decoded.personalFactors.count, 1)
        XCTAssertEqual(report.skipped["dailySexualObservations"], 1)
        XCTAssertEqual(report.skipped["libidoSpots"], 1)
        XCTAssertEqual(report.skipped["safeguardEvents"], 1)
        XCTAssertEqual(report.skipped["riskAlertEvents"], 1)
        XCTAssertEqual(report.skipped["weeklyGoals"], 1)
        XCTAssertEqual(report.skipped["weeklyGoalReviews"], 1)
        XCTAssertEqual(report.skipped["personalFactors"], 1)
    }

    private func makeGoal() -> WeeklyGoal {
        WeeklyGoal(
            id: "goal", category: .healthRoutine, factorID: "walk", title: "Walk",
            rationale: "Gradual baseline increase", baselineDone: 1,
            baselineOpportunities: 4, target: 2,
            startDayKey: "2026-08-24", endDayKey: "2026-08-30"
        )
    }

    private func makeAlert(
        ts: Double,
        tier: PressureTier,
        source: RiskAlertSource = .compoundedRisk,
        zoneID: String? = nil,
        cooldownUntilTs: Double
    ) -> RiskAlertEvent {
        RiskAlertEvent(
            id: "alert-\(Int(ts))", ts: ts, dayKey: dayKey, source: source,
            tier: tier, zoneID: zoneID, route: "bull://risk/alert-\(Int(ts))",
            scoringVersion: 5, deliveryState: .scheduled,
            cooldownUntilTs: cooldownUntilTs
        )
    }

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let raw = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: raw)
    }
}
