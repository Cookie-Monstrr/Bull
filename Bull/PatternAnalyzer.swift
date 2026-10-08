import Foundation

enum RoutineMetric: String, CaseIterable, Identifiable {
    case preventionSleep, stressRegulation, environmentProtection
    case cardio, vigourSleep, bullFuel, strength
    var id: String { rawValue }
    var isUrge: Bool { Self.urge.contains(self) }
    static let urge: [Self] = [.preventionSleep, .stressRegulation, .environmentProtection]
    static let bull: [Self] = [.cardio, .vigourSleep, .bullFuel, .strength]

    var label: String {
        switch self {
        case .preventionSleep: return "Prevention Sleep"
        case .stressRegulation: return "Stress Regulation"
        case .environmentProtection: return "Environment"
        case .cardio: return "Cardio"
        case .vigourSleep: return "Vigour Sleep"
        case .bullFuel: return "Nutrition"
        case .strength: return "Strength"
        }
    }
    var weight: Double {
        switch self {
        case .preventionSleep, .cardio: return 40
        case .stressRegulation: return 35
        case .environmentProtection: return 25
        case .vigourSleep: return 30
        case .bullFuel: return 20
        case .strength: return 10
        }
    }
    func value(in snapshot: RoutineComponentSnapshot?) -> Double? {
        let value: Double?
        switch self {
        case .preventionSleep: value = snapshot?.preventionSleep
        case .stressRegulation: value = snapshot?.stressRegulation
        case .environmentProtection: value = snapshot?.environmentProtection
        case .cardio: value = snapshot?.cardio
        case .vigourSleep: value = snapshot?.vigourSleep
        case .bullFuel: value = snapshot?.bullFuel
        case .strength: value = snapshot?.strength
        }
        guard let value, value.isFinite else { return nil }
        return min(100, max(0, value))
    }
}

struct StatsHistoryDay: Identifiable {
    var id: String { BullDates.key(for: date) }
    var date: Date
    var snapshot: FourScoreSnapshot?
    var components: RoutineComponentSnapshot?
    var reconstructed: Bool
    var sleepHours: Double?
    var hrv: Double?
    var hrvBaseline: Double?
    var relapseCount: Int
    var isFasting = false
}

struct RoutineShortfall {
    var metric: RoutineMetric
    var average: Double
    var observedDays: Int
    var missingPoints: Double { metric.weight * (1 - average / 100) }
}

enum MinimalStats {
    static func average(_ values: [Double?]) -> Double? {
        let valid = values.compactMap { $0 }.filter(\.isFinite)
        return valid.isEmpty ? nil : valid.reduce(0, +) / Double(valid.count)
    }

    /// Compare on the same observed dates: unequal coverage must not determine the rank.
    static func shortfalls(metrics: [RoutineMetric], days: [StatsHistoryDay]) -> [RoutineShortfall] {
        let complete = days.filter { day in metrics.allSatisfy { $0.value(in: day.components) != nil } }
        guard complete.count >= 3 else { return [] }
        return metrics.compactMap { metric in
            guard let avg = average(complete.map { metric.value(in: $0.components) }) else { return nil }
            return RoutineShortfall(metric: metric, average: avg, observedDays: complete.count)
        }.sorted {
            if $0.missingPoints == $1.missingPoints { return $0.metric.rawValue < $1.metric.rawValue }
            return $0.missingPoints > $1.missingPoints
        }
    }

    /// Current-version breakdowns can be reconstructed only if they reproduce the saved total.
    /// Never relabel earlier scoring eras or rewrite their frozen values.
    static func compatibleComponents(
        snapshot: FourScoreSnapshot,
        state: FourScoreState
    ) -> RoutineComponentSnapshot? {
        guard snapshot.scoringVersion == currentFourScoreVersion else { return nil }
        func agrees(_ lhs: Double?, _ rhs: Double?) -> Bool {
            guard let lhs, let rhs else { return lhs == nil && rhs == nil }
            return lhs.isFinite && rhs.isFinite && abs(lhs - rhs) < 0.001
        }
        var result = RoutineComponentSnapshot(urge: state.urgeRoutine, bull: state.bullRoutine)
        if !agrees(snapshot.urgeRoutine, state.urgeRoutine.score) {
            result.preventionSleep = nil; result.stressRegulation = nil; result.environmentProtection = nil
        }
        if !agrees(snapshot.bullRoutine, state.bullRoutine.score) {
            result.cardio = nil; result.vigourSleep = nil; result.bullFuel = nil; result.strength = nil
        }
        return result
    }
}

