import SwiftUI

struct StressCheckInView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    var date: Date? = nil
    @State private var capturedDate: Date?
    @State private var morning = 5
    @State private var evening = 5
    @State private var loaded = false
    @State private var savedMorning = 5
    @State private var savedEvening = 5
    @State private var confirmingDiscard = false

    private var entryDate: Date { capturedDate ?? date ?? store.selectedDate }
    private var isDirty: Bool { morning != savedMorning || evening != savedEvening }

    private var morningReading: StressReading? { store.stressCheckIn(.morning, on: entryDate) }
    private var eveningReading: StressReading? { store.stressCheckIn(.evening, on: entryDate) }
    private var regulation: StressRegulationState { store.stressRegulationState(on: entryDate) }
    private var dateLabel: String {
        BullDates.sameDay(entryDate, Date())
            ? "Today"
            : entryDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(dateLabel).font(.subheadline.weight(.semibold)) }
                Section("Morning Stress") {
                    HStack { Text("After Final Wake"); Spacer(); Text("\(morning)/10").monospacedDigit() }
                    Slider(value: intBinding($morning), in: 0...10, step: 1).tint(BullTheme.gold)
                    Text("After your final wake.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let reading = morningReading {
                        Text("Saved \(reading.date.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Not Recorded").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button(morningReading == nil ? "Save Morning" : "Update Morning") {
                            if feedback.save(store, message: "Morning Stress Saved", change: {
                                store.saveStressCheckIn(morning, context: .morning, on: entryDate)
                            }) { savedMorning = morning }
                        }
                        Spacer()
                        if morningReading != nil {
                            Button("Clear", role: .destructive) {
                                feedback.save(store, message: "Morning Stress Cleared") {
                                    store.deleteStressCheckIn(.morning, on: entryDate)
                                }
                            }
                        }
                    }
                }

                Section("Evening Stress") {
                    HStack { Text("Before Bed"); Spacer(); Text("\(evening)/10").monospacedDigit() }
                    Slider(value: intBinding($evening), in: 0...10, step: 1).tint(BullTheme.gold)
                    Text("Your last stress check-in of the day.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let reading = eveningReading {
                        Text("Saved \(reading.date.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Not Recorded").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button(eveningReading == nil ? "Save Evening" : "Update Evening") {
                            if feedback.save(store, message: "Evening Stress Saved", change: {
                                store.saveStressCheckIn(evening, context: .evening, on: entryDate)
                            }) { savedEvening = evening }
                        }
                        Spacer()
                        if eveningReading != nil {
                            Button("Clear", role: .destructive) {
                                feedback.save(store, message: "Evening Stress Cleared") {
                                    store.deleteStressCheckIn(.evening, on: entryDate)
                                }
                            }
                        }
                    }
                }

                Section("Stress Regulation") {
                    LabeledContent(
                        regulation.isFinal ? "Recorded" : "Awaiting Evening Check-In",
                        value: regulation.score.map { "\(Int($0.rounded())) / 100" } ?? "—"
                    )
                    Text("Tracks how stress changes from morning to evening.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Stress Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { if isDirty { confirmingDiscard = true } else { dismiss() } }
                }
            }
        }
        .bullFormSurface()
        .bullDraftGuard(isDirty: isDirty, confirming: $confirmingDiscard) { dismiss() }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        capturedDate = entryDate
        loaded = true
        morning = morningReading?.value ?? 5
        evening = eveningReading?.value ?? morningReading?.value ?? 5
        savedMorning = morning
        savedEvening = evening
    }
}

