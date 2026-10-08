import Foundation
import Combine

/// Small app-only preferences are kept beside Bull's protected data file. Behavioural
/// history remains in `BullData`; this file contains switches and local alert state only.
@MainActor
final class AppPreferences: ObservableObject {
    @Published var remindersEnabled: Bool { didSet { save() } }
    @Published var biometricLockEnabled: Bool { didSet { save() } }

    // Device-local daily input queue. These preferences contain no health or behavioural
    // values; the queue derives completion from Bull's existing protected data.
    @Published var dailyInputRemindersEnabled: Bool { didSet { save() } }
    @Published var dailyInputReminderIntervalMinutes: Int { didSet { save() } }
    @Published var dailyInputReminderStartHour: Int { didSet { save() } }
    @Published var dailyInputReminderEndHour: Int { didSet { save() } }
    @Published var dailyInputReminderPausedDayKey: String? { didSet { save() } }
    @Published var dailyInputStressEnabled: Bool { didSet { save() } }
    @Published var dailyInputUrgeEnabled: Bool { didSet { save() } }
    @Published var dailyInputBullStateEnabled: Bool { didSet { save() } }
    @Published var dailyInputNutritionEnabled: Bool { didSet { save() } }
    @Published var dailyInputSleepEnabled: Bool { didSet { save() } }
    @Published var dailyInputExerciseEnabled: Bool { didSet { save() } }

    @Published var riskAlertsEnabled: Bool { didSet { save() } }
    @Published var riskWatchEnabled: Bool { didSet { save() } }
    @Published var riskWarningEnabled: Bool { didSet { save() } }
    @Published var riskEmergencyEnabled: Bool { didSet { save() } }
    @Published var riskWatchThreshold: Double { didSet { save() } }
    @Published var riskWarningThreshold: Double { didSet { save() } }
    @Published var riskEmergencyThreshold: Double { didSet { save() } }
    @Published var riskWarningDays: Int { didSet { save() } }
    @Published var riskEmergencyDays: Int { didSet { save() } }
    @Published var riskEmergencyTimeSensitive: Bool {
        didSet {
            if riskEmergencyTimeSensitive { timeSensitiveConsentVersion = 1 }
            save()
        }
    }
    @Published var riskRepeatOnConsecutiveDays: Bool { didSet { save() } }
    @Published var riskQuietHoursEnabled: Bool { didSet { save() } }
    @Published var riskQuietStart: String { didSet { save() } }
    @Published var riskQuietEnd: String { didSet { save() } }
    /// Device-local sync status only. Health samples and derived scores remain in BullData.
    @Published private(set) var lastHealthSyncTs: Double?
    @Published private(set) var lastSaveError: String?

    private var lastRiskAlertDay: String?
    private var lastRiskAlertTier: Int
    /// v2.7 defaulted Time Sensitive delivery on. v2.8 requires a fresh, explicit opt-in;
    /// this marker distinguishes that choice from an inherited default.
    private var timeSensitiveConsentVersion: Int
    private let fileURL: URL

    private struct Payload: Codable {
        var remindersEnabled: Bool
        var biometricLockEnabled: Bool
        var dailyInputRemindersEnabled: Bool
        var dailyInputReminderIntervalMinutes: Int
        var dailyInputReminderStartHour: Int
        var dailyInputReminderEndHour: Int
        var dailyInputReminderPausedDayKey: String?
        var dailyInputStressEnabled: Bool
        var dailyInputUrgeEnabled: Bool
        var dailyInputBullStateEnabled: Bool
        var dailyInputNutritionEnabled: Bool
        var dailyInputSleepEnabled: Bool
        var dailyInputExerciseEnabled: Bool
        var riskAlertsEnabled: Bool
        var riskWatchEnabled: Bool
        var riskWarningEnabled: Bool
        var riskEmergencyEnabled: Bool
        var riskWatchThreshold: Double
        var riskWarningThreshold: Double
        var riskEmergencyThreshold: Double
        var riskWarningDays: Int
        var riskEmergencyDays: Int
        var riskEmergencyTimeSensitive: Bool
        var riskTimeSensitiveConsentVersion: Int
        var riskRepeatOnConsecutiveDays: Bool
        var riskQuietHoursEnabled: Bool
        var riskQuietStart: String
        var riskQuietEnd: String
        var lastRiskAlertDay: String?
        var lastRiskAlertTier: Int
        var lastHealthSyncTs: Double?

