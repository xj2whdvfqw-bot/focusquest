import Foundation

/// C7: cely stav hrace v jednom celku. Vsechna data appky jsou v UserDefaults pod temito klici:
///  - `focusquest.local-profile`        profil (hrdina, mince, inventar, zamrzle dny, ukoly) ~1–2 kB,
///  - `focusquest.local-stats`          statistiky a historie bitev ~0,5 kB + ~250 B za bitvu,
///  - `focusquest.sensory-preferences`  nastaveni, postup ve svetech, focus oblasti ~2 kB,
///  - `fq.stateMeta`                    verze formatu a cas posledni zmeny.
/// Drobnosti mimo celek (zustavaji jen v telefonu): krok tutorialu, den oslavy serie, nabidnute milniky,
/// stav Focus filtru, snimek pro widget.
struct AppState: Codable, Sendable {
    var formatVersion: Int
    var modifiedAt: Date
    var profile: UserProfile
    var stats: PlayerStats
    var preferences: AppPreferences
}

/// Jedina vrstva pro nacteni a ulozeni celeho stavu. LocalProfileSyncService a PreferencesStore pres ni
/// zapisuji casovou znacku posledni zmeny; iCloud sync (CloudSync) cte a zapisuje cely stav.
enum AppStateStore {
    static let formatVersion = 1

    static let profileKey = "focusquest.local-profile"
    static let statsKey = "focusquest.local-stats"
    static let preferencesKey = "focusquest.sensory-preferences"
    static let metaKey = "fq.stateMeta"

    struct Meta: Codable, Sendable {
        var formatVersion: Int
        var modifiedAt: Date
    }

    static func meta(in defaults: UserDefaults) -> Meta? {
        defaults.data(forKey: metaKey).flatMap { try? JSONDecoder().decode(Meta.self, from: $0) }
    }

    /// Nejaka cast stavu se zmenila: nova casova znacka a (kdyz je zapnuty) zapis do iCloudu.
    static func touch(_ defaults: UserDefaults, at date: Date = Date()) {
        let meta = Meta(formatVersion: formatVersion, modifiedAt: date)
        if let data = try? JSONEncoder().encode(meta) { defaults.set(data, forKey: metaKey) }
        if defaults == UserDefaults.standard { CloudSync.scheduleUpload() }
    }

    /// Cely stav; nil, kdyz jeste neni profil ani statistiky (prvni spusteni).
    static func load(from defaults: UserDefaults) -> AppState? {
        let decoder = JSONDecoder()
        guard let profileData = defaults.data(forKey: profileKey),
              let profile = try? decoder.decode(UserProfile.self, from: profileData) else { return nil }
        let stats = defaults.data(forKey: statsKey).flatMap { try? decoder.decode(PlayerStats.self, from: $0) } ?? .initial
        let preferences = defaults.data(forKey: preferencesKey).flatMap { try? decoder.decode(AppPreferences.self, from: $0) } ?? AppPreferences()
        let meta = meta(in: defaults)
        return AppState(formatVersion: meta?.formatVersion ?? formatVersion, modifiedAt: meta?.modifiedAt ?? .distantPast, profile: profile, stats: stats, preferences: preferences)
    }

    /// Zapise cely stav (vcetne casove znacky stavu, ne aktualniho casu).
    static func save(_ state: AppState, to defaults: UserDefaults) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(state.profile) { defaults.set(data, forKey: profileKey) }
        if let data = try? encoder.encode(state.stats) { defaults.set(data, forKey: statsKey) }
        if let data = try? encoder.encode(state.preferences) { defaults.set(data, forKey: preferencesKey) }
        let meta = Meta(formatVersion: formatVersion, modifiedAt: state.modifiedAt)
        if let data = try? encoder.encode(meta) { defaults.set(data, forKey: metaKey) }
    }

    /// Velikost ulozenych dat v bajtech (Debug a odhad pro iCloud KVS, limit 1 MB).
    static func byteSizes(in defaults: UserDefaults) -> [(key: String, bytes: Int)] {
        [profileKey, statsKey, preferencesKey, metaKey].map { ($0, defaults.data(forKey: $0)?.count ?? 0) }
    }
}
