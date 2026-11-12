import Foundation

enum LootRarity: String, Codable, CaseIterable, Sendable {
    case common, rare, epic, legendary
}

enum LootPerk: Codable, Hashable, Sendable {
    case graceShield(seconds: Int)
    case experienceBonus(percent: Int)
    case companionUnlock(String)
}

struct LootItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let rarity: LootRarity
    let perk: LootPerk

    static let catalog: [LootItem] = [
        LootItem(id: "chronos-shield", name: "Chronos Shield", description: "+1 second grace once per session", rarity: .epic, perk: .graceShield(seconds: 1)),
        LootItem(id: "scholars-tome", name: "Scholar's Tome", description: "+10% verified XP", rarity: .rare, perk: .experienceBonus(percent: 10)),
        LootItem(id: "ember-charm", name: "Ember Charm", description: "Unlocks the Ember Dragonling", rarity: .legendary, perk: .companionUnlock("ember-dragonling"))
    ]
}