        enum CodingKeys: String, CodingKey {
            case remindersEnabled, biometricLockEnabled
            case dailyInputRemindersEnabled, dailyInputReminderIntervalMinutes
            case dailyInputReminderStartHour, dailyInputReminderEndHour
            case dailyInputReminderPausedDayKey, dailyInputStressEnabled, dailyInputUrgeEnabled
            case dailyInputBullStateEnabled, dailyInputNutritionEnabled
            case dailyInputSleepEnabled, dailyInputExerciseEnabled
            case riskAlertsEnabled, riskWatchEnabled, riskWarningEnabled, riskEmergencyEnabled
            case riskWatchThreshold, riskWarningThreshold, riskEmergencyThreshold
            case riskWarningDays, riskEmergencyDays, riskEmergencyTimeSensitive
            case riskTimeSensitiveConsentVersion
            case riskRepeatOnConsecutiveDays, riskQuietHoursEnabled, riskQuietStart, riskQuietEnd
            case lastRiskAlertDay, lastRiskAlertTier, lastHealthSyncTs
            // v2.6 persisted these under the old Pressure name.
            case lastPressureAlertDay, lastPressureAlertTier
        }

        init() {
            remindersEnabled = false
            biometricLockEnabled = false
            dailyInputRemindersEnabled = false
            dailyInputReminderIntervalMinutes = 30
            dailyInputReminderStartHour = 8
            dailyInputReminderEndHour = 22
            dailyInputReminderPausedDayKey = nil
            dailyInputStressEnabled = true
            dailyInputUrgeEnabled = true
            dailyInputBullStateEnabled = true
            dailyInputNutritionEnabled = true
            dailyInputSleepEnabled = true
            dailyInputExerciseEnabled = true
            riskAlertsEnabled = false
            riskWatchEnabled = true
            riskWarningEnabled = true
            riskEmergencyEnabled = true
            riskWatchThreshold = 55
            riskWarningThreshold = 65
            riskEmergencyThreshold = 78
            riskWarningDays = 2
            riskEmergencyDays = 3
            riskEmergencyTimeSensitive = false
            riskTimeSensitiveConsentVersion = 0
            riskRepeatOnConsecutiveDays = true
            riskQuietHoursEnabled = true
            riskQuietStart = "22:30"
            riskQuietEnd = "07:00"
            lastRiskAlertDay = nil
            lastRiskAlertTier = 0
            lastHealthSyncTs = nil
        }

