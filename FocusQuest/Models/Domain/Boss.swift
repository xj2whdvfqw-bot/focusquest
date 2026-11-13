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
    static func initialMinutes(for bossID: String) -> Int {
        clampedMinutes(roster.first { $0.id == bossID }?.maxHP ?? defaultMinutes)
    }

    /// Stejny boss s plnym zdravim na zvoleny pocet minut.
    func withHP(minutes: Int) -> Boss {
        var copy = self
        copy.maxHP = Boss.clampedMinutes(minutes)
        copy.currentHP = copy.maxHP
        return copy
    }

    var category: BossCategory { Boss.categoryByID[id] ?? .brainrot }

    /// Bossove podle kategorii; maxHP je jejich vychozi delka bitvy v minutach.
    static let roster: [Boss] = [
        Boss(id: "tung-tung-sahur", name: "Tung Tung Tung Sahur", tier: .novice, maxHP: 25, currentHP: 25, pixelSpriteConfig: "tung-tung-sahur", lootTable: ["chronos-shield"]),
        Boss(id: "ballerina-cappuccina", name: "Ballerina Cappuccina", tier: .adept, maxHP: 30, currentHP: 30, pixelSpriteConfig: "ballerina-cappuccina", lootTable: ["scholars-tome"]),
        Boss(id: "tralalero-tralala", name: "Tralalero Tralala", tier: .elite, maxHP: 45, currentHP: 45, pixelSpriteConfig: "tralalero-tralala", lootTable: ["ember-charm"]),
        Boss(id: "banana-bandit", name: "Banana Bandit", tier: .novice, maxHP: 20, currentHP: 20, pixelSpriteConfig: "banana-bandit", lootTable: ["chronos-shield"]),
        Boss(id: "goggle-grunt", name: "Goggle Grunt", tier: .adept, maxHP: 35, currentHP: 35, pixelSpriteConfig: "goggle-grunt", lootTable: ["scholars-tome"]),
        Boss(id: "purple-chomper", name: "Purple Chomper", tier: .elite, maxHP: 50, currentHP: 50, pixelSpriteConfig: "purple-chomper", lootTable: ["chronos-shield", "scholars-tome"]),
        Boss(id: "captain-procrastination", name: "Captain Procrastination", tier: .adept, maxHP: 40, currentHP: 40, pixelSpriteConfig: "captain-procrastination", lootTable: ["scholars-tome"]),
        Boss(id: "dark-doomscroller", name: "The Dark Doomscroller", tier: .elite, maxHP: 60, currentHP: 60, pixelSpriteConfig: "dark-doomscroller", lootTable: ["chronos-shield"]),
        Boss(id: "iron-distraction", name: "Iron Distraction", tier: .mythic, maxHP: 90, currentHP: 90, pixelSpriteConfig: "iron-distraction", lootTable: ["ember-charm"])
    ]

    private static let categoryByID: [String: BossCategory] = [
        "tung-tung-sahur": .brainrot, "ballerina-cappuccina": .brainrot, "tralalero-tralala": .brainrot,
        "banana-bandit": .henchlings, "goggle-grunt": .henchlings, "purple-chomper": .henchlings,
        "captain-procrastination": .heroes, "dark-doomscroller": .heroes, "iron-distraction": .heroes
    ]
}

/// Skupiny bossu v Arene.
enum BossCategory: String, CaseIterable, Sendable, Identifiable {
    case brainrot, henchlings, heroes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brainrot: "Brainrot"
        case .henchlings: "Henchlings"
        case .heroes: "Super Slackers"
        }
    }

    var bosses: [Boss] { Boss.roster.filter { $0.category == self } }
}