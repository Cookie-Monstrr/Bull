import Foundation
import Combine

@MainActor
final class BullStore: ObservableObject {
    @Published private(set) var data: BullData
    @Published var selectedDate: Date = Date()
    @Published var lastImportReport: ImportReport?
    @Published var lastError: String?
    @Published var lastNotice: String?
    @Published var gapDates: [Date] = []
    @Published private(set) var revision: Int = 0
    // UI save acknowledgements must reflect a successful disk write, not just an
    // in-memory mutation. This is ephemeral and does not alter the data envelope.
    @Published private(set) var lastPersistedRevision: Int = 0
    @Published private(set) var zonesNeedingNotificationReconciliation: Set<String> = []
    @Published private(set) var laylaScheduleBridgeStatus = LaylaScheduleBridgeStatus.notChecked

    private let fileURL: URL
    private let previousFileURL: URL
    private let preImportFileURL: URL
    private let legacyV14FileURL: URL
    private let legacyV14PreviousFileURL: URL
    private let legacyV13FileURL: URL
    private let legacyV13PreviousFileURL: URL
    private let legacyV12FileURL: URL
    private let legacyV12PreviousFileURL: URL
    private let legacyV11FileURL: URL
    private let legacyV11PreviousFileURL: URL
    private let legacyFileURL: URL
    private let legacyPreviousFileURL: URL
    private let legacyV9FileURL: URL
    private let legacyV9PreviousFileURL: URL
    private let legacyV8FileURL: URL
    private let legacyV8PreviousFileURL: URL
    private let dataDirectoryURL: URL
    private var lastGeneratedHistoricalTimestampByDay: [String: Double] = [:]
    private var lastSignalledTherapistProjection: TherapistProjection?
    private let publishesWidgets: Bool

