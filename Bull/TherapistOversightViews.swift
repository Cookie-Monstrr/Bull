import Foundation
import SwiftUI

struct TherapistAccessEndedView: View {
    @EnvironmentObject private var store: BullStore

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Oversight Ended", systemImage: "person.crop.circle.badge.xmark")
            } description: {
                Text("Your client revoked the private iCloud share. Their Bull data is no longer available on this device.")
            } actions: {
                Button("Clear Client View") { store.clearTherapistRole() }
                    .buttonStyle(.borderedProminent)
                    .tint(BullTheme.gold)
                    .foregroundStyle(BullTheme.ink)
            }
            .padding()
            .navigationTitle("Client Oversight")
        }
    }
}

struct TherapistOversightSettingsView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var cloud: TherapistCloudService
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    @State private var showConsent = false
    @State private var showEndConfirmation = false
    @State private var showTherapistPreview = false

    private var configuration: TherapistOversightConfiguration {
        store.data.therapistOversight
    }

    var body: some View {
        Form {
            Section("Status") {
                if cloud.isEndingAccess {
                    ProgressView(cloud.endAccessStatus ?? "Ending access…")
                } else if let status = cloud.endAccessStatus {
                    Text(status).font(.callout)
                        .foregroundStyle(configuration.state == .ended ? BullTheme.green : BullTheme.crimson)
                }
                LabeledContent("Oversight", value: oversightLabel)
                LabeledContent("Therapist Access", value: therapistAccessLabel)
                LabeledContent("iCloud", value: cloud.accountLabel)
                LabeledContent("Connection", value: transportLabel)
                if let message = cloud.shareStatusMessage {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(cloud.lastError == nil ? BullTheme.green : BullTheme.crimson)
                }
                if let lastSync = configuration.lastSyncTs {
                    LabeledContent(
                        "Last Sync",
                        value: Date(timeIntervalSince1970: lastSync / 1_000).formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                }
                if configuration.protectsRiskControls {
                    Text("Changes that reduce protection need therapist approval.")
                        .font(.caption)
                        .foregroundStyle(BullTheme.green)
                }
            }

            Section("Therapist Access") {
                switch configuration.state {
                case .off, .ended:
                    Button(cloud.isSyncing ? "Finishing…" : "Set Up Oversight") {
                        showConsent = true
                    }
                        .buttonStyle(.borderedProminent)
                        .tint(BullTheme.gold)
                        .foregroundStyle(BullTheme.ink)
                        .disabled(cloud.isSyncing)
                case .invitationReady:
                    Button(cloud.isSyncing ? "Preparing…" : invitationButtonTitle) {
                        Task { await cloud.prepareShare(for: store) }
                    }
                    .disabled(cloud.isSyncing)
                    Button("Sync Now") {
                        Task { await cloud.sync(store: store, notifications: notifications) }
                    }
                    .disabled(cloud.isSyncing)
                    Button(cloud.isEndingAccess ? "Ending Access…" : cancelButtonTitle, role: .destructive) {
                        showEndConfirmation = true
                    }
                    .disabled(cloud.isEndingAccess)
                case .active:
                    Button("Manage Access") {
                        Task { await cloud.prepareShare(for: store) }
                    }
                    .disabled(cloud.isSyncing)
                    Button("Sync Now") {
                        Task { await cloud.sync(store: store, notifications: notifications) }
                    }
                    .disabled(cloud.isSyncing)
                    Button(cloud.isEndingAccess ? "Ending Access…" : "End Oversight", role: .destructive) {
                        showEndConfirmation = true
                    }
                    .disabled(cloud.isEndingAccess)
                }
                Button { showTherapistPreview = true } label: {
                    HStack {
                        Text("Preview Therapist View")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                }
                .disabled(cloud.isSyncing || cloud.isEndingAccess)
                Text("Use Apple's sharing screen to invite your therapist or manage access. Pending means the invitation hasn't been accepted yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
              DisclosureGroup("Sharing Details") {
                Text("Shared").font(.subheadline.weight(.semibold))
                Text("Bull shares the latest 90 days plus current Risk Control settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                scopeRow("Urge Fuel", symbol: "calendar.badge.clock")
                scopeRow("Urge State", symbol: "waveform.path.ecg")
                scopeRow("Relapses", symbol: "exclamationmark.arrow.triangle.2.circlepath")
                scopeRow("Risk Zones", symbol: "location.fill")
                scopeRow("Risk Controls", symbol: "lock.shield.fill")
                Text("Zone names and warnings are shared. Exact coordinates stay private.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Not Shared").font(.subheadline.weight(.semibold)).padding(.top, 8)
                Text("Bull Fuel, Bull State, Vigour, sexual health, workouts, HealthKit samples, exact coordinates and free-form notes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
              }
            }

            if !store.data.riskControlChangeRequests.isEmpty {
                Section("Risk Change Reviews") {
                    ForEach(store.data.riskControlChangeRequests.sorted(by: { $0.requestedTs > $1.requestedTs })) { request in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(request.summary).font(.subheadline.weight(.semibold))
                            Text(changeStatus(request.status))
                                .font(.caption)
                                .foregroundStyle(request.status == .pending ? BullTheme.amber : .secondary)
                        }
                    }
                }
            }

            if let error = cloud.lastError ?? configuration.lastTransportError {
                Section("Connection Error") {
                    Text(error).font(.caption).foregroundStyle(BullTheme.crimson)
                }
            }
        }
        .bullFormSurface()
        .navigationTitle("Therapist Oversight")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cloud.refreshAccountStatus() }
        .sheet(isPresented: $showTherapistPreview) {
            TherapistDashboardView(previewProjection: store.therapistProjection())
        }
        .sheet(item: $cloud.preparedShare, onDismiss: {
            cloud.sharingControllerDismissed()
        }) { item in
            TherapistShareSheet(
                item: item,
                onSaved: {
                    cloud.sharingControllerSaved(store: store)
                    feedback.show("Share Options Saved")
                    Task { await cloud.sync(store: store, notifications: notifications) }
                },
                onStopped: { cloud.sharingControllerStopped(store: store) },
                onError: { cloud.sharingControllerFailed($0) }
            )
        }
        .alert("Share Therapist Data?", isPresented: $showConsent) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                Task { await cloud.prepareShare(for: store) }
            }
        } message: {
            Text("Bull shares 90 days of Urge scores, relapses and Risk Zone activity, plus protected Risk Controls. Other Bull data stays private. You can revoke access at any time.")
        }
        .alert(endConfirmationTitle, isPresented: $showEndConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(endConfirmationButtonTitle, role: .destructive) {
                Task { await cloud.stopSharing(store: store) }
            }
        } message: {
            Text(endConfirmationMessage)
        }
    }

    @ViewBuilder
    private func scopeRow(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
    }

    private var oversightLabel: String {
        switch configuration.state {
        case .off: return "Off"
        case .invitationReady: return "Invite Pending"
        case .active: return "Active"
        case .ended: return "Ended"
        }
    }

    private var therapistAccessLabel: String {
        switch configuration.state {
        case .off, .ended: return "Not Invited"
        case .active: return "Active"
        case .invitationReady: return cloud.accessLabel
        }
    }

    private var invitationButtonTitle: String {
        cloud.accessLabel == "Not Invited" ? "Invite Therapist" : "Manage Access"
    }

    private var setupWasNeverConfirmed: Bool {
        configuration.state == .invitationReady && configuration.cloudZoneName == nil
    }

    private var cancelButtonTitle: String {
        setupWasNeverConfirmed ? "Cancel Setup" : "Cancel Oversight"
    }

    private var endConfirmationTitle: String {
        setupWasNeverConfirmed ? "Cancel Therapist Setup?" : "End Therapist Oversight?"
    }

    private var endConfirmationButtonTitle: String {
        setupWasNeverConfirmed ? "Cancel Setup" : "End Access"
    }

    private var endConfirmationMessage: String {
        setupWasNeverConfirmed
            ? "Bull will check for a partially created iCloud share and revoke it before ending setup. Your local history is kept. If iCloud cannot confirm this, you can retry."
            : "Bull will revoke the iCloud share and record the end locally. Risk Controls remain protected if revocation fails."
    }

    private var transportLabel: String {
        switch configuration.transportState {
        case .notConfigured: return "Not Configured"
        case .preparing: return "Preparing"
        case .ready: return "Ready"
        case .syncing: return "Syncing"
        case .error: return "Needs Attention"
        }
    }

    private func changeStatus(_ status: RiskControlChangeStatus) -> String {
        switch status {
        case .pending: return "Awaiting therapist review · current protection remains active"
        case .approved: return "Approved"
        case .rejected: return "Discuss first"
        case .cancelled: return "Cancelled"
        case .applied: return "Approved and applied"
        }
    }
}

