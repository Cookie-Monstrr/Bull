import SwiftUI

enum BullEntryKind {
    case log, urge, urgeSupport, stress, relief, morning, desire, bullState
    case nutrition, sleep, cardio, strength, exercisePlan, stressPlan
    case zones, history, lapse, experiments
}

struct BullEntryRoute: Identifiable {
    let id = UUID()
    let kind: BullEntryKind
    let date: Date
    var editLatest = false
    var domain: BullTodayDomain = .urge
}

struct BullEntryDestination: View {
    @EnvironmentObject private var store: BullStore
    let route: BullEntryRoute

    var body: some View {
      Group {
        switch route.kind {
        case .log: DailyLogView(date: route.date, domain: route.domain)
        case .urge: UrgeStateEntryView(date: route.date, editLatest: route.editLatest)
        case .urgeSupport: UrgeSupportView()
        case .stress: StressCheckInView(date: route.date)
        case .relief: StressReliefEntryView(date: route.date)
        case .morning: SexualCheckInView(date: route.date, initialKind: .morningErection, editLatest: route.editLatest)
        case .desire: SexualCheckInView(date: route.date, initialKind: .naturalDesire, editLatest: route.editLatest)
        case .bullState: SexualCheckInView(date: route.date)
        case .nutrition: NutritionEntryView(date: route.date)
        case .sleep:
            PurposeSleepEntryView(
                prevention: store.day(for: route.date).preventionSleepForScoring,
                vigour: store.day(for: route.date).vigourSleepForScoring
            ) { prevention, vigour in
                store.updateDay(for: route.date) { day in
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
        case .cardio: ManualExerciseEntryView(date: route.date)
        case .strength: StrengthWorkoutEntryView(date: route.date)
        case .exercisePlan: ExercisePlanView()
        case .stressPlan: StressPlanSettingsView()
        case .zones: HighRiskZonesView()
        case .history: MonthHistoryView()
        case .lapse: LapseLogView(date: route.date)
        case .experiments: PersonalExperimentManagerView()
        }
      }
      .bullEditorPrivacy()
    }
}

struct DailyLogView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    let date: Date
    var domain: BullTodayDomain = .urge
    @State private var route: BullEntryRoute?
    @State private var syncing = false

    private var day: DayRecord { store.day(for: date) }
    private var morning: BullStateObservation? {
        store.bullStateObservations(on: date).filter { $0.kind != .naturalDesire }.max { $0.ts < $1.ts }
    }
    private var desire: BullStateObservation? {
        store.bullStateObservations(on: date).filter { $0.healthyDesire != nil }.max { $0.ts < $1.ts }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(BullDates.sameDay(date, Date()) ? "Today" : date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(BullTheme.goldDark)
                }
                if domain == .urge { urgeSection; bullSection } else { bullSection; urgeSection }
                Section("Sleep") {
                    entryRow("Sleep Scores", detail: sleepDetail, icon: "moon.fill", kind: .sleep)
                }
                Section("Events") {
                    entryRow("Log Lapse", detail: "Add an Event", icon: "plus.circle", kind: .lapse)
                }
            }
            .disabled(syncing)
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Task { await syncHealth() } } label: {
                        if syncing { ProgressView() }
                        else { Label("Sync Health", systemImage: "arrow.triangle.2.circlepath") }
                    }
                    .disabled(syncing)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .bullFormSurface()
        // The log hub stays mounted while an editor is open, preserving its position.
        .sheet(item: $route) { BullEntryDestination(route: $0) }
    }

    private func syncHealth() async {
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        if !health.authorizationRequestCompleted, !(await health.requestAuthorization()) {
            feedback.show(health.lastError ?? "Health Access Wasn't Completed", isError: true)
            return
        }
        let result = await health.importForNightEnding(on: date)
        let changed = store.applyHealthBackfill([DatedHealthImportResult(date: date, result: result)])
        preferences.markHealthSyncCompleted()
        feedback.show(changed > 0 ? "Health Data Updated" : "Health Checked")
    }

    private var urgeSection: some View {
        Section("Urge") {
            let last = store.pornUrgeObservations(on: date).max { $0.ts < $1.ts }
            entryRow("Urge Check-In", detail: last.map { "Latest: \($0.intensity)/10 · \($0.date.formatted(date: .omitted, time: .shortened))" } ?? "Not Recorded",
                     icon: "waveform.path.ecg", kind: .urge, canEdit: last != nil)
            let am = store.stressCheckIn(.morning, on: date)
            let pm = store.stressCheckIn(.evening, on: date)
            entryRow("Stress Check-In", detail: am == nil && pm == nil ? "Not Recorded" :
                        "Morning: \(am.map { "\($0.value)/10" } ?? "—") · Evening: \(pm.map { "\($0.value)/10" } ?? "—")",
                     icon: "gauge.with.dots.needle.33percent", kind: .stress)
            let pending = store.pendingStressReliefLogs.contains { $0.dayKey == BullDates.key(for: date) }
            entryRow("Stress Relief", detail: pending ? "Finish Check-In" : "Start or Record an Activity",
                     icon: "leaf.fill", kind: .relief)
        }
    }

    private var bullSection: some View {
        Section("Bull") {
            entryRow("Morning Erection", detail: morning.map { "Recorded · \($0.date.formatted(date: .omitted, time: .shortened))" } ?? "After Waking · Not Recorded",
                     icon: "sunrise.fill", kind: .morning, canEdit: morning != nil)
            entryRow("Natural Desire", detail: desire?.healthyDesire.map { "Latest: \($0)/10" } ?? "Later in the Day · Not Recorded",
                     icon: "sun.horizon.fill", kind: .desire, canEdit: desire != nil)
            let nutrition = store.bullFuelPercent(on: date)
            entryRow("Nutrition & Fasting", detail: NutritionEntryView.label(nutrition) + (store.isFasting(on: date) ? " · Fasting Rest Day" : ""),
                     icon: "fork.knife", kind: .nutrition)
            let completed = store.strengthWorkoutLog(on: date)?.sets.filter(\.completed).count
            entryRow("Strength", detail: completed.map { "\($0) Sets Recorded" } ?? "Not Recorded",
                     icon: "dumbbell.fill", kind: .strength)
            let minutes = store.manualExerciseLog(on: date)?.aerobicMinutesOverride ?? day.aerobicMinutes
            entryRow("Cardio", detail: minutes.map { "\(Int($0.rounded())) Min · Review or Edit" } ?? "Not Recorded",
                     icon: "heart.fill", kind: .cardio)
        }
    }

    private var sleepDetail: String {
        guard day.preventionSleepForScoring != nil || day.vigourSleepForScoring != nil else { return "Not Recorded" }
        return "Pre-filled · Review or Edit"
    }

    private func entryRow(_ title: String, detail: String, icon: String, kind: BullEntryKind, canEdit: Bool = false) -> some View {
        HStack(spacing: 8) {
            Button { route = BullEntryRoute(kind: kind, date: date) } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon).frame(width: 24).foregroundStyle(BullTheme.goldDark)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(BullTheme.ink)
                        Text(detail).font(.caption).foregroundStyle(BullTheme.secondary)
                    }
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(BullTheme.muted)
                }
                .frame(minHeight: BullTheme.controlHeight).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if canEdit {
                Button("Edit") { route = BullEntryRoute(kind: kind, date: date, editLatest: true) }
                    .font(.caption.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit Latest \(title)")
            }
        }
    }
}

