import SwiftUI

struct ExercisePlanView: View {
    @EnvironmentObject private var store: BullStore
    @Environment(\.dismiss) private var dismiss
    @State private var editor: Editor?

    private enum Editor: Identifiable {
        case cardio(Date), strength(Date), day(ExercisePlanDay, Int)
        var id: String {
            switch self {
            case .cardio: return "cardio"
            case .strength: return "strength"
            case .day(let day, _): return day.id
            }
        }
    }

    private var plan: ExercisePlanVersion? { store.activeExercisePlan() }
    private var routine: BullRoutineState { store.fourScoreState().bullRoutine }
    private var todayPlanDay: ExercisePlanDay? { store.planDay() }

    var body: some View {
        NavigationStack {
            List {
                if let plan {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active Plan")
                                .font(.caption.weight(.bold)).foregroundStyle(BullTheme.goldDark)
                            Text("My Exercise Plan").font(.headline)
                            Text("Edits apply from today. Completed workouts stay unchanged.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Section("Today") {
                        if let day = todayPlanDay {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(day.title).font(.headline)
                                    Text(day.kind.rawValue.capitalized)
                                        .font(.caption.weight(.bold)).foregroundStyle(BullTheme.goldDark)
                                }
                                Spacer()
                            }
                            if !(day.strengthExercises?.isEmpty ?? true) {
                                Button(store.strengthWorkoutLog()?.sets.contains(where: \.completed) == true
                                    ? "Edit Strength Workout" : "Log Strength Workout") {
                                    editor = .strength(Date())
                                }
                            }
                            Button("Edit Today's Plan Day") { editor = .day(day, resolvedWeekday(for: day)) }
                        } else {
                            Text("No plan day assigned to today.").foregroundStyle(.secondary)
                        }
                        Button("Log Cardio") { editor = .cardio(Date()) }
                    }

                    Section("Rolling 7 Days") {
                        progressRow(
                            "Cardio",
                            value: routine.weeklyModerateEquivalentMinutes,
                            target: Double(plan.weeklyModerateEquivalentTarget),
                            suffix: "min"
                        )
                        LabeledContent(
                            "Cardio Active Energy",
                            value: routine.weeklyCardioActiveCalories.map {
                                "\(Int($0.rounded())) kcal"
                            } ?? "—"
                        )
                        progressRow(
                            "Strength",
                            value: Double(routine.weeklyStrengthCompletedSets),
                            target: Double(routine.weeklyStrengthScheduledSets),
                            suffix: "sets"
                        )
                        Text("Apple Health supplies cardio minutes and active calories. Strength uses completed scheduled sets.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Section("Weekly Schedule") {
                        ForEach(plan.days.sorted(by: scheduleSort)) { day in
                            DisclosureGroup {
                                ForEach(day.prescription, id: \.self) { Text($0).font(.caption) }
                                ForEach(day.strengthExercises ?? []) { exercise in
                                    LabeledContent(exercise.name, value: "\(exercise.targetSets) × \(exercise.minimumReps)–\(exercise.maximumReps)")
                                        .font(.subheadline)
                                }
                                Button("Edit This Day") { editor = .day(day, resolvedWeekday(for: day)) }
                            } label: {
                                HStack {
                                    Text(scheduleLabel(day)).font(.caption.weight(.black)).foregroundStyle(BullTheme.goldDark)
                                        .frame(width: 66, alignment: .leading)
                                    Text(day.title).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    if todayPlanDay?.id == day.id {
                                        Text("Today").font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6).padding(.vertical, 3)
                                            .background(BullTheme.gold.opacity(0.18)).clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section { Text("No exercise plan is available.").foregroundStyle(.secondary) }
                }

            }
            .navigationTitle("Exercise Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .bullFormSurface()
        .sheet(item: $editor) { selected in
            switch selected {
            case .cardio(let date): ManualExerciseEntryView(date: date)
            case .strength(let date): StrengthWorkoutEntryView(date: date)
            case .day(let day, let weekday): ExerciseDayEditorView(day: day, defaultWeekday: weekday)
            }
        }
    }

    private func progressRow(_ title: String, value: Double, target: Double, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.rounded())) / \(Int(target.rounded())) \(suffix)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
            }
            ProgressView(value: min(target, value), total: max(1, target)).tint(BullTheme.gold)
        }
    }

    private func scheduleLabel(_ day: ExercisePlanDay) -> String {
        guard let weekday = day.weekday else { return "Day \(day.dayNumber)" }
        return Calendar.current.weekdaySymbols[weekday - 1]
    }

    private func scheduleSort(_ lhs: ExercisePlanDay, _ rhs: ExercisePlanDay) -> Bool {
        (lhs.weekday ?? lhs.dayNumber) < (rhs.weekday ?? rhs.dayNumber)
    }

    private func resolvedWeekday(for day: ExercisePlanDay) -> Int {
        if let weekday = day.weekday { return weekday }
        guard let startKey = plan?.startDayKey,
              let start = BullDates.date(from: startKey) else { return day.dayNumber }
        let scheduled = BullDates.addingDays(day.dayNumber - 1, to: start)
        return BullDates.calendar.component(.weekday, from: scheduled)
    }
}

private struct ExerciseDayEditorView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    let original: ExercisePlanDay
    let initialWeekday: Int
    @State private var title: String
    @State private var kind: ExerciseDayKind
    @State private var weekday: Int
    @State private var aerobicMinutes: Int
    @State private var exercises: [StrengthExercisePrescription]
    @State private var confirmingDiscard = false

