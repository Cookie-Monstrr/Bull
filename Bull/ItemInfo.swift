import SwiftUI

struct BullItemInfoButton: View {
    let item: Item
    @State private var showInfo = false

    var body: some View {
        Button { showInfo = true } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(BullTheme.muted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About \(item.label)")
        .sheet(isPresented: $showInfo) {
            BullItemInfoView(item: item)
        }
    }
}

private struct BullItemInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let item: Item

    private var help: BullItemHelp { BullItemHelp.forItem(item) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(help.why)
                        .foregroundStyle(BullTheme.ink)
                }
                Section("In Bull") {
                    Text(BullItemHelp.scoringText(item))
                    if let sub = item.sub, !sub.isEmpty {
                        Text(sub).foregroundStyle(.secondary)
                    }
                }
                if let evidence = help.evidence {
                    Section("Evidence") {
                        Text(evidence)
                    }
                }
                if let tip = help.tip {
                    Section("Use") {
                        Text(tip)
                    }
                }
            }
            .navigationTitle(item.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct BullItemHelp {
    var why: String
    var evidence: String?
    var tip: String?

    static func forItem(_ item: Item) -> BullItemHelp {
        switch item.id {
        case "lonely":
            return .init(
                why: "Tracks unstructured time alone as a possible high-risk context.",
                evidence: "Boredom, loneliness and negative emotional states are common relapse contexts in broader relapse-prevention research; Bull still treats this as a personal hypothesis to test.",
                tip: "If this repeatedly appears around urges, turn it into a concrete If–Then plan."
            )
        case "contentAccess":
            return .init(
                why: "Tracks how easy it was to access triggering content that day.",
                evidence: "Stimulus control is a standard relapse-prevention principle. Filters and blockers are best understood as friction, not as a treatment or guarantee.",
                tip: "Log the real level of access rather than what you intended the level to be."
            )
        case "checkout":
            return .init(
                why: "Tracks a cue/attention pattern you chose to monitor.",
                evidence: "Bull does not assume this causes relapse. Patterns can tell you whether it is actually associated with your outcomes.",
                tip: nil
            )
        case "junk":
            return .init(
                why: "A Double Horns lifestyle item that can affect both Prevention and Vigour in your model.",
                evidence: "General lifestyle balance is sensible, but this specific item is not established as a pornography-relapse treatment.",
                tip: nil
            )
        case "coldplunge":
            return .init(
                why: "A personal routine item tracked on both Prevention and Vigour.",
                evidence: "Bull treats this as your configured health/performance habit, not a validated relapse treatment.",
                tip: nil
            )
        case "nasalclear":
            return .init(
                why: "Tracks clear nasal breathing as low-weight indirect sleep and nitric-oxide support for Bull strength.",
                evidence: "Nasal breathing has plausible indirect respiratory/sleep value, but Bull does not claim that airway clearance independently prevents relapse or produces a clinical sexual benefit.",
                tip: nil
            )
        case "kegels":
            return .init(why: "Tracks pelvic-floor strengthening in your Vigour routine.", evidence: "Vigour is a personal adherence score, not a medical measurement of sexual function.", tip: nil)
        case "stretches":
            return .init(why: "Tracks pelvic-floor relaxation/mobility work in your Vigour routine.", evidence: "Vigour is a personal adherence score, not a medical measurement of sexual function.", tip: nil)
        case "cardio":
            return .init(why: "Tracks cardiovascular training under Heart Power.", evidence: "Exercise is broadly supportive of health and stress regulation; Bull does not treat this item as a proven relapse intervention.", tip: nil)
        case "strength":
            return .init(why: "Tracks strength work under your Testosterone bucket.", evidence: "The bucket is an organising model for your routine, not a direct measurement of testosterone.", tip: nil)
        case "breathwork":
            return .init(why: "Tracks your planned breathing practice under Nitric Oxide.", evidence: "Slow structured breathing can reduce physiological arousal; Bull keeps the Vigour bucket as a personal routine label rather than a medical claim.", tip: nil)
        case "fasting":
            return .init(
                why: "Marks Fasting Today as a rest day and adds 10 capped Urge Fuel points.",
                evidence: "This reflects your experience and is tracked as a personal factor, not a hormone claim.",
                tip: "Cardio and strength prompts stay off for the fasting rest day. Exercise you log still counts."
            )
        case "supplements":
            return .init(why: "Tracks whether you followed your configured supplement routine.", evidence: "Bull scores adherence to your plan; it does not infer hormone levels or medical benefit from taking a supplement.", tip: nil)
        case "sleepScore":
            return .init(
                why: "A Dawn-Aware 0–100 sleep estimate built from duration, bedtime consistency and unplanned interruptions.",
                evidence: "Apple does not expose its own Sleep Score through HealthKit. Bull uses the same public 50/30/20 component structure but its own transparent curves, and excludes up to 90 minutes for one likely planned Dawn split.",
                tip: "Later, Layla can become the preferred source because it knows the planned prayer-aware sleep schedule."
            )
        case "recoveryScore":
            return .init(
                why: "A personal HRV recovery estimate: today's HRV compared with your own recent baseline.",
                evidence: "Bull uses the median of up to 30 prior HRV days and needs at least 7 prior readings. Baseline HRV maps to 70; about 15% below baseline maps to 40. It is a personal readiness signal, not a clinical metric.",
                tip: "A manual Recovery Score remains possible and is never overwritten by the HRV model."
            )
        default:
            return .init(
                why: item.id.hasPrefix("custom-") ? "A custom hypothesis you chose to track." : "A factor used in your Bull scoring model.",
                evidence: item.id.hasPrefix("custom-") ? "Custom items are personal hypotheses until your own Patterns data says otherwise." : nil,
                tip: nil
            )
        }
    }

    static func scoringText(_ item: Item) -> String {
        let side: String
        switch item.list {
        case .prev: side = "Prevention"
        case .prime: side = "Bull support"
        case .both: side = "Prevention + Bull support"
        }

        let behaviour: String
        switch item.kind {
        case .risk: behaviour = "When marked as happened, it acts as a risk/cost factor."
        case .habit: behaviour = "When marked as done, it acts as a protective/adherence factor."
        case .tier: behaviour = "It uses its own graded scoring rule rather than a simple toggle."
        case .derived: behaviour = "Bull calculates this automatically from another logged value."
        }

        if item.list == .both {
            return "\(side). Prevention weight: \(item.weight.label). Vigour weight: \(item.effectiveVigourWeight.label). \(behaviour)"
        }
        return "\(side). Weight: \(item.weight.label). \(behaviour)"
    }
}
