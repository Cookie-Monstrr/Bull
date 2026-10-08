import Foundation
import SwiftUI
import WidgetKit
import Charts

private enum WidgetSharedStore {
    static let appGroupIdentifier = BullFigureSnapshot.appGroupIdentifier
}

private extension BullFigureSnapshot {
    static var placeholder: Self {
        Self(bullState: 58, urgeState: 34, bullRoutine: 72, urgeRoutine: 61, updatedAt: Date())
    }
    static var stored: Self {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let raw = defaults.data(forKey: payloadKey), raw.count < 4_096,
              let value = try? JSONDecoder().decode(Self.self, from: raw) else {
            return .empty(at: Date())
        }
        return value
    }
}

struct BullScoreEntry: TimelineEntry {
    let date: Date
    let snapshot: BullFigureSnapshot
    var currentSnapshot: BullFigureSnapshot { snapshot.current(on: date) }
}

private struct BullScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> BullScoreEntry {
        BullScoreEntry(date: Date(), snapshot: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (BullScoreEntry) -> Void) {
        completion(BullScoreEntry(date: Date(), snapshot: context.isPreview ? .placeholder : .stored))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BullScoreEntry>) -> Void) {
        let now = Date()
        let snapshot = BullFigureSnapshot.stored
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        let refresh = min(midnight, now.addingTimeInterval(30 * 60))
        completion(Timeline(entries: [
            BullScoreEntry(date: now, snapshot: snapshot),
            BullScoreEntry(date: midnight, snapshot: .empty(at: midnight))
        ], policy: .after(refresh)))
    }
}

private enum WidgetPalette {
    static let oxblood = Color(red: 0.155, green: 0.030, blue: 0.040)
    static let oxbloodLight = Color(red: 0.400, green: 0.114, blue: 0.106)
    static let cream = Color(red: 1.000, green: 0.953, blue: 0.855)
    static let gold = Color(red: 0.788, green: 0.588, blue: 0.173)
    static let crimson = Color(red: 0.714, green: 0.184, blue: 0.169)
}

private struct FigurePairView: View {
    let snapshot: BullFigureSnapshot
    var bullDomain = false

    private var characters: [BullFigureCharacter] {
        bullDomain ? [.provider, .bull] : [.angel, .devil]
    }

    var body: some View {
        GeometryReader { proxy in
            let footerHeight = max(36, proxy.size.height * 0.23)
            let artHeight = max(1, proxy.size.height - footerHeight - 7)
            let columnWidth = (proxy.size.width - 1) / 2
            HStack(spacing: 0) {
                column(characters[0], width: columnWidth, artHeight: artHeight, footerHeight: footerHeight)
                Rectangle().fill(WidgetPalette.cream.opacity(0.2)).frame(width: 1)
                column(characters[1], width: columnWidth, artHeight: artHeight, footerHeight: footerHeight)
            }
        }
        .padding(.horizontal, 7)
        .padding(.top, 4)
        .padding(.bottom, 7)
        .foregroundStyle(WidgetPalette.cream)
        .privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(characters.map {
            let value = snapshot.score(for: $0)
            return "\($0.title), \(value == nil ? "no data" : BullFigureScore.text(value))"
        }.joined(separator: ". "))
        .containerBackground(for: .widget) {
            ZStack {
                LinearGradient(colors: [WidgetPalette.oxblood, WidgetPalette.oxbloodLight],
                               startPoint: .leading, endPoint: .trailing)
                Circle().fill(WidgetPalette.crimson.opacity(0.11))
                    .frame(width: 250, height: 250).offset(x: 150, y: -85)
                Circle().fill(WidgetPalette.gold.opacity(0.07))
                    .frame(width: 220, height: 220).offset(x: -155, y: 130)
            }
        }
    }

    private func column(_ character: BullFigureCharacter, width: CGFloat,
                        artHeight: CGFloat, footerHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            BullFigureArtwork(character: character, score: snapshot.score(for: character))
                .frame(width: width - 6, height: artHeight, alignment: .bottom)
                .frame(width: width, height: artHeight + 7, alignment: .top)
            ZStack(alignment: .top) {
                Rectangle().fill(WidgetPalette.cream.opacity(0.035))
                Rectangle().fill(WidgetPalette.cream.opacity(0.18)).frame(height: 1)
                Text(BullFigureScore.text(snapshot.score(for: character)))
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: width, height: footerHeight, alignment: .center)
            }
            .frame(width: width, height: footerHeight)
        }
        .frame(width: width)
    }
}

