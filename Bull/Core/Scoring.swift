import Foundation

// MARK: - Calendar helpers

/// Calendars used by scheduling. Injectable so tests can pin a timezone and so
/// the hijri variant can be swapped if it turns out ICU-in-JS and
/// Foundation-on-Apple disagree (see `ScoringParityTests.fastingCases`).
public struct ScoringCalendars: Sendable {
    public var gregorian: Calendar
    public var hijri: Calendar

    public init(
        timeZone: TimeZone = .current,
        hijriIdentifier: Calendar.Identifier = .islamic
    ) {
        var g = Calendar(identifier: .gregorian)
        g.timeZone = timeZone
        var h = Calendar(identifier: hijriIdentifier)
        h.timeZone = timeZone
        self.gregorian = g
        self.hijri = h
    }

    public static let current = ScoringCalendars()
}

/// Weekday using JavaScript's `Date.getDay()` convention: 0 = Sunday ... 6 = Saturday.
/// Foundation's `.weekday` is 1-based from Sunday, hence the -1.
public func jsWeekday(_ date: Date, calendars: ScoringCalendars = .current) -> Int {
    calendars.gregorian.component(.weekday, from: date) - 1
}

/// Day-of-month in the hijri calendar. Mirrors `hijriDay()` in app.js.
public func hijriDay(_ date: Date, calendars: ScoringCalendars = .current) -> Int? {
    calendars.hijri.component(.day, from: date)
}

/// Mirrors `fastingSuggested()`. The lunar "white days" are hijri 13-15.
public func fastingSuggested(
    _ date: Date, mode: FastMode, calendars: ScoringCalendars = .current
) -> Bool {
    let h = hijriDay(date, calendars: calendars)
    let lunar = h.map { $0 >= 13 && $0 <= 15 } ?? false
    let dow = jsWeekday(date, calendars: calendars)
    let weekly = (dow == 1 || dow == 4)   // Monday or Thursday
    switch mode {
    case .lunar: return lunar
    case .weekly: return weekly
    case .both: return weekly || lunar
    }
}

// MARK: - Scheduling

/// Mirrors `scheduledOn()`. NOTE the empty-array case: `[]` means EVERY day,
/// not "no days".
public func scheduledOn(_ item: Item, on date: Date, calendars: ScoringCalendars = .current) -> Bool {
    switch item.freq {
    case .daily, .none:
        return true
    case .days(let days):
        if days.isEmpty { return true }
        return days.contains(jsWeekday(date, calendars: calendars))
    }
}

/// Mirrors `adherenceExpected()`. Fasting overrides `freq` entirely.
public func adherenceExpected(
    _ item: Item, on date: Date, settings: Settings, calendars: ScoringCalendars = .current
) -> Bool {
    if item.isFastingAuto {
        return fastingSuggested(date, mode: settings.fastMode, calendars: calendars)
    }
    return scheduledOn(item, on: date, calendars: calendars)
}

// MARK: - Relapse Risk

/// Scoring model version used for frozen historical snapshots.
///
/// Version 6 is Bull v2.9's four-component Urge Risk and output-only Sexual Vigour model.
/// Existing v1–v5 snapshots remain frozen and are never silently recalculated.
public let currentScoringVersion = 6

/// Bull keeps closely related risk factors inside four bounded domains so, for
/// example, poor Sleep + low HRV-derived Recovery cannot inflate Risk as though
/// they were wholly independent. Distinct domains can still stack strongly.
public struct RiskBreakdown: Equatable, Sendable {
    public var baseline: Int
    public var rawDomains: [RiskDomain: Int]
    public var cappedDomains: [RiskDomain: Int]
    public var total: Int

    public init(baseline: Int, rawDomains: [RiskDomain: Int], cappedDomains: [RiskDomain: Int], total: Int) {
        self.baseline = baseline
        self.rawDomains = rawDomains
        self.cappedDomains = cappedDomains
        self.total = total
    }
}

/// Backward-compatible domain inference for old backups that predate Item.riskDomain.
public func effectiveRiskDomain(for item: Item) -> RiskDomain {
    if let explicit = item.riskDomain { return explicit }
    switch item.id {
    case "contentAccess", "checkout", "lonely": return .exposure
    case "sleepLow", "recoveryLow", "sickFlag", "junk", "coldplunge", "nasalclear": return .physiology
    case "purposeLow", "purposeHigh", "travelFlag": return .structure
    case "accountabilityGap", "urgeSurvivalBonus": return .protection
    default:
        return item.kind == .risk ? .exposure : .protection
    }
}

