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
            "During a battle, CoreMotion pitch, roll, and gravity values are evaluated on-device at approximately 10 samples per second. A face-up, level posture is required for verified focus. Raw sensor values are processed transiently and are not transmitted. Lifting the device starts a five-second visual warning; returning it to the desk resumes the session, while expiration reports a violation and resets the combo."
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var preferences: AppPreferences
    @Published var selectedDocument: LegalDocument?
    @Published var showingDeleteConfirmation = false
    @Published var statusMessage: String?
    @Published private(set) var isSignedIn = false
    private let store: any PreferencesStoreProtocol
    private let profileSync: any ProfileSyncServiceProtocol
    private let keychain: any KeychainServiceProtocol

    init(store: any PreferencesStoreProtocol, profileSync: any ProfileSyncServiceProtocol, keychain: any KeychainServiceProtocol) {
        self.store = store; self.profileSync = profileSync; self.keychain = keychain
        preferences = store.load()
    }

    func update(_ change: (inout AppPreferences) -> Void) {
        change(&preferences)
        preferences.ambientVolume = min(1, max(0, preferences.ambientVolume))
        store.save(preferences)
    }

    func signInWithApple(identityToken: String) async {
        do { try await profileSync.exchangeAppleToken(identityToken); isSignedIn = true; statusMessage = "Apple account connected." }
        catch { statusMessage = "Sign in could not be completed." }
    }

    func signOut() async {
        do { try await profileSync.signOut(); isSignedIn = false; statusMessage = "Signed out." }
        catch { statusMessage = "Sign out could not be completed." }
    }

    func deleteAccount() async {
        do {
            try await profileSync.deleteAccount()
            try await keychain.deleteAll()
            store.reset()
            preferences = AppPreferences()
            isSignedIn = false
            statusMessage = "Account and locally stored credentials were deleted."
        } catch { statusMessage = "Account deletion could not be completed. Check your connection and try again." }
    }
}