import Foundation

struct SignedRequest: Codable, Sendable {
    let payload: Data
    let nonce: String
    let hmacSHA256: String?
    let appAttestAssertion: Data?
}

struct StartSessionRequest: Codable, Sendable {
    let bossID: String
    let mode: SessionMode
    /// HP bosse zvolene hracem (minuty soustredeni).
    let targetMinutes: Int
    let clientNonce: String
    let clientUptime: TimeInterval
}

struct StartSessionResponse: Codable, Sendable {
    let sessionID: String
    let sessionNonce: String
    let serverTimestamp: Date
}

struct HeartbeatRequest: Codable, Sendable {
    let sessionID: String
    let monotonicElapsedSeconds: TimeInterval
    let motionIntegrityToken: String
    let clientNonce: String
}

struct HeartbeatResponse: Codable, Sendable {
    let authorizedDamage: Int
    let authoritativeBossHP: Int
    let comboMultiplier: Int
    let serverTimestamp: Date
}

struct ViolationRequest: Codable, Sendable {
    let sessionID: String
    let reason: String
    let monotonicElapsedSeconds: TimeInterval
}

struct CompleteSessionResponse: Codable, Sendable {
    let stats: PlayerStats
    let boss: Boss
    let loot: LootItem?
    let xpEarned: Int
}
