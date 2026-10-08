import SwiftUI

struct PersonalExperimentManagerView: View {
    @EnvironmentObject private var store: BullStore
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var editing: PersonalFactor?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Active experiments", value: "\(active.count)/8")
                    Text("Personal experiments help you spot patterns but never change the four scores.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Active") {
                    if active.isEmpty { Text("No active personal experiments").foregroundStyle(.secondary) }
                    ForEach(active) { factor in factorRow(factor) }
                }
                Section("Archived History") {
                    if archived.isEmpty { Text("No archived experiments").foregroundStyle(.secondary) }
                    ForEach(archived) { factor in factorRow(factor) }
                }
                Section("Evidence Labels") {
                    ForEach(FactorEvidenceStatus.allCases, id: \.rawValue) { status in
                        Text(status.label).font(.caption)
                    }
                    Text("A label applies only to the stated outcome; it never validates a score weight.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Personal Experiments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .disabled(active.count >= 8)
                }
            }
        }
        .sheet(isPresented: $adding) {
            PersonalFactorEditor(factor: nil) { _ = store.addPersonalFactor($0) }
        }
        .sheet(item: $editing) { factor in
            PersonalFactorEditor(factor: factor) { store.updatePersonalFactor($0) }
        }
    }

    private var active: [PersonalFactor] { store.data.personalFactors.filter { !$0.archived } }
    private var archived: [PersonalFactor] { store.data.personalFactors.filter(\.archived) }

    private func factorRow(_ factor: PersonalFactor) -> some View {
        HStack(alignment: .top) {
            Button { editing = factor } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(factor.name).foregroundStyle(.primary)
                    Text(factor.evidenceStatus.label)
                        .font(.caption).foregroundStyle(.secondary)
                    Text(factor.hypothesis).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button(factor.archived ? "Restore" : "Archive") {
                store.setPersonalFactorArchived(id: factor.id, archived: !factor.archived)
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.borderless)
        }
    }
}

struct FactorEvidenceView: View {
    @EnvironmentObject private var store: BullStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Four Scores") {
                    evidenceRow("Urge Fuel", detail: "Sleep Protection 40 · Stress Regulation 35 · Environment Protection 25 · Fasting +10")
                    evidenceRow("Urge State", detail: "Latest timestamped Live Urge today · outcome only")
                    evidenceRow("Bull Fuel", detail: "Cardio 40 · Sleep 30 · Nutrition 20 · Strength 10")
                    evidenceRow("Bull State", detail: "Morning Erection 70 · Natural Desire 30 · outcome only")
                    Text("These are Bull's current score weights, not medical risk estimates.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Personal Experiments") {
                    if store.data.personalFactors.isEmpty {
                        Text("No personal experiments yet").foregroundStyle(.secondary)
                    }
                    ForEach(store.data.personalFactors) { factor in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(factor.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(factor.archived ? "Archived" : "Active")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(factor.archived ? BullTheme.muted : BullTheme.green)
                            }
                            Text(factor.evidenceStatus.label)
                                .font(.caption).foregroundStyle(.secondary)
                            Text("\(factor.intendedOutcome.label) · Personal experiment")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
                Section("Your History") {
                    Text("Older entries remain available in your backup and history.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Personal evidence labels apply only to the stated outcome. They do not prove causation or change a fixed score.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Factor Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func evidenceRow(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct PersonalFactorEditor: View {
    @Environment(\.dismiss) private var dismiss
    let original: PersonalFactor?
    let onSave: (PersonalFactor) -> Void
    @State private var name: String
    @State private var kind: PersonalFactorKind
    @State private var outcome: PersonalFactorOutcome
    @State private var hypothesis: String
    @State private var schedule: String
    @State private var evidence: FactorEvidenceStatus

    init(factor: PersonalFactor?, onSave: @escaping (PersonalFactor) -> Void) {
        original = factor
        self.onSave = onSave
        _name = State(initialValue: factor?.name ?? "")
        _kind = State(initialValue: factor?.kind ?? .action)
        _outcome = State(initialValue: factor?.intendedOutcome ?? .highUrge)
        _hypothesis = State(initialValue: factor?.hypothesis ?? "")
        _schedule = State(initialValue: factor?.scheduleDescription ?? "Daily")
        _evidence = State(initialValue: factor?.evidenceStatus ?? .personalExperiment)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Experiment") {
                    TextField("Factor name", text: $name)
                    Picker("Type", selection: $kind) {
                        ForEach(PersonalFactorKind.allCases, id: \.rawValue) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                    Picker("Intended outcome", selection: $outcome) {
                        ForEach(PersonalFactorOutcome.allCases, id: \.rawValue) {
                            Text($0.label).tag($0)
                        }
                    }
                    TextField("Hypothesis", text: $hypothesis, axis: .vertical)
                    TextField("Measurement schedule", text: $schedule)
                    Picker("Evidence status", selection: $evidence) {
                        ForEach(FactorEvidenceStatus.allCases, id: \.rawValue) {
                            Text($0.label).tag($0)
                        }
                    }
                }
                Section {
                    Text("A new measure starts a new comparison. Your history is kept and scores stay unchanged.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(original == nil ? "New Experiment" : "Edit Experiment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.disabled(cleanName.isEmpty || cleanHypothesis.isEmpty)
                }
            }
        }
    }

    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cleanHypothesis: String { hypothesis.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        let factor = PersonalFactor(
            id: original?.id ?? UUID().uuidString,
            name: cleanName,
            kind: kind,
            intendedOutcome: outcome,
            hypothesis: cleanHypothesis,
            scheduleDescription: schedule.trimmingCharacters(in: .whitespacesAndNewlines),
            startDayKey: original?.startDayKey ?? BullDates.key(for: Date()),
            evidenceStatus: evidence,
            definitionVersion: original?.definitionVersion ?? 1,
            archived: original?.archived ?? false,
            aliases: original?.aliases ?? [],
            scoringWeight: nil
        )
        onSave(factor)
        dismiss()
    }
}
