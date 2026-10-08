import Foundation

enum BullDates {
    nonisolated static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .autoupdatingCurrent
        return c
    }

    /// Civil-date key. Avoids adding/subtracting 86,400,000 ms, which breaks over DST.
    nonisolated static func key(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    nonisolated static func date(from key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        var dc = DateComponents()
        dc.calendar = calendar
        dc.timeZone = .autoupdatingCurrent
        dc.year = p[0]; dc.month = p[1]; dc.day = p[2]; dc.hour = 12
        return calendar.date(from: dc)
    }

    nonisolated static func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    nonisolated static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    nonisolated static func sameDay(_ a: Date, _ b: Date) -> Bool { calendar.isDate(a, inSameDayAs: b) }

    nonisolated static func daysAgo(_ days: Int) -> Date { addingDays(-days, to: Date()) }

    nonisolated static func dateRange(last days: Int, endingAt end: Date = Date()) -> [Date] {
        guard days > 0 else { return [] }
        return (0..<days).reversed().map { addingDays(-$0, to: end) }
    }
}

// Native events freeze their local civil date so travelling across time zones later
// cannot move an urge/lapse/wet-dream into a neighbouring day. Legacy PWA events are
// assigned a dayKey once when they are first imported into native Bull.
extension UrgeEvent {
    nonisolated var bullDayKey: String { dayKey ?? BullDates.key(for: date) }
    nonisolated var bullCivilDate: Date { BullDates.date(from: bullDayKey) ?? date }
}

extension RelapseEvent {
    nonisolated var bullDayKey: String { dayKey ?? BullDates.key(for: date) }
    nonisolated var bullCivilDate: Date { BullDates.date(from: bullDayKey) ?? date }
}

extension WetDreamEvent {
    nonisolated var bullDayKey: String { dayKey ?? BullDates.key(for: date) }
    nonisolated var bullCivilDate: Date { BullDates.date(from: bullDayKey) ?? date }
}

extension SexualCheckIn {
    nonisolated var bullDayKey: String { dayKey }
    nonisolated var bullCivilDate: Date { BullDates.date(from: dayKey) ?? date }
}
