import Foundation

enum BossTier: String, Codable, CaseIterable, Sendable {
    case novice, adept, elite, mythic
}

struct Boss: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    let tier: BossTier
    var maxHP: Int
    var currentHP: Int
    let pixelSpriteConfig: String
    let lootTable: [String]

    var isDefeated: Bool { currentHP <= 0 }
    var healthFraction: Double { maxHP > 0 ? Double(max(0, currentHP)) / Double(maxHP) : 0 }

    mutating func applyDamage(_ amount: Int) {
        currentHP = max(0, currentHP - max(0, amount))
    }

    // HP bosse si hrac voli sam: 1 HP = 1 minuta overeneho soustredeni.
    static let minutesRange = 1...240
    static let defaultMinutes = 25

    static func clampedMinutes(_ value: Int) -> Int {
        min(minutesRange.upperBound, max(minutesRange.lowerBound, value))
    }

    /// Stejny boss s plnym zdravim na zvoleny pocet minut.
    func withHP(minutes: Int) -> Boss {
        var copy = self
        copy.maxHP = Boss.clampedMinutes(minutes)
        copy.currentHP = copy.maxHP
        return copy
    }

    static let roster: [Boss] = [
        Boss(id: "chronos-slime", name: "Chronos Slime", tier: .novice, maxHP: 45, currentHP: 45, pixelSpriteConfig: "chronos-slime", lootTable: ["chronos-shield", "scholars-tome"]),
        Boss(id: "shadow-golem", name: "Shadow Golem", tier: .adept, maxHP: 90, currentHP: 90, pixelSpriteConfig: "shadow-golem", lootTable: ["scholars-tome"]),
        Boss(id: "void-dragon", name: "Void Dragon", tier: .mythic, maxHP: 180, currentHP: 180, pixelSpriteConfig: "void-dragon", lootTable: ["ember-charm"])
    ]
}