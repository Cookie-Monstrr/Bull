import Foundation
@preconcurrency import UserNotifications
import Combine

enum BullNotificationError: LocalizedError {
    case invalidTime(String)

    var errorDescription: String? {
        switch self {
        case .invalidTime(let value):
            return "Use a 24-hour reminder time such as 08:00 or 21:30. ‘\(value)’ is not valid."
        }
    }
}

struct NotificationActionRequest: Equatable, Sendable {
    var route: String?
    var eventID: String?
    var zoneID: String?
    var action: AlertUserAction
}

private enum BullNotificationIdentifier {
    static let riskCategory = "BULL_RISK_ACTIONS"
    static let zoneCategory = "BULL_ZONE_ACTIONS"
    static let exitZoneCategory = "BULL_EXIT_ZONE_ACTIONS"
    static let dailyInputCategory = "BULL_DAILY_INPUT"
    static let startResponse = "BULL_START_RESPONSE"
    static let openRiskPlan = "BULL_OPEN_RISK_PLAN"
    static let safeguardDone = "BULL_SAFEGUARD_DONE"
    static let snoozeZone = "BULL_SNOOZE_ZONE"
    static let openBull = "BULL_OPEN"
}

@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var timeSensitiveSetting: UNNotificationSetting = .notSupported
    @Published var lastError: String?
    @Published var requestedRoute: String?
    @Published var actionRequest: NotificationActionRequest?
    @Published var foregroundDeliveredEventID: String?

    private let center = UNUserNotificationCenter.current()
    private let reminderIDs = ["bull.stress.0", "bull.stress.1", "bull.stress.2"]
    private let legacyReminderIDs = ["bull.morning", "bull.evening"]
    private let riskID = "bull.risk.current"
    private let dailyInputRequestIDs = (0..<4).map { "bull.input.\($0)" }

    override init() {
        super.init()
        center.delegate = self
        registerCategories()
        retireLegacyReminders()
    }

    private func registerCategories() {
        let startResponse = UNNotificationAction(
            identifier: BullNotificationIdentifier.startResponse,
            title: "Open urge support",
            options: [.foreground]
        )
        let safeguardDone = UNNotificationAction(
            identifier: BullNotificationIdentifier.safeguardDone,
            title: "Safeguard done",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: BullNotificationIdentifier.snoozeZone,
            title: "Snooze briefly",
            options: []
        )
        let open = UNNotificationAction(
            identifier: BullNotificationIdentifier.openBull,
            title: "Open Bull",
            options: [.foreground]
        )
        let risk = UNNotificationCategory(
            identifier: BullNotificationIdentifier.riskCategory,
            actions: [startResponse, open],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let zone = UNNotificationCategory(
            identifier: BullNotificationIdentifier.zoneCategory,
            actions: [safeguardDone, snooze, open],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let exitZone = UNNotificationCategory(
            identifier: BullNotificationIdentifier.exitZoneCategory,
            actions: [snooze, open],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let dailyInput = UNNotificationCategory(
            identifier: BullNotificationIdentifier.dailyInputCategory,
            actions: [open],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([risk, zone, exitZone, dailyInput])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let route = info["bullRoute"] as? String
        let eventID = info["bullEventID"] as? String
        let zoneID = info["bullZoneID"] as? String
        let action: AlertUserAction
        switch response.actionIdentifier {
        case BullNotificationIdentifier.startResponse: action = .startResponse
        case BullNotificationIdentifier.openRiskPlan: action = .openRiskPlan
        case BullNotificationIdentifier.safeguardDone: action = .safeguardDone
        case BullNotificationIdentifier.snoozeZone: action = .snooze
        case UNNotificationDismissActionIdentifier: action = .dismissed
        default: action = .opened
        }
        if action == .snooze, let eventID {
            if let zoneID {
                let scheduledIDs = ["bull.zone.\(zoneID)", "bull.zone.repeat.\(zoneID)"] +
                    (1...8).map { "bull.zone.followup.\(zoneID).\($0)" }
                center.removePendingNotificationRequests(withIdentifiers: scheduledIDs)
            }
            let content = response.notification.request.content.mutableCopy() as? UNMutableNotificationContent
            content?.title = "Bull Risk Zone Reminder"
            if let content {
                let request = UNNotificationRequest(
                    identifier: "bull.zone.snooze.\(eventID)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
                )
                center.add(request) { _ in }
            }
        }
        completionHandler()
        Task { @MainActor [weak self] in
            self?.requestedRoute = route
            self?.actionRequest = NotificationActionRequest(
                route: route,
                eventID: eventID,
                zoneID: zoneID,
                action: action
            )
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let eventID = notification.request.content.userInfo["bullEventID"] as? String
        completionHandler([.banner, .sound])
        Task { @MainActor [weak self] in self?.foregroundDeliveredEventID = eventID }
    }

    func consumeRoute() { requestedRoute = nil }
    func consumeActionRequest() { actionRequest = nil }
    func consumeForegroundDelivery() { foregroundDeliveredEventID = nil }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        timeSensitiveSetting = settings.timeSensitiveSetting
    }

    func requestAuthorization(includeTimeSensitive: Bool = false) async -> Bool {
        do {
            // UNAuthorizationOptions.timeSensitive is deprecated. Time-sensitive delivery
            // is controlled by the target entitlement plus interruptionLevel; the normal
            // notification permission request remains alert/sound/badge.
            _ = includeTimeSensitive
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func requestAndScheduleStressCheckIns(times: [String]) async -> Bool {
        guard await requestAuthorization() else { return false }
        do {
            try await scheduleStressCheckIns(times: times)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func scheduleStressCheckIns(times: [String]) async throws {
        center.removePendingNotificationRequests(withIdentifiers: reminderIDs + legacyReminderIDs)
        for (index, time) in times.prefix(reminderIDs.count).enumerated() {
            try await addDaily(
                id: reminderIDs[index],
                title: "Bull · Stress check-in",
                body: "How stressed do you feel right now? Log one quick 0–10 reading.",
                time: time
            )
        }
    }

    func disable() {
        center.removePendingNotificationRequests(withIdentifiers: reminderIDs + legacyReminderIDs)
    }

    func retireLegacyReminders() {
        center.removePendingNotificationRequests(withIdentifiers: legacyReminderIDs)
    }

    func retireLegacyCountermoveFollowUps() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("bull.countermove.followup.") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func disableRiskAlerts() {
        center.removePendingNotificationRequests(withIdentifiers: [riskID])
    }

    func disableAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func clearDailyInputReminders() {
        center.removePendingNotificationRequests(withIdentifiers: dailyInputRequestIDs)
        center.removeDeliveredNotifications(withIdentifiers: dailyInputRequestIDs + ["bull.input.test"])
    }

    func reconcileDailyInputReminder(
        item: BullDailyInputQueueItem?,
        intervalMinutes: Int,
        endHour: Int,
        now: Date = Date()
    ) async -> Bool {
        guard let item else {
            clearDailyInputReminders()
            return true
        }
        let route = item.kind.routeValue(dayKey: item.dayKey)
        let pendingRequests = await center.pendingNotificationRequests()
        let existing = pendingRequests.filter {
            $0.identifier.hasPrefix("bull.input.") && $0.identifier != "bull.input.test"
        }
        if !existing.isEmpty,
           existing.allSatisfy({ request in
               (request.content.userInfo["bullRoute"] as? String) == route &&
               (request.content.userInfo["bullInputIntervalMinutes"] as? Int) == intervalMinutes &&
               (request.content.userInfo["bullInputEndHour"] as? Int) == endHour &&
               (request.content.userInfo["bullInputDueHour"] as? Int) == item.dueHour
           }) {
            return true
        }

        clearDailyInputReminders()
        if authorizationStatus != .authorized && authorizationStatus != .provisional {
            guard await requestAuthorization() else { return false }
        }

        let calendar = BullDates.calendar
        let startOfDay = calendar.startOfDay(for: now)
        let due = calendar.date(
            bySettingHour: item.dueHour,
            minute: 0,
            second: 0,
            of: startOfDay
        ) ?? now
        let boundedEndHour = min(23, max(item.dueHour + 1, endHour))
        let end = calendar.date(
            bySettingHour: boundedEndHour,
            minute: 0,
            second: 0,
            of: startOfDay
        ) ?? startOfDay.addingTimeInterval(23 * 3_600)
        let first = max(due, now.addingTimeInterval(60))
        let interval = Double(
            [15, 30, 60, 120].contains(intervalMinutes) ? intervalMinutes : 30
        ) * 60
        let dates = (0..<dailyInputRequestIDs.count)
            .map { first.addingTimeInterval(Double($0) * interval) }
            .filter { $0 < end }
        guard !dates.isEmpty else { return true }

        do {
            for (index, fireDate) in dates.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "Bull · \(item.kind.title)"
                content.body = item.kind.notificationBody
                content.sound = .default
                content.categoryIdentifier = BullNotificationIdentifier.dailyInputCategory
                content.userInfo = [
                    "bullRoute": route,
                    "bullInputKind": item.kind.rawValue,
                    "bullInputDayKey": item.dayKey,
                    "bullInputIntervalMinutes": intervalMinutes,
                    "bullInputEndHour": endHour,
                    "bullInputDueHour": item.dueHour
                ]
                try await center.add(UNNotificationRequest(
                    identifier: dailyInputRequestIDs[index],
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(
                        timeInterval: max(1, fireDate.timeIntervalSinceNow),
                        repeats: false
                    )
                ))
            }
            return true
        } catch {
            lastError = error.localizedDescription
            clearDailyInputReminders()
            return false
        }
    }

    func scheduleDailyInputTest(item: BullDailyInputQueueItem?) async -> Bool {
        guard await requestAuthorization() else { return false }
        let kind = item?.kind ?? .morningStress
        let dayKey = item?.dayKey ?? BullDates.key(for: Date())
        let identifier = "bull.input.test"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = "Bull · \(kind.title)"
        content.body = kind.notificationBody
        content.sound = .default
        content.categoryIdentifier = BullNotificationIdentifier.dailyInputCategory
        content.userInfo = ["bullRoute": kind.routeValue(dayKey: dayKey)]
        do {
            try await center.add(UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            ))
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func cancelZoneAlert(zoneID: String) {
        let ids = [zoneRequestID(zoneID), zoneRepeatRequestID(zoneID)] + zoneFollowUpRequestIDs(zoneID)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        Task { await removeZoneNotifications(zoneID: zoneID) }
    }

    @discardableResult
    func reconcileZoneNotifications(validZoneIDs: Set<String>) async -> Int {
        let pending = await center.pendingNotificationRequests()
        let orphanedPending = pending.filter { request in
            guard let zoneID = request.content.userInfo["bullZoneID"] as? String else { return false }
            return !validZoneIDs.contains(zoneID)
        }.map(\.identifier)
        let delivered = await center.deliveredNotifications()
        let orphanedDelivered = delivered.filter { notification in
            guard let zoneID = notification.request.content.userInfo["bullZoneID"] as? String else {
                return false
            }
            return !validZoneIDs.contains(zoneID)
        }.map { $0.request.identifier }
        center.removePendingNotificationRequests(withIdentifiers: orphanedPending)
        center.removeDeliveredNotifications(withIdentifiers: orphanedDelivered)
        return orphanedPending.count + orphanedDelivered.count
    }

    private func removeZoneNotifications(zoneID: String) async {
        let pendingRequests = await center.pendingNotificationRequests()
        let pending = pendingRequests.filter {
            ($0.content.userInfo["bullZoneID"] as? String) == zoneID
        }.map(\.identifier)
        let deliveredNotifications = await center.deliveredNotifications()
        let delivered = deliveredNotifications.filter {
            ($0.request.content.userInfo["bullZoneID"] as? String) == zoneID
        }.map { $0.request.identifier }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }

    func hasRepeatingZoneAlert(zoneID: String) async -> Bool {
        let repeatID = zoneRepeatRequestID(zoneID)
        let followUpPrefix = "bull.zone.followup.\(zoneID)."
        return await center.pendingNotificationRequests().contains {
            $0.identifier == repeatID || $0.identifier.hasPrefix(followUpPrefix)
        }
    }

    func pendingOneShotZoneAlertDate(zoneID: String) async -> Date? {
        guard let request = await center.pendingNotificationRequests().first(where: {
            $0.identifier == zoneRequestID(zoneID)
        }) else { return nil }
        if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            return trigger.nextTriggerDate()
        }
        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            return trigger.nextTriggerDate()
        }
        return nil
    }

    func scheduleZoneTestAlert(timeSensitive: Bool = false) async -> Bool {
        guard await requestAuthorization(includeTimeSensitive: timeSensitive) else { return false }
        if timeSensitive {
            await refreshStatus()
            guard timeSensitiveSetting == .enabled else {
                lastError = "Time Sensitive Notifications are not enabled for Bull in iPhone Settings or signing capabilities."
                return false
            }
        }
        let content = UNMutableNotificationContent()
        content.title = "Bull Risk Zone Test"
        content.body = "Take action before you regret it! This is a test."
        content.sound = .default
        if timeSensitive { content.interruptionLevel = .timeSensitive }
        let identifier = "bull.zone.test"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        do {
            try await center.add(UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            ))
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func scheduleTherapistAlert(_ event: TherapistOversightEvent) async -> Bool {
        if authorizationStatus != .authorized && authorizationStatus != .provisional {
            guard await requestAuthorization() else { return false }
        }
        let copy = therapistNotificationCopy(for: event)
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        content.userInfo = [
            "bullTherapistEventID": event.id,
            "bullTherapistEventKind": event.kind.rawValue
        ]
        do {
            try await center.add(UNNotificationRequest(
                identifier: "bull.therapist.\(event.id)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            ))
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func scheduleZoneAlert(
        event: RiskAlertEvent,
        zone: HighRiskZone,
        fireDate: Date = Date().addingTimeInterval(1),
        timeSensitive: Bool = false,
        repeatMinutes: Int? = nil,
        repeatUntil: Date? = nil
    ) async -> Bool {
        if timeSensitive {
            guard await requestAuthorization(includeTimeSensitive: true) else { return false }
        } else if authorizationStatus != .authorized && authorizationStatus != .provisional {
            guard await requestAuthorization(includeTimeSensitive: timeSensitive) else { return false }
        }
        await refreshStatus()
        let useTimeSensitive = timeSensitive && timeSensitiveSetting == .enabled
        if timeSensitive && !useTimeSensitive {
            lastError = "Time Sensitive delivery is unavailable; Bull scheduled a normal private reminder instead."
        }
        let copy = riskZoneNotificationCopy(
            zoneName: zone.name,
            safeguardInstruction: zone.safeguard.instruction,
            resolutionMode: zone.resolutionMode,
            showDetails: zone.showNameOnLockScreen
        )
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        content.categoryIdentifier = zone.resolutionMode == .exitRequired
            ? BullNotificationIdentifier.exitZoneCategory
            : BullNotificationIdentifier.zoneCategory
        content.userInfo = [
            "bullRoute": event.route,
            "bullEventID": event.id,
            "bullZoneID": zone.id
        ]
        if useTimeSensitive { content.interruptionLevel = .timeSensitive }
        let id = zoneRequestID(zone.id)
        cancelZoneAlert(zoneID: zone.id)
        do {
            try await center.add(UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, fireDate.timeIntervalSinceNow),
                    repeats: false
                )
            ))
            if let repeatMinutes, let repeatUntil {
                let dates = boundedZoneFollowUpDates(
                    firstFireDate: fireDate,
                    repeatMinutes: repeatMinutes,
                    activeUntil: repeatUntil
                )
                for (offset, followUpDate) in dates.enumerated() {
                    try await center.add(UNNotificationRequest(
                        identifier: zoneFollowUpRequestID(zone.id, index: offset + 1),
                        content: content,
                        trigger: UNTimeIntervalNotificationTrigger(
                            timeInterval: max(1, followUpDate.timeIntervalSinceNow),
                            repeats: false
                        )
                    ))
                }
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func zoneRequestID(_ zoneID: String) -> String { "bull.zone.\(zoneID)" }
    private func zoneRepeatRequestID(_ zoneID: String) -> String { "bull.zone.repeat.\(zoneID)" }
    private func zoneFollowUpRequestID(_ zoneID: String, index: Int) -> String {
        "bull.zone.followup.\(zoneID).\(index)"
    }
    private func zoneFollowUpRequestIDs(_ zoneID: String) -> [String] {
        (1...8).map { zoneFollowUpRequestID(zoneID, index: $0) }
    }

    private func addDaily(id: String, title: String, body: String, time: String) async throws {
        let (hour, minute) = try parse(time: time)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func parse(time: String) throws -> (Int, Int) {
        let trimmed = time.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            throw BullNotificationError.invalidTime(trimmed)
        }
        return (hour, minute)
    }
}
