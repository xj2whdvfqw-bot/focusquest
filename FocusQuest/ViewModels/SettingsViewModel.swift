import Combine
import Foundation

enum LegalDocument: String, Identifiable, CaseIterable {
    case privacy, terms, antiCheat
    var id: String { rawValue }
    var title: String {
        switch self { case .privacy: "Privacy Policy"; case .terms: "Terms of Use"; case .antiCheat: "Anti-Cheat & Sensors" }
    }
    var content: String {
        switch self {
        case .privacy:
            "FocusQuest processes motion sensor measurements on your device in real time to determine whether your phone is resting face-up. Raw motion readings are not uploaded or retained. Session timing uses monotonic uptime and server-issued session challenges; App Attest assertions may be sent to verify app integrity. Account and verified progression data are used to provide sync and gameplay. FocusQuest does not sell personal study data. You may request account deletion from Settings."
        case .terms:
            "Play fairly: do not modify the app, falsify session activity, or disrupt another player's raid. Verified rewards are determined by the service and may be withheld when integrity checks fail. Game names, artwork, and software are FocusQuest intellectual property. Online features require a network connection."
        case .antiCheat:
            "During a battle, CoreMotion pitch, roll, and gravity values are evaluated on-device at approximately 10 samples per second. The phone must lie face-down and still for verified focus. Raw sensor values are processed transiently and are not transmitted. Lifting the device starts a ten-second warning; laying it back down resumes the battle. The first expired warning in a battle is forgiven; after the second, the boss escapes and the battle earns no XP or coins. Your streak and coins are never taken away."
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var preferences: AppPreferences
    @Published var selectedDocument: LegalDocument?
    @Published var statusMessage: String?
    /// Volano po kazde zmene predvoleb, aby se projevila hned (napr. v bezici hudbe).
    var onPreferencesChanged: ((AppPreferences) -> Void)?
    private let store: any PreferencesStoreProtocol
    private let profileSync: any ProfileSyncServiceProtocol

    init(store: any PreferencesStoreProtocol, profileSync: any ProfileSyncServiceProtocol) {
        self.store = store; self.profileSync = profileSync
        preferences = store.load()
    }

    func update(_ change: (inout AppPreferences) -> Void) {
        change(&preferences)
        preferences.ambientVolume = min(1, max(0, preferences.ambientVolume))
        store.save(preferences)
        onPreferencesChanged?(preferences)
    }

    /// Predvolby zmenene jinde (prehravac v Arene) - jen se prevezmou, uz jsou ulozene.
    func syncPreferences(_ updated: AppPreferences) { preferences = updated }

    /// Reset progress: smaze profil, statistiky a predvolby (vcetne predmetu) a vrati vychozi stav.
    /// Vraci false, kdyz se mazani nepovedlo.
    func resetProgress() async -> Bool {
        do {
            try await profileSync.resetProgress()
            store.reset()
            preferences = AppPreferences()
            onPreferencesChanged?(preferences)
            statusMessage = nil
            return true
        } catch {
            statusMessage = "Progress could not be reset. Try again."
            return false
        }
    }
}