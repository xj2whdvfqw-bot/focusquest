import Foundation

/// C7: synchronizace celeho stavu pres iCloud Key-Value Store. PRIPRAVENO, VYPNUTO:
/// bezi jen s `FeatureFlags.iCloudSync` (vychozi false) a s prepinacem v Nastaveni (sekce iCloud sync).
/// Bez entitlementu `com.apple.developer.ubiquity-kvstore-identifier` (placeny ucet) by KVS nic nesynchronizoval.
/// Postup aktivace je v design/DEVELOPER_ACCOUNT_TODO.md.
///
/// Pravidla konfliktu (`merge`): novejsi stav vyhrava, ale
///  - vyssi postup ve svetech a odemcene veci (vybaveni, pozadi, easter eggy, odhalene svety) se nikdy neztrati,
///  - historie bitev je sjednoceni obou (podle id), souhrnna cisla se neztrati (maximum),
///  - serie se prepocita z historie dni (PlayerStats.currentStreak), zamrzle dny jsou sjednoceni.
enum CloudSync {
    static let stateKey = "fq.state"
    /// Prepinac uzivatele (Nastaveni › iCloud sync); plati jen se zapnutym flagem.
    static let enabledKey = "fq.iCloudSyncEnabled"
    static let lastSyncKey = "fq.iCloudLastSync"

    static var isEnabled: Bool {
        FeatureFlags.iCloudSync && UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var lastSync: Date? { UserDefaults.standard.object(forKey: lastSyncKey) as? Date }

    /// Pri spusteni (pred vytvorenim sluzeb): stahne stav z iCloudu, slouci ho s mistnim a ulozi.
    static func pullAndMerge(defaults: UserDefaults = .standard) {
        guard isEnabled else { return }
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        guard let data = store.data(forKey: stateKey),
              let remote = try? JSONDecoder().decode(AppState.self, from: data),
              remote.formatVersion <= AppStateStore.formatVersion else { return }
        guard let local = AppStateStore.load(from: defaults) else {
            AppStateStore.save(remote, to: defaults)
            return
        }
        AppStateStore.save(merge(local: local, remote: remote), to: defaults)
        defaults.set(Date(), forKey: lastSyncKey)
    }

    /// Po zmene stavu: nahraje cely stav do iCloudu (KVS zmeny sam davkuje).
    static func scheduleUpload(defaults: UserDefaults = .standard) {
        guard isEnabled, let state = AppStateStore.load(from: defaults),
              let data = try? JSONEncoder().encode(state) else { return }
        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: stateKey)
        store.synchronize()
        defaults.set(Date(), forKey: lastSyncKey)
    }

    // MARK: - Slouceni

    static func merge(local: AppState, remote: AppState) -> AppState {
        let localIsNewer = local.modifiedAt >= remote.modifiedAt
        var result = localIsNewer ? local : remote
        let other = localIsNewer ? remote : local

        // Profil: novejsi vyhrava, odemcene veci se scitaji.
        result.profile.ownedEquipmentIDs = union(result.profile.ownedEquipmentIDs, other.profile.ownedEquipmentIDs)
        result.profile.ownedBackgroundIDs = union(result.profile.ownedBackgroundIDs, other.profile.ownedBackgroundIDs)
        result.profile.foundEasterEggs = union(result.profile.foundEasterEggs, other.profile.foundEasterEggs)
        result.profile.frozenDays = union(result.profile.frozenDays, other.profile.frozenDays).sorted()
        result.profile.claimedQuests = union(result.profile.claimedQuests, other.profile.claimedQuests)
        result.profile.bossesDefeated = max(result.profile.bossesDefeated, other.profile.bossesDefeated)
        result.profile.firstUseDate = [result.profile.firstUseDate, other.profile.firstUseDate].compactMap { $0 }.min()

        // Postup ve svetech: v kazdem svete vyssi; odhalene svety se scitaji.
        var cleared = result.preferences.clearedNodesByWorld
        for (world, count) in other.preferences.clearedNodesByWorld { cleared[world] = max(cleared[world] ?? 0, count) }
        result.preferences.clearedNodesByWorld = cleared
        if let revealed = other.preferences.revealedWorlds {
            result.preferences.revealedWorlds = union(result.preferences.revealedWorlds ?? [], revealed)
        }

        // Statistiky: historie je sjednoceni (podle id), souhrny se neztrati.
        var seen = Set<UUID>()
        result.stats.sessionHistory = (result.stats.sessionHistory + other.stats.sessionHistory)
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.completedAt > $1.completedAt }
        result.stats.totalXP = max(result.stats.totalXP, other.stats.totalXP)
        result.stats.level = max(1, result.stats.totalXP / PlayerStats.xpPerLevel + 1)
        result.stats.wins = max(result.stats.wins, other.stats.wins)
        result.stats.battles = max(result.stats.battles, other.stats.battles)
        result.stats.totalHPDealt = max(result.stats.totalHPDealt, other.stats.totalHPDealt)
        // Serie z historie dni (vcetne zamrzlych), ne z ulozeneho pocitadla.
        result.stats.streakDays = result.stats.currentStreak(frozenDayKeys: Set(result.profile.frozenDays))

        result.modifiedAt = max(local.modifiedAt, remote.modifiedAt)
        result.formatVersion = AppStateStore.formatVersion
        return result
    }

    private static func union(_ first: [String], _ second: [String]) -> [String] {
        var seen = Set<String>()
        return (first + second).filter { seen.insert($0).inserted }
    }
}