    init(directoryURL: URL? = nil, publishesWidgets: Bool = true) {
        self.publishesWidgets = publishesWidgets
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = directoryURL ?? base.appendingPathComponent("Bull", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        dataDirectoryURL = dir
        fileURL = dir.appendingPathComponent("bull-data-v15.json")
        previousFileURL = dir.appendingPathComponent("bull-data-v15.previous.json")
        preImportFileURL = dir.appendingPathComponent("bull-data-v15.preimport.json")
        legacyV14FileURL = dir.appendingPathComponent("bull-data-v14.json")
        legacyV14PreviousFileURL = dir.appendingPathComponent("bull-data-v14.previous.json")
        legacyV13FileURL = dir.appendingPathComponent("bull-data-v13.json")
        legacyV13PreviousFileURL = dir.appendingPathComponent("bull-data-v13.previous.json")
        legacyV12FileURL = dir.appendingPathComponent("bull-data-v12.json")
        legacyV12PreviousFileURL = dir.appendingPathComponent("bull-data-v12.previous.json")
        legacyV11FileURL = dir.appendingPathComponent("bull-data-v11.json")
        legacyV11PreviousFileURL = dir.appendingPathComponent("bull-data-v11.previous.json")
        legacyFileURL = dir.appendingPathComponent("bull-data-v10.json")
        legacyPreviousFileURL = dir.appendingPathComponent("bull-data-v10.previous.json")
        legacyV9FileURL = dir.appendingPathComponent("bull-data-v9.json")
        legacyV9PreviousFileURL = dir.appendingPathComponent("bull-data-v9.previous.json")
        legacyV8FileURL = dir.appendingPathComponent("bull-data-v8.json")
        legacyV8PreviousFileURL = dir.appendingPathComponent("bull-data-v8.previous.json")

        var recoveryMessage: String?
        let decoder = JSONDecoder()
        let candidates: [(url: URL, label: String)] = [
            (fileURL, "current v3.3 data"),
            (previousFileURL, "the v3.3 previous-good copy"),
            (preImportFileURL, "the v3.3 pre-import safety copy"),
            (legacyV14FileURL, "the preserved v3.2.1 data"),
            (legacyV14PreviousFileURL, "the v3.2.1 previous-good copy"),
            (dir.appendingPathComponent("bull-data-v14.preimport.json"), "the v3.2.1 pre-import safety copy"),
            (legacyV13FileURL, "the preserved v3.1 data"),
            (legacyV13PreviousFileURL, "the v3.1 previous-good copy"),
            (dir.appendingPathComponent("bull-data-v13.preimport.json"), "the v3.1 pre-import safety copy"),
            (legacyV12FileURL, "the preserved v3.0 data"),
            (legacyV12PreviousFileURL, "the v3.0 previous-good copy"),
            (dir.appendingPathComponent("bull-data-v12.preimport.json"), "the v3.0 pre-import safety copy"),
            (legacyV11FileURL, "the preserved v2.9 data"),
            (legacyV11PreviousFileURL, "the v2.9 previous-good copy"),
            (dir.appendingPathComponent("bull-data-v11.preimport.json"), "the v2.9 pre-import safety copy"),
            (legacyFileURL, "the preserved v2.8 data"),
            (legacyPreviousFileURL, "the v2.8 previous-good copy"),
            (dir.appendingPathComponent("bull-data-v10.preimport.json"), "the v2.8 pre-import safety copy"),
            (legacyV9FileURL, "the preserved v2.7 data"),
            (legacyV9PreviousFileURL, "the v2.7 previous-good copy"),
            (dir.appendingPathComponent("bull-data-v9.preimport.json"), "the v2.7 pre-import safety copy"),
            (legacyV8FileURL, "the preserved v2.6 data"),
            (legacyV8PreviousFileURL, "the v2.6 previous-good copy"),
            (dir.appendingPathComponent("bull-data-v8.preimport.json"), "the v2.6 pre-import safety copy")
        ]
        var recovered: (data: BullData, url: URL, label: String)?
        var firstUnreadable: (url: URL, raw: Data)?

        // Try every local generation in preference order. One unreadable new file must not
        // hide a still-valid previous-good or legacy file farther down the chain.
        for candidate in candidates {
            guard let raw = try? Data(contentsOf: candidate.url) else { continue }
            if let decoded = try? decoder.decode(BullData.self, from: raw) {
                recovered = (decoded, candidate.url, candidate.label)
                break
            }
            if firstUnreadable == nil { firstUnreadable = (candidate.url, raw) }
        }

        var unreadableWasPreserved = false
        if let firstUnreadable {
            let stamp = Int(Date().timeIntervalSince1970)
            let recoveryURL = dir.appendingPathComponent("bull-data-recovery-\(stamp).json")
            unreadableWasPreserved = (try? firstUnreadable.raw.write(
                to: recoveryURL,
                options: [.atomic, .completeFileProtection]
            )) != nil
        }

        if let recovered {
            data = recovered.data
            if firstUnreadable != nil {
                recoveryMessage = unreadableWasPreserved
                    ? "Bull restored \(recovered.label) and preserved the first unreadable file for recovery."
                    : "Bull restored \(recovered.label) after a newer local file could not be decoded."
            } else if recovered.url != fileURL {
                recoveryMessage = "Bull restored \(recovered.label) because the current data file was unavailable."
            }
        } else {
            data = BullData()
            if firstUnreadable != nil {
                recoveryMessage = unreadableWasPreserved
                    ? "Bull preserved an unreadable data file for recovery. No valid local generation was available."
                    : "Bull could not decode or preserve the available data file. Avoid entering new data until the original file is recovered."
            }
        }

        if let recoveryMessage { lastError = recoveryMessage }
        migrateToV15()
        repairBuiltInDisplayNames()
        repairBuiltInItemMetadata()
        backfillEventDayKeys()
        let previousOpen = data.settings.lastOpenedTs.map { Date(timeIntervalSince1970: $0 / 1000) }
        if let previousOpen {
            detectGapDates(since: previousOpen)
        }
        data.settings.lastOpenedTs = Self.nowMS
        _ = finalizePastScores()
        let unreadableCurrent = firstUnreadable?.url == fileURL
        let safeToReplaceUnreadableCurrent = recovered != nil || unreadableWasPreserved
        if !unreadableCurrent || safeToReplaceUnreadableCurrent {
            // Never rotate unreadable current bytes into the previous-good slot.
            persist(makeRollingBackup: !unreadableCurrent)
        }
    }

    static var nowMS: Double { Date().timeIntervalSince1970 * 1000 }

    func appBecameActive() {
        if let ms = data.settings.lastOpenedTs {
            detectGapDates(since: Date(timeIntervalSince1970: ms / 1000))
        }
        data.settings.lastOpenedTs = Self.nowMS
        // Also freezes yesterday if the app stayed resident across midnight.
        _ = finalizePastScores()
        persist()
    }

    var todayKey: String { BullDates.key(for: Date()) }
    var selectedKey: String { BullDates.key(for: selectedDate) }
    var isTodaySelected: Bool { BullDates.sameDay(selectedDate, Date()) }

    var selectedDay: DayRecord { data.days[selectedKey] ?? DayRecord() }

    var selectedRisk: Int {
        isTodaySelected ? riskState().currentRisk : risk(for: selectedDate)
    }
    var selectedVigour: Double { sexualVigourState(endingOn: selectedDate).score ?? 0 }

    var latestSexualCheckIn: SexualCheckIn? {
        data.sexualCheckIns
            .filter { $0.ts <= Self.nowMS }
            .max(by: { $0.ts < $1.ts })
    }

    func sexualVigourState(endingOn date: Date = Date()) -> SexualVigourState {
        let dates = BullDates.dateRange(last: 14, endingAt: date)
        let keys = Set(dates.map { BullDates.key(for: $0) })
        let upperBound = BullDates.addingDays(1, to: BullDates.startOfDay(date))
            .timeIntervalSince1970 * 1_000
        return v29SexualVigourState(
            observations: data.dailySexualObservations.filter { $0.ts < upperBound },
            legacyLibidoSpots: data.libidoSpots.filter { $0.ts < upperBound },
            dayKeys: keys
        )
    }

    /// Compares the first 28 programme days with the most recent 28 days. Each window
    /// needs at least eight observed mornings (the 14-day minimum scaled to 28 days), and
    /// the windows must be non-overlapping. This lagging outcome is used only after week 12.
    func erectionHealthTrendChange(
        for plan: ExercisePlanVersion,
        endingOn date: Date = Date()
    ) -> Double? {
        let originKey = plan.programStartDayKey ?? plan.startDayKey
        guard let origin = BullDates.date(from: originKey) else { return nil }
        let elapsed = BullDates.calendar.dateComponents(
            [.day],
            from: BullDates.startOfDay(origin),
            to: BullDates.startOfDay(date)
        ).day ?? -1
        guard elapsed >= 83 else { return nil } // twelve complete seven-day weeks

        let baselineKeys = Set((0..<28).map {
            BullDates.key(for: BullDates.addingDays($0, to: origin))
        })
        let currentKeys = Set(BullDates.dateRange(last: 28, endingAt: date).map {
            BullDates.key(for: $0)
        })
        let baseline = v29SexualVigourState(
            observations: data.dailySexualObservations,
            dayKeys: baselineKeys,
            minimumDaysPerComponent: 1
        )
        let current = v29SexualVigourState(
            observations: data.dailySexualObservations,
            dayKeys: currentKeys,
            minimumDaysPerComponent: 1
        )
        guard baseline.erectionDays >= 8,
              current.erectionDays >= 8,
              let baselineValue = baseline.erectionHealth,
              let currentValue = current.erectionHealth else { return nil }
        return currentValue - baselineValue
    }

    func recoveryComposite(endingOn date: Date = Date()) -> RecoveryCompositeState {
        let current = day(for: date)
        let recentDates = BullDates.dateRange(last: 3, endingAt: date)
        let latestManual = data.manualExerciseLogs.reduce(into: [String: ManualExerciseLog]()) { result, log in
            if result[log.dayKey].map({ $0.loggedTs < log.loggedTs }) ?? true { result[log.dayKey] = log }
        }
        var exercise = 0.0
        var strength = 0
        var loadObserved = false
        for sampleDate in recentDates {
            let key = BullDates.key(for: sampleDate)
            let sample = day(for: sampleDate)
            let manual = latestManual[key]
            let aerobic = manual?.aerobicMinutesOverride ?? sample.aerobicMinutes
            let vigorous = manual?.vigorousMinutesOverride ?? sample.vigorousMinutes
            if aerobic != nil || vigorous != nil {
                loadObserved = true
                exercise += (aerobic ?? 0) + (vigorous ?? 0)
            }
            if let completed = manual?.strengthSessionCompleted {
                loadObserved = true
                if completed { strength += 1 }
            } else if let minutes = sample.strengthMinutes {
                loadObserved = true
                if minutes >= 15 { strength += 1 }
            }
        }
        return v29RecoveryComposite(
            sleepScore: current.vigourSleepForScoring,
            hrv: current.hrv,
            hrvBaseline: hrvBaseline(excluding: date),
            restingHeartRate: current.restingHeartRate,
            restingHeartRateBaseline: restingHeartRateBaseline(excluding: date),
            recentModerateEquivalentMinutes: loadObserved ? exercise : nil,
            recentStrengthSessions: loadObserved ? strength : nil
        )
    }

    func vigourRoutineState(endingOn date: Date = Date()) -> VigourRoutineState {
        let dates = BullDates.dateRange(last: 7, endingAt: date)
        let pairs = dates.map { (key: BullDates.key(for: $0), day: day(for: $0)) }
        let plan = activeExercisePlan(on: date)
        return v29VigourRoutineState(
            daysByKey: pairs,
            manualExerciseLogs: data.manualExerciseLogs.filter { log in pairs.contains { $0.key == log.dayKey } },
            recovery: recoveryComposite(endingOn: date),
            cardioTarget: Double(plan?.weeklyModerateEquivalentTarget ?? 160),
            strengthTarget: plan?.weeklyStrengthTarget ?? 3
        )
    }

    // MARK: - v3.1 four-score model

    func fourScoreState(endingOn date: Date = Date()) -> FourScoreState {
        let dates = BullDates.dateRange(last: 7, endingAt: date)
        let keys = dates.map { BullDates.key(for: $0) }
        let keySet = Set(keys)
        let pairs = dates.map { (key: BullDates.key(for: $0), day: day(for: $0)) }
        let plan = activeExercisePlan(on: date)
        let selectedKey = BullDates.key(for: date)
        let selectedDay = day(for: date)
        let stressRegulation = v31StressRegulationState(
            readings: data.stressReadings,
            dayKey: selectedKey,
            allowProvisional: BullDates.sameDay(date, Date())
        )
        let livePromptAlertIDs = Set(data.riskAlertEvents.compactMap { event -> String? in
            switch event.deliveryState {
            case .attempted, .scheduled, .observedForeground:
                return event.id
            case .failed, .replaced, .cancelled:
                return nil
            }
        })
        let prompts = data.safeguardEvents.filter { event in
            event.dayKey == selectedKey && event.kind == .promptIssued &&
                (event.alertEventID.map(livePromptAlertIDs.contains) ?? true)
        }
        let exposed = Set(prompts.map(\.dayKey))
        let safeguarded: Set<String> = !prompts.isEmpty && prompts.allSatisfy {
            safeguardPromptWasResolved($0, among: data.safeguardEvents)
        } ? [selectedKey] : []
        let environmentProtection: Double
        if BullDates.sameDay(date, Date()) {
            let activeZones = data.highRiskZones.filter {
                $0.enabled && isInsideZone($0.id) && isZoneActive($0, at: date)
            }
            environmentProtection = activeZones.allSatisfy { isZoneSafeguarded($0.id) } ? 100 : 0
        } else {
            environmentProtection = v30EnvironmentProtectionScore(
                exposedZoneDays: exposed,
                safeguardedZoneDays: safeguarded,
                orderedDayKeys: [selectedKey]
            )
        }
        let urgeRoutine = v31UrgeRoutineState(
            sleepScore: selectedDay.preventionSleepForScoring,
            stressRegulationScore: stressRegulation.score,
            environmentProtectionScore: environmentProtection,
            fasting: selectedDay.checks["fasting"] == true
        )
        let urgeState = v31UrgeState(
            observations: data.pornUrgeObservations,
            dayKey: selectedKey
        )
        let v8Start = data.settings.fourScoreV8StartDayKey ?? selectedKey
        let scheduledStrengthDays = Dictionary(uniqueKeysWithValues: dates.compactMap { sampleDate -> (String, ExercisePlanDay)? in
            let key = BullDates.key(for: sampleDate)
            let fastingRestDay = day(for: sampleDate).checks["fasting"] == true
            let completedFastingWorkout = data.strengthWorkoutLogs.contains { log in
                log.dayKey == key && log.sets.contains(where: \.completed)
            }
            guard key >= v8Start,
                  !(fastingRestDay && !completedFastingWorkout),
                  let planDay = planDay(on: sampleDate),
                  !(planDay.strengthExercises?.isEmpty ?? true) else { return nil }
            return (key, planDay)
        })
        let bullRoutine = v31BullRoutineState(
            daysByKey: pairs,
            manualExerciseLogs: data.manualExerciseLogs.filter { keySet.contains($0.dayKey) },
            strengthWorkoutLogs: data.strengthWorkoutLogs.filter { keySet.contains($0.dayKey) },
            scheduledStrengthDays: scheduledStrengthDays,
            cardioTarget: Double(plan?.weeklyModerateEquivalentTarget ?? 160)
        )
        let bullState = v31BullState(
            observations: data.bullStateObservations,
            dayKey: selectedKey
        )
        return FourScoreState(
            urgeRoutine: urgeRoutine,
            urgeState: urgeState,
            bullRoutine: bullRoutine,
            bullState: bullState
        )
    }

    func stressRegulationState(on date: Date = Date()) -> StressRegulationState {
        v31StressRegulationState(
            readings: data.stressReadings,
            dayKey: BullDates.key(for: date),
            allowProvisional: BullDates.sameDay(date, Date())
        )
    }

    /// Momentum is deliberately secondary and uses only finalized v3.1 daily routine
    /// snapshots. Today's acute score never receives credit from an earlier good day.
    func urgeRoutineMomentum(endingOn date: Date = Date()) -> Double? {
        let values = BullDates.dateRange(last: 7, endingAt: date).compactMap { sampleDate -> Double? in
            let key = BullDates.key(for: sampleDate)
            guard let snapshot = data.fourScoreSnapshots[key],
                  snapshot.scoringVersion == currentFourScoreVersion,
                  snapshot.isFinal else { return nil }
            return snapshot.urgeRoutine
        }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    func timeWeightedStress(on date: Date = Date()) -> TimeWeightedStressState {
        let key = BullDates.key(for: date)
        let start = BullDates.startOfDay(date)
        let next = BullDates.addingDays(1, to: start)
        let end = BullDates.sameDay(date, Date()) ? min(Date(), next) : next
        return v30TimeWeightedStress(
            readings: data.stressReadings.filter { $0.dayKey == key },
            dayStartTs: start.timeIntervalSince1970 * 1_000,
            dayEndTs: end.timeIntervalSince1970 * 1_000
        )
    }

    var stressActivityLeaderboard: [StressActivityEffect] {
        v30StressActivityLeaderboard(
            logs: data.stressReliefLogs,
            readings: data.stressReadings,
            activities: data.stressActivities
        )
    }

    func fourScoreSnapshot(on date: Date) -> FourScoreSnapshot? {
        let key = BullDates.key(for: date)
        if key == todayKey { return makeFourScoreSnapshot(for: date, isFinal: false) }
        return data.fourScoreSnapshots[key]
    }

    /// Compatibility projection for v2.8-only charts. New UI reads Sexual Vigour and
    /// Vigour Routine separately and never mixes them into one number.
    func vigourState(endingOn date: Date = Date()) -> VigourState {
        let sexual = sexualVigourState(endingOn: date)
        let routine = vigourRoutineState(endingOn: date)
        return VigourState(
            routineScore: routine.score ?? 0,
            erectionHealth: sexual.erectionHealth,
            libidoReadiness: sexual.healthyDesire,
            bullStrength: sexual.score ?? 0
        )
    }

    func legacyRiskBreakdown(for date: Date) -> RiskBreakdown {
        let d = day(for: date)
        return riskBreakdown(
            day: d, items: data.items,
            accountabilityPenalty: accountabilityPenalty(on: date),
            accountabilityEnabled: data.settings.accountabilityEnabled,
            intentionWeight: data.settings.intentionWeight,
            sleepRiskWeight: data.settings.sleepRiskWeight,
            recoveryRiskWeight: data.settings.recoveryRiskWeight
        )
    }

    /// Compatibility projection for older UI/helpers. In v2.9 each component carries its
    /// own memory; there is no global carryover and personal actions do not silently
    /// subtract points.
    func pressureState(thresholds: PressureThresholds = PressureThresholds()) -> BullPressure {
        let state = riskState(thresholds: thresholds)
        return BullPressure(
            daily: Double(state.baseRisk),
            compounded: Double(state.currentRisk),
            consecutiveHighDays: state.consecutiveElevatedDays,
            tier: state.tier
        )
    }

    func riskState(
        now: Date = Date(),
        thresholds: PressureThresholds = PressureThresholds(watch: 55, warning: 65, emergency: 78)
    ) -> CompoundedRiskState {
        let value = urgeRiskState(at: now, includeLiveContexts: true).score
        var consecutive = 0
        for offset in 0..<7 {
            let date = BullDates.addingDays(-offset, to: now)
            let evaluation = offset == 0 ? now :
                (BullDates.calendar.date(bySettingHour: 23, minute: 59, second: 0, of: date) ?? date)
            if urgeRiskState(at: evaluation, includeLiveContexts: offset == 0).score >= Int(thresholds.watch) {
                consecutive += 1
            } else {
                break
            }
        }
        // Persistence stays visible for alert-repeat policy and Patterns, but it cannot
        // escalate the whole score. v2.9 compounds only inside a factor with real memory
        // (currently sleep/recovery and post-release rebound).
        let tier = v29RiskTier(score: value, thresholds: thresholds)
        return CompoundedRiskState(
            baseRisk: value,
            carryover: 0,
            protection: 0,
            currentRisk: value,
            consecutiveElevatedDays: consecutive,
            tier: tier
        )
    }

    func urgeRiskState(at date: Date = Date(), includeLiveContexts: Bool = true) -> UrgeRiskState {
        let sleep = (0..<3).map { offset in
            day(for: BullDates.addingDays(-offset, to: date)).preventionSleepForScoring
        }
        let nowMS = date.timeIntervalSince1970 * 1_000
        let latestLapseMS = data.relapses
            .filter(countsAsLapse)
            .compactMap { event -> Double? in
                let occurrence = event.occurrence.occurrenceTs ?? event.ts
                return occurrence <= nowMS ? occurrence : nil
            }
            .max()
        let latestWetDreamMS = data.wetDreams
            .compactMap { event -> Double? in
                // The personal delayed-rise hypothesis is anchored to waking, not the time
                // Bull happened to be opened. Fall back to the event timestamp when Health
                // has no wake endpoint for that civil day.
                let anchor = data.days[event.bullDayKey]?.sleepWakeTs ?? event.ts
                return anchor <= nowMS ? anchor : nil
            }
            .max()
        let environment = v29RiskZoneContribution(on: date, includeLiveContexts: includeLiveContexts)
        return v29UrgeRiskState(
            sleepScoresTodayFirst: sleep,
            access: day(for: date).access,
            riskyEnvironmentPoints: environment,
            environmentObserved: !data.highRiskZones.isEmpty ||
                data.zoneEvents.contains(where: { $0.dayKey == BullDates.key(for: date) }),
            hoursSinceLapse: latestLapseMS.map { max(0, nowMS - $0) / 3_600_000 },
            hoursSinceWetDream: latestWetDreamMS.map { max(0, nowMS - $0) / 3_600_000 }
        )
    }

    func baseRisk(for date: Date, includeLiveContexts: Bool) -> Int {
        urgeRiskState(at: date, includeLiveContexts: includeLiveContexts).score
    }

    var selectedHasRelapse: Bool {
        data.relapses.contains { $0.bullDayKey == selectedKey && countsAsLapse($0) }
    }

    var selectedRelapses: [RelapseEvent] {
        data.relapses
            .filter { $0.bullDayKey == selectedKey }
            .sorted { $0.ts > $1.ts }
    }

    var selectedRelapse: RelapseEvent? {
        data.relapses.first { $0.bullDayKey == selectedKey }
    }

    var selectedUrges: [UrgeEvent] {
        data.urges.filter { $0.bullDayKey == selectedKey }
    }

    var selectedWetDream: Bool {
        data.wetDreams.contains { $0.bullDayKey == selectedKey }
    }

    /// Success is only knowable after the civil day has ended: there was at least one urge
    /// and no relapse on that same day. Today's urges are intentionally "pending".
    func urgeDayPassed(key: String) -> Bool? {
        let urges = data.urges.contains { $0.bullDayKey == key }
        guard urges else { return nil }
        if key == todayKey { return nil }
        let relapse = data.relapses.contains { $0.bullDayKey == key && countsAsLapse($0) }
        return !relapse
    }

    func day(for date: Date) -> DayRecord { data.days[BullDates.key(for: date)] ?? DayRecord() }

    func isRiskLogged(for date: Date) -> Bool {
        let key = BullDates.key(for: date)
        return riskLogged(day: data.days[key], items: data.items)
    }

    func risk(for date: Date) -> Int {
        let key = BullDates.key(for: date)
        // A frozen historical value belongs to the model version that produced it. Never
        // reinterpret it merely because the current scoring version changed.
        if key != todayKey, let snap = data.scoreSnapshots[key] { return snap.risk }
        let evaluationDate = key == todayKey ? date :
            (BullDates.calendar.date(bySettingHour: 23, minute: 59, second: 0, of: date) ?? date)
        return baseRisk(for: evaluationDate, includeLiveContexts: key == todayKey)
    }

    /// The seven-day graph uses each day's peak predictive Risk. v2.8/legacy snapshots did
    /// not store a peak, so their frozen end-of-day value is the honest fallback.
    func peakRisk(for date: Date) -> Int {
        let key = BullDates.key(for: date)
        if key == todayKey {
            let live = baseRisk(for: date, includeLiveContexts: true)
            let snapshot = data.scoreSnapshots[key]
            let recorded = snapshot?.scoringVersion == currentScoringVersion
                ? (snapshot?.peakRisk ?? snapshot?.risk ?? live)
                : live
            return max(live, recorded)
        }
        if let snapshot = data.scoreSnapshots[key] {
            return snapshot.peakRisk ?? snapshot.risk
        }
        return risk(for: date)
    }

    func vigour(for date: Date) -> Double {
        let key = BullDates.key(for: date)
        if key != todayKey, let snap = data.scoreSnapshots[key],
           snap.vigourObserved != false { return snap.vigour }
        return sexualVigourState(endingOn: date).score ?? 0
    }

    /// New charts must not relabel a legacy Bull Strength snapshot as Sexual Vigour.
    /// v2.9 snapshots explicitly record whether the output was observed; nil means the
    /// snapshot predates that distinction and remains stored for legacy history only.
    func sexualVigourScore(for date: Date) -> Double? {
        let key = BullDates.key(for: date)
        if key != todayKey, let snapshot = data.scoreSnapshots[key] {
            guard snapshot.vigourObserved == true else { return nil }
            return snapshot.vigour
        }
        return sexualVigourState(endingOn: date).score
    }

    func updateDay(for date: Date? = nil, _ body: (inout DayRecord) -> Void) {
        let target = date ?? selectedDate
        let key = BullDates.key(for: target)
        var d = data.days[key] ?? DayRecord()
        body(&d)
        data.days[key] = d
        // Legacy scoreSnapshots and earlier four-score eras stay immutable. Corrections
        // inside the current era refresh this day plus downstream seven-day routine rows.
        refreshCorrectedFourScoreSnapshots(sourceDayKeys: [key], downstreamDays: 7)
        persist()
    }

    /// Safely backfills HealthKit history in one persistence transaction. Manual/Layla
    /// Sleep scores win and Bull-generated estimates can refresh when Bull versions its own
    /// algorithm. v2.7 imports raw HRV directly for its personal-baseline hypothesis; it
    /// preserves legacy Recovery values but no longer manufactures a duplicate Recovery row.
    @discardableResult
    func applyHealthBackfill(_ imports: [DatedHealthImportResult]) -> Int {
        var changedKeys = Set<String>()

        for dated in imports {
            let key = BullDates.key(for: dated.date)
            var day = data.days[key] ?? DayRecord()
            let r = dated.result
            var changed = false

            let canRefreshRawSleep = day.sleepScoreSource == nil ||
                day.sleepScoreSource == BullSleepScore.sourceIdentifier
            if canRefreshRawSleep, let value = r.sleepHours, day.sleepHours != value {
                day.sleepHours = value; changed = true
            }
            if canRefreshRawSleep, let value = r.sleepWakeTimestampMS, day.sleepWakeTs != value {
                day.sleepWakeTs = value; changed = true
            }

            // Preserve genuinely manual or future Layla scores. Bull-generated sleep scores
            // may be refreshed when the scoring algorithm itself improves.
            let looksLikeLegacyBullEstimate = day.sleepScoreSource == nil &&
                day.sleepDurationPoints != nil && day.sleepConsistencyPoints != nil &&
                day.sleepInterruptionsPoints != nil
            let mayRefreshBullEstimate = day.sleep == nil ||
                day.sleepScoreSource == BullSleepScore.sourceIdentifier || looksLikeLegacyBullEstimate

            if mayRefreshBullEstimate {
                if let value = r.estimatedSleepScore, day.sleep != value { day.sleep = value; changed = true }
                if let value = r.sleepDurationPoints, day.sleepDurationPoints != value { day.sleepDurationPoints = value; changed = true }
                if let value = r.sleepConsistencyPoints, day.sleepConsistencyPoints != value { day.sleepConsistencyPoints = value; changed = true }
                if let value = r.sleepInterruptionsPoints, day.sleepInterruptionsPoints != value { day.sleepInterruptionsPoints = value; changed = true }
                if day.sleepBedtimeDeviationMinutes != r.sleepBedtimeDeviationMinutes { day.sleepBedtimeDeviationMinutes = r.sleepBedtimeDeviationMinutes; changed = true }
                if let value = r.sleepTotalAwakeMinutes, day.sleepTotalAwakeMinutes != value { day.sleepTotalAwakeMinutes = value; changed = true }
                if day.sleepFajrWakeMinutes != r.sleepFajrWakeMinutes { day.sleepFajrWakeMinutes = r.sleepFajrWakeMinutes; changed = true }
                if let value = r.sleepAwakeMinutes, day.sleepAwakeMinutes != value { day.sleepAwakeMinutes = value; changed = true }
                if let value = r.sleepInterruptionCount, day.sleepInterruptionCount != value { day.sleepInterruptionCount = value; changed = true }
                if let source = r.sleepScoreSource, day.sleepScoreSource != source { day.sleepScoreSource = source; changed = true }
                if let version = r.sleepScoreVersion, day.sleepScoreVersion != version { day.sleepScoreVersion = version; changed = true }
            } else {
                if day.sleepDurationPoints == nil, let value = r.sleepDurationPoints { day.sleepDurationPoints = value; changed = true }
                if day.sleepConsistencyPoints == nil, let value = r.sleepConsistencyPoints { day.sleepConsistencyPoints = value; changed = true }
                if day.sleepInterruptionsPoints == nil, let value = r.sleepInterruptionsPoints { day.sleepInterruptionsPoints = value; changed = true }
                if day.sleepBedtimeDeviationMinutes == nil, let value = r.sleepBedtimeDeviationMinutes { day.sleepBedtimeDeviationMinutes = value; changed = true }
                if day.sleepTotalAwakeMinutes == nil, let value = r.sleepTotalAwakeMinutes { day.sleepTotalAwakeMinutes = value; changed = true }
                if day.sleepFajrWakeMinutes == nil, let value = r.sleepFajrWakeMinutes { day.sleepFajrWakeMinutes = value; changed = true }
                if day.sleepAwakeMinutes == nil, let value = r.sleepAwakeMinutes { day.sleepAwakeMinutes = value; changed = true }
                if day.sleepInterruptionCount == nil, let value = r.sleepInterruptionCount { day.sleepInterruptionCount = value; changed = true }
            }

            // Purpose scores have their own provenance so a future Layla/manual value is
            // never overwritten merely because Bull refreshes its generic Health estimate.
            let mayRefreshPurposeScores =
                day.sleepPurposeScoreSource == BullSleepScore.purposeSourceIdentifier ||
                (day.sleepPurposeScoreSource == nil &&
                 (day.sleepScoreSource == nil || day.sleepScoreSource == BullSleepScore.sourceIdentifier))
            if mayRefreshPurposeScores {
                if let value = r.preventionSleepScore, day.preventionSleepScore != value {
                    day.preventionSleepScore = value; changed = true
                }
                if let value = r.vigourSleepScore, day.vigourSleepScore != value {
                    day.vigourSleepScore = value; changed = true
                }
                if let source = r.sleepPurposeScoreSource, day.sleepPurposeScoreSource != source {
                    day.sleepPurposeScoreSource = source; changed = true
                }
                if let version = r.sleepPurposeScoreVersion, day.sleepPurposeScoreVersion != version {
                    day.sleepPurposeScoreVersion = version; changed = true
                }
            }
            let latestLaylaConsistency = data.laylaSleepSchedules
                .filter({ $0.dayKey == key && $0.sleepConsistencyDeviationMinutes != nil })
                .max(by: laylaSnapshotPrecedes)
            if day.sleepPurposeScoreSource != "manual",
               !(day.sleepScoreSource?.hasPrefix("manual") ?? false),
               let laylaDeviation = latestLaylaConsistency?.sleepConsistencyDeviationMinutes,
               let duration = day.sleepDurationPoints,
               let interruptions = day.sleepInterruptionsPoints {
                let boundedDeviation = min(720, max(0, laylaDeviation))
                let consistency = BullSleepScore.consistencyPoints(
                    deviationMinutes: boundedDeviation
                )
                let purpose = BullSleepScore.purposeScores(
                    durationPoints: duration,
                    consistencyPoints: consistency,
                    interruptionPoints: interruptions
                )
                if day.sleepBedtimeDeviationMinutes != boundedDeviation {
                    day.sleepBedtimeDeviationMinutes = boundedDeviation; changed = true
                }
                if day.sleepConsistencyPoints != consistency {
                    day.sleepConsistencyPoints = consistency; changed = true
                }
                if day.preventionSleepScore != purpose.prevention {
                    day.preventionSleepScore = purpose.prevention; changed = true
                }
                if day.vigourSleepScore != purpose.vigour {
                    day.vigourSleepScore = purpose.vigour; changed = true
                }
                if day.sleepPurposeScoreSource != BullSleepScore.laylaPurposeSourceIdentifier {
                    day.sleepPurposeScoreSource = BullSleepScore.laylaPurposeSourceIdentifier
                    changed = true
                }
                if day.sleepPurposeScoreVersion != BullSleepScore.purposeSourceVersion {
                    day.sleepPurposeScoreVersion = BullSleepScore.purposeSourceVersion
                    changed = true
                }
            }

            if let value = r.hrvMilliseconds, day.hrv != value {
                day.hrv = value
                changed = true
            }
            if let value = r.restingHeartRate, day.restingHeartRate != value {
                day.restingHeartRate = value
                changed = true
            }

            if let value = r.aerobicMinutes, day.aerobicMinutes != value {
                day.aerobicMinutes = value; changed = true
            }
            if let value = r.vigorousMinutes, day.vigorousMinutes != value {
                day.vigorousMinutes = value; changed = true
            }
            if let value = r.cardioActiveCalories, day.cardioActiveCalories != value {
                day.cardioActiveCalories = value; changed = true
            }
            if let value = r.cardioIntensitySource, day.cardioIntensitySource != value {
                day.cardioIntensitySource = value; changed = true
            }
            if let value = r.strengthMinutes, day.strengthMinutes != value {
                day.strengthMinutes = value; changed = true
            }

            if changed {
                data.days[key] = day
                changedKeys.insert(key)
            }
        }
        if !changedKeys.isEmpty {
            refreshCorrectedFourScoreSnapshots(sourceDayKeys: changedKeys, downstreamDays: 7)
            persist()
        }
        return changedKeys.count
    }

    func setCheck(_ id: String, value: Bool?) {
        let target = selectedDate
        let definitionVersion = data.items.first(where: { $0.id == id })?.definitionVersion
        updateDay(for: target) { d in
            if let value { d.checks[id] = value }
            else { d.checks.removeValue(forKey: id) }
            if data.items.first(where: { $0.id == id })?.kind == .habit {
                let source: ObservationSource
                if !BullDates.sameDay(target, Date()) {
                    source = .retrospectiveBackfill
                } else if d.completionStates[id]?.loggedTs != nil {
                    source = .prospectiveEdit
                } else {
                    source = .live
                }
                d.completionStates[id] = value.map {
                    CompletionRecord(
                        state: $0 ? .done : .notDone,
                        loggedTs: Self.nowMS,
                        source: source,
                        definitionVersion: definitionVersion
                    )
                }
            }
        }
    }

    func completionRecord(for id: String, on date: Date? = nil) -> CompletionRecord {
        let record = day(for: date ?? selectedDate)
        if let explicit = record.completionStates[id] { return explicit }
        if id == "heartHealthyEating", let value = record.heartHealthyEating {
            return CompletionRecord(state: value ? .done : .notDone, source: .migratedLegacy)
        }
        if let value = record.checks[id] {
            return CompletionRecord(state: value ? .done : .notDone, source: .migratedLegacy)
        }
        return CompletionRecord()
    }

    func setCompletion(
        _ id: String,
        state: CompletionState,
        excuse: CompletionExcuse? = nil,
        on date: Date? = nil
    ) {
        let target = date ?? selectedDate
        let definitionVersion = data.personalFactors.first(where: { $0.id == id })?.definitionVersion ??
            data.items.first(where: { $0.id == id })?.definitionVersion ??
            (id == "heartHealthyEating" ? 1 : nil)
        updateDay(for: target) { day in
            let source: ObservationSource
            if !BullDates.sameDay(target, Date()) {
                source = .retrospectiveBackfill
            } else if day.completionStates[id]?.loggedTs != nil {
                source = .prospectiveEdit
            } else {
                source = .live
            }
            day.completionStates[id] = CompletionRecord(
                state: state,
                excuse: excuse,
                loggedTs: Self.nowMS,
                source: source,
                definitionVersion: definitionVersion
            )
            let legacy: Bool?
            switch state {
            case .done: legacy = true
            case .notDone: legacy = false
            case .excused, .unknown: legacy = nil
            }
            if id == "heartHealthyEating" {
                day.heartHealthyEating = legacy
            } else if let legacy {
                day.checks[id] = legacy
            } else {
                day.checks.removeValue(forKey: id)
            }
        }
    }

    func bullFuelPercent(on date: Date? = nil) -> Int? {
        let record = day(for: date ?? selectedDate)
        if let direct = record.bullFuelPercent { return direct }
        if let explicit = record.completionStates["heartHealthyEating"] {
            if explicit.state == .done { return 100 }
            if explicit.state == .notDone { return 0 }
        }
        return record.heartHealthyEating.map { $0 ? 100 : 0 }
    }

    func setBullFuel(_ percent: Int?, on date: Date? = nil, fasting: Bool? = nil) {
        let target = date ?? selectedDate
        updateDay(for: target) { day in
            let normalized = percent.map { value -> Int in
                if value >= 75 { return 100 }
                if value >= 25 { return 50 }
                return 0
            }
            day.bullFuelPercent = normalized
            // The combined editor saves both existing fields in one transaction.
            // Other callers omit fasting and keep its value unchanged.
            if let fasting {
                if fasting {
                    day.checks["fasting"] = true
                    day.completionStates["fasting"] = CompletionRecord(
                        state: .done, loggedTs: Self.nowMS,
                        source: BullDates.sameDay(target, Date()) ? .live : .retrospectiveBackfill,
                        definitionVersion: 2
                    )
                } else {
                    day.checks.removeValue(forKey: "fasting")
                    day.completionStates.removeValue(forKey: "fasting")
                }
            }
            switch normalized {
            case .some(100):
                day.heartHealthyEating = true
                day.completionStates["heartHealthyEating"] = CompletionRecord(
                    state: .done,
                    loggedTs: Self.nowMS,
                    source: BullDates.sameDay(target, Date()) ? .live : .retrospectiveBackfill,
                    definitionVersion: 2
                )
            case .some(0):
                day.heartHealthyEating = false
                day.completionStates["heartHealthyEating"] = CompletionRecord(
                    state: .notDone,
                    loggedTs: Self.nowMS,
                    source: BullDates.sameDay(target, Date()) ? .live : .retrospectiveBackfill,
                    definitionVersion: 2
                )
            case .some(50):
                day.heartHealthyEating = nil
                day.completionStates.removeValue(forKey: "heartHealthyEating")
            default:
                day.heartHealthyEating = nil
                day.completionStates.removeValue(forKey: "heartHealthyEating")
            }
        }
    }

    func isFasting(on date: Date? = nil) -> Bool {
        day(for: date ?? selectedDate).checks["fasting"] == true
    }

    func setFasting(_ fasting: Bool, on date: Date? = nil) {
        let target = date ?? selectedDate
        updateDay(for: target) { day in
            if fasting {
                day.checks["fasting"] = true
                day.completionStates["fasting"] = CompletionRecord(
                    state: .done,
                    loggedTs: Self.nowMS,
                    source: BullDates.sameDay(target, Date()) ? .live : .retrospectiveBackfill,
                    definitionVersion: 2
                )
            } else {
                day.checks.removeValue(forKey: "fasting")
                day.completionStates.removeValue(forKey: "fasting")
            }
        }
    }

    func saveMorningCommitment(what: String, when: String, whereText: String) {
        let clean = what.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        updateDay { day in
            let existing = day.morningCommitment
            let source: ObservationSource = !isTodaySelected
                ? .retrospectiveBackfill
                : (existing == nil ? .live : .prospectiveEdit)
            day.morningCommitment = MorningCommitment(
                id: existing?.id ?? UUID().uuidString,
                what: clean,
                when: when.trimmingCharacters(in: .whitespacesAndNewlines),
                whereText: whereText.trimmingCharacters(in: .whitespacesAndNewlines),
                committedTs: existing?.committedTs ?? Self.nowMS,
                completion: existing?.completion ?? CompletionRecord(),
                perceivedPurpose: existing?.perceivedPurpose,
                source: source
            )
        }
    }

    func updateMorningCommitmentCompletion(
        _ state: CompletionState,
        excuse: CompletionExcuse? = nil
    ) {
        updateDay { day in
            guard var commitment = day.morningCommitment else { return }
            let source: ObservationSource = !isTodaySelected
                ? .retrospectiveBackfill
                : (commitment.completion.loggedTs == nil ? .live : .prospectiveEdit)
            commitment.completion = CompletionRecord(
                state: state,
                excuse: excuse,
                loggedTs: Self.nowMS,
                source: source
            )
            day.morningCommitment = commitment
        }
    }

    func updateCommitmentPurpose(_ rating: Int?) {
        updateDay { day in
            day.purposeRating = rating.map { min(5, max(1, $0)) }
            if var commitment = day.morningCommitment {
                commitment.perceivedPurpose = day.purposeRating
                day.morningCommitment = commitment
            }
        }
    }

    func saveDailySexualObservation(
        morningErection: MorningErectionObservation,
        erectionHardnessScore: Int?,
        healthyDesire: Int?
    ) {
        let key = selectedKey
        let existingIndex = data.dailySexualObservations.indices
            .filter({ data.dailySexualObservations[$0].dayKey == key })
            .max(by: { data.dailySexualObservations[$0].ts < data.dailySexualObservations[$1].ts })
        let source: ObservationSource = !isTodaySelected
            ? .delayedRecall
            : (existingIndex == nil ? .live : .prospectiveEdit)
        // Keep the retired 0...10 field as historical provenance when this row began in
        // v2.8. v2.9 reads EHS first, so the preserved legacy value cannot override the edit.
        let legacyQuality = existingIndex.flatMap { data.dailySexualObservations[$0].erectionQuality }
        let replacement = DailySexualObservation(
            dayKey: key,
            morningErection: morningErection,
            erectionQuality: legacyQuality,
            erectionHardnessScore: morningErection == .yes ? erectionHardnessScore : nil,
            healthyDesire: healthyDesire,
            source: source
        )
        if let index = existingIndex {
            var value = replacement
            value.id = data.dailySexualObservations[index].id
            data.dailySexualObservations[index] = value
        } else {
            data.dailySexualObservations.append(replacement)
        }
        persist()
    }

    /// Source-compatible bridge for any retained v2.8 caller. New UI uses EHS 1...4 and
    /// healthy desire on the overload above; this bridge preserves an existing desire entry.
    func saveDailySexualObservation(
        morningErection: MorningErectionObservation,
        erectionQuality: Int?
    ) {
        let mappedEHS = erectionQuality.map { min(4, max(1, Int((Double($0) / 2.5).rounded()))) }
        let existingDesire = data.dailySexualObservations
            .filter { $0.dayKey == selectedKey }
            .max(by: { $0.ts < $1.ts })?
            .healthyDesire
        saveDailySexualObservation(
            morningErection: morningErection,
            erectionHardnessScore: mappedEHS,
            healthyDesire: existingDesire
        )
    }

    func saveEjaculatoryControl(
        id: String? = nil,
        perceivedControl: Int,
        soonerThanDesired: Bool,
        bother: Int,
        note: String?,
        on date: Date? = nil
    ) {
        let target = date ?? selectedDate
        let key = BullDates.key(for: target)
        let existing = id.flatMap { targetID in
            data.ejaculatoryControlObservations.first { $0.id == targetID }
        }
        let value = EjaculatoryControlObservation(
            id: existing?.id ?? UUID().uuidString,
            ts: existing?.ts ?? eventTimestampMS(for: target),
            dayKey: key,
            perceivedControl: perceivedControl,
            soonerThanDesired: soonerThanDesired,
            bother: bother,
            note: note,
            modifiedTs: existing == nil ? nil : Self.nowMS,
            source: existing?.source ?? (BullDates.sameDay(target, Date()) ? .live : .delayedRecall)
        )
        if let existing { data.ejaculatoryControlObservations.removeAll { $0.id == existing.id } }
        data.ejaculatoryControlObservations.append(value)
        persist()
    }

    func ejaculatoryControlObservations(on date: Date? = nil) -> [EjaculatoryControlObservation] {
        let key = BullDates.key(for: date ?? selectedDate)
        return data.ejaculatoryControlObservations.enumerated()
            .filter { $0.element.dayKey == key }
            .sorted { lhs, rhs in
                lhs.element.ts == rhs.element.ts ? lhs.offset > rhs.offset : lhs.element.ts > rhs.element.ts
            }
            .map(\.element)
    }

    func deleteEjaculatoryControlObservation(id: String) {
        data.ejaculatoryControlObservations.removeAll { $0.id == id }
        persist()
    }

    func addLibidoSpot(_ rating: Int) {
        data.libidoSpots.append(LibidoSpot(
            dayKey: selectedKey,
            rating: rating,
            source: isTodaySelected ? .live : .delayedRecall
        ))
        persist()
    }

    func removeLibidoSpot(id: String) {
        data.libidoSpots.removeAll { $0.id == id }
        persist()
    }

    func sexualSummary(endingOn date: Date = Date()) -> SexualWeekSummary {
        let keys = Set(BullDates.dateRange(last: 7, endingAt: date).map { BullDates.key(for: $0) })
        return sexualWeekSummary(
            observations: data.dailySexualObservations,
            libidoSpots: data.libidoSpots,
            dayKeys: keys
        )
    }

    func activeExercisePlan(on date: Date = Date()) -> ExercisePlanVersion? {
        let key = BullDates.key(for: date)
        let matching = data.exercisePlans
            .filter { plan in
                plan.startDayKey <= key && (plan.endDayKey.map { key <= $0 } ?? true)
            }
            .max { left, right in
                if left.startDayKey == right.startDayKey {
                    return left.versionNumber < right.versionNumber
                }
                return left.startDayKey < right.startDayKey
            }
        if let matching { return matching }
        // Before the programme begins, show its earliest upcoming version as a preview.
        // Never attach a later version to a pre-programme historical date.
        return data.exercisePlans
            .filter { $0.startDayKey > key }
            .min { left, right in
                if left.startDayKey == right.startDayKey {
                    return left.versionNumber < right.versionNumber
                }
                return left.startDayKey < right.startDayKey
            }
    }

    func planDay(on date: Date = Date()) -> ExercisePlanDay? {
        guard let plan = activeExercisePlan(on: date),
              let start = BullDates.date(from: plan.startDayKey) else { return nil }
        let weekday = BullDates.calendar.component(.weekday, from: date)
        if let scheduled = plan.days.first(where: { $0.weekday == weekday }) {
            return scheduled
        }
        let offset = BullDates.calendar.dateComponents(
            [.day],
            from: BullDates.startOfDay(start),
            to: BullDates.startOfDay(date)
        ).day ?? 0
        guard offset >= 0 else { return nil }
        let number = offset % 7 + 1
        return plan.days.first { $0.dayNumber == number }
    }

    func manualExerciseLog(on date: Date = Date()) -> ManualExerciseLog? {
        let key = BullDates.key(for: date)
        return data.manualExerciseLogs
            .filter { $0.dayKey == key }
            .max { $0.loggedTs < $1.loggedTs }
    }

    func saveManualExercise(
        on date: Date = Date(),
        aerobicMinutesOverride: Double?,
        vigorousMinutesOverride: Double?,
        strengthSessionCompleted: Bool?,
        notes: String?
    ) {
        let key = BullDates.key(for: date)
        let existing = manualExerciseLog(on: date)
        let log = ManualExerciseLog(
            id: existing?.id ?? UUID().uuidString,
            dayKey: key,
            aerobicMinutesOverride: aerobicMinutesOverride,
            vigorousMinutesOverride: vigorousMinutesOverride,
            strengthSessionCompleted: strengthSessionCompleted,
            planDayID: planDay(on: date)?.id,
            notes: notes
        )
        data.manualExerciseLogs.removeAll { $0.id == log.id }
        data.manualExerciseLogs.append(log)
        refreshCorrectedFourScoreSnapshots(sourceDayKeys: [key], downstreamDays: 7)
        persist()
    }

    func strengthWorkoutLog(on date: Date = Date()) -> StrengthWorkoutLog? {
        let key = BullDates.key(for: date)
        return data.strengthWorkoutLogs
            .filter { $0.dayKey == key }
            .max { $0.ts < $1.ts }
    }

    func saveStrengthWorkout(
        on date: Date = Date(),
        sets: [StrengthSetLog],
        completed: Bool,
        note: String?
    ) {
        let key = BullDates.key(for: date)
        let existing = strengthWorkoutLog(on: date)
        let plan = activeExercisePlan(on: date)
        let value = StrengthWorkoutLog(
            id: existing?.id ?? UUID().uuidString,
            ts: existing?.ts ?? eventTimestampMS(for: date),
            dayKey: key,
            planID: plan?.id,
            planDayID: planDay(on: date)?.id,
            sets: sets,
            completed: completed,
            completedTs: completed ? Self.nowMS : nil,
            note: note
        )
        data.strengthWorkoutLogs.removeAll { $0.id == value.id }
        data.strengthWorkoutLogs.append(value)
        refreshCorrectedFourScoreSnapshots(sourceDayKeys: [key], downstreamDays: 7)
        persist()
    }

    func saveStrengthWorkout(on date: Date = Date(), sets: [StrengthSetLog]) {
        let allPlannedSetsComplete = !sets.isEmpty && sets.allSatisfy(\.completed)
        saveStrengthWorkout(
            on: date,
            sets: sets,
            completed: allPlannedSetsComplete,
            note: nil
        )
    }

    /// Saves an editable weekday prescription without rewriting a completed historical
    /// week. If the active version predates today, Bull closes it yesterday and creates a
    /// new version today; repeated edits today update that new version in place.
    func saveExercisePlanDay(_ editedDay: ExercisePlanDay, on date: Date = Date()) {
        guard let active = activeExercisePlan(on: date),
              let index = data.exercisePlans.firstIndex(where: { $0.id == active.id }) else { return }
        let today = BullDates.key(for: date)
        if data.exercisePlans[index].startDayKey >= today {
            // An upcoming plan has no completed history to protect. Keep its intended
            // start date and edit that future version in place instead of starting it now.
            data.exercisePlans[index].days = applyingExercisePlanDay(
                editedDay,
                to: data.exercisePlans[index].days,
                planStartDayKey: data.exercisePlans[index].startDayKey
            )
        } else {
            let yesterday = BullDates.key(for: BullDates.addingDays(-1, to: date))
            data.exercisePlans[index].endDayKey = yesterday
            let days = applyingExercisePlanDay(
                editedDay, to: active.days, planStartDayKey: active.startDayKey
            )
            data.exercisePlans.append(ExercisePlanVersion(
                versionNumber: (data.exercisePlans.map(\.versionNumber).max() ?? active.versionNumber) + 1,
                startDayKey: today,
                programStartDayKey: active.programStartDayKey ?? active.startDayKey,
                phase: active.phase,
                weeklyModerateEquivalentTarget: active.weeklyModerateEquivalentTarget,
                weeklyStrengthTarget: active.weeklyStrengthTarget,
                days: days,
                rationale: "User-edited weekday and exercise prescription.",
                boxingRounds: active.boxingRounds,
                lastProgressionFocus: active.lastProgressionFocus
            ))
        }
        persist()
    }

    /// Keeps weekday assignments unique. Moving one existing day onto another's weekday
    /// swaps the displaced day back to the edited day's previous weekday when possible.
    private func applyingExercisePlanDay(
        _ editedDay: ExercisePlanDay,
        to source: [ExercisePlanDay],
        planStartDayKey: String
    ) -> [ExercisePlanDay] {
        var days = source
        if let dayIndex = days.firstIndex(where: { $0.id == editedDay.id }) {
            let previousWeekday = days[dayIndex].weekday ?? {
                guard let start = BullDates.date(from: planStartDayKey) else {
                    return days[dayIndex].dayNumber
                }
                let scheduled = BullDates.addingDays(days[dayIndex].dayNumber - 1, to: start)
                return BullDates.calendar.component(.weekday, from: scheduled)
            }()
            if let newWeekday = editedDay.weekday,
               let conflictIndex = days.firstIndex(where: {
                   $0.id != editedDay.id && $0.weekday == newWeekday
               }) {
                days[conflictIndex].weekday = previousWeekday
            }
            days[dayIndex] = editedDay
        } else if let weekday = editedDay.weekday,
                  let dayIndex = days.firstIndex(where: { $0.weekday == weekday }) {
            days[dayIndex] = editedDay
        } else {
            days.append(editedDay)
        }
        return days.sorted { $0.dayNumber < $1.dayNumber }
    }

    func proposedExerciseReview(on date: Date = Date()) -> ExerciseWeekReview? {
        guard let plan = activeExercisePlan(on: date),
              let start = BullDates.date(from: plan.startDayKey) else { return nil }
        let elapsed = max(0, BullDates.calendar.dateComponents(
            [.day], from: BullDates.startOfDay(start), to: BullDates.startOfDay(date)
        ).day ?? 0)
        // Offer a decision only after a complete seven-day prescription. Keep the most
        // recently completed week available until the person explicitly decides.
        guard elapsed >= 6 else { return nil }
        let completedWeekIndex = (elapsed - 6) / 7
        let weekStart = BullDates.addingDays(completedWeekIndex * 7, to: start)
        let key = BullDates.key(for: weekStart)
        if let existing = data.exerciseWeekReviews.first(where: {
            $0.planID == plan.id && $0.weekStartDayKey == key
        }) { return existing }
        let origin = BullDates.date(from: plan.programStartDayKey ?? plan.startDayKey) ?? start
        let programmeElapsed = max(0, BullDates.calendar.dateComponents(
            [.day],
            from: BullDates.startOfDay(origin),
            to: BullDates.startOfDay(date)
        ).day ?? 0)
        let completedWeeks = max(1, (programmeElapsed + 1) / 7)
        let suggestion = v29ExerciseDecision(
            weeksSincePlanStart: completedWeeks,
            routine: vigourRoutineState(endingOn: date),
            recovery: recoveryComposite(endingOn: date),
            erectionChangeFrom28DayBaseline: erectionHealthTrendChange(for: plan, endingOn: date)
        )
        return ExerciseWeekReview(
            planID: plan.id,
            weekStartDayKey: key,
            proposedDecision: suggestion.decision,
            rationale: suggestion.rationale
        )
    }

    /// A plan version changes only after an explicit Accept/Edit/Hold choice. Accepting a
    /// proposal starts the next version tomorrow and closes the current version today.
    func decideExerciseReview(
        _ review: ExerciseWeekReview,
        decision: ExercisePlanDecision,
        progressionFocus: ExerciseProgressionFocus? = nil,
        note: String? = nil
    ) {
        guard decision != .progress || progressionFocus != nil else {
            lastError = "Choose the one exercise variable to progress. Bull will not select one automatically."
            return
        }
        var saved = review
        saved.acceptedDecision = decision
        saved.acceptedProgressionFocus = decision == .progress ? progressionFocus : nil
        saved.decidedTs = Self.nowMS
        saved.note = note
        data.exerciseWeekReviews.removeAll { $0.id == saved.id }
        data.exerciseWeekReviews.append(saved)
        if let currentIndex = data.exercisePlans.firstIndex(where: { $0.id == review.planID }) {
            let today = Date()
            let current = data.exercisePlans[currentIndex]
            let origin = BullDates.date(from: current.programStartDayKey ?? current.startDayKey)
            let reviewStart = BullDates.date(from: review.weekStartDayKey)
            let reviewedWeek = origin.flatMap { origin in
                reviewStart.map { reviewStart in
                    max(1, (BullDates.calendar.dateComponents(
                        [.day],
                        from: BullDates.startOfDay(origin),
                        to: BullDates.startOfDay(reviewStart)
                    ).day ?? 0) / 7 + 1)
                }
            }
            data.exercisePlans[currentIndex].endDayKey = BullDates.key(for: today)
            let nextStart = BullDates.key(for: BullDates.addingDays(1, to: today))
            data.exercisePlans.append(v29PlanVersion(
                from: data.exercisePlans[currentIndex],
                applying: decision,
                startDayKey: nextStart,
                progressionFocus: progressionFocus,
                phaseOverride: decision == .hold && reviewedWeek.map({ $0 % 6 == 5 }) == true
                    ? .consolidate
                    : nil
            ))
        }
        persist()
    }

    func scheduleCountermoves(
        urgeID: String?,
        responseIDs: [String],
        intensityBefore: UrgeIntensity?,
        stressBefore: Int?,
        lane: ProtectiveActionLane = .countermove,
        alertEventID: String? = nil
    ) -> [ResponseAttempt] {
        let now = Self.nowMS
        let due = now + Double(data.settings.interventionFollowUpMinutes) * 60_000
        let attempts = responseIDs.map { responseID in
            ResponseAttempt(
                urgeID: urgeID,
                responseID: responseID,
                ts: now,
                completedTs: nil,
                intensityBefore: intensityBefore,
                intensityAfter: nil,
                stressBefore: stressBefore,
                stressAfter: nil,
                dayKey: todayKey,
                followUpDueTs: due,
                actionLane: lane
            )
        }
        data.responseAttempts.append(contentsOf: attempts)
        if let alertEventID,
           let index = data.riskAlertEvents.firstIndex(where: { $0.id == alertEventID }) {
            data.riskAlertEvents[index].selectedInterventionIDs = responseIDs
            data.riskAlertEvents[index].action = .startResponse
            data.riskAlertEvents[index].acknowledgedTs = now
        }
        persist()
        return attempts
    }

    var pendingCountermoveAttempts: [ResponseAttempt] {
        data.responseAttempts.filter {
            $0.actionLane == .countermove && $0.followUpRecordedTs == nil
        }
    }

    var dueCountermoveAttempts: [ResponseAttempt] {
        pendingCountermoveAttempts.filter { ($0.followUpDueTs ?? .greatestFiniteMagnitude) <= Self.nowMS }
    }

    func completeCountermoveFollowUp(
        attemptIDs: [String],
        completed: Bool,
        helpfulness: InterventionHelpfulness?,
        intensityAfter: UrgeIntensity?,
        stressAfter: Int?
    ) {
        let now = Self.nowMS
        for id in attemptIDs {
            guard let index = data.responseAttempts.firstIndex(where: { $0.id == id }) else { continue }
            data.responseAttempts[index].completedTs = completed ? now : nil
            data.responseAttempts[index].followUpRecordedTs = now
            data.responseAttempts[index].helpfulness = completed ? helpfulness : nil
            data.responseAttempts[index].intensityAfter = completed ? intensityAfter : nil
            data.responseAttempts[index].stressAfter = completed ? stressAfter.map { min(10, max(0, $0)) } : nil
        }
        persist()
    }

    func latestLapseWithin48Hours(at date: Date = Date()) -> RelapseEvent? {
        let nowMS = date.timeIntervalSince1970 * 1_000
        return data.relapses
            .filter(countsAsLapse)
            .filter { event in
                let occurrence = event.occurrence.occurrenceTs ?? event.ts
                return occurrence <= nowMS && nowMS - occurrence < 48 * 3_600_000
            }
            .max { ($0.occurrence.occurrenceTs ?? $0.ts) < ($1.occurrence.occurrenceTs ?? $1.ts) }
    }

    func damageControlLog(for relapseID: String) -> DamageControlLog? {
        data.damageControlLogs
            .filter { $0.relapseID == relapseID }
            .max { $0.updatedTs < $1.updatedTs }
    }

    func setDamageControlStep(_ step: DamageControlStep, completed: Bool, relapseID: String) {
        var log = damageControlLog(for: relapseID) ?? DamageControlLog(
            relapseID: relapseID,
            dayKey: todayKey
        )
        var steps = Set(log.completedSteps)
        var timestamps = log.stepCompletionTs ?? [:]
        if completed {
            steps.insert(step)
            timestamps[step.rawValue] = Self.nowMS
        } else {
            steps.remove(step)
            timestamps.removeValue(forKey: step.rawValue)
        }
        log.completedSteps = Array(steps)
        log.stepCompletionTs = timestamps.isEmpty ? nil : timestamps
        log.updatedTs = Self.nowMS
        data.damageControlLogs.removeAll { $0.id == log.id }
        data.damageControlLogs.append(log)
        persist()
    }

    func addDamageControlCheckIn(
        relapseID: String,
        repeatPull: Int,
        recoveryMood: Int,
        feelsRecovered: Bool
    ) {
        var log = damageControlLog(for: relapseID) ?? DamageControlLog(
            relapseID: relapseID,
            dayKey: todayKey
        )
        var checks = log.checkIns ?? []
        checks.append(DamageControlCheckIn(
            repeatPull: repeatPull,
            recoveryMood: recoveryMood,
            feelsRecovered: feelsRecovered
        ))
        log.checkIns = checks
        log.updatedTs = Self.nowMS
        data.damageControlLogs.removeAll { $0.id == log.id }
        data.damageControlLogs.append(log)
        persist()
    }

    func logUrge(intensity: UrgeIntensity? = nil, stress: Int? = nil) -> UrgeEvent {
        let u = UrgeEvent(ts: Self.nowMS, dayKey: todayKey, intensity: intensity, stress: stress)
        data.urges.append(u)
        persist()
        return u
    }

    @discardableResult
    func beginUrgeSupport(intensity: Int) -> UrgeEvent {
        let bounded = min(10, max(0, intensity))
        let legacy: UrgeIntensity = bounded <= 3 ? .low : (bounded <= 6 ? .medium : .high)
        let urge = UrgeEvent(ts: Self.nowMS, dayKey: todayKey, intensity: legacy)
        data.urges.append(urge)
        data.pornUrgeObservations.append(PornUrgeObservation(
            ts: urge.ts,
            dayKey: todayKey,
            intensity: bounded,
            context: .urgeBefore,
            urgeEventID: urge.id
        ))
        persist()
        return urge
    }

    func completeUrgeSupport(
        urgeID: String,
        intensityAfter: Int?,
        triggerIDs: [String],
        additionalResponseIDs: [String]
    ) {
        let now = Self.nowMS
        if let index = data.urges.firstIndex(where: { $0.id == urgeID }) {
            data.urges[index].triggerIDs = triggerIDs
            data.urges[index].triggers = triggerIDs.compactMap { id in
                data.triggerLibrary.first(where: { $0.id == id })?.name
            }
            let responseIDs = Array(Set(["response.sigh"] + additionalResponseIDs)).sorted()
            data.urges[index].responses = responseIDs.compactMap { id in
                data.responseLibrary.first(where: { $0.id == id })?.name
            }
            for responseID in responseIDs {
                if !data.responseAttempts.contains(where: {
                    $0.urgeID == urgeID && $0.responseID == responseID && $0.completedTs != nil
                }) {
                    data.responseAttempts.append(ResponseAttempt(
                        urgeID: urgeID,
                        responseID: responseID,
                        ts: now,
                        completedTs: now,
                        dayKey: todayKey
                    ))
                }
            }
        }
        if let intensityAfter {
            data.pornUrgeObservations.append(PornUrgeObservation(
                ts: now,
                dayKey: todayKey,
                intensity: intensityAfter,
                context: .urgeAfter,
                urgeEventID: urgeID
            ))
        }
        if !data.stressReliefLogs.contains(where: { $0.urgeEventID == urgeID && $0.activityID == "stress.physiological-sigh" }) {
            data.stressReliefLogs.append(StressReliefLog(
                ts: now,
                dayKey: todayKey,
                activityID: "stress.physiological-sigh",
                urgeEventID: urgeID,
                source: .urgeFlow,
                timing: .prospective,
                startedTs: now,
                completedTs: now
            ))
        }
        persist()
    }

    func logUrgeState(_ intensity: Int, on date: Date? = nil) {
        let target = date ?? selectedDate
        let key = BullDates.key(for: target)
        data.pornUrgeObservations.append(PornUrgeObservation(
            ts: eventTimestampMS(for: target),
            dayKey: key,
            intensity: intensity,
            context: intensity == 0 ? .explicitNoUrge : .checkIn,
            source: BullDates.sameDay(target, Date()) ? .live : .delayedRecall
        ))
        refreshCorrectedFourScoreSnapshots(sourceDayKeys: [key], downstreamDays: 1)
        persist()
    }

    func pornUrgeObservations(on date: Date? = nil) -> [PornUrgeObservation] {
        let key = BullDates.key(for: date ?? selectedDate)
        return data.pornUrgeObservations.enumerated()
            .filter { $0.element.dayKey == key }
            .sorted { lhs, rhs in
                lhs.element.ts == rhs.element.ts ? lhs.offset > rhs.offset : lhs.element.ts > rhs.element.ts
            }
            .map(\.element)
    }

    func updatePornUrgeObservation(id: String, intensity: Int) {
        guard let index = data.pornUrgeObservations.firstIndex(where: { $0.id == id }) else { return }
        let key = data.pornUrgeObservations[index].dayKey
        data.pornUrgeObservations[index].intensity = min(10, max(0, intensity))
        data.pornUrgeObservations[index].source = .prospectiveEdit
        if data.pornUrgeObservations[index].context == .checkIn ||
            data.pornUrgeObservations[index].context == .explicitNoUrge {
            data.pornUrgeObservations[index].context = intensity == 0 ? .explicitNoUrge : .checkIn
        }
        refreshCorrectedFourScoreSnapshots(sourceDayKeys: [key], downstreamDays: 1)
        persist()
    }

    func deletePornUrgeObservation(id: String) {
        let key = data.pornUrgeObservations.first(where: { $0.id == id })?.dayKey
        data.pornUrgeObservations.removeAll { $0.id == id }
        if let key { refreshCorrectedFourScoreSnapshots(sourceDayKeys: [key], downstreamDays: 1) }
        persist()
    }

    func logStressCheckIn(_ value: Int, on date: Date? = nil) {
        let target = date ?? selectedDate
        let isLive = BullDates.sameDay(target, Date())
        data.stressReadings.append(StressReading(
            ts: eventTimestampMS(for: target),
            dayKey: BullDates.key(for: target),
            value: value,
            context: .checkIn,
            source: isLive ? .live : .retrospective
        ))
        // Keep the old single field as export provenance for older builds. v3.0 never reads
        // it as the daily average.
        var legacyDay = data.days[BullDates.key(for: target)] ?? DayRecord()
        legacyDay.stressLevel = min(10, max(0, value))
        data.days[BullDates.key(for: target)] = legacyDay
        refreshCorrectedFourScoreSnapshots(
            sourceDayKeys: [BullDates.key(for: target)], downstreamDays: 1
        )
        persist()
    }

    func stressCheckIn(
        _ context: StressReadingContext,
        on date: Date? = nil
    ) -> StressReading? {
        let key = BullDates.key(for: date ?? selectedDate)
        return data.stressReadings
            .filter { $0.dayKey == key && $0.context == context }
            .max { lhs, rhs in lhs.ts == rhs.ts ? lhs.id < rhs.id : lhs.ts < rhs.ts }
    }

    func saveStressCheckIn(
        _ value: Int,
        context: StressReadingContext,
        on date: Date? = nil
    ) {
        guard context == .morning || context == .evening else {
            logStressCheckIn(value, on: date)
            return
        }
        let target = date ?? selectedDate
        let key = BullDates.key(for: target)
        let existing = stressCheckIn(context, on: target)
        let timestamp: Double
        if let existing {
            timestamp = existing.ts
        } else if BullDates.sameDay(target, Date()) {
            timestamp = Self.nowMS
        } else {
            let hour = context == .morning ? 8 : 21
            let fixed = BullDates.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: target)
                ?? BullDates.startOfDay(target)
            timestamp = fixed.timeIntervalSince1970 * 1_000
        }
        let reading = StressReading(
            id: existing?.id ?? UUID().uuidString,
            ts: timestamp,
            dayKey: key,
            value: value,
            context: context,
            source: BullDates.sameDay(target, Date()) ? .live : .retrospective
        )
        if let existing {
            data.stressReadings.removeAll { $0.id == existing.id }
        }
        data.stressReadings.append(reading)
        var legacyDay = data.days[key] ?? DayRecord()
        legacyDay.stressLevel = min(10, max(0, value))
        data.days[key] = legacyDay
        refreshCorrectedFourScoreSnapshots(sourceDayKeys: [key], downstreamDays: 1)
        persist()
    }

    func deleteStressCheckIn(_ context: StressReadingContext, on date: Date? = nil) {
        let target = date ?? selectedDate
        let key = BullDates.key(for: target)
        data.stressReadings.removeAll { $0.dayKey == key && $0.context == context }
        refreshCorrectedFourScoreSnapshots(sourceDayKeys: [key], downstreamDays: 1)
        persist()
    }

    var pendingStressReliefLogs: [StressReliefLog] {
        data.stressReliefLogs
            .filter(\.isPending)
            .sorted { ($0.startedTs ?? $0.ts) > ($1.startedTs ?? $1.ts) }
    }

    @discardableResult
    func startStressRelief(
        activityID: String,
        stressBefore: Int,
        on date: Date = Date()
    ) -> StressReliefLog {
        let timestamp = BullDates.sameDay(date, Date()) ? Self.nowMS : eventTimestampMS(for: date)
        let key = BullDates.key(for: date)
        let logID = UUID().uuidString
        let before = StressReading(
            ts: timestamp,
            dayKey: key,
            value: stressBefore,
            context: .activityBefore,
            source: BullDates.sameDay(date, Date()) ? .live : .retrospective,
            activityLogID: logID
        )
        let log = StressReliefLog(
            id: logID,
            ts: timestamp,
            dayKey: key,
            activityID: activityID,
            beforeReadingID: before.id,
            source: .manual,
            timing: .prospective,
            startedTs: timestamp
        )
        data.stressReadings.append(before)
        data.stressReliefLogs.append(log)
        persist()
        return log
    }

    func completeStressRelief(
        logID: String,
        stressAfter: Int,
        mindfulnessScore: Double? = nil,
        at date: Date = Date()
    ) {
        guard let index = data.stressReliefLogs.firstIndex(where: { $0.id == logID && $0.isPending }) else {
            return
        }
        let timestamp = Self.nowMS
        let reading = StressReading(
            ts: timestamp,
            dayKey: BullDates.key(for: date),
            value: stressAfter,
            context: .activityAfter,
            source: .live,
            activityLogID: logID
        )
        data.stressReadings.append(reading)
        data.stressReliefLogs[index].afterReadingID = reading.id
        data.stressReliefLogs[index].completedTs = timestamp
        data.stressReliefLogs[index].mindfulnessScore = mindfulnessScore.map { min(100, max(0, $0)) }
        if let started = data.stressReliefLogs[index].startedTs {
            data.stressReliefLogs[index].durationMinutes = max(1, Int((timestamp - started) / 60_000))
        }
        persist()
    }

    func cancelPendingStressRelief(logID: String) {
        guard let log = data.stressReliefLogs.first(where: { $0.id == logID && $0.isPending }) else { return }
        let linked = Set([log.beforeReadingID, log.afterReadingID, log.laterReadingID].compactMap { $0 })
        data.stressReadings.removeAll { linked.contains($0.id) }
        data.stressReliefLogs.removeAll { $0.id == logID }
        persist()
    }

    func logStressRelief(
        activityID: String,
        durationMinutes: Int?,
        stressBefore: Int,
        stressAfter: Int,
        delayedAfter: Bool = false,
        followUpDelayMinutes: Int = 0,
        mindfulnessScore: Double? = nil,
        note: String? = nil,
        on date: Date = Date()
    ) {
        let readingTs = BullDates.sameDay(date, Date()) ? Self.nowMS : eventTimestampMS(for: date)
        let duration = max(1, durationMinutes ?? 1)
        let delay = delayedAfter ? max(0, followUpDelayMinutes) : 0
        let activityEndTs = readingTs - Double(delay) * 60_000
        let start = activityEndTs - Double(duration) * 60_000
        let activityKey = BullDates.key(for: Date(timeIntervalSince1970: activityEndTs / 1_000))
        let readingKey = BullDates.key(for: Date(timeIntervalSince1970: readingTs / 1_000))
        let startKey = BullDates.key(for: Date(timeIntervalSince1970: start / 1_000))
        let logID = UUID().uuidString
        let before = StressReading(
            ts: start,
            dayKey: startKey,
            value: stressBefore,
            context: .activityBefore,
            source: .retrospective,
            activityLogID: logID
        )
        let after = StressReading(
            ts: readingTs,
            dayKey: readingKey,
            value: stressAfter,
            context: delayedAfter ? .activityLater : .activityAfter,
            source: BullDates.sameDay(date, Date()) ? .live : .retrospective,
            activityLogID: logID
        )
        data.stressReadings.append(contentsOf: [before, after])
        data.stressReliefLogs.append(StressReliefLog(
            id: logID,
            ts: activityEndTs,
            dayKey: activityKey,
            activityID: activityID,
            durationMinutes: durationMinutes,
            beforeReadingID: before.id,
            afterReadingID: delayedAfter ? nil : after.id,
            laterReadingID: delayedAfter ? after.id : nil,
            source: .manual,
            timing: .estimatedAfterwards,
            startedTs: start,
            completedTs: readingTs,
            mindfulnessScore: mindfulnessScore,
            note: note
        ))
        refreshCorrectedFourScoreSnapshots(
            sourceDayKeys: Set([startKey, activityKey, readingKey]),
            downstreamDays: 1
        )
        persist()
    }

    func saveStressActivity(_ activity: StressActivityDefinition) {
        if let index = data.stressActivities.firstIndex(where: { $0.id == activity.id }) {
            data.stressActivities[index] = activity
        } else {
            data.stressActivities.append(activity)
        }
        persist()
    }

    func addWakeErectionObservation(
        wakeLabel: String,
        erection: MorningErectionObservation,
        erectionHardnessScore: Int?
    ) {
        data.wakeErectionObservations.append(WakeErectionObservation(
            ts: eventTimestampMS(for: selectedDate),
            dayKey: selectedKey,
            wakeLabel: wakeLabel,
            erection: erection,
            erectionHardnessScore: erectionHardnessScore,
            source: isTodaySelected ? .live : .delayedRecall
        ))
        persist()
    }

    func bullStateObservations(on date: Date? = nil) -> [BullStateObservation] {
        let key = BullDates.key(for: date ?? selectedDate)
        return data.bullStateObservations.enumerated()
            .filter { $0.element.dayKey == key }
            .sorted { lhs, rhs in
                lhs.element.ts == rhs.element.ts ? lhs.offset > rhs.offset : lhs.element.ts > rhs.element.ts
            }
            .map(\.element)
    }

    func saveBullStateObservation(
        id: String? = nil,
        wakeLabel: String,
        erection: MorningErectionObservation,
        erectionHardnessScore: Int?,
        healthyDesire: Int? = nil,
        erectionDurationSeconds: Double? = nil,
        kind: BullStateObservationKind? = nil,
        on date: Date? = nil
    ) {
        let target = date ?? selectedDate
        let existing = id.flatMap { targetID in
            data.bullStateObservations.first { $0.id == targetID }
        }
        let normalizedWake: String = switch wakeLabel.lowercased() {
        case "fajr", "fajr wake", "dawn wake": "Dawn"
        case "final wake": "Final Wake"
        case "other wake": "Other Wake"
        default: wakeLabel
        }
        let value = BullStateObservation(
            id: existing?.id ?? UUID().uuidString,
            ts: existing?.ts ?? eventTimestampMS(for: target),
            dayKey: BullDates.key(for: target),
            wakeLabel: normalizedWake,
            erection: erection,
            erectionHardnessScore: erectionHardnessScore,
            healthyDesire: healthyDesire,
            erectionDurationSeconds: erectionDurationSeconds,
            kind: kind,
            source: existing == nil
                ? (BullDates.sameDay(target, Date()) ? .live : .delayedRecall)
                : .prospectiveEdit
        )
        if let existing { data.bullStateObservations.removeAll { $0.id == existing.id } }
        data.bullStateObservations.append(value)
        refreshCorrectedFourScoreSnapshots(
            sourceDayKeys: [BullDates.key(for: target)], downstreamDays: 1
        )
        persist()
    }

    func deleteBullStateObservation(id: String) {
        let key = data.bullStateObservations.first(where: { $0.id == id })?.dayKey
        data.bullStateObservations.removeAll { $0.id == id }
        if let key { refreshCorrectedFourScoreSnapshots(sourceDayKeys: [key], downstreamDays: 1) }
        persist()
    }

    func deleteWakeErectionObservation(id: String) {
        data.wakeErectionObservations.removeAll { $0.id == id }
        persist()
    }

    func saveHealthyDesire(_ value: Int?) {
        let existing = data.dailySexualObservations
            .filter { $0.dayKey == selectedKey }
            .max { $0.ts < $1.ts }
        saveDailySexualObservation(
            morningErection: existing?.morningErection ?? .notObserved,
            erectionHardnessScore: existing?.erectionHardnessScore,
            healthyDesire: value
        )
    }

    func updateUrge(
        id: String,
        triggerIDs: [String],
        intensity: UrgeIntensity?,
        stress: Int?,
        matchedPlanID: String?
    ) {
        guard let i = data.urges.firstIndex(where: { $0.id == id }) else { return }
        let names = triggerIDs.compactMap { id in
            data.triggerLibrary.first(where: { $0.id == id })?.name
        }
        data.urges[i].triggerIDs = triggerIDs
        data.urges[i].triggers = names
        data.urges[i].intensity = intensity
        data.urges[i].stress = stress.map { min(10, max(0, $0)) }
        data.urges[i].matchedPlanID = matchedPlanID
        persist()
    }

    /// Legacy compatibility used by old sheets/import flows.
    func tagUrge(ts: Double, triggers: [String], responses: [String]) {
        guard let i = data.urges.firstIndex(where: { $0.ts == ts }) else { return }
        data.urges[i].triggers = triggers
        data.urges[i].responses = responses
        persist()
    }

    func completeResponses(
        urgeID: String?,
        responseIDs: [String],
        intensityBefore: UrgeIntensity?,
        intensityAfter: UrgeIntensity?,
        stressBefore: Int?,
        stressAfter: Int?,
        alertEventID: String? = nil
    ) {
        let now = Self.nowMS
        for responseID in responseIDs {
            data.responseAttempts.append(ResponseAttempt(
                urgeID: urgeID,
                responseID: responseID,
                ts: now,
                completedTs: now,
                intensityBefore: intensityBefore,
                intensityAfter: intensityAfter,
                stressBefore: stressBefore,
                stressAfter: stressAfter,
                dayKey: todayKey
            ))
        }
        if let urgeID, let index = data.urges.firstIndex(where: { $0.id == urgeID }) {
            let names = responseIDs.compactMap { id in
                data.responseLibrary.first(where: { $0.id == id })?.name
            }
            data.urges[index].responses = names
        }
        if urgeID != nil || alertEventID != nil {
            let reducedUrge = {
                guard let before = intensityBefore, let after = intensityAfter else { return false }
                return after < before
            }()
            let reducedStress = {
                guard let before = stressBefore, let after = stressAfter else { return false }
                return after < before
            }()
            let affectedAlertIndices = data.riskAlertEvents.indices.filter { index in
                let event = data.riskAlertEvents[index]
                return (urgeID != nil && event.linkedUrgeID == urgeID) || event.id == alertEventID
            }
            for index in affectedAlertIndices {
                data.riskAlertEvents[index].selectedInterventionIDs = Array(Set(
                    data.riskAlertEvents[index].selectedInterventionIDs + responseIDs
                )).sorted()
                data.riskAlertEvents[index].completedTs = now
                appendAlertOutcome(
                    reducedUrge || reducedStress ? .responseImproved : .responseNotImproved,
                    to: index,
                    at: now
                )
            }
        }
        persist()
    }

    @discardableResult
    func logRelapse(
        components: Set<LapseComponent>,
        triggerIDs: [String] = [],
        nextAction: String? = nil,
        occurrence: LapseOccurrenceMetadata? = nil
    ) -> RelapseEvent {
        let legacyType: RelapseType = components.contains(.orgasm) ? .orgasm : .edge
        let now = Self.nowMS
        let defaultOccurrence = LapseOccurrenceMetadata(
            occurrenceDayKey: selectedKey,
            occurrenceTs: isTodaySelected ? now : nil,
            timePrecision: isTodaySelected ? .exact : .unknown,
            locationPrecision: .unknown,
            timeZoneIdentifier: TimeZone.current.identifier,
            utcOffsetMinutes: TimeZone.current.secondsFromGMT(for: selectedDate) / 60,
            source: isTodaySelected ? .live : .retrospectiveBackfill,
            timeConfidence: isTodaySelected ? .exact : .unknown,
            locationConfidence: .unknown
        )
        let resolvedOccurrence = occurrence ?? defaultOccurrence
        let resolvedDate = BullDates.date(from: resolvedOccurrence.occurrenceDayKey) ?? selectedDate
        let event = RelapseEvent(
            ts: resolvedOccurrence.occurrenceTs ?? eventTimestampMS(for: resolvedDate),
            dayKey: resolvedOccurrence.occurrenceDayKey,
            type: legacyType,
            triggers: triggerIDs.compactMap { triggerID in
                data.triggerLibrary.first(where: { $0.id == triggerID })?.name
            },
            triggerIDs: triggerIDs,
            components: LapseComponent.allCases.filter { components.contains($0) },
            nextAction: nextAction,
            loggedTs: now,
            occurrence: resolvedOccurrence
        )
        data.relapses.append(event)
        if therapistOversightIsEnabled,
           data.settings.lapsePolicy.counts(components) {
            queueTherapistEvent(TherapistOversightEvent(
                kind: .relapseLogged,
                ts: now,
                dayKey: event.bullDayKey,
                relapseID: event.id,
                message: "Your client logged a relapse for \(event.bullDayKey).",
                requiresAttention: true,
                deduplicationKey: "relapse.\(event.id)"
            ))
        }
        if let occurrenceTs = resolvedOccurrence.occurrenceTs {
            for index in data.riskAlertEvents.indices where
                data.riskAlertEvents[index].dayKey == resolvedOccurrence.occurrenceDayKey &&
                data.riskAlertEvents[index].ts <= occurrenceTs {
                appendAlertOutcome(.lapseLogged, to: index, at: now)
            }
        }
        persist()
        return event
    }

    @discardableResult
    func logRelapse(type: RelapseType) -> RelapseEvent {
        logRelapse(components: type == .edge ? [.masturbation] : [.orgasm])
    }

    func updateSelectedRelapse(type: RelapseType? = nil, triggers: [String]? = nil, nextAction: String? = nil) {
        guard let i = data.relapses.firstIndex(where: { $0.bullDayKey == selectedKey }) else { return }
        if let type { data.relapses[i].type = type }
        if let triggers { data.relapses[i].triggers = triggers }
        if let nextAction { data.relapses[i].nextAction = nextAction }
        persist()
    }

    func updateRelapse(
        id: String,
        components: Set<LapseComponent>,
        triggerIDs: [String],
        nextAction: String?
    ) {
        guard let index = data.relapses.firstIndex(where: { $0.id == id }) else { return }
        data.relapses[index].components = LapseComponent.allCases.filter { components.contains($0) }
        data.relapses[index].type = components.contains(.orgasm) ? .orgasm : .edge
        data.relapses[index].triggerIDs = triggerIDs
        data.relapses[index].triggers = triggerIDs.compactMap { triggerID in
            data.triggerLibrary.first(where: { $0.id == triggerID })?.name
        }
        data.relapses[index].nextAction = nextAction
        persist()
    }

    func updateRelapseOccurrence(id: String, occurrence: LapseOccurrenceMetadata) {
        guard let index = data.relapses.firstIndex(where: { $0.id == id }) else { return }
        data.relapses[index].occurrence = occurrence
        data.relapses[index].dayKey = occurrence.occurrenceDayKey
        if let occurrenceTs = occurrence.occurrenceTs {
            data.relapses[index].ts = occurrenceTs
        }
        persist()
    }

    func removeRelapse(id: String) {
        data.relapses.removeAll { $0.id == id }
        persist()
    }

    func removeSelectedRelapse() {
        guard let first = selectedRelapse else { return }
        removeRelapse(id: first.id)
    }

    func toggleWetDream() {
        if selectedWetDream {
            data.wetDreams.removeAll { $0.bullDayKey == selectedKey }
        } else {
            data.wetDreams.append(WetDreamEvent(ts: eventTimestampMS(for: selectedDate), dayKey: selectedKey))
        }
        persist()
    }

    func saveSexualCheckIn(
        morningErections: Int,
        erectionQuality: Int?,
        libido: Int,
        readiness: Int,
        confidence: Int
    ) {
        let checkIn = SexualCheckIn(
            dayKey: todayKey,
            morningErections: morningErections,
            erectionQuality: erectionQuality,
            libido: libido,
            readiness: readiness,
            confidence: confidence
        )
        let today = BullDates.startOfDay(Date())
        let recentStart = BullDates.addingDays(-6, to: today)
        let recentIndex = data.sexualCheckIns.indices
            .filter {
                let existing = data.sexualCheckIns[$0]
                return existing.ts <= Self.nowMS &&
                    BullDates.startOfDay(existing.bullCivilDate) >= recentStart
            }
            .max { data.sexualCheckIns[$0].ts < data.sexualCheckIns[$1].ts }
        if let recentIndex {
            var replacement = checkIn
            replacement.id = data.sexualCheckIns[recentIndex].id
            data.sexualCheckIns[recentIndex] = replacement
        } else {
            data.sexualCheckIns.append(checkIn)
        }
        persist()
    }

    func saveCurrentSexualState(libido: Int, readiness: Int, confidence: Int) {
        let summary = sexualSummary()
        let weekKeys = Set(BullDates.dateRange(last: 7, endingAt: Date()).map { BullDates.key(for: $0) })
        let qualityValues = data.dailySexualObservations
            .filter { observation in
                observation.morningErection == .yes &&
                weekKeys.contains(observation.dayKey)
            }
            .compactMap(\.erectionQuality)
        let quality = qualityValues.isEmpty ? nil :
            Int((Double(qualityValues.reduce(0, +)) / Double(qualityValues.count)).rounded())
        saveSexualCheckIn(
            morningErections: min(7, summary.yesMornings),
            erectionQuality: quality,
            libido: libido,
            readiness: readiness,
            confidence: confidence
        )
    }

    func addTrigger(named name: String) -> TriggerDefinition? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if let index = data.triggerLibrary.firstIndex(where: {
            $0.name.caseInsensitiveCompare(clean) == .orderedSame
        }) {
            if data.triggerLibrary[index].archived {
                data.triggerLibrary[index].archived = false
                persist()
            }
            return data.triggerLibrary[index]
        }
        let created = TriggerDefinition(name: clean)
        data.triggerLibrary.append(created)
        persist()
        return created
    }

