import SwiftUI
import Charts

private enum PatternsPage: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case breakdown = "Breakdown"
    case relapses = "Relapses"
    var id: String { rawValue }
}

struct PatternsView: View {
    @EnvironmentObject private var store: BullStore
    @State private var page: PatternsPage = .overview
    @State private var window: PatternWindow = .month
    @State private var history: [StatsHistoryDay] = []
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Stats Page", selection: $page) {
                        ForEach(PatternsPage.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Time Window", selection: $window) {
                        ForEach(PatternWindow.allCases) {
                            Text($0 == .all ? "All" : $0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch page {
                    case .overview:
                        timeline(
                            "Urge Overview",
                            subtitle: "Fuel ↑ Better · State ↓ Better",
                            series: [
                                .init(id: "urgeRoutine", label: "Fuel", color: BullTheme.goldDark,
                                      values: history.map { $0.snapshot?.urgeRoutine }),
                                .init(id: "urgeState", label: "State", color: BullTheme.crimson,
                                      values: history.map { $0.snapshot?.urgeState })
                            ],
                            relapseToggle: true
                        )
                        timeline(
                            "Bull Overview",
                            subtitle: "Fuel ↑ Better · State ↑ Better",
                            series: [
                                .init(id: "bullRoutine", label: "Fuel", color: BullTheme.goldDark,
                                      values: history.map { $0.snapshot?.bullRoutine }),
                                .init(id: "bullState", label: "State", color: BullTheme.green,
                                      values: history.map { $0.snapshot?.bullState })
                            ]
                        )
                    case .breakdown:
                        breakdown("Urge Fuel Breakdown", metrics: RoutineMetric.urge,
                                  subtitle: "Daily Contributions")
                        breakdown("Bull Fuel Breakdown", metrics: RoutineMetric.bull,
                                  subtitle: "Contributions Over 7 Days")
                        fastingFactorCard
                    case .relapses:
                        timeline(
                            "Sleep & Relapses",
                            subtitle: "Sleep During the Night Before",
                            series: [
                                .init(id: "sleep", label: "Sleep", color: BullTheme.goldDark,
                                      values: history.map(\.sleepHours))
                            ],
                            unit: "Hours",
                            fixedDomain: nil,
                            relapseToggle: true
                        )
                        timeline(
                            "HRV & Relapses",
                            subtitle: "Night HRV · Uses 24 Hours When Needed",
                            series: [
                                .init(id: "hrv", label: "HRV", color: BullTheme.green,
                                      values: history.map(\.hrv)),
                                .init(id: "baseline", label: "Prior Baseline", color: BullTheme.muted,
                                      values: history.map { $0.hrv == nil ? nil : $0.hrvBaseline }, dashed: true)
                            ],
                            unit: "HRV (ms)",
                            fixedDomain: nil,
                            relapseToggle: true
                        )
                    }

                    Button { showAbout = true } label: {
                        Label("About These Charts", systemImage: "info.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BullTheme.goldDark)
                }
                .padding()
                .padding(.bottom, 32)
            }
            .background(BullTheme.ivory.ignoresSafeArea())
            .navigationTitle("Stats")
            .task(id: "\(window.rawValue)-\(store.revision)") {
                history = store.statsHistory(window: window)
            }
            .onOpenURL(perform: handleDeepLink)
            .sheet(isPresented: $showAbout) { aboutSheet }
        }
    }

    private var aboutSheet: some View {
        NavigationStack {
            List {
                Section("Using the Charts") {
                    Text("Tap or drag to view a day. Show and Hide turn each line on or off.")
                    Text("Gaps mean missing or excluded data.")
                }
                Section("Scores") {
                    Text("Bull Fuel is a rolling 7-day score. Urge Fuel, Urge State and Bull State are daily scores.")
                    Text("Higher Urge Fuel means stronger protective habits and a stronger Sorcerer.")
                    Text("A red diamond marks a logged relapse on that date. It shows timing, not cause.")
                }
                Section("Older Data") {
                    Text("Some older breakdown points may be estimated from saved data.")
                }
            }
            .navigationTitle("About These Charts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showAbout = false }
                }
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "bull", url.host == "stats" else { return }
        window = .month
        let chart = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "chart" })?.value
        page = chart == "urge-breakdown" ? .breakdown : .overview
    }

