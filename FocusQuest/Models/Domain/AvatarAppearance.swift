import Foundation

/// Barva jako tri slozky 0-1. Model nezna SwiftUI; na Color ji prevadi az pohledova vrstva.
struct RGB: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red; self.green = green; self.blue = blue
    }
}

enum SkinTone: String, Codable, CaseIterable, Sendable, Identifiable {
    case porcelain, sand, honey, bronze, umber, ebony

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var rgb: RGB {
        switch self {
        case .porcelain: RGB(0.98, 0.87, 0.78)
        case .sand: RGB(0.94, 0.78, 0.63)
        case .honey: RGB(0.85, 0.65, 0.47)
        case .bronze: RGB(0.70, 0.49, 0.33)
        case .umber: RGB(0.50, 0.33, 0.22)
        case .ebony: RGB(0.33, 0.21, 0.15)
        }
    }
}

enum HairStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case short, long, spiky, mohawk, bald

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum HairColor: String, Codable, CaseIterable, Sendable, Identifiable {
    case ink, chestnut, blonde, ginger, silver, mint, violet

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var rgb: RGB {
        switch self {
        case .ink: RGB(0.12, 0.12, 0.17)
        case .chestnut: RGB(0.42, 0.25, 0.15)
        case .blonde: RGB(0.95, 0.80, 0.42)
        case .ginger: RGB(0.85, 0.42, 0.18)
        case .silver: RGB(0.80, 0.83, 0.88)
        case .mint: RGB(0.40, 0.85, 0.72)
        case .violet: RGB(0.62, 0.42, 0.90)
        }
    }
}

/// Paleta pro obleceni a boty.
enum GearColor: String, Codable, CaseIterable, Sendable, Identifiable {
    case crimson, ocean, forest, violet, gold, slate, snow, ink

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var rgb: RGB {
        switch self {
        case .crimson: RGB(0.80, 0.22, 0.30)
        case .ocean: RGB(0.20, 0.50, 0.88)
        case .forest: RGB(0.22, 0.60, 0.38)
        case .violet: RGB(0.52, 0.36, 0.84)
        case .gold: RGB(0.93, 0.72, 0.25)
        case .slate: RGB(0.38, 0.44, 0.56)
        case .snow: RGB(0.93, 0.94, 0.97)
        case .ink: RGB(0.14, 0.15, 0.22)
        }
    }
}

/// Misto na hrdinovi, kam pujde nasadit vybaveni z obchodu (dalsi buildy).
enum EquipmentSlot: String, Codable, CaseIterable, Sendable {
    case weapon, head, feet, gadget
}

/// Vzhled hrdiny. Kresli se po vrstvach (kuze, obleceni, vlasy...), viz AvatarSprite.
struct AvatarAppearance: Codable, Hashable, Sendable {
    var skin: SkinTone = .sand
    var hairStyle: HairStyle = .short
    var hairColor: HairColor = .chestnut
    var outfitColor: GearColor = .ocean
    var bootsColor: GearColor = .ink
    /// Nasazene vybaveni: klic je `EquipmentSlot.rawValue`, hodnota ID predmetu.
    /// Zatim prazdne - plnit se zacne s Inventarem a Obchodem.
    var equipment: [String: String] = [:]

    enum CodingKeys: String, CodingKey { case skin, hairStyle, hairColor, outfitColor, bootsColor, equipment }

    func equippedItemID(in slot: EquipmentSlot) -> String? { equipment[slot.rawValue] }

    mutating func equip(_ itemID: String?, in slot: EquipmentSlot) { equipment[slot.rawValue] = itemID }
}

