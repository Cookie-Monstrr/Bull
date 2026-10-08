import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var privacy: PrivacyManager
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var zones: HighRiskZoneService
    @EnvironmentObject private var therapistCloud: TherapistCloudService
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var activeAlertRoute: AlertRoute?
    @State private var activeInputRoute: BullEntryRoute?
    @State private var showPriorities = false
    @State private var pendingPrioritiesLink = false

    var body: some View {
        presentationLayer
    }

    @ViewBuilder
    private var appShell: some View {
        ZStack {
            if store.data.therapistOversight.role == .therapist {
                if store.data.therapistOversight.state == .ended {
                    TherapistAccessEndedView()
                } else {
                    TherapistDashboardView()
                }
            } else {
                TabView(selection: $tab) {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "flame.fill") }
                        .tag(0)
                    PatternsView()
                        .tabItem { Label("Stats", systemImage: "chart.bar") }
                        .tag(1)
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(2)
                }
                .tint(BullTheme.gold)
            }

            if privacy.isShielded {
                PrivacyShieldView().zIndex(10)
            } else if preferences.biometricLockEnabled && !privacy.isUnlocked {
                ZStack {
                    PrivacyShieldView()
                    VStack {
                        Spacer()
                        Button("Unlock Bull") { Task { await privacy.unlock() } }
                            .buttonStyle(.borderedProminent)
                            .tint(BullTheme.gold)
                            .foregroundStyle(BullTheme.ink)
                            .padding(.bottom, 60)
                    }
                }
                .zIndex(9)
            }
        }
    }

    private var lifecycleLayer: some View {
        appShell
        .task {
            _ = store.refreshLaylaSleepScheduleFromSharedGroup()
            if preferences.riskAlertsEnabled { preferences.riskAlertsEnabled = false }
            notifications.disableRiskAlerts()
            notifications.retireLegacyReminders()
            // Fixed-time Stress reminders are retired until Bull has a trustworthy
            // wake/bedtime source. Do not leave hidden scheduled reminders behind after
            // their Settings controls are removed.
            if preferences.remindersEnabled { preferences.remindersEnabled = false }
            notifications.disable()
            await notifications.retireLegacyCountermoveFollowUps()
            _ = store.cancelPendingGeneralRiskAlerts()
            configureZones()
            handleNotificationAction(notifications.actionRequest)
            if let route = notifications.requestedRoute, store.data.therapistOversight.role == .owner {
                handleRequestedRoute(route)
                notifications.consumeRoute()
            }
            await reconcileZoneStateAndEvaluate()
            await reconcileDailyInputReminders()
            updateTherapistMonitoringStatus()
            await therapistCloud.sync(store: store, notifications: notifications)
            // A Layla observer/extension can update the App Group while Bull remains
            // resident. Check that narrow file every minute; keep CloudKit at 15 minutes.
            var minutesSinceCloudSync = 0
            while !Task.isCancelled {
                try? await Task<Never, Never>.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                _ = store.refreshLaylaSleepScheduleFromSharedGroup()
                await evaluateZoneWindows()
                if store.data.therapistOversight.role == .owner {
                    BullWidgetSnapshotBridge.publish(
                        store.fourScoreSnapshot(on: Date()),
                        priorities: store.prioritiesPayload(),
                        charts: store.widgetChartsSnapshot()
                    )
                }
                minutesSinceCloudSync += 1
                if minutesSinceCloudSync >= 15 {
                    await therapistCloud.sync(store: store, notifications: notifications)
                    minutesSinceCloudSync = 0
                }
            }
        }
        .onChange(of: store.revision) { _, _ in
            configureZones()
            updateTherapistMonitoringStatus()
            Task {
                await evaluateZoneWindows()
                await reconcileDailyInputReminders()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                configureZones()
                await reconcileZoneStateAndEvaluate()
                await reconcileDailyInputReminders()
                updateTherapistMonitoringStatus()
            }
        }
        .onChange(of: notifications.requestedRoute) { _, route in
            guard let route else { return }
            guard store.data.therapistOversight.role == .owner else {
                notifications.consumeRoute()
                return
            }
            handleRequestedRoute(route)
            notifications.consumeRoute()
        }
        .onChange(of: dailyReminderSettingsFingerprint) { _, _ in
            Task { await reconcileDailyInputReminders() }
        }
    }

    private var monitoringLayer: some View {
        lifecycleLayer
        .onChange(of: notifications.actionRequest) { _, request in
            handleNotificationAction(request)
        }
        .onChange(of: notifications.foregroundDeliveredEventID) { _, eventID in
            guard let eventID else { return }
            store.updateRiskAlertDelivery(eventID: eventID, state: .observedForeground)
            notifications.consumeForegroundDelivery()
        }
        .onChange(of: zones.authorizationLabel) { _, _ in monitoringInputsChanged() }
        .onChange(of: zones.monitoredZoneIDs) { _, _ in monitoringInputsChanged() }
        .onChange(of: zones.monitoringFailedZoneIDs) { _, _ in monitoringInputsChanged() }
        .onChange(of: notifications.authorizationStatus) { _, _ in monitoringInputsChanged() }
        .onChange(of: notifications.timeSensitiveSetting) { _, _ in monitoringInputsChanged() }
    }

    private var cloudEventLayer: some View {
        monitoringLayer
        .onReceive(NotificationCenter.default.publisher(for: .bullTherapistOutboxChanged)) { _ in
            Task { await therapistCloud.sync(store: store, notifications: notifications) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bullCloudKitChanged)) { notification in
            Task {
                let changed = await therapistCloud.sync(
                    store: store,
                    notifications: notifications
                )
                (notification.object as? CloudKitBackgroundFetchCompletion)?
                    .finish(changed ? .newData : .failed)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bullCloudShareAccepted)) { _ in
            Task {
                await therapistCloud.acceptPendingShare(store: store, notifications: notifications)
            }
        }
    }

    private var presentationLayer: some View {
        cloudEventLayer
        .sheet(item: $activeAlertRoute) { route in RiskActionDestinationView(route: route) }
        .sheet(item: $activeInputRoute) { route in BullEntryDestination(route: route) }
        .sheet(isPresented: $showPriorities) { TodayPrioritiesView() }
        .onOpenURL { url in
            guard url.scheme == "bull", store.data.therapistOversight.role == .owner else { return }
            if url.host == "stats" {
                tab = 1
            } else if url.host == "priorities" {
                pendingPrioritiesLink = true
                openPrioritiesIfUnlocked()
            }
        }
        .onChange(of: privacy.isUnlocked) { _, _ in openPrioritiesIfUnlocked() }
        .onChange(of: privacy.isShielded) { _, _ in openPrioritiesIfUnlocked() }
        .onChange(of: store.data.therapistOversight.role) { _, role in
            feedback.clear()
            if role == .therapist {
                showPriorities = false
                pendingPrioritiesLink = false
                activeAlertRoute = nil
                activeInputRoute = nil
                notifications.consumeRoute()
                for zone in store.data.highRiskZones { notifications.cancelZoneAlert(zoneID: zone.id) }
            }
            configureZones()
        }
    }

    private var dailyReminderSettingsFingerprint: String {
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

    private func handleRequestedRoute(_ route: String) {
        tab = 0
        if let input = BullDailyInputKind.parse(route: route),
           let date = BullDates.date(from: input.dayKey) {
            store.selectedDate = date
            activeInputRoute = BullEntryRoute(kind: input.kind.entryKind, date: date)
        } else {
            activeAlertRoute = AlertRoute(value: route)
        }
    }

    private func reconcileDailyInputReminders() async {
        guard store.data.therapistOversight.role == .owner else {
            notifications.clearDailyInputReminders()
            return
        }
        _ = await notifications.reconcileDailyInputReminder(
            item: BullDailyInputQueue.next(store: store, preferences: preferences),
            intervalMinutes: preferences.dailyInputReminderIntervalMinutes,
            endHour: preferences.dailyInputReminderEndHour
        )
    }

    private func openPrioritiesIfUnlocked() {
        guard pendingPrioritiesLink, !privacy.isShielded,
              !preferences.biometricLockEnabled || privacy.isUnlocked,
              store.data.therapistOversight.role == .owner else { return }
        pendingPrioritiesLink = false
        store.selectedDate = Date()
        tab = 0
        showPriorities = true
    }

    private func configureZones() {
        guard store.data.therapistOversight.role == .owner else {
            zones.configure(zones: []) { _, _ in }
            return
        }
        for zoneID in store.consumeZoneNotificationReconciliationIDs() {
            notifications.cancelZoneAlert(zoneID: zoneID)
            store.cancelPendingZoneAlerts(zoneID: zoneID)
        }
        zones.configure(zones: store.data.highRiskZones) { zoneID, kind in
            guard store.data.therapistOversight.role == .owner else { return }
            store.recordZoneEvent(zoneID: zoneID, kind: kind)
            guard let zone = store.data.highRiskZones.first(where: { $0.id == zoneID }) else { return }
            if kind == .exited {
                notifications.cancelZoneAlert(zoneID: zoneID)
                store.cancelPendingZoneAlerts(zoneID: zoneID)
                return
            }
            Task {
                if store.isZoneActive(zone, at: Date()) {
                    await sendZoneAlert(zone: zone, source: .riskZoneEntry, fireDate: Date())
                } else if let boundary = store.nextZoneActiveStart(zone, after: Date()) {
                    await sendZoneAlert(zone: zone, source: .riskZoneScheduleStart, fireDate: boundary)
                }
            }
        }
    }

    private func reconcileZoneStateAndEvaluate() async {
        guard store.data.therapistOversight.role == .owner else { return }
        _ = await notifications.reconcileZoneNotifications(
            validZoneIDs: Set(store.data.highRiskZones.map(\.id))
        )
        zones.requestMonitoredRegionStates()
        _ = await zones.refreshCurrentZoneStates()
        await evaluateZoneWindows()
    }

    private func evaluateZoneWindows(now: Date = Date()) async {
        guard store.data.therapistOversight.role == .owner else { return }
        for zone in store.data.highRiskZones where zone.enabled && store.isInsideZone(zone.id) {
            if store.isZoneActive(zone, at: now) {
                guard !store.isZoneSafeguarded(zone.id) else { continue }
                let source: RiskAlertSource
                if let issued = latestIssuedZonePrompt(zoneID: zone.id, at: now) {
                    // A pending bounded follow-up series is already responsible for nudges while
                    // Bull is backgrounded or open. Do not issue a duplicate foreground one.
                    if await notifications.hasRepeatingZoneAlert(zoneID: zone.id) { continue }
                    guard now.timeIntervalSince(issued) >=
                        Double(store.data.settings.zoneNudgeRepeatMinutes) * 60 else { continue }
                    source = .riskZoneFollowUp
                } else {
                    source = .riskZoneScheduleStart
                }
                await sendZoneAlert(zone: zone, source: source, fireDate: now)
            } else {
                let boundary = store.nextZoneActiveStart(zone, after: now)
                var boundaryAlreadyScheduled = false
                if zone.scheduleMode == .sleepAnchored {
                    let pendingDate = await notifications.pendingOneShotZoneAlertDate(
                        zoneID: zone.id
                    )
                    if let boundary, let pendingDate {
                        boundaryAlreadyScheduled =
                            abs(boundary.timeIntervalSince(pendingDate)) < 60
                    }
                    let hasRepeat = await notifications.hasRepeatingZoneAlert(zoneID: zone.id)
                    if !boundaryAlreadyScheduled && (pendingDate != nil || hasRepeat) {
                        notifications.cancelZoneAlert(zoneID: zone.id)
                        store.cancelPendingZoneAlerts(zoneID: zone.id)
                    }
                }
                if let boundary, !boundaryAlreadyScheduled {
                    await sendZoneAlert(zone: zone, source: .riskZoneScheduleStart, fireDate: boundary)
                }
            }
        }
    }

    private func sendZoneAlert(
        zone: HighRiskZone,
        source: RiskAlertSource,
        fireDate: Date
    ) async {
        guard store.data.therapistOversight.role == .owner,
              zone.enabled, store.isInsideZone(zone.id), !store.isZoneSafeguarded(zone.id) else { return }
        let tier: PressureTier = switch zone.riskLevel {
        case .low: .watch
        case .medium: .warning
        case .high: .emergency
        }
        let decision = store.alertPolicyDecision(
            tier: tier,
            source: source,
            zoneID: zone.id
        )
        let replacedID: String?
        switch decision {
        case .deliver: replacedID = nil
        case .replace(let eventID): replacedID = eventID
        case .suppressCooldown, .suppressAcknowledged, .suppressDuplicate: return
        }
        let event = store.recordRiskAlertAttempt(
            source: source,
            tier: tier,
            zoneID: zone.id,
            safeguardID: zone.safeguard.id,
            contributors: [zone.name],
            cooldownMinutes: store.data.settings.zoneNudgeRepeatMinutes
        )
        store.queueTherapistZoneWarning(
            zoneID: zone.id,
            alertEventID: event.id,
            // A future local notification must not create a future-dated therapist event.
            // Physical entry is shared immediately by recordZoneEvent; this path adds only
            // a throttled still-active warning when the Risk Zone is active now.
            at: Date()
        )
        if let replacedID { store.replaceRiskAlert(eventID: replacedID, with: event.id) }
        _ = store.recordSafeguardEvent(
            zoneID: zone.id,
            kind: .promptIssued,
            alertEventID: event.id,
            at: fireDate
        )
        let delivered = await notifications.scheduleZoneAlert(
            event: event,
            zone: zone,
            fireDate: fireDate,
            timeSensitive: store.data.settings.zoneTimeSensitiveAlerts && tier == .emergency,
            repeatMinutes: store.data.settings.zoneNudgeRepeatMinutes,
            repeatUntil: store.zoneActiveEnd(zone, at: fireDate.addingTimeInterval(1))
        )
        store.updateRiskAlertDelivery(
            eventID: event.id,
            state: delivered ? .scheduled : .failed,
            message: delivered ? nil : notifications.lastError
        )
    }

    private func latestIssuedZonePrompt(zoneID: String, at date: Date) -> Date? {
        let nowMS = date.timeIntervalSince1970 * 1_000
        let enteredMS = store.data.zoneEvents
            .filter { $0.zoneID == zoneID && $0.kind == .entered && $0.ts <= nowMS }
            .map(\.ts)
            .max() ?? 0
        return store.data.safeguardEvents
            .filter {
                $0.zoneID == zoneID && $0.kind == .promptIssued &&
                $0.occurrenceTs >= enteredMS && $0.occurrenceTs <= nowMS
            }
            .max { $0.occurrenceTs < $1.occurrenceTs }
            .map { Date(timeIntervalSince1970: $0.occurrenceTs / 1_000) }
    }

    private func handleNotificationAction(_ request: NotificationActionRequest?) {
        guard let request else { return }
        guard store.data.therapistOversight.role == .owner else {
            notifications.consumeActionRequest()
            return
        }
        if let eventID = request.eventID {
            store.handleRiskAlertAction(eventID: eventID, action: request.action)
            if request.action == .safeguardDone,
               let zoneID = request.zoneID ?? store.riskAlertEvent(id: eventID)?.zoneID,
               store.data.highRiskZones.first(where: { $0.id == zoneID })?.resolutionMode == .safeguard {
                notifications.cancelZoneAlert(zoneID: zoneID)
            }
        }
        if request.route != nil { tab = 0 }
        notifications.consumeActionRequest()
    }

    private func updateTherapistMonitoringStatus() {
        guard store.data.therapistOversight.role == .owner else { return }
        let notificationsAllowed = notifications.authorizationStatus == .authorized ||
            notifications.authorizationStatus == .provisional
        let expected = store.data.highRiskZones.filter(\.enabled).count
        store.updateTherapistMonitoringStatus(TherapistMonitoringStatus(
            locationStatus: zones.authorizationLabel,
            notificationsAllowed: notificationsAllowed,
            timeSensitiveEnabled: notifications.timeSensitiveSetting == .enabled,
            monitoredZoneCount: zones.monitoredZoneIDs.count,
            expectedZoneCount: expected,
            failedZoneCount: zones.monitoringFailedZoneIDs.count
        ))
    }

    private func monitoringInputsChanged() {
        updateTherapistMonitoringStatus()
        Task { await therapistCloud.sync(store: store, notifications: notifications) }
    }
}
