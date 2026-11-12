import Foundation

protocol ProfileSyncServiceProtocol: Sendable {
    func loadProfile() async throws -> UserProfile
    func loadStats() async throws -> PlayerStats
    func saveProfile(_ profile: UserProfile) async throws
    /// Zapise dokoncenou bitvu do statistik a vrati jejich novy stav.
    func recordBattle(_ summary: SessionSummary, bossDefeated: Bool) async throws -> PlayerStats
    func exchangeAppleToken(_ token: String) async throws
    func signOut() async throws
    func deleteAccount() async throws
}

struct ProfileSyncService: ProfileSyncServiceProtocol {
    let api: APIClient
    let keychain: any KeychainServiceProtocol

    func loadProfile() async throws -> UserProfile {
        try await api.get("v1/profile", as: UserProfile.self)
    }

    func loadStats() async throws -> PlayerStats {
        try await api.get("v1/stats", as: PlayerStats.self)
    }

    func saveProfile(_ profile: UserProfile) async throws {
        let _: EmptyAcknowledgement = try await api.post("v1/profile", body: profile, as: EmptyAcknowledgement.self)
    }

    func recordBattle(_ summary: SessionSummary, bossDefeated: Bool) async throws -> PlayerStats {
        // Na serveru statistiky pocita sluzba pri dokonceni bitvy; tady se jen nactou.
        try await loadStats()
    }

    func exchangeAppleToken(_ token: String) async throws {
        let response = try await api.post("v1/auth/apple", body: AppleTokenRequest(identityToken: token), as: AppleTokenExchangeResponse.self)
        try await keychain.save(Data(response.accessToken.utf8), for: "auth-token")
    }

    func signOut() async throws {
        try await api.delete("v1/auth/session")
        try await keychain.delete("auth-token")
    }

    func deleteAccount() async throws {
        try await api.delete("v1/account")
        try await keychain.deleteAll()
    }
}

private struct AppleTokenRequest: Codable, Sendable { let identityToken: String }
private struct AppleTokenExchangeResponse: Codable, Sendable { let accessToken: String }

/// Profil a statistiky ulozene jen v telefonu (rezim bez serveru).
/// Uklada se do UserDefaults, takze hrdina, mince i vesnice preziji restart appky.
actor LocalProfileSyncService: ProfileSyncServiceProtocol {
    private static let profileKey = "focusquest.local-profile"
    private static let statsKey = "focusquest.local-stats"

    private let defaults: UserDefaults
    private var profile: UserProfile
    private var stats: PlayerStats

    init(defaults: UserDefaults = .standard) {
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

    func exchangeAppleToken(_ token: String) async throws { _ = token }
    func signOut() async throws { }

    func deleteAccount() async throws {
        profile = UserProfile.fresh(deviceID: "local-preview")
        stats = .initial
        defaults.removeObject(forKey: Self.profileKey)
        defaults.removeObject(forKey: Self.statsKey)
    }

    private func persist<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func read<Value: Decodable>(_ type: Value.Type, key: String, from defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