struct StressReliefEntryView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var activityID = ""
    @State private var before = 6
    @State private var after = 4
    @State private var finishingID: String?
    @State private var estimatedAfterwards = false
    @State private var duration = 15
    @State private var logMindfulnessScore = false
    @State private var mindfulnessScore = 50.0
    @State private var savedDraft: Draft?
    @State private var confirmingDiscard = false
    @State private var pendingSave = false

    private struct Draft: Equatable {
        let activity: String
        let before: Int
        let after: Int
        let finishing: String?
        let estimated: Bool
        let duration: Int
        let mindfulness: Bool
        let score: Double
    }
    private var draft: Draft {
        Draft(activity: activityID, before: before, after: after, finishing: finishingID,
              estimated: estimatedAfterwards, duration: duration, mindfulness: logMindfulnessScore, score: mindfulnessScore)
    }
    private var isDirty: Bool { savedDraft.map { $0 != draft } ?? false }

    init(date: Date = Date()) {
        self.date = date
        _estimatedAfterwards = State(initialValue: !BullDates.sameDay(date, Date()))
    }

    private var isToday: Bool { BullDates.sameDay(date, Date()) }
    private var dateLabel: String {
        isToday ? "Today" : date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private var activities: [StressActivityDefinition] {
        store.data.stressActivities.filter { $0.enabled && !$0.archived }
    }
    private var selectedActivity: StressActivityDefinition? {
        activities.first { $0.id == activityID }
    }
    private var finishingLog: StressReliefLog? {
        store.pendingStressReliefLogs.first { $0.id == finishingID }
    }
    private var finishingActivity: StressActivityDefinition? {
        finishingLog.flatMap { log in store.data.stressActivities.first { $0.id == log.activityID } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(dateLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BullTheme.goldDark)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isToday && !store.pendingStressReliefLogs.isEmpty {
                        BullCard {
                            Text("Pending Activities").font(.headline)
                            ForEach(store.pendingStressReliefLogs) { log in
                                if log.id != store.pendingStressReliefLogs.first?.id { Divider() }
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(activityName(log.activityID)).font(.subheadline.weight(.semibold))
                                        Text("Started \(Date(timeIntervalSince1970: (log.startedTs ?? log.ts) / 1_000).formatted(date: .omitted, time: .shortened)) · Stress \(beforeValue(log) ?? 0)/10")
                                            .font(.caption).foregroundStyle(BullTheme.secondary)
                                    }
                                    Spacer()
                                    Button("Finish") { finishingID = log.id }
                                        .font(.caption.weight(.bold))
                                }
                                if finishingID == log.id {
                                    Divider()
                                    ratingRow("Stress After", help: "How stressed do you feel now?", value: $after)
                                    if finishingActivity?.kind == .mindfulness {
                                        mindfulnessInput
                                    }
                                    HStack {
                                        Button("Complete Activity") {
                                            save("Activity Completed") {
                                              store.completeStressRelief(
                                                logID: log.id,
                                                stressAfter: after,
                                                mindfulnessScore: finishingActivity?.kind == .mindfulness && logMindfulnessScore
                                                    ? mindfulnessScore : nil
                                              )
                                            }
                                        }
                                        .buttonStyle(.borderedProminent).tint(BullTheme.gold)
                                        Spacer()
                                        Button("Discard", role: .destructive) {
                                            save("Activity Discarded") { store.cancelPendingStressRelief(logID: log.id) }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    BullCard {
                        Text(estimatedAfterwards ? "Estimated Afterwards" : "Start an Activity")
                            .font(.headline)
                        Picker("Activity", selection: $activityID) {
                            ForEach(activities) { Text($0.name).tag($0.id) }
                        }
                        .pickerStyle(.menu)
                        .tint(BullTheme.goldDark)
                        Divider()
                        ratingRow(
                            "Stress Before",
                            help: estimatedAfterwards
                                ? "Your best rough estimate from before the activity."
                                : "Log this now, before you begin.",
                            value: $before
                        )
                        if estimatedAfterwards {
                            Divider()
                            ratingRow("Stress After", help: "Your best rough estimate after the activity.", value: $after)
                            Stepper("Duration: \(duration) Minutes", value: $duration, in: 1...300, step: 5)
                            if selectedActivity?.kind == .mindfulness { mindfulnessInput }
                            Button("Save Estimated Activity") {
                                save("Activity Saved") {
                                  store.logStressRelief(
                                    activityID: activityID,
                                    durationMinutes: duration,
                                    stressBefore: before,
                                    stressAfter: after,
                                    mindfulnessScore: selectedActivity?.kind == .mindfulness && logMindfulnessScore
                                        ? mindfulnessScore : nil,
                                    on: date
                                  )
                                }
                            }
                            .buttonStyle(.borderedProminent).tint(BullTheme.gold)
                            .foregroundStyle(BullTheme.ink)
                            .frame(maxWidth: .infinity)
                            .disabled(activityID.isEmpty)
                        } else {
                            Button("Start Activity") {
                                save("Activity Started") {
                                  store.startStressRelief(
                                    activityID: activityID,
                                    stressBefore: before,
                                    on: date
                                  )
                                }
                            }
                            .buttonStyle(.borderedProminent).tint(BullTheme.gold)
                            .foregroundStyle(BullTheme.ink)
                            .frame(maxWidth: .infinity)
                            .disabled(activityID.isEmpty)
                            Text("Return here afterwards to finish your check-in.")
                                .font(.caption).foregroundStyle(BullTheme.secondary)
                        }
                    }

                    if isToday {
                        Toggle("Estimated Afterwards", isOn: $estimatedAfterwards)
                            .font(.subheadline.weight(.semibold))
                            .tint(BullTheme.gold)
                    }
                    Text(isToday ? "Already finished? Turn on Estimated Afterwards." : "Saved as an estimate for this day.")
                        .font(.caption).foregroundStyle(BullTheme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .background(BullTheme.ivory.ignoresSafeArea())
            .navigationTitle("Log Stress Relief")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { if isDirty { confirmingDiscard = true } else { dismiss() } }
                }
            }
        }
        .bullFormSurface()
        .bullDraftGuard(isDirty: isDirty, confirming: $confirmingDiscard) { dismiss() }
        .bullPendingSave($pendingSave) { dismiss() }
        .interactiveDismissDisabled(isDirty || pendingSave)
        .onAppear {
            guard savedDraft == nil else { return }
            if activityID.isEmpty { activityID = activities.first?.id ?? "" }
            savedDraft = draft
        }
    }

    private func save(_ message: String, change: () -> Void) {
        if feedback.save(store, message: message, change: change) { dismiss() }
        else { pendingSave = true }
    }

    private var mindfulnessInput: some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle("Enter a Muse Score", isOn: $logMindfulnessScore).tint(BullTheme.gold)
            if logMindfulnessScore {
                HStack {
                    Text("Mindfulness Score")
                    Spacer()
                    Text("\(Int(mindfulnessScore.rounded())) / 100").monospacedDigit()
                }
                Slider(value: $mindfulnessScore, in: 0...100, step: 1).tint(BullTheme.gold)
            }
        }
    }

    private func activityName(_ id: String) -> String {
        store.data.stressActivities.first(where: { $0.id == id })?.name ?? "Archived Activity"
    }

    private func beforeValue(_ log: StressReliefLog) -> Int? {
        log.beforeReadingID.flatMap { id in store.data.stressReadings.first { $0.id == id }?.value }
    }

    private func ratingRow(_ title: String, help: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value.wrappedValue)/10").monospacedDigit().font(.headline)
            }
            Text(help).font(.caption).foregroundStyle(BullTheme.secondary)
            Slider(value: intBinding(value), in: 0...10, step: 1).tint(BullTheme.gold)
        }
    }
}

