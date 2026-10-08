import Foundation

/// Compare the proposal independently of its review status. This also protects against
/// a decision for an older/different proposal with a reused identifier.
public func therapistDecisionMatches(
    _ decision: TherapistRiskChangeRecord,
    request: TherapistRiskChangeRecord
) -> Bool {
    guard decision.status == .approved || decision.status == .rejected,
          let reviewedTs = decision.reviewedTs,
          reviewedTs.isFinite, reviewedTs >= request.requestedTs else { return false }
    var proposal = decision
    proposal.status = request.status
    proposal.reviewedTs = request.reviewedTs
    proposal.reviewerDecision = request.reviewerDecision
    return proposal == request
}

public func mergingTherapistDecisions(
    _ decisions: [TherapistRiskChangeRecord],
    into requests: [TherapistRiskChangeRecord]
) -> [TherapistRiskChangeRecord] {
    requests.map { request in
        guard request.status == .pending,
              let decision = decisions.filter({ therapistDecisionMatches($0, request: request) })
                .max(by: { ($0.reviewedTs ?? 0) < ($1.reviewedTs ?? 0) }) else { return request }
        return decision
    }
}

// MARK: - Risk-control protection policy

public func safeguardPromptWasResolved(
    _ prompt: SafeguardEvent,
    among events: [SafeguardEvent]
) -> Bool {
    guard prompt.kind == .promptIssued,
          prompt.effectiveResolutionMode == .safeguard else { return false }
    let latestStatus = events
        .filter {
            $0.zoneID == prompt.zoneID &&
                $0.safeguardID == prompt.safeguardID &&
                $0.dayKey == prompt.dayKey &&
                $0.ts >= prompt.ts &&
                ($0.kind == .completed || $0.kind == .corrected || $0.kind == .reversed)
        }
        .max { $0.ts < $1.ts }
    return latestStatus?.kind == .completed || latestStatus?.kind == .corrected
}

public func classifyRiskZoneChange(
    current: HighRiskZone,
    proposed: HighRiskZone
) -> RiskControlChangeClassification {
    guard current.id == proposed.id else { return .therapistReviewRequired }
    if current == proposed { return .noProtectionChange }

    var protectionIncreased = false
    func reviewRequired(_ condition: Bool) -> Bool { condition }

    // The name is the therapist's only location identifier because coordinates are never
    // in the shared projection. A silent rename would undermine human oversight even
    // though it does not change the geofence itself.
    if current.name != proposed.name { return .therapistReviewRequired }

    // Moving a geofence or changing its civil-time basis cannot be proven stronger locally.
    if reviewRequired(current.latitude != proposed.latitude ||
        current.longitude != proposed.longitude ||
        current.timeZoneIdentifier != proposed.timeZoneIdentifier ||
        current.scheduleMode != proposed.scheduleMode ||
        current.startMinute != proposed.startMinute ||
        current.endMinute != proposed.endMinute) {
        return .therapistReviewRequired
    }

    if current.enabled && !proposed.enabled { return .therapistReviewRequired }
    if !current.enabled && proposed.enabled { protectionIncreased = true }

    if proposed.radiusMetres < current.radiusMetres { return .therapistReviewRequired }
    if proposed.radiusMetres > current.radiusMetres { protectionIncreased = true }

    if proposed.riskLevel.points < current.riskLevel.points { return .therapistReviewRequired }
    if proposed.riskLevel.points > current.riskLevel.points { protectionIncreased = true }

    let allDays = Set(0...6)
    let currentDays = current.activeDays.isEmpty ? allDays : Set(current.activeDays)
    let proposedDays = proposed.activeDays.isEmpty ? allDays : Set(proposed.activeDays)
    if !proposedDays.isSuperset(of: currentDays) { return .therapistReviewRequired }
    if proposedDays != currentDays { protectionIncreased = true }

    if proposed.minutesAllowedAfterFinalWake > current.minutesAllowedAfterFinalWake ||
        proposed.minutesAllowedBeforeBed > current.minutesAllowedBeforeBed {
        return .therapistReviewRequired
    }
    if proposed.minutesAllowedAfterFinalWake < current.minutesAllowedAfterFinalWake ||
        proposed.minutesAllowedBeforeBed < current.minutesAllowedBeforeBed {
        protectionIncreased = true
    }

    if current.activateWhenUnexpectedlyAwake && !proposed.activateWhenUnexpectedlyAwake {
        return .therapistReviewRequired
    }
    if !current.activateWhenUnexpectedlyAwake && proposed.activateWhenUnexpectedlyAwake {
        protectionIncreased = true
    }

    if current.resolutionMode == .exitRequired && proposed.resolutionMode == .safeguard {
        return .therapistReviewRequired
    }
    if current.resolutionMode == .safeguard && proposed.resolutionMode == .exitRequired {
        protectionIncreased = true
    }

    if current.resolutionMode == .safeguard,
       proposed.resolutionMode == .safeguard,
       (current.safeguard.instruction != proposed.safeguard.instruction ||
        current.safeguard.note != proposed.safeguard.note ||
        current.safeguard.id != proposed.safeguard.id) {
        return .therapistReviewRequired
    }

    // Names and private lock-screen wording do not change monitoring coverage.
    return protectionIncreased ? .protectionIncreasing : .noProtectionChange
}

