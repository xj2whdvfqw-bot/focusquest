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

    var world: BossWorld { BossWorld.placement[id]?.world ?? .farm }
    /// Pozice na ceste sveta (od nuly).
    var nodeIndex: Int { BossWorld.placement[id]?.index ?? 0 }
    /// Hlaska o prokrastinaci (karta bosse na mape).
    var quip: String { BossWorld.quip(for: id) }

    /// Vsichni bossove vsech svetu v poradi cest.
    static let roster: [Boss] = BossWorld.allCases.flatMap(\.bosses)

    // MARK: - Rozcvicka ("Not feeling it? Just 5 minutes")

    /// Vlastni boss rychle 5minutove bitvy. Nepatri do zadneho sveta: neposouva Path
    /// a jeho vyhry nedavaji odznak "N×" zadnemu bossovi na Path.
    static let warmUpWispID = "warmup-wisp"
    static let warmUpWisp = Boss(id: warmUpWispID, name: "Warm-up Wisp", tier: .novice, maxHP: quickBattleMinutes, currentHP: quickBattleMinutes, pixelSpriteConfig: warmUpWispID)

    var isWarmUp: Bool { id == Self.warmUpWispID }

    /// Bossove cest a rozcvicka: vse, s cim jde bojovat (simulovany server, hledani podle id).
    static let allBosses: [Boss] = roster + [warmUpWisp]

    /// Najde bosse podle id. Boss ze starsi verze, ktery uz v appce neni, vraci nil
    /// (volajici pak pouzije aktualniho bosse mapy; statistiky ho oznaci jako "Retired boss").
    static func find(_ id: String?) -> Boss? {
        guard let id else { return nil }
        return allBosses.first { $0.id == id }
    }
}