struct BullFaceOffWidget: Widget {
    let kind = "BullFaceOffWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BullScoreProvider()) { entry in
            FigurePairView(snapshot: entry.currentSnapshot)
        }
        .configurationDisplayName("Urge")
        .description("Urge Fuel and Urge State, paired together.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct BullRoutineFiguresWidget: Widget {
    let kind = "BullRoutineFiguresWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BullScoreProvider()) { entry in
            FigurePairView(snapshot: entry.currentSnapshot, bullDomain: true)
                .widgetURL(URL(string: "bull://priorities"))
        }
        .configurationDisplayName("Bull")
        .description("Bull Fuel and Bull State, paired together.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

private extension BullWidgetChartsSnapshot {
    static var stored: Self {
        guard let defaults = UserDefaults(suiteName: BullFigureSnapshot.appGroupIdentifier),
              let raw = defaults.data(forKey: payloadKey), raw.count < 64_000,
              let value = try? JSONDecoder().decode(Self.self, from: raw) else {
            return .empty(at: Date())
        }
        return value
    }

    static var placeholder: Self {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date()).addingTimeInterval(-29 * 86_400)
        let points = (0..<30).map { index in
            let phase = Double(index) / 29
            return BullWidgetChartPoint(
                date: calendar.date(byAdding: .day, value: index, to: start) ?? start,
                urgeRoutine: 52 + phase * 28 + sin(Double(index) * 0.6) * 7,
                urgeState: 58 - phase * 24 + cos(Double(index) * 0.7) * 8,
                preventionSleep: 48 + phase * 30,
                stressRegulation: 42 + phase * 35 + sin(Double(index) * 0.5) * 8,
                environmentProtection: 70 + cos(Double(index) * 0.35) * 12
            )
        }
        return Self(points: points, updatedAt: Date())
    }
}

private struct BullChartEntry: TimelineEntry {
    let date: Date
    let snapshot: BullWidgetChartsSnapshot
}

private struct BullChartProvider: TimelineProvider {
    func placeholder(in context: Context) -> BullChartEntry {
        BullChartEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BullChartEntry) -> Void) {
        completion(BullChartEntry(date: Date(), snapshot: context.isPreview ? .placeholder : .stored))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BullChartEntry>) -> Void) {
        let now = Date()
        completion(Timeline(
            entries: [BullChartEntry(date: now, snapshot: .stored)],
            policy: .after(now.addingTimeInterval(6 * 3_600))
        ))
    }
}

private struct ThirtyDayChartView: View {
    enum Mode: Equatable { case overview, breakdown }
    let snapshot: BullWidgetChartsSnapshot
    let mode: Mode

