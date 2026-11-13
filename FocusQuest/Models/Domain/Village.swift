import Foundation

/// Stupne obydli od chatrce po mesto. Poradi pripadu = poradi vylepsovani.
enum DwellingStage: String, Codable, CaseIterable, Sendable, Identifiable {
    case woodenHut, brickCottage, stoneHouse, castle, village, city

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .woodenHut: "Wooden Hut"
        case .brickCottage: "Brick House"
        case .stoneHouse: "Stone House"
        case .castle: "Castle"
        case .village: "Thriving Village"
        case .city: "Scholar City"
        }
    }

    var summary: String {
        switch self {
        case .woodenHut: "A drafty shack. Every legend starts somewhere."
        case .brickCottage: "Solid walls and a real chimney. The rain stays outside."
        case .stoneHouse: "Thick stone, warm hearth, room for a proper library."
        case .castle: "Towers, banners and a gate that bosses fear to knock on."
        case .village: "Neighbors moved in. Your focus built a community."
        case .city: "A whole city grown from quiet hours of study."
        }
    }

    var next: DwellingStage? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    /// Co je potreba ke stavbe tohoto stupne (z predchoziho).
    var requirement: VillageRequirement {
        switch self {
        case .woodenHut: VillageRequirement(level: 1, bossesDefeated: 0, coins: 0)
        case .brickCottage: VillageRequirement(level: 1, bossesDefeated: 1, coins: 50)
        case .stoneHouse: VillageRequirement(level: 2, bossesDefeated: 3, coins: 150)
        case .castle: VillageRequirement(level: 4, bossesDefeated: 8, coins: 400)
        case .village: VillageRequirement(level: 7, bossesDefeated: 15, coins: 900)
        case .city: VillageRequirement(level: 12, bossesDefeated: 30, coins: 2000)
        }
    }
}

struct VillageRequirement: Hashable, Sendable {
    let level: Int
    let bossesDefeated: Int
    /// Cena v mincich; pri vylepseni se odecte.
    let coins: Int

    func isMet(level: Int, bossesDefeated: Int, coins: Int) -> Bool {
        level >= self.level && bossesDefeated >= self.bossesDefeated && coins >= self.coins
    }
}

/// Stav hracovy zakladny. Uklada se jako soucast profilu.
struct VillageState: Codable, Hashable, Sendable {
    var stage: DwellingStage = .woodenHut
    /// Kdy byl postaven ktery stupen (klic je `DwellingStage.rawValue`).
    var builtAt: [String: Date] = [:]
    /// Dekorace a vedlejsi budovy - pripraveno pro dalsi buildy.
    var decorationIDs: [String] = []

    enum CodingKeys: String, CodingKey { case stage, builtAt, decorationIDs }

    var nextStage: DwellingStage? { stage.next }

    func canUpgrade(level: Int, bossesDefeated: Int, coins: Int) -> Bool {
        guard let next = nextStage else { return false }
        return next.requirement.isMet(level: level, bossesDefeated: bossesDefeated, coins: coins)
    }

    /// Postavi dalsi stupen a vrati jeho cenu v mincich; nil = podminky nejsou splnene.
    mutating func upgrade(level: Int, bossesDefeated: Int, coins: Int, now: Date = Date()) -> Int? {
        guard let next = nextStage, canUpgrade(level: level, bossesDefeated: bossesDefeated, coins: coins) else { return nil }
        stage = next
        builtAt[next.rawValue] = now
        return next.requirement.coins
    }
}

extension VillageState {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stage = (try? container.decode(DwellingStage.self, forKey: .stage)) ?? .woodenHut
        builtAt = (try? container.decode([String: Date].self, forKey: .builtAt)) ?? [:]
        decorationIDs = (try? container.decode([String].self, forKey: .decorationIDs)) ?? []
    }
}

/// Odmeny za bitvu v mincich.
enum RewardRules {
    static let coinsPerVerifiedMinute = 1
    static let bossDefeatBonus = 10

    static func coins(verifiedMinutes: Int, bossDefeated: Bool) -> Int {
        max(0, verifiedMinutes) * coinsPerVerifiedMinute + (bossDefeated ? bossDefeatBonus : 0)
    }
}
