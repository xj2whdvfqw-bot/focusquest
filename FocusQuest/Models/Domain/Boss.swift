import Foundation

enum BossTier: String, Codable, CaseIterable, Sendable {
    case novice, adept, elite, mythic

    /// Obtiznost podle pozice na ceste: kazde dva uzly o stupen tezsi.
    static func forNode(_ index: Int) -> BossTier {
        switch index {
        case ..<2: .novice
        case 2..<4: .adept
        case 4..<6: .elite
        default: .mythic
        }
    }
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

    // 1 HP = 1 minuta overeneho soustredeni. Delku bitvy hrac nevoli:
    // uzel N na ceste trva 10 + 5*(N-1) minut. Rozsah nize hlida jen server;
    // spodnich 5 minut je rychla bitva "Not feeling it? Just 5 minutes".
    static let minutesRange = 5...240
    static let minutesStep = 5
    static let firstNodeMinutes = 10
    /// Rychla bitva z Areny ("Not feeling it? Just 5 minutes").
    static let quickBattleMinutes = 5

    /// Pevna delka uzlu na ceste (index od nuly): 10, 15, 20, 25 ... minut.
    static func fixedMinutes(forNode index: Int) -> Int {
        clampedMinutes(firstNodeMinutes + minutesStep * max(0, index))
    }

    /// Zaokrouhli na nejblizsich 5 minut a drzi hodnotu v rozsahu 5-240.
    static func clampedMinutes(_ value: Int) -> Int {
        let snapped = Int((Double(value) / Double(minutesStep)).rounded()) * minutesStep
        return min(minutesRange.upperBound, max(minutesRange.lowerBound, snapped))
    }

    /// Stejny boss s plnym zdravim na zvoleny pocet minut.
    func withHP(minutes: Int) -> Boss {
        var copy = self
        copy.maxHP = Boss.clampedMinutes(minutes)
        copy.currentHP = copy.maxHP
        return copy
    }

    var world: BossWorld { BossWorld.placement[id]?.world ?? .heroes }
    /// Pozice na ceste sveta (od nuly).
    var nodeIndex: Int { BossWorld.placement[id]?.index ?? 0 }

    /// Vsichni bossove vsech svetu v poradi cest.
    static let roster: [Boss] = BossWorld.allCases.flatMap(\.bosses)

    /// Najde bosse podle id; id ze starsich verzi Dojo a Farm prevede na nove bosse.
    static func find(_ id: String?) -> Boss? {
        guard let id else { return nil }
        let current = currentID(id)
        return roster.first { $0.id == current }
    }

    /// Aktualni id bosse (stare id z Dojo a Farm se prevede, ostatni zustanou).
    static func currentID(_ id: String) -> String { BossWorld.legacyBossIDs[id] ?? id }
}

