import SwiftUI

struct ImplementationPlansView: View {
    @EnvironmentObject private var store: BullStore
    @Environment(\.dismiss) private var dismiss

    @State private var adding = false
    @State private var editing: ImplementationPlan?
    @State private var showActiveLimit = false

    private var activeCount: Int { store.data.plans.filter(\.enabled).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    BullCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Keep 1–3 Active")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BullTheme.goldDark)
                                Text("Cover your recurring high-risk situations — not every possibility.")
                                    .font(.caption)
                                    .foregroundStyle(BullTheme.secondary)
                            }
                            Spacer()
                            Text("\(activeCount)/3")
                                .font(.system(.headline, design: .monospaced).weight(.bold))
                                .foregroundStyle(BullTheme.ink)
                        }
                    }

                    if store.data.plans.isEmpty {
                        BullCard {
                            Text("No plans yet")
                                .font(.headline)
                            Text("Example: If I am alone in bed with my phone, then I leave the phone outside the room.")
                                .font(.caption)
                                .foregroundStyle(BullTheme.secondary)
                        }
                    }

                    ForEach(store.data.plans) { plan in
                        BullCard {
                            HStack(alignment: .top, spacing: 12) {
                                Button { toggle(plan) } label: {
                                    Image(systemName: plan.enabled ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(plan.enabled ? BullTheme.green : BullTheme.muted)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(plan.enabled ? "Deactivate plan" : "Activate plan")

                                VStack(alignment: .leading, spacing: 5) {
                                    Text("If")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BullTheme.crimson)
                                    Text(plan.trigger)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(BullTheme.ink)
                                    Text("Then")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BullTheme.goldDark)
                                        .padding(.top, 2)
                                    Text(plan.action)
                                        .font(.subheadline)
                                        .foregroundStyle(BullTheme.ink)
                                }

                                Spacer(minLength: 6)

                                Menu {
                                    Button { editing = plan } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) { store.deletePlan(plan.id) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(BullTheme.muted)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(BullTheme.ivory.ignoresSafeArea())
            .navigationTitle("If–Then")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .sheet(isPresented: $adding) {
            PlanEditorView(
                title: "New Plan",
                trigger: "",
                action: "",
                note: activeCount >= 3 ? "This will be saved inactive because you already have three active plans." : nil
            ) { trigger, action in
                store.addPlan(trigger: trigger, action: action, enabled: activeCount < 3)
            }
        }
        .sheet(item: $editing) { plan in
            PlanEditorView(title: "Edit Plan", trigger: plan.trigger, action: plan.action, note: nil) { trigger, action in
                var updated = plan
                updated.trigger = trigger
                updated.triggerID = store.addTrigger(named: trigger)?.id
                updated.action = action
                store.updatePlan(updated)
            }
        }
        .alert("Three active plans is enough", isPresented: $showActiveLimit) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Deactivate one first. Bull keeps the Today screen focused on a small set of rehearsable plans.")
        }
    }

    private func toggle(_ plan: ImplementationPlan) {
        if !plan.enabled && activeCount >= 3 {
            showActiveLimit = true
            return
        }
        var updated = plan
        updated.enabled.toggle()
        store.updatePlan(updated)
    }
}

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let note: String?
    let onSave: (String, String) -> Void

    @State private var trigger: String
    @State private var action: String

    init(title: String, trigger: String, action: String, note: String?, onSave: @escaping (String, String) -> Void) {
        self.title = title
        self.note = note
        self.onSave = onSave
        _trigger = State(initialValue: trigger)
        _action = State(initialValue: action)
    }

    private var trimmedTrigger: String { trigger.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedAction: String { action.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("If") {
                    TextField("Specific trigger", text: $trigger, axis: .vertical)
                    Text("Example: I am alone in bed with my phone")
                        .font(.caption)
                        .foregroundStyle(BullTheme.muted)
                }
                Section("Then") {
                    TextField("Specific response", text: $action, axis: .vertical)
                    Text("Example: I leave the phone outside and walk for 10 minutes")
                        .font(.caption)
                        .foregroundStyle(BullTheme.muted)
                }
                if let note {
                    Section {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(BullTheme.secondary)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(trimmedTrigger, trimmedAction)
                        dismiss()
                    }
                    .disabled(trimmedTrigger.isEmpty || trimmedAction.isEmpty)
                }
            }
        }
    }
}
