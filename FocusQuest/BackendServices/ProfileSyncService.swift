import Foundation

/// Profil a statistiky hrace. Aplikace nema server ani ucty, vse je ulozene v telefonu.
protocol ProfileSyncServiceProtocol: Sendable {
    func loadProfile() async throws -> UserProfile
    func loadStats() async throws -> PlayerStats
    func saveProfile(_ profile: UserProfile) async throws
    /// Zapise dokoncenou bitvu do statistik a vrati jejich novy stav.
    func recordBattle(_ summary: SessionSummary, bossDefeated: Bool) async throws -> PlayerStats
    /// Vyvojarske testovaci XP mimo bitvu. Vraci novy stav statistik.
    func addBonusXP(_ amount: Int) async throws -> PlayerStats
    /// Ladeni (#if DEBUG v Nastaveni): nastavi level primo. Vraci novy stav statistik.
    func setLevel(_ level: Int) async throws -> PlayerStats
    /// Trvale smazani predmetu (24 h po smazani): z historie a Bestiare zmizi jeho bitvy.
    func removeSubjectStats(_ subjectIDs: Set<String>) async throws -> PlayerStats
    /// C6: poznamka k bitve v historii. Vraci novy stav statistik.
    func setNote(_ note: String?, forSession id: UUID) async throws -> PlayerStats
    /// Reset progress v Nastaveni: smaze hrdinu, mince i statistiky a vrati vychozi stav.
    func resetProgress() async throws
}

/// Profil a statistiky ulozene jen v telefonu (rezim bez serveru).
/// Uklada se do UserDefaults, takze hrdina, mince i statistiky preziji restart appky.
actor LocalProfileSyncService: ProfileSyncServiceProtocol {
    private static let profileKey = "focusquest.local-profile"
    private static let statsKey = "focusquest.local-stats"

    private let defaults: UserDefaults
    private var profile: UserProfile
    private var stats: PlayerStats

    /// `suiteName` = vlastni uloziste (testy); nil = standardni UserDefaults appky.
    /// UserDefaults neni Sendable, proto si ho actor vytvari sam a nedostava ho zvenku.
    init(suiteName: String? = nil) {
        let defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        self.defaults = defaults
        profile = Self.read(UserProfile.self, key: Self.profileKey, from: defaults) ?? UserProfile.fresh(deviceID: "local-preview")
        stats = Self.read(PlayerStats.self, key: Self.statsKey, from: defaults) ?? .initial
    }

    func loadProfile() async throws -> UserProfile { profile }
    func loadStats() async throws -> PlayerStats { stats }

    func saveProfile(_ profile: UserProfile) async throws {
        self.profile = profile
        persist(profile, key: Self.profileKey)
    }

    func recordBattle(_ summary: SessionSummary, bossDefeated: Bool) async throws -> PlayerStats {
        stats.record(summary, bossDefeated: bossDefeated)
        persist(stats, key: Self.statsKey)
        return stats
    }

    func addBonusXP(_ amount: Int) async throws -> PlayerStats {
        stats.grantBonusXP(amount)
        persist(stats, key: Self.statsKey)
        return stats
    }

    func setLevel(_ level: Int) async throws -> PlayerStats {
        stats.setLevel(level)
        persist(stats, key: Self.statsKey)
        return stats
    }

    func removeSubjectStats(_ subjectIDs: Set<String>) async throws -> PlayerStats {
        stats.removeSubjects(subjectIDs)
        persist(stats, key: Self.statsKey)
        return stats
    }

    func setNote(_ note: String?, forSession id: UUID) async throws -> PlayerStats {
        guard let index = stats.sessionHistory.firstIndex(where: { $0.id == id }) else { return stats }
        stats.sessionHistory[index].note = note
        persist(stats, key: Self.statsKey)
        return stats
    }

    func resetProgress() async throws {
        profile = UserProfile.fresh(deviceID: "local-preview")
        stats = .initial
        defaults.removeObject(forKey: Self.profileKey)
        defaults.removeObject(forKey: Self.statsKey)
        defaults.removeObject(forKey: StoredDataBackup.key(for: Self.profileKey))
        defaults.removeObject(forKey: StoredDataBackup.key(for: Self.statsKey))
    }

    private func persist<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func read<Value: Decodable>(_ type: Value.Type, key: String, from defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        if let value = try? JSONDecoder().decode(type, from: data) { return value }
        // Data nejdou nacist (poskozena nebo z nekompatibilni verze): pred prepsanim novym profilem
        // se puvodni bajty ulozi stranou, aby se daly zachranit.
        StoredDataBackup.preserve(data, key: key, in: defaults)
        return nil
    }
}

/// Zaloha dat, ktera se nepodarilo nacist. Uklada se jen prvni zaloha, aby ji pozdejsi chyba neprepsala.
enum StoredDataBackup {
    static func key(for key: String) -> String { key + ".unreadable-backup" }

    static func preserve(_ data: Data, key: String, in defaults: UserDefaults) {
        let backupKey = Self.key(for: key)
        guard defaults.data(forKey: backupKey) == nil else { return }
        defaults.set(data, forKey: backupKey)
    }
}
