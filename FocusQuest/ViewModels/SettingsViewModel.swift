import Combine
import Foundation

/// Verejne stranky na GitHub Pages (slozka docs/ v repu). Terms of Use = standardni Apple EULA.
enum LegalLinks {
    static let privacy = URL(string: "https://xj2whdvfqw-bot.github.io/focusquest/privacy.html")!
    static let support = URL(string: "https://xj2whdvfqw-bot.github.io/focusquest/support.html")!
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var preferences: AppPreferences
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