/// Net contribution caps. Positive caps prevent correlated clusters from being
/// counted as separate giant risks; negative caps stop a pile of protective
/// habits in one domain from erasing unrelated vulnerability elsewhere.
public func riskDomainBounds(_ domain: RiskDomain) -> ClosedRange<Int> {
    switch domain {
    case .exposure: return -8...45
    case .physiology: return -10...25
    case .structure: return -12...25
    case .protection: return -18...20
    }
}

/// Version-5 predictive core Risk with domain balancing.
public func riskBreakdown(
    day: DayRecord,
    items: [Item],
    accountabilityPenalty: Double = 0,
    accountabilityEnabled: Bool = false,
    intentionWeight: Weight = .med,
    sleepRiskWeight: Weight = .med,
    recoveryRiskWeight: Weight = .med,
    calendars: ScoringCalendars = .current
) -> RiskBreakdown {
    func weightOf(_ id: String, fallback: Weight) -> Weight {
        items.first(where: { $0.id == id && !$0.isArchived })?.weight ?? fallback
    }
    func scaleOf(_ id: String, fallback: Weight) -> Double {
        weightOf(id, fallback: fallback).scale
    }
    func domainForID(_ id: String, fallback: RiskDomain) -> RiskDomain {
        guard let item = items.first(where: { $0.id == id && !$0.isArchived }) else { return fallback }
        return effectiveRiskDomain(for: item)
    }

    var raw = Dictionary(uniqueKeysWithValues: RiskDomain.allCases.map { ($0, 0) })
    func add(_ points: Int, to domain: RiskDomain) { raw[domain, default: 0] += points }

    let flagged = day.isFlagged
    let fastingExcuse = day.checks["fasting"] == true
    for item in items where !item.isArchived && item.list.feedsPrevention && item.kind.isToggleable {
        if item.isExcusable && (flagged || (fastingExcuse && item.id != "fasting")) { continue }
        let v = day.checks[item.id]
        let domain = effectiveRiskDomain(for: item)
        if item.kind == .risk {
            if v == true { add(item.weight.riskPoints, to: domain) }
        } else if v == true {
            add(-item.weight.protectivePoints, to: domain)
        }
    }

    if day.sick {
        add(weightOf("sickFlag", fallback: .med).riskPoints,
            to: domainForID("sickFlag", fallback: .physiology))
    }
    if day.travelling {
        add(weightOf("travelFlag", fallback: .high).riskPoints,
            to: domainForID("travelFlag", fallback: .structure))
    }

    if items.contains(where: { $0.id == "contentAccess" && !$0.isArchived }) {
        let s = scaleOf("contentAccess", fallback: .high)
        let domain = domainForID("contentAccess", fallback: .exposure)
        if day.access == .high { add(jsRound(25 * s), to: domain) }
        else if day.access == .med { add(jsRound(12 * s), to: domain) }
    }

    // v2.7 removes the arbitrary Recovery<40 switch. HRV is handled as a continuous,
    // personal-baseline hypothesis by the v2.7 risk layer. Sleep remains a strong personal
    // predictor but is continuous: a score of 64 is not categorically different from 65.
    if let sl = day.sleep {
        let deficit = max(0, min(1, (85 - sl) / 85))
        if deficit > 0 {
            add(jsRound(20 * sleepRiskWeight.scale * deficit),
                to: domainForID("sleepLow", fallback: .physiology))
        }
    }

    // Purpose, legacy intentions and v2.8's Morning Commitment are collected
    // prospectively but deliberately contribute no automatic Risk points.

    if accountabilityEnabled {
        add(jsRound(accountabilityPenalty * scaleOf("accountabilityGap", fallback: .high)),
            to: domainForID("accountabilityGap", fallback: .protection))
    }

    var capped: [RiskDomain: Int] = [:]
    for domain in RiskDomain.allCases {
        let bounds = riskDomainBounds(domain)
        capped[domain] = min(bounds.upperBound, max(bounds.lowerBound, raw[domain, default: 0]))
    }
    let total = max(0, min(100, 15 + capped.values.reduce(0, +)))
    return RiskBreakdown(baseline: 15, rawDomains: raw, cappedDomains: capped, total: total)
}

