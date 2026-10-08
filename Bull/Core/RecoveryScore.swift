import Foundation

/// Transparent HRV-derived recovery estimate used by native Bull.
///
/// This is intentionally NOT presented as a clinical measurement or as a clone of WHOOP/Oura.
/// It answers a narrower question: how suppressed or elevated is today's HRV relative to the
/// user's own recent baseline?
public enum BullRecoveryScore {
    public static let sourceIdentifier = "bull-hrv"
    public static let sourceVersion = 1
    public static let minimumBaselineSamples = 7
    public static let baselineWindow = 30

    /// A personal-baseline score where baseline HRV maps to 70/100.
    /// Every 1% deviation from baseline moves the score by 2 points.
    /// - 15% below baseline -> 40
    /// - baseline -> 70
    /// - 15% above baseline -> 100
    /// Values are clamped to 0...100.
    public static func score(hrv: Double, baseline: Double) -> Double? {
        guard hrv.isFinite, baseline.isFinite, hrv > 0, baseline > 0 else { return nil }
        let deviationPercent = ((hrv / baseline) - 1) * 100
        return min(100, max(0, 70 + deviationPercent * 2))
    }

    public static func classification(_ score: Double) -> String {
        switch score {
        case 85...: return "Strong"
        case 65..<85: return "Normal"
        case 40..<65: return "Strained"
        default: return "Suppressed"
        }
    }
}