extension BullStore {
    /// One read-only projection per Stats refresh, shared by all three pages.
    func statsHistory(window: PatternWindow, now: Date = Date()) -> [StatsHistoryDay] {
        let relapseCounts = Dictionary(grouping: data.relapses.filter(countsAsLapse), by: \.bullDayKey)
        return window.completedDates(firstUseMS: data.firstUse, now: now).map { date in
            let key = BullDates.key(for: date)
            let day = data.days[key]
            let excluded = day?.excluded == true
            let saved = data.fourScoreSnapshots[key]
            let snapshot = !excluded && saved?.isFinal == true &&
                (saved?.scoringVersion ?? 0) >= 8 &&
                (saved?.scoringVersion ?? Int.max) <= currentFourScoreVersion ? saved : nil
            var components = snapshot?.routineComponents
            var reconstructed = false
            if components == nil, let snapshot, snapshot.scoringVersion == currentFourScoreVersion {
                components = MinimalStats.compatibleComponents(snapshot: snapshot, state: fourScoreState(endingOn: date))
                reconstructed = components != nil
            }
            return StatsHistoryDay(
                date: date, snapshot: snapshot, components: components, reconstructed: reconstructed,
                sleepHours: excluded ? nil : day?.sleepHours,
                hrv: excluded ? nil : day?.hrv,
                hrvBaseline: excluded ? nil : PatternAnalyzer.rollingHRVBaseline(data: data, before: date),
                // Mark logged events even when the biometric observation is missing/excluded.
                relapseCount: relapseCounts[key]?.count ?? 0,
                isFasting: day?.checks["fasting"] == true
            )
        }
    }
}

enum PatternWindow: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case year = "1Y"
    case all = "ALL"
    var id: String { rawValue }

    var statsLabel: String {
        switch self {
        case .week: return "7D"
        case .month: return "30D"
        case .year: return "1Y"
        case .all: return "All Time"
        }
    }

    var averageLabel: String {
        self == .all ? "All-Time Avg" : "\(rawValue) Avg"
    }

    /// Patterns use completed civil days only. Today is deliberately excluded because an
    /// urge day cannot be labelled passed and today's exposures are still accumulating.
    func containsCompletedDay(_ date: Date, now: Date = Date()) -> Bool {
        let day = BullDates.startOfDay(date)
        let today = BullDates.startOfDay(now)
        guard day < today else { return false }
        switch self {
        case .all: return true
        case .week: return day >= BullDates.addingDays(-7, to: today)
        case .month: return day >= BullDates.addingDays(-30, to: today)
        case .year: return day >= BullDates.addingDays(-365, to: today)
        }
    }

    /// Dates represented by the Stats window, always ending yesterday. Today remains live
    /// and incomplete, so it must not leak into a range average or a "passed" outcome.
    func completedDates(firstUseMS: Double, now: Date = Date()) -> [Date] {
        let today = BullDates.startOfDay(now)
        let lastCompleted = BullDates.addingDays(-1, to: today)
        let firstUse = BullDates.startOfDay(Date(timeIntervalSince1970: firstUseMS / 1_000))
        let requestedStart: Date
        switch self {
        case .week: requestedStart = BullDates.addingDays(-7, to: today)
        case .month: requestedStart = BullDates.addingDays(-30, to: today)
        case .year: requestedStart = BullDates.addingDays(-365, to: today)
        case .all: requestedStart = firstUse
        }
        let start = max(firstUse, requestedStart)
        guard start <= lastCompleted else { return [] }
        let span = BullDates.calendar.dateComponents([.day], from: start, to: lastCompleted).day ?? -1
        guard span >= 0 else { return [] }
        return (0...span).map { BullDates.addingDays($0, to: start) }
    }
}