public func riskScore(
    day: DayRecord,
    items: [Item],
    accountabilityPenalty: Double = 0,
    accountabilityEnabled: Bool = false,
    intentionWeight: Weight = .med,
    sleepRiskWeight: Weight = .med,
    recoveryRiskWeight: Weight = .med,
    calendars: ScoringCalendars = .current
) -> Int {
    riskBreakdown(
        day: day, items: items, accountabilityPenalty: accountabilityPenalty,
        accountabilityEnabled: accountabilityEnabled, intentionWeight: intentionWeight,
        sleepRiskWeight: sleepRiskWeight, recoveryRiskWeight: recoveryRiskWeight,
        calendars: calendars
    ).total
}

/// Exact scoring-v2 arithmetic retained for the parity fixture and for diagnosing
/// historical snapshots. New product code should call `riskScore` instead.
public func legacyRiskScoreV2(
    day: DayRecord,
    items: [Item],
    accountabilityPenalty: Double = 0,
    accountabilityEnabled: Bool = false,
    intentionWeight: Weight = .med,
    sleepRiskWeight: Weight = .med,
    recoveryRiskWeight: Weight = .med,
    calendars: ScoringCalendars = .current
) -> Int {
    func weightOf(_ id: String, fallback: Weight) -> Weight {
        items.first(where: { $0.id == id })?.weight ?? fallback
    }
    func scaleOf(_ id: String, fallback: Weight) -> Double {
        weightOf(id, fallback: fallback).scale
    }

    var r = 15
    let flagged = day.isFlagged
    let fastingExcuse = day.checks["fasting"] == true
    for item in items where !item.isArchived && item.list.feedsPrevention && item.kind.isToggleable {
        if item.isExcusable && (flagged || (fastingExcuse && item.id != "fasting")) { continue }
        let v = day.checks[item.id]
        if item.kind == .risk {
            if v == true { r += item.weight.riskPoints }
        } else if v == true {
            r -= item.weight.protectivePoints
        }
    }
    if day.sick { r += weightOf("sickFlag", fallback: .med).riskPoints }
    if day.travelling { r += weightOf("travelFlag", fallback: .high).riskPoints }
    if items.contains(where: { $0.id == "contentAccess" }) {
        let s = scaleOf("contentAccess", fallback: .high)
        if day.access == .high { r += jsRound(25 * s) }
        else if day.access == .med { r += jsRound(12 * s) }
    }
    if items.contains(where: { $0.id == "checkout" }) {
        let s = scaleOf("checkout", fallback: .high)
        if day.checkout == .lot { r += jsRound(12 * s) }
        else if day.checkout == .few { r += jsRound(4 * s) }
    }
    if let rec = day.recovery, rec < 40 { r += jsRound(10 * recoveryRiskWeight.scale) }
    if let sl = day.sleep, sl < 65 { r += jsRound(10 * sleepRiskWeight.scale) }
    if !day.intentions.isEmpty {
        let met = day.intentions.filter(\.met).count
        r -= jsRound(Double(intentionWeight.protectivePoints) * (Double(met) / Double(day.intentions.count)))
    }
    if let p = day.purposeRating {
        if p <= 2 { r += jsRound(10 * scaleOf("purposeLow", fallback: .med)) }
        else if p >= 4 { r -= jsRound(5 * scaleOf("purposeHigh", fallback: .med)) }
    }
    if accountabilityEnabled { r += jsRound(accountabilityPenalty * scaleOf("accountabilityGap", fallback: .high)) }
    return max(0, min(100, r))
}

/// Compatibility overload for code written against the original parity port.
/// `urgesSurvived` and `hadRelapse` remain intentionally ignored in predictive scoring.
@available(*, deprecated, message: "Use predictive riskScore without urge/relapse outcomes")
public func riskScore(
    day: DayRecord,
    items: [Item],
    urgesSurvived: Int,
    hadRelapse: Bool,
    accountabilityPenalty: Double = 0,
    intentionWeight: Weight = .med,
    sleepRiskWeight: Weight = .med,
    recoveryRiskWeight: Weight = .med,
    calendars: ScoringCalendars = .current
) -> Int {
    riskScore(
        day: day, items: items, accountabilityPenalty: accountabilityPenalty,
        accountabilityEnabled: accountabilityPenalty > 0,
        intentionWeight: intentionWeight, sleepRiskWeight: sleepRiskWeight,
        recoveryRiskWeight: recoveryRiskWeight, calendars: calendars
    )
}

