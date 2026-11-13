import Foundation

extension EquipmentSlot {
    var displayName: String {
        switch self {
        case .weapon: "Weapons"
        case .head: "Helmets & hats"
        case .feet: "Boots"
        case .gadget: "Gadgets"
        }
    }

    /// Poradi sekci v obchode.
    static let shopOrder: [EquipmentSlot] = [.head, .weapon, .feet, .gadget]
}

/// Vybaveni z obchodu. Kazdy predmet je par pixelovych vrstev na mrizce hrdiny 16x16,
/// takze po koupi a nasazeni je opravdu videt na postavicce.
///
/// Mrizka hrdiny: vlasy radky 0-3, hlava 2-5 (sloupce 5-10), oci radek 4,
/// trup 7-10, ruce radky 9-10 ve sloupcich 3 a 12, opasek 11, nohy 12-13, boty 14.
struct EquipmentItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let summary: String
    let slot: EquipmentSlot
    let price: Int
    /// true = kresli se za telem (napr. raketovy batoh).
    let drawsBehindBody: Bool
    let layers: [AvatarLayer]

    /// Jedna barevna cast predmetu: radky mrizky a v nich sloupce.
    struct Part {
        let name: String
        let spans: [Int: [ClosedRange<Int>]]
        let rgb: RGB
        init(_ name: String, _ spans: [Int: [ClosedRange<Int>]], _ rgb: RGB) { self.name = name; self.spans = spans; self.rgb = rgb }
    }

    init(id: String, name: String, summary: String, slot: EquipmentSlot, price: Int, drawsBehindBody: Bool = false, parts: [Part]) {
        self.id = id
        self.name = name
        self.summary = summary
        self.slot = slot
        self.price = price
        self.drawsBehindBody = drawsBehindBody
        self.layers = parts.map { AvatarLayer(id: "\(id)-\($0.name)", rows: AvatarSprite.grid($0.spans), rgb: $0.rgb) }
    }

    static func item(withID id: String) -> EquipmentItem? { catalog.first { $0.id == id } }

    private static let steel = RGB(0.72, 0.76, 0.84)
    private static let gold = RGB(0.98, 0.78, 0.25)
    private static let ivory = RGB(0.97, 0.93, 0.80)
    private static let wood = RGB(0.58, 0.38, 0.20)
    private static let darkWood = RGB(0.38, 0.24, 0.13)
    private static let blade = RGB(0.88, 0.92, 0.98)
    private static let cyan = RGB(0.40, 0.88, 1.00)
    private static let flame = RGB(1.00, 0.55, 0.16)
    private static let ink = RGB(0.12, 0.12, 0.18)

    static let catalog: [EquipmentItem] = [
        // Hlava
        EquipmentItem(id: "viking-helmet", name: "Viking Helmet", summary: "Steel dome with two proud horns.", slot: .head, price: 150, parts: [
            Part("dome", [0: [6...9], 1: [5...10]], steel),
            Part("rim", [2: [4...11]], gold),
            Part("horns", [0: [3...3, 12...12], 1: [3...4, 11...12]], ivory)
        ]),
        EquipmentItem(id: "wizard-hat", name: "Wizard Hat", summary: "Pointy, starry and full of answers.", slot: .head, price: 220, parts: [
            Part("cone", [0: [7...8], 1: [6...9], 2: [4...11]], RGB(0.45, 0.30, 0.85)),
            Part("star", [1: [7...7]], gold)
        ]),
        EquipmentItem(id: "royal-crown", name: "Royal Crown", summary: "For the ruler of deep focus.", slot: .head, price: 600, parts: [
            Part("gold", [0: [5...5, 7...8, 10...10], 1: [5...10]], gold),
            Part("gems", [1: [6...6, 9...9]], RGB(0.90, 0.22, 0.35))
        ]),
        // Zbrane (v prave ruce)
        EquipmentItem(id: "wooden-sword", name: "Wooden Sword", summary: "Every hero's first blade.", slot: .weapon, price: 60, parts: [
            Part("blade", [3: [13...13], 4: [13...13], 5: [13...13], 6: [13...13], 7: [13...13]], wood),
            Part("guard", [8: [12...14]], darkWood),
            Part("grip", [9: [13...13], 10: [13...13]], darkWood)
        ]),
        EquipmentItem(id: "excalibur", name: "Excalibur", summary: "Pulled from the stone of procrastination.", slot: .weapon, price: 400, parts: [
            Part("blade", [0: [13...13], 1: [13...13], 2: [13...13], 3: [13...13], 4: [13...13], 5: [13...13], 6: [13...13], 7: [13...13]], blade),
            Part("guard", [8: [12...14], 11: [13...13]], gold),
            Part("gem", [8: [13...13]], RGB(0.25, 0.45, 0.95)),
            Part("grip", [9: [13...13], 10: [13...13]], darkWood)
        ]),
        EquipmentItem(id: "magic-staff", name: "Magic Staff", summary: "Glows brighter the longer you focus.", slot: .weapon, price: 300, parts: [
            Part("staff", [3: [13...13], 4: [13...13], 5: [13...13], 6: [13...13], 7: [13...13], 8: [13...13], 9: [13...13], 10: [13...13], 11: [13...13], 12: [13...13], 13: [13...13], 14: [13...13]], wood),
            Part("orb", [0: [13...13], 1: [12...14], 2: [12...14]], cyan)
        ]),
        // Boty
        EquipmentItem(id: "flying-boots", name: "Flying Boots", summary: "Winged boots. Mind the ceiling.", slot: .feet, price: 250, parts: [
            Part("boots", [14: [4...6, 9...11]], gold),
            Part("wings", [12: [2...2, 13...13], 13: [2...3, 12...13]], RGB(0.96, 0.97, 1.00))
        ]),
        EquipmentItem(id: "rocket-boots", name: "Rocket Boots", summary: "Zero to library in three seconds.", slot: .feet, price: 180, parts: [
            Part("boots", [14: [4...6, 9...11]], RGB(0.85, 0.22, 0.28)),
            Part("flame", [15: [4...6, 9...11]], flame)
        ]),
        // Gadgety
        EquipmentItem(id: "focus-headphones", name: "Focus Headphones", summary: "Noise-cancelling, distraction-cancelling.", slot: .gadget, price: 100, parts: [
            Part("band", [0: [5...10], 1: [4...4, 11...11], 2: [4...4, 11...11]], ink),
            Part("cups", [3: [3...4, 11...12], 4: [3...4, 11...12]], cyan)
        ]),
        EquipmentItem(id: "pocket-calculator", name: "Pocket Calculator", summary: "Math class's secret weapon.", slot: .gadget, price: 80, parts: [
            Part("body", [8: [1...2], 9: [1...2], 10: [1...2], 11: [1...2]], RGB(0.30, 0.32, 0.40)),
            Part("screen", [8: [1...2]], RGB(0.55, 0.95, 0.55))
        ]),
        EquipmentItem(id: "jetpack", name: "Jetpack", summary: "Strapped on, fuelled by coffee.", slot: .gadget, price: 350, drawsBehindBody: true, parts: [
            Part("tanks", [6: [2...3, 12...13], 7: [2...3, 12...13], 8: [2...3, 12...13], 9: [2...3, 12...13], 10: [2...3, 12...13]], steel),
            Part("flame", [11: [2...3, 12...13], 12: [2...2, 13...13]], flame)
        ])
    ]
}
