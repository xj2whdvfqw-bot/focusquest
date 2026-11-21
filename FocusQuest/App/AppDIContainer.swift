import Foundation

@MainActor
final class AppDIContainer {
    let environment: AppEnvironment
    let keychain: any KeychainServiceProtocol
    let profileSync: any ProfileSyncServiceProtocol
    let preferences: any PreferencesStoreProtocol
    let arenaViewModel: ArenaViewModel
    let statsViewModel: StatsViewModel
    let profileViewModel: ProfileViewModel
    let settingsViewModel: SettingsViewModel
    /// Hlida odchod z appky behem bitvy a drzi vyber "blokovanych" appek z uvodu.
    let appBlocker: AppBlockerManager
    let runtimeSecurity: any RuntimeSecurityServiceProtocol
    let isIntegrityCompromised: Bool

    init(environment: AppEnvironment = AppEnvironment()) {
        self.environment = environment
        let keychain = KeychainService()
        let api = APIClient(baseURL: environment.apiBaseURL, pinnedCertificateSHA256: environment.pinnedCertificateSHA256, keychain: keychain)
        let profileSync: any ProfileSyncServiceProtocol = environment.usesSimulatedBackend ? LocalProfileSyncService() : ProfileSyncService(api: api, keychain: keychain)
        let preferences = PreferencesStore()
        let profile = UserProfile.fresh(deviceID: "local-preview")
        let profileViewModel = ProfileViewModel(profile: profile, sync: profileSync)
        let attestation = AppAttestService(keychain: keychain)
        let previewSigningKey = Data(CryptoSigner().makeNonce(byteCount: 48).utf8)
        let activity = FocusBattleActivityController()
        let validation: any FocusValidationServiceProtocol = environment.usesSimulatedBackend ? SimulatedSecureBackendService(signingKey: previewSigningKey) : RemoteFocusValidationService(api: api, attestation: attestation, signer: CryptoSigner())
        let motion = MotionMonitoringService()
        let haptics = HapticEngineService()
        let audio = AudioAtmosphereService()
        let security = RuntimeSecurityService()

        self.keychain = keychain
        self.profileSync = profileSync
        self.preferences = preferences
        self.profileViewModel = profileViewModel
        self.statsViewModel = StatsViewModel(profileSync: profileSync)
        self.settingsViewModel = SettingsViewModel(store: preferences, profileSync: profileSync, keychain: keychain)
        self.appBlocker = AppBlockerManager()
        self.runtimeSecurity = security
        self.isIntegrityCompromised = security.integrityReport().isCompromised
        if security.integrityReport().isCompromised { Task { try? await keychain.deleteAll() } }
        self.arenaViewModel = ArenaViewModel(validation: validation, motion: motion, haptics: haptics, audio: audio, security: security, preferenceStore: preferences, profileProvider: { [weak profileViewModel] in profileViewModel?.profile ?? profile }, simulationSigningKey: previewSigningKey, activity: activity, notifications: BattleNotificationService())
        // Odmenu pripisuje model Areny, ne obrazovka - prijde i kdyz bitva skonci na pozadi.
        arenaViewModel.onVictory = { [weak profileViewModel, weak arena = self.arenaViewModel] victory in
            profileViewModel?.recordVictory(victory)
            // Dnes uz se bojovalo: dnesni pripominka v 17:00 odpada.
            arena?.refreshDailyReminder(focusedToday: true)
        }
        // Zmeny v Nastaveni (hudba, hlasitost, skladba) se maji projevit hned i v bezici bitve.
        settingsViewModel.onPreferencesChanged = { [weak arenaViewModel] updated in arenaViewModel?.updatePreferences(updated) }
        arenaViewModel.onPreferencesChanged = { [weak settingsViewModel] updated in settingsViewModel?.syncPreferences(updated) }
        // Statistiky zmenene vitezstvim nebo bonusem se hned ukazi i na zalozce Stats.
        profileViewModel.onStatsChanged = { [weak stats = self.statsViewModel] updated in stats?.replace(with: updated) }

        // Ustup z bitvy ("Retreat Anyway") jen necha bosse utect: bitva nic neprinese, serie a mince zustavaji.
        // Odchod z appky uz se netresta: bitva bezi dal i na pozadi.
    }
}