enum AssociationOutcome: String, CaseIterable, Identifiable {
    case lapse = "Any Lapse"
    case porn = "Porn"
    case masturbation = "Masturbation"
    case orgasm = "Orgasm"
    case wetDream = "Wet Dream"
    var id: String { rawValue }
}

struct PatternSummary {
    var averageRisk: Double?
    var averageVigour: Double?
    var relapses: Int
    var pornEvents: Int
    var masturbationEvents: Int
    var orgasmEvents: Int
    var urges: Int
    var urgeDaysCompleted: Int
    var urgeDaysPassed: Int
    var clean30: Int
    var wetDreams: Int
}

struct FourScoreRangeSummary {
    var urgeRoutine: Double?
    var urgeState: Double?
    var bullRoutine: Double?
    var bullState: Double?
    var observedDays: Int
}

struct ObservedAssociation: Identifiable {
    var id: String { label }
    var label: String
    var exposedDays: Int
    var exposedRelapses: Int
    var unexposedDays: Int
    var unexposedRelapses: Int
    var missingDays: Int = 0
    var definitionVersion: Int? = nil

    /// Jeffreys smoothing prevents one sparse event from producing a 0%/100% claim.
    var exposedRate: Double {
        exposedDays == 0 ? 0 : (Double(exposedRelapses) + 0.5) / (Double(exposedDays) + 1)
    }
    var unexposedRate: Double {
        unexposedDays == 0 ? 0 : (Double(unexposedRelapses) + 0.5) / (Double(unexposedDays) + 1)
    }
    var ratio: Double? {
        guard unexposedRate > 0 else { return exposedRate > 0 ? nil : 1 }
        return exposedRate / unexposedRate
    }
    var deltaPoints: Double { (exposedRate - unexposedRate) * 100 }
}

struct PersonalFactorPattern: Identifiable {
    var id: String { factorID }
    var factorID: String
    var name: String
    var outcome: PersonalFactorOutcome
    var definitionVersion: Int
    var readiness: DataReadiness
    var prospective: ObservedAssociation?
    var retrospective: ObservedAssociation?
    var compatibleBinaryOutcome: Bool
}

struct TriggerOutcome: Identifiable {
    var id: String { triggerID }
    var triggerID: String
    var trigger: String
    var passedDays: Int
    var relapseDays: Int
    var suggestedResponse: String?
    var totalDays: Int { passedDays + relapseDays }
    var passRate: Double { totalDays == 0 ? 0 : Double(passedDays) / Double(totalDays) }
}

struct HelpfulResponse: Identifiable {
    var id: String { responseID }
    var responseID: String
    var response: String
    var completedUses: Int
    var improvedUses: Int
    var averageStressChange: Double?
    var intensitySummary: String
    var improvementRate: Double { completedUses == 0 ? 0 : Double(improvedUses) / Double(completedUses) }
}

enum PatternAnalyzer {
    static func fourScoreRangeSummary(
        data: BullData,
        window: PatternWindow,
        now: Date = Date()
    ) -> FourScoreRangeSummary {
        let snapshots = data.fourScoreSnapshots.compactMap { key, snapshot -> FourScoreSnapshot? in
            guard snapshot.isFinal,
                  snapshot.scoringVersion >= 8,
                  snapshot.scoringVersion <= currentFourScoreVersion,
                  let date = BullDates.date(from: key),
                  window.containsCompletedDay(date, now: now) else { return nil }
            return snapshot
        }
        func average(_ values: [Double?]) -> Double? {
            let observed = values.compactMap { $0 }
            guard !observed.isEmpty else { return nil }
            return observed.reduce(0, +) / Double(observed.count)
        }
        return FourScoreRangeSummary(
            urgeRoutine: average(snapshots.map(\.urgeRoutine)),
            urgeState: average(snapshots.map(\.urgeState)),
            bullRoutine: average(snapshots.map(\.bullRoutine)),
            bullState: average(snapshots.map(\.bullState)),
            observedDays: snapshots.count
        )
    }

