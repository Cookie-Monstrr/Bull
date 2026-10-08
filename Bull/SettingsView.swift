import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var privacy: PrivacyManager
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var therapistCloud: TherapistCloudService
    @EnvironmentObject private var feedback: BullFeedbackCenter

    @State private var editLapsePlan = false
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument = BullBackupDocument(data: Data())
    @State private var exportFilename = "bull-backup"
    @State private var showFullExportWarning = false
    @State private var showReset = false
    @State private var showRestorePreImport = false
    @State private var statusMessage: String?
    @State private var isBackfillingHealth = false
    @State private var privacyEnableAttemptID: UUID?

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "3.4"
    }
    private var appBuild: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "54"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Apple Health") {
                    Button(health.authorizationRequestCompleted ? "Health Access Requested" : "Request Health Access") {
                        Task {
                            let ok = await health.requestAuthorization()
                            statusMessage = ok ? "Health access request completed." : (health.lastError ?? "Health access failed.")
                        }
                    }
                    Button(isBackfillingHealth ? "Syncing 90 Days…" : "Sync 90 Days") {
                        Task { await backfillHealth() }
                    }
                    .disabled(isBackfillingHealth)
                    if isBackfillingHealth { ProgressView() }
                }

                Section("Layla Sleep Schedule") {
                    Text(store.laylaScheduleBridgeStatus.message)
                        .font(.caption)
                        .foregroundStyle(store.laylaScheduleBridgeStatus.usesCurrentSchedule
                                         ? BullTheme.green : BullTheme.amber)
                    Button("Refresh Layla Connection") {
                        let accepted = store.refreshLaylaSleepScheduleFromSharedGroup()
                        statusMessage = accepted
                            ? "Latest Layla schedule connected."
                            : store.laylaScheduleBridgeStatus.message
                    }
                    Text("Bull uses current Layla wake and bedtime timing for sleep-anchored Risk Zones and reminder timing. Apple Health remains the source for completed sleep.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Notifications") {
                    NavigationLink("Daily Input Reminders") {
                        DailyInputReminderSettingsView()
                    }
                    Text("Bull nudges one unfinished input at a time and opens the correct page.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Lapse Support") {
                    Button("Edit Post-Lapse Plan") { editLapsePlan = true }
                }

                Section("Therapist") {
                    NavigationLink("Therapist Oversight") {
                        TherapistOversightSettingsView()
                    }
                    Text("Share Urge scores, relapses and Risk Zones with your therapist.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    Toggle(
                        "Require Device Unlock",
                        isOn: Binding(
                            get: { preferences.biometricLockEnabled },
                            set: { enabled in
                                if enabled {
                                    let attemptID = UUID()
                                    privacyEnableAttemptID = attemptID
                                    Task {
                                        privacy.isUnlocked = false
                                        await privacy.unlock()
                                        guard privacyEnableAttemptID == attemptID else { return }
                                        privacyEnableAttemptID = nil
                                        if privacy.isUnlocked {
                                            preferences.biometricLockEnabled = true
                                            statusMessage = "Bull privacy lock enabled."
                                        } else {
                                            preferences.biometricLockEnabled = false
                                            statusMessage = privacy.lastError ??
                                                "Device authentication must succeed before Bull can enable its privacy lock."
                                        }
                                    }
                                } else {
                                    privacyEnableAttemptID = nil
                                    preferences.biometricLockEnabled = false
                                    privacy.isUnlocked = true
                                }
                            }
                        )
                    )
                        .tint(BullTheme.gold)
                    Text("Therapist Oversight excludes your full logs and exact coordinates.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Data & Backup") {
                    Button("Export Bull Backup") {
                        showFullExportWarning = true
                    }
                    Button("Export Redacted Trends") { prepareRedactedExport() }
                    Text("Trends only. Notes, locations and individual entries stay private.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Import Backup") { showImporter = true }
                        .disabled(store.data.therapistOversight.protectsRiskControls)
                    if store.hasPreImportBackup {
                        Button("Undo Last Import") { showRestorePreImport = true }
                            .disabled(store.data.therapistOversight.protectsRiskControls)
                    }
                    if store.data.therapistOversight.protectsRiskControls {
                        Text("Full import and restore are locked during Therapist Oversight so an older backup cannot replace protected Risk Controls.")
                            .font(.caption)
                            .foregroundStyle(BullTheme.amber)
                    }
                    if let report = store.lastImportReport {
                        Text("Last Import: \(report.daysImported) days · \(report.urgesImported) urges · \(report.relapsesImported) lapses" + (report.hadSkips ? " · malformed entries skipped" : ""))
                            .font(.caption).foregroundStyle(report.hadSkips ? BullTheme.amber : BullTheme.green)
                    }
                    Button("Reset All Data", role: .destructive) { showReset = true }
                }

                Section("About") {
                    LabeledContent("App", value: "Bull \(appVersion)")
                    LabeledContent("Build", value: appBuild)
                    Text("Your older scores and entries remain safely preserved.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let statusMessage { Section { Text(statusMessage).font(.caption).foregroundStyle(.secondary) } }
                if let error = store.lastError ?? preferences.lastSaveError ?? notifications.lastError {
                    Section("Last Error") { Text(error).font(.caption).foregroundStyle(BullTheme.crimson) }
                }
            }
            .bullFormSurface()
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $editLapsePlan) {
            LongTextEditorView(title: "Post-Lapse Plan", text: store.data.settings.lapsePlan) {
                text in store.updateSettings { $0.lapsePlan = text }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false, onCompletion: importFile)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result { statusMessage = error.localizedDescription }
        }
        .alert("Reset Bull?", isPresented: $showReset) {
            Button("Cancel", role: .cancel) { }
            Button("Wipe Everything", role: .destructive) {
                Task {
                    guard await therapistCloud.stopSharing(store: store) else {
                        statusMessage = "Bull did not wipe local data because therapist access could not be revoked. Try again when iCloud is available."
                        return
                    }
                    notifications.disableAllNotifications()
                    store.resetAll()
                    preferences.reset()
                    privacy.isUnlocked = true
                }
            }
        } message: {
            Text("This revokes therapist sharing, then deletes local logs, settings, plans, zone history and recovery copies. Export first if you may need them.")
        }
        .alert("Export Complete Private Backup?", isPresented: $showFullExportWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Export") { prepareFullExport() }
        } message: {
            Text("This unencrypted JSON includes private notes, sexual-health observations, exact Risk Zone coordinates, visit history and therapist-access audit records. Anyone with the file can read it. Use the redacted trends export for review unless you specifically need a recovery backup.")
        }
        .alert("Undo last import?", isPresented: $showRestorePreImport) {
            Button("Cancel", role: .cancel) { }
            Button("Restore") {
                statusMessage = store.restorePreImportBackup()
                    ? "Restored the pre-import data."
                    : (store.lastError ?? "Restore failed.")
            }
        } message: { Text("This replaces the current data with the safety copy made before the last import.") }
        .task {
            // General score alerts belonged to the retired v2.9 Risk model.
            if preferences.riskAlertsEnabled { preferences.riskAlertsEnabled = false }
            notifications.disableRiskAlerts()
            _ = store.cancelPendingGeneralRiskAlerts()
        }
    }

    private func backfillHealth() async {
        if !health.authorizationRequestCompleted, !(await health.requestAuthorization()) {
            statusMessage = health.lastError ?? "The Health access request could not be completed."
            return
        }
        isBackfillingHealth = true
        let imports = await health.importRecentNights(days: 90)
        let changed = store.applyHealthBackfill(imports)
        isBackfillingHealth = false
        statusMessage = imports.isEmpty
            ? "No matching Sleep or workout history was found."
            : "Health checked · \(changed) day\(changed == 1 ? "" : "s") updated."
    }

    private func prepareFullExport() {
        guard let raw = store.exportBackup() else { return }
        exportDocument = BullBackupDocument(data: raw)
        exportFilename = "bull-backup-\(BullDates.key(for: Date()))"
        showExporter = true
    }

    private func prepareRedactedExport() {
        guard let raw = store.exportRedactedTrends() else { return }
        exportDocument = BullBackupDocument(data: raw)
        exportFilename = "bull-redacted-trends-\(BullDates.key(for: Date()))"
        showExporter = true
    }

    private func importFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): statusMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                   size > BackupImporter.maximumBackupBytes {
                    statusMessage = BackupImportError.tooLarge(
                        maximumBytes: BackupImporter.maximumBackupBytes
                    ).localizedDescription
                    return
                }
                let raw = try Data(contentsOf: url)
                statusMessage = store.importBackup(raw)
                    ? "Backup imported. A one-step safety copy is available."
                    : (store.lastError ?? "Import failed.")
            } catch { statusMessage = error.localizedDescription }
        }
    }
}