    private var points: [BullWidgetChartPoint] { Array(snapshot.points.suffix(30)) }
    private var axisDates: [Date] {
        guard let first = points.first?.date, let last = points.last?.date else { return [] }
        let middle = points[points.count / 2].date
        return [first, middle, last]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(mode == .overview ? "Urge Overview" : "Urge Fuel Breakdown")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Spacer()
                Text("30 DAYS").font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetPalette.cream.opacity(0.72))
            }
            if points.isEmpty {
                Spacer()
                Text("Open Bull to Refresh")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                legend
                Chart {
                    if mode == .overview {
                        ForEach(points) { point in
                            if let value = point.urgeRoutine {
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Fuel", value),
                                    series: .value("Series", "Fuel")
                                )
                                    .foregroundStyle(WidgetPalette.gold)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                            }
                            if let value = point.urgeState {
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("State", value),
                                    series: .value("Series", "State")
                                )
                                    .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.40))
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                            }
                        }
                    } else {
                        ForEach(points) { point in
                            if let value = point.preventionSleep {
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Sleep", value),
                                    series: .value("Series", "Sleep")
                                )
                                    .foregroundStyle(WidgetPalette.gold)
                                    .lineStyle(StrokeStyle(lineWidth: 1.8))
                            }
                            if let value = point.stressRegulation {
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Stress", value),
                                    series: .value("Series", "Stress")
                                )
                                    .foregroundStyle(WidgetPalette.cream)
                                    .lineStyle(StrokeStyle(lineWidth: 1.8))
                            }
                            if let value = point.environmentProtection {
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Environment", value),
                                    series: .value("Series", "Environment")
                                )
                                    .foregroundStyle(Color(red: 0.50, green: 0.82, blue: 0.55))
                                    .lineStyle(StrokeStyle(lineWidth: 1.8))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) {
                        AxisGridLine().foregroundStyle(WidgetPalette.cream.opacity(0.18))
                        AxisValueLabel().foregroundStyle(WidgetPalette.cream.opacity(0.82))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: axisDates) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .foregroundStyle(WidgetPalette.cream.opacity(0.82))
                    }
                }
                .chartYAxisLabel("Score")
                .chartXAxisLabel("Date")
                .chartLegend(.hidden)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .foregroundStyle(WidgetPalette.cream)
        .privacySensitive()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [WidgetPalette.oxblood, WidgetPalette.oxbloodLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var legend: some View {
        if mode == .overview {
            HStack(spacing: 12) {
                legendItem("Fuel", color: WidgetPalette.gold, value: average(\.urgeRoutine))
                legendItem("State", color: Color(red: 1.0, green: 0.42, blue: 0.40), value: average(\.urgeState))
            }
        } else {
            HStack(spacing: 9) {
                legendItem("Sleep", color: WidgetPalette.gold, value: average(\.preventionSleep))
                legendItem("Stress", color: WidgetPalette.cream, value: average(\.stressRegulation))
                legendItem("Environment", color: Color(red: 0.50, green: 0.82, blue: 0.55), value: average(\.environmentProtection))
            }
        }
    }

    private func legendItem(_ label: String, color: Color, value: Int?) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).lineLimit(1)
            Text(value.map { String($0) } ?? "—").fontWeight(.bold).monospacedDigit()
        }
        .font(.system(size: 9))
        .minimumScaleFactor(0.75)
    }

    private func average(_ keyPath: KeyPath<BullWidgetChartPoint, Double?>) -> Int? {
        let values = points.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        return Int((values.reduce(0, +) / Double(values.count)).rounded())
    }
}

struct BullUrgeOverviewChartWidget: Widget {
    let kind = "BullUrgeOverviewChartWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BullChartProvider()) { entry in
            ThirtyDayChartView(snapshot: entry.snapshot, mode: .overview)
                .widgetURL(URL(string: "bull://stats?chart=urge-overview"))
        }
        .configurationDisplayName("Urge Overview · 30 Days")
        .description("Urge Fuel and Urge State over 30 completed days.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct BullUrgeBreakdownChartWidget: Widget {
    let kind = "BullUrgeBreakdownChartWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BullChartProvider()) { entry in
            ThirtyDayChartView(snapshot: entry.snapshot, mode: .breakdown)
                .widgetURL(URL(string: "bull://stats?chart=urge-breakdown"))
        }
        .configurationDisplayName("Urge Fuel Breakdown · 30 Days")
        .description("Sleep, stress and environment components over 30 completed days.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

// A separate, deliberately narrow contract. No BullData decoding in this extension.
private struct PriorityAction: Codable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var symbol: String
    var weightLabel: String
    var progress: Double?
    var rank: Double
}

private struct PrioritiesSnapshot: Codable {
    var actions: [PriorityAction]
    var updatedAt: Date
    var validUntil: Date

    static var current: Self? {
        guard let defaults = UserDefaults(suiteName: WidgetSharedStore.appGroupIdentifier),
              let raw = defaults.data(forKey: "bull-widget-priorities-v1"), raw.count < 32_768 else { return nil }
        return try? JSONDecoder().decode(Self.self, from: raw)
    }
    static var placeholder: Self {
        Self(actions: [
            PriorityAction(id: "cardio", title: "Cardio · 30 min remaining", detail: "Follow today's plan; sync if done", symbol: "heart.fill", weightLabel: "B 40%", progress: 0.25, rank: 40),
            PriorityAction(id: "stress", title: "Evening stress check-in", detail: "Record how you feel", symbol: "leaf.fill", weightLabel: "U 35%", progress: nil, rank: 35),
            PriorityAction(id: "fuel", title: "Follow / log Nutrition", detail: "Today's food-plan adherence", symbol: "fork.knife", weightLabel: "B 20%", progress: nil, rank: 20)
        ], updatedAt: Date(), validUntil: Date().addingTimeInterval(1_800))
    }
}

private struct PrioritiesEntry: TimelineEntry {
    var date: Date
    var snapshot: PrioritiesSnapshot?
    var isCurrent: Bool {
        guard let snapshot else { return false }
        return snapshot.updatedAt <= date.addingTimeInterval(60) && snapshot.validUntil > date &&
            Calendar.current.isDate(snapshot.updatedAt, inSameDayAs: date)
    }
}

