import SwiftUI

struct SexualCheckInView: View {
    private enum EntryMode: String, CaseIterable, Identifiable {
        case morning = "Morning Erection"
        case desire = "Natural Desire"
        case combinedLegacy = "Combined Entry"
        var id: String { rawValue }
    }

    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    var date: Date? = nil
    var initialKind: BullStateObservationKind? = nil
    var editLatest = false
    @State private var capturedDate: Date?
    @State private var editingID: String?
    @State private var mode: EntryMode = .morning
    @State private var wakeLabel = "Dawn"
    @State private var erection: MorningErectionObservation = .notObserved
    @State private var hardness = 3
    @State private var desire = 5
    @State private var timerStartedAt: Date?
    @State private var observedDurationSeconds: Double?
    @State private var manualDurationMinutes = 0
    @State private var showEjaculatoryControl = false
    @State private var loaded = false
    @State private var confirmingDiscard = false
    @State private var pendingEdit: BullStateObservation?
    @State private var savedDraft: Draft?

    private struct Draft: Equatable {
        let mode: EntryMode
        let wake: String
        let erection: MorningErectionObservation
        let hardness: Int
        let desire: Int
        let started: Date?
        let duration: Double?
        let minutes: Int
    }
    private var entryDate: Date { capturedDate ?? date ?? store.selectedDate }
    private var draft: Draft {
        Draft(mode: mode, wake: wakeLabel, erection: erection, hardness: hardness, desire: desire,
              started: timerStartedAt, duration: observedDurationSeconds, minutes: manualDurationMinutes)
    }
    private var isDirty: Bool { savedDraft.map { $0 != draft } ?? false }

    private var observations: [BullStateObservation] {
        store.bullStateObservations(on: entryDate)
    }
    private var legacyWakes: [WakeErectionObservation] {
        store.data.wakeErectionObservations.filter { $0.dayKey == BullDates.key(for: entryDate) }
    }