    static func summary(data: BullData, window: PatternWindow) -> PatternSummary {
        let now = Date()
        let lapses = countedLapses(data).filter { window.containsCompletedDay($0.bullCivilDate, now: now) }
        let relapseKeys = Set(lapses.map(\.bullDayKey))
        let selectedDays = data.days.compactMap { key, day -> (String, Date, DayRecord)? in
            guard let date = BullDates.date(from: key),
                  window.containsCompletedDay(date, now: now),
                  !day.excluded else { return nil }
            return (key, date, day)
        }

        let riskValues = selectedDays.compactMap { key, _, day -> Double? in
            guard riskLogged(day: day, items: data.items) else { return nil }
            guard let snapshot = data.scoreSnapshots[key],
                  snapshot.scoringVersion == currentScoringVersion else { return nil }
            return Double(snapshot.peakRisk ?? snapshot.risk)
        }
        let bullValues = selectedDays.compactMap { key, _, _ -> Double? in
            guard let snapshot = data.scoreSnapshots[key],
                  snapshot.scoringVersion == currentScoringVersion,
                  snapshot.vigourObserved == true else { return nil }
            return snapshot.vigour
        }
        let urges = data.urges.filter { window.containsCompletedDay($0.bullCivilDate, now: now) }
        let urgeKeys = Set(urges.map(\.bullDayKey))

        return PatternSummary(
            averageRisk: mean(riskValues),
            averageVigour: mean(bullValues),
            relapses: lapses.count,
            pornEvents: lapses.filter { $0.components.contains(.porn) }.count,
            masturbationEvents: lapses.filter { $0.components.contains(.masturbation) }.count,
            orgasmEvents: lapses.filter { $0.components.contains(.orgasm) }.count,
            urges: urges.count,
            urgeDaysCompleted: urgeKeys.count,
            urgeDaysPassed: urgeKeys.filter { !relapseKeys.contains($0) }.count,
            clean30: cleanPercent(data: data, days: 30, endingAt: BullDates.addingDays(-1, to: now)),
            wetDreams: data.wetDreams.filter { window.containsCompletedDay($0.bullCivilDate, now: now) }.count
        )
    }

    /// Descriptive signal only, never causality. Today is excluded; missing factors stay
    /// unknown. A result needs 28 observed days, 8 exposed, 8 unexposed and 3 outcome days.
    static func associations(
        data: BullData,
        window: PatternWindow,
        outcome: AssociationOutcome = .lapse
    ) -> [ObservedAssociation] {
        let today = BullDates.startOfDay(Date())
        let firstUseDay = BullDates.startOfDay(Date(timeIntervalSince1970: data.firstUse / 1000))
        let logged: [(String, DayRecord)] = data.days.compactMap { key, day in
            guard !day.excluded,
                  let date = BullDates.date(from: key),
                  date >= firstUseDay,
                  BullDates.startOfDay(date) < today,
                  window.containsCompletedDay(date) else { return nil }
            return (key, day)
        }
        let eligibleSpan = BullDates.calendar.dateComponents(
            [.day],
            from: firstUseDay,
            to: today
        ).day ?? 0
        let eligibleDayCount = (0..<max(0, eligibleSpan)).reduce(into: 0) { count, offset in
            let date = BullDates.addingDays(offset, to: firstUseDay)
            if window.containsCompletedDay(date) { count += 1 }
        }
        let outcomeKeys = keys(for: outcome, data: data)
        guard logged.count >= 28,
              Set(logged.map(\.0)).intersection(outcomeKeys).count >= 3 else { return [] }

        struct Factor { let label: String; let test: (String, DayRecord) -> Bool? }
        var factors: [Factor] = []

        if data.items.contains(where: { $0.id == "contentAccess" && !$0.isArchived }) {
            factors.append(Factor(label: "Elevated Content Access") { _, day in
                day.access.map { $0 == .med || $0 == .high }
            })
        }
        if data.items.contains(where: { $0.id == "checkout" && !$0.isArchived }) {
            factors.append(Factor(label: "Checking Out: A Lot") { _, day in day.checkout.map { $0 == .lot } })
        }
        factors += [
            Factor(label: "Prevention Sleep Below 65") { _, day in
                day.preventionSleepForScoring.map { $0 < 65 }
            },
            Factor(label: "High Stress (7+)") { _, day in day.stressLevel.map { $0 >= 7 } },
            Factor(label: "Low-Purpose Day (1–2)") { _, day in day.purposeRating.map { $0 <= 2 } },
            Factor(label: "HRV 10%+ below baseline") { key, day in
                guard let hrv = day.hrv,
                      let date = BullDates.date(from: key),
                      let baseline = rollingHRVBaseline(data: data, before: date) else { return nil }
                return hrv < baseline * 0.90
            },
            Factor(label: "Wet Dream on Waking Day") { key, _ in
                data.wetDreams.contains { $0.bullDayKey == key }
            },
            Factor(label: "Risky Private Space") { key, _ in
                highRiskContextOccurred(data: data, dayKey: key)
            },
            Factor(label: "Fasting Completed") { _, day in day.checks["fasting"] },
            Factor(label: "Sick Day") { _, day in day.sick },
            Factor(label: "Travelling Day") { _, day in day.travelling }
        ]

        return factors.compactMap { factor in
            let known = logged.compactMap { key, day in factor.test(key, day).map { (key, $0) } }
            let exposed = known.filter { $0.1 }
            let unexposed = known.filter { !$0.1 }
            guard exposed.count >= 8, unexposed.count >= 8 else { return nil }
            return ObservedAssociation(
                label: factor.label,
                exposedDays: exposed.count,
                exposedRelapses: exposed.filter { outcomeKeys.contains($0.0) }.count,
                unexposedDays: unexposed.count,
                unexposedRelapses: unexposed.filter { outcomeKeys.contains($0.0) }.count,
                missingDays: max(0, eligibleDayCount - known.count),
                definitionVersion: currentScoringVersion
            )
        }
        .filter { abs($0.deltaPoints) >= 3 }
        .sorted { abs($0.deltaPoints) > abs($1.deltaPoints) }
    }