/// Decides whether a day has enough on it to count toward Risk averages at all.
public func riskLogged(day: DayRecord?, items: [Item]) -> Bool {
    guard let day else { return false }
    let anyRisk = items.contains { item in
        !item.isArchived && item.list.feedsPrevention && day.checks[item.id] != nil
    }
    return anyRisk || day.access != nil ||
        day.sleep != nil || day.recovery != nil || day.hrv != nil || day.stressLevel != nil ||
        day.sick || day.travelling
}

// MARK: - Sexual Vigour

public struct VigourResult: Equatable, Sendable {
    public var done: Double
    public var total: Double

    public init(done: Double, total: Double) {
        self.done = done
        self.total = total
    }

    public var percent: Double { pctFrom(done: done, total: total) }
}

public func pctFrom(done: Double, total: Double) -> Double {
    guard total != 0 else { return 0 }
    return max(0, min(100, (done / total) * 100))
}

/// Version-3 Vigour. Items are first normalized WITHIN their physiological bucket,
/// then each active bucket gets the same 4-point capacity. This stops a bucket with
/// many scheduled toggles from dominating simply because it has more rows. Sleep and
/// Recovery remain cross-cutting components using their configured 1-4 point weights.
public func vigourForDay(
    day: DayRecord,
    date: Date,
    items: [Item],
    settings: Settings,
    calendars: ScoringCalendars = .current
) -> VigourResult {
    let flagged = day.isFlagged
    let fastingExcuse = day.checks["fasting"] == true
    var categoryDone: [Bucket: Double] = [:]
    var categoryTotal: [Bucket: Double] = [:]

    for item in items where !item.isArchived && item.list.feedsVigour && item.kind.isToggleable {
        guard adherenceExpected(item, on: date, settings: settings, calendars: calendars) else { continue }
        if item.isExcusable && (flagged || (fastingExcuse && item.id != "fasting")) { continue }
        let bucket = item.bucket ?? .test
        let w = Double(item.effectiveVigourWeight.adherencePoints)
        categoryTotal[bucket, default: 0] += w
        let v = day.checks[item.id]
        if item.kind == .risk {
            if v == false { categoryDone[bucket, default: 0] += w }
            else if v == true { categoryDone[bucket, default: 0] -= w }
        } else if v == true {
            categoryDone[bucket, default: 0] += w
        }
    }

    // Supplements live inside Testosterone rather than acting as a fifth behavioural
    // category. Their legacy 2-point internal weight still controls their share WITHIN it.
    if !settings.supplements.isEmpty {
        let w = 2.0
        categoryTotal[.test, default: 0] += w
        let taken = settings.supplements.filter { day.supplementsTaken[$0] == true }.count
        categoryDone[.test, default: 0] += w * (Double(taken) / Double(settings.supplements.count))
    }

    var total = 0.0
    var done = 0.0
    let bucketCapacity = 4.0
    for bucket in Bucket.allCases {
        guard let rawTotal = categoryTotal[bucket], rawTotal > 0 else { continue }
        let rawDone = categoryDone[bucket, default: 0]
        let adherence = max(-1, min(1, rawDone / rawTotal))
        total += bucketCapacity
        done += bucketCapacity * adherence
    }

    let sw = Double(settings.sleepWeight.adherencePoints)
    if sw > 0, let sleep = day.sleep {
        total += sw
        done += sw * max(0, min(1, sleep / 100))
    }

    let rw = Double(settings.recoveryWeight.adherencePoints)
    if rw > 0, let recovery = day.recovery {
        total += rw
        done += rw * max(0, min(1, recovery / 100))
    }

    return VigourResult(done: done, total: total)
}

/// Exact v2 Vigour arithmetic retained for parity/diagnostics.
public func legacyVigourForDayV2(
    day: DayRecord,
    date: Date,
    items: [Item],
    settings: Settings,
    calendars: ScoringCalendars = .current
) -> VigourResult {
    var total = 0.0
    var done = 0.0
    let flagged = day.isFlagged
    for item in items where !item.isArchived && item.list.feedsVigour && item.kind.isToggleable {
        guard adherenceExpected(item, on: date, settings: settings, calendars: calendars) else { continue }
        // This diagnostic must remain exact to the original v2 engine captured by
        // ScoringVectors.json. The later rule that lets a completed fast excuse
        // other activities belongs to current scoring, not frozen v2 parity.
        if item.isExcusable && flagged { continue }
        let w = Double(item.effectiveVigourWeight.adherencePoints)
        let v = day.checks[item.id]
        total += w
        if item.kind == .risk {
            if v == false { done += w }
            else if v == true { done -= w }
        } else if v == true { done += w }
    }
    if !settings.supplements.isEmpty {
        total += 2
        let taken = settings.supplements.filter { day.supplementsTaken[$0] == true }.count
        done += 2 * (Double(taken) / Double(settings.supplements.count))
    }
    let sw = Double(settings.sleepWeight.adherencePoints)
    if sw > 0, let sleep = day.sleep {
        total += sw
        done += sw * max(0, min(1, sleep / 100))
    }
    let rw = Double(settings.recoveryWeight.adherencePoints)
    if rw > 0, let recovery = day.recovery {
        total += rw
        done += rw * max(0, min(1, recovery / 100))
    }
    return VigourResult(done: done, total: total)
}