struct DailyInputReminderSettingsView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var notifications: NotificationService
    @State private var statusMessage: String?

    private var todayKey: String { BullDates.key(for: Date()) }
    private var pausedToday: Bool { preferences.dailyInputReminderPausedDayKey == todayKey }
    private var nextItem: BullDailyInputQueueItem? {
        BullDailyInputQueue.next(store: store, preferences: preferences)
    }
    private var settingsFingerprint: String {
        [
            preferences.dailyInputRemindersEnabled.description,
            String(preferences.dailyInputReminderIntervalMinutes),
            String(preferences.dailyInputReminderStartHour),
            String(preferences.dailyInputReminderEndHour),
            preferences.dailyInputReminderPausedDayKey ?? "",
            preferences.dailyInputStressEnabled.description,
            preferences.dailyInputUrgeEnabled.description,
            preferences.dailyInputBullStateEnabled.description,
            preferences.dailyInputNutritionEnabled.description,
            preferences.dailyInputSleepEnabled.description,
            preferences.dailyInputExerciseEnabled.description
        ].joined(separator: "|")
    }

    var body: some View {
        Form {
            Section("Daily Input Queue") {
                Toggle("Reminders", isOn: Binding(
                    get: { preferences.dailyInputRemindersEnabled },
                    set: { enabled in
                        preferences.dailyInputRemindersEnabled = enabled
                        if enabled {
                            preferences.dailyInputReminderPausedDayKey = nil
                            Task {
                                let allowed = await notifications.requestAuthorization()
                                statusMessage = allowed ? "Reminders enabled." :
                                    (notifications.lastError ?? "Notifications are not allowed for Bull.")
                            }
                        } else {
                            notifications.clearDailyInputReminders()
                        }
                    }
                ))
                .tint(BullTheme.gold)
                LabeledContent(
                    "Next Input",
                    value: pausedToday ? "Paused Today" : (nextItem?.kind.title ?? "Caught Up")
                )
                Text("Bull repeats only the next unfinished input. Saving it advances the queue.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Timing") {
                Picker("Repeat", selection: $preferences.dailyInputReminderIntervalMinutes) {
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("1 hr").tag(60)
                    Text("2 hr").tag(120)
                }
                Stepper(
                    "Starts: \(hourLabel(preferences.dailyInputReminderStartHour))",
                    value: Binding(
                        get: { preferences.dailyInputReminderStartHour },
                        set: { preferences.dailyInputReminderStartHour = min($0, preferences.dailyInputReminderEndHour - 1) }
                    ),
                    in: 0...21
                )
                Stepper(
                    "Stops: \(hourLabel(preferences.dailyInputReminderEndHour))",
                    value: Binding(
                        get: { preferences.dailyInputReminderEndHour },
                        set: { preferences.dailyInputReminderEndHour = max($0, preferences.dailyInputReminderStartHour + 1) }
                    ),
                    in: 1...23
                )
                Button(pausedToday ? "Resume Today" : "Pause for Today") {
                    preferences.dailyInputReminderPausedDayKey = pausedToday ? nil : todayKey
                }
            }

            Section {
                DisclosureGroup("Inputs") {
                    Toggle("Sleep", isOn: $preferences.dailyInputSleepEnabled)
                    Toggle("Stress", isOn: $preferences.dailyInputStressEnabled)
                    Toggle("Urge State", isOn: $preferences.dailyInputUrgeEnabled)
                    Toggle("Morning Erection & Natural Desire", isOn: $preferences.dailyInputBullStateEnabled)
                    Toggle("Nutrition & Fasting", isOn: $preferences.dailyInputNutritionEnabled)
                    Toggle("Planned Exercise", isOn: $preferences.dailyInputExerciseEnabled)
                    Text("Exercise reminders stay off on fasting rest days. Bull never sends a routine reminder to log a lapse.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Check") {
                Button("Send Test Notification") {
                    Task {
                        let sent = await notifications.scheduleDailyInputTest(item: nextItem)
                        statusMessage = sent ? "Test notification scheduled." :
                            (notifications.lastError ?? "Test notification failed.")
                    }
                }
                if let statusMessage {
                    Text(statusMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .bullFormSurface()
        .navigationTitle("Input Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshSchedule() }
        .onChange(of: settingsFingerprint) { _, _ in Task { await refreshSchedule() } }
        .onChange(of: store.revision) { _, _ in Task { await refreshSchedule() } }
    }

    private func refreshSchedule() async {
        _ = await notifications.reconcileDailyInputReminder(
            item: BullDailyInputQueue.next(store: store, preferences: preferences),
            intervalMinutes: preferences.dailyInputReminderIntervalMinutes,
            endHour: preferences.dailyInputReminderEndHour
        )
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.calendar = BullDates.calendar
        components.hour = hour
        return components.date?.formatted(date: .omitted, time: .shortened)
            ?? String(format: "%02d:00", hour)
    }
}

struct StressPlanSettingsView: View {
    @EnvironmentObject private var store: BullStore
    @Environment(\.dismiss) private var dismiss
    @State private var editorActivity: StressActivityDefinition?

    private var activeActivities: [StressActivityDefinition] {
        store.data.stressActivities.filter { !$0.archived }
    }

    private var removedActivities: [StressActivityDefinition] {
        store.data.stressActivities.filter(\.archived)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose your stress-relief activities. Logging an activity alone earns no points.")
                        .font(.subheadline)
                        .foregroundStyle(BullTheme.secondary)

                    ForEach(activeActivities) { activity in
                        BullCard {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(activity.name)
                                        .font(.headline)
                                    Text("Available When Needed")
                                        .font(.caption)
                                        .foregroundStyle(BullTheme.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: activityEnabledBinding(activity))
                                    .labelsHidden()
                                    .tint(BullTheme.gold)
                                Menu {
                                    Button {
                                        editorActivity = currentActivity(activity)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        archive(activity)
                                    } label: {
                                        Label("Remove", systemImage: "archivebox")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title3)
                                        .foregroundStyle(BullTheme.goldDark)
                                        .frame(width: 44, height: 44)
                                }
                            }
                        }
                    }

                    Button {
                        editorActivity = StressActivityDefinition(
                            id: "stress.custom.\(UUID().uuidString)",
                            name: "",
                            kind: .custom
                        )
                    } label: {
                        Label("Add Activity", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BullTheme.gold)
                    .foregroundStyle(BullTheme.ink)

                    if !removedActivities.isEmpty {
                        BullCard {
                            Text("Removed Activities")
                                .font(.headline)
                            ForEach(removedActivities) { activity in
                                HStack {
                                    Text(activity.name)
                                    Spacer()
                                    Button("Restore") { restore(activity) }
                                        .buttonStyle(.bordered)
                                        .tint(BullTheme.goldDark)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(BullTheme.ivory.ignoresSafeArea())
            .navigationTitle("Stress Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .sheet(item: $editorActivity) { activity in
            StressActivityEditorView(activity: activity) { edited in
                store.saveStressActivity(edited)
            }
        }
    }

    private func activityEnabledBinding(_ activity: StressActivityDefinition) -> Binding<Bool> {
        Binding(get: {
            store.data.stressActivities.first(where: { $0.id == activity.id })?.enabled ?? false
        }, set: { value in
            var edited = currentActivity(activity); edited.enabled = value; store.saveStressActivity(edited)
        })
    }

    private func currentActivity(_ activity: StressActivityDefinition) -> StressActivityDefinition {
        store.data.stressActivities.first(where: { $0.id == activity.id }) ?? activity
    }

    private func archive(_ activity: StressActivityDefinition) {
        var edited = currentActivity(activity)
        edited.archived = true
        edited.enabled = false
        store.saveStressActivity(edited)
    }

    private func restore(_ activity: StressActivityDefinition) {
        var edited = currentActivity(activity)
        edited.archived = false
        edited.enabled = true
        store.saveStressActivity(edited)
    }

}

private struct StressActivityEditorView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    let activity: StressActivityDefinition
    let onSave: (StressActivityDefinition) -> Void
    @State private var name: String
    @State private var confirmingDiscard = false

    init(activity: StressActivityDefinition, onSave: @escaping (StressActivityDefinition) -> Void) {
        self.activity = activity
        self.onSave = onSave
        _name = State(initialValue: activity.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Activity Name", text: $name)
                }
            }
            .scrollContentBackground(.hidden)
            .background(BullTheme.ivory)
            .navigationTitle(activity.name.isEmpty ? "Add Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { if name != activity.name { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var edited = activity
                        edited.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        edited.weeklyTarget = 0
                        edited.archived = false
                        if feedback.save(store, message: "Activity Saved", change: { onSave(edited) }) { dismiss() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .bullFormSurface()
        .bullDraftGuard(isDirty: name != activity.name, confirming: $confirmingDiscard) { dismiss() }
    }
}

private struct LongTextEditorView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onSave: (String) -> Void
    @State private var text: String
    let originalText: String
    @State private var confirmingDiscard = false

    init(title: String, text: String, onSave: @escaping (String) -> Void) {
        self.title = title; self.onSave = onSave; _text = State(initialValue: text)
        originalText = text
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding().background(BullTheme.ivory)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { if text != originalText { confirmingDiscard = true } else { dismiss() } }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            if feedback.save(store, change: { onSave(text) }) { dismiss() }
                        }
                    }
                }
        }
        .bullFormSurface()
        .bullDraftGuard(isDirty: text != originalText, confirming: $confirmingDiscard) { dismiss() }
    }
}