    private var isDirty: Bool {
        title != original.title || kind != original.kind || weekday != initialWeekday ||
        aerobicMinutes != original.plannedAerobicMinutes || exercises != (original.strengthExercises ?? [])
    }

    init(day: ExercisePlanDay, defaultWeekday: Int) {
        original = day
        initialWeekday = day.weekday ?? min(7, max(1, defaultWeekday))
        _title = State(initialValue: day.title)
        _kind = State(initialValue: day.kind)
        _weekday = State(initialValue: day.weekday ?? min(7, max(1, defaultWeekday)))
        _aerobicMinutes = State(initialValue: day.plannedAerobicMinutes)
        _exercises = State(initialValue: day.strengthExercises ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule") {
                    TextField("Day Title", text: $title)
                    Picker("Weekday", selection: $weekday) {
                        ForEach(1...7, id: \.self) { value in
                            Text(Calendar.current.weekdaySymbols[value - 1]).tag(value)
                        }
                    }
                    Picker("Type", selection: $kind) {
                        ForEach(ExerciseDayKind.allCases, id: \.rawValue) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Stepper("Planned Cardio: \(aerobicMinutes) Min", value: $aerobicMinutes, in: 0...300, step: 5)
                }

                if kind == .strength {
                    Section("Strength Exercises") {
                        if exercises.isEmpty {
                            Text("No Structured Exercises Yet").foregroundStyle(.secondary)
                        }
                        ForEach($exercises) { $exercise in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Exercise", text: $exercise.name)
                                Stepper("Sets: \(exercise.targetSets)", value: $exercise.targetSets, in: 1...12)
                                Stepper("Minimum Reps: \(exercise.minimumReps)", value: $exercise.minimumReps, in: 1...exercise.maximumReps)
                                Stepper("Maximum Reps: \(exercise.maximumReps)", value: $exercise.maximumReps, in: exercise.minimumReps...100)
                                HStack {
                                    Text("Target kg")
                                    Spacer()
                                    TextField(
                                        "Optional",
                                        value: Binding(
                                            get: { exercise.targetWeightKg ?? 0 },
                                            set: { exercise.targetWeightKg = max(0, $0) }
                                        ),
                                        format: .number
                                    )
                                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                }
                                Button("Remove Exercise", role: .destructive) {
                                    exercises.removeAll { $0.id == exercise.id }
                                }
                                .font(.caption.weight(.semibold))
                            }
                            .padding(.vertical, 5)
                        }
                        Button { exercises.append(StrengthExercisePrescription(name: "")) } label: {
                            Label("Add Exercise", systemImage: "plus")
                        }
                    }
                }
            }
            .navigationTitle("Edit Plan Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { if isDirty { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var edited = original
                        edited.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        edited.weekday = weekday
                        edited.kind = kind
                        edited.plannedAerobicMinutes = aerobicMinutes
                        let savedExercises = kind == .strength ? exercises.filter {
                            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        } : []
                        edited.plannedStrengthSession = !savedExercises.isEmpty
                        edited.strengthExercises = savedExercises
                        if feedback.save(store, message: "Plan Saved", change: {
                            store.saveExercisePlanDay(edited)
                        }) { dismiss() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .bullFormSurface()
        .bullDraftGuard(isDirty: isDirty, confirming: $confirmingDiscard) { dismiss() }
    }
}

private struct EditableStrengthSet: Identifiable, Equatable {
    var id = UUID().uuidString
    var exerciseID: String
    var exerciseName: String
    var setNumber: Int
    var weightKg: Double
    var reps: Int
    var completed: Bool
    var targetWeightKg: Double?
    var minimumReps: Int?
    var maximumReps: Int?
    var isPlanned: Bool
}

struct StrengthWorkoutEntryView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var sets: [EditableStrengthSet] = []
    @State private var loaded = false
    @State private var savedSets: [EditableStrengthSet] = []
    @State private var confirmingDiscard = false
    private var isDirty: Bool { loaded && sets != savedSets }