/// Tematicke svety. Kazdy ma vlastni cestu bossu; hrac si muze vybrat kohokoli, postup pocita souvislou radu porazenych.
/// rawValue Dojo a Farm zustava ze starsich verzi ("sewerDojo", "brainrot"), aby ulozeny postup platil dal.
enum BossWorld: String, CaseIterable, Identifiable, Sendable {
    case heroes, villains
    case dojo = "sewerDojo"
    case fairyTale
    case farm = "brainrot"
    case history, planets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heroes: "Hero Heights"
        case .villains: "Villain Vault"
        case .dojo: "Dojo"
        case .fairyTale: "Swamp Kingdom"
        case .farm: "Farm"
        case .history: "History Hall"
        case .planets: "Orbit"
        }
    }

    var tagline: String {
        switch self {
        case .heroes: "Caped slackers who'd rather nap than save the day."
        case .villains: "Masterminds of the endless scroll."
        case .dojo: "A whole dojo of fighters who skip every single training."
        case .fairyTale: "Once upon a time, someone stopped studying."
        case .farm: "Nobody on this farm has done a single chore."
        case .history: "Great minds who'd rather do it tomorrow."
        case .planets: "Eight planets, zero homework done."
        }
    }

    var bosses: [Boss] { Self.builtBosses[self] ?? [] }

    /// Uzel, ktery je na rade (prvni neporazeny); nil = cely svet je dobyty.
    func frontierBoss(cleared: Int) -> Boss? {
        let list = bosses
        return cleared < list.count ? list[max(0, cleared)] : nil
    }

    // MARK: - Soupiska

    private static let loot = ["chronos-shield", "scholars-tome", "ember-charm"]

    /// (id, jmeno) v poradi uzlu na ceste.
    private static let lineup: [BossWorld: [(String, String)]] = [
        .heroes: [
            ("web-slacker", "Web-Slacker"),
            ("thunder-snooze", "Thunder Snooze"),
            ("mr-incredulous", "Mr. Incredulous"),
            ("elasti-snooze", "Elasti-Snooze"),
            ("dash-distracted", "Dash Distracted"),
            ("vanishing-violet", "Vanishing Violet"),
            ("jack-jack-attack", "Jack-Jack Attack")
        ],
        .villains: [
            ("the-jokester", "The Jokester"),
            ("venomeme", "Venomeme"),
            ("green-gobbler", "The Green Gobbler"),
            ("sandbagman", "Sandbagman")
        ],
        .dojo: [
            ("dojo-karate", "Kara-Tea Break"),
            ("dojo-master", "Master Someday"),
            ("dojo-monk", "Monk Mañana"),
            ("dojo-boxer", "Rope-a-Dope Ray"),
            ("dojo-mma", "Tap-Out Tyler"),
            ("dojo-judo", "Ju-Don't"),
            ("dojo-kendo", "Ken-Doze"),
            ("dojo-muaythai", "Muay Thai-red"),
            ("dojo-sumo", "Sumo More Snacks")
        ],
        .fairyTale: [
            ("swamp-ogre", "Grumbrek the Swamp Ogre"),
            ("don-keyboard", "Don Keyboard"),
            ("rapunzzzel", "Rapunzzzel"),
            ("puss-in-popups", "Puss in Pop-ups")
        ],
        .farm: [
            ("farm-bunny", "Snooze Bunny"),
            ("farm-hen", "Procrasti-Hen"),
            ("farm-sheep", "Baa-ck in Five"),
            ("farm-cow", "Moo-ve It Later"),
            ("farm-pig", "Couch Hog"),
            ("farm-donkey", "Hee-Haw Hold-On"),
            ("farm-horse", "Neigh-ver Mind")
        ],
        .history: [
            ("hist-napoleon", "Nap-oleon"),
            ("hist-cleo", "Cleo, Queen of De-Nile"),
            ("hist-caesar", "Veni, Vidi, Scrolli"),
            ("hist-bard", "Will Do It Tomorrow"),
            ("hist-leonardo", "Leonardo da Wi-Fi"),
            ("hist-mozart", "Amadeus Pause"),
            ("hist-newton", "Isaac Inertia"),
            ("hist-karel", "Karel IV-get It"),
            ("hist-komensky", "Komenský's Homework")
        ],
        .planets: [
            ("planet-mercury", "Retro Mercury"),
            ("planet-venus", "Meme Venus"),
            ("planet-earth", "Day-Off Earth"),
            ("planet-mars", "Binge Mars"),
            ("planet-jupiter", "Jupi-Later"),
            ("planet-saturn", "Ring-Ring Saturn"),
            ("planet-uranus", "Tilted Uranus"),
            ("planet-neptune", "Sea-Ya Neptune")
        ]
    ]

    /// Bossove starsich verzi Dojo a Farm (stare id -> nove id na stejne pozici cesty).
    /// Farm ma jen 7 bossu, takze stare uzly 8 a 9 pripadnou poslednimu.
    static let legacyBossIDs: [String: String] = {
        let oldDojo = ["leo-napardo", "raph-scroll", "do-not-tello", "mikey-snackelangelo"]
        let oldFarm = ["banana-bandit", "tung-tung-sahur", "goggle-grunt", "ballerina-cappuccina", "captain-procrastination", "purple-chomper", "tralalero-tralala", "dark-doomscroller", "iron-distraction"]
        var result: [String: String] = [:]
        for (world, old) in [(BossWorld.dojo, oldDojo), (.farm, oldFarm)] {
            let ids = (lineup[world] ?? []).map(\.0)
            for (index, id) in old.enumerated() where !ids.isEmpty { result[id] = ids[min(index, ids.count - 1)] }
        }
        return result
    }()

    private static let builtBosses: [BossWorld: [Boss]] = Dictionary(uniqueKeysWithValues: allCases.map { world in
        let bosses = (lineup[world] ?? []).enumerated().map { index, entry in
            let minutes = Boss.fixedMinutes(forNode: index)
            return Boss(id: entry.0, name: entry.1, tier: .forNode(index), maxHP: minutes, currentHP: minutes, pixelSpriteConfig: entry.0, lootTable: [loot[index % loot.count]])
        }
        return (world, bosses)
    })

    fileprivate static let placement: [String: (world: BossWorld, index: Int)] = {
        var result: [String: (world: BossWorld, index: Int)] = [:]
        for world in allCases {
            for (index, entry) in (lineup[world] ?? []).enumerated() { result[entry.0] = (world, index) }
        }
        return result
    }()
}
