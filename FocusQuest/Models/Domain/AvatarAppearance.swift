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

/// S1/M2: sloty vybavy hrdiny. V kazdem slotu je nejvys jedna vec; nasazeni nahradi jen vec ve stejnem slotu.
/// Head = helmy, klobouky, koruna; Main hand = zbrane tridy (prava ruka); Off hand = gadgety v leve ruce;
/// Neck = sluchatka kolem krku; Feet = boty; Back = batoh na zadech (jetpack).
enum EquipmentSlot: String, Codable, CaseIterable, Sendable {
    case head, mainHand, offHand, neck, feet, back
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
        equipment = Self.migratedEquipment((try? container.decode([String: String].self, forKey: .equipment)) ?? [:])
    }

    /// S1/M2: starsi verze mely sloty weapon a gadget (sluchatka, kalkulacka i jetpack v jednom). Kazdy znamy predmet
    /// se presune do sveho slotu podle katalogu; nezname ID zustane pod puvodnim klicem (novejsi verze appky).
    static func migratedEquipment(_ stored: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for key in stored.keys.sorted() {
            guard let id = stored[key] else { continue }
            if let item = EquipmentItem.item(withID: id) {
                result[item.slot.rawValue] = id
            } else if EquipmentSlot(rawValue: key) != nil, result[key] == nil {
                result[key] = id
            }
        }
        return result
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

    /// S1/M2: co ma hrdina v kazdem slotu. Main hand je vzdy obsazena: bez zbrane z obchodu (nebo se zbrani
    /// jine tridy, napr. po zmene tridy lektvarem) drzi vychozi zbran sve tridy. Nezname ID se preskoci.
    static func gear(for appearance: AvatarAppearance, heroClass: HeroClass) -> [EquipmentItem] {
        EquipmentSlot.allCases.compactMap { equippedItem(in: $0, appearance: appearance, heroClass: heroClass) }
    }

    static func equippedItem(in slot: EquipmentSlot, appearance: AvatarAppearance, heroClass: HeroClass) -> EquipmentItem? {
        if let stored = appearance.equippedItemID(in: slot).flatMap(EquipmentItem.item(withID:)),
           stored.slot == slot, stored.fits(heroClass) {
            return stored
        }
        return slot == .mainHand ? EquipmentItem.defaultWeapon(for: heroClass) : nil
    }

    static func layers(for appearance: AvatarAppearance, heroClass: HeroClass) -> [AvatarLayer] {
        let gear = gear(for: appearance, heroClass: heroClass)
        // S1/M3: doplnek tridy (naramenik, plast, toulec, satek) zustava vzdy nasazeny.
        let marks = classMarks(heroClass)
        var layers = marks.filter(\.behindBody).map(\.layer)
        layers += gear.filter(\.drawsBehindBody).flatMap(\.layers)
        layers += bodyLayers(for: appearance, heroClass: heroClass)
        // O1/H3: ucesy jsou vzdy cele videt; jen pokryvka hlavy z obchodu cast vlasu schova (maska).
        let headwear = gear.first { $0.slot == .head }
        if let hair = hairRows(appearance.hairStyle, under: headwear) {
            layers.append(AvatarLayer(id: "hair", rows: hair, rgb: appearance.hairColor.rgb))
        }
        layers.append(AvatarLayer(id: "eyes", rows: grid([4: [6...6, 9...9]]), rgb: RGB(0.10, 0.10, 0.16)))
        layers += marks.filter { !$0.behindBody }.map(\.layer)
        // Helmy, zbrane, gadgety, sluchatka a boty jsou nakreslene pres hrdinu.
        layers += gear.filter { !$0.drawsBehindBody }.flatMap(\.layers)
        return layers
    }

    /// Telo hrdiny: kuze, obleceni, pasek v barve tridy a boty.
    static func bodyLayers(for appearance: AvatarAppearance, heroClass: HeroClass) -> [AvatarLayer] {
        [
            AvatarLayer(id: "skin", rows: grid([2: [5...10], 3: [5...10], 4: [5...10], 5: [5...10], 6: [7...8], 9: [3...3, 12...12], 10: [3...3, 12...12]]), rgb: appearance.skin.rgb),
            AvatarLayer(id: "outfit", rows: grid([7: [4...11], 8: [3...12], 9: [4...11], 10: [5...10], 12: [5...6, 9...10], 13: [5...6, 9...10]]), rgb: appearance.outfitColor.rgb),
            AvatarLayer(id: "belt", rows: grid([11: [5...10]]), rgb: classAccent(heroClass)),
            AvatarLayer(id: "boots", rows: grid([14: [4...6, 9...11]]), rgb: appearance.bootsColor.rgb)
        ]
    }

    /// Doplnek, podle ktereho se povolani pozna na prvni pohled. Je vzdy nasazeny a nezabira zadny slot.
    struct ClassMark: Sendable {
        let behindBody: Bool
        let layer: AvatarLayer
    }

    static func classMarks(_ heroClass: HeroClass) -> [ClassMark] {
        func mark(_ id: String, behind: Bool = false, _ spans: [Int: [ClosedRange<Int>]], _ rgb: RGB) -> ClassMark {
            ClassMark(behindBody: behind, layer: AvatarLayer(id: "class-\(id)", rows: grid(spans), rgb: rgb))
        }
        // O1/H3: zadna trida nema pokryvku hlavy, ucesy jsou vzdy cele videt.
        // S1/M3: zbran tridy je predmet ve slotu Main hand (EquipmentItem.defaultWeapon); tady zustal jen doplnek.
        // Doplnky nezasahuji do slotu: prava ruka (sloupce 12-15) patri zbrani, leva ruka (sloupce 0-2, radky 9-11)
        // gadgetu, krk (radky 6-7, sloupce 5-10) sluchatkum. Proto je toulec na levem rameni, plast nesaha
        // za pravou ruku a satek u krku nechava misto muslim sluchatek.
        switch heroClass {
        case .warrior:
            return [mark("pauldron", [6: [3...3], 7: [2...3], 8: [2...3]], RGB(0.72, 0.76, 0.84))]
        case .mage:
            return [mark("cape", behind: true, [7: [3...12], 8: [2...12], 9: [3...12], 10: [4...11]], RGB(0.36, 0.22, 0.62))]
        case .archer:
            return [
                mark("quiver", behind: true, [4: [2...3], 5: [2...3], 6: [2...3], 7: [2...3], 8: [2...2]], RGB(0.50, 0.32, 0.17)),
                mark("fletching", behind: true, [2: [2...2], 3: [2...3]], RGB(0.92, 0.90, 0.82))
            ]
        case .rogue:
            return [mark("scarf", [5: [5...10], 6: [6...9]], RGB(0.22, 0.22, 0.30))]
        }
    }

    static func classAccent(_ heroClass: HeroClass) -> RGB {
        switch heroClass {
        case .mage: RGB(0.68, 0.45, 0.85)
        case .rogue: RGB(0.26, 0.72, 0.82)
        case .archer: RGB(0.36, 0.73, 0.46)
        case .warrior: RGB(0.78, 0.30, 0.26)
        }
    }

    /// O1/H3: radky vlasu pod pokryvkou hlavy z obchodu (maska). Bez pokryvky cely ucs.
    /// Pod pokryvkou se schova vse do jejiho okraje (`hairBrimRow`) i kazdy pixel, ktery pokryvka kresli;
    /// Long nechava jen pramínky po stranach pod okrajem, Spiky a Mohawk se schovaji cele, Short a Bald podle tvaru.
    /// nil = zadne vlasy.
    static func hairRows(_ style: HairStyle, under headwear: EquipmentItem?) -> [String]? {
        guard let spans = hairSpans(style) else { return nil }
        var rows = grid(spans)
        guard let headwear, let brim = headwear.hairBrimRow else { return rows }
        let covered = headwear.layers.map { $0.rows }
        for y in rows.indices {
            var cells = Array(rows[y])
            for x in cells.indices where cells[x] == "#" {
                let underHat = covered.contains { Array($0[y])[x] == "#" }
                let hidden: Bool = switch style {
                case .spiky, .mohawk: true
                case .long: y <= brim || (x > 4 && x < 11)
                case .short, .bald: y <= brim
                }
                if hidden || underHat { cells[x] = "." }
            }
            rows[y] = String(cells)
        }
        return rows.contains { $0.contains("#") } ? rows : nil
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
