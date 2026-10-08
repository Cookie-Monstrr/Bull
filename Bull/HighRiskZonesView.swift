import SwiftUI
import UIKit
import CoreLocation
import MapKit
import UserNotifications

struct HighRiskZonesView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var zones: HighRiskZoneService
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var adding = false
    @State private var editing: HighRiskZone?
    @State private var showDiagnostics = false

    var body: some View {
        NavigationStack {
            List {
                permissionSection
                alertBehaviourSection

                Section("Configured Zones") {
                    if store.data.highRiskZones.isEmpty {
                        Text("No Risk Zones configured").foregroundStyle(.secondary)
                    }
                    ForEach(store.data.highRiskZones) { zone in
                        Button { editing = zone } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(zone.name).foregroundStyle(.primary)
                                    Text("\(zone.riskLevel.label) caution · \(Int(zone.radiusMetres)) m · \(scheduleText(zone))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(zoneStatus(zone).label)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(zoneStatus(zone).color)
                                }
                                Spacer()
                                Image(systemName: zoneStatus(zone).symbol)
                                    .foregroundStyle(zoneStatus(zone).color)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let values = store.data.highRiskZones
                        for index in offsets {
                            let zoneID = values[index].id
                            if store.deleteZone(id: zoneID) == .applied {
                                notifications.cancelZoneAlert(zoneID: zoneID)
                                store.cancelPendingZoneAlerts(zoneID: zoneID)
                                zones.stopMonitoring(zoneID: zoneID)
                            }
                        }
                    }
                    Button { adding = true } label: { Label("Add Risk Zone", systemImage: "plus") }
                        .disabled(store.data.highRiskZones.count >= 20)
                }

                Section("Recent Visits") {
                    let visits = recentVisits.prefix(10)
                    if visits.isEmpty { Text("No zone visits yet").foregroundStyle(.secondary) }
                    ForEach(Array(visits)) { visit in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.data.highRiskZones.first(where: { $0.id == visit.zoneID })?.name ?? "Previous zone")
                                Text(visit.exited == nil ? "Currently inside" : "Completed visit")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(visit.durationText(now: Date()))
                                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                                Text(visit.entered.date, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("Your therapist sees zone activity, without exact coordinates. A geofence cannot identify a room.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = zones.lastError {
                    Section("Location Status") {
                        Text(error).font(.caption).foregroundStyle(BullTheme.crimson)
                    }
                }
                if let notice = store.lastNotice {
                    Section("Oversight") {
                        Text(notice).font(.caption).foregroundStyle(BullTheme.amber)
                    }
                }
            }
            .navigationTitle("Risk Zones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .task {
            _ = store.refreshLaylaSleepScheduleFromSharedGroup()
            await zones.refreshPermissionState()
            await notifications.refreshStatus()
            zones.requestMonitoredRegionStates()
            _ = await zones.refreshCurrentZoneStates()
        }
        .sheet(isPresented: $adding) {
            HighRiskZoneEditor(zone: nil) { zone in
                let result = store.addZone(zone)
                if result == .applied, zone.enabled {
                    Task {
                        _ = await notifications.requestAuthorization()
                        await zones.requestBackgroundMonitoringAuthorization()
                    }
                }
                return result
            }
        }
        .sheet(item: $editing) { zone in
            HighRiskZoneEditor(zone: zone) { updated in
                let result = store.updateZone(updated)
                if result == .applied {
                    notifications.cancelZoneAlert(zoneID: updated.id)
                    store.cancelPendingZoneAlerts(zoneID: updated.id)
                    if updated.enabled {
                        Task { await zones.requestBackgroundMonitoringAuthorization() }
                    } else {
                        zones.stopMonitoring(zoneID: updated.id)
                    }
                    return .applied
                }
                if case .pendingApproval(let requestID) = result {
                    return .pendingApproval(requestID: requestID)
                }
                if case .rejected(let reason) = result { return .rejected(reason: reason) }
                return .rejected(reason: "Risk Zone save failed.")
            }
        }
        .sheet(isPresented: $showDiagnostics) { RiskZoneDiagnosticsView() }
    }

    @ViewBuilder
    private var permissionSection: some View {
        Section("Monitoring") {
            LabeledContent("Location access", value: zones.authorizationLabel)
            switch zones.permissionState {
            case .notRequested:
                Text("Allow location while using Bull to find or adjust a pin. Background access is requested only if you save an active zone.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Allow While Using Bull") { Task { await zones.requestWhenInUseAuthorization() } }
            case .whileUsing:
                Text("Pin selection is ready. Active zone monitoring needs Always access so iOS can detect entry when Bull is closed.")
                    .font(.caption).foregroundStyle(.secondary)
                if store.data.highRiskZones.contains(where: \.enabled) {
                    Button("Enable Background Alerts") {
                        Task { await zones.requestBackgroundMonitoringAuthorization() }
                    }
                }
            case .always:
                LabeledContent("Background monitoring", value: "Ready")
            case .denied, .restricted, .servicesOff:
                Text(permissionHelp)
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open iPhone Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            case .unknown:
                Text("Location status is unavailable. Refresh the device check or use the map manually.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LabeledContent("Risk Zone alerts", value: notificationLabel)
            if notifications.authorizationStatus != .authorized &&
                notifications.authorizationStatus != .provisional {
                Button("Allow Risk Zone Alerts") { Task { _ = await notifications.requestAuthorization() } }
            }
            Button("Check Device Status") { showDiagnostics = true }
        }
    }

    @ViewBuilder
    private var alertBehaviourSection: some View {
        Section("Alerts") {
            Toggle(
                "Time Sensitive",
                isOn: Binding(
                    get: { store.data.settings.zoneTimeSensitiveAlerts },
                    set: { _ = store.requestZoneTimeSensitiveAlerts($0) }
                )
            )
            .tint(BullTheme.gold)
            Stepper(
                "Repeat: \(store.data.settings.zoneNudgeRepeatMinutes) min",
                value: Binding(
                    get: { store.data.settings.zoneNudgeRepeatMinutes },
                    set: { _ = store.requestZoneNudgeRepeatMinutes($0) }
                ),
                in: 15...180,
                step: 15
            )
            Text("Repeats stop when the zone is resolved.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionHelp: String {
        switch zones.permissionState {
        case .servicesOff: return "Turn on iPhone Location Services, or choose the centre manually on the map."
        case .denied: return "Location access is denied. Bull can still use a manually placed pin after access is restored."
        case .restricted: return "Location access is restricted by this iPhone's settings. You can still inspect the map editor."
        default: return "Location permission needs attention."
        }
    }

    private func scheduleText(_ zone: HighRiskZone) -> String {
        if zone.scheduleMode == .sleepAnchored {
            return "Layla · \(zone.minutesAllowedAfterFinalWake)m after wake · \(zone.minutesAllowedBeforeBed)m before bed"
        }
        guard zone.startMinute != zone.endMinute else { return "all day" }
        func time(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
        return "\(time(zone.startMinute))–\(time(zone.endMinute))"
    }

    private var notificationLabel: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional: return "Allowed"
        case .denied: return "Denied"
        case .notDetermined: return "Not requested"
        case .ephemeral: return "Temporary"
        @unknown default: return "Unknown"
        }
    }

    private func zoneStatus(_ zone: HighRiskZone) -> (label: String, symbol: String, color: Color) {
        if store.data.riskControlChangeRequests.contains(where: {
            $0.zoneID == zone.id && $0.status == .pending
        }) {
            return ("Awaiting Therapist Approval · Current Zone Active", "person.badge.clock", BullTheme.amber)
        }
        if !zone.enabled { return ("Paused", "pause.circle", BullTheme.muted) }
        if zones.permissionState != .always {
            return ("Permission needed", "exclamationmark.location", BullTheme.amber)
        }
        if zones.monitoringFailedZoneIDs.contains(zone.id) {
            return ("Monitoring failed", "xmark.circle", BullTheme.crimson)
        }
        if !zones.monitoredZoneIDs.contains(zone.id) {
            return ("Monitoring pending", "clock", BullTheme.amber)
        }
        if store.isInsideZone(zone.id) {
            if !store.isZoneActive(zone, at: Date()) {
                return ("Inside · Outside Active Hours", "clock", BullTheme.green)
            }
            if zone.resolutionMode == .exitRequired {
                return ("Inside · Leave Zone", "figure.walk", BullTheme.crimson)
            }
            return store.isZoneSafeguarded(zone.id)
                ? ("Inside · Safeguarded", "shield.fill", Color.blue.opacity(0.75))
                : ("Inside · Action Needed", "exclamationmark.shield.fill", BullTheme.crimson)
        }
        if zones.regionState(for: zone.id) == .outside {
            return ("Outside · Monitoring", "location.fill", BullTheme.green)
        }
        return ("Checking Location", "location.circle", BullTheme.amber)
    }

    private var recentVisits: [ZoneVisit] {
        var open: [String: ZoneEvent] = [:]
        var visits: [ZoneVisit] = []
        for event in store.data.zoneEvents.sorted(by: { $0.ts < $1.ts }) {
            switch event.kind {
            case .entered:
                if open[event.zoneID] == nil { open[event.zoneID] = event }
            case .exited:
                if let entered = open.removeValue(forKey: event.zoneID) {
                    visits.append(ZoneVisit(entered: entered, exited: event))
                }
            }
        }
        visits.append(contentsOf: open.values.map { ZoneVisit(entered: $0, exited: nil) })
        return visits.sorted { $0.entered.ts > $1.entered.ts }
    }
}

private struct ZoneVisit: Identifiable {
    var id: String { entered.id }
    var zoneID: String { entered.zoneID }
    var entered: ZoneEvent
    var exited: ZoneEvent?

    func durationText(now: Date) -> String {
        let end = exited?.ts ?? now.timeIntervalSince1970 * 1_000
        let minutes = max(0, Int(((end - entered.ts) / 60_000).rounded()))
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours)h \(remainder)m"
    }
}

private struct HighRiskZoneEditor: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var zones: HighRiskZoneService
    @Environment(\.dismiss) private var dismiss
    let original: HighRiskZone?
    let onSave: (HighRiskZone) -> RiskControlMutationResult

    @StateObject private var placeSearch = RiskZonePlaceSearch()
    @State private var name: String
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var radius: Double
    @State private var riskLevel: ZoneRiskLevel
    @State private var enabled: Bool
    @State private var selectedDays: Set<Int>
    @State private var allDay: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var scheduleMode: ZoneScheduleMode
    @State private var minutesAllowedAfterFinalWake: Int
    @State private var minutesAllowedBeforeBed: Int
    @State private var activateWhenUnexpectedlyAwake: Bool
    @State private var resolutionMode: ZoneResolutionMode
    @State private var safeguardInstruction: String
    @State private var safeguardNote: String
    @State private var showNameOnLockScreen: Bool
    @State private var timeZoneIdentifier: String
    @State private var searchText = ""
    @State private var editorError: String?
    @State private var showSaveConfirmation = false

    init(zone: HighRiskZone?, onSave: @escaping (HighRiskZone) -> RiskControlMutationResult) {
        original = zone
        self.onSave = onSave
        _name = State(initialValue: zone?.name ?? "")
        _coordinate = State(initialValue: zone.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        })
        _radius = State(initialValue: min(500, max(75, zone?.radiusMetres ?? 150)))
        _riskLevel = State(initialValue: zone?.riskLevel ?? .high)
        _enabled = State(initialValue: zone?.enabled ?? true)
        let configuredDays = zone?.activeDays ?? []
        _selectedDays = State(initialValue: Set(configuredDays.isEmpty ? Array(0...6) : configuredDays))
        let isAllDay = zone == nil || zone?.startMinute == zone?.endMinute
        _allDay = State(initialValue: isAllDay)
        _startTime = State(initialValue: Self.date(for: zone?.startMinute ?? 0))
        _endTime = State(initialValue: Self.date(for: zone?.endMinute ?? 0))
        _scheduleMode = State(initialValue: zone?.scheduleMode ?? .fixed)
        _minutesAllowedAfterFinalWake = State(initialValue: zone?.minutesAllowedAfterFinalWake ?? 90)
        _minutesAllowedBeforeBed = State(initialValue: zone?.minutesAllowedBeforeBed ?? 90)
        _activateWhenUnexpectedlyAwake = State(initialValue: zone?.activateWhenUnexpectedlyAwake ?? true)
        _resolutionMode = State(initialValue: zone?.resolutionMode ?? .safeguard)
        _safeguardInstruction = State(initialValue:
            zone?.resolutionMode == .exitRequired ? "" : (zone?.safeguard.instruction ?? "")
        )
        _safeguardNote = State(initialValue: zone?.safeguard.note ?? "")
        _showNameOnLockScreen = State(initialValue: zone?.showNameOnLockScreen ?? false)
        _timeZoneIdentifier = State(initialValue: zone?.timeZoneIdentifier ?? TimeZone.current.identifier)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Place") {
                    TextField("Place name", text: $name)
                    HStack {
                        TextField("Search address or place", text: $searchText)
                            .textInputAutocapitalization(.words)
                            .onSubmit { Task { await placeSearch.search(searchText, near: coordinate) } }
                        Button {
                            Task { await placeSearch.search(searchText, near: coordinate) }
                        } label: {
                            if placeSearch.isSearching { ProgressView() }
                            else { Image(systemName: "magnifyingglass") }
                        }
                        .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    ForEach(Array(placeSearch.results.enumerated()), id: \.offset) { _, item in
                        let details = mapItemDetails(item)
                        Button {
                            coordinate = details.coordinate
                            if let placeTimeZone = item.timeZone {
                                timeZoneIdentifier = placeTimeZone.identifier
                            }
                            if cleanName.isEmpty { name = item.name ?? details.subtitle ?? "Risk Zone" }
                            placeSearch.clear()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Place")
                                if let title = details.subtitle {
                                    Text(title).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    if let error = placeSearch.lastError {
                        Text(error).font(.caption).foregroundStyle(BullTheme.crimson)
                    }
                    Button(zones.isFindingLocation ? "Finding location…" : "Use Current Location") {
                        Task { await captureLocation() }
                    }
                    .disabled(zones.isFindingLocation)

                    RiskZoneMapPicker(
                        coordinate: $coordinate,
                        radiusMetres: radius
                    )
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("Risk Zone map. Tap to place or drag the pin.")
                    Text("Tap the map or drag the pin. The circle is the building-scale monitoring radius.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let coordinate {
                        Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                            .font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                    Picker("Schedule time zone", selection: $timeZoneIdentifier) {
                        ForEach(timeZoneChoices, id: \.self) { identifier in
                            Text(identifier.replacingOccurrences(of: "_", with: " ")).tag(identifier)
                        }
                    }
                    Text("Risk windows keep this place-local clock if you travel. Search normally supplies it; choose explicitly after a manual pin.")
                        .font(.caption2).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Radius · \(Int(radius)) m")
                        Slider(value: $radius, in: 75...500, step: 25)
                    }
                }

                Section("Resolution") {
                    Toggle(
                        "No Safeguard Possible",
                        isOn: Binding(
                            get: { resolutionMode == .exitRequired },
                            set: { resolutionMode = $0 ? .exitRequired : .safeguard }
                        )
                    )
                    .tint(BullTheme.crimson)
                    if resolutionMode == .safeguard {
                        TextField("Concrete action", text: $safeguardInstruction, axis: .vertical)
                        TextField("Supporting note (optional)", text: $safeguardNote, axis: .vertical)
                    } else {
                        Text("Only leaving the active Risk Zone resolves it. Bull never offers a completion button for this zone.")
                            .font(.caption)
                            .foregroundStyle(BullTheme.crimson)
                    }
                    Picker("Operational caution", selection: $riskLevel) {
                        ForEach(ZoneRiskLevel.allCases, id: \.rawValue) { Text($0.label).tag($0) }
                    }
                    Text(resolutionMode == .exitRequired
                        ? "This marks the place as unresolved for the entire active visit."
                        : "Completing a safeguard records the action but does not erase residual exposure or automatically subtract Risk.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("When This Place Is Risky") {
                    Picker("Schedule", selection: $scheduleMode) {
                        ForEach(ZoneScheduleMode.allCases, id: \.rawValue) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    if scheduleMode == .sleepAnchored {
                        Stepper(
                            "Getting ready after final wake · \(minutesAllowedAfterFinalWake) min",
                            value: $minutesAllowedAfterFinalWake,
                            in: 15...240,
                            step: 15
                        )
                        Stepper(
                            "Wind-down before bed · \(minutesAllowedBeforeBed) min",
                            value: $minutesAllowedBeforeBed,
                            in: 15...240,
                            step: 15
                        )
                        Toggle("Unexpected Wake Alerts", isOn: $activateWhenUnexpectedlyAwake)
                        Text(store.laylaScheduleBridgeStatus.message)
                            .font(.caption)
                            .foregroundStyle(laylaStatusColor)
                        if store.laylaScheduleBridgeStatus.usesCurrentSchedule {
                            Text("A planned brief wake remains safe until Layla reports final wake or its return-to-sleep deadline expires.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(scheduleMode == .fixed
                        ? "The geofence can remain monitored outside these times. Prompts apply only in the selected windows."
                        : "Fixed hours remain the fallback whenever Layla data is missing, stale, or invalid.")
                        .font(.caption).foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(Array(enumeratedWeekdays), id: \.0) { day in
                            Button(day.1) {
                                if selectedDays.contains(day.0) { selectedDays.remove(day.0) }
                                else { selectedDays.insert(day.0) }
                            }
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(selectedDays.contains(day.0) ? BullTheme.gold.opacity(0.32) : BullTheme.field)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                        }
                    }
                    Toggle("All Day", isOn: $allDay)
                    if !allDay {
                        DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                        if Self.minute(of: startTime) > Self.minute(of: endTime) {
                            Text("Overnight window — ends the following morning.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Monitoring") {
                    Toggle("Monitoring", isOn: $enabled)
                    Text("Changes apply after Save. Active monitoring needs Always location access.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Lock Screen Details", isOn: $showNameOnLockScreen)
                    Text(showNameOnLockScreen
                         ? "Notifications may name Bull, this place and your chosen safeguard."
                         : "Lock-screen wording stays generic and private.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let error = editorError {
                    Section { Text(error).font(.caption).foregroundStyle(BullTheme.crimson) }
                }
            }
            .navigationTitle(original == nil ? "New Risk Zone" : "Edit Risk Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { showSaveConfirmation = true }
                        .disabled(!canSave)
                }
            }
            .alert("Save this Risk Zone?", isPresented: $showSaveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Save") { save() }
            } message: {
                Text("\(cleanName) · \(Int(radius)) m\nResolution: \(resolutionMode.label)")
            }
        }
    }

    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cleanSafeguard: String { safeguardInstruction.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var laylaStatusColor: Color {
        switch store.laylaScheduleBridgeStatus.state {
        case .current, .cachedCurrent, .ignoredOlderUpdate: return BullTheme.green
        case .invalid: return BullTheme.crimson
        case .notChecked, .unavailableInTherapistRole: return BullTheme.muted
        case .stale, .missing, .appGroupUnavailable: return BullTheme.amber
        }
    }
    private var canSave: Bool {
        !cleanName.isEmpty && (resolutionMode == .exitRequired || !cleanSafeguard.isEmpty) && coordinate != nil &&
            !selectedDays.isEmpty && TimeZone(identifier: timeZoneIdentifier) != nil
    }
    private var timeZoneChoices: [String] {
        Array(Set([
            timeZoneIdentifier,
            original?.timeZoneIdentifier ?? TimeZone.current.identifier,
            TimeZone.current.identifier,
            "Europe/London",
            "Africa/Cairo"
        ])).sorted()
    }
    private var enumeratedWeekdays: [(Int, String)] {
        [(0, "Sun"), (1, "Mon"), (2, "Tue"), (3, "Wed"), (4, "Thu"), (5, "Fri"), (6, "Sat")]
    }

    private func captureLocation() async {
        editorError = nil
        do {
            let location = try await zones.currentLocation()
            coordinate = location.coordinate
            timeZoneIdentifier = TimeZone.current.identifier
        } catch {
            editorError = error.localizedDescription
        }
    }

    private func mapItemDetails(
        _ item: MKMapItem
    ) -> (coordinate: CLLocationCoordinate2D, subtitle: String?) {
        if #available(iOS 26.0, *) {
            return (item.location.coordinate, nil)
        } else {
            return (item.placemark.coordinate, item.placemark.title)
        }
    }

    private func save() {
        guard let coordinate else { return }
        let days = selectedDays.count == 7 ? [] : selectedDays.sorted()
        let zoneID = original?.id ?? UUID().uuidString
        let resolvedInstruction = resolutionMode == .exitRequired ? "Leave this Risk Zone" : cleanSafeguard
        let resolvedNote = resolutionMode == .exitRequired ? nil : (cleanNote.isEmpty ? nil : cleanNote)
        let changedInstruction = original?.safeguard.instruction != resolvedInstruction ||
            original?.safeguard.note != resolvedNote || original?.resolutionMode != resolutionMode
        let safeguard = ZoneSafeguardDefinition(
            id: original?.safeguard.id ?? "safeguard.\(zoneID)",
            instruction: resolvedInstruction,
            note: resolvedNote,
            definitionVersion: original == nil
                ? 1
                : (original?.safeguard.definitionVersion ?? 1) + (changedInstruction ? 1 : 0)
        )
        let value = HighRiskZone(
            id: zoneID,
            name: cleanName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMetres: radius,
            riskLevel: riskLevel,
            enabled: enabled,
            activeDays: days,
            startMinute: allDay ? 0 : Self.minute(of: startTime),
            endMinute: allDay ? 0 : Self.minute(of: endTime),
            scheduleMode: scheduleMode,
            minutesAllowedAfterFinalWake: minutesAllowedAfterFinalWake,
            minutesAllowedBeforeBed: minutesAllowedBeforeBed,
            activateWhenUnexpectedlyAwake: activateWhenUnexpectedlyAwake,
            onlyWhenRiskAtLeast: nil,
            legacyOnlyWhenRiskAtLeast: original?.legacyOnlyWhenRiskAtLeast ?? original?.onlyWhenRiskAtLeast,
            resolutionMode: resolutionMode,
            safeguard: safeguard,
            showNameOnLockScreen: showNameOnLockScreen,
            timeZoneIdentifier: timeZoneIdentifier,
            createdTs: original?.createdTs ?? Date().timeIntervalSince1970 * 1_000
        )
        switch onSave(value) {
        case .applied:
            editorError = nil
            dismiss()
        case .pendingApproval:
            editorError = nil
            dismiss()
        case .rejected(let reason):
            editorError = reason
        }
    }

    private var cleanNote: String { safeguardNote.trimmingCharacters(in: .whitespacesAndNewlines) }

    private static func date(for minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }

    private static func minute(of date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
    }
}

private struct RiskZoneDiagnosticsView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var zones: HighRiskZoneService
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.dismiss) private var dismiss
    @State private var fixResult = "Not run"
    @State private var alertTestResult = "Not run"
    @State private var repairResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Device Status") {
                    LabeledContent("Location Services", value: zones.locationServicesEnabled ? "On" : "Off")
                    LabeledContent("Location permission", value: zones.authorizationLabel)
                    LabeledContent("Configured active zones", value: "\(store.data.highRiskZones.filter(\.enabled).count)")
                    LabeledContent("Monitored by iOS", value: "\(zones.monitoredZoneIDs.count)")
                    LabeledContent("Monitoring failures", value: "\(zones.monitoringFailedZoneIDs.count)")
                    LabeledContent("Configuration match", value: monitoringMatches ? "Matched" : "Needs Repair")
                    LabeledContent("Notifications", value: notificationLabel)
                    LabeledContent("Time Sensitive", value: timeSensitiveLabel)
                    LabeledContent("Foreground location fix", value: fixResult)
                    LabeledContent("Test alert", value: alertTestResult)
                }
                Section("Layla Schedule") {
                    Text(store.laylaScheduleBridgeStatus.message)
                        .font(.caption)
                    if let checked = store.laylaScheduleBridgeStatus.checkedTs {
                        LabeledContent("Last checked") {
                            Text(Date(timeIntervalSince1970: checked / 1_000), style: .relative)
                        }
                    }
                    if let updated = store.laylaScheduleBridgeStatus.sourceUpdatedTs {
                        LabeledContent("Last source update") {
                            Text(Date(timeIntervalSince1970: updated / 1_000), style: .relative)
                        }
                    }
                    if let sourceVersion = store.laylaScheduleBridgeStatus.sourceVersion {
                        LabeledContent("Source version", value: "\(sourceVersion)")
                    }
                    if let sequence = store.laylaScheduleBridgeStatus.sourceSequence {
                        LabeledContent("Update sequence", value: "\(sequence)")
                    }
                    if let source = store.laylaScheduleBridgeStatus.sourceBundleIdentifier {
                        LabeledContent("Source app", value: source)
                    }
                    if let timeZone = store.laylaScheduleBridgeStatus.timeZoneIdentifier {
                        LabeledContent("Schedule time zone", value: timeZone)
                    }
                }
                Section {
                    if !monitoringMatches {
                        Button("Repair Monitoring") {
                            Task {
                                zones.reconcileConfiguredZones(store.data.highRiskZones)
                                let removed = await notifications.reconcileZoneNotifications(
                                    validZoneIDs: Set(store.data.highRiskZones.map(\.id))
                                )
                                zones.requestMonitoredRegionStates()
                                repairResult = removed == 0
                                    ? "Monitoring reconciled."
                                    : "Monitoring reconciled and \(removed) stale alert(s) removed."
                            }
                        }
                    }
                    Button("Refresh Status") {
                        Task {
                            _ = store.refreshLaylaSleepScheduleFromSharedGroup()
                            await zones.refreshPermissionState()
                            await notifications.refreshStatus()
                        }
                    }
                    if let repairResult {
                        Text(repairResult).font(.caption).foregroundStyle(BullTheme.green)
                    }
                    Button("Test Current Location") {
                        Task {
                            let refreshed = await zones.refreshCurrentZoneStates(timeoutSeconds: 10)
                            fixResult = refreshed ? "Zones Reconciled" : (zones.lastError ?? "Failed")
                        }
                    }
                    Button("Send Test Alert") {
                        Task {
                            let sent = await notifications.scheduleZoneTestAlert(
                                timeSensitive: store.data.settings.zoneTimeSensitiveAlerts
                            )
                            alertTestResult = sent ? "Scheduled" : (notifications.lastError ?? "Failed")
                        }
                    }
                }
                Section {
                    Text("This confirms configuration and permissions only. It does not fake or claim a real geofence boundary crossing.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Risk Zone Device Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .task {
            _ = store.refreshLaylaSleepScheduleFromSharedGroup()
            await zones.refreshPermissionState()
            await notifications.refreshStatus()
        }
    }

    private var notificationLabel: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional: return "Allowed"
        case .denied: return "Denied"
        case .notDetermined: return "Not requested"
        case .ephemeral: return "Temporary"
        @unknown default: return "Unknown"
        }
    }

    private var monitoringMatches: Bool {
        Set(store.data.highRiskZones.filter(\.enabled).map(\.id)) == zones.monitoredZoneIDs &&
            zones.monitoringFailedZoneIDs.isEmpty
    }

    private var timeSensitiveLabel: String {
        switch notifications.timeSensitiveSetting {
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        case .notSupported: return "Not supported"
        @unknown default: return "Unknown"
        }
    }
}