struct TherapistDashboardView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var cloud: TherapistCloudService
    @State private var showStop = false
    @Environment(\.dismiss) private var dismiss
    var previewProjection: TherapistProjection? = nil

    private var isPreview: Bool { previewProjection != nil }
    private var projection: TherapistProjection? { previewProjection ?? store.data.therapistProjectionCache }
    private var warningEvents: [TherapistOversightEvent] {
        // Preview reads only the same scoped events sent to CloudKit.
        let events = isPreview ? store.data.therapistOutboxEvents : store.data.therapistInboxEvents
        return events.filter(\.requiresAttention).sorted { $0.ts > $1.ts }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let projection {
                    List {
                        Section {
                            if isPreview {
                                Label("Preview · Your Shared Data", systemImage: "eye")
                                Text("Read-only preview. This does not test the iCloud connection.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            LabeledContent("Updated", value: Date(timeIntervalSince1970: projection.generatedTs / 1_000)
                                .formatted(date: .abbreviated, time: .shortened))
                            Text(isPreview ? "Shown from this phone's current data." : "A snapshot from the client's last upload. Pull to refresh.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        monitoringSection(projection.monitoring)
                        reviewSection(projection.pendingRiskChanges)
                        currentRiskSection(projection)
                        urgeSection(projection)
                        relapseSection(projection.relapses)
                        recentAlertsSection
                        if !isPreview, let error = cloud.lastError ?? store.data.therapistOversight.lastTransportError {
                            Section("Connection Error") {
                                Text(error).font(.caption).foregroundStyle(BullTheme.crimson)
                            }
                        }
                        Section {
                            Text("This view is limited to urge, relapse and Risk Zone oversight. Bull and Vigour data are not available here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .refreshable {
                        if !isPreview { await cloud.sync(store: store, notifications: notifications) }
                    }
                } else {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "Waiting for Bull Data",
                            systemImage: "icloud.and.arrow.down",
                            description: Text("Keep Bull open briefly after accepting the invitation, then refresh.")
                        )
                        Button(cloud.isSyncing ? "Syncing…" : "Retry Sync") {
                            Task { await cloud.sync(store: store, notifications: notifications) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(cloud.isSyncing)
                        if let error = cloud.lastError ?? store.data.therapistOversight.lastTransportError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(BullTheme.crimson)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BullTheme.ivory)
            .navigationTitle("Client Oversight")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isPreview {
                        Button("Done") { dismiss() }
                    } else {
                        Menu {
                            Button("Sync Now") {
                                Task { await cloud.sync(store: store, notifications: notifications) }
                            }
                            .disabled(cloud.isSyncing)
                            Button("Leave Oversight", role: .destructive) { showStop = true }
                                .disabled(cloud.isSyncing)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .accessibilityLabel("Oversight Actions")
                        }
                    }
                }
            }
        }
        .task { if !isPreview { await cloud.sync(store: store, notifications: notifications) } }
        .alert("Leave Therapist Oversight?", isPresented: $showStop) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                Task { _ = await cloud.stopReceiving(store: store) }
            }
        } message: {
            Text("Bull will leave the private iCloud share and remove this client view. Nothing is removed if iCloud cannot confirm the change.")
        }
    }

    @ViewBuilder
    private func monitoringSection(_ status: TherapistMonitoringStatus) -> some View {
        Section("Monitoring") {
            LabeledContent("Location", value: status.locationStatus)
            LabeledContent("Notifications", value: status.notificationsAllowed ? "Allowed" : "Unavailable")
            LabeledContent("Time Sensitive", value: status.timeSensitiveEnabled ? "Available" : "Unavailable")
            LabeledContent("Zones", value: "\(status.monitoredZoneCount) of \(status.expectedZoneCount)")
            if status.failedZoneCount > 0 {
                Label("\(status.failedZoneCount) zone monitoring failure(s)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(BullTheme.crimson)
            }
        }
    }

    @ViewBuilder
    private func reviewSection(_ changes: [TherapistRiskChangeRecord]) -> some View {
        let pending = changes.filter { $0.status == .pending }
        if !pending.isEmpty {
            Section("Review Risk Changes") {
                ForEach(pending) { change in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(change.summary).font(.headline)
                        if let zone = change.currentZone {
                            Text("Current: \(zoneSummary(zone))").font(.caption).foregroundStyle(.secondary)
                        }
                        if let zone = change.proposedZone {
                            Text("Proposed: \(zoneSummary(zone))").font(.caption)
                        } else if change.kind == .deleteZone {
                            Text("Proposed: Remove This Zone").font(.caption)
                        }
                        if let before = change.currentIntegerValue, let after = change.proposedIntegerValue {
                            Text("Alert Repeat: \(before) → \(after) min").font(.caption)
                        }
                        if let before = change.currentBooleanValue, let after = change.proposedBooleanValue {
                            Text("Time Sensitive: \(before ? "On" : "Off") → \(after ? "On" : "Off")").font(.caption)
                        }
                        HStack {
                            Button("Approve") {
                                Task { await cloud.reviewRiskChange(id: change.id, approve: true, store: store) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(BullTheme.green)
                            .accessibilityLabel("Approve \(change.summary)")
                            .disabled(isPreview || cloud.isSyncing)
                            Button("Discuss") {
                                Task { await cloud.reviewRiskChange(id: change.id, approve: false, store: store) }
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Discuss \(change.summary)")
                            .disabled(isPreview || cloud.isSyncing)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        let reviewed = changes.filter { $0.status != .pending }
        if !reviewed.isEmpty {
            Section("Reviewed Changes") {
                ForEach(reviewed) { change in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(change.summary).font(.subheadline.weight(.semibold))
                        Text(reviewStatus(change.status)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func currentRiskSection(_ projection: TherapistProjection) -> some View {
        Section("Risk Zones") {
            LabeledContent("Alert Repeat", value: "\(projection.zoneAlertRepeatMinutes) min")
            LabeledContent("Time Sensitive", value: projection.timeSensitiveAlerts ? "On" : "Off")
            ForEach(projection.riskZones) { zone in
                let lastEvent = latestZoneEvent(zoneID: zone.id, events: projection.zoneEvents)
                let inside = zone.enabled && lastEvent?.kind == .entered
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(zone.name).font(.headline)
                        Spacer()
                        if inside {
                            Text("Last Report: Inside")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(BullTheme.crimson)
                        }
                    }
                    Text(zoneSummary(zone)).font(.caption).foregroundStyle(.secondary)
                    if let lastEvent {
                        Text(Date(timeIntervalSince1970: lastEvent.ts / 1_000), format: .dateTime)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if zone.resolutionMode == .exitRequired {
                        Text("Leaving Required")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BullTheme.crimson)
                    } else if let instruction = zone.safeguardInstruction {
                        Text("Safeguard: \(instruction)").font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func urgeSection(_ projection: TherapistProjection) -> some View {
        Section("Urge") {
            if let latest = projection.urgeScores.max(by: { $0.dayKey < $1.dayKey }) {
                LabeledContent("Urge Fuel", value: score(latest.urgeRoutine))
                LabeledContent("Urge State", value: score(latest.urgeState))
                Text(latest.dayKey).font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No Urge score yet").foregroundStyle(.secondary)
            }
            ForEach(projection.urgeObservations.prefix(8)) { observation in
                HStack {
                    Text(observation.dayKey)
                    Spacer()
                    Text("\(observation.intensity) of 10")
                        .font(.system(.subheadline, design: .monospaced))
                }
            }
            NavigationLink("View Urge History") {
                List {
                    Section("Daily Scores") {
                        ForEach(projection.urgeScores.sorted { $0.dayKey > $1.dayKey }) { day in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.dayKey).font(.headline)
                                Text("Fuel \(score(day.urgeRoutine)) · State \(score(day.urgeState))")
                                if !day.isFinal { Text("Awaiting Final Entry").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                    Section("Recorded Urges") {
                        ForEach(projection.urgeObservations.sorted { $0.ts > $1.ts }) { observation in
                            LabeledContent(observation.dayKey, value: "\(observation.intensity) of 10")
                        }
                    }
                }
                .navigationTitle("Urge History")
            }
        }
    }

    @ViewBuilder
    private func relapseSection(_ relapses: [TherapistRelapseRecord]) -> some View {
        Section("Relapses") {
            if relapses.isEmpty {
                Text("No counted relapse in the shared period").foregroundStyle(.secondary)
            }
            ForEach(relapses.prefix(12)) { relapse in
                VStack(alignment: .leading, spacing: 3) {
                    Text(relapse.dayKey).font(.headline)
                    Text(relapse.components.map(\.label).joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if relapses.count > 12 {
                NavigationLink("View All \(relapses.count) Relapses") {
                    List(relapses.sorted { $0.loggedTs > $1.loggedTs }) { relapse in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(relapse.dayKey).font(.headline)
                            Text(relapse.components.map(\.label).joined(separator: ", ")).font(.caption)
                        }
                    }
                    .navigationTitle("Relapse History")
                }
            }
        }
    }

    @ViewBuilder
    private var recentAlertsSection: some View {
        Section("Recent Warnings") {
            let events = warningEvents.prefix(12)
            if events.isEmpty { Text("No warning received").foregroundStyle(.secondary) }
            ForEach(Array(events)) { event in
                VStack(alignment: .leading, spacing: 3) {
                    Text(therapistNotificationCopy(for: event).title).font(.headline)
                    Text(event.message).font(.caption)
                    Text(event.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
                }
            }
            if warningEvents.count > 12 {
                NavigationLink("View All Warnings") {
                    List(warningEvents) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(therapistNotificationCopy(for: event).title).font(.headline)
                            Text(event.message).font(.caption)
                            Text(event.date, format: .dateTime).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("Warning History")
                }
            }
        }
    }

    private func latestZoneEvent(
        zoneID: String,
        events: [TherapistZoneEvent]
    ) -> TherapistZoneEvent? {
        events.filter { $0.zoneID == zoneID }.max { $0.ts < $1.ts }
    }

    private func score(_ value: Double?) -> String {
        guard let value, value.isFinite, (0...100).contains(value) else { return "Not Recorded" }
        return "\(Int(value.rounded()))"
    }

    private func reviewStatus(_ status: RiskControlChangeStatus) -> String {
        switch status {
        case .pending: return "Awaiting Review"
        case .approved: return "Approved · Waiting for Client Sync"
        case .rejected: return "Discuss with Client"
        case .applied: return "Applied on Client's Phone"
        case .cancelled: return "Cancelled or Replaced"
        }
    }

    private func zoneSummary(_ zone: TherapistRiskZoneRecord) -> String {
        let fixedHours = zone.startMinute == zone.endMinute
            ? "all day"
            : String(
                format: "%02d:%02d–%02d:%02d",
                zone.startMinute / 60,
                zone.startMinute % 60,
                zone.endMinute / 60,
                zone.endMinute % 60
            )
        let schedule = zone.scheduleMode == .sleepAnchored
            ? "Layla: \(zone.minutesAllowedAfterFinalWake)m after wake, \(zone.minutesAllowedBeforeBed)m before bed; fallback \(fixedHours)"
            : fixedHours
        let days = zone.activeDays.isEmpty
            ? "daily"
            : zone.activeDays.filter { (0...6).contains($0) }.sorted().map { ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][$0] }
                .joined(separator: ", ")
        let unexpected = zone.scheduleMode == .sleepAnchored
            ? " · unexpected wake \(zone.activateWhenUnexpectedlyAwake ? "on" : "off")"
            : ""
        let radius = zone.radiusMetres.isFinite && (0...1_000_000).contains(zone.radiusMetres)
            ? "\(Int(zone.radiusMetres)) m" : "Unknown Radius"
        return "\(zone.enabled ? "Active" : "Paused") · \(zone.riskLevel.label) · \(radius) · \(days) · \(schedule)\(unexpected)"
    }
}
