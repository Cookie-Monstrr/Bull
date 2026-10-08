import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

enum BullTheme {
    static let cardRadius: CGFloat = 18
    static let controlRadius: CGFloat = 12
    static let controlHeight: CGFloat = 44
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let ivory = Color(hex: 0xFAF6EF)
    static let paper = Color(hex: 0xFFFDF8)
    static let ink = Color(hex: 0x2A2419)
    static let secondary = Color(hex: 0x6F675C)
    static let muted = Color(hex: 0x776F63)
    static let gold = Color(hex: 0xC9962C)
    static let goldDark = Color(hex: 0x795313)
    static let green = Color(hex: 0x47752F)
    static let amber = Color(hex: 0xC2701E)
    static let crimson = Color(hex: 0xB62F2B)
    static let oxblood = Color(hex: 0x351112)
    static let oxbloodLight = Color(hex: 0x661D1B)
    static let cream = Color(hex: 0xFFF3DA)
    static let hairline = Color(hex: 0x2A2419, alpha: 0.10)
    static let field = Color(hex: 0x2A2419, alpha: 0.05)

    static func riskColor(_ risk: Int) -> Color {
        if risk <= 25 { return green }
        if risk <= 55 { return amber }
        return crimson
    }

    static func riskLabel(_ risk: Int) -> String {
        if risk <= 25 { return "Safe" }
        if risk <= 55 { return "Caution" }
        return "High Risk"
    }
}

struct BullCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        // A ViewBuilder can contain several sibling views. Applying card modifiers
        // directly to the tuple makes SwiftUI style each sibling independently,
        // which produced the mysterious extra "empty" cards/dividers seen in v1.
        // Wrap the content in one real container so one BullCard is always one card.
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(BullTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(BullTheme.ink)
        .background(BullTheme.paper.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: BullTheme.cardRadius)
                .stroke(BullTheme.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BullTheme.cardRadius))
    }
}

struct BullSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(BullTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 7)
    }
}

struct BullPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(BullTheme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.22))
            .clipShape(Capsule())
    }
}
