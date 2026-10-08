import Foundation

// MARK: - Additive migrations

/// Pure v8→v9 migration retained as a release gate for old PWA/native backups. Rows and
/// settings are archived or retained, never deleted; canonical trigger/Response IDs are
/// added alongside the legacy display strings.
public func migratedBullDataToV9(_ source: BullData) -> BullData {
    guard source.version < 9 else { return source }
    var data = source
    data.version = 9

    let archivedIDs: Set<String> = [
        "junk", "caffeine", "coldplunge", "stretches", "mouthtape",
        "recoveryLow", "urgeSurvivalBonus", "kegels", "cardio", "strength",
        "breathwork"
    ]
    let archivedLabels = [
        "junk food", "coffee", "cold plunge", "pelvic floor stretch",
        "reverse) kegel", "reverse kegel", "mouth tape", "breathwork",
        "isometric", "beetroot", "leafy green", "zone 2", "hiit", "home alone"
    ]
    for index in data.items.indices {
        let id = data.items[index].id
        let label = data.items[index].label.lowercased()
        if archivedIDs.contains(id) || archivedLabels.contains(where: { label.contains($0) }) {
            data.items[index].archived = true
        }
        switch id {
        case "contentAccess":
            data.items[index].weight = .vhigh
            data.items[index].riskDomain = .exposure
            data.items[index].archived = false
        case "sleepLow":
            data.items[index].weight = .vhigh
            data.items[index].riskDomain = .physiology
            data.items[index].archived = false
        case "purposeLow", "purposeHigh":
            data.items[index].weight = .med
            data.items[index].riskDomain = .structure
            data.items[index].archived = false
        case "accountabilityGap":
            data.items[index].weight = .low
            data.items[index].riskDomain = .protection
            data.items[index].archived = false
        case "fasting":
            data.items[index].label = "Fasting"
            data.items[index].list = .prev
            data.items[index].kind = .habit
            data.items[index].weight = .med
            data.items[index].vigourWeight = nil
            data.items[index].bucket = nil
            data.items[index].riskDomain = .protection
            data.items[index].fastingAuto = true
            data.items[index].excusable = false
            data.items[index].archived = false
        default:
            if label.contains("clear nasal") || label.contains("nasal rinse") {
                data.items[index].list = .prime
                data.items[index].kind = .habit
                data.items[index].weight = .low
                data.items[index].vigourWeight = nil
                data.items[index].bucket = .no
                data.items[index].archived = false
            }
        }
    }

    let existingIDs = Set(data.items.map(\.id))
    for item in DefaultItems.all where !existingIDs.contains(item.id) {
        let represented: Bool
        switch item.id {
        case "nasalclear":
            represented = data.items.contains {
                let label = $0.label.lowercased()
                return !$0.isArchived && (label.contains("clear nasal") || label.contains("nasal rinse"))
            }
        case "fasting":
            represented = data.items.contains {
                !$0.isArchived && $0.label.caseInsensitiveCompare("Fasting") == .orderedSame
            }
        default:
            represented = false
        }
        if !represented { data.items.append(item) }
    }
    // Keep configured supplement names and all historical supplement checks exportable.
    data.settings.sleepRiskWeight = .vhigh
    data.settings.recoveryRiskWeight = .med

    let triggerIDs = Set(data.triggerLibrary.map(\.id))
    data.triggerLibrary.append(contentsOf: V27Defaults.triggers.filter { !triggerIDs.contains($0.id) })
    let responseIDs = Set(data.responseLibrary.map(\.id))
    data.responseLibrary.append(contentsOf: V27Defaults.responses.filter { !responseIDs.contains($0.id) })

    func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let characters = value.lowercased().unicodeScalars.map {
            allowed.contains($0) ? Character(String($0)) : "-"
        }
        return String(characters)
            .split(separator: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .prefix(42)
            .description
    }
    func triggerID(for name: String) -> String {
        let target = normalized(name)
        if let existing = data.triggerLibrary.first(where: {
            normalized($0.name) == target || $0.aliases.contains(where: { normalized($0) == target })
        }) { return existing.id }
        let base = "trigger.migrated.\(slug(name))"
        var candidate = base
        var suffix = 2
        while data.triggerLibrary.contains(where: { $0.id == candidate }) {
            candidate = "\(base)-\(suffix)"; suffix += 1
        }
        data.triggerLibrary.append(TriggerDefinition(id: candidate, name: name))
        return candidate
    }
    func responseID(for name: String) -> String {
        let target = normalized(name)
        if let existing = data.responseLibrary.first(where: {
            normalized($0.name) == target || $0.aliases.contains(where: { normalized($0) == target })
        }) { return existing.id }
        let base = "response.migrated.\(slug(name))"
        var candidate = base
        var suffix = 2
        while data.responseLibrary.contains(where: { $0.id == candidate }) {
            candidate = "\(base)-\(suffix)"; suffix += 1
        }
        data.responseLibrary.append(ResponseDefinition(id: candidate, name: name))
        return candidate
    }

    for index in data.urges.indices {
        var urge = data.urges[index]
        if urge.triggerIDs.isEmpty { urge.triggerIDs = urge.triggers.map { triggerID(for: $0) } }
        for name in urge.responses { _ = responseID(for: name) }
        data.urges[index] = urge
    }
    for index in data.relapses.indices {
        var lapse = data.relapses[index]
        if lapse.triggerIDs.isEmpty { lapse.triggerIDs = lapse.triggers.map { triggerID(for: $0) } }
        data.relapses[index] = lapse
    }
    for rule in data.rules {
        for name in rule.triggers { _ = triggerID(for: name) }
        for name in rule.responses { _ = responseID(for: name) }
    }
    for index in data.plans.indices where data.plans[index].triggerID == nil {
        var plan = data.plans[index]
        plan.triggerID = triggerID(for: plan.trigger)
        data.plans[index] = plan
    }
    return data
}