    /// Personal experiments are analysed from their raw completion records. Live and
    /// prospective edits are kept separate from recall/backfill/migrated records.
    /// No result is connected to scoring in v2.9.
    static func personalFactorPatterns(data: BullData, window: PatternWindow) -> [PersonalFactorPattern] {
        let today = BullDates.startOfDay(Date())
        return data.personalFactors
            .filter { !$0.archived && $0.kind == .action }
            .compactMap { factor -> PersonalFactorPattern? in
                guard let outcomeKeys = binaryOutcomeKeys(for: factor.intendedOutcome, data: data) else {
                    return PersonalFactorPattern(
                        factorID: factor.id,
                        name: factor.name,
                        outcome: factor.intendedOutcome,
                        definitionVersion: factor.definitionVersion,
                        readiness: personalAssociationReadiness(
                            prospectiveDays: 0, exposed: 0, unexposed: 0, outcomeDays: 0, missing: 0
                        ),
                        prospective: nil,
                        retrospective: nil,
                        compatibleBinaryOutcome: false
                    )
                }
                guard let experimentStart = BullDates.date(from: factor.startDayKey) else { return nil }
                let start = BullDates.startOfDay(experimentStart)
                let span = BullDates.calendar.dateComponents([.day], from: start, to: today).day ?? 0
                let eligible: [(String, CompletionRecord?)] = (0..<max(0, span)).compactMap { offset in
                    let date = BullDates.addingDays(offset, to: start)
                    guard window.containsCompletedDay(date) else { return nil }
                    let key = BullDates.key(for: date)
                    let day = data.days[key]
                    guard day?.excluded != true else { return nil }
                    return (key, day?.completionStates[factor.id])
                }
                let prospectiveSources: Set<ObservationSource> = [.live, .prospectiveEdit, .automaticHealthKit]
                let retrospectiveSources: Set<ObservationSource> = [.delayedRecall, .retrospectiveBackfill, .migratedLegacy]

                let prospectiveKnown = eligible.compactMap { key, record -> (String, Bool)? in
                    guard let record,
                          record.definitionVersion == factor.definitionVersion,
                          prospectiveSources.contains(record.source) else { return nil }
                    switch record.state {
                    case .done: return (key, true)
                    case .notDone: return (key, false)
                    case .excused, .unknown: return nil
                    }
                }
                let retrospectiveKnown = eligible.compactMap { key, record -> (String, Bool)? in
                    guard let record,
                          record.definitionVersion == factor.definitionVersion,
                          retrospectiveSources.contains(record.source) else { return nil }
                    switch record.state {
                    case .done: return (key, true)
                    case .notDone: return (key, false)
                    case .excused, .unknown: return nil
                    }
                }
                let prospective = association(
                    label: factor.name,
                    observations: prospectiveKnown,
                    outcomeKeys: outcomeKeys,
                    missing: eligible.count - prospectiveKnown.count,
                    definitionVersion: factor.definitionVersion
                )
                let retrospective = association(
                    label: factor.name,
                    observations: retrospectiveKnown,
                    outcomeKeys: outcomeKeys,
                    missing: eligible.count - retrospectiveKnown.count,
                    definitionVersion: factor.definitionVersion
                )
                let exposed = prospectiveKnown.filter(\.1).count
                let unexposed = prospectiveKnown.filter { !$0.1 }.count
                let outcomeDays = Set(prospectiveKnown.map(\.0)).intersection(outcomeKeys).count
                let readiness = personalAssociationReadiness(
                    prospectiveDays: prospectiveKnown.count,
                    exposed: exposed,
                    unexposed: unexposed,
                    outcomeDays: outcomeDays,
                    missing: eligible.count - prospectiveKnown.count
                )
                return PersonalFactorPattern(
                    factorID: factor.id,
                    name: factor.name,
                    outcome: factor.intendedOutcome,
                    definitionVersion: factor.definitionVersion,
                    readiness: readiness,
                    prospective: prospective,
                    retrospective: retrospective,
                    compatibleBinaryOutcome: true
                )
            }
            .sorted { lhs, rhs in
                if lhs.readiness.level == rhs.readiness.level { return lhs.name < rhs.name }
                return readinessRank(lhs.readiness.level) > readinessRank(rhs.readiness.level)
            }
    }

