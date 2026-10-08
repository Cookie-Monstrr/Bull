import SwiftUI
import UIKit

struct StateFiguresView: View {
    let urgeState: Double?
    let bullState: Double?
    let urgeRoutine: Double?
    let bullRoutine: Double?
    let showBull: Bool
    let selectedState: Bool
    let isFinal: Bool
    let onSelect: (Bool) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            Circle()
                .fill(BullTheme.crimson.opacity(0.12))
                .frame(width: 290, height: 290)
                .offset(x: 165, y: -90)
            Circle()
                .fill(BullTheme.gold.opacity(0.08))
                .frame(width: 250, height: 250)
                .offset(x: -165, y: 155)
            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 12) {
                    figure(showBull ? .provider : .angel,
                           value: showBull ? bullRoutine : urgeRoutine, state: false)
                    Rectangle().fill(BullTheme.cream.opacity(0.18)).frame(width: 1)
                    figure(showBull ? .bull : .devil,
                           value: showBull ? bullState : urgeState, state: true)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.17, green: 0.04, blue: 0.05), BullTheme.oxbloodLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: BullTheme.cardRadius))
    }

    private func figure(_ character: BullFigureCharacter, value: Double?, state: Bool) -> some View {
        Button { onSelect(state) } label: {
          VStack(spacing: 6) {
            BullFigureArtwork(character: character, score: value)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 130 : 154)
                .frame(maxWidth: .infinity)
            HStack(spacing: 5) {
                Text(character.title).multilineTextAlignment(.center)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(BullTheme.cream.opacity(0.9))
            Text(BullFigureScore.text(value))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(BullTheme.cream)
                .monospacedDigit()
            Capsule().fill(selectedState == state ? BullTheme.cream : .clear).frame(height: 2)
                .padding(.horizontal, 24).padding(.top, 4)
          }
          .padding(.vertical, 4)
          .frame(maxWidth: .infinity)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(character.title)
        .accessibilityValue(BullFigureScore.text(value))
        .accessibilityHint("Shows the score breakdown")
        .accessibilityAddTraits(selectedState == state ? .isSelected : [])
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    var detail: String? = nil
    var color: Color = BullTheme.ink

    var body: some View {
        BullCard {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(BullTheme.secondary)
            Text(value)
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundStyle(color)
                .padding(.top, 2)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(BullTheme.muted)
                    .padding(.top, 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail.map { "\(label), \(value), \($0)" } ?? "\(label), \(value)")
    }
}

struct TriStateButtons: View {
    let value: Bool?
    let positiveLabel: String
    let negativeLabel: String
    let positiveColor: Color
    let negativeColor: Color
    let onChange: (Bool?) -> Void

    var body: some View {
        HStack(spacing: 7) {
            stateButton("—", selected: value == nil, color: BullTheme.secondary.opacity(0.35)) { onChange(nil) }
            stateButton(negativeLabel, selected: value == false, color: negativeColor) { onChange(false) }
            stateButton(positiveLabel, selected: value == true, color: positiveColor) { onChange(true) }
        }
    }

    private func stateButton(_ text: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.caption2.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: BullTheme.controlHeight)
                .foregroundStyle(selected ? BullTheme.ink : BullTheme.secondary)
                .background(selected ? color.opacity(0.85) : BullTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text == "—" ? "Not Recorded" : text)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}

struct ItemLogRow: View {
    let item: Item
    let value: Bool?
    let onChange: (Bool?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Text(item.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BullTheme.ink)
                Spacer(minLength: 4)
                BullItemInfoButton(item: item)
            }
            if item.kind == .risk {
                TriStateButtons(
                    value: value,
                    positiveLabel: "Happened",
                    negativeLabel: "Avoided",
                    positiveColor: BullTheme.crimson,
                    negativeColor: BullTheme.green,
                    onChange: onChange
                )
            } else {
                TriStateButtons(
                    value: value,
                    positiveLabel: "Done",
                    negativeLabel: "Skipped",
                    positiveColor: BullTheme.gold,
                    negativeColor: BullTheme.secondary.opacity(0.55),
                    onChange: onChange
                )
            }
        }
        .padding(.vertical, 9)
    }
}

struct ScoreRing: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(BullTheme.hairline, lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(0, min(1, value / 100)))
                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(value.rounded()))")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(BullTheme.muted)
            }
        }
        .frame(width: 74, height: 74)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value.rounded())) out of 100")
    }
}

struct EvidenceChip: View {
    enum Strength: String {
        case stronger = "Stronger"
        case moderate = "Moderate"
        case indirect = "Indirect"
        case personal = "Personal"
    }
    let strength: Strength

    var color: Color {
        switch strength {
        case .stronger: return BullTheme.green
        case .moderate: return BullTheme.gold
        case .indirect: return BullTheme.amber
        case .personal: return BullTheme.secondary
        }
    }

    var body: some View {
        Text(strength.rawValue)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// Shared wrapping layout for compact chip/button collections.
///
/// This used to live inside the retired Urge Reset screen even though Risk Zones
/// and lapse logging also depended on it. It belongs with the shared components.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
