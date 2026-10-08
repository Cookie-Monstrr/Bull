import SwiftUI

struct TriggerResponseLibraryView: View {
    @EnvironmentObject private var store: BullStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingTrigger: TriggerDefinition?
    @State private var editingResponse: ResponseDefinition?
    @State private var addingTrigger = false
    @State private var addingResponse = false
    @State private var mergeTrigger: TriggerDefinition?
    @State private var mergeResponse: ResponseDefinition?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.data.triggerLibrary.filter { !$0.archived }) { trigger in
                        libraryRow(
                            title: trigger.name,
                            subtitle: usageText(forTrigger: trigger.id),
                            onEdit: { editingTrigger = trigger },
                            onArchive: { var value = trigger; value.archived = true; store.updateTrigger(value) },
                            onMerge: { mergeTrigger = trigger }
                        )
                    }
                    Button { addingTrigger = true } label: {
                        Label("Add Trigger", systemImage: "plus")
                    }
                } header: { Text("Triggers") }

                Section {
                    ForEach(store.data.responseLibrary.filter {
                        !$0.archived && $0.id != "response.contact" && $0.id != "response.if-then"
                    }) { response in
                        libraryRow(
                            title: response.name,
                            subtitle: "\(response.evidence.label) · \(usageText(forResponse: response.id))",
                            onEdit: { editingResponse = response },
                            onArchive: { var value = response; value.archived = true; store.updateResponse(value) },
                            onMerge: { mergeResponse = response }
                        )
                    }
                    Button { addingResponse = true } label: {
                        Label("Add Response", systemImage: "plus")
                    }
                } header: { Text("Responses") }

                let archivedTriggers = store.data.triggerLibrary.filter(\.archived)
                // Contact/disclosure and visible If–Then actions are retained only for
                // historical decoding. They are deliberately not restored into v3.0's
                // optional post-sigh action list.
                let retiredResponseIDs: Set<String> = ["response.contact", "response.if-then"]
                let archivedResponses = store.data.responseLibrary.filter {
                    $0.archived && !retiredResponseIDs.contains($0.id)
                }
                if !archivedTriggers.isEmpty || !archivedResponses.isEmpty {
                    Section("Archived") {
                        ForEach(archivedTriggers) { trigger in
                            Button("Restore · \(trigger.name)") {
                                var value = trigger; value.archived = false; store.updateTrigger(value)
                            }
                        }
                        ForEach(archivedResponses) { response in
                            Button("Restore · \(response.name)") {
                                var value = response; value.archived = false; store.updateResponse(value)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trigger & Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .sheet(item: $editingTrigger) { trigger in
            TriggerEditorView(title: "Edit Trigger", initialName: trigger.name) { name in
                var value = trigger; value.name = name; store.updateTrigger(value)
            }
        }
        .sheet(isPresented: $addingTrigger) {
            TriggerEditorView(title: "New Trigger", initialName: "") { _ = store.addTrigger(named: $0) }
        }
        .sheet(item: $editingResponse) { response in
            ResponseEditorView(title: "Edit Response", response: response) { store.updateResponse($0) }
        }
        .sheet(isPresented: $addingResponse) {
            ResponseEditorView(title: "New Response", response: ResponseDefinition(name: "")) {
                guard let created = store.addResponse(named: $0.name) else { return }
                var configured = created
                configured.evidence = $0.evidence
                store.updateResponse(configured)
            }
        }
        .confirmationDialog(
            "Merge ‘\(mergeTrigger?.name ?? "")’ into…",
            isPresented: Binding(get: { mergeTrigger != nil }, set: { if !$0 { mergeTrigger = nil } }),
            titleVisibility: .visible
        ) {
            if let source = mergeTrigger {
                ForEach(store.data.triggerLibrary.filter { !$0.archived && $0.id != source.id }) { target in
                    Button(target.name) { store.mergeTrigger(sourceID: source.id, into: target.id); mergeTrigger = nil }
                }
            }
            Button("Cancel", role: .cancel) { mergeTrigger = nil }
        } message: {
            Text("Historical events and matching implementation-plan records will move to the selected label.")
        }
        .confirmationDialog(
            "Merge ‘\(mergeResponse?.name ?? "")’ into…",
            isPresented: Binding(get: { mergeResponse != nil }, set: { if !$0 { mergeResponse = nil } }),
            titleVisibility: .visible
        ) {
            if let source = mergeResponse {
                ForEach(store.data.responseLibrary.filter { !$0.archived && $0.id != source.id }) { target in
                    Button(target.name) { store.mergeResponse(sourceID: source.id, into: target.id); mergeResponse = nil }
                }
            }
            Button("Cancel", role: .cancel) { mergeResponse = nil }
        } message: {
            Text("Historical response attempts will move to the selected label.")
        }
    }

    private func usageText(forTrigger id: String) -> String {
        let count = store.data.urges.filter { $0.triggerIDs.contains(id) }.count
        return "\(count) urge\(count == 1 ? "" : "s")"
    }

    private func usageText(forResponse id: String) -> String {
        let count = store.data.responseAttempts.filter {
            $0.responseID == id && $0.completedTs != nil
        }.count
        return "\(count) completed"
    }

    private func libraryRow(
        title: String,
        subtitle: String,
        onEdit: @escaping () -> Void,
        onArchive: @escaping () -> Void,
        onMerge: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
                Button(action: onMerge) { Label("Merge", systemImage: "arrow.triangle.merge") }
                Button(role: .destructive, action: onArchive) {
                    Label("Archive", systemImage: "archivebox")
                }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }
}

struct TriggerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onSave: (String) -> Void
    @State private var name: String

    init(title: String, initialName: String, onSave: @escaping (String) -> Void) {
        self.title = title; self.onSave = onSave; _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form { TextField("Trigger", text: $name) }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") { onSave(cleanName); dismiss() }.disabled(cleanName.isEmpty)
                    }
                }
        }
    }

    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
}

struct ResponseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onSave: (ResponseDefinition) -> Void
    @State private var value: ResponseDefinition

    init(title: String, response: ResponseDefinition, onSave: @escaping (ResponseDefinition) -> Void) {
        self.title = title; self.onSave = onSave; _value = State(initialValue: response)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Response", text: $value.name)
                Picker("Evidence", selection: $value.evidence) {
                    ForEach(ResponseEvidence.allCases, id: \.rawValue) { Text($0.label).tag($0) }
                }
                Text("Bull records completed optional actions for personal review. They never change Urge Fuel or Urge State automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { value.name = cleanName; onSave(value); dismiss() }.disabled(cleanName.isEmpty)
                }
            }
        }
    }

    private var cleanName: String { value.name.trimmingCharacters(in: .whitespacesAndNewlines) }
}
