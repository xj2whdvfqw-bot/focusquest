import Foundation

struct UserProfile: Codable, Sendable {
    let userID: String
    var username: String
    var title: String
    var heroClass: HeroClass
    var avatarMatrix: [Int]
    var dailyFocusGoalMinutes: Int
    var avatar = AvatarAppearance()
    /// Herni mena za overene minuty a porazene bosse.
    var coins = 0
    var bossesDefeated = 0
    /// Vybaveni koupene v obchode (ID z EquipmentItem.catalog).
    var ownedEquipmentIDs: [String] = []
    /// false = hrac jeste neprosel uvodni tvorbou hrdiny.
    var hasCreatedHero = false
    /// Co chce hrac s FocusQuestem zmenit; vybira v uvodu.
    var focusGoals: [FocusGoal] = []
    /// Pozadi koupena v obchode (ShopBackground.rawValue); pozadi zdarma se neukladaji.
    var ownedBackgroundIDs: [String] = []
    /// Zvolene pozadi; nil = World scenes (kazdy svet ma svou scenu).
    var backgroundID: String? = nil
    /// Nalezene easter eggy na mape (MapEasterEgg.rawValue); kazdy jde najit jednou za celou hru.
    var foundEasterEggs: [String] = []
    /// B2: extra pauzy koupene v Shopu (nejvys `maxExtraPauses`); v jedne bitve jde pouzit nejvys jedna.
    var extraPauses = 0
    /// C0: prvni den pouzivani appky (sloupec 1 Habits). Nil = jeste nezjisteno (doplni ProfileViewModel).
    var firstUseDate: Date? = nil
    /// C2: Streak freeze v zasobe (nejvys StreakFreeze.maxOwned).
    var streakFreezes = 0
    /// C2: dny zachranene Streak freeze (PlayerStats.dayKey).
    var frozenDays: [String] = []
    /// C5: vyzvednute truhly tydennich ukolu (WeeklyQuest.id, jen nekolik poslednich tydnu).
    var claimedQuests: [String] = []

    /// Kolik extra pauz jde drzet najednou.
    static let maxExtraPauses = 5
    /// Cena jedne extra pauzy v mincich (asi 13 minut soustredeni pri 3 mincich za minutu).
    static let extraPausePrice = 40

    enum CodingKeys: String, CodingKey {
        case userID, username, title, heroClass, avatarMatrix, dailyFocusGoalMinutes
        case avatar, coins, bossesDefeated, hasCreatedHero, ownedEquipmentIDs, focusGoals
        case ownedBackgroundIDs, backgroundID, foundEasterEggs, extraPauses
        case firstUseDate, streakFreezes, frozenDays, claimedQuests
    }

    /// Novy hrac (i po Reset progress) zacina s pozadim Daybreak; World scenes si muze vybrat v Shopu.
    static func fresh(deviceID: String) -> UserProfile {
        var profile = UserProfile(userID: deviceID, username: defaultUsername, title: "Novice Focuser", heroClass: .warrior, avatarMatrix: [], dailyFocusGoalMinutes: 60)
        profile.backgroundID = ShopBackground.dawn.rawValue
        profile.firstUseDate = Date()
        return profile
    }

    /// Jmeno noveho hrace, nez si v onboardingu zada vlastni (pozdrav na Home se pak neukaze).
    static let defaultUsername = "NewFocuser"
    static let nameLimit = 20

    /// Upravene jmeno hrace: 1–20 znaku, pismena (i s diakritikou), cislice, mezery, pomlcka a apostrof;
    /// vice mezer za sebou se slouci. Nil = jmeno nejde pouzit.
    static func cleanName(_ raw: String) -> String? {
        let name = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard (1...nameLimit).contains(name.count) else { return nil }
        let allowed = name.allSatisfy { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" || $0 == "'" || $0 == "’" || $0 == "." }
        guard allowed, name.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }
        return name
    }
}

extension UserProfile {
    // Profil ze serveru nebo ze starsi verze appky nova pole mit nemusi; doplni se vychozimi hodnotami.
    // Starsi verze ukladaly i relikvie (equippedLootIDs, unlockedLootIDs) a vesnici (village);
    // ty uz v appce nejsou a jejich klice se pri cteni ignoruji.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(String.self, forKey: .userID)
        username = try container.decode(String.self, forKey: .username)
        title = try container.decode(String.self, forKey: .title)
        heroClass = try container.decode(HeroClass.self, forKey: .heroClass)
        avatarMatrix = try container.decodeIfPresent([Int].self, forKey: .avatarMatrix) ?? []
        dailyFocusGoalMinutes = try container.decode(Int.self, forKey: .dailyFocusGoalMinutes)
        avatar = (try? container.decodeIfPresent(AvatarAppearance.self, forKey: .avatar)) ?? AvatarAppearance()
        let storedCoins = try container.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        let storedBosses = try container.decodeIfPresent(Int.self, forKey: .bossesDefeated) ?? 0
        coins = max(0, storedCoins)
        bossesDefeated = max(0, storedBosses)
        hasCreatedHero = try container.decodeIfPresent(Bool.self, forKey: .hasCreatedHero) ?? false
        ownedEquipmentIDs = (try? container.decodeIfPresent([String].self, forKey: .ownedEquipmentIDs)) ?? []
        // Neznamy cil z novejsi verze se zahodi, ostatni zustanou.
        let storedGoals = (try? container.decodeIfPresent([String].self, forKey: .focusGoals)) ?? []
        focusGoals = storedGoals.compactMap(FocusGoal.init(rawValue:))
        ownedBackgroundIDs = (try? container.decodeIfPresent([String].self, forKey: .ownedBackgroundIDs)) ?? []
        backgroundID = try? container.decodeIfPresent(String.self, forKey: .backgroundID)
        foundEasterEggs = (try? container.decodeIfPresent([String].self, forKey: .foundEasterEggs)) ?? []
        extraPauses = min(Self.maxExtraPauses, max(0, (try? container.decodeIfPresent(Int.self, forKey: .extraPauses)) ?? 0))
        firstUseDate = (try? container.decodeIfPresent(Date.self, forKey: .firstUseDate)) ?? nil
        streakFreezes = min(StreakFreeze.maxOwned, max(0, (try? container.decodeIfPresent(Int.self, forKey: .streakFreezes)) ?? 0))
        frozenDays = (try? container.decodeIfPresent([String].self, forKey: .frozenDays)) ?? []
        claimedQuests = (try? container.decodeIfPresent([String].self, forKey: .claimedQuests)) ?? []
    }
}

/// Uvodni cil hrace. Urcuje, cim ho appka v Profilu povzbuzuje.
enum FocusGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case removeBrainFog, stopScrolling, studyDaily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .removeBrainFog: "Remove brain fog"
        case .stopScrolling: "Stop scrolling"
        case .studyDaily: "Focus every day"
        }
    }

    var detail: String {
        switch self {
        case .removeBrainFog: "Long, calm focus blocks to clear your head."
        case .stopScrolling: "Win back the hours your feed keeps stealing."
        case .studyDaily: "A small battle every day keeps the streak alive."
        }
    }

    var symbol: String {
        switch self {
        case .removeBrainFog: "cloud.sun.fill"
        case .stopScrolling: "hand.raised.fill"
        case .studyDaily: "calendar.badge.checkmark"
        }
    }
}
