import SwiftUI

private struct GuideEntry: Identifiable {
    let id = UUID()
    var title: String
    var evidence: EvidenceChip.Strength
    var lead: String
    var bullets: [String]
}

private struct GuideGroup: Identifiable {
    let id = UUID()
    var title: String
    var entries: [GuideEntry]
}

struct GuideView: View {
    private let groups: [GuideGroup] = [
        GuideGroup(title: "Highest Evidence", entries: [
            GuideEntry(title: "ACT and CBT", evidence: .stronger,
                       lead: "Psychotherapy is the strongest-supported intervention family in the review.",
                       bullets: [
                        "Bull is a self-management tool, not a replacement for therapy when the behaviour is causing genuine impairment.",
                        "ACT is useful for learning to make room for urges and uncomfortable thoughts without automatically acting on them; CBT targets triggers, beliefs, coping and relapse prevention.",
                        "The evidence base is still young and RCT-poor, so Bull deliberately avoids presenting any single technique as a cure."
                       ]),
            GuideEntry(title: "If–Then Plans", evidence: .moderate,
                       lead: "Implementation intentions are one of the most replicated general behaviour-change tools.",
                       bullets: [
                        "Use a contingent form: If [specific trigger], then [specific response].",
                        "Specific, rehearsed plans tend to work better than vague intentions.",
                        "Keep a small working set (Bull allows up to three active plans) for recurring triggers rather than trying to write a rule for every possible situation.",
                        "Bull keeps these prospective plans separate from patterns learned after an urge."
                       ])
        ]),
        GuideGroup(title: "In The Moment", entries: [
            GuideEntry(title: "Urge Reset", evidence: .moderate,
                       lead: "Urge tolerance and urge surfing are supported indirectly through ACT and relapse-prevention approaches, rather than by strong isolated trials.",
                       bullets: [
                        "Tap Urge immediately to record the event and create space before acting.",
                        "The breathing screen is a reset tool, not proof that the urge was 'survived'.",
                        "Bull only calls an urge day passed after that civil day ends without a lapse."
                       ]),
            GuideEntry(title: "Change Environment", evidence: .moderate,
                       lead: "Stimulus control is a standard relapse-prevention principle.",
                       bullets: [
                        "If the urge stays loud, leave the room, move the phone, go outside, or otherwise break the cue-response chain.",
                        "Filters and blockers are useful friction, not a treatment and not impossible to bypass."
                       ]),
            GuideEntry(title: "After A Lapse", evidence: .moderate,
                       lead: "Avoid the abstinence-violation effect: one lapse can become a larger relapse when it is interpreted as total failure.",
                       bullets: [
                        "Bull does not reset a streak to zero.",
                        "Log what happened, show the lapse plan, choose the next useful action, and continue the day.",
                        "The 30-day trend is more informative than an all-or-nothing counter."
                       ])
        ]),
        GuideGroup(title: "Prevention", entries: [
            GuideEntry(title: "Trigger Identification", evidence: .moderate,
                       lead: "Boredom, stress, loneliness, fatigue and late-night/in-bed phone use are plausible high-risk situations in relapse-prevention research.",
                       bullets: [
                        "Log factors honestly rather than assuming they are true for you.",
                        "Patterns only surfaces an observed association after a minimum amount of known data, and it never treats missing data as 'No'."
                       ]),
            GuideEntry(title: "Sleep, Exercise & Stress", evidence: .moderate,
                       lead: "Supported well as general relapse-prevention/lifestyle factors, but porn-specific evidence is weaker.",
                       bullets: [
                        "Protecting sleep and routine is low-risk and sensible.",
                        "Patterns overlays HRV and Sleep Score with lapse/wet-dream days, then separately tests low sleep, bedtime inconsistency, unplanned interruptions and Dawn-gap length once enough personal data exists.",
                        "Those are observed associations, not proof that sleep caused an event."
                       ]),
            GuideEntry(title: "Self-Monitoring", evidence: .moderate,
                       lead: "Tracking frequency, triggers and mood can help; punitive gamification can backfire.",
                       bullets: [
                        "Use the logs to learn trends, not to create shame.",
                        "Risk is predictive: the eventual lapse is not fed back into the same day's Risk score."
                       ]),
            GuideEntry(title: "Accountability", evidence: .indirect,
                       lead: "Peer/accountability mechanisms are plausible but have weak controlled evidence for this specific problem.",
                       bullets: [
                        "Therapy/accountability is opt-in in native Bull.",
                        "If you choose a cadence, Bull can flag an overdue gap; choosing no cadence does not create a penalty."
                       ])
        ]),
        GuideGroup(title: "Framing", entries: [
            GuideEntry(title: "Abstinence vs Reduction", evidence: .personal,
                       lead: "The review does not show that total abstinence is superior to controlled-use/reduction goals for pornography use.",
                       bullets: [
                        "Bull can support your chosen values-based goal without claiming one goal is medically required.",
                        "Avoid fixed '90-day reboot' claims; the review finds no research-backed universal timeline."
                       ]),
            GuideEntry(title: "Moral Incongruence", evidence: .stronger,
                       lead: "Distress can come from genuine loss of control, values conflict, or both.",
                       bullets: [
                        "The optional baseline reflection asks about impairment, failed attempts, consequences and emotion-regulation use.",
                        "It is not a diagnosis. If there is significant impairment, escalation, or co-occurring mental-health difficulty, seek a licensed clinician."
                       ])
        ]),
        GuideGroup(title: "Sexual Vigour", entries: [
            GuideEntry(title: "Separate Module", evidence: .personal,
                       lead: "Bull's Vigour module is a personal health-performance tracker; it is not validated by the attached pornography-treatment review.",
                       bullets: [
                        "Sleep, training, pelvic-floor work, cardio, supplements and other habits are tracked as your configured routine.",
                        "Weights are editable. Treat the score as adherence to your chosen plan, not as a medical measurement of testosterone or sexual function."
                       ])
        ])
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    BullCard {
                        Text("Evidence-aware, not evidence-themed")
                            .font(.system(.title3, design: .serif).weight(.bold))
                        Text("Evidence labels show relative confidence, not certainty.")
                            .font(.caption)
                            .foregroundStyle(BullTheme.secondary)
                            .padding(.top, 5)
                    }

                    ForEach(groups) { group in
                        BullSectionLabel(text: group.title)
                        ForEach(group.entries) { entry in
                            BullCard {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(entry.title)
                                        .font(.headline)
                                        .foregroundStyle(BullTheme.ink)
                                    Spacer()
                                    EvidenceChip(strength: entry.evidence)
                                }
                                Text(entry.lead)
                                    .font(.subheadline)
                                    .foregroundStyle(BullTheme.secondary)
                                    .padding(.top, 5)
                                ForEach(entry.bullets, id: \.self) { bullet in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle().fill(BullTheme.gold).frame(width: 5, height: 5).padding(.top, 6)
                                        Text(bullet)
                                            .font(.caption)
                                            .foregroundStyle(BullTheme.ink)
                                    }
                                    .padding(.top, 5)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(BullTheme.ivory.ignoresSafeArea())
            .navigationTitle("Guide")
        }
    }
}
