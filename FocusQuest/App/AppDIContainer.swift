import Foundation
@preconcurrency import UserNotifications

/// Sklada sluzby a modely. Aplikace nema server ani ucty: profil, statistiky
/// i overovani bitev bezi jen v telefonu.
@MainActor
final class AppDIContainer {
    let profileSync: any ProfileSyncServiceProtocol
    let preferences: any PreferencesStoreProtocol
    let arenaViewModel: ArenaViewModel
    let statsViewModel: StatsViewModel
    let profileViewModel: ProfileViewModel
    let settingsViewModel: SettingsViewModel
    /// Hlida odchod z appky behem bitvy a drzi vyber "blokovanych" appek z uvodu.
    let appBlocker: AppBlockerManager
    private let activity: FocusBattleActivityController
    private var didCleanUpAfterTermination = false

    init() {
        let profileSync: any ProfileSyncServiceProtocol = LocalProfileSyncService()
        let preferences = PreferencesStore()
        let profile = UserProfile.fresh(deviceID: "local-preview")
        let profileViewModel = ProfileViewModel(profile: profile, sync: profileSync)
        let previewSigningKey = Data(CryptoSigner().makeNonce(byteCount: 48).utf8)
        let activity = FocusBattleActivityController()
        let validation: any FocusValidationServiceProtocol = SimulatedSecureBackendService(signingKey: previewSigningKey)
        let motion = MotionMonitoringService()
        let haptics = HapticEngineService()
        let audio = AudioAtmosphereService()

        self.profileSync = profileSync
        self.preferences = preferences
        self.profileViewModel = profileViewModel
        self.activity = activity
        self.statsViewModel = StatsViewModel(profileSync: profileSync)
        self.settingsViewModel = SettingsViewModel(store: preferences, profileSync: profileSync)
        self.appBlocker = AppBlockerManager()
        self.arenaViewModel = ArenaViewModel(validation: validation, motion: motion, haptics: haptics, audio: audio, preferenceStore: preferences, profileProvider: { [weak profileViewModel] in profileViewModel?.profile ?? profile }, simulationSigningKey: previewSigningKey, activity: activity, notifications: BattleNotificationService())
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

    /// Uklid po nasilnem ukonceni appky behem bitvy: bitva se ztratila, takze naplanovana
    /// notifikace "Victory!" uz neplati a Live Activity nema co ukazovat.
    /// Vola se jednou pri spusteni appky, kdy jeste zadna bitva nebezi.
    func cleanUpAfterTermination() async {
        guard !didCleanUpAfterTermination, arenaViewModel.isBetweenBattles else { return }
        didCleanUpAfterTermination = true
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [BattleNotificationService.victoryIdentifier])
        await activity.end()
    }

    /// Reset progress v Nastaveni: smaze hrdinu, mince, statistiky, predmety a nastaveni.
    /// Vraci false, kdyz se mazani nepovedlo (data pak zustanou beze zmeny).
    func resetProgress() async -> Bool {
        guard arenaViewModel.isBetweenBattles else { return false }
        guard await settingsViewModel.resetProgress() else { return false }
        appBlocker.reset()
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        await profileViewModel.reloadAfterReset()
        arenaViewModel.selectBoss(BossWorld.allCases[0].bosses[0])
        arenaViewModel.refreshDailyReminder(focusedToday: false)
        return true
    }
}
