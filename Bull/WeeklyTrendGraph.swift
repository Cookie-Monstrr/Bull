import SwiftUI

struct WeeklyTrendPoint: Identifiable, Equatable {
    var id: String { dayKey }
    var dayKey: String
    var date: Date
    var urgeState: Double?
    var bullState: Double?
    var urgeCount: Int
    var lapse: Bool
}

/// State outcomes only. Routine adherence belongs in the four score cards and breakdowns,
/// not on this graph. Missing observations remain visible gaps.
struct WeeklyTrendGraph: View {
    let points: [WeeklyTrendPoint]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                legend(color: BullTheme.crimson, text: "Urge State")
                legend(color: BullTheme.goldDark, text: "Bull State")
                Spacer()
            }
            GeometryReader { proxy in
                let labelWidth: CGFloat = 25
                let graphWidth = max(1, proxy.size.width - labelWidth)
                let plotTop: CGFloat = 5
                let height = max(1, proxy.size.height - 24)
                ZStack(alignment: .topLeading) {
                    ForEach([0, 25, 50, 75, 100], id: \.self) { value in
                        let y = plotTop + yPosition(Double(value), height: height)
                        Text("\(value)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(BullTheme.muted)
                            .frame(width: 22, alignment: .trailing)
                            .position(x: 11, y: y)
                        Path { path in
                            path.move(to: CGPoint(x: labelWidth, y: y))
                            path.addLine(to: CGPoint(x: labelWidth + graphWidth, y: y))
                        }
                        .stroke(BullTheme.hairline, style: StrokeStyle(lineWidth: 0.7, dash: [3, 4]))
                    }

                    segmentedPath(values: points.map(\.urgeState), width: graphWidth, height: height, xInset: labelWidth, yInset: plotTop)
                        .stroke(BullTheme.crimson, style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
                    segmentedPath(values: points.map(\.bullState), width: graphWidth, height: height, xInset: labelWidth, yInset: plotTop)
                        .stroke(BullTheme.goldDark, style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))

                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        let x = labelWidth + xPosition(index: index, width: graphWidth)
                        if let value = point.urgeState {
                            Circle()
                                .fill(BullTheme.crimson)
                                .frame(width: 10, height: 10)
                                .position(x: x, y: plotTop + yPosition(value, height: height))
                        }
                        if let value = point.bullState {
                            Circle()
                                .fill(BullTheme.goldDark)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: plotTop + yPosition(value, height: height))
                        }
                        Text(point.date.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(BullTheme.muted)
                            .position(x: x, y: plotTop + height + 12)
                    }

                    if !hasStateData {
                        Text("Add an Urge State or Bull State check-in to start your trend.")
                            .font(.caption2)
                            .foregroundStyle(BullTheme.secondary)
                            .multilineTextAlignment(.center)
                            .frame(width: max(120, graphWidth - 32))
                            .position(x: labelWidth + graphWidth / 2, y: plotTop + height / 2)
                    }
                }
            }
            .frame(height: 132)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption2.weight(.semibold)).foregroundStyle(BullTheme.muted)
        }
    }

    private func xPosition(index: Int, width: CGFloat) -> CGFloat {
        guard points.count > 1 else { return width / 2 }
        return width * CGFloat(index) / CGFloat(points.count - 1)
    }

    private func yPosition(_ value: Double, height: CGFloat) -> CGFloat {
        height * CGFloat(1 - min(100, max(0, value)) / 100)
    }

    private var hasStateData: Bool {
        points.contains { $0.urgeState != nil || $0.bullState != nil }
    }

    private func segmentedPath(
        values: [Double?], width: CGFloat, height: CGFloat, xInset: CGFloat, yInset: CGFloat
    ) -> Path {
        Path { path in
            var drawing = false
            for (index, value) in values.enumerated() {
                guard let value else { drawing = false; continue }
                let point = CGPoint(
                    x: xInset + xPosition(index: index, width: width),
                    y: yInset + yPosition(value, height: height)
                )
                if drawing { path.addLine(to: point) } else { path.move(to: point); drawing = true }
            }
        }
    }

    private var accessibilitySummary: String {
        points.map { point in
            let urge = point.urgeState.map { "Urge State \(Int($0.rounded()))" } ?? "Urge State missing"
            let bull = point.bullState.map { "Bull State \(Int($0.rounded()))" } ?? "Bull State missing"
            return "\(point.date.formatted(date: .abbreviated, time: .omitted)): \(urge), \(bull)"
        }.joined(separator: ". ")
    }
}