    static func rollingHRVBaseline(data: BullData, before date: Date) -> Double? {
        let reference = BullDates.startOfDay(date)
        let values = data.days.compactMap { key, day -> (Date, Double)? in
            guard let sampleDate = BullDates.date(from: key), sampleDate < reference,
                  let hrv = day.hrv, hrv > 0 else { return nil }
            return (sampleDate, hrv)
        }
        .sorted { $0.0 > $1.0 }
        .prefix(30)
        .map(\.1)
        guard values.count >= 7 else { return nil }
        return median(Array(values))
    }

    static func triggerOutcomes(data: BullData, window: PatternWindow) -> [TriggerOutcome] {
        let today = BullDates.key(for: Date())
        let lapses = countedLapses(data)
        let triggerNames = data.triggerLibrary.reduce(into: [String: String]()) { $0[$1.id] = $1.name }
        let responseNames = data.responseLibrary.reduce(into: [String: String]()) { $0[$1.id] = $1.name }
        var attemptsByUrge: [String: [ResponseAttempt]] = [:]
        for attempt in data.responseAttempts where attempt.completedTs != nil {
            if let urgeID = attempt.urgeID { attemptsByUrge[urgeID, default: []].append(attempt) }
        }
        var perTrigger: [String: (passed: Set<String>, lapsed: Set<String>, responses: [String: Int])] = [:]

        for urge in data.urges where urge.bullDayKey != today && window.containsCompletedDay(urge.bullCivilDate) {
            let lapsed = lapses.contains {
                $0.bullDayKey == urge.bullDayKey && $0.ts >= urge.ts
            }
            for triggerID in Set(urge.triggerIDs) {
                var entry = perTrigger[triggerID] ?? ([], [], [:])
                if lapsed {
                    entry.lapsed.insert(urge.bullDayKey)
                    entry.passed.remove(urge.bullDayKey)
                } else if !entry.lapsed.contains(urge.bullDayKey) {
                    entry.passed.insert(urge.bullDayKey)
                    for attempt in attemptsByUrge[urge.id] ?? [] where improved(attempt) {
                        entry.responses[attempt.responseID, default: 0] += 1
                    }
                }
                perTrigger[triggerID] = entry
            }
        }

        return perTrigger.compactMap { id, entry in
            guard let name = triggerNames[id] else { return nil }
            let bestID = entry.responses.max { $0.value < $1.value }?.key
            return TriggerOutcome(
                triggerID: id,
                trigger: name,
                passedDays: entry.passed.count,
                relapseDays: entry.lapsed.count,
                suggestedResponse: bestID.flatMap { responseNames[$0] }
            )
        }
        .sorted { $0.totalDays > $1.totalDays }
    }

