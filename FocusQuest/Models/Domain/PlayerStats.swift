import Foundation

struct SessionSummary: Identifiable, Codable, Sendable {
    let id: UUID
    let bossName: String
    let verifiedMinutes: Int
    let xpEarned: Int
    let completedAt: Date
    let flawless: Bool
    /// Predmet bitvy; starsi zaznamy ho nemaji.
    var subject: StudySubject? = nil
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

extension PlayerStats {
    static let xpPerLevel = 1000

    /// Pripocte dokoncenou bitvu: XP, level, vyhry, historii a serii dni.
    mutating func record(_ summary: SessionSummary, bossDefeated: Bool, calendar: Calendar = .current) {
        let previousDay = sessionHistory.first?.completedAt
        battles += 1
        if bossDefeated { wins += 1 }
        totalXP += max(0, summary.xpEarned)
        level = max(1, totalXP / Self.xpPerLevel + 1)
        totalHPDealt += max(0, summary.verifiedMinutes)
        sessionHistory.insert(summary, at: 0)

        if let previousDay {
            if calendar.isDate(previousDay, inSameDayAs: summary.completedAt) {
                streakDays = max(1, streakDays)
            } else if let dayAfter = calendar.date(byAdding: .day, value: 1, to: previousDay), calendar.isDate(dayAfter, inSameDayAs: summary.completedAt) {
                streakDays += 1
            } else {
                streakDays = 1
            }
        } else {
            streakDays = 1
        }
    }
}
