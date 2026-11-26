import Foundation

extension EquipmentSlot {
    /// S1/M5: nazev slotu v panelu veci ("Main hand · replaces Battle Axe").
    var displayName: String {
        switch self {
        case .head: "Head"
        case .mainHand: "Main hand"
        case .offHand: "Off hand"
        case .neck: "Neck"
        case .feet: "Feet"
        case .back: "Back"
        }
    }
}

/// Police v obchode. Jedna police muze nest veci z vic slotu (Gadgets: Off hand, Neck, Back).
enum EquipmentShelf: String, CaseIterable, Sendable {
    case head, weapons, boots, gadgets

    var title: String {
        switch self {
        case .head: "Helmets & hats"
        case .weapons: "Weapons"
        case .boots: "Boots"
        case .gadgets: "Gadgets"
        }
    }

    /// Poradi polic v obchode.
    static let shopOrder: [EquipmentShelf] = [.head, .weapons, .boots, .gadgets]
}

/// Vybaveni z obchodu. Kazdy predmet je par pixelovych vrstev na mrizce hrdiny 16x16,
/// takze po koupi a nasazeni je opravdu videt na postavicce.
///
/// Mrizka hrdiny: vlasy radky 0-3, hlava 2-5 (sloupce 5-10), oci radek 4, krk radek 6 (sloupce 7-8),
/// trup 7-10, ruce radky 9-10 ve sloupcich 3 a 12, opasek 11, nohy 12-13, boty 14.
///
/// S1/M2: kazdy slot ma na mrizce svou oblast, takze se veci z ruznych slotu nikdy neprekryvaji:
/// Head radky 0-2; Main hand sloupce 12-15 radky 0-11 (bez 12,0-1 kde jsou rohy helmy a 12,7 kde je plast);
/// Off hand sloupce 1-2 radky 9-11; Neck radky 6-7 sloupce 5-10; Feet radky 12-15 (kridla ve sloupcich 2-3
/// a 12-13); Back za telem, videt jen u ramen (4 a 11, radky 5-6) a plamen u boku (radky 11-12).
/// Hlida to `EquipmentSlotTests`.
struct EquipmentItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let summary: String
    let slot: EquipmentSlot
    let price: Int
    /// S1/M3: zbran patri jedne tride; nil = predmet muze nosit kazda trida.
    let heroClass: HeroClass?
    /// S1/M3: vychozi zbran tridy: zdarma, vzdy vlastnena, drzi ji prazdna Main hand.
    let isClassDefault: Bool
    /// true = kresli se za telem (raketovy batoh).
    let drawsBehindBody: Bool
    /// O1/H3: pokryvka hlavy definuje masku ucesu: vlasy do tohoto radku (vcetne) se pod ni schovaji
    /// (viz `AvatarSprite.hairRows`). nil = predmet vlasy nezakryva.
    let hairBrimRow: Int?
    let layers: [AvatarLayer]

    /// Jedna barevna cast predmetu: radky mrizky a v nich sloupce.
    struct Part {
        let name: String
        let spans: [Int: [ClosedRange<Int>]]
        let rgb: RGB
        init(_ name: String, _ spans: [Int: [ClosedRange<Int>]], _ rgb: RGB) { self.name = name; self.spans = spans; self.rgb = rgb }
    }

    init(id: String, name: String, summary: String, slot: EquipmentSlot, price: Int, heroClass: HeroClass? = nil, isClassDefault: Bool = false, drawsBehindBody: Bool = false, hairBrimRow: Int? = nil, parts: [Part]) {
        self.id = id
        self.name = name
        self.summary = summary
        self.slot = slot
        self.price = price
        self.heroClass = heroClass
        self.isClassDefault = isClassDefault
        self.drawsBehindBody = drawsBehindBody
        self.hairBrimRow = hairBrimRow
        self.layers = parts.map { AvatarLayer(id: "\(id)-\($0.name)", rows: AvatarSprite.grid($0.spans), rgb: $0.rgb) }
    }

    /// Muze ho nosit tato trida (zbrane jen sve tride, ostatni vybaveni kazda).
    func fits(_ heroClass: HeroClass) -> Bool { self.heroClass == nil || self.heroClass == heroClass }

    var shelf: EquipmentShelf {
        switch slot {
        case .head: .head
        case .mainHand: .weapons
        case .feet: .boots
        case .offHand, .neck, .back: .gadgets
        }
    }

    static func item(withID id: String) -> EquipmentItem? { catalog.first { $0.id == id } }

    /// S1/M3: vychozi zbran tridy (Battle Axe, Oak Staff, Short Bow, Dagger).
    static func defaultWeapon(for heroClass: HeroClass) -> EquipmentItem {
        catalog.first { $0.isClassDefault && $0.heroClass == heroClass }!
    }

    /// Zbrane jedne tridy v poradi obchodu (vychozi prvni).
    static func weapons(for heroClass: HeroClass) -> [EquipmentItem] {
        catalog.filter { $0.slot == .mainHand && $0.heroClass == heroClass }
    }

    private static let steel = RGB(0.72, 0.76, 0.84)
    private static let gold = RGB(0.98, 0.78, 0.25)
    private static let ivory = RGB(0.97, 0.93, 0.80)
    private static let wood = RGB(0.58, 0.38, 0.20)
    private static let classWood = RGB(0.55, 0.36, 0.18)
    private static let darkWood = RGB(0.38, 0.24, 0.13)
    private static let blade = RGB(0.88, 0.92, 0.98)
    private static let cyan = RGB(0.40, 0.88, 1.00)
    private static let flame = RGB(1.00, 0.55, 0.16)
    private static let ink = RGB(0.12, 0.12, 0.18)
    private static let string = RGB(0.92, 0.90, 0.82)

    /// Sloupec 13 v radcich `rows` (rukojeti, cepele, luky).
    private static func column(_ x: Int, _ rows: ClosedRange<Int>) -> [Int: [ClosedRange<Int>]] {
        Dictionary(uniqueKeysWithValues: rows.map { ($0, [x...x]) })
    }

    static let catalog: [EquipmentItem] = [
        // Head
        EquipmentItem(id: "viking-helmet", name: "Viking Helmet", summary: "Steel dome with two proud horns.", slot: .head, price: 150, hairBrimRow: 2, parts: [
            Part("dome", [0: [6...9], 1: [5...10]], steel),
            Part("rim", [2: [4...11]], gold),
            Part("horns", [0: [3...3, 12...12], 1: [3...4, 11...12]], ivory)
        ]),
        EquipmentItem(id: "wizard-hat", name: "Wizard Hat", summary: "Pointy, starry and full of answers.", slot: .head, price: 220, hairBrimRow: 2, parts: [
            Part("cone", [0: [7...8], 1: [6...9], 2: [4...11]], RGB(0.45, 0.30, 0.85)),
            Part("star", [1: [7...7]], gold)
        ]),
        EquipmentItem(id: "royal-crown", name: "Royal Crown", summary: "For the ruler of deep focus.", slot: .head, price: 600, hairBrimRow: 1, parts: [
            Part("gold", [0: [5...5, 7...8, 10...10], 1: [5...10]], gold),
            Part("gems", [1: [6...6, 9...9]], RGB(0.90, 0.22, 0.35))
        ]),

        // Main hand: Warrior (sekery, mece)
        EquipmentItem(id: "battle-axe", name: "Battle Axe", summary: "Every warrior's trusty first axe.", slot: .mainHand, price: 0, heroClass: .warrior, isClassDefault: true, parts: [
            Part("handle", column(13, 3...11), classWood),
            Part("blade", [3: [14...15], 4: [12...12, 14...15], 5: [14...15], 6: [14...14]], steel)
        ]),
        EquipmentItem(id: "wooden-sword", name: "Wooden Sword", summary: "Every hero's first blade.", slot: .mainHand, price: 60, heroClass: .warrior, parts: [
            Part("blade", column(13, 3...7), wood),
            Part("guard", [8: [12...14]], darkWood),
            Part("grip", column(13, 9...10), darkWood)
        ]),
        EquipmentItem(id: "excalibur", name: "Excalibur", summary: "Pulled from the stone of procrastination.", slot: .mainHand, price: 400, heroClass: .warrior, parts: [
            Part("blade", column(13, 0...7), blade),
            Part("guard", [8: [12...12, 14...14], 11: [13...13]], gold),
            Part("gem", [8: [13...13]], RGB(0.25, 0.45, 0.95)),
            Part("grip", column(13, 9...10), darkWood)
        ]),
        EquipmentItem(id: "flame-axe", name: "Flame Axe", summary: "Its edge burns hotter with every minute.", slot: .mainHand, price: 320, heroClass: .warrior, parts: [
            Part("handle", column(13, 2...11), darkWood),
            Part("blade", [2: [14...14], 3: [15...15], 4: [12...12, 15...15], 5: [15...15], 6: [14...14]], flame),
            Part("glow", [3: [14...14], 4: [14...14], 5: [14...14]], gold),
            Part("tip", [1: [14...14]], RGB(0.90, 0.25, 0.15))
        ]),

        // Main hand: Mage (hole)
        EquipmentItem(id: "oak-staff", name: "Oak Staff", summary: "A mage's first staff, worn smooth by study.", slot: .mainHand, price: 0, heroClass: .mage, isClassDefault: true, parts: [
            Part("staff", column(13, 3...11), classWood),
            Part("gem", [1: [13...13], 2: [12...14]], RGB(0.68, 0.45, 0.85))
        ]),
        EquipmentItem(id: "magic-staff", name: "Magic Staff", summary: "Glows brighter the longer you focus.", slot: .mainHand, price: 300, heroClass: .mage, parts: [
            Part("staff", column(13, 4...11), wood),
            Part("orb", [1: [13...13], 2: [12...14], 3: [12...14]], cyan)
        ]),
        EquipmentItem(id: "crystal-staff", name: "Crystal Staff", summary: "A shard of pure, quiet concentration.", slot: .mainHand, price: 450, heroClass: .mage, parts: [
            Part("shaft", column(13, 4...11), RGB(0.80, 0.82, 0.90)),
            Part("crystal", [0: [13...13], 1: [14...14], 2: [13...14], 3: [13...13]], RGB(0.55, 0.90, 0.95)),
            Part("shine", [1: [13...13]], RGB(1.0, 1.0, 1.0))
        ]),

        // Main hand: Archer (luky v prave ruce)
        EquipmentItem(id: "short-bow", name: "Short Bow", summary: "Light, quick and always ready.", slot: .mainHand, price: 0, heroClass: .archer, isClassDefault: true, parts: [
            Part("bow", [4: [13...13], 5: [14...14], 6: [15...15], 7: [15...15], 8: [15...15], 9: [15...15], 10: [14...14], 11: [13...13]], classWood),
            Part("string", column(13, 5...10), string)
        ]),
        EquipmentItem(id: "elven-bow", name: "Elven Bow", summary: "Carved from a tree that never sleeps.", slot: .mainHand, price: 280, heroClass: .archer, parts: [
            Part("bow", [3: [14...14], 4: [15...15], 5: [15...15], 6: [15...15], 7: [15...15], 8: [15...15], 9: [15...15], 10: [14...14]], RGB(0.36, 0.62, 0.36)),
            Part("tips", [2: [13...13], 11: [13...13]], gold),
            Part("string", column(13, 3...10), RGB(0.90, 0.95, 1.0))
        ]),
        EquipmentItem(id: "golden-bow", name: "Golden Bow", summary: "Never misses a deadline.", slot: .mainHand, price: 500, heroClass: .archer, parts: [
            Part("bow", [3: [13...13], 4: [14...14], 5: [15...15], 6: [15...15], 8: [15...15], 9: [15...15], 10: [14...14], 11: [13...13]], gold),
            Part("gem", [7: [15...15]], RGB(0.90, 0.22, 0.35)),
            Part("string", column(13, 4...10), RGB(1.0, 1.0, 1.0))
        ]),

        // Main hand: Rogue (dyky, noze)
        EquipmentItem(id: "dagger", name: "Dagger", summary: "Small, sharp and easy to hide.", slot: .mainHand, price: 0, heroClass: .rogue, isClassDefault: true, parts: [
            Part("blade", column(13, 6...8), steel),
            Part("hilt", [9: [12...14], 10: [13...13]], classWood)
        ]),
        EquipmentItem(id: "twin-knives", name: "Twin Knives", summary: "Two quick cuts through any distraction.", slot: .mainHand, price: 200, heroClass: .rogue, parts: [
            Part("blades", [5: [13...13, 15...15], 6: [13...13, 15...15], 7: [13...13, 15...15]], blade),
            Part("guards", [8: [13...13, 15...15]], gold),
            Part("grips", [9: [13...13, 15...15], 10: [13...13, 15...15]], darkWood)
        ]),
        EquipmentItem(id: "shadow-blade", name: "Shadow Blade", summary: "Strikes before the scroll even starts.", slot: .mainHand, price: 420, heroClass: .rogue, parts: [
            Part("blade", [3: [14...14], 5: [13...13], 6: [13...13], 7: [13...13]], RGB(0.30, 0.22, 0.45)),
            Part("edge", [2: [15...15], 3: [15...15], 4: [14...14], 5: [14...14]], RGB(0.62, 0.50, 0.88)),
            Part("guard", [8: [12...14]], ink),
            Part("grip", column(13, 9...10), darkWood)
        ]),

        // Feet
        EquipmentItem(id: "flying-boots", name: "Flying Boots", summary: "Winged boots. Mind the ceiling.", slot: .feet, price: 250, parts: [
            Part("boots", [14: [4...6, 9...11]], gold),
            Part("wings", [12: [2...2, 13...13], 13: [2...3, 12...13]], RGB(0.96, 0.97, 1.00))
        ]),
        EquipmentItem(id: "rocket-boots", name: "Rocket Boots", summary: "Zero to library in three seconds.", slot: .feet, price: 180, parts: [
            Part("boots", [14: [4...6, 9...11]], RGB(0.85, 0.22, 0.28)),
            Part("flame", [15: [4...6, 9...11]], flame)
        ]),

        // Gadgets: Neck (sluchatka kolem krku), Off hand (leva ruka), Back (za telem)
        EquipmentItem(id: "focus-headphones", name: "Focus Headphones", summary: "Noise-cancelling, distraction-cancelling.", slot: .neck, price: 100, parts: [
            Part("band", [7: [6...9]], ink),
            Part("cups", [6: [5...5, 10...10], 7: [5...5, 10...10]], cyan)
        ]),
        EquipmentItem(id: "pocket-calculator", name: "Pocket Calculator", summary: "Math class's secret weapon.", slot: .offHand, price: 80, parts: [
            Part("body", [10: [1...2], 11: [1...2]], RGB(0.30, 0.32, 0.40)),
            Part("screen", [9: [1...2]], RGB(0.55, 0.95, 0.55))
        ]),
        EquipmentItem(id: "jetpack", name: "Jetpack", summary: "Strapped on, fuelled by coffee.", slot: .back, price: 350, drawsBehindBody: true, parts: [
            Part("tanks", [5: [4...4, 11...11], 6: [4...4, 11...11], 7: [4...5, 10...11], 8: [4...5, 10...11], 9: [4...5, 10...11]], steel),
            Part("flame", [11: [4...4, 11...11], 12: [4...4, 11...11]], flame)
        ])
    ]
}
