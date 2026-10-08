import SwiftUI

struct ItemManagementView: View {
    @EnvironmentObject private var store: BullStore
    @Environment(\.dismiss) private var dismiss
    @State private var newLabel = ""
    @State private var newList: ItemList = .prev
    @State private var newKind: ItemKind = .risk
    @State private var newWeight: Weight = .med
    @State private var newVigourWeight: Weight = .low
    @State private var newBucket: Bucket = .heart
    @State private var newRiskDomain: RiskDomain = .exposure

    var body: some View {
        NavigationStack {
            List {
                Section("Prevention") {
                    let items = store.data.items.filter { $0.list == .prev }
                    if items.isEmpty { Text("No prevention items").foregroundStyle(.secondary) }
                    ForEach(items) { item in itemLink(item) }
                }

                Section("Double Horns") {
                    let items = store.data.items.filter { $0.list == .both }
                    if items.isEmpty { Text("No Double Horns items").foregroundStyle(.secondary) }
                    ForEach(items) { item in itemLink(item) }
                }

                Section("Vigour") {
                    ForEach(Bucket.allCases, id: \.rawValue) { bucket in
                        let items = store.data.items.filter { $0.list == .prime && ($0.bucket ?? .test) == bucket }
                        if !items.isEmpty {
                            DisclosureGroup(bucket.label) {
                                ForEach(items) { item in itemLink(item) }
                            }
                        }
                    }
                }

                Section("Add Custom Item") {
                    TextField("Name", text: $newLabel)
                    Picker("List", selection: $newList) {
                        Text("Prevention").tag(ItemList.prev)
                        Text("Vigour").tag(ItemList.prime)
                        Text("Both").tag(ItemList.both)
                    }
                    Picker("Type", selection: $newKind) {
                        Text("Risk").tag(ItemKind.risk)
                        Text("Habit").tag(ItemKind.habit)
                    }
                    if newList.feedsPrevention {
                        Picker("Risk domain", selection: $newRiskDomain) {
                            ForEach(RiskDomain.allCases, id: \.rawValue) { d in Text(d.label).tag(d) }
                        }
                    }
                    if newList.feedsVigour {
                        Picker("Vigour bucket", selection: $newBucket) {
                            ForEach(Bucket.allCases, id: \.rawValue) { b in Text(b.label).tag(b) }
                        }
                    }
                    Picker(newList == .prime ? "Vigour Weight" : "Prevention Weight", selection: $newWeight) {
                        ForEach(Weight.allCases, id: \.rawValue) { w in Text(w.label).tag(w) }
                    }
                    if newList == .both {
                        Picker("Vigour weight", selection: $newVigourWeight) {
                            ForEach(Weight.allCases, id: \.rawValue) { w in Text(w.label).tag(w) }
                        }
                    }
                    Button("Add") { add() }
                        .disabled(newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Safety") {
                    Button("Restore Built-ins") { store.restoreMissingDefaultItems() }
                    Text("Built-ins keep their own scoring rules. Custom items use simple risk or habit toggles.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Scoring Items")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    @ViewBuilder
    private func itemLink(_ item: Item) -> some View {
        NavigationLink {
            ItemEditorView(item: item)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.label).font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(item.kind.rawValue.uppercased())
                    if item.list.feedsPrevention {
                        Text("· \(effectiveRiskDomain(for: item).label)")
                    }
                    if item.list.feedsVigour {
                        Text("· \((item.bucket ?? .test).label)")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { delete(item) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func delete(_ item: Item) {
        store.replaceItems(store.data.items.filter { $0.id != item.id })
    }

    private func add() {
        let label = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        var items = store.data.items
        items.append(Item(
            id: "custom-\(UUID().uuidString)", label: label, list: newList,
            kind: newKind, weight: newWeight,
            vigourWeight: newList == .both ? newVigourWeight : nil,
            bucket: newList.feedsVigour ? newBucket : nil,
            riskDomain: newList.feedsPrevention ? newRiskDomain : nil,
            freq: .daily
        ))
        store.replaceItems(items)
        newLabel = ""
    }
}

private struct ItemEditorView: View {
    @EnvironmentObject private var store: BullStore
    @Environment(\.dismiss) private var dismiss
    @State var item: Item
    @State private var daily: Bool
    @State private var weekdays: Set<Int>

    init(item: Item) {
        _item = State(initialValue: item)
        switch item.freq {
        case .days(let d):
            _daily = State(initialValue: d.isEmpty)
            _weekdays = State(initialValue: Set(d))
        default:
            _daily = State(initialValue: true)
            _weekdays = State(initialValue: [])
        }
    }

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $item.label)
                if item.kind.isToggleable {
                    Picker("Score side", selection: $item.list) {
                        Text("Prevention").tag(ItemList.prev)
                        Text("Vigour").tag(ItemList.prime)
                        Text("Double Horns").tag(ItemList.both)
                    }
                } else {
                    LabeledContent("Score side", value: sideLabel(item.list))
                    Text("This built-in uses bespoke scoring, so its score side is locked.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Type", value: item.kind.rawValue.uppercased())
                if item.list.feedsPrevention {
                    Picker("Risk domain", selection: Binding(
                        get: { item.riskDomain ?? effectiveRiskDomain(for: item) },
                        set: { item.riskDomain = $0 }
                    )) {
                        ForEach(RiskDomain.allCases, id: \.rawValue) { d in Text(d.label).tag(d) }
                    }
                }
            }
            Section("Weights") {
                Picker(item.list == .prime ? "Vigour" : "Prevention", selection: $item.weight) {
                    ForEach(Weight.allCases, id: \.rawValue) { w in Text(w.label).tag(w) }
                }
                if item.list == .both {
                    Picker("Vigour", selection: Binding(
                        get: { item.vigourWeight ?? item.weight },
                        set: { item.vigourWeight = $0 }
                    )) {
                        ForEach(Weight.allCases, id: \.rawValue) { w in Text(w.label).tag(w) }
                    }
                }
            }
            if item.kind.isToggleable && !item.isFastingAuto {
                Section("Schedule") {
                    Toggle("Daily", isOn: $daily)
                    if !daily {
                        HStack(spacing: 5) {
                            ForEach(Array(["S","M","T","W","T","F","S"].enumerated()), id: \.offset) { i, label in
                                Button(label) {
                                    if weekdays.contains(i) { weekdays.remove(i) } else { weekdays.insert(i) }
                                }
                                .font(.caption2.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(weekdays.contains(i) ? BullTheme.gold.opacity(0.65) : BullTheme.field)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Toggle("Excuse on Sick or Travel Days", isOn: Binding(
                        get: { item.excusable == true },
                        set: { item.excusable = $0 }
                    ))
                }
            }
            if item.list.feedsVigour {
                Section("Vigour Bucket") {
                    Picker("Bucket", selection: Binding(
                        get: { item.bucket ?? .heart },
                        set: { item.bucket = $0 }
                    )) {
                        ForEach(Bucket.allCases, id: \.rawValue) { b in Text(b.label).tag(b) }
                    }
                }
            }
        }
        .navigationTitle("Edit Item")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    item.freq = daily ? .daily : .days(Array(weekdays).sorted())
                    if item.list.feedsVigour && item.bucket == nil { item.bucket = .heart }
                    if !item.list.feedsVigour { item.bucket = nil; item.vigourWeight = nil }
                    if item.list.feedsPrevention && item.riskDomain == nil { item.riskDomain = effectiveRiskDomain(for: item) }
                    if !item.list.feedsPrevention { item.riskDomain = nil }
                    if item.list == .both && item.vigourWeight == nil { item.vigourWeight = item.weight }
                    store.updateItem(item)
                    dismiss()
                }
            }
        }
    }

    private func sideLabel(_ list: ItemList) -> String {
        switch list {
        case .prev: return "Prevention"
        case .prime: return "Vigour"
        case .both: return "Double Horns"
        }
    }
}
