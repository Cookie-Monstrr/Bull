import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var feedback: BullFeedbackCenter

    private enum SelectedScore: String, CaseIterable {
        case urgeRoutine = "Urge Fuel"
        case urgeState = "Urge State"
        case bullRoutine = "Bull Fuel"
        case bullState = "Bull State"
    }

    @State private var domain: BullTodayDomain = .urge
    @State private var showingState = false
    @State private var breakdownExpanded = false
    @State private var route: BullEntryRoute?
    @State private var eventsExpanded = false
    @State private var isSyncing = false
    @State private var statusMessage: String?

    private var scores: FourScoreState { store.fourScoreState(endingOn: store.selectedDate) }
    private var selectedScore: SelectedScore {
        switch (domain, showingState) {
        case (.urge, false): return .urgeRoutine
        case (.urge, true): return .urgeState
        case (.bull, false): return .bullRoutine
        case (.bull, true): return .bullState
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BullTheme.sectionSpacing) {
                    dateHeader
                    domainSelector
                    StateFiguresView(
                        urgeState: displayedSnapshot.urgeState,
                        bullState: displayedSnapshot.bullState,
                        urgeRoutine: displayedSnapshot.urgeRoutine,
                        bullRoutine: displayedSnapshot.bullRoutine,
                        showBull: domain == .bull,
                        selectedState: showingState,
                        isFinal: displayedSnapshot.isFinal
                    ) { state in
                        showingState = state
                        breakdownExpanded = true
                    }
                    if store.isTodaySelected { nextActionCard }
                    if !store.isTodaySelected, displayedSnapshot.revision > 0 {
                        Text("Updated Historical Score")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BullTheme.goldDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Corrected historical score, revision \(displayedSnapshot.revision)")
                    }
                    breakdownCard

                    if store.isTodaySelected {
                        ForEach(activeRiskZones) { zone in zoneCard(zone) }
                    }
                    personalExperiments
                    eventsCard
                    healthSyncRow
                    if let statusMessage {
                        Text(statusMessage).font(.caption).foregroundStyle(BullTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .background(BullTheme.ivory.ignoresSafeArea())
            .navigationTitle("Bull")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { open(.history) } label: { Image(systemName: "calendar") }
                        .accessibilityLabel("Open Calendar")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 12) {
                    Button { open(.log) } label: { Label("Log", systemImage: "plus.circle.fill") }
                        .buttonStyle(BullActionButtonStyle(prominent: true))
                    if store.isTodaySelected {
                        Button { open(.urgeSupport) } label: { Label("Urge Support", systemImage: "wind") }
                            .buttonStyle(BullActionButtonStyle())
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(BullTheme.ivory)
                .overlay(alignment: .top) { Rectangle().fill(BullTheme.hairline).frame(height: 1) }
            }
        }
        .bullFeedbackOverlay()
        .sheet(item: $route) { BullEntryDestination(route: $0) }
    }

    private func open(_ kind: BullEntryKind) {
        route = BullEntryRoute(kind: kind, date: store.selectedDate, domain: domain)
    }

    private var domainSelector: some View {
        HStack(spacing: 0) {
            ForEach(BullTodayDomain.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { domain = option }
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(domain == option ? BullTheme.ink : BullTheme.secondary)
                        .frame(maxWidth: .infinity, minHeight: BullTheme.controlHeight)
                        .background(domain == option ? BullTheme.paper : Color.clear)
                        .clipShape(Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(domain == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(BullTheme.field)
        .clipShape(Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today View")
    }

    private var nextActionCard: some View {
        BullCard {
            Text("Next Step").font(.caption.weight(.semibold)).foregroundStyle(BullTheme.secondary)
            if let action = domain.nextAction(in: store.prioritiesPayload().actions) {
                if action.id == "prepareSleep" {
                    Label(BullRecordingStatus.displayTitle(action.title), systemImage: action.symbol).font(.subheadline.weight(.semibold))
                    Text(action.detail).font(.caption).foregroundStyle(BullTheme.secondary)
                } else {
                    Button { handle(action) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: action.symbol).foregroundStyle(BullTheme.goldDark)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(BullRecordingStatus.displayTitle(action.title)).font(.subheadline.weight(.semibold)).foregroundStyle(BullTheme.ink)
                                Text(action.detail).font(.caption).foregroundStyle(BullTheme.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .frame(minHeight: BullTheme.controlHeight).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("No Pending Steps").font(.subheadline.weight(.semibold))
            }
        }
    }

    private func handle(_ action: BullPriorityAction) {
        switch action.id {
        case "environment": open(.zones)
        case "syncSleep": open(.sleep)
        case "stress": open(.stress)
        case "relief": open(.relief)
        case "fuel": open(.nutrition)
        case "cardio": open(.cardio)
        case "strength": open(.strength)
        default: break
        }
    }

    private var dateHeader: some View {
        HStack {
            Button { store.selectedDate = BullDates.addingDays(-1, to: store.selectedDate) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous Day")
            Spacer()
            VStack(spacing: 2) {
                Text(store.isTodaySelected ? "Today" : store.selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.caption.weight(.semibold)).foregroundStyle(BullTheme.goldDark)
                Text(store.selectedDate.formatted(.dateTime.day().month(.wide)))
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(BullTheme.ink)
            }
            Spacer()
            Button {
                let next = BullDates.addingDays(1, to: store.selectedDate)
                if BullDates.startOfDay(next) <= BullDates.startOfDay(Date()) { store.selectedDate = next }
            } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
            .accessibilityLabel("Next Day")
            .disabled(store.isTodaySelected)
        }
        .padding(.vertical, 4)
    }

    private var healthSyncRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.text.square.fill")
                .foregroundStyle(BullTheme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BullTheme.ink)
                Text(lastHealthSyncLabel)
                    .font(.caption2)
                    .foregroundStyle(BullTheme.secondary)
            }
            Spacer()
            Button {
                Task { await syncHealth() }
            } label: {
                if isSyncing {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.bold))
                }
            }
            .buttonStyle(.bordered)
            .tint(BullTheme.goldDark)
            .disabled(isSyncing)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(BullTheme.paper)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BullTheme.hairline))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var lastHealthSyncLabel: String {
        return BullRecordingStatus.updated(preferences.lastHealthSyncTs.map { Date(timeIntervalSince1970: $0 / 1_000) })
    }

    private var breakdownCard: some View {
        BullCard {
            DisclosureGroup(isExpanded: $breakdownExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    breakdownRows
                }
                .padding(.top, 8)
            } label: {
                Text("\(domain.scoreTitle(state: showingState)) Breakdown")
                    .font(.headline).foregroundStyle(BullTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: BullTheme.controlHeight, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var breakdownRows: some View {
        switch selectedScore {
        case .urgeRoutine:
            breakdownRow("Prevention Sleep", score: scores.urgeRoutine.sleepProtection, weight: 40, source: "Semi-Automatic", sourceColor: BullTheme.green)
            breakdownRow("Stress Regulation", score: scores.urgeRoutine.stressRegulation, weight: 35, source: "Manual", sourceColor: BullTheme.goldDark)
            breakdownRow("Environment Protection", score: scores.urgeRoutine.environmentProtection, weight: 25, source: "Semi-Automatic", sourceColor: BullTheme.amber)
            if scores.urgeRoutine.fastingProtection != nil {
                HStack {
                    Label("Fasting Protection", systemImage: "moon.stars.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("+10").font(.system(.subheadline, design: .monospaced).weight(.semibold))
                }
                .foregroundStyle(BullTheme.goldDark)
                .padding(.vertical, 3)
            }
            simpleScoreRow("7-Day Momentum", value: store.urgeRoutineMomentum(endingOn: store.selectedDate))
            Divider().padding(.top, 6)
            breakdownActions
        case .urgeState:
            breakdownRow("Live Urge", score: scores.urgeState.score, weight: 100, source: nil, sourceColor: BullTheme.crimson)
            fullWidthAction("Log Urge", icon: "plus") { open(.urge) }
        case .bullRoutine:
            breakdownRow("Cardio", score: scores.bullRoutine.cardio, weight: 40, source: "Semi-Automatic", sourceColor: BullTheme.green)
            Text(cardioSummary)
                .font(.caption).foregroundStyle(BullTheme.secondary)
            componentActions([("Log Cardio", { open(.cardio) })])
            breakdownRow("Vigour Sleep", score: scores.bullRoutine.sleep, weight: 30, source: "Semi-Automatic", sourceColor: BullTheme.green)
            componentActions([("Edit Sleep Scores", { open(.sleep) })])
            breakdownRow("Nutrition", score: scores.bullRoutine.foodPlan, weight: 20, source: nil, sourceColor: BullTheme.goldDark)
            bullFuelButtons
            breakdownRow("Strength", score: scores.bullRoutine.strength, weight: 10, source: "Manual", sourceColor: BullTheme.goldDark)
            Text("\(scores.bullRoutine.weeklyStrengthCompletedSets) of \(scores.bullRoutine.weeklyStrengthScheduledSets) Scheduled Sets Completed")
                .font(.caption).foregroundStyle(BullTheme.secondary)
            componentActions([
                ("Log Strength Workout", { open(.strength) }),
                ("Edit Exercise Plan", { open(.exercisePlan) })
            ])
        case .bullState:
            breakdownRow("Morning Erection", score: scores.bullState.erectionHealth, weight: 70, source: "Manual", sourceColor: BullTheme.goldDark)
            breakdownRow("Natural Desire", score: scores.bullState.healthyDesire, weight: 30, source: nil, sourceColor: BullTheme.goldDark)
            fullWidthAction(
                "Log Bull State",
                icon: "plus"
            ) { open(.bullState) }
        }
    }

    private var cardioSummary: String {
        let minutes = Int(scores.bullRoutine.weeklyModerateEquivalentMinutes.rounded())
        let calories = scores.bullRoutine.weeklyCardioActiveCalories.map {
            "\(Int($0.rounded())) Active kcal"
        } ?? "Active Energy Not Recorded"
        return "Last 7 Days: \(minutes) Equivalent Cardio Min · \(calories)"
    }

    private func breakdownRow(
        _ label: String, score: Double?, weight: Double, source: String?, sourceColor: Color
    ) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(BullTheme.ink)
                if let source { SourceBadge(text: source, color: sourceColor) }
            }
            Spacer()
            Text(score.map { "\(Int(($0 / 100 * weight).rounded())) / \(Int(weight))" } ?? "— / \(Int(weight))")
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(score == nil ? BullTheme.muted : BullTheme.ink)
        }
        .padding(.vertical, 3)
    }

    private func simpleScoreRow(_ label: String, value: Double?) -> some View {
        HStack {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(BullTheme.ink)
            Spacer()
            Text(value.map { "\(Int($0.rounded())) / 100" } ?? "— / 100")
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(value == nil ? BullTheme.muted : BullTheme.ink)
        }
        .padding(.vertical, 5)
    }

    private var breakdownActions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                breakdownAction("Edit Stress Plan", icon: "list.bullet.rectangle") { open(.stressPlan) }
                breakdownAction("Log Stress Relief", icon: "leaf.fill") { open(.relief) }
            }
            HStack(spacing: 10) {
                breakdownAction("Stress Check-In", icon: "gauge.with.dots.needle.33percent") {
                    open(.stress)
                }
                breakdownAction("Open Risk Zones", icon: "location.fill") { open(.zones) }
            }
        }
        .padding(.top, 4)
    }

    private func breakdownAction(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
            }
            .foregroundStyle(BullTheme.goldDark)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(BullTheme.gold.opacity(0.10))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BullTheme.gold.opacity(0.35)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func fullWidthAction(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(BullActionButtonStyle())
        .padding(.top, 7)
    }

    private func componentActions(_ actions: [(String, () -> Void)]) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                Button(item.0, action: item.1)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: BullTheme.controlHeight)
                    .background(BullTheme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
        .foregroundStyle(BullTheme.goldDark)
        .buttonStyle(.plain)
    }

    private var bullFuelButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NutritionEntryView.label(store.bullFuelPercent(on: store.selectedDate)))
                .font(.caption).foregroundStyle(BullTheme.secondary)
            if store.isFasting(on: store.selectedDate) {
                Label("Fasting Rest Day", systemImage: "moon.stars.fill")
                    .font(.caption).foregroundStyle(BullTheme.goldDark)
            }
            fullWidthAction("Edit Nutrition & Fasting", icon: "pencil") { open(.nutrition) }
        }
    }

    private func completionButtons(id: String) -> some View {
        let state = store.completionRecord(for: id).state
        return HStack(spacing: 8) {
            completionButton("—", selected: state == .unknown) { store.setCompletion(id, state: .unknown) }
            completionButton("Done", selected: state == .done) { store.setCompletion(id, state: .done) }
            completionButton("Not Done", selected: state == .notDone) { store.setCompletion(id, state: .notDone) }
        }
    }

    private func completionButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.caption.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                .foregroundStyle(BullTheme.ink)
                .background(selected ? BullTheme.gold.opacity(0.35) : BullTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private var personalExperiments: some View {
        BullCard {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Sick", isOn: Binding(
                        get: { store.selectedDay.sick },
                        set: { value in store.updateDay { $0.sick = value } }
                    ))
                    .padding(.trailing, 8)
                    Toggle("Travelling", isOn: Binding(
                        get: { store.selectedDay.travelling },
                        set: { value in store.updateDay { $0.travelling = value } }
                    ))
                    .padding(.trailing, 8)
                    ForEach(store.data.personalFactors.filter { !$0.archived && $0.kind == .action }) { factor in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(factor.name).font(.subheadline.weight(.semibold))
                            completionButtons(id: factor.id)
                        }
                    }
                    Text("Tracked in Stats. Your scores stay unchanged.")
                        .font(.caption).foregroundStyle(BullTheme.secondary)
                    fullWidthAction("Manage Personal Experiments", icon: "slider.horizontal.3") {
                        open(.experiments)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Personal Experiments")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: BullTheme.controlHeight, alignment: .leading)
            }
        }
    }

    private var eventsCard: some View {
        BullCard {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { eventsExpanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text("Events").font(.headline).foregroundStyle(BullTheme.ink)
                        Image(systemName: eventsExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BullTheme.ink)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Log Lapse") { open(.lapse) }.font(.caption.weight(.bold))
            }
            .frame(minHeight: BullTheme.controlHeight)
            if eventsExpanded {
                Divider()
                Toggle("Wet Dream", isOn: Binding(
                    get: { store.selectedWetDream },
                    set: { _ in store.toggleWetDream() }
                ))
                .tint(BullTheme.gold)
                .padding(.trailing, 8)
                HStack {
                    Text("Urges Logged").font(.subheadline)
                    Spacer()
                    Text("\(store.pornUrgeObservations(on: store.selectedDate).count)")
                        .monospacedDigit()
                }
                HStack {
                    Text("Lapses Logged").font(.subheadline)
                    Spacer()
                    Text("\(store.selectedRelapses.count)").monospacedDigit()
                }
                DisclosureGroup("What Counts as a Lapse") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Porn", isOn: lapsePolicyBinding(\.pornCounts))
                        Toggle("Masturbation", isOn: lapsePolicyBinding(\.masturbationCounts))
                        Toggle("Deliberate Orgasm", isOn: lapsePolicyBinding(\.orgasmCounts))
                        Text("Wet Dreams Never Count as Lapses.")
                            .font(.caption)
                            .foregroundStyle(BullTheme.secondary)
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
            }
        }
    }

    private func lapsePolicyBinding(_ keyPath: WritableKeyPath<LapsePolicy, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.data.settings.lapsePolicy[keyPath: keyPath] },
            set: { value in store.updateSettings { $0.lapsePolicy[keyPath: keyPath] = value } }
        )
    }

    private var activeRiskZones: [HighRiskZone] {
        store.data.highRiskZones.filter {
            $0.enabled && store.isInsideZone($0.id) && store.isZoneActive($0)
        }
    }

    private func zoneCard(_ zone: HighRiskZone) -> some View {
        BullCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Risk Zone").font(.caption.weight(.semibold)).foregroundStyle(BullTheme.crimson)
                    Text(zone.name).font(.headline)
                    Text(zone.resolutionMode == .exitRequired
                        ? "No safeguard possible · leave this Risk Zone"
                        : zone.safeguard.instruction)
                        .font(.caption)
                        .foregroundStyle(zone.resolutionMode == .exitRequired ? BullTheme.crimson : BullTheme.secondary)
                }
                Spacer()
                if store.isZoneSafeguarded(zone.id) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(BullTheme.green)
                } else if zone.resolutionMode == .safeguard {
                    Button("Safeguard Done") {
                        _ = store.recordSafeguardEvent(zoneID: zone.id, kind: .completed)
                    }
                    .font(.caption.weight(.bold)).buttonStyle(.borderedProminent).tint(BullTheme.gold)
                } else {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(BullTheme.crimson)
                        .accessibilityLabel("Leave Zone")
                }
            }
            Button("Manage Risk Zones") { open(.zones) }.font(.caption.weight(.semibold))
        }
    }

    private var displayedSnapshot: FourScoreSnapshot {
        store.fourScoreSnapshot(on: store.selectedDate) ?? FourScoreSnapshot(
            urgeRoutine: nil, urgeState: nil, bullRoutine: nil, bullState: nil, isFinal: !store.isTodaySelected
        )
    }

    private func syncHealth() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        if !health.authorizationRequestCompleted, !(await health.requestAuthorization()) {
            statusMessage = health.lastError ?? "The Health access request could not be completed."
            return
        }
        let imports = await health.importRecentNights(days: 14)
        let changed = store.applyHealthBackfill(imports)
        preferences.markHealthSyncCompleted()
        statusMessage = imports.isEmpty
            ? "No matching Sleep or workout data was found."
            : "Health checked · \(changed) day\(changed == 1 ? "" : "s") updated."
    }
}