struct UrgeStateEntryView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    var date: Date? = nil
    var editLatest = false
    @State private var intensity = 0
    @State private var editingID: String?
    @State private var capturedDate: Date?
    @State private var loaded = false
    @State private var savedIntensity = 0
    @State private var confirmingDiscard = false
    @State private var pendingEdit: PornUrgeObservation?

    private var entryDate: Date { capturedDate ?? date ?? store.selectedDate }
    private var isDirty: Bool { intensity != savedIntensity }

    private var observations: [PornUrgeObservation] {
        store.pornUrgeObservations(on: entryDate)
    }

    private var dateLabel: String {
        BullDates.sameDay(entryDate, Date())
            ? "Today"
            : entryDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Urge Check-In · \(dateLabel)") {
                    HStack { Text("Perceived Urge"); Spacer(); Text("\(intensity)/10").monospacedDigit() }
                    Slider(value: intBinding($intensity), in: 0...10, step: 1).tint(BullTheme.crimson)
                    Text("0 means no urge. Leave unrecorded if you haven't checked in.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(editingID == nil ? "Save Urge" : "Save Changes") {
                        let existingIDs = Set(observations.map(\.id))
                        if feedback.save(store, message: "Urge Saved", change: {
                            if let editingID {
                                store.updatePornUrgeObservation(id: editingID, intensity: intensity)
                            } else {
                                store.logUrgeState(intensity, on: entryDate)
                            }
                        }) {
                            dismiss()
                        } else if editingID == nil {
                            // A write failure can leave the new entry in memory. Retry
                            // that same entry, avoiding a duplicate observation.
                            editingID = observations.first { !existingIDs.contains($0.id) }?.id
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(BullTheme.crimson)
                }

                Section("Urge Log · \(dateLabel)") {
                    if observations.isEmpty {
                        Text("No Urge Entries Yet").foregroundStyle(.secondary)
                    }
                    ForEach(observations) { observation in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(observation.date.formatted(date: .omitted, time: .shortened))
                                    .font(.subheadline.weight(.semibold))
                                Text(observationContext(observation.context))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(observation.intensity)/10")
                                .font(.system(.headline, design: .monospaced))
                            Button {
                                if isDirty {
                                    pendingEdit = observation
                                    confirmingDiscard = true
                                } else { edit(observation) }
                            } label: { Image(systemName: "pencil") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Edit Urge Entry")
                            Button(role: .destructive) {
                                if feedback.save(store, message: "Entry Deleted", change: {
                                    store.deletePornUrgeObservation(id: observation.id)
                                }), editingID == observation.id {
                                    editingID = nil; intensity = 0; savedIntensity = 0
                                }
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete Urge Entry")
                        }
                    }
                }
            }
            .navigationTitle(editingID == nil ? "Log Urge" : "Edit Urge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        pendingEdit = nil
                        if isDirty { confirmingDiscard = true } else { dismiss() }
                    }
                }
            }
        }
        .bullFormSurface()
        .bullDraftGuard(isDirty: isDirty, confirming: $confirmingDiscard) {
            if let pendingEdit { edit(pendingEdit); self.pendingEdit = nil } else { dismiss() }
        }
        .onAppear {
            guard !loaded else { return }
            capturedDate = entryDate
            loaded = true
            if editLatest, let latest = observations.max(by: { $0.ts < $1.ts }) { edit(latest) }
        }
    }

    private func edit(_ observation: PornUrgeObservation) {
        editingID = observation.id
        intensity = observation.intensity
        savedIntensity = intensity
    }

    private func observationContext(_ context: PornUrgeObservationContext) -> String {
        switch context {
        case .urgeBefore: return "Before Sigh"
        case .urgeAfter: return "After Sigh"
        case .checkIn, .explicitNoUrge: return "Live Urge"
        }
    }
}

