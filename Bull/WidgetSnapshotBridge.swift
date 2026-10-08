import Foundation
import WidgetKit
import SwiftUI

/// Explicit allowlist: generic actions and score weights, never notes or zone names.
struct BullPriorityAction: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var symbol: String
    var weightLabel: String
    var progress: Double?
    var rank: Double
}

struct BullPrioritiesPayload: Codable, Equatable {
    var actions: [BullPriorityAction]
    var updatedAt: Date
    var validUntil: Date
}

struct BullPriorityContext {
    var sleeping = false
    var unsafeZone = false
    var exitRequired = false
    var missingSleep = false
    var plannedCardio = 0.0
    var recordedCardio: Double?
    var plannedSets = 0
    var completedSets = 0
    var morningLogged = false
    var eveningLogged = false
    var eveningDue = false
    var pendingStressRelief = false
    var fuelPercent: Int?
    var bedtimeLabel: String?
    var fasting = false
}

enum BullPriorityBuilder {
    static func actions(_ context: BullPriorityContext) -> [BullPriorityAction] {
        var result: [BullPriorityAction] = []
        func add(_ id: String, _ title: String, _ detail: String, _ symbol: String,
                 _ weight: String, _ rank: Double, _ progress: Double? = nil) {
            result.append(BullPriorityAction(id: id, title: title, detail: detail, symbol: symbol,
                                             weightLabel: weight, progress: progress, rank: rank))
        }
        if context.unsafeZone {
            add("environment", context.exitRequired ? "Leave the risk zone" : "Complete your safeguard",
                "Active protection comes first", "shield.lefthalf.filled", "U 25%", 1_000, 0)
        }
        // A fixed-hour risk zone can still be active while Layla reports sleep.
        // Never let routine suppression hide that already-active safety action.
        if context.sleeping { return result }
        if context.missingSleep {
            add("syncSleep", "Sync or log sleep", "Record last night; do not redo it", "moon.fill", "U 40% · B 30%", 40)
        }
        if !context.fasting && context.plannedCardio > 0 && (context.recordedCardio ?? 0) < context.plannedCardio {
            let remaining = max(0, context.plannedCardio - (context.recordedCardio ?? 0))
            let label = context.recordedCardio == nil ? "planned" : "remaining"
            add("cardio", "Cardio · \(Int(remaining.rounded(.up))) min \(label)",
                "Follow today's plan; sync if done", "heart.fill", "B 40%", 40,
                context.recordedCardio.map { min(1, max(0, $0 / context.plannedCardio)) })
        }
        if context.pendingStressRelief {
            add("relief", "Finish stress-relief check-in", "Record how you feel afterwards", "leaf.fill", "U 35%", 36)
        } else if !context.morningLogged || (context.eveningDue && !context.eveningLogged) {
            add("stress", context.morningLogged ? "Evening stress check-in" : "Morning stress check-in",
                "Record honestly; logging is not recovery", "gauge.with.dots.needle.33percent", "U 35%", 35)
        }
        if context.eveningDue {
            add("prepareSleep", "Protect tonight's sleep", context.bedtimeLabel.map { "Planned bedtime · \($0)" } ?? "Prepare for your intended bedtime",
                "moon.stars.fill", "U 40% · B 30%", 39)
        }
        if context.fuelPercent == nil || context.fuelPercent == 50 {
            add("fuel", context.fuelPercent == nil ? "Follow / log Nutrition" : "Nutrition · partly recorded",
                "Record today's food-plan adherence", "fork.knife", "B 20%", 20,
                context.fuelPercent.map { Double($0) / 100 })
        }
        if !context.fasting && context.plannedSets > context.completedSets {
            add("strength", "Strength · \(context.plannedSets - context.completedSets) sets left",
                "Scheduled sets only; log if done", "dumbbell.fill", "B 10%", 10,
                Double(context.completedSets) / Double(context.plannedSets))
        }
        return result.sorted { $0.rank == $1.rank ? $0.id < $1.id : $0.rank > $1.rank }
    }
}