private struct PrioritiesProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrioritiesEntry { PrioritiesEntry(date: Date(), snapshot: .placeholder) }
    func getSnapshot(in context: Context, completion: @escaping (PrioritiesEntry) -> Void) {
        completion(PrioritiesEntry(date: Date(), snapshot: context.isPreview ? .placeholder : .current))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrioritiesEntry>) -> Void) {
        let now = Date()
        let snapshot = PrioritiesSnapshot.current
        var entries = [PrioritiesEntry(date: now, snapshot: snapshot)]
        if let expiry = snapshot?.validUntil, expiry > now {
            entries.append(PrioritiesEntry(date: expiry, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

private struct PrioritiesView: View {
    let entry: PrioritiesEntry

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("TODAY'S PRIORITIES").font(.system(size: 11, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(WidgetPalette.cream.opacity(0.8))
                if entry.isCurrent, let snapshot = entry.snapshot {
                    let limit = proxy.size.height < 140 ? 2 : 3
                    if snapshot.actions.isEmpty {
                        Spacer(minLength: 0)
                        Text("No pending actions identified").font(.system(size: 14, weight: .semibold))
                        Text("Tap to review your current plan.").font(.system(size: 11))
                        Spacer(minLength: 0)
                    } else {
                        ForEach(Array(snapshot.actions.prefix(limit))) { action in
                            HStack(spacing: 9) {
                                Image(systemName: action.symbol)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(action.id == "environment" ? WidgetPalette.cream : WidgetPalette.gold)
                                    .frame(width: 19)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(action.title).font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1).minimumScaleFactor(0.92)
                                    if let progress = action.progress, progress.isFinite {
                                        GeometryReader { bar in
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(WidgetPalette.cream.opacity(0.12))
                                                Capsule().fill(WidgetPalette.gold).frame(width: bar.size.width * min(1, max(0, progress)))
                                            }
                                        }.frame(height: 3)
                                    }
                                }
                            }
                            .frame(maxHeight: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(action.title). \(action.detail).")
                        }
                        Spacer(minLength: 0)
                        if snapshot.actions.count > limit {
                            Text("+\(snapshot.actions.count - limit) More")
                                .font(.system(size: 11))
                                .foregroundStyle(WidgetPalette.cream.opacity(0.8))
                        }
                    }
                } else {
                    Spacer()
                    Text("Open Bull to refresh").font(.system(size: 16, weight: .semibold))
                    Text("Your next actions need a current update.").font(.system(size: 11))
                    Spacer()
                }
            }
            .foregroundStyle(WidgetPalette.cream)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .privacySensitive()
        .containerBackground(for: .widget) {
            LinearGradient(colors: [WidgetPalette.oxblood, WidgetPalette.oxbloodLight], startPoint: .leading, endPoint: .trailing)
        }
        .widgetURL(URL(string: "bull://priorities"))
    }
}

struct BullPrioritiesWidget: Widget {
    let kind = "BullPrioritiesWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrioritiesProvider()) { entry in PrioritiesView(entry: entry) }
            .configurationDisplayName("Today's Priorities")
            .description("Pending actions. Tap to review or log in Bull.")
            .supportedFamilies([.systemMedium])
            .contentMarginsDisabled()
    }
}

@main
struct BullWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BullFaceOffWidget()
        BullRoutineFiguresWidget()
        BullPrioritiesWidget()
        BullUrgeOverviewChartWidget()
        BullUrgeBreakdownChartWidget()
    }
}

#Preview("Urge", as: .systemMedium) {
    BullFaceOffWidget()
} timeline: {
    BullScoreEntry(date: .now, snapshot: .placeholder)
}

#Preview("Today's Priorities", as: .systemMedium) {
    BullPrioritiesWidget()
} timeline: {
    PrioritiesEntry(date: .now, snapshot: .placeholder)
}

#Preview("Bull", as: .systemMedium) {
    BullRoutineFiguresWidget()
} timeline: {
    BullScoreEntry(date: .now, snapshot: .placeholder)
}

#Preview("Urge Overview", as: .systemMedium) {
    BullUrgeOverviewChartWidget()
} timeline: {
    BullChartEntry(date: .now, snapshot: .placeholder)
}

#Preview("Urge Breakdown", as: .systemMedium) {
    BullUrgeBreakdownChartWidget()
} timeline: {
    BullChartEntry(date: .now, snapshot: .placeholder)
}