    var body: some View {
        NavigationStack {
            Form {
                if initialKind == nil {
                    Section("Today's Bull State") {
                        stateEntryRow(
                            title: "Morning Erection",
                            recorded: observations.contains { $0.kind != .naturalDesire },
                            target: .morning
                        )
                        stateEntryRow(
                            title: "Natural Desire",
                            recorded: observations.contains { $0.healthyDesire != nil },
                            target: .desire
                        )
                    }
                }
                Section {
                    if mode != .combinedLegacy {
                        Picker("Entry", selection: $mode) {
                            Text("Morning").tag(EntryMode.morning)
                            Text("Desire").tag(EntryMode.desire)
                        }
                        .pickerStyle(.segmented)
                    }
                    if mode == .morning || mode == .combinedLegacy { morningEditor }
                    if mode == .desire || mode == .combinedLegacy { desireEditor }
                    Button(editingID == nil ? "Save Entry" : "Save Changes", action: save)
                        .font(.headline).frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .tint(BullTheme.gold)
                        .foregroundStyle(BullTheme.ink)
                }

                Section("Bull State Log · \(selectedDateLabel)") {
                    if observations.isEmpty {
                        Text("No Bull State Entries Yet").foregroundStyle(.secondary)
                    }
                    ForEach(observations) { observation in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(observation.date.formatted(date: .omitted, time: .shortened)) · \(entryTitle(observation))")
                                    .font(.subheadline.weight(.semibold))
                                Text(observationSummary(observation))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                if isDirty { pendingEdit = observation; confirmingDiscard = true }
                                else { edit(observation) }
                            } label: { Image(systemName: "pencil") }
                                .buttonStyle(.borderless)
                            .accessibilityLabel("Edit Bull State Entry")
                            Button(role: .destructive) {
                                if feedback.save(store, message: "Entry Deleted", change: {
                                    store.deleteBullStateObservation(id: observation.id)
                                }), editingID == observation.id { resetEditor() }
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete Bull State Entry")
                        }
                    }
                }

                if !legacyWakes.isEmpty {
                    Section("Earlier Wake Records") {
                        ForEach(legacyWakes) { wake in
                            LabeledContent(displayWake(wake.wakeLabel), value: legacyWakeSummary(wake))
                        }
                        Text("Kept for reference. These older entries don't change Bull State.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Other Observations") {
                    Button { showEjaculatoryControl = true } label: {
                        HStack { Text("Ejaculatory Control"); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                    }
                    Text("Tracked in Stats. Your score stays unchanged.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(mode.rawValue)
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
        .sheet(isPresented: $showEjaculatoryControl) {
            EjaculatoryControlView(date: entryDate)
        }
        .onAppear(perform: loadDefaultWake)
    }

    @ViewBuilder
    private var morningEditor: some View {
        Picker("Wake", selection: $wakeLabel) {
            Text("Dawn").tag("Dawn")
            Text("Final Wake").tag("Final Wake")
            Text("Other Wake").tag("Other Wake")
        }
        Picker("Erection", selection: Binding(get: { erection }, set: { value in
            erection = value
            if value != .yes {
                timerStartedAt = nil
                observedDurationSeconds = nil
                manualDurationMinutes = 0
            }
        })) {
            Text("Not Observed").tag(MorningErectionObservation.notObserved)
            Text("No").tag(MorningErectionObservation.no)
            Text("Yes").tag(MorningErectionObservation.yes)
        }
        .pickerStyle(.segmented)
        if erection == .yes {
            Picker("Erection Hardness", selection: $hardness) {
                Text("1 · Larger, Not Hard").tag(1)
                Text("2 · Hard, Not Enough for Penetration").tag(2)
                Text("3 · Hard Enough, Not Fully Rigid").tag(3)
                Text("4 · Fully Hard and Rigid").tag(4)
            }
            durationEditor
        }
    }

    @ViewBuilder
    private var desireEditor: some View {
        Picker("Natural Desire Today", selection: $desire) {
            Text("None").tag(0)
            Text("Low").tag(3)
            Text("Moderate").tag(5)
            Text("High").tag(8)
            Text("Very High").tag(10)
        }
        Text("Later in the day: rate your natural sexual interest, separate from porn-driven urges.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var durationEditor: some View {
        if let started = timerStartedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                LabeledContent("Observed Duration", value: durationText(context.date.timeIntervalSince(started)))
                    .monospacedDigit()
            }
            Button("Erection Ended") {
                observedDurationSeconds = max(0, Date().timeIntervalSince(started))
                manualDurationMinutes = Int(((observedDurationSeconds ?? 0) / 60).rounded())
                timerStartedAt = nil
            }
        } else {
            Button(observedDurationSeconds == nil ? "Start Duration Timer" : "Restart Duration Timer") {
                observedDurationSeconds = nil
                manualDurationMinutes = 0
                timerStartedAt = Date()
            }
            .disabled(!BullDates.sameDay(entryDate, Date()))
            Stepper("Observed Duration: \(manualDurationMinutes) Min", value: Binding(
                get: { manualDurationMinutes }, set: { value in
                    manualDurationMinutes = value
                    observedDurationSeconds = value == 0 ? nil : Double(value * 60)
                }
            ), in: 0...240)
        }
        Text("Optional. Duration doesn't change your score.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func save() {
        let existingIDs = Set(observations.map(\.id))
        let duration = timerStartedAt.map { max(0, Date().timeIntervalSince($0)) }
            ?? observedDurationSeconds
        let saved = feedback.save(store, message: "Bull State Saved") {
          store.saveBullStateObservation(
            id: editingID,
            wakeLabel: mode == .desire ? "Later Today" : wakeLabel,
            erection: mode == .desire ? .notObserved : erection,
            erectionHardnessScore: mode != .desire && erection == .yes ? hardness : nil,
            healthyDesire: mode == .morning ? nil : desire,
            erectionDurationSeconds: mode != .desire && erection == .yes ? duration : nil,
            kind: mode == .combinedLegacy ? nil : (mode == .morning ? .morningErection : .naturalDesire),
            on: entryDate
          )
        }
        if saved {
            if initialKind == nil, !editLatest, mode == .morning {
                editingID = nil
                mode = .desire
                erection = .notObserved
                hardness = 3
                desire = 5
                timerStartedAt = nil
                observedDurationSeconds = nil
                manualDurationMinutes = 0
                savedDraft = draft
                feedback.show("Morning Erection Saved · Natural Desire Stays Available")
            } else {
                dismiss()
            }
        }
        else if editingID == nil { editingID = observations.first { !existingIDs.contains($0.id) }?.id }
    }

    private func stateEntryRow(title: String, recorded: Bool, target: EntryMode) -> some View {
        Button {
            editingID = nil
            mode = target
            savedDraft = draft
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(BullTheme.ink)
                    Text(recorded ? "Recorded · Tap to Add or Edit" : "Not Recorded")
                        .font(.caption).foregroundStyle(BullTheme.secondary)
                }
                Spacer()
                Image(systemName: recorded ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(recorded ? BullTheme.green : BullTheme.muted)
            }
            .frame(minHeight: BullTheme.controlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadDefaultWake() {
        guard !loaded else { return }
        capturedDate = entryDate
        loaded = true
        if let initialKind { mode = initialKind == .naturalDesire ? .desire : .morning }
        else {
            mode = observations.contains(where: { $0.kind != .naturalDesire && $0.erection != .notObserved })
                ? .desire : .morning
        }
        wakeLabel = observations.contains(where: { displayWake($0.wakeLabel) == "Dawn" })
            ? "Final Wake" : "Dawn"
        if editLatest, let latest = observations.filter({ observation in
            if initialKind == .naturalDesire { return observation.healthyDesire != nil }
            if initialKind == .morningErection { return observation.kind != .naturalDesire }
            return true
        }).max(by: { $0.ts < $1.ts }) { edit(latest) }
        savedDraft = draft
    }

    private func edit(_ observation: BullStateObservation) {
        editingID = observation.id
        switch observation.kind {
        case .morningErection: mode = .morning
        case .naturalDesire: mode = .desire
        case nil: mode = .combinedLegacy
        }
        wakeLabel = displayWake(observation.wakeLabel)
        erection = observation.erection
        hardness = observation.erectionHardnessScore ?? 3
        desire = observation.healthyDesire ?? 5
        observedDurationSeconds = observation.erectionDurationSeconds
        manualDurationMinutes = Int(((observation.erectionDurationSeconds ?? 0) / 60).rounded())
        timerStartedAt = nil
        savedDraft = draft
    }

    private func resetEditor() {
        editingID = nil
        mode = observations.contains(where: { $0.kind != .naturalDesire && $0.erection != .notObserved })
            ? .desire : .morning
        erection = .notObserved
        hardness = 3
        desire = 5
        timerStartedAt = nil
        observedDurationSeconds = nil
        manualDurationMinutes = 0
        wakeLabel = observations.contains(where: { displayWake($0.wakeLabel) == "Dawn" })
            ? "Final Wake" : "Dawn"
        savedDraft = draft
    }

    private func observationSummary(_ observation: BullStateObservation) -> String {
        let erectionText: String = switch observation.erection {
        case .yes:
            observation.erectionHardnessScore.map { "Yes · EHS \($0)" } ?? "Yes"
        case .no: "No"
        case .notObserved: "Not Observed"
        }
        var parts = [String]()
        if observation.kind != .naturalDesire { parts.append(erectionText) }
        if let duration = observation.erectionDurationSeconds { parts.append(durationText(duration)) }
        if let desire = observation.healthyDesire { parts.append("Natural Desire \(desire)/10") }
        return parts.joined(separator: " · ")
    }

    private func entryTitle(_ observation: BullStateObservation) -> String {
        switch observation.kind {
        case .morningErection: return displayWake(observation.wakeLabel)
        case .naturalDesire: return "Natural Desire"
        case nil: return displayWake(observation.wakeLabel)
        }
    }

    private func durationText(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return total >= 60 ? "\(total / 60)m \(total % 60)s" : "\(total)s"
    }

    private func legacyWakeSummary(_ wake: WakeErectionObservation) -> String {
        switch wake.erection {
        case .yes: return wake.erectionHardnessScore.map { "Yes · EHS \($0)" } ?? "Yes"
        case .no: return "No"
        case .notObserved: return "Not Observed"
        }
    }

    private func displayWake(_ label: String) -> String {
        switch label.lowercased() {
        case "fajr", "fajr wake", "dawn wake", "dawn": return "Dawn"
        case "final wake": return "Final Wake"
        case "other wake": return "Other Wake"
        default: return label
        }
    }

    private var selectedDateLabel: String {
        BullDates.sameDay(entryDate, Date()) ? "Today" : entryDate.formatted(.dateTime.day().month(.abbreviated))
    }

}

struct EjaculatoryControlView: View {
    @EnvironmentObject private var store: BullStore
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var editingID: String?
    @State private var perceivedControl = 5
    @State private var soonerThanDesired = false
    @State private var bother = 0
    @State private var note = ""

    private var observations: [EjaculatoryControlObservation] {
        store.ejaculatoryControlObservations(on: date)
    }

    private var dateLabel: String {
        BullDates.sameDay(date, Date())
            ? "Today"
            : date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Relevant Event · \(dateLabel)") {
                    scoreRow("Perceived Control", value: $perceivedControl)
                    Toggle("Sooner Than I Wanted", isOn: $soonerThanDesired)
                    scoreRow("Distress", value: $bother)
                    TextField("Optional Note", text: $note, axis: .vertical)
                }
                Section {
                    Text("Use your perception. This is for trends only, not a diagnosis or daily score.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Saved Entries · \(dateLabel)") {
                    if observations.isEmpty {
                        Text("No Ejaculatory Control Entries Yet").foregroundStyle(.secondary)
                    }
                    ForEach(observations) { observation in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Control \(observation.perceivedControl)/10 · Distress \(observation.bother)/10")
                                    .font(.subheadline.weight(.semibold))
                                Text(observation.soonerThanDesired ? "Sooner than desired" : "Not sooner than desired")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let note = observation.note, !note.isEmpty {
                                    Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                if observation.source != .live || observation.modifiedTs != nil {
                                    Text(observation.modifiedTs == nil ? "Retrospective" : "Corrected")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(BullTheme.goldDark)
                                }
                            }
                            Spacer()
                            Button { edit(observation) } label: { Image(systemName: "pencil") }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Edit ejaculatory control entry")
                            Button(role: .destructive) {
                                store.deleteEjaculatoryControlObservation(id: observation.id)
                                if editingID == observation.id { resetEditor() }
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete ejaculatory control entry")
                        }
                    }
                }
            }
            .navigationTitle("Ejaculatory Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(editingID == nil ? "Save" : "Save Changes") {
                        store.saveEjaculatoryControl(
                            id: editingID,
                            perceivedControl: perceivedControl,
                            soonerThanDesired: soonerThanDesired,
                            bother: bother,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
                            on: date
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private func edit(_ observation: EjaculatoryControlObservation) {
        editingID = observation.id
        perceivedControl = observation.perceivedControl
        soonerThanDesired = observation.soonerThanDesired
        bother = observation.bother
        note = observation.note ?? ""
    }

    private func resetEditor() {
        editingID = nil
        perceivedControl = 5
        soonerThanDesired = false
        bother = 0
        note = ""
    }

    private func scoreRow(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text("\(value.wrappedValue)/10").monospacedDigit() }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0.rounded()) }
                ),
                in: 0...10,
                step: 1
            )
            .tint(BullTheme.gold)
        }
    }
}
