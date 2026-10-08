import SwiftUI

/// Notification destination retained for direct Risk Zone safeguards and any already-
/// delivered v2.9 alert. It never resurrects the retired predictive Risk score.
struct RiskActionDestinationView: View {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var zones: HighRiskZoneService
    @Environment(\.dismiss) private var dismiss
    let route: AlertRoute

    @State private var showUrgeSupport = false
    @State private var showRiskZones = false
    @State private var statusMessage: String?
    @State private var zoneAlertInactive = false

    private var eventID: String {
        switch route {
        case .risk(let id): return id
        case .zone(_, _, let id): return id
        }
    }
    private var event: RiskAlertEvent? { store.riskAlertEvent(id: eventID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch route {
                    case .risk:
                        BullCard {
                            Text("Past Alert")
                                .font(.caption.weight(.bold)).foregroundStyle(BullTheme.muted)
                            Text("This is an older alert. Bull keeps it in your history, but it no longer affects today's scores.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button {
                                store.handleRiskAlertAction(eventID: eventID, action: .startResponse)
                                showUrgeSupport = true
                            } label: {
                                Label("I Have an Urge", systemImage: "wind").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).tint(BullTheme.crimson)
                        }
                    case .zone(let zoneID, _, _):
                        zoneActionCard(zoneID: zoneID)
                    }
                    if let statusMessage {
                        Text(statusMessage).font(.caption).foregroundStyle(BullTheme.secondary)
                    }
                }
                .padding()
            }
            .background(BullTheme.ivory.ignoresSafeArea())
            .navigationTitle("Bull Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .sheet(isPresented: $showUrgeSupport) { UrgeSupportView() }
        .sheet(isPresented: $showRiskZones) { HighRiskZonesView() }
        .task { await refreshOpenedZoneAlert() }
    }

    @ViewBuilder
    private func zoneActionCard(zoneID: String) -> some View {
        if let zone = store.data.highRiskZones.first(where: { $0.id == zoneID }),
           !zoneAlertInactive {
            BullCard {
                Text(zone.resolutionMode == .exitRequired
                    ? "Leave Zone"
                    : (store.isZoneSafeguarded(zoneID) ? "Safeguarded" : "Risk Zone"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(store.isZoneSafeguarded(zoneID) ? BullTheme.green : BullTheme.crimson)
                Text(zone.name).font(.title3.weight(.bold))
                if zone.resolutionMode == .exitRequired {
                    Text("No safeguard is possible here. Leave this Risk Zone.")
                        .font(.headline)
                } else {
                    Text(zone.safeguard.instruction).font(.headline)
                    if let note = zone.safeguard.note, !note.isEmpty {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if zone.resolutionMode == .safeguard && !store.isZoneSafeguarded(zoneID) {
                    Button {
                        store.handleRiskAlertAction(eventID: eventID, action: .safeguardDone)
                        notifications.cancelZoneAlert(zoneID: zoneID)
                        statusMessage = "Safeguard recorded."
                    } label: {
                        Label("Safeguard Done", systemImage: "shield.checkered").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(BullTheme.gold).foregroundStyle(BullTheme.ink)
                    Button("Snooze 10 Minutes") {
                        store.handleRiskAlertAction(eventID: eventID, action: .snooze)
                        if let event {
                            Task {
                                let ok = await notifications.scheduleZoneAlert(
                                    event: event, zone: zone,
                                    fireDate: Date().addingTimeInterval(10 * 60)
                                )
                                statusMessage = ok ? "Reminder scheduled." : (notifications.lastError ?? "Reminder failed.")
                            }
                        }
                    }
                } else if zone.resolutionMode == .safeguard {
                    Button("Undo") {
                        _ = store.recordSafeguardEvent(
                            zoneID: zoneID, kind: .reversed, alertEventID: eventID,
                            note: "User corrected the completion state"
                        )
                        statusMessage = "Safeguard marked not completed."
                    }
                    .buttonStyle(.bordered)
                }
                Text(zone.resolutionMode == .exitRequired
                    ? "Bull keeps this visit unresolved until iOS records that you left the zone."
                    : "Completing the safeguard is recorded in your Risk Zone history.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            BullCard {
                Label("This Alert Is No Longer Active", systemImage: "checkmark.shield")
                    .font(.headline)
                    .foregroundStyle(BullTheme.green)
                Text("Bull cleared the old notification and any orphaned monitoring. Your saved history remains available.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open Risk Zones") { showRiskZones = true }
                    .buttonStyle(BullActionButtonStyle())
                Button {
                    showUrgeSupport = true
                } label: {
                    Label("Urge Support", systemImage: "wind")
                }
                .buttonStyle(BullActionButtonStyle(prominent: true))
            }
        }
    }

    private func refreshOpenedZoneAlert() async {
        guard case .zone(let zoneID, _, _) = route else { return }
        guard let zone = store.data.highRiskZones.first(where: { $0.id == zoneID }) else {
            notifications.cancelZoneAlert(zoneID: zoneID)
            zones.stopMonitoring(zoneID: zoneID)
            zoneAlertInactive = true
            return
        }
        let refreshed = await zones.refreshCurrentZoneStates(timeoutSeconds: 10)
        guard refreshed else { return }
        if !store.isInsideZone(zoneID) || !store.isZoneActive(zone, at: Date()) {
            notifications.cancelZoneAlert(zoneID: zoneID)
            store.cancelPendingZoneAlerts(zoneID: zoneID)
            zoneAlertInactive = true
        }
    }
}