// MARK: - Bull Pressure

public enum PressureTier: Int, Codable, Comparable, CaseIterable, Sendable {
    case normal = 0
    case watch = 1
    case warning = 2
    case emergency = 3

    public static func < (lhs: PressureTier, rhs: PressureTier) -> Bool { lhs.rawValue < rhs.rawValue }

    public var label: String {
        switch self {
        case .normal: return "Normal"
        case .watch: return "Watch"
        case .warning: return "Warning"
        case .emergency: return "Emergency"
        }
    }
}

public struct PressureThresholds: Equatable, Sendable {
    public var watch: Double
    public var warning: Double
    public var emergency: Double
    public var warningDays: Int
    public var emergencyDays: Int

    public init(watch: Double = 65, warning: Double = 78, emergency: Double = 88,
                warningDays: Int = 2, emergencyDays: Int = 3) {
        self.watch = watch; self.warning = warning; self.emergency = emergency
        self.warningDays = warningDays; self.emergencyDays = emergencyDays
    }
}

public struct BullPressure: Equatable, Sendable {
    public var daily: Double
    public var compounded: Double
    public var consecutiveHighDays: Int
    public var tier: PressureTier

    public init(daily: Double, compounded: Double, consecutiveHighDays: Int, tier: PressureTier) {
        self.daily = daily; self.compounded = compounded
        self.consecutiveHighDays = consecutiveHighDays; self.tier = tier
    }
}

/// Daily pressure combines current vulnerability with depleted Vigour. It is an index,
/// NOT a probability of relapse.
public func dailyBullPressure(risk: Int, vigour: Double) -> Double {
    max(0, min(100, 0.65 * Double(risk) + 0.35 * (100 - max(0, min(100, vigour)))))
}

/// Compounds recent high-pressure days using decaying carry-over above 55. A prior
/// low-pressure day (<45) breaks the chain completely so recovery is rewarded quickly.
/// `recentDailyPressures` is ordered newest-first (yesterday, two days ago...).
public func compoundedBullPressure(today: Double, recentDailyPressures: [Double]) -> Double {
    let weights = [0.30, 0.18, 0.10, 0.05]
    var carry = 0.0
    for (index, p) in recentDailyPressures.prefix(weights.count).enumerated() {
        if p < 45 { break }
        carry += max(0, p - 55) * weights[index]
    }
    return max(0, min(100, today + carry))
}

public func bullPressureState(
    todayRisk: Int,
    todayVigour: Double,
    recentDailyPressures: [Double],
    thresholds: PressureThresholds = PressureThresholds()
) -> BullPressure {
    let daily = dailyBullPressure(risk: todayRisk, vigour: todayVigour)
    let compounded = compoundedBullPressure(today: daily, recentDailyPressures: recentDailyPressures)
    var streak = daily >= thresholds.watch ? 1 : 0
    if streak > 0 {
        for p in recentDailyPressures {
            if p >= thresholds.watch { streak += 1 } else { break }
        }
    }

    let tier: PressureTier
    if daily >= thresholds.emergency || (compounded >= thresholds.emergency && streak >= thresholds.emergencyDays) {
        tier = .emergency
    } else if compounded >= thresholds.warning && streak >= thresholds.warningDays {
        tier = .warning
    } else if compounded >= thresholds.watch {
        tier = .watch
    } else {
        tier = .normal
    }
    return BullPressure(daily: daily, compounded: compounded, consecutiveHighDays: streak, tier: tier)
}

// MARK: - Risk colour bands

public enum RiskBand: Sendable {
    case safe       // <= 25
    case caution    // <= 55
    case danger     // > 55

    public init(risk: Int) {
        if risk <= 25 { self = .safe }
        else if risk <= 55 { self = .caution }
        else { self = .danger }
    }
}
