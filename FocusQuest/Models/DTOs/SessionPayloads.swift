import Foundation

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
    let serverTimestamp: Date
}

struct CompleteSessionResponse: Codable, Sendable {
    let stats: PlayerStats
    let boss: Boss
    let xpEarned: Int
}

extension JSONEncoder {
    /// Kodovani podepisovaneho heartbeatu bitvy (kontrola v telefonu).
    static var focusQuest: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Podepisovany payload musi mit stale stejne poradi klicu.
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
