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
    // uzel N na ceste trva 10 + 5*(N-1) minut. Rozsah nize hlida jen server.
    static let minutesRange = 10...240
    static let minutesStep = 5
    static let firstNodeMinutes = 10

    /// Pevna delka uzlu na ceste (index od nuly): 10, 15, 20, 25 ... minut.
    static func fixedMinutes(forNode index: Int) -> Int {
        clampedMinutes(firstNodeMinutes + minutesStep * max(0, index))
    }

    /// Zaokrouhli na nejblizsich 5 minut a drzi hodnotu v rozsahu 10-240.
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

    var world: BossWorld { BossWorld.placement[id]?.world ?? .brainrot }
    /// Pozice na ceste sveta (od nuly).
    var nodeIndex: Int { BossWorld.placement[id]?.index ?? 0 }

    /// Vsichni bossove vsech svetu v poradi cest.
    static let roster: [Boss] = BossWorld.allCases.flatMap(\.bosses)

    static func find(_ id: String?) -> Boss? {
        guard let id else { return nil }
        return roster.first { $0.id == id }
    }
}

/// Tematicke svety. Kazdy ma vlastni cestu bossu; dalsi uzel se odemkne porazenim predchoziho.
enum BossWorld: String, CaseIterable, Identifiable, Sendable {
    case heroes, villains, sewerDojo, fairyTale, brainrot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heroes: "Hero Heights"
        case .villains: "Villain Vault"
        case .sewerDojo: "Sewer Dojo"
        case .fairyTale: "Swamp Kingdom"
        case .brainrot: "Brainrot Badlands"
        }
    }

    var tagline: String {
        switch self {
        case .heroes: "Caped slackers who'd rather nap than save the day."
        case .villains: "Masterminds of the endless scroll."
        case .sewerDojo: "Four shell-shocked ninjas who skipped training."
        case .fairyTale: "Once upon a time, someone stopped studying."
        case .brainrot: "Where focus goes to melt."
        }
    }

    var symbol: String {
        switch self {
        case .heroes: "bolt.shield.fill"
        case .villains: "theatermasks.fill"
        case .sewerDojo: "figure.martial.arts"
        case .fairyTale: "crown.fill"
        case .brainrot: "tornado"
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
        .sewerDojo: [
            ("leo-napardo", "Leo-Nap-ardo"),
            ("raph-scroll", "Raph-Scroll"),
            ("do-not-tello", "Do-Not-Tello"),
            ("mikey-snackelangelo", "Mikey Snackelangelo")
        ],
        .fairyTale: [
            ("swamp-ogre", "Grumbrek the Swamp Ogre"),
            ("don-keyboard", "Don Keyboard"),
            ("rapunzzzel", "Rapunzzzel"),
            ("puss-in-popups", "Puss in Pop-ups")
        ],
        .brainrot: [
            ("banana-bandit", "Banana Bandit"),
            ("tung-tung-sahur", "Tung Tung Tung Sahur"),
            ("goggle-grunt", "Goggle Grunt"),
            ("ballerina-cappuccina", "Ballerina Cappuccina"),
            ("captain-procrastination", "Captain Procrastination"),
            ("purple-chomper", "Purple Chomper"),
            ("tralalero-tralala", "Tralalero Tralala"),
            ("dark-doomscroller", "The Dark Doomscroller"),
            ("iron-distraction", "Iron Distraction")
        ]
    ]

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
