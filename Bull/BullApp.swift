import SwiftUI
import UIKit

@main
struct BullApp: App {
    @UIApplicationDelegateAdaptor(BullAppDelegate.self) private var appDelegate
    @StateObject private var store = BullStore()
    @StateObject private var preferences = AppPreferences()
    @StateObject private var privacy = PrivacyManager()
    @StateObject private var health = HealthKitService()
    @StateObject private var notifications = NotificationService()
    @StateObject private var zones = HighRiskZoneService()
    @StateObject private var therapistCloud = TherapistCloudService()
    @StateObject private var feedback = BullFeedbackCenter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(preferences)
                .environmentObject(privacy)
                .environmentObject(health)
                .environmentObject(notifications)
                .environmentObject(zones)
                .environmentObject(therapistCloud)
                .environmentObject(feedback)
                .task {
                    _ = store.refreshLaylaSleepScheduleFromSharedGroup()
                    UIApplication.shared.registerForRemoteNotifications()
                    if preferences.riskEmergencyTimeSensitive {
                        store.adoptLegacyZoneTimeSensitivePreference(true)
                        preferences.riskEmergencyTimeSensitive = false
                    }
                    if preferences.biometricLockEnabled {
                        privacy.isUnlocked = false
                        await privacy.unlock()
                    }
                    await notifications.refreshStatus()
                    await therapistCloud.refreshAccountStatus()
                    await therapistCloud.recoverExistingAccess(store: store)
                    await therapistCloud.acceptPendingShare(
                        store: store,
                        notifications: notifications
                    )
                    await therapistCloud.sync(store: store, notifications: notifications)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive, .background:
                feedback.clear()
                privacy.sceneBecameInactive(lockEnabled: preferences.biometricLockEnabled)
            case .active:
                store.appBecameActive()
                _ = store.refreshLaylaSleepScheduleFromSharedGroup()
                Task {
                    await privacy.sceneBecameActive(lockEnabled: preferences.biometricLockEnabled)
                    await therapistCloud.acceptPendingShare(
                        store: store,
                        notifications: notifications
                    )
                    await therapistCloud.sync(store: store, notifications: notifications)
                }
            @unknown default:
                break
            }
        }
    }
}