/// Tematicke svety v poradi na mape (zdola nahoru). Kazdy ma vlastni cestu bossu; postup pocita
/// souvislou radu porazenych. Dalsi svet se odemkne az po porazce finalniho bosse predchoziho.
enum BossWorld: String, CaseIterable, Identifiable, Sendable {
    case farm, forest, reef, dojo, highSchool, history, planets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .farm: "Farm"
        case .forest: "Whisperwood"
        case .reef: "Coral Deep"
        case .dojo: "Dojo"
        case .highSchool: "Snoozeville High"
        case .history: "History Hall"
        case .planets: "Orbit"
        }
    }

    var tagline: String {
        switch self {
        case .farm: "Nobody on this farm has done a single chore."
        case .forest: "Sprites who'll sprout tomorrow. Probably."
        case .reef: "Where homework sinks without a trace."
        case .dojo: "A whole dojo of fighters who skip every single training."
        case .highSchool: "Everyone's busy. Nobody's studying."
        case .history: "Great minds who'd rather do it tomorrow."
        case .planets: "Eight planets, zero homework done."
        }
    }

    var bosses: [Boss] { Self.builtBosses[self] ?? [] }

    /// Svet pred timto na mape (nil u prvniho).
    var previous: BossWorld? {
        guard let index = Self.allCases.firstIndex(of: self), index > 0 else { return nil }
        return Self.allCases[index - 1]
    }

    /// Uzel, ktery je na rade (prvni neporazeny); nil = cely svet je dobyty.
    func frontierBoss(cleared: Int) -> Boss? {
        let list = bosses
        return cleared < list.count ? list[max(0, cleared)] : nil
    }

    static func quip(for id: String) -> String { quips[id] ?? "" }

    // MARK: - Soupiska

    /// (id, jmeno, hlaska) v poradi uzlu na ceste. Vsechny postavy jsou vlastni, nejsou to zname postavy.
    private static let lineup: [BossWorld: [(String, String, String)]] = [
        .farm: [
            ("farm-bunny", "Snooze Bunny", "Hop to it? I'll hop to bed first."),
            ("farm-hen", "Procrasti-Hen", "I'll lay that essay tomorrow. Maybe."),
            ("farm-sheep", "Baa-ck in Five", "Counting sheep is a study method, right?"),
            ("farm-cow", "Moo-ve It Later", "I'm still chewing on the first page."),
            ("farm-pig", "Couch Hog", "The couch is warm. The homework is not."),
            ("farm-donkey", "Hee-Haw Hold-On", "Hold on, I'm busy being stubborn."),
            ("farm-horse", "Neigh-ver Mind", "Neigh. Not today. Ask me tomorrow.")
        ],
        .forest: [
            ("forest-mushroom", "Puffcap", "I'll grow on it after a nap in the shade."),
            ("forest-grass", "Lazy Sprig", "Just five more minutes of photosynthesis."),
            ("forest-flower", "Petal Pause", "I only bloom after the deadline."),
            ("forest-moss", "Mossy Snoozer", "A rolling stone gathers homework. I don't roll."),
            ("forest-acorn", "Acorn Afterwhile", "Someday I'll be an oak. Someday."),
            ("forest-tree", "Twiggy Tomorrow", "Leaf it for later."),
            ("forest-elder", "Old Oakdrowse", "I've been postponing things for three hundred years.")
        ],
        .reef: [
            ("reef-seahorse", "Driftwell the Seahorse", "I'll start when the current turns. Any decade now."),
            ("reef-clownfish", "Clownin' Around", "Homework? I'm still hiding in my anemone."),
            ("reef-jelly", "Jelly Later", "No brain, no deadlines. Living the dream."),
            ("reef-urchin", "Spiky Maybe", "Touch your notes? Ouch. Maybe tomorrow."),
            ("reef-octopus", "Octo-Tasker", "Eight arms, eight tabs, zero progress."),
            ("reef-shark", "Snack-Break Shark", "I smell a snack break. Every five minutes."),
            ("reef-kraken", "The Kraken of Later", "I drag every deadline down to the deep.")
        ],
        .dojo: [
            ("dojo-karate", "Kara-Tea Break", "First a tea. Then another tea."),
            ("dojo-master", "Master Someday", "The way of the master: someday."),
            ("dojo-monk", "Monk Mañana", "Inner peace means outer deadlines don't exist."),
            ("dojo-boxer", "Rope-a-Dope Ray", "I dodge homework like a champ."),
            ("dojo-mma", "Tap-Out Tyler", "One page in and I'm tapping out."),
            ("dojo-judo", "Ju-Don't", "My best throw? Your study plan, out the window."),
            ("dojo-kendo", "Ken-Doze", "My sword is sharp. My focus is asleep."),
            ("dojo-muaythai", "Muay Thai-red", "Too tired. Trained my thumbs all night."),
            ("dojo-sumo", "Sumo More Snacks", "Snack first. Snack second. Study… snack.")
        ],
        .highSchool: [
            ("hs-nerd", "Theo Theorem", "I'll study right after I color-code my study plan."),
            ("hs-emo", "Raven Rainclouds", "Homework is just… not my aesthetic right now."),
            ("hs-cheer", "Pep Rally Penny", "Gimme an S! Gimme a… snack break!"),
            ("hs-gymbro", "Brody Bulk", "Skipping study day. Never skipping snack day."),
            ("hs-hoops", "Dribble Dex", "One more free throw. Or fifty."),
            ("hs-quarterback", "Hail Mary Max", "I'll throw a hail mary the night before the test."),
            ("hs-principal", "Principal Postpone", "Today's meeting about procrastination is postponed.")
        ],
        .history: [
            ("hist-napoleon", "Nap-oleon", "I conquered half the map. Not my homework."),
            ("hist-cleo", "Cleo, Queen of De-Nile", "Deadline? Never heard of her."),
            ("hist-caesar", "Veni, Vidi, Scrolli", "I came, I saw, I kept scrolling."),
            ("hist-bard", "Will Do It Tomorrow", "To study or not to study? Tomorrow."),
            ("hist-leonardo", "Leonardo da Wi-Fi", "My masterpiece is a 300-tab browser."),
            ("hist-mozart", "Amadeus Pause", "Every symphony needs a long, long rest."),
            ("hist-newton", "Isaac Inertia", "A student at rest stays at rest."),
            ("hist-karel", "Karel IV-get It", "I built a bridge. Over my to-do list."),
            ("hist-komensky", "Komenský's Homework", "Teacher of nations, master of later.")
        ],
        .planets: [
            ("planet-mercury", "Retro Mercury", "I'm in retrograde. Can't study now."),
            ("planet-venus", "Meme Venus", "Hot take: memes count as research."),
            ("planet-earth", "Day-Off Earth", "Even I take a day off. Every day."),
            ("planet-mars", "Binge Mars", "Just one more episode. Per sol."),
            ("planet-jupiter", "Jupi-Later", "I've got 95 moons of excuses."),
            ("planet-saturn", "Ring-Ring Saturn", "Sorry, my rings are ringing. Notifications."),
            ("planet-uranus", "Tilted Uranus", "I'm tilted 98 degrees away from work."),
            ("planet-neptune", "Sea-Ya Neptune", "So far out, the deadline can't reach me.")
        ]
    ]

    /// Klice svetu ulozene starsimi verzemi -> dnesni svet. Postup ve trech odstranenych svetech
    /// (prvni tri na starsi ceste) prevezmou Coral Deep, Whisperwood a Snoozeville High;
    /// Dojo a Farm mely drive jine klice.
    static let legacyWorldKeys: [String: BossWorld] = [
        "heroes": .reef,
        "villains": .forest,
        "fairyTale": .highSchool,
        "sewerDojo": .dojo,
        "brainrot": .farm
    ]

    private static let quips: [String: String] = Dictionary(uniqueKeysWithValues: lineup.values.flatMap { $0 }.map { ($0.0, $0.2) })

    private static let builtBosses: [BossWorld: [Boss]] = Dictionary(uniqueKeysWithValues: allCases.map { world in
        let bosses = (lineup[world] ?? []).enumerated().map { index, entry in
            let minutes = Boss.fixedMinutes(forNode: index)
            return Boss(id: entry.0, name: entry.1, tier: .forNode(index), maxHP: minutes, currentHP: minutes, pixelSpriteConfig: entry.0)
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