extension BullStore {
    func widgetChartsSnapshot(at now: Date = Date()) -> BullWidgetChartsSnapshot {
        let points = statsHistory(window: .month, now: now).suffix(30).map { day in
            BullWidgetChartPoint(
                date: day.date,
                urgeRoutine: BullFigureScore.normalized(day.snapshot?.urgeRoutine),
                urgeState: BullFigureScore.normalized(day.snapshot?.urgeState),
                preventionSleep: BullFigureScore.normalized(day.components?.preventionSleep),
                stressRegulation: BullFigureScore.normalized(day.components?.stressRegulation),
                environmentProtection: BullFigureScore.normalized(day.components?.environmentProtection)
            )
        }
        return BullWidgetChartsSnapshot(points: Array(points), updatedAt: now)
    }

    func prioritiesPayload(at now: Date = Date()) -> BullPrioritiesPayload {
        let day = day(for: now)
        let plan = planDay(on: now)
        let schedule = laylaSleepSchedule(at: now)
        let active = data.highRiskZones.filter { $0.enabled && isInsideZone($0.id) && isZoneActive($0, at: now) && !isZoneSafeguarded($0.id) }
        var planned = Set<String>()
        for exercise in plan?.strengthExercises ?? [] {
            for number in 1...max(1, exercise.targetSets) { planned.insert("\(exercise.id)#\(number)") }
        }
        let completed = Set((strengthWorkoutLog(on: now)?.sets ?? []).filter(\.completed).map { "\($0.exerciseID)#\($0.setNumber)" }).intersection(planned)
        let bedtime = schedule.map { Date(timeIntervalSince1970: $0.plannedBedtimeTs / 1_000) }
        let eveningDue = bedtime.map { $0.timeIntervalSince(now) <= 3 * 3_600 && $0 > now }
            ?? (BullDates.calendar.component(.hour, from: now) >= 18)
        let context = BullPriorityContext(
            sleeping: schedule?.state == .sleeping,
            unsafeZone: !active.isEmpty,
            exitRequired: active.contains { $0.resolutionMode == .exitRequired },
            missingSleep: day.preventionSleepForScoring == nil || day.vigourSleepForScoring == nil,
            plannedCardio: Double(plan?.plannedAerobicMinutes ?? 0),
            recordedCardio: manualExerciseLog(on: now)?.aerobicMinutesOverride ?? day.aerobicMinutes,
            plannedSets: planned.count, completedSets: completed.count,
            morningLogged: stressCheckIn(.morning, on: now) != nil,
            eveningLogged: stressCheckIn(.evening, on: now) != nil,
            eveningDue: eveningDue,
            pendingStressRelief: pendingStressReliefLogs.contains { $0.dayKey == BullDates.key(for: now) },
            fuelPercent: bullFuelPercent(on: now),
            bedtimeLabel: bedtime?.formatted(date: .omitted, time: .shortened),
            fasting: isFasting(on: now)
        )
        let midnight = BullDates.addingDays(1, to: BullDates.startOfDay(now))
        return BullPrioritiesPayload(actions: BullPriorityBuilder.actions(context), updatedAt: now,
                                     validUntil: min(midnight, now.addingTimeInterval(30 * 60)))
    }
}

/// Publishes the smallest possible home-screen projection of Bull's private data.
/// Separate payloads contain live scores and generic pending-action summaries.
/// Neither includes observations, raw HealthKit, relapse history, notes or zone identity.
enum BullWidgetSnapshotBridge {
    static let appGroupIdentifier = "group.com.ahmed.Bull"
    static let payloadKey = "bull-widget-score-snapshot-v1"
    static let prioritiesKey = "bull-widget-priorities-v1"
    static let chartsKey = BullWidgetChartsSnapshot.payloadKey