    func updateTrigger(_ trigger: TriggerDefinition) {
        guard let index = data.triggerLibrary.firstIndex(where: { $0.id == trigger.id }) else { return }
        data.triggerLibrary[index] = trigger
        for planIndex in data.plans.indices where data.plans[planIndex].triggerID == trigger.id {
            data.plans[planIndex].trigger = trigger.name
        }
        refreshLegacyTriggerNames()
        persist()
    }

    func mergeTrigger(sourceID: String, into targetID: String) {
        guard sourceID != targetID,
              let source = data.triggerLibrary.first(where: { $0.id == sourceID }),
              let targetIndex = data.triggerLibrary.firstIndex(where: { $0.id == targetID }) else { return }
        if !data.triggerLibrary[targetIndex].aliases.contains(source.name) {
            data.triggerLibrary[targetIndex].aliases.append(source.name)
        }
        for index in data.urges.indices {
            data.urges[index].triggerIDs = Array(Set(data.urges[index].triggerIDs.map { $0 == sourceID ? targetID : $0 }))
        }
        for index in data.relapses.indices {
            data.relapses[index].triggerIDs = Array(Set(data.relapses[index].triggerIDs.map { $0 == sourceID ? targetID : $0 }))
        }
        for index in data.plans.indices where data.plans[index].triggerID == sourceID {
            data.plans[index].triggerID = targetID
            data.plans[index].trigger = data.triggerLibrary[targetIndex].name
        }
        data.triggerLibrary.removeAll { $0.id == sourceID }
        refreshLegacyTriggerNames()
        persist()
    }