/// Pure, testable v9→v10 migration. It archives rather than deletes, preserves frozen
/// snapshots verbatim, and gives every missing v2.8 field a neutral/unknown meaning.
public func migratedBullDataToV10(
    _ source: BullData,
    timeZone: TimeZone = .current
) -> BullData {
    var data = migratedBullDataToV9(source)
    guard data.version < 10 else { return data }

    for index in data.items.indices {
        let id = data.items[index].id
        if id == "checkout" || id == "purposeLow" || id == "purposeHigh" {
            data.items[index].archived = true
        }
        if let definition = DefaultItems.all.first(where: { $0.id == id }) {
            data.items[index].evidenceStatus = definition.evidenceStatus
            data.items[index].intendedOutcome = definition.intendedOutcome
            data.items[index].definitionVersion = definition.definitionVersion
        } else {
            data.items[index].evidenceStatus = data.items[index].evidenceStatus ?? .personalExperiment
            data.items[index].intendedOutcome = data.items[index].intendedOutcome ?? "Personal experiment"
            data.items[index].definitionVersion = data.items[index].definitionVersion ?? 1
        }
    }

    let itemByID = data.items.reduce(into: [String: Item]()) { result, item in
        if result[item.id] == nil { result[item.id] = item }
    }
    for key in Array(data.days.keys) {
        guard var day = data.days[key] else { continue }
        for (id, value) in day.checks where day.completionStates[id] == nil {
            day.completionStates[id] = migratedCompletionRecord(
                legacyValue: value,
                itemKind: itemByID[id]?.kind,
                definitionVersion: itemByID[id]?.definitionVersion
            )
        }
        if let value = day.heartHealthyEating,
           day.completionStates["heartHealthyEating"] == nil {
            day.completionStates["heartHealthyEating"] = migratedCompletionRecord(
                legacyValue: value,
                itemKind: .habit,
                definitionVersion: 1
            )
        }
        if day.morningCommitment == nil, let first = day.intentions.first {
            day.morningCommitment = MorningCommitment(
                id: first.id,
                what: first.text,
                when: first.when,
                whereText: first.whereText,
                committedTs: nil,
                completion: CompletionRecord(
                    state: first.met ? .done : .unknown,
                    loggedTs: nil,
                    source: .migratedLegacy
                ),
                perceivedPurpose: day.purposeRating,
                source: .migratedLegacy
            )
        }
        data.days[key] = day
    }

    for index in data.highRiskZones.indices {
        if let legacyGate = data.highRiskZones[index].onlyWhenRiskAtLeast {
            data.highRiskZones[index].legacyOnlyWhenRiskAtLeast = legacyGate
        }
        data.highRiskZones[index].onlyWhenRiskAtLeast = nil
        if data.highRiskZones[index].timeZoneIdentifier == nil {
            data.highRiskZones[index].timeZoneIdentifier = timeZone.identifier
        }
    }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    func dayKey(for timestampMS: Double) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: Date(timeIntervalSince1970: timestampMS / 1_000)
        )
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 1970,
            components.month ?? 1,
            components.day ?? 1
        )
    }
    for index in data.relapses.indices {
        if data.relapses[index].occurrence.occurrenceDayKey.isEmpty {
            data.relapses[index].occurrence.occurrenceDayKey =
                data.relapses[index].dayKey ?? dayKey(for: data.relapses[index].ts)
        }
        if data.relapses[index].occurrence.source == .live,
           data.relapses[index].occurrence.timePrecision == .unknown,
           data.relapses[index].occurrence.occurrenceTs == nil,
           data.relapses[index].occurrence.occurrenceEndTs == nil {
            data.relapses[index].occurrence.source = .migratedLegacy
            data.relapses[index].occurrence.timePrecision = .unknown
            data.relapses[index].occurrence.occurrenceTs = nil
            data.relapses[index].occurrence.occurrenceEndTs = nil
            data.relapses[index].occurrence.timeConfidence = .unknown
        }
    }

    for index in data.personalFactors.indices {
        data.personalFactors[index].scoringWeight = nil
    }
    data.version = 10
    return data
}

