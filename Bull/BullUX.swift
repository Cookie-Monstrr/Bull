import SwiftUI
import Combine

/// Presentation only. These names never replace stored score keys or widget kinds.
enum BullTodayDomain: String, CaseIterable, Identifiable {
    case urge = "Urge"
    case bull = "Bull"
    var id: String { rawValue }

    func scoreTitle(state: Bool) -> String {
        switch (self, state) {
        case (.urge, false): return "Urge Fuel"
        case (.urge, true): return "Urge State"
        case (.bull, false): return "Bull Fuel"
        case (.bull, true): return "Bull State"
        }
    }

    func nextAction(in actions: [BullPriorityAction]) -> BullPriorityAction? {
        // Preserve the existing priority order, including active Risk Zone protection
        // and the builder's fasting/rest-day exclusions. This is a display filter only.
        let shared: Set<String> = ["environment", "syncSleep", "prepareSleep"]
        let own: Set<String> = self == .urge ? ["stress", "relief"] : ["fuel", "cardio", "strength"]
        return actions.first { shared.contains($0.id) || own.contains($0.id) }
    }
}

enum BullRecordingStatus {
    static func displayTitle(_ title: String) -> String {
        title.split(separator: " ", omittingEmptySubsequences: false).map { token in
            guard let first = token.first, first.isLetter else { return String(token) }
            return String(first).uppercased() + token.dropFirst()
        }.joined(separator: " ")
    }
    static func score(_ value: Double?, isFinal: Bool) -> String {
        guard BullFigureScore.normalized(value) != nil else { return "Not Recorded" }
        return "Recorded"
    }

    static func updated(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "Not Synced" }
        if BullDates.sameDay(date, now) {
            return "Updated Today · \(date.formatted(date: .omitted, time: .shortened))"
        }
        if BullDates.sameDay(date, BullDates.addingDays(-1, to: now)) { return "Updated Yesterday" }
        return "Updated \(date.formatted(.dateTime.day().month(.abbreviated)))"
    }
}

/// Short-lived UI feedback only; no drafts or sensitive values are written to defaults.
@MainActor
final class BullFeedbackCenter: ObservableObject {
    struct Message: Identifiable {
        let id = UUID()
        let text: String
        var isError = false
        var undo: (() -> Void)?
    }

    @Published private(set) var message: Message?
    private var expiration: Task<Void, Never>?

    func show(_ text: String, isError: Bool = false, undo: (() -> Void)? = nil) {
        expiration?.cancel()
        let next = Message(text: text, isError: isError, undo: undo)
        message = next
        expiration = Task { [weak self] in
            try? await Task<Never, Never>.sleep(for: .seconds(undo == nil && !isError ? 4 : 10))
            guard !Task.isCancelled, self?.message?.id == next.id else { return }
            self?.message = nil
        }
    }

    func clear() { expiration?.cancel(); message = nil }

    @discardableResult
    func save(_ store: BullStore, message: String = "Saved", change: () -> Void) -> Bool {
        let before = store.revision
        change()
        guard store.revision != before, store.lastPersistedRevision == store.revision else {
            show(store.lastError ?? "Couldn't Save. Please Try Again.", isError: true)
            return false
        }
        show(message)
        return true
    }
}

private struct BullFeedbackOverlay: ViewModifier {
    @EnvironmentObject private var feedback: BullFeedbackCenter
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = feedback.message {
                HStack(spacing: 12) {
                    Image(systemName: message.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(message.isError ? BullTheme.crimson : BullTheme.green)
                    Text(message.text).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let undo = message.undo {
                        Button("Undo") { feedback.clear(); undo() }
                            .font(.subheadline.weight(.semibold)).frame(minHeight: BullTheme.controlHeight)
                    }
                    Button { feedback.clear() } label: {
                        Image(systemName: "xmark").frame(width: BullTheme.controlHeight, height: BullTheme.controlHeight)
                    }
                    .accessibilityLabel("Dismiss Confirmation")
                }
                .padding(.leading, 14).padding(.trailing, 2).padding(.vertical, 4)
                .foregroundStyle(BullTheme.ink)
                .background(BullTheme.paper, in: RoundedRectangle(cornerRadius: BullTheme.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: BullTheme.controlRadius).stroke(BullTheme.hairline))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                .padding(12)
                .accessibilityElement(children: .contain)
                .id(message.id)
            }
        }
    }
}

private struct BullEditorPrivacy: ViewModifier {
    @EnvironmentObject private var privacy: PrivacyManager
    @EnvironmentObject private var preferences: AppPreferences

    func body(content: Content) -> some View {
        content.overlay {
            if privacy.isShielded {
                PrivacyShieldView()
            } else if preferences.biometricLockEnabled && !privacy.isUnlocked {
                ZStack {
                    PrivacyShieldView()
                    Button("Unlock Bull") { Task { await privacy.unlock() } }
                        .buttonStyle(.borderedProminent).tint(BullTheme.goldDark)
                }
            }
        }
    }
}

private struct BullPendingSave: ViewModifier {
    @EnvironmentObject private var store: BullStore
    @EnvironmentObject private var feedback: BullFeedbackCenter
    @Binding var pending: Bool
    let onSaved: () -> Void

    func body(content: Content) -> some View {
        content
            .disabled(pending)
            .safeAreaInset(edge: .bottom) {
                if pending {
                    Button("Retry Save") {
                        if feedback.save(store, change: { store.retryPendingWrite() }) {
                            pending = false
                            onSaved()
                        }
                    }
                    .buttonStyle(BullActionButtonStyle(prominent: true))
                    .padding().background(BullTheme.ivory)
                }
            }
    }
}

struct BullActionButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: BullTheme.controlHeight)
            .padding(.horizontal, 12)
            .foregroundStyle(prominent ? BullTheme.cream : BullTheme.goldDark)
            .background(prominent ? BullTheme.oxblood : BullTheme.field)
            .clipShape(RoundedRectangle(cornerRadius: BullTheme.controlRadius))
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.7 : 1)
    }
}

extension View {
    func bullFeedbackOverlay() -> some View { modifier(BullFeedbackOverlay()) }
    func bullEditorPrivacy() -> some View { modifier(BullEditorPrivacy()) }

    func bullFormSurface() -> some View {
        scrollContentBackground(.hidden)
            .background(BullTheme.ivory)
            .tint(BullTheme.goldDark)
            .environment(\.defaultMinListRowHeight, BullTheme.controlHeight)
            .bullFeedbackOverlay()
            .bullEditorPrivacy()
    }

    func bullPendingSave(_ pending: Binding<Bool>, onSaved: @escaping () -> Void) -> some View {
        modifier(BullPendingSave(pending: pending, onSaved: onSaved))
    }

    func bullDraftGuard(isDirty: Bool, confirming: Binding<Bool>, discard: @escaping () -> Void) -> some View {
        interactiveDismissDisabled(isDirty)
            .confirmationDialog("Discard Unsaved Changes?", isPresented: confirming, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive, action: discard)
                Button("Keep Editing", role: .cancel) { }
            }
    }
}