public func riskZoneCentreShiftMetres(
    from current: HighRiskZone,
    to proposed: HighRiskZone
) -> Double {
    let earthRadiusMetres = 6_371_000.0
    let latitude1 = current.latitude * .pi / 180
    let latitude2 = proposed.latitude * .pi / 180
    let latitudeDelta = (proposed.latitude - current.latitude) * .pi / 180
    let longitudeDelta = (proposed.longitude - current.longitude) * .pi / 180
    let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2) +
        cos(latitude1) * cos(latitude2) *
        sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
    return earthRadiusMetres * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
}

public func classifyAlertRepeatChange(
    currentMinutes: Int,
    proposedMinutes: Int
) -> RiskControlChangeClassification {
    let current = min(180, max(15, currentMinutes))
    let proposed = min(180, max(15, proposedMinutes))
    if proposed < current { return .protectionIncreasing }
    if proposed > current { return .therapistReviewRequired }
    return .noProtectionChange
}

public func therapistRiskZoneRecord(_ zone: HighRiskZone) -> TherapistRiskZoneRecord {
    TherapistRiskZoneRecord(
        id: zone.id,
        name: zone.name,
        radiusMetres: zone.radiusMetres,
        riskLevel: zone.riskLevel,
        enabled: zone.enabled,
        activeDays: zone.activeDays,
        startMinute: zone.startMinute,
        endMinute: zone.endMinute,
        scheduleMode: zone.scheduleMode,
        minutesAllowedAfterFinalWake: zone.minutesAllowedAfterFinalWake,
        minutesAllowedBeforeBed: zone.minutesAllowedBeforeBed,
        activateWhenUnexpectedlyAwake: zone.activateWhenUnexpectedlyAwake,
        resolutionMode: zone.resolutionMode,
        safeguardInstruction: zone.resolutionMode == .safeguard
            ? zone.safeguard.instruction
            : nil,
        safeguardDefinitionVersion: zone.safeguard.definitionVersion,
        timeZoneIdentifier: zone.timeZoneIdentifier
    )
}

public func therapistRiskChangeRecord(
    _ request: RiskControlChangeRequest
) -> TherapistRiskChangeRecord {
    TherapistRiskChangeRecord(
        id: request.id,
        kind: request.kind,
        zoneID: request.zoneID,
        currentZone: request.currentZone.map(therapistRiskZoneRecord),
        proposedZone: request.proposedZone.map(therapistRiskZoneRecord),
        currentIntegerValue: request.currentIntegerValue,
        proposedIntegerValue: request.proposedIntegerValue,
        currentBooleanValue: request.currentBooleanValue,
        proposedBooleanValue: request.proposedBooleanValue,
        summary: request.summary,
        requestedTs: request.requestedTs,
        status: request.status,
        reviewedTs: request.reviewedTs,
        reviewerDecision: request.reviewerDecision
    )
}

public func makeTherapistProjection(
    from data: BullData,
    monitoring: TherapistMonitoringStatus,
    now: Date = Date(),
    historyDays: Int = 90
) -> TherapistProjection {
    let boundedDays = min(365, max(7, historyDays))
    let cutoff = now.addingTimeInterval(-Double(boundedDays) * 86_400)
    let cutoffMS = cutoff.timeIntervalSince1970 * 1_000
    let cutoffKey = BullDates.key(for: cutoff)

    let urgeScores = data.fourScoreSnapshots
        .filter { $0.key >= cutoffKey }
        .map { key, value in
            TherapistUrgeScore(
                dayKey: key,
                urgeRoutine: value.urgeRoutine,
                urgeState: value.urgeState,
                recordedTs: value.recordedTs,
                isFinal: value.isFinal,
                revision: value.revision
            )
        }
        .sorted { $0.dayKey > $1.dayKey }

    let urgeObservations = data.pornUrgeObservations
        .filter { $0.ts >= cutoffMS || $0.dayKey >= cutoffKey }
        .sorted { $0.ts > $1.ts }

    let relapses = data.relapses
        .filter { data.settings.lapsePolicy.counts(Set($0.components)) }
        .filter { $0.loggedTs >= cutoffMS || $0.bullDayKey >= cutoffKey }
        .map { event in
            TherapistRelapseRecord(
                id: event.id,
                dayKey: event.bullDayKey,
                occurrenceTs: event.occurrence.occurrenceTs,
                loggedTs: event.loggedTs,
                components: event.components,
                riskZoneID: event.occurrence.locationPrecision == .riskZone
                    ? event.occurrence.zoneID
                    : nil
            )
        }
        .sorted { $0.loggedTs > $1.loggedTs }

    var zoneTransitions = data.zoneEvents.filter { $0.ts >= cutoffMS }
    let includedTransitionIDs = Set(zoneTransitions.map(\.id))
    for zone in data.highRiskZones {
        guard let latest = data.zoneEvents
            .filter({ $0.zoneID == zone.id })
            .max(by: { $0.ts < $1.ts }),
              latest.kind == .entered,
              !includedTransitionIDs.contains(latest.id) else { continue }
        // Keep an old, still-open visit visible even when its entry predates the normal
        // history window. This is current Risk Zone state, not historical expansion.
        zoneTransitions.append(latest)
    }

    return TherapistProjection(
        generatedTs: now.timeIntervalSince1970 * 1_000,
        urgeScores: urgeScores,
        urgeObservations: urgeObservations,
        relapses: relapses,
        riskZones: data.highRiskZones.map(therapistRiskZoneRecord),
        zoneEvents: zoneTransitions
            .map {
                TherapistZoneEvent(
                    id: $0.id,
                    zoneID: $0.zoneID,
                    kind: $0.kind,
                    ts: $0.ts,
                    dayKey: $0.dayKey
                )
            }
            .sorted { $0.ts > $1.ts },
        riskAlerts: data.riskAlertEvents
            .filter {
                $0.ts >= cutoffMS && $0.source != .compoundedRisk && $0.zoneID != nil
            }
            .map { event in
                TherapistRiskAlertRecord(
                    id: event.id,
                    ts: event.ts,
                    dayKey: event.dayKey,
                    source: event.source,
                    tier: event.tier,
                    zoneID: event.zoneID,
                    deliveryState: event.deliveryState,
                    acknowledgedTs: event.acknowledgedTs,
                    action: event.action,
                    completedTs: event.completedTs,
                    laterOutcomes: event.laterOutcomes
                )
            }
            .sorted { $0.ts > $1.ts },
        pendingRiskChanges: data.riskControlChangeRequests
            .filter { $0.requestedTs >= cutoffMS || $0.status == .pending }
            .map(therapistRiskChangeRecord)
            .sorted { $0.requestedTs > $1.requestedTs },
        zoneAlertRepeatMinutes: data.settings.zoneNudgeRepeatMinutes,
        timeSensitiveAlerts: data.settings.zoneTimeSensitiveAlerts,
        monitoring: monitoring
    )
}