/// A field-level snapshot makes Undo leave every unrelated record untouched.
struct BullNutritionSnapshot: Equatable {
    let percent: Int?
    let eating: Bool?
    let eatingCompletion: CompletionRecord?
    let fasting: Bool?
    let fastingCompletion: CompletionRecord?

    init(_ day: DayRecord) {
        percent = day.bullFuelPercent
        eating = day.heartHealthyEating
        eatingCompletion = day.completionStates["heartHealthyEating"]
        fasting = day.checks["fasting"]
        fastingCompletion = day.completionStates["fasting"]
    }

    func restore(_ day: inout DayRecord) {
        day.bullFuelPercent = percent
        day.heartHealthyEating = eating
        day.completionStates["heartHealthyEating"] = eatingCompletion
        day.checks["fasting"] = fasting
        day.completionStates["fasting"] = fastingCompletion
    }
}

struct NutritionEntryView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var percent: Int?
    @State private var fasting = false
    @State private var loaded = false
    @State private var originalPercent: Int?
    @State private var originalFasting = false
    @State private var confirmingDiscard = false

    private var isDirty: Bool { loaded && (percent != originalPercent || fasting != originalFasting) }

    static func label(_ value: Int?) -> String {
        switch value {
        case .some(100): return "On Plan"
        case .some(50): return "Partly"
        case .some(0): return "Off Plan"
        default: return "Not Recorded"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nutrition") {
                    Picker("Food Plan", selection: $percent) {
                        Text("Not Recorded").tag(Int?.none)
                        Text("On Plan").tag(Int?.some(100))
                        Text("Partly").tag(Int?.some(50))
                        Text("Off Plan").tag(Int?.some(0))
                    }
                    .pickerStyle(.inline).labelsHidden()
                }
                Section {
                    Toggle("Fasting", isOn: $fasting)
                    if fasting {
                        Label("Rest Day · +10 Urge Fuel", systemImage: "moon.stars.fill")
                            .font(.caption).foregroundStyle(BullTheme.goldDark)
                    }
                }
            }
            .navigationTitle("Nutrition & Fasting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if isDirty { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
        .bullFormSurface()
        .bullDraftGuard(isDirty: isDirty, confirming: $confirmingDiscard) { dismiss() }
        .onAppear {
            guard !loaded else { return }
            percent = store.bullFuelPercent(on: date)
            fasting = store.isFasting(on: date)
            originalPercent = percent
            originalFasting = fasting
            loaded = true
        }
    }

    private func save() {
        let before = BullNutritionSnapshot(store.day(for: date))
        guard feedback.save(store, message: "Nutrition Saved", change: {
            store.setBullFuel(percent, on: date, fasting: fasting == store.isFasting(on: date) ? nil : fasting)
        }) else { return }
        let saved = BullNutritionSnapshot(store.day(for: date))
        feedback.show("Nutrition Saved", undo: {
            guard BullNutritionSnapshot(store.day(for: date)) == saved else {
                feedback.show("This Entry Has Changed. Open Nutrition to Edit.")
                return
            }
            feedback.save(store, message: "Change Undone") {
                store.updateDay(for: date) { before.restore(&$0) }
            }
        })
        dismiss()
    }
}