    private var plannedSets: [EditableStrengthSet] { sets.filter(\.isPlanned) }
    private var completedPlannedSets: Int { plannedSets.filter(\.completed).count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(
                        "Scheduled Sets Completed",
                        value: "\(completedPlannedSets) of \(plannedSets.count)"
                    )
                    if !plannedSets.isEmpty {
                        Button(completedPlannedSets == plannedSets.count
                               ? "Clear Planned Sets"
                               : "Complete All Planned Sets") {
                            let markCompleted = completedPlannedSets != plannedSets.count
                            for index in sets.indices where sets[index].isPlanned {
                                sets[index].completed = markCompleted
                            }
                        }
                        .accessibilityHint("Does not change weights, repetitions, or extra sets")
                    }
                }
                Section("Strength Workout") {
                    if sets.isEmpty {
                        Text("Add structured strength exercises in Edit Plan Day first.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach($sets) { $set in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Button {
                                    set.completed.toggle()
                                } label: {
                                    Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(set.completed ? BullTheme.green : BullTheme.muted)
                                }
                                .buttonStyle(.plain)
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityLabel("\(set.exerciseName), Set \(set.setNumber)")
                                .accessibilityValue(set.completed ? "Completed" : "Not Completed")
                                VStack(alignment: .leading, spacing: 2) {
                                    if set.isPlanned {
                                        Text("\(set.exerciseName) · Set \(set.setNumber)")
                                            .font(.subheadline.weight(.semibold))
                                    } else {
                                        TextField("Extra Exercise", text: $set.exerciseName)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    Text(suggestion(for: set))
                                        .font(.caption).foregroundStyle(BullTheme.secondary)
                                }
                                Spacer()
                            }
                            HStack {
                                Text("Actual")
                                    .font(.caption.weight(.semibold)).foregroundStyle(BullTheme.secondary)
                                Spacer()
                                TextField("kg", value: $set.weightKg, format: .number)
                                    .keyboardType(.decimalPad).frame(width: 70).multilineTextAlignment(.trailing)
                                Text("kg").font(.caption).foregroundStyle(.secondary)
                                Stepper("\(set.reps) Reps", value: $set.reps, in: 0...100)
                            }
                            if !set.isPlanned {
                                Button("Remove Extra Set", role: .destructive) {
                                    sets.removeAll { $0.id == set.id }
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Button {
                        sets.append(EditableStrengthSet(
                            exerciseID: UUID().uuidString,
                            exerciseName: "",
                            setNumber: (sets.map(\.setNumber).max() ?? 0) + 1,
                            weightKg: 0,
                            reps: 0,
                            completed: false,
                            targetWeightKg: nil,
                            minimumReps: nil,
                            maximumReps: nil,
                            isPlanned: false
                        ))
                    } label: { Label("Add Extra Set", systemImage: "plus") }
                }
            }
            .navigationTitle("Log Strength Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { if isDirty { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if feedback.save(store, message: "Workout Saved", change: {
                          store.saveStrengthWorkout(
                            on: date,
                            sets: sets.map { value in
                                StrengthSetLog(
                                    exerciseID: value.exerciseID,
                                    exerciseName: value.exerciseName,
                                    setNumber: value.setNumber,
                                    weightKg: value.weightKg,
                                    reps: value.reps,
                                    completed: value.completed
                                )
                            }
                          )
                        }) { dismiss() }
                    }
                }
            }
        }
        .bullFormSurface()
        .bullDraftGuard(isDirty: isDirty, confirming: $confirmingDiscard) { dismiss() }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let existingSets = store.strengthWorkoutLog(on: date)?.sets ?? []
        let existingByToken = existingSets.reduce(into: [String: StrengthSetLog]()) { result, set in
            result["\(set.exerciseID)#\(set.setNumber)"] = set
        }
        var plannedTokens = Set<String>()
        var loadedSets: [EditableStrengthSet] = []
        for exercise in store.planDay(on: date)?.strengthExercises ?? [] {
            for number in 1...exercise.targetSets {
                let token = "\(exercise.id)#\(number)"
                plannedTokens.insert(token)
                let existing = existingByToken[token]
                loadedSets.append(EditableStrengthSet(
                    id: existing?.id ?? UUID().uuidString,
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    setNumber: number,
                    weightKg: existing?.weightKg ?? exercise.targetWeightKg ?? 0,
                    reps: existing?.reps ?? 0,
                    completed: existing?.completed ?? false,
                    targetWeightKg: exercise.targetWeightKg,
                    minimumReps: exercise.minimumReps,
                    maximumReps: exercise.maximumReps,
                    isPlanned: true
                ))
            }
        }
        loadedSets.append(contentsOf: existingSets.compactMap { existing in
            let token = "\(existing.exerciseID)#\(existing.setNumber)"
            guard !plannedTokens.contains(token) else { return nil }
            return EditableStrengthSet(
                id: existing.id,
                exerciseID: existing.exerciseID,
                exerciseName: existing.exerciseName,
                setNumber: existing.setNumber,
                weightKg: existing.weightKg,
                reps: existing.reps,
                completed: existing.completed,
                targetWeightKg: nil,
                minimumReps: nil,
                maximumReps: nil,
                isPlanned: false
            )
        })
        sets = loadedSets
        savedSets = sets
    }

    private func suggestion(for set: EditableStrengthSet) -> String {
        guard set.isPlanned else { return "Extra Set · Tracked in Stats" }
        let weight = set.targetWeightKg.map { "\($0.formatted()) kg" } ?? "Target Weight Not Set"
        let reps: String
        if let minimum = set.minimumReps, let maximum = set.maximumReps {
            reps = minimum == maximum ? "\(minimum) Reps" : "\(minimum)–\(maximum) Reps"
        } else {
            reps = "Reps Not Set"
        }
        return "Suggested: \(weight) · \(reps)"
    }
}