public func shouldQueueTherapistEvent(
    deduplicationKey: String,
    existing: [TherapistOversightEvent]
) -> Bool {
    // Failed events remain in the durable outbox and are retried; creating a second event
    // with the same key would turn one real-world incident into duplicate warnings.
    !existing.contains { $0.deduplicationKey == deduplicationKey }
}

public func therapistNotificationCopy(
    for event: TherapistOversightEvent
) -> RiskZoneNotificationCopy {
    switch event.kind {
    case .zoneEntered, .zoneStillActive:
        return RiskZoneNotificationCopy(
            title: "Bull · Risk Zone",
            body: event.message
        )
    case .zoneExited:
        return RiskZoneNotificationCopy(
            title: "Bull · Risk Zone Resolved",
            body: "Your client has left the Risk Zone."
        )
    case .relapseLogged:
        return RiskZoneNotificationCopy(title: "Bull · Relapse Logged", body: event.message)
    case .riskControlChangeRequested:
        return RiskZoneNotificationCopy(title: "Bull · Review Needed", body: event.message)
    case .monitoringUnavailable:
        return RiskZoneNotificationCopy(title: "Bull · Monitoring Unavailable", body: event.message)
    case .oversightEnded:
        return RiskZoneNotificationCopy(title: "Bull · Oversight Ended", body: event.message)
    }
}

// MARK: - Additive v14 -> v15 migration

public func migratedBullDataToV15(
    _ source: BullData,
    timeZone: TimeZone = .current,
    now: Date = Date()
) -> BullData {
    var data = migratedBullDataToV14(source, timeZone: timeZone, now: now)
    if data.version < 15 { data.version = 15 }
    return data
}

/// A full backup preserves the access audit and reviewed change history, but never treats
/// device/account-specific CloudKit state as proof that this install is still connected.
/// The service re-discovers a real share from iCloud after import or reinstall.
public func clearedTherapistTransportForImport(
    _ source: BullData,
    now: Date = Date()
) -> BullData {
    var data = source
    let hadTransport = data.therapistOversight.state != .off ||
        !data.therapistOutboxEvents.isEmpty ||
        !data.therapistInboxEvents.isEmpty ||
        data.therapistProjectionCache != nil
    data.therapistOversight = TherapistOversightConfiguration()
    data.therapistOutboxEvents = []
    data.therapistInboxEvents = []
    data.therapistProjectionCache = nil
    for index in data.riskControlChangeRequests.indices
        where data.riskControlChangeRequests[index].status == .pending {
        data.riskControlChangeRequests[index].status = .cancelled
        data.riskControlChangeRequests[index].reviewedTs = now.timeIntervalSince1970 * 1_000
        data.riskControlChangeRequests[index].reviewerDecision = "Cancelled by full-backup restore"
    }
    if hadTransport {
        data.therapistAccessAudit.append(TherapistAccessAuditEvent(
            kind: .oversightEnded,
            ts: now.timeIntervalSince1970 * 1_000,
            detail: "Cloud access awaiting iCloud revalidation after full-backup restore"
        ))
    }
    return data
}