        init(from decoder: Decoder) throws {
            self.init()
            let c = try decoder.container(keyedBy: CodingKeys.self)
            remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? remindersEnabled
            biometricLockEnabled = try c.decodeIfPresent(Bool.self, forKey: .biometricLockEnabled) ?? biometricLockEnabled
            dailyInputRemindersEnabled = try c.decodeIfPresent(
                Bool.self, forKey: .dailyInputRemindersEnabled
            ) ?? dailyInputRemindersEnabled
            dailyInputReminderIntervalMinutes = try c.decodeIfPresent(
                Int.self, forKey: .dailyInputReminderIntervalMinutes
            ) ?? dailyInputReminderIntervalMinutes
            dailyInputReminderStartHour = try c.decodeIfPresent(
                Int.self, forKey: .dailyInputReminderStartHour
            ) ?? dailyInputReminderStartHour
            dailyInputReminderEndHour = try c.decodeIfPresent(
                Int.self, forKey: .dailyInputReminderEndHour
            ) ?? dailyInputReminderEndHour
            dailyInputReminderPausedDayKey = try c.decodeIfPresent(
                String.self, forKey: .dailyInputReminderPausedDayKey
            )
            dailyInputStressEnabled = try c.decodeIfPresent(
                Bool.self, forKey: .dailyInputStressEnabled
            ) ?? dailyInputStressEnabled
            dailyInputUrgeEnabled = try c.decodeIfPresent(
                Bool.self, forKey: .dailyInputUrgeEnabled
            ) ?? dailyInputUrgeEnabled
            dailyInputBullStateEnabled = try c.decodeIfPresent(
                Bool.self, forKey: .dailyInputBullStateEnabled
            ) ?? dailyInputBullStateEnabled
            dailyInputNutritionEnabled = try c.decodeIfPresent(
                Bool.self, forKey: .dailyInputNutritionEnabled
            ) ?? dailyInputNutritionEnabled
            dailyInputSleepEnabled = try c.decodeIfPresent(
                Bool.self, forKey: .dailyInputSleepEnabled
            ) ?? dailyInputSleepEnabled
            dailyInputExerciseEnabled = try c.decodeIfPresent(
                Bool.self, forKey: .dailyInputExerciseEnabled
            ) ?? dailyInputExerciseEnabled
            riskAlertsEnabled = try c.decodeIfPresent(Bool.self, forKey: .riskAlertsEnabled) ?? riskAlertsEnabled
            riskWatchEnabled = try c.decodeIfPresent(Bool.self, forKey: .riskWatchEnabled) ?? riskWatchEnabled
            riskWarningEnabled = try c.decodeIfPresent(Bool.self, forKey: .riskWarningEnabled) ?? riskWarningEnabled
            riskEmergencyEnabled = try c.decodeIfPresent(Bool.self, forKey: .riskEmergencyEnabled) ?? riskEmergencyEnabled
            riskWatchThreshold = try c.decodeIfPresent(Double.self, forKey: .riskWatchThreshold) ?? riskWatchThreshold
            riskWarningThreshold = try c.decodeIfPresent(Double.self, forKey: .riskWarningThreshold) ?? riskWarningThreshold
            riskEmergencyThreshold = try c.decodeIfPresent(Double.self, forKey: .riskEmergencyThreshold) ?? riskEmergencyThreshold
            riskWarningDays = try c.decodeIfPresent(Int.self, forKey: .riskWarningDays) ?? riskWarningDays
            riskEmergencyDays = try c.decodeIfPresent(Int.self, forKey: .riskEmergencyDays) ?? riskEmergencyDays
            riskEmergencyTimeSensitive = try c.decodeIfPresent(Bool.self, forKey: .riskEmergencyTimeSensitive) ?? riskEmergencyTimeSensitive
            riskTimeSensitiveConsentVersion = try c.decodeIfPresent(
                Int.self,
                forKey: .riskTimeSensitiveConsentVersion
            ) ?? 0
            riskRepeatOnConsecutiveDays = try c.decodeIfPresent(Bool.self, forKey: .riskRepeatOnConsecutiveDays) ?? riskRepeatOnConsecutiveDays
            riskQuietHoursEnabled = try c.decodeIfPresent(Bool.self, forKey: .riskQuietHoursEnabled) ?? riskQuietHoursEnabled
            riskQuietStart = try c.decodeIfPresent(String.self, forKey: .riskQuietStart) ?? riskQuietStart
            riskQuietEnd = try c.decodeIfPresent(String.self, forKey: .riskQuietEnd) ?? riskQuietEnd
            let currentDay = try c.decodeIfPresent(String.self, forKey: .lastRiskAlertDay)
            let legacyDay = try c.decodeIfPresent(String.self, forKey: .lastPressureAlertDay)
            lastRiskAlertDay = currentDay ?? legacyDay
            let currentTier = try c.decodeIfPresent(Int.self, forKey: .lastRiskAlertTier)
            let legacyTier = try c.decodeIfPresent(Int.self, forKey: .lastPressureAlertTier)
            lastRiskAlertTier = currentTier ?? legacyTier ?? lastRiskAlertTier
            lastHealthSyncTs = try c.decodeIfPresent(Double.self, forKey: .lastHealthSyncTs)
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(remindersEnabled, forKey: .remindersEnabled)
            try c.encode(biometricLockEnabled, forKey: .biometricLockEnabled)
            try c.encode(dailyInputRemindersEnabled, forKey: .dailyInputRemindersEnabled)
            try c.encode(dailyInputReminderIntervalMinutes, forKey: .dailyInputReminderIntervalMinutes)
            try c.encode(dailyInputReminderStartHour, forKey: .dailyInputReminderStartHour)
            try c.encode(dailyInputReminderEndHour, forKey: .dailyInputReminderEndHour)
            try c.encodeIfPresent(dailyInputReminderPausedDayKey, forKey: .dailyInputReminderPausedDayKey)
            try c.encode(dailyInputStressEnabled, forKey: .dailyInputStressEnabled)
            try c.encode(dailyInputUrgeEnabled, forKey: .dailyInputUrgeEnabled)
            try c.encode(dailyInputBullStateEnabled, forKey: .dailyInputBullStateEnabled)
            try c.encode(dailyInputNutritionEnabled, forKey: .dailyInputNutritionEnabled)
            try c.encode(dailyInputSleepEnabled, forKey: .dailyInputSleepEnabled)
            try c.encode(dailyInputExerciseEnabled, forKey: .dailyInputExerciseEnabled)
            try c.encode(riskAlertsEnabled, forKey: .riskAlertsEnabled)
            try c.encode(riskWatchEnabled, forKey: .riskWatchEnabled)
            try c.encode(riskWarningEnabled, forKey: .riskWarningEnabled)
            try c.encode(riskEmergencyEnabled, forKey: .riskEmergencyEnabled)
            try c.encode(riskWatchThreshold, forKey: .riskWatchThreshold)
            try c.encode(riskWarningThreshold, forKey: .riskWarningThreshold)
            try c.encode(riskEmergencyThreshold, forKey: .riskEmergencyThreshold)
            try c.encode(riskWarningDays, forKey: .riskWarningDays)
            try c.encode(riskEmergencyDays, forKey: .riskEmergencyDays)
            try c.encode(riskEmergencyTimeSensitive, forKey: .riskEmergencyTimeSensitive)
            try c.encode(riskTimeSensitiveConsentVersion, forKey: .riskTimeSensitiveConsentVersion)
            try c.encode(riskRepeatOnConsecutiveDays, forKey: .riskRepeatOnConsecutiveDays)
            try c.encode(riskQuietHoursEnabled, forKey: .riskQuietHoursEnabled)
            try c.encode(riskQuietStart, forKey: .riskQuietStart)
            try c.encode(riskQuietEnd, forKey: .riskQuietEnd)
            try c.encodeIfPresent(lastRiskAlertDay, forKey: .lastRiskAlertDay)
            try c.encode(lastRiskAlertTier, forKey: .lastRiskAlertTier)
            try c.encodeIfPresent(lastHealthSyncTs, forKey: .lastHealthSyncTs)
        }
    }

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Bull", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("bull-preferences-v1.json")

