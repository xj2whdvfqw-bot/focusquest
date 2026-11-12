import Foundation

protocol ProfileSyncServiceProtocol: Sendable {
    func loadProfile() async throws -> UserProfile
    func loadStats() async throws -> PlayerStats
    func saveProfile(_ profile: UserProfile) async throws
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

actor LocalProfileSyncService: ProfileSyncServiceProtocol {
    private var profile = UserProfile.fresh(deviceID: "local-preview")
    private var stats = PlayerStats.initial

    func loadProfile() async throws -> UserProfile { profile }
    func loadStats() async throws -> PlayerStats { stats }
    func saveProfile(_ profile: UserProfile) async throws { self.profile = profile }
    func exchangeAppleToken(_ token: String) async throws { _ = token }
    func signOut() async throws { }
    func deleteAccount() async throws { profile = UserProfile.fresh(deviceID: "local-preview"); stats = .initial }
}