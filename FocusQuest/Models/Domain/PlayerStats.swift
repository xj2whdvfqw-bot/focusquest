import Foundation

struct SessionSummary: Identifiable, Codable, Sendable {
    let id: UUID
    let bossName: String
    let verifiedMinutes: Int
    let xpEarned: Int
    let completedAt: Date
    let flawless: Bool
}

struct PlayerStats: Codable, Sendable {
    var level: Int
    var totalXP: Int
    var wins: Int
    var battles: Int
    var streakDays: Int
    var bestCombo: Int
    var totalHPDealt: Int
    var sessionHistory: [SessionSummary]

    var winRate: Double { battles > 0 ? Double(wins) / Double(battles) : 0 }
    var xpIntoLevel: Int { totalXP % 1000 }
    var xpForNextLevel: Int { 1000 }

    static let initial = PlayerStats(level: 1, totalXP: 0, wins: 0, battles: 0, streakDays: 0, bestCombo: 1, totalHPDealt: 0, sessionHistory: [])
}