        let loaded: Payload
        if let bytes = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Payload.self, from: bytes) {
            loaded = decoded
        } else {
            loaded = Payload()
        }

        remindersEnabled = loaded.remindersEnabled
        biometricLockEnabled = loaded.biometricLockEnabled
        dailyInputRemindersEnabled = loaded.dailyInputRemindersEnabled
        dailyInputReminderIntervalMinutes = [15, 30, 60, 120].contains(loaded.dailyInputReminderIntervalMinutes)
            ? loaded.dailyInputReminderIntervalMinutes : 30
        let loadedStartHour = min(21, max(0, loaded.dailyInputReminderStartHour))
        dailyInputReminderStartHour = loadedStartHour
        dailyInputReminderEndHour = min(23, max(loadedStartHour + 1, loaded.dailyInputReminderEndHour))
        dailyInputReminderPausedDayKey = loaded.dailyInputReminderPausedDayKey
        dailyInputStressEnabled = loaded.dailyInputStressEnabled
        dailyInputUrgeEnabled = loaded.dailyInputUrgeEnabled
        dailyInputBullStateEnabled = loaded.dailyInputBullStateEnabled
        dailyInputNutritionEnabled = loaded.dailyInputNutritionEnabled
        dailyInputSleepEnabled = loaded.dailyInputSleepEnabled
        dailyInputExerciseEnabled = loaded.dailyInputExerciseEnabled
        riskAlertsEnabled = loaded.riskAlertsEnabled
        riskWatchEnabled = loaded.riskWatchEnabled
        riskWarningEnabled = loaded.riskWarningEnabled
        riskEmergencyEnabled = loaded.riskEmergencyEnabled
        // Upgrade untouched v2.6 defaults to the v2.7 Risk-only tiers. Custom values survive.
        let oldDefaults = loaded.riskWatchThreshold == 65
            && loaded.riskWarningThreshold == 78
            && loaded.riskEmergencyThreshold == 88
        riskWatchThreshold = oldDefaults ? 55 : loaded.riskWatchThreshold
        riskWarningThreshold = oldDefaults ? 65 : loaded.riskWarningThreshold
        riskEmergencyThreshold = oldDefaults ? 78 : loaded.riskEmergencyThreshold
        riskWarningDays = loaded.riskWarningDays
        riskEmergencyDays = loaded.riskEmergencyDays
        timeSensitiveConsentVersion = loaded.riskTimeSensitiveConsentVersion
        riskEmergencyTimeSensitive = loaded.riskTimeSensitiveConsentVersion >= 1
            ? loaded.riskEmergencyTimeSensitive
            : false
        riskRepeatOnConsecutiveDays = loaded.riskRepeatOnConsecutiveDays
        riskQuietHoursEnabled = loaded.riskQuietHoursEnabled
        riskQuietStart = loaded.riskQuietStart
        riskQuietEnd = loaded.riskQuietEnd
        lastRiskAlertDay = loaded.lastRiskAlertDay
        lastRiskAlertTier = loaded.lastRiskAlertTier
        lastHealthSyncTs = loaded.lastHealthSyncTs
        lastSaveError = nil
    }

    var riskThresholds: PressureThresholds {
        let watch = min(100, max(0, riskWatchThreshold))
        let warning = min(100, max(watch, riskWarningThreshold))
        let emergency = min(100, max(warning, riskEmergencyThreshold))
        let warningDays = max(1, riskWarningDays)
        let emergencyDays = max(warningDays, riskEmergencyDays)
        return PressureThresholds(
            watch: watch,
            warning: warning,
            emergency: emergency,
            warningDays: warningDays,
            emergencyDays: emergencyDays
        )
    }

    func shouldDeliverRiskAlert(
        dayKey: String,
        tier: PressureTier,
        consecutiveElevatedDays: Int = 1
    ) -> Bool {
        guard riskAlertsEnabled else { return false }
        guard tier != .normal else {
            if lastRiskAlertTier != 0 || lastRiskAlertDay != nil {
                lastRiskAlertTier = 0
                lastRiskAlertDay = nil
                save()
            }
            return false
        }

        let enabled: Bool
        switch tier {
        case .watch: enabled = riskWatchEnabled
        case .warning: enabled = riskWarningEnabled
        case .emergency: enabled = riskEmergencyEnabled
        case .normal: enabled = false
        }
        guard enabled else { return false }
        if lastRiskAlertDay == dayKey { return tier.rawValue > lastRiskAlertTier }
        if !riskRepeatOnConsecutiveDays,
           consecutiveElevatedDays > 1,
           tier.rawValue <= lastRiskAlertTier { return false }
        return true
    }

    func isRiskTierEnabled(_ tier: PressureTier) -> Bool {
        guard riskAlertsEnabled else { return false }
        switch tier {
        case .normal: return false
        case .watch: return riskWatchEnabled
        case .warning: return riskWarningEnabled
        case .emergency: return riskEmergencyEnabled
        }
    }

    /// A delayed quiet-hours request must not survive a downgrade or a settings change
    /// that disables its tier. This is state reconciliation, not an additional alert.
    func shouldCancelPendingRiskAlert(dayKey: String, tier: PressureTier) -> Bool {
        guard lastRiskAlertDay == dayKey else { return false }
        return tier.rawValue < lastRiskAlertTier || !isRiskTierEnabled(tier)
    }

    func markPendingRiskAlertCancelled(dayKey: String, currentTier: PressureTier) {
        if isRiskTierEnabled(currentTier) {
            lastRiskAlertDay = dayKey
            lastRiskAlertTier = currentTier.rawValue
        } else {
            lastRiskAlertDay = nil
            lastRiskAlertTier = 0
        }
        save()
    }

    func markRiskAlertDelivered(dayKey: String, tier: PressureTier) {
        lastRiskAlertDay = dayKey
        lastRiskAlertTier = tier.rawValue
        save()
    }

    func markHealthSyncCompleted(at date: Date = Date()) {
        lastHealthSyncTs = date.timeIntervalSince1970 * 1_000
        save()
    }

    func reset() {
        remindersEnabled = false
        biometricLockEnabled = false
        dailyInputRemindersEnabled = false
        dailyInputReminderIntervalMinutes = 30
        dailyInputReminderStartHour = 8
        dailyInputReminderEndHour = 22
        dailyInputReminderPausedDayKey = nil
        dailyInputStressEnabled = true
        dailyInputUrgeEnabled = true
        dailyInputBullStateEnabled = true
        dailyInputNutritionEnabled = true
        dailyInputSleepEnabled = true
        dailyInputExerciseEnabled = true
        riskAlertsEnabled = false
        riskWatchEnabled = true
        riskWarningEnabled = true
        riskEmergencyEnabled = true
        riskWatchThreshold = 55
        riskWarningThreshold = 65
        riskEmergencyThreshold = 78
        riskWarningDays = 2
        riskEmergencyDays = 3
        riskEmergencyTimeSensitive = false
        timeSensitiveConsentVersion = 0
        riskRepeatOnConsecutiveDays = true
        riskQuietHoursEnabled = true
        riskQuietStart = "22:30"
        riskQuietEnd = "07:00"
        lastRiskAlertDay = nil
        lastRiskAlertTier = 0
        lastHealthSyncTs = nil
        save()
    }

    private func save() {
        var payload = Payload()
        payload.remindersEnabled = remindersEnabled
        payload.biometricLockEnabled = biometricLockEnabled
        payload.dailyInputRemindersEnabled = dailyInputRemindersEnabled
        payload.dailyInputReminderIntervalMinutes = dailyInputReminderIntervalMinutes
        payload.dailyInputReminderStartHour = dailyInputReminderStartHour
        payload.dailyInputReminderEndHour = dailyInputReminderEndHour
        payload.dailyInputReminderPausedDayKey = dailyInputReminderPausedDayKey
        payload.dailyInputStressEnabled = dailyInputStressEnabled
        payload.dailyInputUrgeEnabled = dailyInputUrgeEnabled
        payload.dailyInputBullStateEnabled = dailyInputBullStateEnabled
        payload.dailyInputNutritionEnabled = dailyInputNutritionEnabled
        payload.dailyInputSleepEnabled = dailyInputSleepEnabled
        payload.dailyInputExerciseEnabled = dailyInputExerciseEnabled
        payload.riskAlertsEnabled = riskAlertsEnabled
        payload.riskWatchEnabled = riskWatchEnabled
        payload.riskWarningEnabled = riskWarningEnabled
        payload.riskEmergencyEnabled = riskEmergencyEnabled
        payload.riskWatchThreshold = riskWatchThreshold
        payload.riskWarningThreshold = riskWarningThreshold
        payload.riskEmergencyThreshold = riskEmergencyThreshold
        payload.riskWarningDays = riskWarningDays
        payload.riskEmergencyDays = riskEmergencyDays
        payload.riskEmergencyTimeSensitive = riskEmergencyTimeSensitive
        payload.riskTimeSensitiveConsentVersion = timeSensitiveConsentVersion
        payload.riskRepeatOnConsecutiveDays = riskRepeatOnConsecutiveDays
        payload.riskQuietHoursEnabled = riskQuietHoursEnabled
        payload.riskQuietStart = riskQuietStart
        payload.riskQuietEnd = riskQuietEnd
        payload.lastRiskAlertDay = lastRiskAlertDay
        payload.lastRiskAlertTier = lastRiskAlertTier
        payload.lastHealthSyncTs = lastHealthSyncTs

        do {
            let bytes = try JSONEncoder().encode(payload)
            try bytes.write(to: fileURL, options: [.atomic, .completeFileProtection])
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
        }
    }
}