    static func helpfulResponses(data: BullData, window: PatternWindow) -> [HelpfulResponse] {
        let names = data.responseLibrary.reduce(into: [String: String]()) { $0[$1.id] = $1.name }
        let completed = data.responseAttempts.filter { attempt in
            guard let timestamp = attempt.completedTs else { return false }
            let day = attempt.dayKey.flatMap(BullDates.date(from:)) ??
                Date(timeIntervalSince1970: timestamp / 1000)
            return window.containsCompletedDay(day)
        }
        return Dictionary(grouping: completed, by: \.responseID)
            .compactMap { id, attempts in
                guard let name = names[id], !attempts.isEmpty else { return nil }
                let improvedAttempts = attempts.filter(improved)
                let stressChanges = attempts.compactMap { attempt -> Double? in
                    guard let before = attempt.stressBefore, let after = attempt.stressAfter else { return nil }
                    return Double(before - after)
                }
                let intensityText = UrgeIntensity.allCases.compactMap { intensity -> String? in
                    let atLevel = attempts.filter { $0.intensityBefore == intensity }
                    guard !atLevel.isEmpty else { return nil }
                    return "\(intensity.label) \(atLevel.filter(improved).count)/\(atLevel.count)"
                }.joined(separator: " · ")
                return HelpfulResponse(
                    responseID: id,
                    response: name,
                    completedUses: attempts.count,
                    improvedUses: improvedAttempts.count,
                    averageStressChange: mean(stressChanges),
                    intensitySummary: intensityText
                )
            }
            .sorted {
                if $0.completedUses == $1.completedUses { return $0.improvementRate > $1.improvementRate }
                return $0.completedUses > $1.completedUses
            }
    }

    static func cleanPercent(data: BullData, days: Int, endingAt end: Date) -> Int {
        guard days > 0 else { return 100 }
        let endDay = BullDates.startOfDay(end)
        let requestedStart = BullDates.addingDays(-(days - 1), to: endDay)
        let firstUseDay = BullDates.startOfDay(Date(timeIntervalSince1970: data.firstUse / 1000))
        let start = max(requestedStart, firstUseDay)
        guard start <= endDay else { return 100 }
        let span = (BullDates.calendar.dateComponents([.day], from: start, to: endDay).day ?? 0) + 1
        let keys = (0..<max(1, span)).map { BullDates.key(for: BullDates.addingDays($0, to: start)) }
        let relapse = Set(countedLapses(data).map(\.bullDayKey))
        return Int((Double(keys.filter { !relapse.contains($0) }.count) / Double(keys.count) * 100).rounded())
    }

    private static func countedLapses(_ data: BullData) -> [RelapseEvent] {
        data.relapses.filter { data.settings.lapsePolicy.counts(Set($0.components)) }
    }