// MARK: - Daily outcome summaries

public func sexualWeekSummary(
    observations: [DailySexualObservation],
    libidoSpots: [LibidoSpot],
    dayKeys: Set<String>
) -> SexualWeekSummary {
    let mornings = observations
        .filter { dayKeys.contains($0.dayKey) }
        .reduce(into: [String: DailySexualObservation]()) { latest, observation in
            if latest[observation.dayKey].map({ $0.ts < observation.ts }) ?? true {
                latest[observation.dayKey] = observation
            }
        }
        .values
    let observed = mornings.filter { $0.morningErection != .notObserved }
    let yes = observed.filter { $0.morningErection == .yes }
    let unknown = mornings.filter { $0.morningErection == .notObserved }.count
    let frequencyScore = observed.isEmpty ? nil : Double(yes.count) / Double(observed.count) * 100
    let qualities = yes.compactMap(\.erectionQuality)
    let qualityScore = qualities.isEmpty ? nil : qualities.reduce(0, +).mapDouble / Double(qualities.count) * 10
    let erection: Double?
    if let frequencyScore, let qualityScore {
        erection = (frequencyScore + qualityScore) / 2
    } else {
        erection = frequencyScore ?? qualityScore
    }

    let spots = libidoSpots.filter { dayKeys.contains($0.dayKey) }
    let average = spots.isEmpty ? nil : spots.map(\.rating).reduce(0, +).mapDouble / Double(spots.count)
    return SexualWeekSummary(
        observedMornings: observed.count,
        yesMornings: yes.count,
        unknownMornings: unknown,
        erectionHealth: erection,
        libidoSpotCount: spots.count,
        averageLibido: average
    )
}

/// Selects only information that had actually been logged by the requested boundary.
/// This is the shared guard against a later legacy/current-state check-in leaking into
/// an earlier historical Bull Strength calculation.
public func latestSexualCheckIn(
    _ checkIns: [SexualCheckIn],
    loggedBefore upperBound: Date,
    notBefore lowerBound: Date? = nil
) -> SexualCheckIn? {
    let upperMS = upperBound.timeIntervalSince1970 * 1_000
    let lowerMS = lowerBound.map { $0.timeIntervalSince1970 * 1_000 }
    return checkIns
        .filter { checkIn in
            checkIn.ts < upperMS && (lowerMS.map { checkIn.ts >= $0 } ?? true)
        }
        .max { $0.ts < $1.ts }
}

private extension Int {
    var mapDouble: Double { Double(self) }
}