    func addResponse(named name: String) -> ResponseDefinition? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if let index = data.responseLibrary.firstIndex(where: {
            $0.name.caseInsensitiveCompare(clean) == .orderedSame
        }) {
            if data.responseLibrary[index].archived {
                data.responseLibrary[index].archived = false
                persist()
            }
            return data.responseLibrary[index]
        }
        let created = ResponseDefinition(name: clean, lane: .countermove)
        data.responseLibrary.append(created)
        persist()
        return created
    }

    func updateResponse(_ response: ResponseDefinition) {
        guard let index = data.responseLibrary.firstIndex(where: { $0.id == response.id }) else { return }
        data.responseLibrary[index] = response
        refreshLegacyResponseNames(for: response.id)
        persist()
    }

    func mergeResponse(sourceID: String, into targetID: String) {
        guard sourceID != targetID,
              let source = data.responseLibrary.first(where: { $0.id == sourceID }),
              let targetIndex = data.responseLibrary.firstIndex(where: { $0.id == targetID }) else { return }
        if !data.responseLibrary[targetIndex].aliases.contains(source.name) {
            data.responseLibrary[targetIndex].aliases.append(source.name)
        }
        for index in data.responseAttempts.indices where data.responseAttempts[index].responseID == sourceID {
            data.responseAttempts[index].responseID = targetID
        }
        data.responseLibrary.removeAll { $0.id == sourceID }
        refreshLegacyResponseNames(for: targetID)
        persist()
    }

    func ensureTodayIntentionsFromTemplates() {
        let key = todayKey
        var d = data.days[key] ?? DayRecord()
        guard d.intentions.isEmpty, !data.settings.intentionTemplates.isEmpty else { return }
        d.intentions = data.settings.intentionTemplates.map { t in
            Intention(id: t.id, text: t.text, when: t.when, whereText: t.whereText, met: false, repeatDaily: true)
        }
        data.days[key] = d
        persist()
    }

    func addIntention(text: String, when: String, whereText: String, repeatDaily: Bool) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let id = UUID().uuidString
        let intention = Intention(id: id, text: text, when: when, whereText: whereText, met: false, repeatDaily: repeatDaily)
        updateDay { d in
            guard d.intentions.count < 3 else { return }
            d.intentions.append(intention)
        }
        if repeatDaily {
            data.settings.intentionTemplates.append(IntentionTemplate(id: id, text: text, when: when, whereText: whereText))
            persist()
        }
    }

    func updateIntention(_ intention: Intention) {
        var day = data.days[selectedKey] ?? DayRecord()
        guard let index = day.intentions.firstIndex(where: { $0.id == intention.id }) else { return }
        day.intentions[index] = intention
        data.days[selectedKey] = day
        if intention.repeatDaily {
            let t = IntentionTemplate(id: intention.id, text: intention.text, when: intention.when, whereText: intention.whereText)
            if let i = data.settings.intentionTemplates.firstIndex(where: { $0.id == intention.id }) { data.settings.intentionTemplates[i] = t }
            else { data.settings.intentionTemplates.append(t) }
        } else {
            data.settings.intentionTemplates.removeAll { $0.id == intention.id }
        }
        persist()
    }

    func removeIntention(_ id: String) {
        var day = data.days[selectedKey] ?? DayRecord()
        day.intentions.removeAll { $0.id == id }
        data.days[selectedKey] = day
        data.settings.intentionTemplates.removeAll { $0.id == id }
        persist()
    }

    func addPlan(trigger: String, action: String, enabled: Bool = true) {
        let t = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = action.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !a.isEmpty else { return }
        let triggerID: String
        if let existing = data.triggerLibrary.first(where: {
            $0.name.caseInsensitiveCompare(t) == .orderedSame
        }) {
            triggerID = existing.id
        } else {
            let created = TriggerDefinition(name: t)
            data.triggerLibrary.append(created)
            triggerID = created.id
        }
        data.plans.insert(
            ImplementationPlan(trigger: t, triggerID: triggerID, action: a, enabled: enabled),
            at: 0
        )
        persist()
    }

    func addPlan(triggerID: String, action: String, enabled: Bool = true) {
        let clean = action.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              let trigger = data.triggerLibrary.first(where: { $0.id == triggerID }) else { return }
        data.plans.insert(
            ImplementationPlan(
                trigger: trigger.name,
                triggerID: trigger.id,
                action: clean,
                enabled: enabled
            ),
            at: 0
        )
        persist()
    }

    func updatePlan(_ plan: ImplementationPlan) {
        guard let i = data.plans.firstIndex(where: { $0.id == plan.id }) else { return }
        data.plans[i] = plan
        persist()
    }

    func deletePlan(_ id: String) {
        data.plans.removeAll { $0.id == id }
        persist()
    }

    func updateItem(_ item: Item) {
        guard let i = data.items.firstIndex(where: { $0.id == item.id }) else { return }
        data.items[i] = item
        persist()
    }

    func replaceItems(_ items: [Item]) {
        data.items = items
        persist()
    }

    func restoreMissingDefaultItems() {
        let existing = Set(data.items.map(\.id))
        data.items.append(contentsOf: DefaultItems.all.filter { !existing.contains($0.id) })
        repairBuiltInDisplayNames()
        repairBuiltInItemMetadata()
        persist()
    }

    func dueManualActionIDs(on date: Date) -> [String] {
        var ids = data.items
            .filter {
                !$0.isArchived && $0.kind == .habit &&
                adherenceExpected($0, on: date, settings: data.settings)
            }
            .map(\.id)
        ids.append("heartHealthyEating")
        ids.append(contentsOf: data.personalFactors
            .filter { !$0.archived && $0.kind == .action }
            .map(\.id))
        return Array(Set(ids)).sorted()
    }

    func labelForManualAction(_ id: String) -> String {
        if id == "heartHealthyEating" { return "Heart-healthy eating" }
        if let item = data.items.first(where: { $0.id == id }) { return item.label }
        if let factor = data.personalFactors.first(where: { $0.id == id }) { return factor.name }
        return "Personal action"
    }

    func weeklyAdherenceCandidates(endingOn end: Date = Date()) -> [WeeklyGoalCandidate] {
        let dates = BullDates.dateRange(last: 7, endingAt: end)
        func records(for id: String, due: (Date) -> Bool = { _ in true }) -> [CompletionRecord] {
            dates.compactMap { date in
                guard due(date) else { return nil }
                let day = self.day(for: date)
                if let explicit = day.completionStates[id] { return explicit }
                if id == "heartHealthyEating", let value = day.heartHealthyEating {
                    return CompletionRecord(state: value ? .done : .notDone, source: .migratedLegacy)
                }
                if let value = day.checks[id] {
                    return CompletionRecord(state: value ? .done : .notDone, source: .migratedLegacy)
                }
                return CompletionRecord()
            }
        }

        var candidates: [WeeklyGoalCandidate] = []
        candidates.append(WeeklyGoalCandidate(
            category: .healthRoutine,
            factorID: "heartHealthyEating",
            title: "Heart-healthy eating",
            rationale: "Improve gradually from your observed recent baseline.",
            summary: adherenceSummary(records(for: "heartHealthyEating"))
        ))

        for item in data.items where !item.isArchived && item.kind == .habit {
            let category: WeeklyGoalCategory = item.id == "fasting" ? .preventionSafeguard : .healthRoutine
            candidates.append(WeeklyGoalCandidate(
                category: category,
                factorID: item.id,
                title: item.label,
                rationale: "This is actionable and was due often enough to review.",
                summary: adherenceSummary(records(for: item.id) { date in
                    adherenceExpected(item, on: date, settings: self.data.settings)
                })
            ))
        }

        func automaticSummary(_ values: [(observed: Bool, done: Bool)]) -> AdherenceSummary {
            adherenceSummary(values.map { value in
                value.observed
                    ? CompletionRecord(state: value.done ? .done : .notDone, source: .automaticHealthKit)
                    : CompletionRecord(state: .unknown, source: .automaticHealthKit)
            })
        }
        candidates.append(WeeklyGoalCandidate(
            category: .healthRoutine,
            factorID: "health.aerobic",
            title: "Aerobic activity",
            rationale: "Add one achievable active day above your recent baseline.",
            summary: automaticSummary(dates.map { date in
                let day = self.day(for: date)
                let observed = day.aerobicMinutes != nil || day.vigorousMinutes != nil
                return (observed, (day.aerobicMinutes ?? 0) + (day.vigorousMinutes ?? 0) > 0)
            })
        ))
        candidates.append(WeeklyGoalCandidate(
            category: .healthRoutine,
            factorID: "health.strength",
            title: "Strength activity",
            rationale: "Add one achievable strength day above your recent baseline.",
            summary: automaticSummary(dates.map { date in
                let value = self.day(for: date).strengthMinutes
                return (value != nil, (value ?? 0) >= 15)
            })
        ))

        for factor in data.personalFactors where !factor.archived && factor.kind == .action {
            candidates.append(WeeklyGoalCandidate(
                category: .healthRoutine,
                factorID: factor.id,
                title: factor.name,
                rationale: "Continue this unweighted personal experiment gradually.",
                summary: adherenceSummary(records(for: factor.id))
            ))
        }

        let weekKeys = Set(dates.map { BullDates.key(for: $0) })
        let prompts = data.safeguardEvents.filter {
            weekKeys.contains($0.dayKey) && $0.kind == .promptIssued &&
                $0.effectiveResolutionMode == .safeguard
        }
        if !prompts.isEmpty {
            let outcomes = prompts.map { prompt -> CompletionRecord in
                let completed = safeguardPromptWasResolved(
                    prompt,
                    among: data.safeguardEvents
                )
                return CompletionRecord(state: completed ? .done : .notDone, source: .live)
            }
            candidates.append(WeeklyGoalCandidate(
                category: .preventionSafeguard,
                factorID: "safeguard.primary",
                title: "Complete the prompted place safeguard",
                rationale: "Confirm the concrete safeguard when Bull prompts it.",
                summary: adherenceSummary(outcomes)
            ))
        }

        let urges = data.urges.filter { weekKeys.contains($0.bullDayKey) }
        if !urges.isEmpty {
            let attempts = urges.map { urge -> CompletionRecord in
                let completed = data.responseAttempts.contains {
                    guard $0.urgeID == urge.id, $0.completedTs != nil else { return false }
                    let stressImproved: Bool
                    if let before = $0.stressBefore, let after = $0.stressAfter {
                        stressImproved = after < before
                    } else {
                        stressImproved = false
                    }
                    return $0.reducedUrge || stressImproved
                }
                return CompletionRecord(state: completed ? .done : .notDone, source: .live)
            }
            candidates.append(WeeklyGoalCandidate(
                category: .preventionSafeguard,
                factorID: "response.measured",
                title: "Complete a measured Response",
                rationale: "Choose, finish, and rate a Response when an urge occurs.",
                summary: adherenceSummary(attempts)
            ))
        }

        return candidates
    }

    @discardableResult
    func generateWeeklyGoals(startingOn start: Date = Date()) -> [WeeklyGoal] {
        let startKey = BullDates.key(for: start)
        let end = BullDates.addingDays(6, to: start)
        if data.weeklyGoals.contains(where: { $0.startDayKey == startKey }) {
            return data.weeklyGoals.filter { $0.startDayKey == startKey }
        }
        let baselineEnd = BullDates.addingDays(-1, to: start)
        let goals = weeklyGoalRecommendations(
            candidates: weeklyAdherenceCandidates(endingOn: baselineEnd),
            startDayKey: startKey,
            endDayKey: BullDates.key(for: end)
        )
        data.weeklyGoals.append(contentsOf: goals)
        if !goals.isEmpty { persist() }
        return goals
    }

    func decideWeeklyGoal(_ goal: WeeklyGoal, decision: WeeklyGoalDecision) {
        guard let index = data.weeklyGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        data.weeklyGoals[index] = applyingWeeklyGoalDecision(
            to: goal,
            decision: decision,
            decidedTs: Self.nowMS
        )
        persist()
    }

    @discardableResult
    func replaceWeeklyGoal(_ goal: WeeklyGoal) -> WeeklyGoal? {
        guard let index = data.weeklyGoals.firstIndex(where: { $0.id == goal.id }),
              let start = BullDates.date(from: goal.startDayKey) else { return nil }
        data.weeklyGoals[index] = applyingWeeklyGoalDecision(
            to: goal,
            decision: .rejected,
            decidedTs: Self.nowMS
        )
        let baselineEnd = BullDates.addingDays(-1, to: start)
        let alternatives = weeklyAdherenceCandidates(endingOn: baselineEnd).filter {
            $0.category == goal.category && $0.factorID != goal.factorID
        }
        let replacement = weeklyGoalRecommendations(
            candidates: alternatives,
            startDayKey: goal.startDayKey,
            endDayKey: goal.endDayKey
        ).first
        if let replacement {
            data.weeklyGoals.append(replacement)
        } else {
            lastError = "No other observed actionable factor is ready in this category yet."
        }
        persist()
        return replacement
    }

    func reviewWeeklyGoal(goalID: String, completed: Int, opportunities: Int, note: String?) {
        guard let goal = data.weeklyGoals.first(where: { $0.id == goalID }) else { return }
        data.weeklyGoalReviews.append(WeeklyGoalReview(
            goalID: goalID,
            weekEndDayKey: goal.endDayKey,
            completed: completed,
            opportunities: opportunities,
            userNote: note
        ))
        persist()
    }

    @discardableResult
    func addPersonalFactor(_ factor: PersonalFactor) -> Bool {
        let activeCount = data.personalFactors.filter { !$0.archived }.count
        guard activeCount < 8 else {
            lastError = "Archive an active experiment before adding another (maximum 8)."
            return false
        }
        var unweighted = factor
        unweighted.scoringWeight = nil
        data.personalFactors.append(unweighted)
        persist()
        return true
    }

    func updatePersonalFactor(_ factor: PersonalFactor) {
        guard let index = data.personalFactors.firstIndex(where: { $0.id == factor.id }) else { return }
        let existing = data.personalFactors[index]
        let definitionChanged = existing.name != factor.name ||
            existing.kind != factor.kind ||
            existing.hypothesis != factor.hypothesis ||
            existing.scheduleDescription != factor.scheduleDescription ||
            existing.intendedOutcome != factor.intendedOutcome ||
            existing.evidenceStatus != factor.evidenceStatus
        if definitionChanged {
            var revised = factor
            revised.definitionVersion = max(existing.definitionVersion + 1, factor.definitionVersion)
            if existing.name != factor.name && !revised.aliases.contains(existing.name) {
                revised.aliases.append(existing.name)
            }
            revised.scoringWeight = nil
            data.personalFactors[index] = revised
        } else {
            var unweighted = factor
            unweighted.scoringWeight = nil
            data.personalFactors[index] = unweighted
        }
        persist()
    }

    func setPersonalFactorArchived(id: String, archived: Bool) {
        guard let index = data.personalFactors.firstIndex(where: { $0.id == id }) else { return }
        if !archived && data.personalFactors.filter({ !$0.archived }).count >= 8 {
            lastError = "Archive an active experiment before restoring this one (maximum 8)."
            return
        }
        data.personalFactors[index].archived = archived
        persist()
    }

    /// The package-owned migration is pure so old-backup preservation is unit-testable.
    private func migrateToV9() {
        data = migratedBullDataToV9(data)
    }

    /// Additive v8→v15 chain. Historical checks, events, private-context sessions,
    /// accountability rows, If–Then plans and frozen snapshots all remain exportable.
    private func migrateToV15() {
        migrateToV9()
        data = migratedBullDataToV10(data, timeZone: .current)
        data = migratedBullDataToV11(data, timeZone: .current)
        data = migratedBullDataToV12(data, timeZone: .current)
        data = migratedBullDataToV13(data, timeZone: .current)
        data = migratedBullDataToV14(data, timeZone: .current)
        data = migratedBullDataToV15(data, timeZone: .current)
        if data.settings.fourScoreV10StartDayKey == nil {
            data.settings.fourScoreV10StartDayKey = BullDates.key(for: Date())
        }
    }

    private func mergeDefaultLibraries() {
        let triggerIDs = Set(data.triggerLibrary.map(\.id))
        data.triggerLibrary.append(contentsOf: V27Defaults.triggers.filter { !triggerIDs.contains($0.id) })
        let responseIDs = Set(data.responseLibrary.map(\.id))
        data.responseLibrary.append(contentsOf: V27Defaults.responses.filter { !responseIDs.contains($0.id) })
    }

    private func migrateLegacyTriggerAndResponseStrings() {
        func normalized(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        func slug(_ value: String) -> String {
            let allowed = CharacterSet.alphanumerics
            let parts = value.lowercased().unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
            let raw = String(parts)
            return raw.split(separator: "-").filter { !$0.isEmpty }.joined(separator: "-").prefix(42).description
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
            if data.urges[index].triggerIDs.isEmpty {
                let names = data.urges[index].triggers
                let ids = names.map { triggerID(for: $0) }
                data.urges[index].triggerIDs = ids
            }
            // Keep legacy response names, but create canonical library entries without
            // pretending a historical selection proved completion/effectiveness.
            let responseNames = data.urges[index].responses
            _ = responseNames.map { responseID(for: $0) }
        }
        for index in data.relapses.indices where data.relapses[index].triggerIDs.isEmpty {
            let names = data.relapses[index].triggers
            let ids = names.map { triggerID(for: $0) }
            data.relapses[index].triggerIDs = ids
        }
        for rule in data.rules {
            _ = rule.triggers.map { triggerID(for: $0) }
            _ = rule.responses.map { responseID(for: $0) }
        }
        for index in data.plans.indices {
            if data.plans[index].triggerID == nil {
                let name = data.plans[index].trigger
                let id = triggerID(for: name)
                data.plans[index].triggerID = id
            }
        }
    }

    private func refreshLegacyTriggerNames() {
        let names = data.triggerLibrary.reduce(into: [String: String]()) { $0[$1.id] = $1.name }
        for index in data.urges.indices where !data.urges[index].triggerIDs.isEmpty {
            data.urges[index].triggers = data.urges[index].triggerIDs.compactMap { names[$0] }
        }
        for index in data.relapses.indices where !data.relapses[index].triggerIDs.isEmpty {
            data.relapses[index].triggers = data.relapses[index].triggerIDs.compactMap { names[$0] }
        }
    }

    private func refreshLegacyResponseNames(for responseID: String) {
        guard let name = data.responseLibrary.first(where: { $0.id == responseID })?.name else { return }
        let urgeIDs = Set(data.responseAttempts.filter { $0.responseID == responseID }.compactMap(\.urgeID))
        for index in data.urges.indices where urgeIDs.contains(data.urges[index].id) {
            let linked = Set(data.responseAttempts
                .filter { $0.urgeID == data.urges[index].id }
                .map(\.responseID))
            data.urges[index].responses = data.responseLibrary
                .filter { linked.contains($0.id) }
                .map(\.name)
            if data.urges[index].responses.isEmpty { data.urges[index].responses = [name] }
        }
    }

    /// Repairs metadata added by newer native scoring models without overwriting the
    /// user's editable weights/classification. This matters especially for old/imported
    /// `fasting` rows: before `fastingAuto` existed they decode as a normal daily habit,
    /// which would incorrectly show Fasting every day.
    private func repairBuiltInItemMetadata() {
        let defaults = Dictionary(uniqueKeysWithValues: DefaultItems.all.map { ($0.id, $0) })
        for index in data.items.indices {
            let id = data.items[index].id
            guard let builtIn = defaults[id] else { continue }

            if id == "fasting" {
                // Fasting's calendar-controlled scheduling is intrinsic to this built-in.
                // Preserve the user's score side/weights/bucket, but never let a legacy
                // missing flag silently turn it into an everyday task.
                data.items[index].fastingAuto = true
            }
            if data.items[index].riskDomain == nil, data.items[index].list.feedsPrevention {
                data.items[index].riskDomain = builtIn.riskDomain
            }
            if data.items[index].bucket == nil, data.items[index].list.feedsVigour {
                data.items[index].bucket = builtIn.bucket
            }
        }
    }

    /// v3.2.1 removes slash-separated synonym labels from built-in controls and menus.
    /// Only exact legacy defaults are changed; anything the user renamed stays untouched.
    private func repairBuiltInDisplayNames() {
        let triggerNames: [String: (legacy: String, concise: String)] = [
            "trigger.anxiety": ("Anxiety / stress", "Stress"),
            "trigger.lonely": ("Lonely / isolated", "Lonely"),
            "trigger.bored": ("Bored / unstructured", "Bored"),
            "trigger.tired": ("Tired / underslept", "Tired")
        ]
        for index in data.triggerLibrary.indices {
            guard let names = triggerNames[data.triggerLibrary[index].id],
                  data.triggerLibrary[index].name.caseInsensitiveCompare(names.legacy) == .orderedSame else {
                continue
            }
            if !data.triggerLibrary[index].aliases.contains(where: {
                $0.caseInsensitiveCompare(names.legacy) == .orderedSame
            }) {
                data.triggerLibrary[index].aliases.append(names.legacy)
            }
            data.triggerLibrary[index].name = names.concise
        }

        let activityNames: [String: (legacy: String, concise: String)] = [
            "stress.nature-walk": ("Riverside / Nature Walk", "Nature Walk"),
            "stress.mindfulness": ("Muse / Mindfulness", "Mindfulness"),
            "stress.social": ("Social Connection / Laughter", "Social Connection")
        ]
        for index in data.stressActivities.indices {
            guard let names = activityNames[data.stressActivities[index].id],
                  data.stressActivities[index].name.caseInsensitiveCompare(names.legacy) == .orderedSame else {
                continue
            }
            data.stressActivities[index].name = names.concise
        }

        if let index = data.personalFactors.firstIndex(where: {
            $0.id == "experiment.accountability-support" &&
                $0.name.caseInsensitiveCompare("Accountability / support") == .orderedSame
        }) {
            data.personalFactors[index].name = "Accountability"
        }
        if let index = data.items.firstIndex(where: {
            $0.id == "cardio" && $0.label.caseInsensitiveCompare("Cardio / Boxing") == .orderedSame
        }) {
            data.items[index].label = "Cardio and Boxing"
        }
    }

    func updateSettings(_ body: (inout Settings) -> Void) {
        let protectedRepeat = data.settings.zoneNudgeRepeatMinutes
        let protectedTimeSensitive = data.settings.zoneTimeSensitiveAlerts
        body(&data.settings)
        if data.therapistOversight.protectsRiskControls {
            if data.settings.zoneNudgeRepeatMinutes > protectedRepeat {
                data.settings.zoneNudgeRepeatMinutes = protectedRepeat
                lastError = "Use Risk Zone Alerts to request a longer repeat interval."
            }
            if protectedTimeSensitive && !data.settings.zoneTimeSensitiveAlerts {
                data.settings.zoneTimeSensitiveAlerts = true
                lastError = "Use Risk Zone Alerts to request turning off Time Sensitive delivery."
            }
        }
        persist()
    }

    // MARK: Therapist safeguard oversight

    var therapistOversightIsEnabled: Bool {
        let state = data.therapistOversight.state
        return data.therapistOversight.role == .owner &&
            (state == .invitationReady || state == .active)
    }

    func beginTherapistOversight() {
        let now = Self.nowMS
        data.therapistOversight = TherapistOversightConfiguration(
            role: .owner,
            state: .invitationReady,
            transportState: .preparing,
            consentVersion: 1,
            consentedTs: now
        )
        data.therapistAccessAudit.append(TherapistAccessAuditEvent(
            kind: .consentGranted,
            ts: now,
            detail: "Urge, relapse and Risk Zone scope"
        ))
        let currentDate = Date(timeIntervalSince1970: now / 1_000)
        for zone in data.highRiskZones where zone.enabled && isInsideZone(zone.id) {
            if let entry = data.zoneEvents
                .filter({ $0.zoneID == zone.id && $0.kind == .entered })
                .max(by: { $0.ts < $1.ts }) {
                _ = queueTherapistZoneEntry(
                    zone: zone,
                    zoneEventID: entry.id,
                    at: currentDate
                )
            }
        }
        lastNotice = "Therapist oversight is being prepared. Risk controls are now protected."
        persist()
    }

    func markTherapistSharePrepared(zoneName: String, shareRecordName: String) {
        data.therapistOversight.state = .invitationReady
        data.therapistOversight.transportState = .ready
        data.therapistOversight.cloudZoneName = zoneName
        data.therapistOversight.cloudShareRecordName = shareRecordName
        data.therapistOversight.lastTransportError = nil
        data.therapistAccessAudit.append(TherapistAccessAuditEvent(
            kind: .sharePrepared,
            detail: "iCloud share prepared"
        ))
        persist()
    }

    func markTherapistConnectionActive() {
        data.therapistOversight.state = .active
        data.therapistOversight.transportState = .ready
        data.therapistOversight.lastTransportError = nil
        persist()
    }

    func markTherapistConnectionPending() {
        guard data.therapistOversight.role == .owner,
              data.therapistOversight.state != .off,
              data.therapistOversight.state != .ended else { return }
        data.therapistOversight.state = .invitationReady
        data.therapistOversight.transportState = .ready
        data.therapistOversight.lastTransportError = nil
        persist()
    }

    func recoverOwnerTherapistOversight(
        zoneName: String,
        shareRecordName: String,
        connected: Bool
    ) {
        let now = Self.nowMS
        data.therapistOversight = TherapistOversightConfiguration(
            role: .owner,
            state: connected ? .active : .invitationReady,
            transportState: .ready,
            consentVersion: 1,
            consentedTs: now,
            cloudZoneName: zoneName,
            cloudShareRecordName: shareRecordName
        )
        data.therapistAccessAudit.append(TherapistAccessAuditEvent(
            kind: .sharePrepared,
            ts: now,
            detail: "Existing iCloud share revalidated"
        ))
        let currentDate = Date(timeIntervalSince1970: now / 1_000)
        for zone in data.highRiskZones where zone.enabled && isInsideZone(zone.id) {
            if let entry = data.zoneEvents
                .filter({ $0.zoneID == zone.id && $0.kind == .entered })
                .max(by: { $0.ts < $1.ts }) {
                _ = queueTherapistZoneEntry(
                    zone: zone,
                    zoneEventID: "recovered.\(entry.id).\(Int(now))",
                    at: currentDate
                )
            }
        }
        lastNotice = connected
            ? "Bull restored the existing therapist connection from iCloud."
            : "Bull found the existing therapist invitation in iCloud."
        persist()
    }

    func setTherapistTransport(
        _ state: TherapistTransportState,
        error: String? = nil,
        syncedAt timestamp: Double? = nil
    ) {
        data.therapistOversight.transportState = state
        data.therapistOversight.lastTransportError = error
        if let timestamp { data.therapistOversight.lastSyncTs = timestamp }
        if let error {
            let detail = String(error.prefix(180))
            let recentDuplicate = data.therapistAccessAudit.last(where: {
                $0.kind == .transportFailed && $0.detail == detail
            }).map { Self.nowMS - $0.ts < 60 * 60 * 1_000 } ?? false
            if !recentDuplicate {
                data.therapistAccessAudit.append(TherapistAccessAuditEvent(
                    kind: .transportFailed,
                    detail: detail
                ))
            }
        }
        persist()
    }

    func enterTherapistRole(zoneName: String?, shareRecordName: String?) {
        data.therapistOversight = TherapistOversightConfiguration(
            role: .therapist,
            state: .active,
            transportState: .ready,
            consentVersion: 1,
            consentedTs: Self.nowMS,
            cloudZoneName: zoneName,
            cloudShareRecordName: shareRecordName
        )
        data.therapistAccessAudit.append(TherapistAccessAuditEvent(kind: .shareAccepted))
        persist()
    }

    func endTherapistOversight(queueRemoteNotice: Bool = true) {
        guard data.therapistOversight.state != .off,
              data.therapistOversight.state != .ended else { return }
        let now = Self.nowMS
        if queueRemoteNotice && data.therapistOversight.role == .owner {
            queueTherapistEvent(TherapistOversightEvent(
                kind: .oversightEnded,
                ts: now,
                dayKey: todayKey,
                message: "Your client ended Therapist Oversight.",
                requiresAttention: true,
                deduplicationKey: "oversight-ended.\(Int(now))"
            ))
        }
        data.therapistOversight.state = .ended
        data.therapistOversight.endedTs = now
        data.therapistAccessAudit.append(TherapistAccessAuditEvent(
            kind: .oversightEnded,
            ts: now
        ))
        lastNotice = queueRemoteNotice
            ? "Therapist oversight ended. The end event remains in the audit history."
            : "Therapist oversight ended and access was revoked. The end remains in the audit history."
        persist()
    }

    func clearTherapistRole() {
        data.therapistOversight = TherapistOversightConfiguration()
        data.therapistProjectionCache = nil
        data.therapistInboxEvents = []
        persist()
    }

    func markTherapistAccessEndedByOwner() {
        guard data.therapistOversight.role == .therapist else { return }
        let now = Self.nowMS
        data.therapistOversight.state = .ended
        data.therapistOversight.transportState = .notConfigured
        data.therapistOversight.endedTs = now
        data.therapistOversight.lastTransportError = nil
        data.therapistProjectionCache = nil
        data.therapistInboxEvents = []
        data.therapistAccessAudit.append(TherapistAccessAuditEvent(
            kind: .oversightEnded,
            ts: now,
            detail: "Owner revoked the private iCloud share"
        ))
        lastNotice = "Your client ended Therapist Oversight and revoked this iCloud share."
        persist()
    }

    func therapistProjection() -> TherapistProjection {
        makeTherapistProjection(
            from: data,
            monitoring: therapistMonitoringStatus
        )
    }

    func cacheTherapistProjection(
        _ projection: TherapistProjection,
        events: [TherapistOversightEvent],
        remoteEventTs: Double? = nil
    ) {
        data.therapistProjectionCache = projection
        let known = Set(data.therapistInboxEvents.map(\.id))
        data.therapistInboxEvents.append(contentsOf: events.filter { !known.contains($0.id) })
        data.therapistInboxEvents = Array(
            data.therapistInboxEvents.sorted { $0.ts > $1.ts }.prefix(500)
        )
        data.therapistOversight.lastSyncTs = Self.nowMS
        if let latest = remoteEventTs {
            data.therapistOversight.lastRemoteEventTs = max(
                data.therapistOversight.lastRemoteEventTs ?? 0,
                latest
            )
        }
        persist()
    }

    @Published private(set) var therapistMonitoringStatus = TherapistMonitoringStatus()

    func updateTherapistMonitoringStatus(_ status: TherapistMonitoringStatus) {
        let previous = therapistMonitoringStatus
        let materiallyChanged = previous.locationStatus != status.locationStatus ||
            previous.notificationsAllowed != status.notificationsAllowed ||
            previous.timeSensitiveEnabled != status.timeSensitiveEnabled ||
            previous.monitoredZoneCount != status.monitoredZoneCount ||
            previous.expectedZoneCount != status.expectedZoneCount ||
            previous.failedZoneCount != status.failedZoneCount
        therapistMonitoringStatus = status
        guard therapistOversightIsEnabled else { return }
        let monitoringUnavailable = status.expectedZoneCount > 0 && (
            !status.locationStatus.lowercased().hasPrefix("always") ||
                !status.notificationsAllowed ||
                (data.settings.zoneTimeSensitiveAlerts && !status.timeSensitiveEnabled) ||
                status.monitoredZoneCount < status.expectedZoneCount ||
                status.failedZoneCount > 0
        )
        let key = [
            "monitoring",
            todayKey,
            status.locationStatus,
            String(status.notificationsAllowed),
            String(status.timeSensitiveEnabled),
            String(status.monitoredZoneCount),
            String(status.expectedZoneCount),
            String(status.failedZoneCount)
        ].joined(separator: ".")
        let warningQueued: Bool
        if monitoringUnavailable {
            warningQueued = queueTherapistEvent(TherapistOversightEvent(
                kind: .monitoringUnavailable,
                dayKey: todayKey,
                message: "Risk Zone monitoring needs attention on your client’s iPhone.",
                requiresAttention: true,
                deduplicationKey: key
            ))
        } else {
            warningQueued = false
        }
        guard materiallyChanged || warningQueued else { return }
        // Availability and recovery are part of the shared dashboard even when no warning
        // is queued, so both directions must trigger a fresh projection.
        persist()
    }

    func queueTherapistZoneWarning(
        zoneID: String,
        alertEventID: String,
        at date: Date = Date()
    ) {
        guard therapistOversightIsEnabled,
              let zone = data.highRiskZones.first(where: { $0.id == zoneID }),
              isInsideZone(zoneID), isZoneActive(zone, at: date) else { return }
        let earlierWarnings = data.therapistOutboxEvents.filter {
            ($0.kind == .zoneEntered || $0.kind == .zoneStillActive) &&
                $0.zoneID == zoneID && $0.dayKey == BullDates.key(for: date)
        }
        if let latestWarningTs = earlierWarnings.map(\.ts).max(),
           date.timeIntervalSince1970 * 1_000 - latestWarningTs <
            Double(data.settings.zoneNudgeRepeatMinutes) * 60_000 {
            return
        }
        if queueTherapistEvent(TherapistOversightEvent(
            kind: earlierWarnings.isEmpty ? .zoneEntered : .zoneStillActive,
            ts: date.timeIntervalSince1970 * 1_000,
            dayKey: BullDates.key(for: date),
            zoneID: zoneID,
            zoneName: zone.name,
            message: zone.resolutionMode == .exitRequired
                ? "Take action before you regret it! Your client is in an active Risk Zone that can only be resolved by leaving."
                : "Take action before you regret it! Your client is in an active Risk Zone.",
            requiresAttention: true,
            deduplicationKey: "zone-warning.\(alertEventID)"
        )) { persist() }
    }

    func markTherapistOutboxPublished(eventIDs: Set<String>, at timestamp: Double? = nil) {
        // Default arguments are evaluated outside this @MainActor-isolated type. Resolve
        // "now" inside the method so Swift 6 does not reference actor-isolated `Self`
        // from a nonisolated default-argument expression.
        let deliveryTimestamp = timestamp ?? Self.nowMS
        var changed = false
        for index in data.therapistOutboxEvents.indices where eventIDs.contains(data.therapistOutboxEvents[index].id) {
            data.therapistOutboxEvents[index].deliveryState = .published
            data.therapistOutboxEvents[index].deliveryAttempts += 1
            data.therapistOutboxEvents[index].lastDeliveryTs = deliveryTimestamp
            data.therapistOutboxEvents[index].lastDeliveryError = nil
            changed = true
        }
        if changed { persist() }
    }

    func markTherapistOutboxFailed(eventIDs: Set<String>, error: String) {
        var changed = false
        for index in data.therapistOutboxEvents.indices where eventIDs.contains(data.therapistOutboxEvents[index].id) {
            data.therapistOutboxEvents[index].deliveryState = .failed
            data.therapistOutboxEvents[index].deliveryAttempts += 1
            data.therapistOutboxEvents[index].lastDeliveryTs = Self.nowMS
            data.therapistOutboxEvents[index].lastDeliveryError = String(error.prefix(180))
            changed = true
        }
        if changed { persist() }
    }

    @discardableResult
    func requestZoneNudgeRepeatMinutes(_ proposed: Int) -> RiskControlMutationResult {
        let normalized = min(180, max(15, proposed))
        let current = data.settings.zoneNudgeRepeatMinutes
        guard current != normalized else { return .applied }
        if data.therapistOversight.protectsRiskControls,
           classifyAlertRepeatChange(currentMinutes: current, proposedMinutes: normalized) ==
            .therapistReviewRequired {
            return requestRiskControlChange(RiskControlChangeRequest(
                kind: .alertRepeatMinutes,
                currentIntegerValue: current,
                proposedIntegerValue: normalized,
                summary: "Change Risk Zone alert repeat from \(current) to \(normalized) minutes"
            ))
        }
        data.settings.zoneNudgeRepeatMinutes = normalized
        zonesNeedingNotificationReconciliation.formUnion(data.highRiskZones.map(\.id))
        persist()
        return .applied
    }

    func adoptLegacyZoneTimeSensitivePreference(_ enabled: Bool) {
        guard enabled, !data.settings.zoneTimeSensitiveAlerts else { return }
        data.settings.zoneTimeSensitiveAlerts = true
        persist()
    }

    @discardableResult
    func requestZoneTimeSensitiveAlerts(_ proposed: Bool) -> RiskControlMutationResult {
        let current = data.settings.zoneTimeSensitiveAlerts
        guard current != proposed else { return .applied }
        if data.therapistOversight.protectsRiskControls && current && !proposed {
            return requestRiskControlChange(RiskControlChangeRequest(
                kind: .timeSensitiveAlerts,
                currentBooleanValue: current,
                proposedBooleanValue: proposed,
                summary: "Turn off Time Sensitive Risk Zone alerts"
            ))
        }
        data.settings.zoneTimeSensitiveAlerts = proposed
        zonesNeedingNotificationReconciliation.formUnion(data.highRiskZones.map(\.id))
        persist()
        return .applied
    }

    @discardableResult
    private func requestRiskControlChange(
        _ request: RiskControlChangeRequest
    ) -> RiskControlMutationResult {
        if let existing = data.riskControlChangeRequests.first(where: {
            $0.status == .pending && $0.kind == request.kind && $0.zoneID == request.zoneID
        }) {
            lastNotice = "A change for this Risk Control is already awaiting therapist review."
            return .pendingApproval(requestID: existing.id)
        }
        let previousData = data
        data.riskControlChangeRequests.append(request)
        queueTherapistEvent(TherapistOversightEvent(
            kind: .riskControlChangeRequested,
            ts: request.requestedTs,
            dayKey: BullDates.key(for: Date(timeIntervalSince1970: request.requestedTs / 1_000)),
            zoneID: request.zoneID,
            zoneName: request.currentZone?.name ?? request.proposedZone?.name,
            changeRequestID: request.id,
            message: request.summary,
            requiresAttention: true,
            deduplicationKey: "risk-change.\(request.id)"
        ))
        lastNotice = "The current protection remains active while your therapist reviews this change."
        guard persist() else {
            data = previousData
            objectWillChange.send()
            return .rejected(reason: lastError ?? "Bull could not save the review request.")
        }
        return .pendingApproval(requestID: request.id)
    }

    @discardableResult
    func applyTherapistRiskDecisions(_ decisions: [TherapistRiskChangeRecord]) -> Bool {
        var changed = false
        for decision in decisions where decision.status == .approved || decision.status == .rejected {
            guard let index = data.riskControlChangeRequests.firstIndex(where: {
                $0.id == decision.id && $0.status == .pending
            }) else { continue }
            guard therapistDecisionMatches(
                decision,
                request: therapistRiskChangeRecord(data.riskControlChangeRequests[index])
            ) else { continue }
            data.riskControlChangeRequests[index].status = decision.status
            data.riskControlChangeRequests[index].reviewedTs = decision.reviewedTs ?? Self.nowMS
            data.riskControlChangeRequests[index].reviewerDecision = decision.reviewerDecision
            if decision.status == .approved {
                applyApprovedRiskControlChange(at: index)
            }
            data.therapistAccessAudit.append(TherapistAccessAuditEvent(
                kind: .riskChangeReviewed,
                detail: "\(decision.id): \(decision.status.rawValue)"
            ))
            changed = true
        }
        if changed { persist() }
        return changed
    }

    private func applyApprovedRiskControlChange(at index: Int) {
        let request = data.riskControlChangeRequests[index]
        switch request.kind {
        case .updateZone:
            if let proposed = request.proposedZone,
               let reviewedCurrent = request.currentZone,
               let zoneIndex = data.highRiskZones.firstIndex(where: { $0.id == proposed.id }),
               data.highRiskZones[zoneIndex] == reviewedCurrent {
                let wasEnabled = data.highRiskZones[zoneIndex].enabled
                data.highRiskZones[zoneIndex] = proposed
                zonesNeedingNotificationReconciliation.insert(proposed.id)
                if wasEnabled && !proposed.enabled { closeZoneOccupancyIfNeeded(zoneID: proposed.id) }
            } else {
                cancelSupersededRiskControlChange(at: index)
                return
            }
        case .deleteZone:
            if let zoneID = request.zoneID,
               let reviewedCurrent = request.currentZone,
               let current = data.highRiskZones.first(where: { $0.id == zoneID }),
               current == reviewedCurrent {
                zonesNeedingNotificationReconciliation.insert(zoneID)
                applyZoneDeletion(id: zoneID)
            } else {
                cancelSupersededRiskControlChange(at: index)
                return
            }
        case .alertRepeatMinutes:
            if let value = request.proposedIntegerValue,
               let reviewedCurrent = request.currentIntegerValue,
               data.settings.zoneNudgeRepeatMinutes == reviewedCurrent {
                data.settings.zoneNudgeRepeatMinutes = min(180, max(15, value))
                zonesNeedingNotificationReconciliation.formUnion(data.highRiskZones.map(\.id))
            } else {
                cancelSupersededRiskControlChange(at: index)
                return
            }
        case .timeSensitiveAlerts:
            if let value = request.proposedBooleanValue,
               let reviewedCurrent = request.currentBooleanValue,
               data.settings.zoneTimeSensitiveAlerts == reviewedCurrent {
                data.settings.zoneTimeSensitiveAlerts = value
                zonesNeedingNotificationReconciliation.formUnion(data.highRiskZones.map(\.id))
            } else {
                cancelSupersededRiskControlChange(at: index)
                return
            }
        }
        data.riskControlChangeRequests[index].status = .applied
        data.riskControlChangeRequests[index].appliedTs = Self.nowMS
    }

    private func cancelSupersededRiskControlChange(at index: Int) {
        data.riskControlChangeRequests[index].status = .cancelled
        data.riskControlChangeRequests[index].reviewerDecision =
            "Approved proposal was superseded by a later protection change"
    }

    func consumeZoneNotificationReconciliationIDs() -> Set<String> {
        let ids = zonesNeedingNotificationReconciliation
        zonesNeedingNotificationReconciliation = []
        return ids
    }

    @discardableResult
    private func queueTherapistEvent(_ event: TherapistOversightEvent) -> Bool {
        guard shouldQueueTherapistEvent(
            deduplicationKey: event.deduplicationKey,
            existing: data.therapistOutboxEvents
        ) else { return false }
        data.therapistOutboxEvents.append(event)
        data.therapistOutboxEvents = Array(
            data.therapistOutboxEvents.sorted { $0.ts > $1.ts }.prefix(1_000)
        )
        NotificationCenter.default.post(name: .bullTherapistOutboxChanged, object: nil)
        return true
    }

    private func riskZoneChangeSummary(
        current: HighRiskZone,
        proposed: HighRiskZone
    ) -> String {
        var changes: [String] = []
        if current.name != proposed.name { changes.append("rename to ‘\(proposed.name)’") }
        if current.enabled != proposed.enabled { changes.append(proposed.enabled ? "enable zone" : "pause zone") }
        if current.radiusMetres != proposed.radiusMetres {
            changes.append("radius \(Int(current.radiusMetres))→\(Int(proposed.radiusMetres)) m")
        }
        if current.latitude != proposed.latitude || current.longitude != proposed.longitude {
            let distance = riskZoneCentreShiftMetres(from: current, to: proposed)
            let distanceText = distance >= 1_000
                ? String(format: "%.1f km", distance / 1_000)
                : "\(Int(distance.rounded())) m"
            changes.append("move geofence centre by \(distanceText)")
        }
        if current.activeDays != proposed.activeDays || current.startMinute != proposed.startMinute ||
            current.endMinute != proposed.endMinute || current.scheduleMode != proposed.scheduleMode {
            changes.append("change active schedule")
        }
        if current.resolutionMode != proposed.resolutionMode {
            changes.append("resolution: \(proposed.resolutionMode.label)")
        }
        if current.safeguard != proposed.safeguard { changes.append("change safeguard") }
        return changes.isEmpty
            ? "Review Risk Zone settings for ‘\(current.name)’"
            : "\(current.name): \(changes.joined(separator: ", "))"
    }

    func markAccountabilityCheckIn(attended: Bool) {
        guard let scheduled = data.settings.nextCheckin else { return }
        data.accountabilityCheckIns.append(AccountabilityCheckIn(
            scheduledTs: scheduled,
            attended: attended,
            dayKey: todayKey
        ))
        if attended { data.settings.therapySessions += 1 }
        data.settings.countedCheckin = scheduled
        let scheduledDate = Date(timeIntervalSince1970: scheduled / 1_000)
        let cadenceAnchor = max(scheduledDate, Date())
        data.settings.nextCheckin = BullDates.addingDays(
            data.settings.therapistEveryWeeks * 7,
            to: cadenceAnchor
        ).timeIntervalSince1970 * 1_000
        persist()
    }

    @discardableResult
    func addZone(_ zone: HighRiskZone) -> RiskControlMutationResult {
        guard data.highRiskZones.count < 20 else {
            lastError = "iOS supports at most 20 monitored Risk Zones."
            return .rejected(reason: lastError ?? "Risk Zone limit reached.")
        }
        guard !data.highRiskZones.contains(where: { $0.id == zone.id }) else {
            return .rejected(reason: "A Risk Zone with this identifier already exists.")
        }
        data.highRiskZones.append(zone)
        guard persist(), persistedZoneMatches(zone) else {
            data.highRiskZones.removeAll { $0.id == zone.id }
            objectWillChange.send()
            _ = persist(makeRollingBackup: false)
            lastError = lastError ?? "Bull could not verify the saved Risk Zone. Please try again."
            return .rejected(reason: lastError ?? "Risk Zone save failed.")
        }
        return .applied
    }

    @discardableResult
    func updateZone(_ zone: HighRiskZone) -> RiskControlMutationResult {
        guard let index = data.highRiskZones.firstIndex(where: { $0.id == zone.id }) else {
            return .rejected(reason: "Risk Zone not found.")
        }
        let current = data.highRiskZones[index]
        if data.therapistOversight.protectsRiskControls,
           classifyRiskZoneChange(current: current, proposed: zone) == .therapistReviewRequired {
            return requestRiskControlChange(RiskControlChangeRequest(
                kind: .updateZone,
                zoneID: zone.id,
                currentZone: current,
                proposedZone: zone,
                summary: riskZoneChangeSummary(current: current, proposed: zone)
            ))
        }
        let wasEnabled = current.enabled
        data.highRiskZones[index] = zone
        guard persist(), persistedZoneMatches(zone) else {
            data.highRiskZones[index] = current
            objectWillChange.send()
            _ = persist(makeRollingBackup: false)
            lastError = lastError ?? "Bull could not verify the saved Risk Zone. Please try again."
            return .rejected(reason: lastError ?? "Risk Zone save failed.")
        }
        if wasEnabled && !zone.enabled { closeZoneOccupancyIfNeeded(zoneID: zone.id) }
        return .applied
    }

    private func persistedZoneMatches(_ zone: HighRiskZone) -> Bool {
        guard let raw = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(BullData.self, from: raw) else {
            return false
        }
        guard let persisted = saved.highRiskZones.first(where: { $0.id == zone.id }) else {
            return false
        }
        // Verify the fields that define monitoring and user-visible behaviour. Keeping the
        // comparison explicit avoids a false negative if a future decoder normalises an
        // unrelated Codable field while the zone itself was written successfully.
        return persisted.name == zone.name &&
            persisted.latitude == zone.latitude &&
            persisted.longitude == zone.longitude &&
            persisted.radiusMetres == zone.radiusMetres &&
            persisted.riskLevel == zone.riskLevel &&
            persisted.enabled == zone.enabled &&
            persisted.activeDays == zone.activeDays &&
            persisted.startMinute == zone.startMinute &&
            persisted.endMinute == zone.endMinute &&
            persisted.scheduleMode == zone.scheduleMode &&
            persisted.minutesAllowedAfterFinalWake == zone.minutesAllowedAfterFinalWake &&
            persisted.minutesAllowedBeforeBed == zone.minutesAllowedBeforeBed &&
            persisted.activateWhenUnexpectedlyAwake == zone.activateWhenUnexpectedlyAwake &&
            persisted.onlyWhenRiskAtLeast == zone.onlyWhenRiskAtLeast &&
            persisted.legacyOnlyWhenRiskAtLeast == zone.legacyOnlyWhenRiskAtLeast &&
            persisted.resolutionMode == zone.resolutionMode &&
            persisted.safeguard == zone.safeguard &&
            persisted.showNameOnLockScreen == zone.showNameOnLockScreen &&
            persisted.timeZoneIdentifier == zone.timeZoneIdentifier &&
            persisted.createdTs == zone.createdTs
    }

    func laylaSleepSchedule(at date: Date = Date()) -> LaylaSleepScheduleSnapshot? {
        data.laylaSleepSchedules
            .filter { $0.isTrustedAndCurrent(at: date) }
            .max(by: laylaSnapshotPrecedes)
    }

    /// Reads Layla's one-record App Group projection and applies it through the same
    /// validation/audit path used by every other schedule ingestion. Returns true only
    /// when a new record was accepted; cached/idempotent reads do not churn persistence.
    @discardableResult
    func refreshLaylaSleepScheduleFromSharedGroup(at date: Date = Date()) -> Bool {
        let checkedTs = date.timeIntervalSince1970 * 1_000
        guard data.therapistOversight.role == .owner else {
            laylaScheduleBridgeStatus = LaylaScheduleBridgeStatus(
                state: .unavailableInTherapistRole,
                checkedTs: checkedTs
            )
            return false
        }
        switch LaylaScheduleBridge.readLatest(now: date) {
        case .available(let envelope):
            let snapshot = envelope.snapshot
            let statusState: LaylaScheduleBridgeStatus.State =
                snapshot.isTrustedAndCurrent(at: date) ? .current : .stale
            let status = LaylaScheduleBridgeStatus(
                state: statusState,
                checkedTs: checkedTs,
                sourceUpdatedTs: snapshot.updatedTs,
                sourceVersion: snapshot.sourceVersion,
                sourceSequence: snapshot.sourceSequence,
                sourceBundleIdentifier: snapshot.sourceBundleIdentifier,
                timeZoneIdentifier: snapshot.timeZoneIdentifier
            )
            switch laylaSnapshotIngestionDecision(
                incoming: snapshot,
                existing: data.laylaSleepSchedules
            ) {
            case .accept:
                guard applyLaylaSleepSchedule(snapshot) else {
                    laylaScheduleBridgeStatus = LaylaScheduleBridgeStatus(
                        state: .invalid,
                        checkedTs: checkedTs,
                        detail: lastError
                    )
                    return false
                }
                laylaScheduleBridgeStatus = status
                return true
            case .idempotent:
                laylaScheduleBridgeStatus = status
                return false
            case .rejectStale:
                let current = laylaSleepSchedule(at: date)
                laylaScheduleBridgeStatus = LaylaScheduleBridgeStatus(
                    state: current == nil ? .stale : .ignoredOlderUpdate,
                    checkedTs: checkedTs,
                    sourceUpdatedTs: current?.updatedTs,
                    sourceVersion: current?.sourceVersion,
                    sourceSequence: current?.sourceSequence,
                    sourceBundleIdentifier: current?.sourceBundleIdentifier,
                    timeZoneIdentifier: current?.timeZoneIdentifier
                )
                return false
            case .rejectConflict:
                laylaScheduleBridgeStatus = LaylaScheduleBridgeStatus(
                    state: .invalid,
                    checkedTs: checkedTs,
                    detail: "Bull rejected a conflicting Layla update and kept its last accepted schedule."
                )
                return false
            }
        case .missing:
            let current = laylaSleepSchedule(at: date)
            laylaScheduleBridgeStatus = LaylaScheduleBridgeStatus(
                state: current == nil
                    ? (data.laylaSleepSchedules.isEmpty ? .missing : .stale)
                    : .cachedCurrent,
                checkedTs: checkedTs,
                sourceUpdatedTs: current?.updatedTs,
                sourceVersion: current?.sourceVersion,
                sourceSequence: current?.sourceSequence,
                sourceBundleIdentifier: current?.sourceBundleIdentifier,
                timeZoneIdentifier: current?.timeZoneIdentifier
            )
            return false
        case .appGroupUnavailable:
            laylaScheduleBridgeStatus = LaylaScheduleBridgeStatus(
                state: .appGroupUnavailable,
                checkedTs: checkedTs
            )
            return false
        case .invalid(let failure):
            laylaScheduleBridgeStatus = LaylaScheduleBridgeStatus(
                state: .invalid,
                checkedTs: checkedTs,
                detail: "\(failure.message) Bull kept its last accepted schedule or fixed-hour fallback."
            )
            return false
        }
    }

    func isZoneActive(_ zone: HighRiskZone, at date: Date = Date()) -> Bool {
        zone.isActive(
            at: date,
            sleepSchedule: laylaSleepSchedule(at: date),
            calendar: BullDates.calendar
        )
    }

    func nextZoneActiveStart(_ zone: HighRiskZone, after date: Date = Date()) -> Date? {
        guard zone.scheduleMode == .sleepAnchored,
              let schedule = laylaSleepSchedule(at: date) else {
            return nextZoneScheduleStart(for: zone, after: date, calendar: BullDates.calendar)
        }
        switch schedule.state {
        case .sleeping:
            // Layla must confirm the final wake; a theoretical wake must not arm the zone.
            return nil
        case .plannedBriefWake:
            guard zone.activateWhenUnexpectedlyAwake,
                  let deadlineMS = schedule.expectedReturnToSleepByTs else { return nil }
            let nowMS = date.timeIntervalSince1970 * 1_000
            let preBedMS = schedule.plannedBedtimeTs -
                Double(zone.minutesAllowedBeforeBed) * 60_000
            guard deadlineMS > nowMS, deadlineMS < preBedMS else { return nil }
            return Date(timeIntervalSince1970: deadlineMS / 1_000)
        case .upForDay:
            break
        case .unexpectedlyAwake:
            guard zone.activateWhenUnexpectedlyAwake else {
                return nextZoneScheduleStart(for: zone, after: date, calendar: BullDates.calendar)
            }
        }
        let wake = schedule.actualFinalWakeTs ?? schedule.plannedFinalWakeTs
        let candidateMS = wake + Double(zone.minutesAllowedAfterFinalWake) * 60_000
        let preBedMS = schedule.plannedBedtimeTs -
            Double(zone.minutesAllowedBeforeBed) * 60_000
        let nowMS = date.timeIntervalSince1970 * 1_000
        guard candidateMS > nowMS, candidateMS < preBedMS else { return nil }
        return Date(timeIntervalSince1970: candidateMS / 1_000)
    }

    /// End of the effective active interval containing `date`. Notification scheduling uses
    /// this to pre-create a bounded follow-up series that cannot continue into a safe window.
    func zoneActiveEnd(_ zone: HighRiskZone, at date: Date) -> Date? {
        if zone.scheduleMode == .sleepAnchored, let schedule = laylaSleepSchedule(at: date) {
            switch schedule.state {
            case .sleeping:
                return nil
            case .plannedBriefWake:
                let nowMS = date.timeIntervalSince1970 * 1_000
                guard zone.activateWhenUnexpectedlyAwake,
                      let deadlineMS = schedule.expectedReturnToSleepByTs,
                      deadlineMS <= nowMS else { return nil }
                let end = Date(timeIntervalSince1970:
                    (schedule.plannedBedtimeTs - Double(zone.minutesAllowedBeforeBed) * 60_000) / 1_000
                )
                return end > date ? end : nil
            case .unexpectedlyAwake where !zone.activateWhenUnexpectedlyAwake:
                break // use the fixed fallback below
            case .unexpectedlyAwake, .upForDay:
                let end = Date(timeIntervalSince1970:
                    (schedule.plannedBedtimeTs - Double(zone.minutesAllowedBeforeBed) * 60_000) / 1_000
                )
                return end > date ? end : nil
            }
        }

        let calendar = BullDates.calendar
        var intervals: [DateInterval] = []
        for offset in -1...2 {
            let sample = BullDates.addingDays(offset, to: date)
            intervals.append(contentsOf: zone.scheduledIntervals(on: sample, calendar: calendar))
        }
        let ordered = intervals.sorted { $0.start < $1.start }
        guard let firstIndex = ordered.firstIndex(where: {
            date >= $0.start && date < $0.end
        }) else { return nil }
        var end = ordered[firstIndex].end
        for interval in ordered.dropFirst(firstIndex + 1) {
            guard abs(interval.start.timeIntervalSince(end)) < 1 else { break }
            end = max(end, interval.end)
        }
        return end
    }

    /// Common ingestion endpoint used by the live Layla bridge and legacy/import tests.
    /// Invalid or unversioned payloads are rejected; accepted snapshots are auditable and
    /// capped to the latest 30 records.
    @discardableResult
    func applyLaylaSleepSchedule(_ snapshot: LaylaSleepScheduleSnapshot) -> Bool {
        let nowMS = Self.nowMS
        let finalWake = snapshot.actualFinalWakeTs ?? snapshot.plannedFinalWakeTs
        let earliestRelevantWake = snapshot.plannedFinalWakeTs - 12 * 3_600_000
        let returnDeadlineIsValid = snapshot.expectedReturnToSleepByTs.map {
            let lowerBound = snapshot.stateObservedTs ?? earliestRelevantWake
            return $0 >= lowerBound && $0 <= snapshot.plannedBedtimeTs
        } ?? true
        guard snapshot.sourceIdentifier == "layla",
              snapshot.sourceVersion >= 1,
              snapshot.sourceSequence.map({ $0 >= 1 }) ?? true,
              snapshot.sourceBundleIdentifier.map({
                  !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 200
              }) ?? true,
              snapshot.timeZoneIdentifier.map({ TimeZone(identifier: $0) != nil }) ?? true,
              snapshot.plannedBedtimeTs > snapshot.plannedFinalWakeTs,
              snapshot.plannedBedtimeTs - snapshot.plannedFinalWakeTs <= 36 * 3_600_000,
              finalWake >= earliestRelevantWake,
              finalWake <= snapshot.plannedBedtimeTs,
              snapshot.stateObservedTs.map({
                  $0 >= earliestRelevantWake && $0 <= snapshot.plannedBedtimeTs
              }) ?? true,
              snapshot.updatedTs > 0,
              snapshot.updatedTs <= nowMS + 5 * 60_000,
              returnDeadlineIsValid,
              laylaSnapshotSourceIdentityIsConsistent(
                  incoming: snapshot,
                  existing: data.laylaSleepSchedules
              ),
              BullDates.date(from: snapshot.dayKey) != nil else {
            lastError = "Bull rejected an invalid Layla sleep-schedule snapshot."
            return false
        }
        switch laylaSnapshotIngestionDecision(
            incoming: snapshot,
            existing: data.laylaSleepSchedules
        ) {
        case .idempotent:
            lastError = nil
            return true
        case .rejectStale:
            lastError = "Bull ignored an older Layla schedule because a newer update already exists."
            return false
        case .rejectConflict:
            lastError = "Bull rejected conflicting Layla schedules with the same source order."
            return false
        case .accept:
            break
        }
        data.laylaSleepSchedules.removeAll {
            $0.id == snapshot.id ||
                ($0.dayKey == snapshot.dayKey && $0.sourceIdentifier == snapshot.sourceIdentifier)
        }
        data.laylaSleepSchedules.append(snapshot)
        data.laylaSleepSchedules = Array(
            data.laylaSleepSchedules.sorted { lhs, rhs in
                laylaSnapshotPrecedes(rhs, lhs)
            }.prefix(30)
        )

        var day = data.days[snapshot.dayKey] ?? DayRecord()
        var dayChanged = false
        if let actualFinalWakeTs = snapshot.actualFinalWakeTs {
            if day.sleepWakeTs != actualFinalWakeTs {
                day.sleepWakeTs = actualFinalWakeTs
                dayChanged = true
            }
        }
        if day.sleepPurposeScoreSource != "manual",
           !(day.sleepScoreSource?.hasPrefix("manual") ?? false),
           let deviation = snapshot.sleepConsistencyDeviationMinutes,
           let duration = day.sleepDurationPoints,
           let interruptions = day.sleepInterruptionsPoints {
            let consistency = BullSleepScore.consistencyPoints(
                deviationMinutes: min(720, max(0, deviation))
            )
            let purpose = BullSleepScore.purposeScores(
                durationPoints: duration,
                consistencyPoints: consistency,
                interruptionPoints: interruptions
            )
            day.sleepBedtimeDeviationMinutes = min(720, max(0, deviation))
            day.sleepConsistencyPoints = consistency
            day.preventionSleepScore = purpose.prevention
            day.vigourSleepScore = purpose.vigour
            day.sleepPurposeScoreSource = BullSleepScore.laylaPurposeSourceIdentifier
            day.sleepPurposeScoreVersion = BullSleepScore.purposeSourceVersion
            dayChanged = true
        }
        if dayChanged { data.days[snapshot.dayKey] = day }
        if dayChanged {
            refreshCorrectedFourScoreSnapshots(
                sourceDayKeys: [snapshot.dayKey], downstreamDays: 1
            )
        }
        lastError = nil
        persist()
        return true
    }

    @discardableResult
    func deleteZone(id: String) -> RiskControlMutationResult {
        guard let current = data.highRiskZones.first(where: { $0.id == id }) else {
            return .rejected(reason: "Risk Zone not found.")
        }
        if data.therapistOversight.protectsRiskControls {
            return requestRiskControlChange(RiskControlChangeRequest(
                kind: .deleteZone,
                zoneID: id,
                currentZone: current,
                summary: "Delete Risk Zone ‘\(current.name)’"
            ))
        }
        applyZoneDeletion(id: id)
        return .applied
    }

    private func applyZoneDeletion(id: String) {
        closeZoneOccupancyIfNeeded(zoneID: id)
        data.highRiskZones.removeAll { $0.id == id }
        // Event history deliberately remains, referencing the stable historical ID.
        persist()
    }

    private func closeZoneOccupancyIfNeeded(zoneID: String, at date: Date = Date()) {
        guard data.zoneEvents
            .filter({ $0.zoneID == zoneID })
            .max(by: { $0.ts < $1.ts })?.kind == .entered else { return }
        recordZoneEvent(zoneID: zoneID, kind: .exited, at: date)
    }

    func recordZoneEvent(zoneID: String, kind: ZoneEventKind, at date: Date = Date()) {
        let timestamp = date.timeIntervalSince1970 * 1000
        let latest = data.zoneEvents
            .filter({ $0.zoneID == zoneID })
            .max(by: { $0.ts < $1.ts })
        if latest?.kind == kind {
            if kind == .entered,
               let latest,
               let zone = data.highRiskZones.first(where: { $0.id == zoneID }) {
                if queueTherapistZoneEntry(zone: zone, zoneEventID: latest.id, at: date) {
                    persist()
                }
            }
            return
        }
        let visitStartedTs = kind == .exited && latest?.kind == .entered ? latest?.ts : nil
        let zoneEvent = ZoneEvent(
            zoneID: zoneID,
            kind: kind,
            ts: timestamp,
            dayKey: BullDates.key(for: date),
            baseRiskAtEvent: nil
        )
        data.zoneEvents.append(zoneEvent)
        if kind == .entered,
           let zone = data.highRiskZones.first(where: { $0.id == zoneID }) {
            _ = queueTherapistZoneEntry(zone: zone, zoneEventID: zoneEvent.id, at: date)
        }
        if kind == .exited,
           let zone = data.highRiskZones.first(where: { $0.id == zoneID }) {
            data.safeguardEvents.append(SafeguardEvent(
                zoneID: zoneID,
                safeguardID: zone.safeguard.id,
                kind: .visitEnded,
                occurrenceTs: timestamp,
                dayKey: BullDates.key(for: date),
                resolutionMode: zone.resolutionMode
            ))
            if let visitStartedTs {
                for index in data.riskAlertEvents.indices where
                    data.riskAlertEvents[index].zoneID == zoneID &&
                    data.riskAlertEvents[index].ts >= visitStartedTs &&
                    data.riskAlertEvents[index].ts <= timestamp {
                    appendAlertOutcome(.visitEnded, to: index, at: timestamp)
                }
            }
            if therapistOversightIsEnabled {
                queueTherapistEvent(TherapistOversightEvent(
                    kind: .zoneExited,
                    ts: timestamp,
                    dayKey: BullDates.key(for: date),
                    zoneID: zoneID,
                    zoneName: zone.name,
                    message: "Your client left the Risk Zone.",
                    requiresAttention: false,
                    deduplicationKey: "zone-exit.\(latest?.id ?? String(Int(timestamp)))"
                ))
            }
        }
        persist()
    }

    @discardableResult
    private func queueTherapistZoneEntry(
        zone: HighRiskZone,
        zoneEventID: String,
        at date: Date
    ) -> Bool {
        guard therapistOversightIsEnabled, zone.enabled else { return false }
        let isActive = isZoneActive(zone, at: date)
        let message: String
        if zone.resolutionMode == .exitRequired {
            message = isActive
                ? "Take action before you regret it! Your client entered an active Risk Zone that can only be resolved by leaving."
                : "Take action before you regret it! Your client entered a Risk Zone that has no in-place safeguard."
        } else {
            message = isActive
                ? "Take action before you regret it! Your client entered an active Risk Zone."
                : "Take action before you regret it! Your client entered a configured Risk Zone outside its active window."
        }
        return queueTherapistEvent(TherapistOversightEvent(
            kind: .zoneEntered,
            ts: date.timeIntervalSince1970 * 1_000,
            dayKey: BullDates.key(for: date),
            zoneID: zone.id,
            zoneName: zone.name,
            message: message,
            requiresAttention: true,
            deduplicationKey: "zone-entry.\(zoneEventID)"
        ))
    }

    func isInsideZone(_ zoneID: String) -> Bool {
        data.zoneEvents
            .filter { $0.zoneID == zoneID }
            .max(by: { $0.ts < $1.ts })?.kind == .entered
    }

    func isZoneSafeguarded(_ zoneID: String) -> Bool {
        guard isInsideZone(zoneID),
              let zone = data.highRiskZones.first(where: { $0.id == zoneID }),
              zone.resolutionMode == .safeguard,
              let entered = data.zoneEvents
                .filter({ $0.zoneID == zoneID && $0.kind == .entered })
                .max(by: { $0.ts < $1.ts }) else { return false }
        let relevant = data.safeguardEvents
            .filter {
                $0.zoneID == zoneID && $0.safeguardID == zone.safeguard.id && $0.ts >= entered.ts
            }
            .sorted { $0.ts < $1.ts }
        guard let last = relevant.last(where: {
            $0.kind == .completed || $0.kind == .reversed || $0.kind == .corrected
        }) else { return false }
        return last.kind == .completed || last.kind == .corrected
    }

    @discardableResult
    func recordSafeguardEvent(
        zoneID: String,
        kind: SafeguardEventKind,
        alertEventID: String? = nil,
        note: String? = nil,
        at date: Date = Date()
    ) -> SafeguardEvent? {
        guard let zone = data.highRiskZones.first(where: { $0.id == zoneID }) else { return nil }
        if zone.resolutionMode == .exitRequired,
           kind == .completed || kind == .corrected || kind == .reversed {
            lastError = "This Risk Zone has no in-place safeguard. Leave the zone to resolve it."
            return nil
        }
        let resolvedKind = kind == .completed
            ? safeguardCompletionKind(zoneID: zoneID, safeguardID: zone.safeguard.id)
            : kind
        let event = SafeguardEvent(
            zoneID: zoneID,
            safeguardID: zone.safeguard.id,
            kind: resolvedKind,
            occurrenceTs: date.timeIntervalSince1970 * 1_000,
            dayKey: BullDates.key(for: date),
            alertEventID: alertEventID,
            note: note,
            resolutionMode: zone.resolutionMode
        )
        data.safeguardEvents.append(event)
        // Completion changes display state only. It deliberately does not create a
        // ResponseAttempt or change Urge Risk.
        persist()
        return event
    }

    func alertPolicyDecision(
        tier: PressureTier,
        source: RiskAlertSource,
        zoneID: String?,
        now: Date = Date()
    ) -> AlertPolicyDecision {
        riskAlertPolicyDecision(
            proposedTier: tier,
            source: source,
            zoneID: zoneID,
            nowMS: now.timeIntervalSince1970 * 1_000,
            history: data.riskAlertEvents
        )
    }

    @discardableResult
    func recordRiskAlertAttempt(
        source: RiskAlertSource,
        tier: PressureTier,
        zoneID: String? = nil,
        safeguardID: String? = nil,
        contributors: [String],
        cooldownMinutes: Int = 180,
        now: Date = Date()
    ) -> RiskAlertEvent {
        let id = UUID().uuidString
        let route: AlertRoute = {
            if let zoneID, let safeguardID {
                return .zone(zoneID: zoneID, safeguardID: safeguardID, eventID: id)
            }
            return .risk(eventID: id)
        }()
        let timestamp = now.timeIntervalSince1970 * 1_000
        let event = RiskAlertEvent(
            id: id,
            ts: timestamp,
            dayKey: BullDates.key(for: now),
            source: source,
            tier: tier,
            zoneID: zoneID,
            safeguardID: safeguardID,
            route: route.value,
            leadingContributors: contributors,
            scoringVersion: currentFourScoreVersion,
            deliveryState: .attempted,
            cooldownUntilTs: timestamp + Double(max(15, cooldownMinutes)) * 60_000
        )
        data.riskAlertEvents.append(event)
        persist()
        return event
    }

    func updateRiskAlertDelivery(
        eventID: String,
        state: AlertDeliveryState,
        message: String? = nil
    ) {
        guard let index = data.riskAlertEvents.firstIndex(where: { $0.id == eventID }) else { return }
        data.riskAlertEvents[index].deliveryState = state
        data.riskAlertEvents[index].deliveryMessage = message
        persist()
    }

    func replaceRiskAlert(eventID: String, with replacementID: String) {
        guard let index = data.riskAlertEvents.firstIndex(where: { $0.id == eventID }) else { return }
        data.riskAlertEvents[index].deliveryState = .replaced
        data.riskAlertEvents[index].replacedByEventID = replacementID
        persist()
    }

    func cancelPendingZoneAlerts(zoneID: String) {
        var changed = false
        for index in data.riskAlertEvents.indices where
            data.riskAlertEvents[index].zoneID == zoneID &&
            (data.riskAlertEvents[index].deliveryState == .attempted ||
             data.riskAlertEvents[index].deliveryState == .scheduled ||
             data.riskAlertEvents[index].deliveryState == .observedForeground) {
            data.riskAlertEvents[index].deliveryState = .cancelled
            changed = true
        }
        if changed { persist() }
    }

    @discardableResult
    func cancelPendingGeneralRiskAlerts(above tier: PressureTier? = nil) -> Bool {
        var changed = false
        for index in data.riskAlertEvents.indices where
            data.riskAlertEvents[index].source == .compoundedRisk &&
            (data.riskAlertEvents[index].deliveryState == .attempted ||
             data.riskAlertEvents[index].deliveryState == .scheduled) &&
            (tier.map { data.riskAlertEvents[index].tier > $0 } ?? true) {
            data.riskAlertEvents[index].deliveryState = .cancelled
            changed = true
        }
        if changed { persist() }
        return changed
    }

    func handleRiskAlertAction(eventID: String, action: AlertUserAction, at date: Date = Date()) {
        guard let index = data.riskAlertEvents.firstIndex(where: { $0.id == eventID }) else { return }
        if action == .safeguardDone,
           let zoneID = data.riskAlertEvents[index].zoneID,
           data.highRiskZones.first(where: { $0.id == zoneID })?.resolutionMode == .exitRequired {
            lastError = "This Risk Zone can only be resolved by leaving it."
            return
        }
        let timestamp = date.timeIntervalSince1970 * 1_000
        data.riskAlertEvents[index].acknowledgedTs = timestamp
        data.riskAlertEvents[index].action = action
        if action == .openRiskPlan {
            data.riskAlertEvents[index].selectedInterventionIDs = Array(Set(
                data.riskAlertEvents[index].selectedInterventionIDs + ["risk-plan"]
            )).sorted()
        } else if action == .safeguardDone,
                  let safeguardID = data.riskAlertEvents[index].safeguardID {
            data.riskAlertEvents[index].selectedInterventionIDs = Array(Set(
                data.riskAlertEvents[index].selectedInterventionIDs + [safeguardID]
            )).sorted()
        }
        if action == .safeguardDone || action == .startResponse || action == .openRiskPlan {
            // Only safeguard completion is genuinely complete at this point. Starting or
            // opening a Response does not create a completion or change Urge Risk.
            if action == .safeguardDone { data.riskAlertEvents[index].completedTs = timestamp }
        }
        if action == .snooze {
            data.riskAlertEvents[index].snoozedUntilTs = timestamp + 10 * 60_000
        }
        if let zoneID = data.riskAlertEvents[index].zoneID {
            let safeguardKind: SafeguardEventKind
            switch action {
            case .safeguardDone:
                if let safeguardID = data.riskAlertEvents[index].safeguardID {
                    safeguardKind = safeguardCompletionKind(
                        zoneID: zoneID,
                        safeguardID: safeguardID
                    )
                } else {
                    safeguardKind = .completed
                }
            case .snooze: safeguardKind = .snoozed
            case .opened, .startResponse, .openRiskPlan: safeguardKind = .opened
            case .dismissed: safeguardKind = .actionSelected
            }
            if let zone = data.highRiskZones.first(where: { $0.id == zoneID }) {
                data.safeguardEvents.append(SafeguardEvent(
                    zoneID: zoneID,
                    safeguardID: zone.safeguard.id,
                    kind: safeguardKind,
                    occurrenceTs: timestamp,
                    dayKey: BullDates.key(for: date),
                    alertEventID: eventID,
                    resolutionMode: zone.resolutionMode
                ))
            }
        }
        persist()
    }

    private func safeguardCompletionKind(
        zoneID: String,
        safeguardID: String
    ) -> SafeguardEventKind {
        let lastStatus = data.safeguardEvents
            .filter {
                $0.zoneID == zoneID && $0.safeguardID == safeguardID &&
                ($0.kind == .completed || $0.kind == .corrected || $0.kind == .reversed)
            }
            .max { $0.ts < $1.ts }
        return lastStatus?.kind == .reversed ? .corrected : .completed
    }

    func linkRiskAlertToUrge(eventID: String, urgeID: String, at date: Date = Date()) {
        guard let index = data.riskAlertEvents.firstIndex(where: { $0.id == eventID }) else { return }
        let timestamp = date.timeIntervalSince1970 * 1_000
        data.riskAlertEvents[index].linkedUrgeID = urgeID
        appendAlertOutcome(.urgeLogged, to: index, at: timestamp)
        persist()
    }

    private func appendAlertOutcome(_ outcome: RiskAlertOutcome, to index: Int, at timestamp: Double) {
        guard data.riskAlertEvents.indices.contains(index) else { return }
        if !data.riskAlertEvents[index].laterOutcomes.contains(outcome) {
            data.riskAlertEvents[index].laterOutcomes.append(outcome)
        }
        data.riskAlertEvents[index].laterOutcomeTs = timestamp
    }

    func leadingRiskContributors(at date: Date = Date()) -> [String] {
        let state = urgeRiskState(at: date, includeLiveContexts: true)
        let values: [(String, Int)] = [
            ("Sleep and recovery deficit", Int(state.sleepRecovery.rounded())),
            ("Content access", Int(state.explicitContent.rounded())),
            ("Risky environment", Int(state.riskyEnvironment.rounded())),
            ("Post-release rebound", Int(state.postReleaseRebound.rounded()))
        ]
        return values
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map(\.0)
    }

    func riskAlertEvent(id: String) -> RiskAlertEvent? {
        data.riskAlertEvents.first { $0.id == id }
    }

    var activePrivateContext: PrivateContextSession? {
        data.privateContextSessions.last(where: { $0.endedTs == nil })
    }

    func togglePrivateContext() {
        if let activeIndex = data.privateContextSessions.lastIndex(where: { $0.endedTs == nil }) {
            data.privateContextSessions[activeIndex].endedTs = Self.nowMS
        } else {
            data.privateContextSessions.append(PrivateContextSession(dayKey: todayKey))
        }
        persist()
    }

    var hasPreImportBackup: Bool {
        FileManager.default.fileExists(atPath: preImportFileURL.path)
    }

    func importBackup(_ raw: Data) -> Bool {
        guard !data.therapistOversight.protectsRiskControls else {
            lastError = "End Therapist Oversight before importing a full backup. This prevents an older backup from replacing protected Risk Controls."
            return false
        }
        switch BackupImporter.importBackup(from: raw) {
        case .failure(let error):
            lastError = error.localizedDescription
            return false
        case .success(let result):
            // A verified safety copy is a precondition, not a best-effort side effect.
            // Never replace the current record while claiming an undo path that failed.
            guard savePreImportSnapshot() else { return false }
            let incoming = clearedTherapistTransportForImport(result.0)
            // Native-only fields decode with safe defaults when importing a PWA backup.
            data = incoming
            lastImportReport = result.1
            migrateToV15()
            repairBuiltInDisplayNames()
            repairBuiltInItemMetadata()
            backfillEventDayKeys()
            data.settings.lastOpenedTs = Self.nowMS
            // Preserve frozen native snapshots. v3.1 starts a new score era on the
            // migration day and never backfills an older score under new semantics.
            _ = finalizePastScores()
            persist()
            return true
        }
    }

    func restorePreImportBackup() -> Bool {
        guard !data.therapistOversight.protectsRiskControls else {
            lastError = "End Therapist Oversight before restoring an older full backup."
            return false
        }
        guard let raw = try? Data(contentsOf: preImportFileURL) else {
            lastError = "No pre-import backup is available."
            return false
        }
        do {
            let restored = clearedTherapistTransportForImport(
                try JSONDecoder().decode(BullData.self, from: raw)
            )
            data = restored
            migrateToV15()
            repairBuiltInDisplayNames()
            repairBuiltInItemMetadata()
            backfillEventDayKeys()
            data.settings.lastOpenedTs = Self.nowMS
            _ = finalizePastScores()
            try? FileManager.default.removeItem(at: preImportFileURL)
            persist()
            lastImportReport = nil
            return true
        } catch {
            lastError = "The pre-import backup could not be restored: \(error.localizedDescription)"
            return false
        }
    }

    func exportBackup() -> Data? {
        do { return try BackupImporter.exportData(data) }
        catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func exportRedactedTrends() -> Data? {
        do { return try BackupImporter.exportRedactedTrends(data) }
        catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func resolveGapDays(as kind: String?) {
        guard !gapDates.isEmpty else { return }
        if let kind {
            for date in gapDates {
                let key = BullDates.key(for: date)
                var d = data.days[key] ?? DayRecord()
                if kind == "sick" { d.sick = true }
                if kind == "travelling" { d.travelling = true }
                data.days[key] = d
            }
        }
        gapDates = []
        persist()
    }

    func resetAll() {
        guard !data.therapistOversight.protectsRiskControls else {
            lastError = "Revoke Therapist Oversight before wiping Bull data."
            return
        }
        // "Wipe Everything" must also remove rolling/recovery copies; otherwise private
        // history would remain recoverable after the user explicitly reset Bull.
        wipeStoredDataFiles()
        data = migratedBullDataToV15(BullData(), timeZone: .current)
        data.settings.lastOpenedTs = Self.nowMS
        selectedDate = Date()
        gapDates = []
        lastImportReport = nil
        lastError = nil
        persist(makeRollingBackup: false)
    }

    func cleanPercent(last days: Int = 30, endingAt end: Date = Date()) -> Int {
        guard days > 0 else { return 100 }
        let endDay = BullDates.startOfDay(end)
        let requestedStart = BullDates.addingDays(-(days - 1), to: endDay)
        let firstUseDay = BullDates.startOfDay(Date(timeIntervalSince1970: data.firstUse / 1000))
        let start = max(requestedStart, firstUseDay)
        guard start <= endDay else { return 100 }
        let span = (BullDates.calendar.dateComponents([.day], from: start, to: endDay).day ?? 0) + 1
        let dates = (0..<max(1, span)).map { BullDates.addingDays($0, to: start) }
        let relapseKeys = Set(data.relapses.filter(countsAsLapse).map(\.bullDayKey))
        let clean = dates.filter { !relapseKeys.contains(BullDates.key(for: $0)) }.count
        return Int((Double(clean) / Double(dates.count) * 100).rounded())
    }

    func cleanDelta(window days: Int = 30, endingAt end: Date = Date()) -> Int? {
        let firstUseDay = BullDates.startOfDay(Date(timeIntervalSince1970: data.firstUse / 1000))
        let endDay = BullDates.startOfDay(end)
        let age = BullDates.calendar.dateComponents([.day], from: firstUseDay, to: endDay).day ?? 0
        guard age >= days else { return nil }
        let previousEnd = BullDates.addingDays(-days, to: endDay)
        return cleanPercent(last: days, endingAt: endDay) - cleanPercent(last: days, endingAt: previousEnd)
    }

    func hrvBaseline(excluding date: Date? = nil) -> Double? {
        let reference = BullDates.startOfDay(date ?? Date())
        let candidates = data.days.compactMap { key, day -> (Date, Double)? in
            guard let sampleDate = BullDates.date(from: key),
                  sampleDate < reference,
                  let hrv = day.hrv, hrv > 0 else { return nil }
            return (sampleDate, hrv)
        }
        .sorted { $0.0 > $1.0 }
        .prefix(30)
        .map(\.1)

        guard candidates.count >= 7 else { return nil }
        return Self.median(Array(candidates))
    }

    func restingHeartRateBaseline(excluding date: Date? = nil) -> Double? {
        let reference = BullDates.startOfDay(date ?? Date())
        let candidates = data.days.compactMap { key, day -> (Date, Double)? in
            guard let sampleDate = BullDates.date(from: key),
                  sampleDate < reference,
                  let value = day.restingHeartRate, value > 0 else { return nil }
            return (sampleDate, value)
        }
        .sorted { $0.0 > $1.0 }
        .prefix(30)
        .map(\.1)

        guard candidates.count >= 7 else { return nil }
        return Self.median(Array(candidates))
    }

    func accountabilityPenalty(on date: Date) -> Double {
        guard data.settings.accountabilityEnabled else { return 0 }
        let key = BullDates.key(for: date)
        if data.accountabilityCheckIns.contains(where: { $0.dayKey == key && !$0.attended }) {
            return 15
        }
        guard let ms = data.settings.nextCheckin else { return 15 }
        let next = Date(timeIntervalSince1970: ms / 1000)
        if next < BullDates.startOfDay(date) { return 15 }
        let cadenceEnd = BullDates.calendar.date(
            byAdding: .day,
            value: data.settings.therapistEveryWeeks * 7 + 4,
            to: BullDates.startOfDay(date)
        ) ?? date
        return next > cadenceEnd ? 8 : 0
    }

    func countsAsLapse(_ event: RelapseEvent) -> Bool {
        data.settings.lapsePolicy.counts(Set(event.components))
    }

    /// v2.9's bounded 20-point environment component. Old room-level manual sessions stay
    /// exportable but never enter live Risk; only configured Risk Zones and their dwell do.
    private func v29RiskZoneContribution(on date: Date, includeLiveContexts: Bool) -> Double {
        var strongest = 0.0
        for zone in data.highRiskZones {
            guard let minutes = scheduledZoneExposureMinutes(
                zone: zone,
                on: date,
                endingAt: includeLiveContexts ? date : nil
            ) else { continue }
            let base: Double
            switch zone.riskLevel {
            case .low: base = 5
            case .medium: base = 10
            case .high: base = 18
            }
            let dwell = min(5, floor(max(0, minutes) / 30) * 2)
            strongest = max(strongest, min(20, base + dwell))
        }
        return strongest
    }

    private func zoneContribution(on date: Date, includeLiveContexts: Bool) -> Int {
        var total = 0

        // Disabled zones have already received a closing exit event. Keep their completed
        // exposure in historical/current-day Risk instead of making time already spent in
        // the context disappear when the user disables monitoring.
        for zone in data.highRiskZones {
            var minutes = scheduledZoneExposureMinutes(
                    zone: zone,
                    on: date,
                    endingAt: includeLiveContexts ? date : nil
                  )
            if minutes == nil,
               includeLiveContexts,
               BullDates.sameDay(date, Date()),
               isInsideZone(zone.id),
               isZoneActive(zone, at: date) {
                // A newly activated sleep-anchored zone may have no fixed-window overlap;
                // the active presence still contributes the zone's base risk immediately.
                minutes = 0
            }
            guard let minutes else { continue }
            total += zone.riskLevel.points + min(10, Int(minutes / 30) * 2)
        }

        if let minutes = privateContextExposureMinutes(
            on: date,
            endingAt: includeLiveContexts ? date : nil
        ) {
            total += ZoneRiskLevel.high.points + min(10, Int(minutes / 30) * 2)
        }
        return min(30, max(0, total))
    }

    /// Manual room-level sessions may legitimately cross midnight. Treat them as time
    /// intervals rather than assigning all exposure to the civil day on which Start was tapped.
    private func privateContextExposureMinutes(on date: Date, endingAt liveEnd: Date?) -> Double? {
        let dayStartDate = BullDates.startOfDay(date)
        let fullDayEnd = BullDates.addingDays(1, to: dayStartDate)
        let evaluationEnd = min(fullDayEnd, max(dayStartDate, liveEnd ?? fullDayEnd))
        guard evaluationEnd > dayStartDate else { return nil }

        let start = dayStartDate.timeIntervalSince1970 * 1_000
        let end = evaluationEnd.timeIntervalSince1970 * 1_000
        let sessions = data.privateContextSessions.filter { session in
            session.ts < end && (session.endedTs ?? end) > start
        }
        guard !sessions.isEmpty else { return nil }
        return sessions.reduce(0.0) { result, session in
            let sessionStart = min(end, max(start, session.ts))
            let sessionEnd = min(end, max(sessionStart, session.endedTs ?? end))
            return result + max(0, sessionEnd - sessionStart) / 60_000
        }
    }

    /// Returns scheduled occupancy minutes, or nil when no scheduled exposure occurred.
    /// Entry/exit events are paired across midnight so hotel stays and overnight bedroom
    /// rules contribute only during their configured active intervals.
    private func scheduledZoneExposureMinutes(
        zone: HighRiskZone,
        on date: Date,
        endingAt liveEnd: Date?
    ) -> Double? {
        let dayStartDate = BullDates.startOfDay(date)
        let fullDayEnd = BullDates.addingDays(1, to: dayStartDate)
        let evaluationEnd = min(fullDayEnd, max(dayStartDate, liveEnd ?? fullDayEnd))
        guard evaluationEnd > dayStartDate else { return nil }

        let dayStart = dayStartDate.timeIntervalSince1970 * 1_000
        let dayEnd = evaluationEnd.timeIntervalSince1970 * 1_000
        let zoneEvents = data.zoneEvents
            .filter { $0.zoneID == zone.id && $0.ts < dayEnd }
            .sorted { $0.ts < $1.ts }
        var inside = zoneEvents.last(where: { $0.ts < dayStart })?.kind == .entered
        var enteredAt: Double? = inside ? dayStart : nil
        var occupancy: [DateInterval] = []

        for event in zoneEvents where event.ts >= dayStart {
            let timestamp = min(dayEnd, max(dayStart, event.ts))
            if event.kind == .entered, !inside {
                inside = true
                enteredAt = timestamp
            } else if event.kind == .exited, inside {
                if let enteredAt, timestamp > enteredAt {
                    occupancy.append(DateInterval(
                        start: Date(timeIntervalSince1970: enteredAt / 1_000),
                        end: Date(timeIntervalSince1970: timestamp / 1_000)
                    ))
                }
                inside = false
                enteredAt = nil
            }
        }
        if inside, let enteredAt, dayEnd > enteredAt {
            occupancy.append(DateInterval(
                start: Date(timeIntervalSince1970: enteredAt / 1_000),
                end: evaluationEnd
            ))
        }

        let scheduled = zone.scheduledIntervals(on: dayStartDate, calendar: BullDates.calendar)
            .compactMap { interval -> DateInterval? in
                let start = max(interval.start, dayStartDate)
                let end = min(interval.end, evaluationEnd)
                return end > start ? DateInterval(start: start, end: end) : nil
            }
        let seconds = occupancy.reduce(0.0) { total, occupied in
            total + scheduled.reduce(0.0) { overlap, rule in
                overlap + max(0, min(occupied.end, rule.end).timeIntervalSince(max(occupied.start, rule.start)))
            }
        }

        if seconds > 0 { return seconds / 60 }
        let scheduledEntry = zoneEvents.contains { event in
            event.kind == .entered && event.ts >= dayStart && event.ts < dayEnd &&
                zone.isScheduled(at: event.date, calendar: BullDates.calendar)
        }
        return scheduledEntry ? 0 : nil
    }

    func scheduledVigourItems(on date: Date) -> [Item] {
        data.items.filter {
            !$0.isArchived && $0.list.feedsVigour && $0.kind.isToggleable &&
            adherenceExpected($0, on: date, settings: data.settings)
        }
    }

    func preventionItems() -> [Item] {
        data.items.filter { !$0.isArchived && $0.list.feedsPrevention && $0.kind.isToggleable }
    }

    private func makeFourScoreSnapshot(
        for date: Date,
        isFinal: Bool,
        revision: Int = 0,
        originalRecordedTs: Double? = nil
    ) -> FourScoreSnapshot {
        let state = fourScoreState(endingOn: date)
        return FourScoreSnapshot(
            urgeRoutine: state.urgeRoutine.score,
            urgeState: state.urgeState.score,
            bullRoutine: state.bullRoutine.score,
            bullState: state.bullState.score,
            scoringVersion: currentFourScoreVersion,
            recordedTs: Self.nowMS,
            isFinal: isFinal,
            revision: revision,
            originalRecordedTs: originalRecordedTs,
            routineComponents: RoutineComponentSnapshot(urge: state.urgeRoutine, bull: state.bullRoutine)
        )
    }

    /// Rebuilds only the current v3.2 scoring era. A source-day correction can affect its
    /// own score and, for routine inputs, the following six seven-day rolling snapshots.
    /// Earlier scoring versions remain frozen. Existing final rows retain their original
    /// timestamp and increment an explicit revision counter.
    private func refreshCorrectedFourScoreSnapshots<S: Sequence>(
        sourceDayKeys: S,
        downstreamDays: Int
    ) where S.Element == String {
        guard let startKey = data.settings.fourScoreV10StartDayKey else { return }
        let count = max(1, downstreamDays)
        var affectedKeys = Set<String>()
        for sourceKey in sourceDayKeys {
            guard sourceKey >= startKey, let sourceDate = BullDates.date(from: sourceKey) else { continue }
            for offset in 0..<count {
                let key = BullDates.key(for: BullDates.addingDays(offset, to: sourceDate))
                if key >= startKey && key < todayKey { affectedKeys.insert(key) }
            }
        }

        for key in affectedKeys.sorted() {
            guard let date = BullDates.date(from: key) else { continue }
            let existing = data.fourScoreSnapshots[key]
            guard existing == nil || existing?.scoringVersion == currentFourScoreVersion else { continue }
            let revisingFinal = existing?.isFinal == true
            data.fourScoreSnapshots[key] = makeFourScoreSnapshot(
                for: date,
                isFinal: true,
                revision: revisingFinal ? (existing?.revision ?? 0) + 1 : (existing?.revision ?? 0),
                originalRecordedTs: revisingFinal
                    ? (existing?.originalRecordedTs ?? existing?.recordedTs)
                    : existing?.originalRecordedTs
            )
        }
    }

    private func refreshTodayFourScoreSnapshot(at date: Date = Date()) {
        let key = BullDates.key(for: date)
        guard key == todayKey,
              let start = data.settings.fourScoreV10StartDayKey,
              key >= start else { return }
        data.fourScoreSnapshots[key] = makeFourScoreSnapshot(for: date, isFinal: false)
    }

    /// Only v3.2 dates are finalized here. v3.0/v3.1 rows and the legacy
    /// `scoreSnapshots` dictionary are never opened, recomputed or backfilled.
    private func finalizePastScores() -> Bool {
        guard let startKey = data.settings.fourScoreV10StartDayKey,
              let startDate = BullDates.date(from: startKey) else { return false }
        let yesterday = BullDates.addingDays(-1, to: Date())
        let span = BullDates.calendar.dateComponents(
            [.day], from: BullDates.startOfDay(startDate), to: BullDates.startOfDay(yesterday)
        ).day ?? -1
        guard span >= 0 else { return false }
        var changed = false
        for offset in 0...span {
            let date = BullDates.addingDays(offset, to: startDate)
            let key = BullDates.key(for: date)
            if data.fourScoreSnapshots[key]?.scoringVersion != currentFourScoreVersion ||
                data.fourScoreSnapshots[key]?.isFinal != true {
                data.fourScoreSnapshots[key] = makeFourScoreSnapshot(for: date, isFinal: true)
                changed = true
            }
        }
        return changed
    }

    private func backfillEventDayKeys() {
        for i in data.urges.indices where data.urges[i].dayKey == nil {
            data.urges[i].dayKey = BullDates.key(for: data.urges[i].date)
        }
        for i in data.relapses.indices where data.relapses[i].dayKey == nil {
            data.relapses[i].dayKey = BullDates.key(for: data.relapses[i].date)
        }
        for i in data.wetDreams.indices where data.wetDreams[i].dayKey == nil {
            data.wetDreams[i].dayKey = BullDates.key(for: data.wetDreams[i].date)
        }
    }

    private func detectGapDates(since previous: Date) {
        let prevStart = BullDates.startOfDay(previous)
        let todayStart = BullDates.startOfDay(Date())
        let span = BullDates.calendar.dateComponents([.day], from: prevStart, to: todayStart).day ?? 0
        guard span > 1 else { return }
        let eventKeys = Set(
            data.urges.map(\.bullDayKey)
            + data.relapses.map(\.bullDayKey)
            + data.wetDreams.map(\.bullDayKey)
        )
        var missing: [Date] = []
        if span > 1 {
            for i in 1..<span {
                let date = BullDates.addingDays(i, to: prevStart)
                let key = BullDates.key(for: date)
                if data.days[key] == nil && !eventKeys.contains(key) { missing.append(date) }
            }
        }
        gapDates = missing
    }

    private func eventTimestampMS(for date: Date) -> Double {
        if BullDates.sameDay(date, Date()) { return Self.nowMS }
        // Preserve the selected civil day while using the current local clock time as a
        // deterministic ingestion order. The source flag still marks the value as recalled;
        // this timestamp does not pretend the user supplied an exact occurrence time.
        let key = BullDates.key(for: date)
        let now = Date()
        let calendar = BullDates.calendar
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let clock = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: now)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = clock.hour
        components.minute = clock.minute
        components.second = clock.second
        components.nanosecond = clock.nanosecond
        var candidate = (calendar.date(from: components) ?? BullDates.startOfDay(date))
            .timeIntervalSince1970 * 1_000
        if let previous = lastGeneratedHistoricalTimestampByDay[key], candidate <= previous {
            candidate = previous + 1
        }
        lastGeneratedHistoricalTimestampByDay[key] = candidate
        return candidate
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    @discardableResult
    private func savePreImportSnapshot() -> Bool {
        do {
            let raw = try JSONEncoder().encode(data)
            try raw.write(to: preImportFileURL, options: [.atomic, .completeFileProtection])
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: preImportFileURL.path
            )
            let verified = try Data(contentsOf: preImportFileURL)
            _ = try JSONDecoder().decode(BullData.self, from: verified)
            return true
        } catch {
            try? FileManager.default.removeItem(at: preImportFileURL)
            lastError = "Bull could not create a pre-import safety copy: \(error.localizedDescription)"
            return false
        }
    }

    private func wipeStoredDataFiles() {
        let fm = FileManager.default
        let direct = [
            fileURL, previousFileURL, preImportFileURL, fileURL.appendingPathExtension("tmp"),
            legacyV14FileURL, legacyV14PreviousFileURL,
            dataDirectoryURL.appendingPathComponent("bull-data-v14.preimport.json"),
            legacyV13FileURL, legacyV13PreviousFileURL,
            dataDirectoryURL.appendingPathComponent("bull-data-v13.preimport.json"),
            legacyV12FileURL, legacyV12PreviousFileURL,
            dataDirectoryURL.appendingPathComponent("bull-data-v12.preimport.json"),
            legacyV11FileURL, legacyV11PreviousFileURL,
            dataDirectoryURL.appendingPathComponent("bull-data-v11.preimport.json"),
            legacyFileURL, legacyPreviousFileURL,
            legacyV9FileURL, legacyV9PreviousFileURL,
            dataDirectoryURL.appendingPathComponent("bull-data-v9.preimport.json"),
            dataDirectoryURL.appendingPathComponent("bull-data-v10.preimport.json"),
            legacyV8FileURL, legacyV8PreviousFileURL,
            dataDirectoryURL.appendingPathComponent("bull-data-v8.preimport.json")
        ]
        for url in direct { try? fm.removeItem(at: url) }
        if let files = try? fm.contentsOfDirectory(at: dataDirectoryURL, includingPropertiesForKeys: nil) {
            for url in files where url.lastPathComponent.hasPrefix("bull-data-recovery-") {
                try? fm.removeItem(at: url)
            }
        }
    }

    /// Retry the current in-memory edit after a failed write without creating the event again.
    func retryPendingWrite() { persist() }

    @discardableResult
    private func persist(makeRollingBackup: Bool = true) -> Bool {
        refreshTodayFourScoreSnapshot()
        if data.therapistAccessAudit.count > 2_000 {
            data.therapistAccessAudit = Array(data.therapistAccessAudit.suffix(2_000))
        }
        if data.riskControlChangeRequests.count > 2_000 {
            let pending = data.riskControlChangeRequests.filter { $0.status == .pending }
            let retainedClosed = data.riskControlChangeRequests
                .filter { $0.status != .pending }
                .sorted { $0.requestedTs > $1.requestedTs }
                .prefix(max(0, 2_000 - pending.count))
            data.riskControlChangeRequests = (pending + Array(retainedClosed))
                .sorted { $0.requestedTs < $1.requestedTs }
        }
        objectWillChange.send()
        revision &+= 1
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let raw = try encoder.encode(data)
            let tmp = fileURL.appendingPathExtension("tmp")
            try raw.write(to: tmp, options: [.atomic, .completeFileProtection])
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // Keep one rolling previous-good copy in addition to atomic replacement.
                if makeRollingBackup {
                    try? FileManager.default.removeItem(at: previousFileURL)
                    try? FileManager.default.copyItem(at: fileURL, to: previousFileURL)
                    try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: previousFileURL.path)
                }
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: fileURL)
            }
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )
            if publishesWidgets, data.therapistOversight.role == .owner {
                BullWidgetSnapshotBridge.publish(
                    data.fourScoreSnapshots[todayKey],
                    priorities: prioritiesPayload(),
                    charts: widgetChartsSnapshot()
                )
            } else if publishesWidgets {
                // A dedicated therapist installation must never retain a previous owner's
                // score snapshot in its shared widget container.
                BullWidgetSnapshotBridge.clear()
            }
            lastPersistedRevision = revision
            signalTherapistProjectionChangeIfNeeded()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func signalTherapistProjectionChangeIfNeeded() {
        guard therapistOversightIsEnabled else {
            lastSignalledTherapistProjection = nil
            return
        }
        var projection = makeTherapistProjection(
            from: data,
            monitoring: therapistMonitoringStatus
        )
        projection.generatedTs = 0
        projection.monitoring.updatedTs = 0
        guard projection != lastSignalledTherapistProjection else { return }
        lastSignalledTherapistProjection = projection
        NotificationCenter.default.post(name: .bullTherapistOutboxChanged, object: nil)
    }
}
