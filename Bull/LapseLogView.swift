import SwiftUI

struct LapseLogView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    @State private var components: Set<LapseComponent>
    @State private var triggerIDs: Set<String>
    @State private var nextAction: String
    @State private var occurrenceDate: Date
    @State private var timePrecision: LapseTimePrecision
    @State private var occurrenceTime: Date
    @State private var dayPart: LapseDayPart
    @State private var locationPrecision: LapseLocationPrecision
    @State private var zoneID: String?
    @State private var placeName: String
    @State private var timeZoneIdentifier: String
    let existing: RelapseEvent?
    @State private var savedDraft: Draft?
    @State private var confirmingDiscard = false
    @State private var pendingSave = false

    private struct Draft: Equatable {
        let components: Set<LapseComponent>
        let triggers: Set<String>
        let next: String
        let date: Date
        let precision: LapseTimePrecision
        let time: Date
        let dayPart: LapseDayPart
        let location: LapseLocationPrecision
        let zone: String?
        let place: String
        let timeZone: String
    }
    private var draft: Draft {
        Draft(components: components, triggers: triggerIDs, next: nextAction, date: occurrenceDate,
              precision: timePrecision, time: occurrenceTime, dayPart: dayPart,
              location: locationPrecision, zone: zoneID, place: placeName, timeZone: timeZoneIdentifier)
    }
    private var isDirty: Bool { savedDraft.map { $0 != draft } ?? false }

    init(existing: RelapseEvent? = nil, date selectedDate: Date? = nil) {
        self.existing = existing
        let occurrence = existing?.occurrence
        let dayKey = occurrence?.occurrenceDayKey ?? existing?.dayKey
        let date = dayKey.flatMap(BullDates.date(from:)) ?? selectedDate ?? Date()
        _components = State(initialValue: Set(existing?.components ?? []))
        _triggerIDs = State(initialValue: Set(existing?.triggerIDs ?? []))
        _nextAction = State(initialValue: existing?.nextAction ?? "")
        _occurrenceDate = State(initialValue: date)
        _timePrecision = State(initialValue: occurrence?.timePrecision ?? (existing == nil && BullDates.sameDay(date, Date()) ? .exact : .unknown))
        _occurrenceTime = State(initialValue: occurrence?.occurrenceTs.map {
            Date(timeIntervalSince1970: $0 / 1_000)
        } ?? Date())
        _dayPart = State(initialValue: occurrence?.dayPart ?? .evening)
        _locationPrecision = State(initialValue: occurrence?.locationPrecision ?? .unknown)
        _zoneID = State(initialValue: occurrence?.zoneID)
        _placeName = State(initialValue: occurrence?.placeName ?? "")
        _timeZoneIdentifier = State(initialValue: occurrence?.timeZoneIdentifier ?? TimeZone.current.identifier)
    }

    private var activeTriggers: [TriggerDefinition] { store.data.triggerLibrary.filter { !$0.archived } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Record what happened and your next useful action.")
                        .font(.subheadline)
                }

                Section("What Happened?") {
                    ForEach(LapseComponent.allCases, id: \.rawValue) { component in
                        Button {
                            if components.contains(component) { components.remove(component) }
                            else { components.insert(component) }
                        } label: {
                            HStack {
                                Text(component.label)
                                Spacer()
                                Image(systemName: components.contains(component) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(components.contains(component) ? BullTheme.crimson : BullTheme.muted)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Choose what happened. Wet dreams don't count as a lapse.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("When Did It Occur?") {
                    DatePicker("Occurrence Date", selection: $occurrenceDate, in: ...Date(), displayedComponents: .date)
                    Picker("Time Precision", selection: $timePrecision) {
                        ForEach(LapseTimePrecision.allCases, id: \.rawValue) { Text($0.label).tag($0) }
                    }
                    if timePrecision == .exact || timePrecision == .approximate {
                        DatePicker(
                            timePrecision == .exact ? "Time" : "Approximate Time",
                            selection: $occurrenceTime,
                            displayedComponents: .hourAndMinute
                        )
                    } else if timePrecision == .partOfDay {
                        Picker("Part of Day", selection: $dayPart) {
                            ForEach(LapseDayPart.allCases, id: \.rawValue) { Text($0.label).tag($0) }
                        }
                    }
                    Text("Choose Unknown if you don't remember the time.")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Occurrence time zone", selection: $timeZoneIdentifier) {
                        ForEach(timeZoneChoices, id: \.self) { identifier in
                            Text(identifier.replacingOccurrences(of: "_", with: " ")).tag(identifier)
                        }
                    }
                    .disabled(locationPrecision == .riskZone && zoneID != nil)
                }

                Section("Where Did It Occur?") {
                    Picker("Location Precision", selection: $locationPrecision) {
                        ForEach(LapseLocationPrecision.allCases, id: \.rawValue) { Text($0.label).tag($0) }
                    }
                    if locationPrecision == .riskZone {
                        if store.data.highRiskZones.isEmpty {
                            Text("No Risk Zones are configured. Choose another precision.")
                                .font(.caption).foregroundStyle(BullTheme.amber)
                        } else {
                            Picker("Risk Zone", selection: $zoneID) {
                                Text("Choose Zone").tag(String?.none)
                                ForEach(store.data.highRiskZones) { zone in
                                    Text(zone.name).tag(String?.some(zone.id))
                                }
                            }
                            .onChange(of: zoneID) { _, selectedID in
                                if let selectedID,
                                   let identifier = store.data.highRiskZones
                                    .first(where: { $0.id == selectedID })?.timeZoneIdentifier {
                                    timeZoneIdentifier = identifier
                                }
                            }
                        }
                    } else if locationPrecision == .namedPlace || locationPrecision == .approximatePlace {
                        TextField(
                            locationPrecision == .namedPlace ? "Place Name" : "Approximate Place",
                            text: $placeName
                        )
                    }
                    Text("Places entered here are saved as your recollection.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Triggers · Optional") {
                    FlowLayout(spacing: 7) {
                        ForEach(activeTriggers) { trigger in
                            chip(trigger.name, selected: triggerIDs.contains(trigger.id)) {
                                if triggerIDs.contains(trigger.id) { triggerIDs.remove(trigger.id) }
                                else { triggerIDs.insert(trigger.id) }
                            }
                        }
                    }
                }

                Section("Next Useful Action") {
                    if !store.data.settings.lapsePlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(store.data.settings.lapsePlan).font(.subheadline)
                    }
                    TextField("Leave the room, block access, call someone…", text: $nextAction, axis: .vertical)
                }
            }
            .navigationTitle(existing == nil ? "Log Lapse" : "Edit Lapse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { if isDirty { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
        }
        .bullFormSurface()
        .bullDraftGuard(isDirty: isDirty || pendingSave, confirming: $confirmingDiscard) { dismiss() }
        .bullPendingSave($pendingSave) { dismiss() }
        .onAppear { if savedDraft == nil { savedDraft = draft } }
    }

    private var canSave: Bool {
        guard !components.isEmpty else { return false }
        if locationPrecision == .riskZone { return zoneID != nil }
        if locationPrecision == .namedPlace || locationPrecision == .approximatePlace {
            return !placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? BullTheme.amber.opacity(0.32) : BullTheme.field)
            .foregroundStyle(BullTheme.ink)
            .clipShape(Capsule())
            .buttonStyle(.plain)
    }

    private func save() {
        let action = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = action.isEmpty ? nil : action
        let dayKey = BullDates.key(for: occurrenceDate)
        let timestamp = combinedTimestampMS()
        let range = partOfDayRangeMS()
        let isHistorical = !BullDates.sameDay(occurrenceDate, Date())
        let source: ObservationSource
        if existing == nil {
            source = isHistorical ? .retrospectiveBackfill : .live
        } else {
            switch existing?.occurrence.source {
            case .live, .prospectiveEdit:
                source = isHistorical ? .retrospectiveBackfill : .prospectiveEdit
            case .delayedRecall, .retrospectiveBackfill, .migratedLegacy, .automaticHealthKit, .none:
                source = .retrospectiveBackfill
            }
        }
        let occurrenceZone = occurrenceTimeZone
        let offsetReference = (timestamp ?? range?.0).map {
            Date(timeIntervalSince1970: $0 / 1_000)
        } ?? occurrenceDate
        let occurrence = LapseOccurrenceMetadata(
            occurrenceDayKey: dayKey,
            occurrenceTs: timestamp ?? range?.0,
            occurrenceEndTs: range?.1,
            timePrecision: timePrecision,
            dayPart: timePrecision == .partOfDay ? dayPart : nil,
            locationPrecision: locationPrecision,
            zoneID: locationPrecision == .riskZone ? zoneID : nil,
            placeName: [.namedPlace, .approximatePlace].contains(locationPrecision)
                ? placeName.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil,
            timeZoneIdentifier: occurrenceZone.identifier,
            utcOffsetMinutes: occurrenceZone.secondsFromGMT(for: offsetReference) / 60,
            source: source,
            timeConfidence: timeConfidence,
            locationConfidence: selectedLocationConfidence
        )
        let saved = feedback.save(store, message: "Lapse Saved") {
          if let existing {
            store.updateRelapse(
                id: existing.id,
                components: components,
                triggerIDs: Array(triggerIDs),
                nextAction: next
            )
            store.updateRelapseOccurrence(id: existing.id, occurrence: occurrence)
        } else {
            store.logRelapse(
                components: components,
                triggerIDs: Array(triggerIDs),
                nextAction: next,
                occurrence: occurrence
            )
          }
        }
        if saved { dismiss() } else { pendingSave = true }
    }

    private var timeConfidence: FieldConfidence {
        switch timePrecision {
        case .exact: return .exact
        case .approximate, .partOfDay: return .approximate
        case .unknown: return .unknown
        }
    }

    private var selectedLocationConfidence: FieldConfidence {
        switch locationPrecision {
        case .unknown: return .unknown
        case .approximatePlace: return .approximate
        case .riskZone, .namedPlace, .elsewhere: return .exact
        }
    }

    private var occurrenceTimeZone: TimeZone {
        if locationPrecision == .riskZone,
           let zoneID,
           let identifier = store.data.highRiskZones.first(where: { $0.id == zoneID })?.timeZoneIdentifier,
           let zone = TimeZone(identifier: identifier) {
            return zone
        }
        return TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    private var timeZoneChoices: [String] {
        let zoneIdentifiers = store.data.highRiskZones.compactMap(\.timeZoneIdentifier)
        let values = [
            timeZoneIdentifier,
            TimeZone.current.identifier,
            "Europe/London",
            "Africa/Cairo"
        ] + zoneIdentifiers
        return Array(Set(values)).sorted()
    }

    private func combinedTimestampMS() -> Double? {
        guard timePrecision == .exact || timePrecision == .approximate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = occurrenceTimeZone
        var dateParts = calendar.dateComponents([.year, .month, .day], from: occurrenceDate)
        let timeParts = calendar.dateComponents([.hour, .minute], from: occurrenceTime)
        dateParts.hour = timeParts.hour
        dateParts.minute = timeParts.minute
        return calendar.date(from: dateParts)?.timeIntervalSince1970.mapMilliseconds
    }

    private func partOfDayRangeMS() -> (Double, Double)? {
        guard timePrecision == .partOfDay else { return nil }
        let hours: (Int, Int)
        switch dayPart {
        case .morning: hours = (6, 12)
        case .afternoon: hours = (12, 17)
        case .evening: hours = (17, 22)
        case .night: hours = (22, 24)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = occurrenceTimeZone
        let startOfDay = calendar.startOfDay(for: occurrenceDate)
        guard let start = calendar.date(byAdding: .hour, value: hours.0, to: startOfDay) else { return nil }
        let end: Date?
        if hours.1 == 24 {
            end = calendar.date(byAdding: .day, value: 1, to: startOfDay)
        } else {
            end = calendar.date(byAdding: .hour, value: hours.1, to: startOfDay)
        }
        guard let end else { return nil }
        return (start.timeIntervalSince1970.mapMilliseconds, end.timeIntervalSince1970.mapMilliseconds)
    }
}

private extension Double {
    var mapMilliseconds: Double { self * 1_000 }
}