/// v2.8 keeps the same motivational routine component while sourcing recall-sensitive
/// outcomes from daily observations. A current weekly check-in can still anchor readiness
/// and confidence, but future entries can never leak into earlier weeks.
public func v28VigourState(
    recentDays: [DayRecord],
    sexualSummary: SexualWeekSummary,
    currentStateCheckIn: SexualCheckIn?,
    nasalSupportDays: [Bool] = []
) -> VigourState {
    let days = Array(recentDays.suffix(7))
    let aerobic = days.compactMap(\.aerobicMinutes).reduce(0, +)
    let vigorous = days.compactMap(\.vigorousMinutes).reduce(0, +)
    let hasWorkoutData = days.contains {
        $0.aerobicMinutes != nil || $0.vigorousMinutes != nil || $0.strengthMinutes != nil
    }
    let aerobicScore = min(100, (aerobic + vigorous) / 150 * 100)
    let strengthDays = days.filter { ($0.strengthMinutes ?? 0) >= 15 }.count
    let strengthScore = min(100, Double(strengthDays) / 2 * 100)
    let dietValues = days.compactMap(\.heartHealthyEating)
    let dietScore = dietValues.isEmpty ? nil :
        Double(dietValues.filter { $0 }.count) / Double(dietValues.count) * 100
    let sleepValues = days.compactMap(\.sleep)
    let sleepScore = sleepValues.isEmpty ? nil : sleepValues.reduce(0, +) / Double(sleepValues.count)
    let nasalScore = nasalSupportDays.isEmpty ? nil :
        Double(nasalSupportDays.filter { $0 }.count) / Double(nasalSupportDays.count) * 100

    var weighted = 0.0
    var weight = 0.0
    if hasWorkoutData { weighted += aerobicScore * 4 + strengthScore; weight += 5 }
    if let dietScore { weighted += dietScore * 2; weight += 2 }
    if let sleepScore { weighted += sleepScore * 3; weight += 3 }
    if let nasalScore { weighted += nasalScore * 0.5; weight += 0.5 }
    let routine = weight > 0 ? max(0, min(100, weighted / weight)) : 50

    let erection = sexualSummary.erectionHealth
    let readinessAnchor = currentStateCheckIn.map {
        Double($0.readiness + $0.confidence) / 2
    }
    let libidoPieces = [sexualSummary.averageLibido, readinessAnchor].compactMap { $0 }
    let libidoReadiness = libidoPieces.isEmpty ? nil :
        libidoPieces.reduce(0, +) / Double(libidoPieces.count) * 10
    let outcomes = [erection, libidoReadiness].compactMap { $0 }
    let outcomeMean = outcomes.isEmpty ? nil : outcomes.reduce(0, +) / Double(outcomes.count)
    let strength = outcomeMean.map { 0.60 * $0 + 0.40 * routine } ?? routine
    return VigourState(
        routineScore: routine,
        erectionHealth: erection,
        libidoReadiness: libidoReadiness,
        bullStrength: max(0, min(100, strength))
    )
}

// MARK: - Zone schedule boundaries

/// Returns the next risky-window boundary after `date`. This lets the app schedule a
/// one-shot safeguard while the user is already inside instead of relying on a new entry.
public func nextZoneScheduleStart(
    for zone: HighRiskZone,
    after date: Date,
    calendar: Calendar = .current
) -> Date? {
    var calendar = calendar
    if let identifier = zone.timeZoneIdentifier, let zoneTimeZone = TimeZone(identifier: identifier) {
        calendar.timeZone = zoneTimeZone
    }
    let start = calendar.startOfDay(for: date)
    for offset in 0...8 {
        guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
        for interval in zone.scheduledIntervals(on: day, calendar: calendar).sorted(by: { $0.start < $1.start }) {
            if interval.start > date { return interval.start }
        }
    }
    return nil
}

public func shouldPromptAtZoneScheduleStart(
    zone: HighRiskZone,
    enteredAt: Date,
    boundary: Date,
    exitedAt: Date? = nil,
    calendar: Calendar = .current
) -> Bool {
    guard zone.enabled, enteredAt < boundary, exitedAt.map({ $0 > boundary }) ?? true else { return false }
    return zone.isScheduled(at: boundary.addingTimeInterval(1), calendar: calendar)
}