struct ManualExerciseEntryView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var useCardioCorrection = false
    @State private var aerobicMinutes = 0.0
    @State private var vigorousMinutes = 0.0
    @State private var notes = ""
    @State private var loaded = false
    @State private var savedDraft: Draft?
    @State private var confirmingDiscard = false
    private struct Draft: Equatable {
        let correction: Bool
        let aerobic: Double
        let vigorous: Double
        let notes: String
    }
    private var draft: Draft { Draft(correction: useCardioCorrection, aerobic: aerobicMinutes, vigorous: vigorousMinutes, notes: notes) }
    private var isDirty: Bool { savedDraft.map { $0 != draft } ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cardio") {
                    Toggle("Correct Apple Health Minutes", isOn: $useCardioCorrection)
                    if useCardioCorrection {
                        Stepper("Total Aerobic: \(Int(aerobicMinutes)) Min", value: $aerobicMinutes, in: 0...300, step: 5)
                        Stepper("Of Which Vigorous: \(Int(vigorousMinutes)) Min", value: $vigorousMinutes, in: 0...300, step: 5)
                        Text("Your correction replaces the imported minutes.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        let imported = store.day(for: date)
                        LabeledContent("Apple Health Aerobic", value: imported.aerobicMinutes.map { "\(Int($0.rounded())) Min" } ?? "Not Recorded")
                        LabeledContent("Vigorous Minutes", value: imported.vigorousMinutes.map { "\(Int($0.rounded())) Min" } ?? "Not Recorded")
                    }
                    let imported = store.day(for: date)
                    LabeledContent("Active Energy", value: imported.cardioActiveCalories.map { "\(Int($0.rounded())) kcal" } ?? "—")
                    LabeledContent("Intensity Source", value: intensitySourceLabel(imported.cardioIntensitySource))
                    Text("Active energy is shown for reference.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Optional Note") { TextField("Context", text: $notes, axis: .vertical) }
            }
            .navigationTitle("Cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { if isDirty { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if feedback.save(store, message: "Cardio Saved", change: {
                          store.saveManualExercise(
                            on: date,
                            aerobicMinutesOverride: useCardioCorrection ? aerobicMinutes : nil,
                            vigorousMinutesOverride: useCardioCorrection ? min(aerobicMinutes, vigorousMinutes) : nil,
                            strengthSessionCompleted: store.manualExerciseLog(on: date)?.strengthSessionCompleted,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                          )
                        }) { dismiss() }
                    }
                }
            }
        }
        .bullFormSurface()
        .bullDraftGuard(isDirty: isDirty, confirming: $confirmingDiscard) { dismiss() }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let imported = store.day(for: date)
        aerobicMinutes = min(300, max(0, imported.aerobicMinutes ?? 0))
        vigorousMinutes = min(aerobicMinutes, max(0, imported.vigorousMinutes ?? 0))
        let log = store.manualExerciseLog(on: date)
        if let log, log.aerobicMinutesOverride != nil || log.vigorousMinutesOverride != nil {
            useCardioCorrection = true
            aerobicMinutes = log.aerobicMinutesOverride ?? 0
            vigorousMinutes = min(aerobicMinutes, log.vigorousMinutesOverride ?? 0)
        }
        notes = log?.notes ?? ""
        savedDraft = draft
    }

    private func intensitySourceLabel(_ source: String?) -> String {
        switch source {
        case "heart-rate-zones": return "Heart-Rate Zones"
        case "heart-rate-zones-and-workout-estimate": return "Mixed"
        case "workout-type-estimate": return "Workout Estimate"
        default: return "—"
        }
    }
}