    private func timeline(
        _ title: String,
        subtitle: String,
        series: [StatsLine],
        unit: String = "",
        fixedDomain: ClosedRange<Double>? = 0...100,
        relapseToggle: Bool = false
    ) -> some View {
        StatsTimelineCard(
            title: title,
            subtitle: subtitle,
            days: history,
            lines: series,
            unit: unit,
            fixedDomain: fixedDomain,
            offersRelapses: relapseToggle
        )
        .id("\(title)-\(window.rawValue)")
    }

    private func breakdown(_ title: String, metrics: [RoutineMetric], subtitle: String) -> some View {
        timeline(
            title,
            subtitle: subtitle,
            series: metrics.enumerated().map { index, metric in
                StatsLine(
                    id: metric.id,
                    label: metric.label,
                    color: [BullTheme.goldDark, BullTheme.green, BullTheme.crimson, BullTheme.amber][index],
                    values: history.map { metric.value(in: $0.components) }
                )
            },
            unit: "Attainment (%)"
        )
    }

    private var fastingFactorCard: some View {
        BullCard {
            Text("Personal Factor")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BullTheme.muted)
            HStack {
                Label("Fasting", systemImage: "moon.stars.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                let count = history.filter(\.isFasting).count
                Text("\(count) Recorded Day\(count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(BullTheme.ink)
        }
    }
}

private struct StatsLine: Identifiable {
    var id: String
    var label: String
    var color: Color
    var values: [Double?]
    var dashed = false
}

private struct StatsMark: Identifiable {
    var id: String
    var date: Date
    var value: Double
    var segment: String
    var isolated: Bool
}

private struct StatsTimelineCard: View {
    let title: String
    let subtitle: String
    let days: [StatsHistoryDay]
    let lines: [StatsLine]
    let unit: String
    let fixedDomain: ClosedRange<Double>?
    let offersRelapses: Bool
    @State private var hidden = Set<String>()
    @State private var selectedDate: Date?
    @State private var relapsesVisible = true

    private var visible: [StatsLine] { lines.filter { !hidden.contains($0.id) } }
    private var hasValues: Bool { lines.contains { $0.values.contains { $0?.isFinite == true } } }
    private var hasRelapses: Bool { days.contains { $0.relapseCount > 0 } }
    private var domain: ClosedRange<Double> {
        if let fixedDomain { return fixedDomain }
        let values = lines.flatMap(\.values).compactMap { $0 }.filter(\.isFinite)
        let maximum = values.max() ?? (unit == "Hours" ? 10 : 100)
        return 0...max(1, maximum * 1.12)
    }
    private var dates: ClosedRange<Date> {
        let first = days.first?.date ?? BullDates.addingDays(-1, to: Date())
        let last = days.last?.date ?? first
        return first.addingTimeInterval(-43_200)...last.addingTimeInterval(43_200)
    }
    private var selectedIndex: Int? {
        guard let selectedDate, !days.isEmpty else { return nil }
        return days.indices.min {
            abs(days[$0].date.timeIntervalSince(selectedDate)) <
                abs(days[$1].date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        BullCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(BullTheme.secondary)
            }

            if selectedIndex == nil {
                summaryGrid
            }

            if hasValues || (offersRelapses && hasRelapses) {
                chart
            } else {
                Text("No Recorded Data in This Period Yet")
                    .font(.subheadline)
                    .foregroundStyle(BullTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }

            controlGrid

            if let index = selectedIndex {
                selectedDayPanel(index)
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(lines) { line in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(line.label) Average")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(line.color)
                    Text(averageValue(for: line))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    Text(recordedDaysLabel(for: line))
                        .font(.caption2)
                        .foregroundStyle(BullTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(9)
                .background(BullTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.top, 5)
    }

    private var controlGrid: some View {
        FlowLayout(spacing: 7) {
            ForEach(lines) { line in
                let isHidden = hidden.contains(line.id)
                Button {
                    if isHidden { hidden.remove(line.id) } else { hidden.insert(line.id) }
                } label: {
                    Label(
                        "\(isHidden ? "Show" : "Hide") \(line.label)",
                        systemImage: isHidden ? "eye.slash" : "eye"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(minHeight: BullTheme.controlHeight)
                    .foregroundStyle(isHidden ? BullTheme.muted : line.color)
                    .background(BullTheme.field)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            if offersRelapses {
                Button { relapsesVisible.toggle() } label: {
                    Label(
                        "\(relapsesVisible ? "Hide" : "Show") Relapses",
                        systemImage: "diamond.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(minHeight: BullTheme.controlHeight)
                    .foregroundStyle(relapsesVisible ? BullTheme.crimson : BullTheme.muted)
                    .background(BullTheme.field)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func selectedDayPanel(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(days[index].date.formatted(date: .complete, time: .omitted))
                    .font(.subheadline.weight(.bold))
                Spacer()
                Button("Clear") { selectedDate = nil }
                    .font(.caption.weight(.semibold))
            }
            ForEach(lines) { line in
                HStack {
                    Circle().fill(line.color).frame(width: 7, height: 7)
                    Text(line.label)
                    Spacer()
                    Text(dayValue(for: line, index: index)).monospacedDigit()
                }
                .font(.caption)
            }
            if offersRelapses {
                HStack {
                    Image(systemName: "diamond.fill").foregroundStyle(BullTheme.crimson)
                    Text("Relapses")
                    Spacer()
                    Text("\(days[index].relapseCount)").monospacedDigit()
                }
                .font(.caption)
            }
        }
        .padding(10)
        .background(BullTheme.gold.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var chart: some View {
        Chart {
            if offersRelapses && relapsesVisible {
                ForEach(days.filter { $0.relapseCount > 0 }) { day in
                    RuleMark(x: .value("Relapse Day", day.date))
                        .foregroundStyle(BullTheme.crimson.opacity(0.20))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    PointMark(
                        x: .value("Relapse Day", day.date),
                        y: .value("Relapse Marker", domain.upperBound * 0.96)
                    )
                    .symbol(.diamond)
                    .symbolSize(38)
                    .foregroundStyle(BullTheme.crimson)
                }
            }
            ForEach(visible) { line in
                ForEach(marks(for: line)) { mark in
                    LineMark(
                        x: .value("Date", mark.date),
                        y: .value(unit.isEmpty ? "Score" : unit, mark.value),
                        series: .value("Segment", mark.segment)
                    )
                    .foregroundStyle(line.color)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: line.dashed ? [4, 3] : []))
                    .interpolationMethod(.linear)
                    if days.count <= 31 || mark.isolated {
                        PointMark(
                            x: .value("Date", mark.date),
                            y: .value(unit.isEmpty ? "Score" : unit, mark.value)
                        )
                        .foregroundStyle(line.color)
                        .symbolSize(18)
                    }
                }
            }
            if let index = selectedIndex {
                RuleMark(x: .value("Selected Date", days[index].date))
                    .foregroundStyle(BullTheme.ink.opacity(0.35))
            }
        }
        .chartXScale(domain: dates)
        .chartYScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartYAxisLabel(unit)
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let frame = proxy.plotFrame else { return }
                                let origin = geometry[frame].origin
                                selectedDate = proxy.value(
                                    atX: value.location.x - origin.x,
                                    as: Date.self
                                )
                            }
                    )
            }
        }
        .frame(height: 190)
        .accessibilityHint("Tap or drag to inspect the nearest day")
    }

    private func averageValue(for line: StatsLine) -> String {
        format(MinimalStats.average(line.values))
    }

    private func recordedDaysLabel(for line: StatsLine) -> String {
        let count = line.values.compactMap { $0 }.filter(\.isFinite).count
        return "\(count) Recorded Day\(count == 1 ? "" : "s")"
    }

    private func dayValue(for line: StatsLine, index: Int) -> String {
        guard line.values.indices.contains(index) else { return "—" }
        return format(line.values[index])
    }

    private func format(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        if unit == "Hours" {
            return value.formatted(.number.precision(.fractionLength(1)))
        }
        return String(Int(value.rounded()))
    }

    private func marks(for line: StatsLine) -> [StatsMark] {
        var segment = 0
        var result: [StatsMark] = []
        var previousVersion: Int?
        for index in days.indices {
            guard line.values.indices.contains(index),
                  let value = line.values[index],
                  value.isFinite else {
                segment += 1
                previousVersion = nil
                continue
            }
            let version = days[index].snapshot?.scoringVersion
            if let previousVersion, version != previousVersion { segment += 1 }
            result.append(
                StatsMark(
                    id: "\(line.id)-\(days[index].id)",
                    date: days[index].date,
                    value: value,
                    segment: "\(line.id)-\(segment)",
                    isolated: false
                )
            )
            previousVersion = version
        }
        let counts = Dictionary(grouping: result, by: \.segment).mapValues(\.count)
        for index in result.indices {
            result[index].isolated = counts[result[index].segment] == 1
        }
        return result
    }
}