/// Builds a finite notification series inside one active Risk Zone interval. A recurring
/// trigger cannot express an end boundary, so it could continue after the zone becomes safe.
public func boundedZoneFollowUpDates(
    firstFireDate: Date,
    repeatMinutes: Int,
    activeUntil: Date,
    maximumCount: Int = 8
) -> [Date] {
    let count = min(8, max(0, maximumCount))
    guard count > 0, activeUntil > firstFireDate else { return [] }
    let interval = Double(min(180, max(15, repeatMinutes))) * 60
    return (1...count)
        .map { firstFireDate.addingTimeInterval(Double($0) * interval) }
        .prefix { $0 < activeUntil }
        .map { $0 }
}

public struct RiskZoneNotificationCopy: Equatable, Sendable {
    public var title: String
    public var body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// Keeps the requested action prompt consistent while preserving the private lock-screen
/// mode: the generic variant contains neither the app, place nor safeguard name.
public func riskZoneNotificationCopy(
    zoneName: String,
    safeguardInstruction: String,
    resolutionMode: ZoneResolutionMode = .safeguard,
    showDetails: Bool
) -> RiskZoneNotificationCopy {
    let prompt = "Take action before you regret it!"
    return showDetails
        ? RiskZoneNotificationCopy(
            title: "Bull · \(zoneName)",
            body: "\(prompt) \(resolutionMode == .exitRequired ? "Leave this Risk Zone." : safeguardInstruction)"
        )
        : RiskZoneNotificationCopy(title: "Private reminder", body: prompt)
}

// MARK: - Alert policy

public func riskAlertPolicyDecision(
    proposedTier: PressureTier,
    source: RiskAlertSource,
    zoneID: String?,
    nowMS: Double,
    history: [RiskAlertEvent]
) -> AlertPolicyDecision {
    let proposedIsZone = source != .compoundedRisk
    let related = history
        .filter { event in
            let sourceMatches = proposedIsZone
                ? event.source != .compoundedRisk
                : event.source == .compoundedRisk
            return sourceMatches && event.zoneID == zoneID &&
                event.deliveryState != .cancelled && event.deliveryState != .failed
        }
        .sorted { $0.ts > $1.ts }
    guard let latest = related.first else { return .deliver }

    if proposedTier > latest.tier {
        return .replace(eventID: latest.id)
    }
    if proposedTier < latest.tier,
       latest.cooldownUntilTs.map({ $0 > nowMS }) ?? false {
        return .suppressCooldown
    }
    if latest.cooldownUntilTs.map({ $0 > nowMS }) ?? false {
        if latest.completedTs != nil || latest.action == .safeguardDone {
            return .suppressAcknowledged
        }
        return .suppressCooldown
    }
    if source == .riskZoneFollowUp,
       latest.tier == proposedTier {
        return .deliver
    }
    if latest.tier == proposedTier {
        return nowMS - latest.ts < 20 * 60 * 60 * 1_000 ? .suppressDuplicate : .deliver
    }
    return .deliver
}

// MARK: - Adherence and weekly coaching

public func adherenceSummary(_ records: [CompletionRecord]) -> AdherenceSummary {
    records.reduce(into: AdherenceSummary()) { result, record in
        switch record.state {
        case .done: result.done += 1
        case .notDone: result.notDone += 1
        case .excused: result.excused += 1
        case .unknown: result.unknown += 1
        }
    }
}

/// Neutral, explicit conversion used by the app's v10 migration. A missing legacy value
/// remains missing and non-action factors are never manufactured into adherence records.
public func migratedCompletionRecord(
    legacyValue: Bool?,
    itemKind: ItemKind?,
    definitionVersion: Int? = nil
) -> CompletionRecord? {
    guard itemKind == .habit, let legacyValue else { return nil }
    return CompletionRecord(
        state: legacyValue ? .done : .notDone,
        loggedTs: nil,
        source: .migratedLegacy,
        definitionVersion: definitionVersion
    )
}

public struct WeeklyGoalCandidate: Equatable, Sendable {
    public var category: WeeklyGoalCategory
    public var factorID: String
    public var title: String
    public var rationale: String
    public var summary: AdherenceSummary
    public var isActionable: Bool
    public var isOutcome: Bool

