import Foundation
import SwiftUI

/// Shared by the app and WidgetKit extension so the same score always selects the same art.
enum BullFigureCharacter: String, CaseIterable, Identifiable, Sendable {
    // Stable asset keys: provider contains Inferno Titan; angel contains Cinder
    // Sorcerer. The Sorcerer source files run strongest→weakest, so its asset lookup
    // is reversed below. Every visible score now progresses weakest→strongest.
    case bull, provider, devil, angel
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bull: return "Bull State"
        case .provider: return "Bull Fuel"
        case .devil: return "Urge State"
        case .angel: return "Urge Fuel"
        }
    }
    func assetName(stage: Int) -> String {
        let normalizedStage = min(5, max(1, stage))
        let assetStage = self == .angel ? 6 - normalizedStage : normalizedStage
        return "bull-figure-\(rawValue)-\(assetStage)"
    }
}

enum BullFigureScore {
    static func normalized(_ score: Double?) -> Double? {
        guard let score, score.isFinite else { return nil }
        return min(100, max(0, score))
    }
    static func stage(for score: Double?) -> Int? {
        guard let score = normalized(score) else { return nil }
        switch score {
        case ..<40: return 1
        case ..<60: return 2
        case ..<75: return 3
        case ..<90: return 4
        default: return 5
        }
    }
    static func text(_ score: Double?) -> String {
        normalized(score).map { String(Int($0.rounded())) } ?? "—"
    }
}

/// Narrow App Group contract: only four scores and a timestamp, never source observations.
/// Optional routine fields keep existing v1 payloads readable during an app/widget upgrade.
struct BullFigureSnapshot: Codable, Equatable, Sendable {
    var bullState: Double?
    var urgeState: Double?
    var bullRoutine: Double?
    var urgeRoutine: Double?
    var updatedAt: Date

    static let appGroupIdentifier = "group.com.ahmed.Bull"
    static let payloadKey = "bull-widget-score-snapshot-v1"

    static func empty(at date: Date) -> Self {
        Self(bullState: nil, urgeState: nil, bullRoutine: nil, urgeRoutine: nil, updatedAt: date)
    }
    func current(on date: Date, calendar: Calendar = .current) -> Self {
        guard updatedAt <= date.addingTimeInterval(60),
              calendar.isDate(updatedAt, inSameDayAs: date) else { return .empty(at: date) }
        return self
    }
    func score(for character: BullFigureCharacter) -> Double? {
        let score: Double?
        switch character {
        case .bull: score = bullState
        case .provider: score = bullRoutine
        case .devil: score = urgeState
        case .angel: score = urgeRoutine
        }
        return BullFigureScore.normalized(score)
    }
    func hasSameScores(as other: Self) -> Bool {
        BullFigureCharacter.allCases.allSatisfy { score(for: $0) == other.score(for: $0) }
    }
}

/// Home-screen chart contract. It contains only completed-day derived scores/components;
/// relapse dates, raw observations, notes and HealthKit samples are deliberately excluded.
struct BullWidgetChartPoint: Codable, Equatable, Identifiable, Sendable {
    var date: Date
    var urgeRoutine: Double?
    var urgeState: Double?
    var preventionSleep: Double?
    var stressRegulation: Double?
    var environmentProtection: Double?

    var id: Date { date }
}

struct BullWidgetChartsSnapshot: Codable, Equatable, Sendable {
    var points: [BullWidgetChartPoint]
    var updatedAt: Date

    static let payloadKey = "bull-widget-charts-v1"

    static func empty(at date: Date) -> Self { Self(points: [], updatedAt: date) }
}

/// Production PNG contract: 512×768 transparent canvas; torso x=256, boot baseline y=744.
/// Every character uses that baseline, including fire/capes. A kneeling or depleted
/// stage stays shorter instead of being enlarged to match a stronger silhouette.
struct BullFigureArtwork: View {
    let character: BullFigureCharacter
    let score: Double?

    var body: some View {
        Group {
            if let stage = BullFigureScore.stage(for: score) {
                Image(character.assetName(stage: stage))
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}
