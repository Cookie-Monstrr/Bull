import SwiftUI
import LocalAuthentication
import Combine

@MainActor
final class PrivacyManager: ObservableObject {
    @Published var isShielded = false
    @Published var isUnlocked = true
    @Published var lastError: String?

    func sceneBecameInactive(lockEnabled: Bool) {
        isShielded = true
        if lockEnabled { isUnlocked = false }
    }

    func sceneBecameActive(lockEnabled: Bool) async {
        isShielded = false
        if lockEnabled && !isUnlocked {
            await unlock()
        }
    }

    func unlock() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastError = error?.localizedDescription ?? "Device authentication is unavailable."
            // A user who enabled the privacy lock must never be silently let through just
            // because authentication is unavailable or the device passcode was removed.
            isUnlocked = false
            return
        }
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Bull"
            )
            isUnlocked = ok
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            isUnlocked = false
        }
    }
}

struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            BullTheme.ivory.ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(BullTheme.gold)
                Text("Bull")
                    .font(.title2.weight(.black))
                    .foregroundStyle(BullTheme.ink)
                Text("Private")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BullTheme.muted)
            }
        }
    }
}