extension AvatarAppearance {
    // Chybejici nebo neznama hodnota (starsi ci novejsi verze appky) se nahradi vychozi,
    // aby se kvuli jednomu poli nezahodil cely profil.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AvatarAppearance()
        skin = (try? container.decode(SkinTone.self, forKey: .skin)) ?? fallback.skin
        hairStyle = (try? container.decode(HairStyle.self, forKey: .hairStyle)) ?? fallback.hairStyle
        hairColor = (try? container.decode(HairColor.self, forKey: .hairColor)) ?? fallback.hairColor
        outfitColor = (try? container.decode(GearColor.self, forKey: .outfitColor)) ?? fallback.outfitColor
        bootsColor = (try? container.decode(GearColor.self, forKey: .bootsColor)) ?? fallback.bootsColor
        equipment = (try? container.decode([String: String].self, forKey: .equipment)) ?? [:]
    }
}

/// Jedna vrstva hrdiny: mrizka 16x16 ("#" = pixel) a jeji barva.
struct AvatarLayer: Identifiable, Hashable, Sendable {
    let id: String
    let rows: [String]
    let rgb: RGB
}

/// Sklada hrdinu z vrstev. Vybaveni z obchodu se sem prida jako dalsi vrstvy.
enum AvatarSprite {
    static let gridSize = 16

    static func layers(for appearance: AvatarAppearance, heroClass: HeroClass) -> [AvatarLayer] {
        var layers = [
            AvatarLayer(id: "skin", rows: grid([2: [5...10], 3: [5...10], 4: [5...10], 5: [5...10], 6: [7...8], 9: [3...3, 12...12], 10: [3...3, 12...12]]), rgb: appearance.skin.rgb),
            AvatarLayer(id: "outfit", rows: grid([7: [4...11], 8: [3...12], 9: [4...11], 10: [5...10], 12: [5...6, 9...10], 13: [5...6, 9...10]]), rgb: appearance.outfitColor.rgb),
            AvatarLayer(id: "belt", rows: grid([11: [5...10]]), rgb: classAccent(heroClass)),
            AvatarLayer(id: "boots", rows: grid([14: [4...6, 9...11]]), rgb: appearance.bootsColor.rgb)
        ]
        if let hair = hairSpans(appearance.hairStyle) {
            layers.append(AvatarLayer(id: "hair", rows: grid(hair), rgb: appearance.hairColor.rgb))
        }
        layers.append(AvatarLayer(id: "eyes", rows: grid([4: [6...6, 9...9]]), rgb: RGB(0.10, 0.10, 0.16)))
        return layers
    }

    static func classAccent(_ heroClass: HeroClass) -> RGB {
        switch heroClass {
        case .arcaneScholar: RGB(0.68, 0.45, 0.85)
        case .cyberRonin: RGB(0.26, 0.72, 0.82)
        case .alchemist: RGB(0.36, 0.73, 0.46)
        case .voidKnight: RGB(0.55, 0.58, 0.70)
        }
    }

    private static func hairSpans(_ style: HairStyle) -> [Int: [ClosedRange<Int>]]? {
        switch style {
        case .short: [1: [5...10], 2: [5...10], 3: [5...5, 10...10]]
        case .long: [1: [5...10], 2: [4...11], 3: [4...5, 10...11], 4: [4...4, 11...11], 5: [4...4, 11...11], 6: [4...4, 11...11], 7: [4...4, 11...11]]
        case .spiky: [0: [5...5, 7...7, 9...10], 1: [5...10], 2: [5...10], 3: [5...5, 10...10]]
        case .mohawk: [0: [7...8], 1: [7...8], 2: [7...8]]
        case .bald: nil
        }
    }

    /// Prevede rozsahy sloupcu po radcich na radky mrizky, aby se pixely nemusely pocitat rucne.
    static func grid(_ spans: [Int: [ClosedRange<Int>]]) -> [String] {
        (0..<gridSize).map { y in
            var cells = Array(repeating: Character("."), count: gridSize)
            for range in spans[y] ?? [] {
                for x in range where x >= 0 && x < gridSize { cells[x] = "#" }
            }
            return String(cells)
        }
    }
}