    private static func highRiskContextOccurred(data: BullData, dayKey: String) -> Bool {
        guard let day = BullDates.date(from: dayKey) else { return false }
        let startDate = BullDates.startOfDay(day)
        let endDate = BullDates.addingDays(1, to: startDate)
        let start = startDate.timeIntervalSince1970 * 1_000
        let end = endDate.timeIntervalSince1970 * 1_000
        if data.privateContextSessions.contains(where: { session in
            session.ts < end && (session.endedTs ?? end) > start
        }) { return true }
        // Disabling monitoring must not erase a completed historical exposure from Patterns.
        // Store invariants close any active interval at the moment a zone is disabled.
        for zone in data.highRiskZones {
            let scheduled = zone.scheduledIntervals(on: day, calendar: BullDates.calendar)
            guard !scheduled.isEmpty else { continue }
            let events = data.zoneEvents
                .filter { $0.zoneID == zone.id && $0.ts < end }
                .sorted { $0.ts < $1.ts }
            var inside = events.last(where: { $0.ts < start })?.kind == .entered
            var enteredAt: Double? = inside ? start : nil
            var occupancy: [DateInterval] = []
            for event in events where event.ts >= start {
                if event.kind == .entered, !inside {
                    inside = true; enteredAt = event.ts
                } else if event.kind == .exited, inside {
                    if let enteredAt, event.ts > enteredAt {
                        occupancy.append(DateInterval(
                            start: Date(timeIntervalSince1970: enteredAt / 1_000),
                            end: Date(timeIntervalSince1970: event.ts / 1_000)
                        ))
                    }
                    inside = false; enteredAt = nil
                }
            }
            if inside, let enteredAt, end > enteredAt {
                occupancy.append(DateInterval(
                    start: Date(timeIntervalSince1970: enteredAt / 1_000),
                    end: endDate
                ))
            }
            if occupancy.contains(where: { occupied in
                scheduled.contains { rule in
                    min(occupied.end, rule.end) > max(occupied.start, rule.start)
                }
            }) { return true }
        }
        return false
    }

    private static func keys(for outcome: AssociationOutcome, data: BullData) -> Set<String> {
        switch outcome {
        case .lapse: return Set(countedLapses(data).map(\.bullDayKey))
        case .porn: return Set(data.relapses.filter { $0.components.contains(.porn) }.map(\.bullDayKey))
        case .masturbation: return Set(data.relapses.filter { $0.components.contains(.masturbation) }.map(\.bullDayKey))
        case .orgasm: return Set(data.relapses.filter { $0.components.contains(.orgasm) }.map(\.bullDayKey))
        case .wetDream: return Set(data.wetDreams.map(\.bullDayKey))
        }
    }

    private static func binaryOutcomeKeys(
        for outcome: PersonalFactorOutcome,
        data: BullData
    ) -> Set<String>? {
        switch outcome {
        case .lapse:
            return Set(countedLapses(data).map(\.bullDayKey))
        case .highUrge:
            let legacy = Set(data.urges.filter { $0.intensity == .high }.map(\.bullDayKey))
            let live = Set(data.pornUrgeObservations.filter { $0.intensity >= 7 }.map(\.dayKey))
            return legacy.union(live)
        case .safeguardCompletion:
            return Set(data.safeguardEvents.filter { $0.kind == .completed }.map(\.dayKey))
        case .bullStrength, .sexualHealth, .wellbeing:
            return nil
        }
    }

    private static func association(
        label: String,
        observations: [(String, Bool)],
        outcomeKeys: Set<String>,
        missing: Int,
        definitionVersion: Int
    ) -> ObservedAssociation? {
        let exposed = observations.filter(\.1)
        let unexposed = observations.filter { !$0.1 }
        guard !exposed.isEmpty || !unexposed.isEmpty else { return nil }
        return ObservedAssociation(
            label: label,
            exposedDays: exposed.count,
            exposedRelapses: exposed.filter { outcomeKeys.contains($0.0) }.count,
            unexposedDays: unexposed.count,
            unexposedRelapses: unexposed.filter { outcomeKeys.contains($0.0) }.count,
            missingDays: max(0, missing),
            definitionVersion: definitionVersion
        )
    }

    private static func readinessRank(_ level: DataReadinessLevel) -> Int {
        switch level {
        case .reviewReady: return 3
        case .exploratory: return 2
        case .inconclusive: return 1
        case .collecting: return 0
        }
    }

    nonisolated private static func improved(_ attempt: ResponseAttempt) -> Bool {
        if attempt.helpfulness == .somewhat || attempt.helpfulness == .clearly { return true }
        if attempt.reducedUrge { return true }
        guard let before = attempt.stressBefore, let after = attempt.stressAfter else { return false }
        return after < before
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.filter(\.isFinite).sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }
}