    public init(
        category: WeeklyGoalCategory,
        factorID: String,
        title: String,
        rationale: String,
        summary: AdherenceSummary,
        isActionable: Bool = true,
        isOutcome: Bool = false
    ) {
        self.category = category
        self.factorID = factorID
        self.title = title
        self.rationale = rationale
        self.summary = summary
        self.isActionable = isActionable
        self.isOutcome = isOutcome
    }
}

/// Selects at most one actionable goal in each category. Targets rise by one observed
/// completion from the recent baseline and never jump to perfection automatically.
public func weeklyGoalRecommendations(
    candidates: [WeeklyGoalCandidate],
    startDayKey: String,
    endDayKey: String
) -> [WeeklyGoal] {
    WeeklyGoalCategory.allCases.compactMap { category in
        let eligible = candidates.filter {
            $0.category == category && $0.isActionable && !$0.isOutcome &&
            $0.summary.observedOpportunities >= 2
        }
        let selected = eligible.min { lhs, rhs in
            let l = lhs.summary.adherence ?? 1
            let r = rhs.summary.adherence ?? 1
            if l == r { return lhs.summary.observedOpportunities > rhs.summary.observedOpportunities }
            return l < r
        }
        guard let selected else { return nil }
        let opportunities = selected.summary.observedOpportunities
        let target = min(opportunities, selected.summary.done + 1)
        guard target > selected.summary.done else { return nil }
        return WeeklyGoal(
            category: category,
            factorID: selected.factorID,
            title: selected.title,
            rationale: selected.rationale,
            baselineDone: selected.summary.done,
            baselineOpportunities: opportunities,
            target: target,
            startDayKey: startDayKey,
            endDayKey: endDayKey
        )
    }
}

/// Applies the user's explicit accept/edit/reject choice without altering scoring inputs.
public func applyingWeeklyGoalDecision(
    to goal: WeeklyGoal,
    decision: WeeklyGoalDecision,
    decidedTs: Double = Date().timeIntervalSince1970 * 1_000
) -> WeeklyGoal {
    var updated = goal
    updated.decision = decision
    updated.decidedTs = decidedTs
    return updated
}

// MARK: - Data readiness

public enum DataReadinessLevel: String, Codable, Sendable {
    case collecting
    case exploratory
    case reviewReady
    case inconclusive
}

public struct DataReadiness: Equatable, Sendable {
    public var level: DataReadinessLevel
    public var prospectiveDays: Int
    public var exposed: Int
    public var unexposed: Int
    public var outcomeDays: Int
    public var missing: Int
    public var message: String

    public init(
        level: DataReadinessLevel,
        prospectiveDays: Int,
        exposed: Int,
        unexposed: Int,
        outcomeDays: Int,
        missing: Int,
        message: String
    ) {
        self.level = level
        self.prospectiveDays = prospectiveDays
        self.exposed = exposed
        self.unexposed = unexposed
        self.outcomeDays = outcomeDays
        self.missing = missing
        self.message = message
    }
}

public func personalAssociationReadiness(
    prospectiveDays: Int,
    exposed: Int,
    unexposed: Int,
    outcomeDays: Int,
    missing: Int
) -> DataReadiness {
    let exploratory = prospectiveDays >= 28 && exposed >= 8 && unexposed >= 8 && outcomeDays >= 3
    let review = prospectiveDays >= 84 && exposed >= 16 && unexposed >= 16 && outcomeDays >= 5
    let level: DataReadinessLevel
    if review {
        level = .reviewReady
    } else if exploratory {
        level = .exploratory
    } else if prospectiveDays >= 84 {
        level = .inconclusive
    } else {
        level = .collecting
    }
    let message: String
    switch level {
    case .reviewReady:
        message = "Ready for a cautious personal review; uncertainty and confounding still apply."
    case .exploratory:
        message = "Enough for an exploratory card only; this cannot change a weight."
    case .collecting:
        message = "Keep collecting prospective exposed and unexposed observations."
    case .inconclusive:
        message = "The available observations are inconclusive."
    }
    return DataReadiness(
        level: level,
        prospectiveDays: max(0, prospectiveDays),
        exposed: max(0, exposed),
        unexposed: max(0, unexposed),
        outcomeDays: max(0, outcomeDays),
        missing: max(0, missing),
        message: message
    )
}