    private static let widgetKinds = [
        "BullFaceOffWidget", "BullRoutineFiguresWidget", "BullPrioritiesWidget",
        "BullUrgeOverviewChartWidget", "BullUrgeBreakdownChartWidget"
    ]

    static func publish(
        _ snapshot: FourScoreSnapshot?,
        priorities: BullPrioritiesPayload,
        charts: BullWidgetChartsSnapshot
    ) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        let next = BullFigureSnapshot(
            bullState: BullFigureScore.normalized(snapshot?.bullState),
            urgeState: BullFigureScore.normalized(snapshot?.urgeState),
            bullRoutine: BullFigureScore.normalized(snapshot?.bullRoutine),
            urgeRoutine: BullFigureScore.normalized(snapshot?.urgeRoutine),
            updatedAt: Date()
        )
        let decoder = JSONDecoder()
        var changed = false
        if let existingData = defaults.data(forKey: payloadKey),
           let existing = try? decoder.decode(BullFigureSnapshot.self, from: existingData),
           existing.hasSameScores(as: next), Calendar.current.isDate(existing.updatedAt, inSameDayAs: next.updatedAt) {
            // No score change; priorities can still change independently.
        } else if let encoded = try? JSONEncoder().encode(next) {
            defaults.set(encoded, forKey: payloadKey)
            changed = true
        }
        if let raw = defaults.data(forKey: prioritiesKey),
           let old = try? decoder.decode(BullPrioritiesPayload.self, from: raw),
           old.actions == priorities.actions,
           priorities.updatedAt.timeIntervalSince(old.updatedAt) < 5 * 60,
           old.validUntil > priorities.updatedAt {
            // Coalesce routine foreground ticks, never hide changed tasks.
        } else if let raw = try? JSONEncoder().encode(priorities) {
            defaults.set(raw, forKey: prioritiesKey)
            changed = true
        }
        if let raw = defaults.data(forKey: chartsKey),
           let old = try? decoder.decode(BullWidgetChartsSnapshot.self, from: raw),
           old.points == charts.points,
           charts.updatedAt.timeIntervalSince(old.updatedAt) < 15 * 60 {
            // Completed-day history changes infrequently; avoid redundant reloads.
        } else if let raw = try? JSONEncoder().encode(charts), raw.count < 64_000 {
            defaults.set(raw, forKey: chartsKey)
            changed = true
        }
        if changed { reloadWidgets() }
    }

    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        guard defaults.object(forKey: payloadKey) != nil ||
                defaults.object(forKey: prioritiesKey) != nil ||
                defaults.object(forKey: chartsKey) != nil else { return }
        defaults.removeObject(forKey: payloadKey)
        defaults.removeObject(forKey: prioritiesKey)
        defaults.removeObject(forKey: chartsKey)
        reloadWidgets()
    }

    private static func reloadWidgets() {
        for kind in widgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}

