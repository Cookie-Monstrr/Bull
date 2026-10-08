import SwiftUI

struct MonthHistoryView: View {
    @EnvironmentObject private var store: BullStore
    @Environment(\.dismiss) private var dismiss
    @State private var monthOffset = 0

    private var monthDate: Date {
        let now = Date()
        let comps = BullDates.calendar.dateComponents([.year, .month], from: now)
        let first = BullDates.calendar.date(from: comps) ?? now
        return BullDates.calendar.date(byAdding: .month, value: monthOffset, to: first) ?? first
    }

    private var days: [Date?] {
        let c = BullDates.calendar
        guard let range = c.range(of: .day, in: .month, for: monthDate) else { return [] }
        let firstWeekday = c.component(.weekday, from: monthDate) - 1
        var out = Array<Date?>(repeating: nil, count: firstWeekday)
        for day in range {
            var comps = c.dateComponents([.year, .month], from: monthDate)
            comps.day = day; comps.hour = 12
            out.append(c.date(from: comps))
        }
        return out
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(monthDate.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)
                    Spacer()
                    Button { if monthOffset < 0 { monthOffset += 1 } } label: { Image(systemName: "chevron.right") }
                        .disabled(monthOffset >= 0)
                }
                .padding(.horizontal)

                HStack {
                    ForEach(Array(["S","M","T","W","T","F","S"].enumerated()), id: \.offset) { _, d in
                        Text(d).font(.caption2.weight(.bold)).foregroundStyle(BullTheme.muted).frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                        if let date { dayCell(date) } else { Color.clear.frame(height: 62) }
                    }
                }
                .padding(.horizontal)

                BullCard {
                    HStack(spacing: 14) {
                        legendBar(color: BullTheme.crimson, text: "Urge")
                        legendBar(color: BullTheme.goldDark, text: "Bull")
                        legendSymbol(systemName: "circle.fill", color: BullTheme.crimson, text: "Lapse")
                        legendSymbol(systemName: "moon.fill", color: BullTheme.ink, text: "Wet Dream")
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            .padding(.top)
            .background(BullTheme.ivory.ignoresSafeArea())
            .navigationTitle("Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let key = BullDates.key(for: date)
        let future = BullDates.startOfDay(date) > BullDates.startOfDay(Date())
        let hasData = store.data.days[key] != nil || store.data.fourScoreSnapshots[key] != nil ||
            store.data.relapses.contains { $0.bullDayKey == key && store.countsAsLapse($0) }
        let snapshot = store.fourScoreSnapshot(on: date)
        let relapse = store.data.relapses.contains { $0.bullDayKey == key && store.countsAsLapse($0) }
        let wet = store.data.wetDreams.contains { $0.bullDayKey == key }

        return Button {
            guard !future else { return }
            store.selectedDate = date
            dismiss()
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topLeading) {
                    Text("\(BullDates.calendar.component(.day, from: date))")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    HStack(spacing: 3) {
                        if relapse { Circle().fill(BullTheme.crimson).frame(width: 6, height: 6) }
                        if wet { Image(systemName: "moon.fill").font(.system(size: 7)) }
                    }
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                }
                .frame(maxWidth: .infinity, minHeight: 14, alignment: .topLeading)
                Spacer(minLength: 0)
                VStack(spacing: 3) {
                    historyBar(snapshot?.urgeState, color: BullTheme.crimson)
                    historyBar(snapshot?.bullState, color: BullTheme.gold)
                }
            }
            .padding(7)
            .frame(height: 62)
            .foregroundStyle(BullTheme.ink)
            .background(future ? BullTheme.field : hasData ? BullTheme.gold.opacity(0.08) : BullTheme.paper)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(BullTheme.hairline))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(future)
    }

    private func historyBar(_ value: Double?, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.55))
                if let value {
                    Capsule().fill(color)
                        .frame(width: geo.size.width * max(0, min(1, value / 100)))
                }
            }
        }
        .frame(height: 3)
    }

    private func legendBar(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 12, height: 3)
            Text(text)
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(BullTheme.secondary)
    }

    private func legendSymbol(systemName: String, color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemName).font(.system(size: 7)).foregroundStyle(color)
            Text(text)
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(BullTheme.secondary)
    }
}
