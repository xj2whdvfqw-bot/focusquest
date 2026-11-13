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
    /// ID bosse pro Bestiar; starsi zaznamy ho nemaji.
    var bossID: String? = nil
}

/// Jeden radek Bestiare: kolikrat hrac porazil daneho bosse pri danem predmetu.
struct BestiaryEntry: Identifiable, Codable, Equatable, Sendable {
    let bossID: String
    var bossName: String
    let subject: StudySubject?
    var defeats: Int

    var id: String { "\(subject?.rawValue ?? "none")|\(bossID)" }
}

/// Porazeni bossove jednoho predmetu, serazeni od nejcastejsiho.
struct BestiaryGroup: Identifiable, Equatable, Sendable {
    let subject: StudySubject?
    let entries: [BestiaryEntry]

    var id: String { subject?.rawValue ?? "none" }
    var totalDefeats: Int { entries.reduce(0) { $0 + $1.defeats } }

    /// Skupiny podle predmetu: nejvic porazenych nahore, bitvy bez predmetu na konci.
    static func groups(from entries: [BestiaryEntry]) -> [BestiaryGroup] {
        var bySubject: [String: [BestiaryEntry]] = [:]
        for entry in entries where entry.defeats > 0 {
            bySubject[entry.subject?.rawValue ?? "none", default: []].append(entry)
        }
        let groups: [BestiaryGroup] = bySubject.values.map { list in
            let sorted = list.sorted { left, right in
                left.defeats == right.defeats ? left.bossName < right.bossName : left.defeats > right.defeats
            }
            return BestiaryGroup(subject: sorted[0].subject, entries: sorted)
        }
        return groups.sorted { left, right in
            if (left.subject == nil) != (right.subject == nil) { return left.subject != nil }
            if left.totalDefeats != right.totalDefeats { return left.totalDefeats > right.totalDefeats }
            return left.id < right.id
        }
    }
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
    /// Porazeni bossove podle predmetu. Uklada se spolu se statistikami (UserDefaults).
    var bestiary: [BestiaryEntry] = []

    var winRate: Double { battles > 0 ? Double(wins) / Double(battles) : 0 }
    var xpIntoLevel: Int { totalXP % 1000 }
    var xpForNextLevel: Int { 1000 }

    static let initial = PlayerStats(level: 1, totalXP: 0, wins: 0, battles: 0, streakDays: 0, bestCombo: 1, totalHPDealt: 0, sessionHistory: [])

    enum CodingKeys: String, CodingKey {
        case level, totalXP, wins, battles, streakDays, bestCombo, totalHPDealt, sessionHistory, bestiary
    }
}

extension PlayerStats {
    // Statistiky ze starsi verze Bestiar nemaji; bez tohohle by se cele zahodily.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        level = try container.decode(Int.self, forKey: .level)
        totalXP = try container.decode(Int.self, forKey: .totalXP)
        wins = try container.decode(Int.self, forKey: .wins)
        battles = try container.decode(Int.self, forKey: .battles)
        streakDays = try container.decode(Int.self, forKey: .streakDays)
        bestCombo = try container.decode(Int.self, forKey: .bestCombo)
        totalHPDealt = try container.decode(Int.self, forKey: .totalHPDealt)
        sessionHistory = try container.decode([SessionSummary].self, forKey: .sessionHistory)
        bestiary = (try? container.decodeIfPresent([BestiaryEntry].self, forKey: .bestiary)) ?? []
    }
}

extension PlayerStats {
    static let xpPerLevel = 1000

    /// Pripocte dokoncenou bitvu: XP, level, vyhry, historii, Bestiar a serii dni.
    mutating func record(_ summary: SessionSummary, bossDefeated: Bool, calendar: Calendar = .current) {
        let previousDay = sessionHistory.first?.completedAt
        battles += 1
        if bossDefeated {
            wins += 1
            recordDefeat(bossID: summary.bossID ?? summary.bossName, bossName: summary.bossName, subject: summary.subject)
        }
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

    /// Prida XP mimo bitvu (vyvojarske testovaci odmeny) a prepocita level.
    mutating func grantBonusXP(_ amount: Int) {
        totalXP += max(0, amount)
        level = max(1, totalXP / Self.xpPerLevel + 1)
    }

    private mutating func recordDefeat(bossID: String, bossName: String, subject: StudySubject?) {
        if let index = bestiary.firstIndex(where: { $0.bossID == bossID && $0.subject == subject }) {
            bestiary[index].defeats += 1
            bestiary[index].bossName = bossName
        } else {
            bestiary.append(BestiaryEntry(bossID: bossID, bossName: bossName, subject: subject, defeats: 1))
        }
    }
}
