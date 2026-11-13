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
    // Nejkratsi bitva je 10 minut a delka se meni po 5 minutach.
    static let minutesRange = 10...240
    static let minutesStep = 5
    static let defaultMinutes = 25

    /// Zaokrouhli na nejblizsich 5 minut a drzi hodnotu v rozsahu 10-240.
    static func clampedMinutes(_ value: Int) -> Int {
        let snapped = Int((Double(value) / Double(minutesStep)).rounded()) * minutesStep
        return min(minutesRange.upperBound, max(minutesRange.lowerBound, snapped))
    }

    /// Vychozi HP konkretniho bosse, dokud si ho hrac nezmeni.
    static func defaultMinutes(for bossID: String) -> Int {
        clampedMinutes(roster.first { $0.id == bossID }?.maxHP ?? defaultMinutes)
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