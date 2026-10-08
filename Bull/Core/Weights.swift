import Foundation

// MARK: - Weight

/// The single Low / Med / High / V.High scale every weighted thing in Bull uses.
/// Ported from `WEIGHT_OPTS` in app.js. Raw values match the JS strings exactly so
/// existing exported JSON decodes without translation.
public enum Weight: String, Codable, CaseIterable, Sendable {
    case low
    case med
    case high
    case vhigh

    /// Display label, matching `wLabel()` in app.js.
    public var label: String {
        switch self {
        case .low: return "LOW"
        case .med: return "MED"
        case .high: return "HIGH"
        case .vhigh: return "V.HIGH"
        }
    }

    /// Sort rank, matching `WEIGHT_RANK`. Higher sorts first.
    public var rank: Int {
        switch self {
        case .low: return 1
        case .med: return 2
        case .high: return 3
        case .vhigh: return 4
        }
    }

    /// Points ADDED to Relapse Risk when a risk-kind item happens. `W_RISK`.
    public var riskPoints: Int {
        switch self {
        case .low: return 5
        case .med: return 10
        case .high: return 20
        case .vhigh: return 30
        }
    }

    /// Points SUBTRACTED from Relapse Risk when a protective item is done. `W_PROT`.
    public var protectivePoints: Int {
        switch self {
        case .low: return 2
        case .med: return 5
        case .high: return 8
        case .vhigh: return 11
        }
    }

    /// Adherence weight used by the Vigour calculation. `W_ADH`.
    public var adherencePoints: Int {
        switch self {
        case .low: return 1
        case .med: return 2
        case .high: return 3
        case .vhigh: return 4
        }
    }

    /// Multiplier applied to the fixed point values of derived/tiered factors.
    /// `WEIGHT_SCALE`. Note these are NOT proportional to the other tables —
    /// they are their own curve and must not be "simplified".
    public var scale: Double {
        switch self {
        case .low: return 0.3
        case .med: return 0.6
        case .high: return 1.0
        case .vhigh: return 1.4
        }
    }
}

// MARK: - JS-compatible rounding

/// JavaScript's `Math.round` rounds half toward POSITIVE INFINITY
/// (`Math.round(-0.5) === -0`), whereas Swift's `rounded()` rounds half AWAY
/// from zero (`(-0.5).rounded() == -1`). Every rounded quantity in Bull's
/// scoring is currently non-negative, where the two agree — but the scoring
/// code subtracts as well as adds, so relying on that is fragile. This
/// reproduces the JS semantics exactly so the port cannot silently drift.
@inlinable
public func jsRound(_ x: Double) -> Int {
    Int((x + 0.5).rounded(.down))
}