struct TodayPrioritiesView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var privacy: PrivacyManager
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var route: PriorityRoute?
    @State private var syncing = false
    @State private var syncMessage: String?
    @State private var actionDate = Date()

    private var canPresentEntry: Bool {
        !privacy.isShielded && (!preferences.biometricLockEnabled || privacy.isUnlocked)
    }

    private enum PriorityRoute: String, Identifiable {
        case stress, relief, strength, cardio, environment, sleep
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                let actions = store.prioritiesPayload().actions
                if actions.isEmpty {
                    Text("No pending actions identified from current data. Open Today to review your plan and logs.")
                }
                ForEach(actions) { action in
                    Section {
                        Button { handle(action) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Label(BullRecordingStatus.displayTitle(action.title), systemImage: action.symbol).font(.headline)
                                Text(action.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(syncing)
                        if action.id == "fuel" {
                            HStack {
                                Button("On Plan") { store.setBullFuel(100, on: Date()) }
                                Spacer()
                                Button("Partly") { store.setBullFuel(50, on: Date()) }
                                Spacer()
                                Button("Off Plan") { store.setBullFuel(0, on: Date()) }
                            }
                            .font(.caption)
                        }
                    }
                }
                if syncing { ProgressView("Syncing Health…") }
                if let syncMessage { Text(syncMessage).font(.caption) }
            }
            .navigationTitle("Today's Priorities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $route) { selected in
                switch selected {
                case .stress: StressCheckInView()
                case .relief: StressReliefEntryView(date: actionDate)
                case .strength: StrengthWorkoutEntryView(date: actionDate)
                case .cardio: ManualExerciseEntryView(date: actionDate)
                case .environment: HighRiskZonesView()
                case .sleep:
                    PurposeSleepEntryView(prevention: store.day(for: actionDate).preventionSleepForScoring,
                                          vigour: store.day(for: actionDate).vigourSleepForScoring) { prevention, vigour in
                        store.updateDay(for: actionDate) { day in
                            day.preventionSleepScore = prevention
                            day.vigourSleepScore = vigour
                            day.sleepPurposeScoreSource = prevention == nil && vigour == nil ? nil : "manual"
                            day.sleepPurposeScoreVersion = prevention == nil && vigour == nil ? nil : 1
                            let values = [prevention, vigour].compactMap { $0 }
                            day.sleep = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
                            day.sleepScoreSource = values.isEmpty ? nil : "manual-purpose-average"
                            day.sleepScoreVersion = values.isEmpty ? nil : 1
                        }
                    }
                }
            }
        }
        .overlay {
            if privacy.isShielded {
                PrivacyShieldView()
            } else if preferences.biometricLockEnabled && !privacy.isUnlocked {
                ZStack {
                    PrivacyShieldView()
                    Button("Unlock Bull") { Task { await privacy.unlock() } }
                        .buttonStyle(.borderedProminent)
                        .tint(BullTheme.gold)
                        .foregroundStyle(BullTheme.ink)
                }
            }
        }
        .onChange(of: privacy.isShielded) { _, shielded in if shielded { route = nil } }
        .onChange(of: privacy.isUnlocked) { _, unlocked in
            if preferences.biometricLockEnabled && !unlocked { route = nil }
        }
    }

    private func handle(_ action: BullPriorityAction) {
        guard canPresentEntry else { return }
        let targetDate = Date()
        actionDate = targetDate
        store.selectedDate = targetDate
        if action.id == "syncSleep" {
            syncing = true
            Task {
                if await health.requestAuthorization() {
                    let result = await health.importForNightEnding(on: targetDate)
                    _ = store.applyHealthBackfill([DatedHealthImportResult(date: targetDate, result: result)])
                }
                syncing = false
                let day = store.day(for: targetDate)
                if day.preventionSleepForScoring == nil || day.vigourSleepForScoring == nil {
                    syncMessage = health.lastError ?? "Sleep not available from Health; manual entry is optional."
                    if canPresentEntry { route = .sleep }
                } else { syncMessage = "Sleep data refreshed." }
            }
        } else if action.id == "prepareSleep" {
            syncMessage = action.detail + ". This supports the next night; it does not change last night's recorded score."
        } else if action.id == "fuel" {
            syncMessage = "Use On Plan, Partly or Off Plan to record today honestly."
        } else if action.id == "cardio" {
            syncing = true
            Task {
                if await health.requestAuthorization() {
                    let result = await health.importForNightEnding(on: targetDate)
                    _ = store.applyHealthBackfill([DatedHealthImportResult(date: targetDate, result: result)])
                    syncMessage = health.lastError ?? "Health refreshed. Corrections replace imported minutes."
                } else { syncMessage = health.lastError ?? "Health access request could not complete." }
                syncing = false
                if canPresentEntry { route = .cardio }
            }
        } else { route = PriorityRoute(rawValue: action.id) }
    }
}