struct UrgeSupportView: View {
    @EnvironmentObject private var store: BullStore
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case rate, breathe, reflect }
    @State private var phase: Phase = .rate
    @State private var intensityBefore = 6
    @State private var logAfter = true
    @State private var intensityAfter = 3
    @State private var breathCount = 0
    @State private var urge: UrgeEvent?
    @State private var selectedTriggers = Set<String>()
    @State private var selectedResponses = Set<String>()
    @State private var addingTrigger = false
    @State private var addingResponse = false

    private var triggers: [TriggerDefinition] {
        store.data.triggerLibrary.filter { !$0.archived }
    }
    private var otherResponses: [ResponseDefinition] {
        store.data.responseLibrary.filter {
            !$0.archived && $0.id != "response.sigh"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .rate: rateView
                case .breathe: breatheView
                case .reflect: reflectView
                }
            }
            .padding()
            .navigationTitle("Urge Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
        }
        .interactiveDismissDisabled(phase == .breathe)
        .sheet(isPresented: $addingTrigger) {
            TriggerEditorView(title: "New Trigger", initialName: "") { name in
                if let created = store.addTrigger(named: name) {
                    selectedTriggers.insert(created.id)
                }
            }
        }
        .sheet(isPresented: $addingResponse) {
            ResponseEditorView(title: "New Response", response: ResponseDefinition(name: "")) { response in
                guard let created = store.addResponse(named: response.name) else { return }
                var configured = created
                configured.evidence = response.evidence
                store.updateResponse(configured)
                selectedResponses.insert(configured.id)
            }
        }
    }

    private var rateView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("How strong is the urge?")
                .font(.title2.weight(.bold))
            HStack { Text("Perceived urge"); Spacer(); Text("\(intensityBefore)/10").monospacedDigit() }
            Slider(value: intBinding($intensityBefore), in: 0...10, step: 1).tint(BullTheme.crimson)
            Button {
                urge = store.beginUrgeSupport(intensity: intensityBefore)
                phase = .breathe
            } label: {
                Label("Start Physiological Sigh", systemImage: "wind")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(BullTheme.gold).foregroundStyle(BullTheme.ink)
            Text("Triggers are collected afterwards. The first job is to ride out the wave.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var breatheView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "wind").font(.system(size: 54)).foregroundStyle(BullTheme.goldDark)
            Text("Double inhale. Long exhale.")
                .font(.title2.weight(.bold)).multilineTextAlignment(.center)
            Text("Inhale through your nose, take a short second inhale, then exhale slowly and fully. Repeat five times.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("\(breathCount) of 5")
                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
            ProgressView(value: Double(breathCount), total: 5).tint(BullTheme.gold)
            Button(breathCount < 4 ? "Breath Completed" : "Fifth Breath Completed") {
                breathCount += 1
                if breathCount >= 5 {
                    if let urge {
                        store.completeUrgeSupport(
                            urgeID: urge.id,
                            intensityAfter: nil,
                            triggerIDs: [],
                            additionalResponseIDs: []
                        )
                    }
                    phase = .reflect
                }
            }
            .buttonStyle(.borderedProminent).tint(BullTheme.gold).foregroundStyle(BullTheme.ink)
            Spacer()
        }
    }

    private var reflectView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("You completed the sigh.").font(.title2.weight(.bold))
                Toggle("Rate the Urge Now", isOn: $logAfter)
                if logAfter {
                    HStack { Text("Urge now"); Spacer(); Text("\(intensityAfter)/10").monospacedDigit() }
                    Slider(value: intBinding($intensityAfter), in: 0...10, step: 1).tint(BullTheme.crimson)
                }

                optionalChips(title: "Trigger · Optional, Data Only", values: triggers.map { ($0.id, $0.name) }, selection: $selectedTriggers)
                addLibraryButton("Add New Trigger") { addingTrigger = true }
                optionalChips(title: "What Else Did You Do? · Optional", values: otherResponses.map { ($0.id, $0.name) }, selection: $selectedResponses)
                addLibraryButton("Add New Response") { addingResponse = true }

                Button("Save and Close") {
                    if let urge {
                        store.completeUrgeSupport(
                            urgeID: urge.id,
                            intensityAfter: logAfter ? intensityAfter : nil,
                            triggerIDs: Array(selectedTriggers),
                            additionalResponseIDs: Array(selectedResponses)
                        )
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent).tint(BullTheme.gold).foregroundStyle(BullTheme.ink)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func optionalChips(
        title: String,
        values: [(String, String)],
        selection: Binding<Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            ForEach(values, id: \.0) { id, label in
                Button {
                    if selection.wrappedValue.contains(id) { selection.wrappedValue.remove(id) }
                    else { selection.wrappedValue.insert(id) }
                } label: {
                    HStack {
                        Image(systemName: selection.wrappedValue.contains(id) ? "checkmark.circle.fill" : "circle")
                        Text(label)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
            }
        }
    }

    private func addLibraryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(.bordered)
        .tint(BullTheme.goldDark)
    }
}

private func intBinding(_ value: Binding<Int>) -> Binding<Double> {
    Binding(
        get: { Double(value.wrappedValue) },
        set: { value.wrappedValue = Int($0.rounded()) }
    )
}