private struct SourceBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(color.opacity(0.12)).clipShape(Capsule())
    }
}

struct PurposeSleepEntryView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Environment(\.dismiss) private var dismiss
    let onSave: (Double?, Double?) -> Void
    private let initialPrevention: Double?
    private let initialVigour: Double?
    @State private var prevention: Double
    @State private var vigour: Double
    @State private var hasPrevention: Bool
    @State private var hasVigour: Bool
    @State private var confirmingDiscard = false

    private var isDirty: Bool {
        (hasPrevention ? prevention : nil) != initialPrevention ||
        (hasVigour ? vigour : nil) != initialVigour
    }

    init(
        prevention: Double?,
        vigour: Double?,
        onSave: @escaping (Double?, Double?) -> Void
    ) {
        self.onSave = onSave
        initialPrevention = prevention
        initialVigour = vigour
        _prevention = State(initialValue: prevention ?? 70)
        _vigour = State(initialValue: vigour ?? 70)
        _hasPrevention = State(initialValue: prevention != nil)
        _hasVigour = State(initialValue: vigour != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Urge Prevention") {
                    Toggle("Log Prevention Sleep", isOn: $hasPrevention)
                    if hasPrevention {
                        Text("\(Int(prevention.rounded())) / 100")
                            .font(.title2.monospacedDigit())
                        Slider(value: $prevention, in: 0...100, step: 1).tint(BullTheme.gold)
                    }
                }
                Section("Bull Vigour") {
                    Toggle("Log Vigour Sleep", isOn: $hasVigour)
                    if hasVigour {
                        Text("\(Int(vigour.rounded())) / 100")
                            .font(.title2.monospacedDigit())
                        Slider(value: $vigour, in: 0...100, step: 1).tint(BullTheme.green)
                    }
                }
                Text("Pre-filled where available. Your edits replace the imported scores.")
                    .font(.caption)
                    .foregroundStyle(BullTheme.secondary)
            }
            .navigationTitle("Sleep Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { if isDirty { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if feedback.save(store, message: "Sleep Saved", change: {
                            onSave(hasPrevention ? prevention : nil, hasVigour ? vigour : nil)
                        }) { dismiss() }
                    }
                }
            }
        }
        .bullFormSurface()
        .bullDraftGuard(isDirty: isDirty, confirming: $confirmingDiscard) { dismiss() }
    }
}
