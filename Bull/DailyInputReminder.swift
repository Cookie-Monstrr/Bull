import Foundation

enum BullDailyInputKind: String, CaseIterable, Identifiable, Equatable, Sendable {
    case sleep
    case morningErection
    case morningStress
    case stressRelief
    case urgeCheckIn
    case nutrition
    case cardio
    case strength
    case naturalDesire
    case eveningStress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: return "Review Sleep"
        case .morningErection: return "Log Morning Erection"
        case .morningStress: return "Log Morning Stress"
        case .stressRelief: return "Finish Stress Relief"
        case .urgeCheckIn: return "Log Urge State"
        case .nutrition: return "Log Nutrition & Fasting"
        case .cardio: return "Complete Cardio Log"
        case .strength: return "Complete Strength Sets"
        case .naturalDesire: return "Log Natural Desire"
        case .eveningStress: return "Log Evening Stress"
        }
    }

    var notificationBody: String {
        switch self {
        case .sleep: return "Review the sleep values Bull will use today."
        case .morningErection: return "Record the observation from your final wake."
        case .morningStress: return "Record one quick morning stress value."
        case .stressRelief: return "Add the after-value to finish your activity."
        case .urgeCheckIn: return "Record your current urge, including zero."
        case .nutrition: return "Record food-plan adherence and whether you fasted."
        case .cardio: return "Review or complete today’s planned cardio."
        case .strength: return "Tick the planned sets you completed."
        case .naturalDesire: return "Later today, record natural desire separately from urges."
        case .eveningStress: return "Record your final stress value before bed."
        }
    }

    var preferredHour: Int {
        switch self {
        case .sleep, .morningErection, .morningStress, .stressRelief: return 8
        case .urgeCheckIn: return 12
        case .nutrition: return 17
        case .cardio, .strength: return 18
        case .naturalDesire: return 19
        case .eveningStress: return 20
        }
    }

    var entryKind: BullEntryKind {
        switch self {
        case .sleep: return .sleep
        case .morningErection: return .morning
        case .morningStress, .eveningStress: return .stress
        case .stressRelief: return .relief
        case .urgeCheckIn: return .urge
        case .nutrition: return .nutrition
        case .cardio: return .cardio
        case .strength: return .strength
        case .naturalDesire: return .desire
        }
    }

    func routeValue(dayKey: String) -> String {
        "bull://input/\(rawValue)/\(dayKey)"
    }

    static func parse(route: String) -> (kind: Self, dayKey: String)? {
        let parts = route.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 4, parts[0] == "bull:", parts[1] == "input",
              let kind = Self(rawValue: parts[2]), BullDates.date(from: parts[3]) != nil else {
            return nil
        }
        return (kind, parts[3])
    }
}

struct BullDailyInputQueueItem: Equatable, Sendable {
    let kind: BullDailyInputKind
    let dayKey: String
    let dueHour: Int
}

@MainActor
enum BullDailyInputQueue {
    static func next(
        store: BullStore,
        preferences: AppPreferences,
        now: Date = Date()
    ) -> BullDailyInputQueueItem? {
        guard preferences.dailyInputRemindersEnabled else { return nil }
        let dayKey = BullDates.key(for: now)
        guard preferences.dailyInputReminderPausedDayKey != dayKey else { return nil }
        let start = min(21, max(0, preferences.dailyInputReminderStartHour))
        let end = min(23, max(start + 1, preferences.dailyInputReminderEndHour))
        let hour = BullDates.calendar.component(.hour, from: now)
        guard hour < end else { return nil }

        let date = BullDates.startOfDay(now)
        let day = store.day(for: date)
        let observations = store.bullStateObservations(on: date)
        let plan = store.planDay(on: date)
        let fasting = store.isFasting(on: date)
        let layla = store.laylaSleepSchedule(at: now)

        var candidates: [BullDailyInputKind] = []
        if preferences.dailyInputSleepEnabled,
           (day.preventionSleepForScoring == nil || day.vigourSleepForScoring == nil) {
            candidates.append(.sleep)
        }
        if preferences.dailyInputBullStateEnabled,
           !observations.contains(where: { $0.kind != .naturalDesire }) {
            candidates.append(.morningErection)
        }
        if preferences.dailyInputStressEnabled,
           store.stressCheckIn(.morning, on: date) == nil {
            candidates.append(.morningStress)
        }
        if preferences.dailyInputStressEnabled,
           store.pendingStressReliefLogs.contains(where: { $0.dayKey == dayKey }) {
            candidates.append(.stressRelief)
        }
        if preferences.dailyInputUrgeEnabled,
           store.pornUrgeObservations(on: date).isEmpty {
            candidates.append(.urgeCheckIn)
        }
        if preferences.dailyInputNutritionEnabled, store.bullFuelPercent(on: date) == nil {
            candidates.append(.nutrition)
        }
        if preferences.dailyInputExerciseEnabled, !fasting, let plan {
            if plan.plannedAerobicMinutes > 0 {
                let recorded = store.manualExerciseLog(on: date)?.aerobicMinutesOverride
                    ?? day.aerobicMinutes ?? 0
                if recorded < Double(plan.plannedAerobicMinutes) { candidates.append(.cardio) }
            }
            let plannedSetIDs = Set((plan.strengthExercises ?? []).flatMap { exercise in
                (1...max(1, exercise.targetSets)).map { "\(exercise.id)#\($0)" }
            })
            if !plannedSetIDs.isEmpty {
                let completedSetIDs = Set((store.strengthWorkoutLog(on: date)?.sets ?? [])
                    .filter(\.completed)
                    .map { "\($0.exerciseID)#\($0.setNumber)" })
                if plannedSetIDs.intersection(completedSetIDs).count < plannedSetIDs.count {
                    candidates.append(.strength)
                }
            }
        }
        if preferences.dailyInputBullStateEnabled,
           !observations.contains(where: { $0.healthyDesire != nil }) {
            candidates.append(.naturalDesire)
        }
        if preferences.dailyInputStressEnabled,
           store.stressCheckIn(.evening, on: date) == nil {
            candidates.append(.eveningStress)
        }

        guard let kind = candidates.first else { return nil }
        let scheduleHour: Int = {
            switch kind {
            case .sleep, .morningErection, .morningStress, .stressRelief:
                guard let wakeMS = layla?.actualFinalWakeTs ?? layla?.plannedFinalWakeTs else {
                    return kind.preferredHour
                }
                return BullDates.calendar.component(
                    .hour, from: Date(timeIntervalSince1970: wakeMS / 1_000)
                )
            case .naturalDesire, .eveningStress:
                guard let bedtimeMS = layla?.plannedBedtimeTs else { return kind.preferredHour }
                let offsetHours = kind == .naturalDesire ? 3 : 1
                let target = Date(timeIntervalSince1970: bedtimeMS / 1_000)
                    .addingTimeInterval(Double(-offsetHours) * 3_600)
                return BullDates.calendar.component(.hour, from: target)
            default:
                return kind.preferredHour
            }
        }()
        return BullDailyInputQueueItem(
            kind: kind,
            dayKey: dayKey,
            dueHour: max(start, min(end - 1, scheduleHour))
        )
    }
}
