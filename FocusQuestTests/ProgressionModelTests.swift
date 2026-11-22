import XCTest
@testable import FocusQuest

final class ProgressionModelTests: XCTestCase {
    // MARK: - HP bosse

    func testBossHPStartsAtTenMinutesAndMovesInFiveMinuteSteps() {
        let boss = Boss.roster[0].withHP(minutes: 35)
        XCTAssertEqual(boss.maxHP, 35)
        XCTAssertEqual(boss.currentHP, 35)
        XCTAssertEqual(Boss.clampedMinutes(37), 35)
        XCTAssertEqual(Boss.clampedMinutes(38), 40)
        XCTAssertEqual(Boss.clampedMinutes(1), 5)
        XCTAssertEqual(Boss.roster[0].withHP(minutes: 0).maxHP, 5)
        XCTAssertEqual(Boss.roster[0].withHP(minutes: Boss.quickBattleMinutes).maxHP, 5)
        XCTAssertEqual(Boss.roster[0].withHP(minutes: 9_999).maxHP, Boss.minutesRange.upperBound)
    }

    func testPathNodesHaveFixedDurationsTenFifteenTwenty() {
        XCTAssertEqual(Boss.fixedMinutes(forNode: 0), 10)
        XCTAssertEqual(Boss.fixedMinutes(forNode: 1), 15)
        XCTAssertEqual(Boss.fixedMinutes(forNode: 2), 20)
        for world in BossWorld.allCases {
            for (index, boss) in world.bosses.enumerated() {
                XCTAssertEqual(boss.maxHP, 10 + 5 * index, boss.name)
                XCTAssertEqual(boss.currentHP, boss.maxHP, boss.name)
            }
        }
    }

    func testSimulatedBackendUsesCustomHPForEachBattle() async throws {
        let backend = SimulatedSecureBackendService()
        let session = try await backend.startSession(bossID: Boss.roster[0].id, mode: .solo, targetMinutes: 15)
        let result = try await backend.completeSession(sessionID: session.sessionID)
        XCTAssertEqual(result.boss.maxHP, 15)
        XCTAssertEqual(result.boss.currentHP, 15)
    }

    // MARK: - Predvolby

    func testPreferencesSavedByOlderVersionKeepTheirValues() throws {
        let legacy = Data(#"{"isHapticsEnabled":false,"isMusicEnabled":true,"isSFXEnabled":true,"ambientVolume":0.3,"selectedTrack":"tokyoSunset","bossMinutes":1,"bossMinutesByID":{"web-slacker":60}}"#.utf8)
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: legacy)
        XCTAssertFalse(preferences.isHapticsEnabled)
        XCTAssertEqual(preferences.ambientVolume, 0.3, accuracy: 0.0001)
        XCTAssertEqual(preferences.selectedTrack, .tokyoSunset)
        XCTAssertEqual(preferences.soundscape, .lofi)
        XCTAssertNil(preferences.lastSubject)
        // Stare vlastni delky bitev se zahodi; cesta zacina od prvniho uzlu.
        XCTAssertTrue(preferences.clearedNodesByWorld.isEmpty)
        XCTAssertEqual(preferences.clearedNodes(in: .heroes), 0)
    }

    func testPathProgressCountsClearedNodesInOrderInEachWorld() {
        var preferences = AppPreferences()
        let heroes = BossWorld.heroes.bosses
        let villains = BossWorld.villains.bosses
        // Vyhra nad uzlem mimo poradi cestu neposune.
        preferences.markCleared(heroes[2])
        XCTAssertEqual(preferences.clearedNodes(in: .heroes), 0)

        preferences.markCleared(heroes[0])
        XCTAssertEqual(preferences.clearedNodes(in: .heroes), 1)
        XCTAssertEqual(BossWorld.heroes.frontierBoss(cleared: 1)?.id, heroes[1].id)

        // Opakovana vyhra nad starsim uzlem nic nemeni.
        preferences.markCleared(heroes[0])
        XCTAssertEqual(preferences.clearedNodes(in: .heroes), 1)

        // Kazdy svet ma vlastni cestu.
        XCTAssertEqual(preferences.clearedNodes(in: .villains), 0)

        // Dobyty svet uz nema dalsi uzel.
        for boss in villains { preferences.markCleared(boss) }
        XCTAssertEqual(preferences.clearedNodes(in: .villains), villains.count)
        XCTAssertNil(BossWorld.villains.frontierBoss(cleared: villains.count))
    }

    func testPreferencesRoundTripKeepsSoundscapePathProgressAndSubject() throws {
        var preferences = AppPreferences()
        preferences.soundscape = .brownNoise
        preferences.clearedNodesByWorld = [BossWorld.heroes.rawValue: 3, BossWorld.farm.rawValue: 1]
        preferences.lastSubject = .german
        preferences.lastBossID = Boss.roster[1].id
        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        XCTAssertEqual(decoded, preferences)
    }

    func testSubjectProgressSumsMinutesPerSubject() {
        let now = Date()
        let history = [
            SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: 25, xpEarned: 250, completedAt: now, flawless: true, subject: .math),
            SessionSummary(id: UUID(), bossName: "B", verifiedMinutes: 40, xpEarned: 400, completedAt: now, flawless: true, subject: .german),
            SessionSummary(id: UUID(), bossName: "C", verifiedMinutes: 20, xpEarned: 200, completedAt: now, flawless: true, subject: .math),
            SessionSummary(id: UUID(), bossName: "D", verifiedMinutes: 30, xpEarned: 300, completedAt: now, flawless: true)
        ]
        let progress = SubjectProgress.summarize(history)
        // Bitva bez predmetu se pocita do "General".
        XCTAssertEqual(progress.map(\.subject), [.math, .german, .general])
        XCTAssertEqual(progress.first?.minutes, 45)
        XCTAssertEqual(progress.first?.battles, 2)
        XCTAssertEqual(progress.last?.subject.title, "General")
        XCTAssertEqual(progress.last?.minutes, 30)
    }

    // MARK: - Hrdina a profil

    func testProfileFromOlderVersionGetsDefaultHero() throws {
        let legacy = Data(#"{"userID":"u1","username":"Adam","title":"Novice Focuser","heroClass":"cyberRonin","avatarMatrix":[],"dailyFocusGoalMinutes":60}"#.utf8)
        let profile = try JSONDecoder().decode(UserProfile.self, from: legacy)
        XCTAssertEqual(profile.username, "Adam")
        XCTAssertEqual(profile.avatar, AvatarAppearance())
        XCTAssertEqual(profile.coins, 0)
        XCTAssertFalse(profile.hasCreatedHero)
    }

    func testProfileWithRemovedRelicsAndVillageStillLoads() throws {
        // Starsi verze ukladaly relikvie a vesnici; profil se musi nacist a mince zustat.
        let legacy = Data(#"{"userID":"u1","username":"Adam","title":"Novice Focuser","heroClass":"cyberRonin","avatarMatrix":[],"dailyFocusGoalMinutes":60,"equippedLootIDs":["chronos-shield"],"unlockedLootIDs":["scholars-tome","chronos-shield"],"village":{"stage":"castle","builtAt":{}},"coins":420,"bossesDefeated":7,"hasCreatedHero":true,"heroHP":12,"potions":{"health":2,"timeFreeze":1}}"#.utf8)
        let profile = try JSONDecoder().decode(UserProfile.self, from: legacy)
        XCTAssertEqual(profile.username, "Adam")
        XCTAssertEqual(profile.coins, 420)
        XCTAssertEqual(profile.bossesDefeated, 7)
        XCTAssertTrue(profile.hasCreatedHero)
        // Po ulozeni uz stare klice nezustanou.
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
        for key in ["equippedLootIDs", "unlockedLootIDs", "village", "heroHP", "potions"] { XCTAssertNil(saved[key], key) }
    }

    func testProfileRoundTripKeepsHeroLook() throws {
        var profile = UserProfile.fresh(deviceID: "test")
        profile.avatar.skin = .umber
        profile.avatar.hairStyle = .mohawk
        profile.avatar.equip("excalibur", in: .weapon)
        profile.coins = 321
        profile.hasCreatedHero = true
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(decoded.avatar, profile.avatar)
        XCTAssertEqual(decoded.avatar.equippedItemID(in: .weapon), "excalibur")
        XCTAssertEqual(decoded.coins, 321)
        XCTAssertTrue(decoded.hasCreatedHero)
    }

    func testUnknownHeroLookValueFallsBackInsteadOfLosingProfile() throws {
        let data = Data(#"{"skin":"neon","hairStyle":"long","hairColor":"violet","outfitColor":"gold","bootsColor":"snow"}"#.utf8)
        let avatar = try JSONDecoder().decode(AvatarAppearance.self, from: data)
        XCTAssertEqual(avatar.skin, AvatarAppearance().skin)
        XCTAssertEqual(avatar.hairStyle, .long)
        XCTAssertEqual(avatar.outfitColor, .gold)
    }

    func testEveryHeroLayerIsAFullGrid() {
        for style in HairStyle.allCases {
            var appearance = AvatarAppearance()
            appearance.hairStyle = style
            let layers = AvatarSprite.layers(for: appearance, heroClass: .warrior)
            let hasHair = layers.contains(where: { $0.id == "hair" })
            XCTAssertEqual(hasHair, style != .bald)
            for layer in layers {
                XCTAssertEqual(layer.rows.count, AvatarSprite.gridSize)
                XCTAssertTrue(layer.rows.allSatisfy({ $0.count == AvatarSprite.gridSize }))
                XCTAssertTrue(layer.rows.contains(where: { $0.contains("#") }), "Layer \(layer.id) is empty")
            }
        }
    }

    // MARK: - Obchod a bossove

    func testEquippedGearIsDrawnOnTheHero() {
        XCTAssertEqual(Set(EquipmentItem.catalog.map(\.id)).count, EquipmentItem.catalog.count, "Duplicate item IDs")
        for item in EquipmentItem.catalog {
            var appearance = AvatarAppearance()
            appearance.equip(item.id, in: item.slot)
            let layers = AvatarSprite.layers(for: appearance, heroClass: .mage)
            let itemLayers = layers.filter { $0.id.hasPrefix("\(item.id)-") }
            XCTAssertFalse(itemLayers.isEmpty, "\(item.name) is not drawn")
            XCTAssertEqual(Set(layers.map(\.id)).count, layers.count, "Layer IDs must be unique for \(item.name)")
            for layer in itemLayers {
                XCTAssertEqual(layer.rows.count, AvatarSprite.gridSize)
                XCTAssertTrue(layer.rows.contains(where: { $0.contains("#") }), "Layer \(layer.id) is empty")
            }
            // Za telem se kresli jen batoh; ostatni vybaveni je navrchu.
            let index = layers.firstIndex { $0.id.hasPrefix("\(item.id)-") }!
            let skinIndex = layers.firstIndex { $0.id == "skin" }!
            XCTAssertEqual(index < skinIndex, item.drawsBehindBody)
        }
    }

    func testEachClassLooksDifferent() {
        let looks: [String] = HeroClass.allCases.map { heroClass in
            let marks = AvatarSprite.layers(for: AvatarAppearance(), heroClass: heroClass).filter { $0.id.hasPrefix("class-") }
            return marks.map { $0.rows.joined(separator: "|") }.joined(separator: "/")
        }
        XCTAssertEqual(Set(looks).count, HeroClass.allCases.count)
        for heroClass in HeroClass.allCases {
            for mark in AvatarSprite.classMarks(heroClass) {
                XCTAssertTrue(mark.layer.rows.contains(where: { $0.contains("#") }), "Layer \(mark.layer.id) is empty")
            }
        }
    }

    func testShopGearReplacesTheClassMarkInItsSlot() {
        var appearance = AvatarAppearance()
        appearance.equip("viking-helmet", in: .head)
        let ids = AvatarSprite.layers(for: appearance, heroClass: .warrior).map(\.id)
        XCTAssertFalse(ids.contains("class-helmet"))
        XCTAssertTrue(ids.contains("class-shield"))
        XCTAssertTrue(ids.contains("viking-helmet-dome"))
    }

    func testUnknownEquipmentIsIgnored() {
        var appearance = AvatarAppearance()
        appearance.equip("item-from-the-future", in: .head)
        XCTAssertEqual(AvatarSprite.layers(for: appearance, heroClass: .archer).count, AvatarSprite.layers(for: AvatarAppearance(), heroClass: .archer).count)
    }

    func testProfileKeepsOwnedEquipment() throws {
        var profile = UserProfile.fresh(deviceID: "test")
        profile.ownedEquipmentIDs = ["excalibur"]
        profile.avatar.equip("excalibur", in: .weapon)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(decoded.ownedEquipmentIDs, ["excalibur"])
        XCTAssertEqual(decoded.avatar.equippedItemID(in: .weapon), "excalibur")
    }

    func testEveryBossHasAFullSpriteAndAPlaceOnAPath() {
        XCTAssertEqual(Set(Boss.roster.map(\.id)).count, Boss.roster.count, "boss IDs must be unique")
        for world in BossWorld.allCases {
            XCTAssertFalse(world.bosses.isEmpty, world.rawValue)
            for (index, boss) in world.bosses.enumerated() {
                XCTAssertEqual(boss.world, world, boss.name)
                XCTAssertEqual(boss.nodeIndex, index, boss.name)
            }
        }
        for boss in Boss.roster {
            let rows = SpritePalette.bossRows[boss.pixelSpriteConfig] ?? SpritePalette.worldBossRows[boss.pixelSpriteConfig]
            XCTAssertNotNil(rows, "\(boss.name) has no sprite")
            XCTAssertEqual(rows?.count, 16, boss.name)
            XCTAssertTrue(rows?.allSatisfy { $0.count == 16 } ?? false, boss.name)
        }
    }

    func testLegacyDojoAndFarmBossIDsMapToNewBosses() {
        XCTAssertEqual(BossWorld(rawValue: "sewerDojo"), .dojo)
        XCTAssertEqual(BossWorld(rawValue: "brainrot"), .farm)
        XCTAssertEqual(Boss.find("leo-napardo")?.id, "dojo-karate")
        XCTAssertEqual(Boss.find("banana-bandit")?.id, "farm-bunny")
        XCTAssertEqual(Boss.find("iron-distraction")?.id, "farm-horse")
        XCTAssertEqual(Boss.find("web-slacker")?.id, "web-slacker")
        XCTAssertNil(Boss.find("no-such-boss"))
    }

    // MARK: - Odmeny

    func testCoinRewardCountsMinutesAndBossBonus() {
        XCTAssertEqual(RewardRules.coins(verifiedMinutes: 25), 75)
        XCTAssertEqual(RewardRules.xp(verifiedMinutes: 25), 300)
        XCTAssertEqual(RewardRules.coins(verifiedMinutes: -5), 0)
        XCTAssertEqual(RewardRules.xp(verifiedMinutes: -5), 0)
    }

    func testRecordedBattleUpdatesLevelHistoryAndStreak() {
        let calendar = Calendar(identifier: .gregorian)
        let dayOne = Date(timeIntervalSince1970: 1_700_000_000)
        let dayTwo = dayOne.addingTimeInterval(86_400)
        let dayFive = dayOne.addingTimeInterval(86_400 * 4)
        var stats = PlayerStats.initial

        stats.record(SessionSummary(id: UUID(), bossName: "Slime", verifiedMinutes: 60, xpEarned: 600, completedAt: dayOne, flawless: true), bossDefeated: true, calendar: calendar)
        XCTAssertEqual(stats.level, 1)
        XCTAssertEqual(stats.streakDays, 1)

        stats.record(SessionSummary(id: UUID(), bossName: "Golem", verifiedMinutes: 50, xpEarned: 500, completedAt: dayTwo, flawless: true), bossDefeated: true, calendar: calendar)
        XCTAssertEqual(stats.level, 2)
        XCTAssertEqual(stats.streakDays, 2)
        XCTAssertEqual(stats.wins, 2)
        XCTAssertEqual(stats.totalHPDealt, 110)
        XCTAssertEqual(stats.sessionHistory.first?.bossName, "Golem")

        stats.record(SessionSummary(id: UUID(), bossName: "Dragon", verifiedMinutes: 10, xpEarned: 100, completedAt: dayFive, flawless: true), bossDefeated: false, calendar: calendar)
        XCTAssertEqual(stats.streakDays, 1)
        XCTAssertEqual(stats.wins, 2)
        XCTAssertEqual(stats.battles, 3)
    }

    // MARK: - Serie

    func testStreakExpiresAfterAMissedDay() {
        let calendar = Calendar(identifier: .gregorian)
        let dayOne = Date(timeIntervalSince1970: 1_700_000_000)
        let dayTwo = dayOne.addingTimeInterval(86_400)
        var stats = PlayerStats.initial
        XCTAssertEqual(stats.currentStreak(now: dayOne, calendar: calendar), 0)

        stats.record(SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: 10, xpEarned: 100, completedAt: dayOne, flawless: true), bossDefeated: true, calendar: calendar)
        stats.record(SessionSummary(id: UUID(), bossName: "B", verifiedMinutes: 10, xpEarned: 100, completedAt: dayTwo, flawless: true), bossDefeated: true, calendar: calendar)
        XCTAssertEqual(stats.currentStreak(now: dayTwo, calendar: calendar), 2)
        // Den bez bitvy serii jeste drzi, dva dny uz ne.
        XCTAssertEqual(stats.currentStreak(now: dayTwo.addingTimeInterval(86_400), calendar: calendar), 2)
        XCTAssertEqual(stats.currentStreak(now: dayTwo.addingTimeInterval(86_400 * 2), calendar: calendar), 0)
    }

    func testStatsFromOlderVersionWithHPComboAndFailureStillLoad() throws {
        let calendar = Calendar(identifier: .gregorian)
        let dayOne = Date(timeIntervalSince1970: 1_700_000_000)
        var stats = PlayerStats.initial
        stats.record(SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: 10, xpEarned: 100, completedAt: dayOne, flawless: true), bossDefeated: true, calendar: calendar)

        // Starsi verze ukladaly Hero HP, nejlepsi combo a cas neuspechu, ktery mazal serii.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stats)) as? [String: Any])
        json["heroHP"] = 40
        json["bestCombo"] = 4
        json["lastQuestFailedAt"] = 700_000_000.0
        let legacy = try JSONDecoder().decode(PlayerStats.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.wins, 1)
        // Utek bosse serii nebere.
        XCTAssertEqual(legacy.currentStreak(now: dayOne.addingTimeInterval(120), calendar: calendar), 1)

        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        for key in ["heroHP", "bestCombo", "lastQuestFailedAt"] { XCTAssertNil(saved[key], key) }
    }

    func testLocalProfileSurvivesRelaunch() async throws {
        let suiteName = "focusquest.tests.\(UUID().uuidString)"
        var profile = UserProfile.fresh(deviceID: "local-preview")
        profile.avatar.hairColor = .mint
        profile.coins = 77
        let firstLaunch = LocalProfileSyncService(suiteName: suiteName)
        try await firstLaunch.saveProfile(profile)
        let summary = SessionSummary(id: UUID(), bossName: "Slime", verifiedMinutes: 25, xpEarned: 250, completedAt: Date(), flawless: true)
        _ = try await firstLaunch.recordBattle(summary, bossDefeated: true)

        let secondLaunch = LocalProfileSyncService(suiteName: suiteName)
        let restored = try await secondLaunch.loadProfile()
        let restoredStats = try await secondLaunch.loadStats()
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)

        XCTAssertEqual(restored.avatar.hairColor, .mint)
        XCTAssertEqual(restored.coins, 77)
        XCTAssertEqual(restoredStats.wins, 1)
        XCTAssertEqual(restoredStats.totalXP, 250)
    }

    func testNestedCornerRadiiAreConcentric() {
        // Vnitrni polomer = vnejsi − odsazeni.
        XCTAssertEqual(FQRadius.inCard, FQRadius.card - FQRadius.Inset.card)
        XCTAssertEqual(FQRadius.inDialog, FQRadius.dialog - FQRadius.Inset.dialog)
        XCTAssertEqual(FQRadius.inDialog, FQRadius.control, "Dialog buttons keep the control radius")
        XCTAssertEqual(FQRadius.inSmallCard, FQRadius.smallCard - FQRadius.Inset.smallCard)
        XCTAssertEqual(FQRadius.tabBar, FQRadius.display - FQRadius.Inset.tabBar)
        XCTAssertEqual(FQRadius.tabHighlight, FQRadius.tabBar - FQRadius.Inset.tabHighlight)
        // Vnoreny prvek nikdy neni vetsi nez jeho kontejner a nikdy hranaty.
        XCTAssertLessThan(FQRadius.inSheet, FQRadius.card)
        XCTAssertEqual(FQRadius.concentric(20, inset: 30), FQRadius.minimum)
    }

    func testUnreadableStoredDataIsBackedUpBeforeItIsReplaced() async throws {
        let suiteName = "focusquest.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let garbage = Data("not json".utf8)
        defaults.set(garbage, forKey: "focusquest.local-profile")
        let store = LocalProfileSyncService(suiteName: suiteName)
        let profile = try await store.loadProfile()
        let backup = defaults.data(forKey: StoredDataBackup.key(for: "focusquest.local-profile"))

        // Druha chyba prvni zalohu neprepise.
        defaults.set(Data("other garbage".utf8), forKey: "focusquest.local-profile")
        _ = LocalProfileSyncService(suiteName: suiteName)
        let backupAfterSecondFailure = defaults.data(forKey: StoredDataBackup.key(for: "focusquest.local-profile"))
        defaults.removePersistentDomain(forName: suiteName)

        XCTAssertFalse(profile.hasCreatedHero)
        XCTAssertEqual(backup, garbage)
        XCTAssertEqual(backupAfterSecondFailure, garbage)
    }

    func testResetProgressClearsStoredProfileAndStats() async throws {
        let suiteName = "focusquest.tests.\(UUID().uuidString)"
        var profile = UserProfile.fresh(deviceID: "local-preview")
        profile.coins = 500
        profile.hasCreatedHero = true
        let store = LocalProfileSyncService(suiteName: suiteName)
        try await store.saveProfile(profile)
        let summary = SessionSummary(id: UUID(), bossName: "Slime", verifiedMinutes: 25, xpEarned: 250, completedAt: Date(), flawless: true)
        _ = try await store.recordBattle(summary, bossDefeated: true)

        try await store.resetProgress()
        let afterReset = try await store.loadProfile()
        let relaunch = LocalProfileSyncService(suiteName: suiteName)
        let restored = try await relaunch.loadProfile()
        let restoredStats = try await relaunch.loadStats()
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)

        XCTAssertEqual(afterReset.coins, 0)
        XCTAssertFalse(restored.hasCreatedHero)
        XCTAssertEqual(restored.coins, 0)
        XCTAssertEqual(restoredStats.wins, 0)
        XCTAssertEqual(restoredStats.totalXP, 0)
    }

    // MARK: - Bestiar, hodnosti a povolani

    func testBestiaryCountsDefeatsPerSubjectAndBoss() {
        var stats = PlayerStats.initial
        func battle(_ bossID: String, _ name: String, _ subject: StudySubject?, won: Bool = true) {
            let summary = SessionSummary(id: UUID(), bossName: name, verifiedMinutes: 20, xpEarned: 200, completedAt: Date(), flawless: true, subject: subject, bossID: bossID)
            stats.record(summary, bossDefeated: won)
        }
        battle("banana-bandit", "Banana Bandit", .english)
        battle("banana-bandit", "Banana Bandit", .english)
        battle("banana-bandit", "Banana Bandit", .economics)
        battle("ballerina-cappuccina", "Ballerina Cappuccina", .economics)
        battle("ballerina-cappuccina", "Ballerina Cappuccina", .economics)
        battle("ballerina-cappuccina", "Ballerina Cappuccina", .economics)
        battle("goggle-grunt", "Goggle Grunt", .math, won: false)

        let groups = BestiaryGroup.groups(from: stats.bestiary)
        XCTAssertEqual(groups.map(\.subject), [.economics, .english])
        XCTAssertEqual(groups[0].totalDefeats, 4)
        XCTAssertEqual(groups[0].entries.map(\.bossName), ["Ballerina Cappuccina", "Banana Bandit"])
        XCTAssertEqual(groups[0].entries.map(\.defeats), [3, 1])
        XCTAssertEqual(groups[1].entries.map(\.defeats), [2])
    }

    func testBestiarySurvivesRelaunchAndOlderStatsStillLoad() async throws {
        let suiteName = "focusquest.tests.\(UUID().uuidString)"
        let firstLaunch = LocalProfileSyncService(suiteName: suiteName)
        let summary = SessionSummary(id: UUID(), bossName: "Banana Bandit", verifiedMinutes: 20, xpEarned: 200, completedAt: Date(), flawless: true, subject: .english, bossID: "banana-bandit")
        _ = try await firstLaunch.recordBattle(summary, bossDefeated: true)
        _ = try await firstLaunch.recordBattle(summary, bossDefeated: true)
        let restored = try await LocalProfileSyncService(suiteName: suiteName).loadStats()
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        XCTAssertEqual(restored.bestiary.count, 1)
        XCTAssertEqual(restored.bestiary.first?.defeats, 2)
        XCTAssertEqual(restored.bestiary.first?.subject, .english)

        let legacy = Data(#"{"level":3,"totalXP":2100,"wins":4,"battles":5,"streakDays":2,"bestCombo":3,"totalHPDealt":210,"sessionHistory":[]}"#.utf8)
        let older = try JSONDecoder().decode(PlayerStats.self, from: legacy)
        XCTAssertEqual(older.level, 3)
        XCTAssertTrue(older.bestiary.isEmpty)
    }

    func testLevelTierFollowsLevel() {
        XCTAssertEqual(LevelTier(level: 1), .bronze)
        XCTAssertEqual(LevelTier(level: 4), .bronze)
        XCTAssertEqual(LevelTier(level: 5), .silver)
        XCTAssertEqual(LevelTier(level: 10), .gold)
        XCTAssertEqual(LevelTier(level: 19), .sapphire)
        XCTAssertEqual(LevelTier(level: 20), .rainbow)
        XCTAssertFalse(LevelTier(level: 9).hasWings)
        XCTAssertTrue(LevelTier(level: 10).hasWings)
    }

    func testShopBackgroundCatalogMatchesDesign() {
        XCTAssertEqual(ShopBackground.free.map(\.price), [0, 0])
        XCTAssertEqual(ShopBackground.forCoins.map(\.price), [800, 800, 1000, 1000, 1200, 1500, 1500])
        XCTAssertEqual(Set(ShopBackground.free + ShopBackground.forCoins), Set(ShopBackground.allCases))
        XCTAssertEqual(ShopBackground.wind.name, "Wind Farm")
        XCTAssertTrue(ShopBackground.dawn.isBright)
        XCTAssertFalse(ShopBackground.city.isBright)
    }

    func testDebugSetLevelMovesXPToStartOfLevel() {
        var stats = PlayerStats.initial
        stats.setLevel(10)
        XCTAssertEqual(stats.level, 10)
        XCTAssertEqual(stats.totalXP, 9_000)
        XCTAssertEqual(stats.xpIntoLevel, 0)
        stats.setLevel(0)
        XCTAssertEqual(stats.level, 1)
        XCTAssertEqual(stats.totalXP, 0)
    }

    func testBattleSoundMapsToMusicAndSoundscape() {
        var preferences = AppPreferences()
        XCTAssertEqual(preferences.battleSound, .lofi)
        preferences.battleSound = .brownNoise
        XCTAssertTrue(preferences.isMusicEnabled)
        XCTAssertEqual(preferences.soundscape, .brownNoise)
        preferences.battleSound = .off
        XCTAssertFalse(preferences.isMusicEnabled)
        XCTAssertEqual(preferences.battleSound, .off)
        preferences.battleSound = .whiteNoise
        XCTAssertEqual(preferences.battleSound, .whiteNoise)
    }

    func testOlderPreferencesGetSoundAndNotificationDefaults() throws {
        let json = Data(#"{"isHapticsEnabled":false,"isMusicEnabled":true,"isSFXEnabled":false}"#.utf8)
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: json)
        XCTAssertFalse(preferences.isHapticsEnabled)
        XCTAssertTrue(preferences.isAchievementSoundEnabled)
        XCTAssertTrue(preferences.isAlarmSoundEnabled)
        XCTAssertFalse(preferences.isDailyReminderEnabled)
        XCTAssertTrue(preferences.isBattleDoneNotificationEnabled)
        XCTAssertTrue(preferences.isBreakOverNotificationEnabled)
        // Stary spolecny prepinac "Tap and battle sounds" byl vypnuty: vypnute jsou klepnuti i bitva.
        XCTAssertFalse(preferences.isBattleSoundEnabled)
        XCTAssertEqual(preferences.effectsVolume, 0.8)
        XCTAssertEqual(preferences.soundEffectsOnCount, 2)
    }

    func testSplitSoundTogglesRoundTrip() throws {
        var preferences = AppPreferences()
        preferences.isSFXEnabled = true
        preferences.isBattleSoundEnabled = false
        preferences.isAchievementSoundEnabled = false
        preferences.effectsVolume = 0.35
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertTrue(decoded.isSFXEnabled)
        XCTAssertFalse(decoded.isBattleSoundEnabled)
        XCTAssertFalse(decoded.isAchievementSoundEnabled)
        XCTAssertEqual(decoded.effectsVolume, 0.35, accuracy: 0.0001)
        XCTAssertEqual(decoded.soundEffectsOnCount, 2)
    }

    func testOlderProfileDecodesWithoutBackgrounds() throws {
        let json = Data(#"{"userID":"a","username":"Hero1","title":"x","heroClass":"cyberRonin","avatarMatrix":[],"dailyFocusGoalMinutes":60}"#.utf8)
        let profile = try JSONDecoder().decode(UserProfile.self, from: json)
        XCTAssertTrue(profile.ownedBackgroundIDs.isEmpty)
        XCTAssertNil(profile.backgroundID)
    }

    func testShopSceneLayoutUsesThreePointGrid() {
        let layout = ShopSceneLayout(size: CGSize(width: 402, height: 874), background: .wind)
        XCTAssertEqual(layout.px, 3)
        XCTAssertEqual(layout.cols, 135)
    }

    func testBossesBeatenSkipsWarmUp() {
        var stats = PlayerStats.initial
        stats.bestiary = [
            BestiaryEntry(bossID: Boss.roster[0].id, bossName: Boss.roster[0].name, subject: nil, defeats: 2),
            BestiaryEntry(bossID: Boss.warmUpWispID, bossName: Boss.warmUpWisp.name, subject: nil, defeats: 3)
        ]
        XCTAssertEqual(stats.bossesBeaten, 2)
    }

    func testDevBonusXPRaisesLevelWithoutCountingABattle() async throws {
        let suiteName = "focusquest.tests.\(UUID().uuidString)"
        let service = LocalProfileSyncService(suiteName: suiteName)
        let stats = try await service.addBonusXP(5_000)
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        XCTAssertEqual(stats.totalXP, 5_000)
        XCTAssertEqual(stats.level, 6)
        XCTAssertEqual(stats.battles, 0)
    }

    func testOlderHeroClassNamesMapToNewClasses() throws {
        let decoded = try JSONDecoder().decode([HeroClass].self, from: Data(#"["voidKnight","arcaneScholar","alchemist","cyberRonin","archer","somethingNew"]"#.utf8))
        XCTAssertEqual(decoded, [.warrior, .mage, .archer, .rogue, .archer, .warrior])
    }

    // MARK: - Sumy

    func testNoiseLoopsHaveExpectedLengthAndBrownNoiseLoopsWithoutAClick() {
        let expected = NoiseSynth.sampleRate * NoiseSynth.loopSeconds
        let white = NoiseSynth.whiteNoise()
        let brown = NoiseSynth.brownNoise()
        XCTAssertEqual(white.count, expected)
        XCTAssertEqual(brown.count, expected)
        XCTAssertGreaterThan(Set(white.prefix(1_000)).count, 100)
        // Konec smycky navazuje na zacatek: skok mezi poslednim a prvnim vzorkem je zanedbatelny.
        let seam = abs(Int(brown[brown.count - 1]) - Int(brown[0]))
        XCTAssertLessThan(seam, 64)
        // Spicka odpovida ztisene hlasitosti (NoiseSynth.brownPeak = 0,19 z plneho rozsahu), ne tichu.
        let peak = brown.map { abs(Int($0)) }.max() ?? 0
        let expectedPeak = Int(NoiseSynth.brownPeak * Double(Int16.max))
        XCTAssertGreaterThan(peak, expectedPeak * 9 / 10)
        XCTAssertLessThanOrEqual(peak, expectedPeak + 1)
    }

    // MARK: - Predmety (Fight sheet)

    func testAddingSubjectCreatesItOnceAndPicksExistingOnDuplicate() {
        var subjects = StudySubject.defaults.map { SubjectEntry(subject: $0) }
        XCTAssertEqual(subjects.add(named: "  statistics "), .created(StudySubject(id: "Statistics", title: "Statistics")))
        XCTAssertEqual(subjects.count, StudySubject.defaults.count + 1)
        // Bez ohledu na velikost pismen a diakritiku.
        XCTAssertEqual(subjects.add(named: "MATH")?.subject, .math)
        XCTAssertEqual(subjects.add(named: "Čzech")?.subject, .czech)
        // Zacatek nazvu od 4 pismen najde existujici predmet.
        if case let .existing(found)? = subjects.add(named: "econ") { XCTAssertEqual(found, .economics) } else { XCTFail("econ ma najit Economics") }
        // Kratsi zacatek uz je novy predmet.
        if case .created? = subjects.add(named: "Ma") {} else { XCTFail("Ma ma byt novy predmet") }
        XCTAssertNil(subjects.add(named: "   "))
    }

    func testDeletedSubjectDisappearsAndComesBackWhenAddedAgain() {
        var subjects = StudySubject.defaults.map { SubjectEntry(subject: $0) }
        subjects.softDelete(.english)
        XCTAssertFalse(subjects.visibleSubjects.contains(.english))
        XCTAssertEqual(subjects.count, StudySubject.defaults.count)
        XCTAssertEqual(subjects.add(named: "english"), .existing(.english))
        XCTAssertTrue(subjects.visibleSubjects.contains(.english))
        // Poradi seznamu se nemeni.
        XCTAssertEqual(subjects.visibleSubjects, StudySubject.defaults)
    }

    func testPreselectedSubjectIsLastUsedOrFirstVisible() {
        var preferences = AppPreferences()
        XCTAssertEqual(preferences.preselectedSubject, .math)
        preferences.lastSubject = .german
        XCTAssertEqual(preferences.preselectedSubject, .german)
        preferences.subjects.softDelete(.german)
        XCTAssertEqual(preferences.preselectedSubject, .math)
    }

    func testRenamedSubjectSurvivesRoundTrip() throws {
        var preferences = AppPreferences()
        preferences.subjects[0].subject.title = "Maths"
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: try JSONEncoder().encode(preferences))
        XCTAssertEqual(decoded.subjects[0].subject.title, "Maths")
        XCTAssertEqual(decoded.subjects[0].subject, .math)
        XCTAssertEqual(decoded, preferences)
    }

    func testOlderSaveWithLastSubjectKeepsItInTheList() throws {
        let legacy = Data(#"{"isHapticsEnabled":true,"isMusicEnabled":true,"isSFXEnabled":true,"ambientVolume":0.5,"selectedTrack":"tokyoSunset","lastSubject":"history"}"#.utf8)
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: legacy)
        XCTAssertEqual(preferences.lastSubject, .history)
        XCTAssertTrue(preferences.subjects.visibleSubjects.contains(.history))
        XCTAssertEqual(preferences.preselectedSubject?.title, "History")
    }

    func testInlineCompletionSkipsSubjectsThePlayerAlreadyHas() {
        // Math uz hrac ma (vychozi predmety), takze "m" nabidne az Microeconomics.
        XCTAssertEqual(StudySubject.completion(for: "m", taken: StudySubject.defaults), "Microeconomics")
        XCTAssertEqual(StudySubject.completion(for: "M", taken: []), "Math")
        XCTAssertEqual(StudySubject.completion(for: "PSY", taken: []), "Psychology")
        XCTAssertEqual(StudySubject.completion(for: "Mac", taken: []), "Macroeconomics")
    }

    func testInlineCompletionStopsWhenNothingIsLeftToAdd() {
        XCTAssertNil(StudySubject.completion(for: "", taken: []))
        XCTAssertNil(StudySubject.completion(for: " m", taken: []))
        XCTAssertNil(StudySubject.completion(for: "Math", taken: []), "A full match has no grey rest")
        XCTAssertNil(StudySubject.completion(for: "Quantum", taken: []))
        XCTAssertNil(StudySubject.completion(for: "e", taken: [StudySubject(id: "English"), StudySubject(id: "Economics")]))
    }

    // MARK: - Rozcvicka (Warm-up Wisp)

    func testKeepGoingPicksShortestUnbeatenBossAcrossWorlds() {
        // Nikdo neporazeny: nejkratsi (10 min) je prvni boss prvniho sveta.
        XCTAssertEqual(Boss.shortestUnbeaten { _ in false }?.id, BossWorld.heroes.bosses[0].id)
        // Prvni boss Hero Heights porazeny: shoda 10 min vyhraje prvni v poradi svetu (Villain Vault).
        let first = BossWorld.heroes.bosses[0]
        XCTAssertEqual(Boss.shortestUnbeaten { $0.id == first.id }?.id, BossWorld.villains.bosses[0].id)
        // Vsechny 10minutove porazene: nejkratsi zbyvajici je 15 min, prvni v poradi.
        let next = Boss.shortestUnbeaten { $0.maxHP <= 10 }
        XCTAssertEqual(next?.maxHP, 15)
        XCTAssertEqual(next?.id, BossWorld.heroes.bosses[1].id)
        XCTAssertNil(Boss.shortestUnbeaten { _ in true })
        XCTAssertFalse(Boss.roster.contains { $0.isWarmUp }, "The warm-up boss is never on a Path")
    }

    func testWarmUpWinGivesRewardsButNoPathBadge() {
        var stats = PlayerStats.initial
        let wisp = Boss.warmUpWisp
        XCTAssertEqual(wisp.maxHP, 5)
        XCTAssertEqual(RewardRules.xp(verifiedMinutes: wisp.maxHP), 60)
        XCTAssertEqual(RewardRules.coins(verifiedMinutes: wisp.maxHP), 15)
        let summary = SessionSummary(id: UUID(), bossName: wisp.name, verifiedMinutes: 5, xpEarned: 60, completedAt: Date(), flawless: true, subject: .math, bossID: wisp.id, isQuick: true)
        stats.record(summary, bossDefeated: true)
        XCTAssertEqual(stats.wins, 1)
        XCTAssertEqual(stats.totalXP, 60)
        XCTAssertEqual(stats.streakDays, 1)
        XCTAssertTrue(stats.pathWins.isEmpty, "A warm-up win must not give any Path boss a badge")
    }

    func testWarmUpNeverMovesThePath() {
        var preferences = AppPreferences()
        preferences.markCleared(Boss.warmUpWisp)
        XCTAssertTrue(BossWorld.allCases.allSatisfy { preferences.clearedNodes(in: $0) == 0 })
        XCTAssertEqual(Boss.find(Boss.warmUpWispID)?.name, "Warm-up Wisp")
        XCTAssertEqual(SpritePalette.rows(for: .boss(Boss.warmUpWispID), startled: false).count, 16)
        XCTAssertNotEqual(SpritePalette.rows(for: .boss(Boss.warmUpWispID), startled: false), SpritePalette.slimeRows)
    }

    func testOlderQuickWinsOnPathBossesAreDroppedFromBadgesOnce() throws {
        let boss = BossWorld.heroes.bosses[0]
        var stats = PlayerStats.initial
        // Starsi verze: rychla 5min bitva proti bossovi z Path a normalni bitva, obe bez znacky isQuick.
        stats.record(SessionSummary(id: UUID(), bossName: boss.name, verifiedMinutes: 5, xpEarned: 60, completedAt: Date(), flawless: true, subject: .math, bossID: boss.id), bossDefeated: true)
        stats.record(SessionSummary(id: UUID(), bossName: boss.name, verifiedMinutes: boss.maxHP, xpEarned: 120, completedAt: Date(), flawless: true, subject: .math, bossID: boss.id), bossDefeated: true)
        XCTAssertEqual(stats.pathWins[boss.id], 2)

        let loaded = try JSONDecoder().decode(PlayerStats.self, from: JSONEncoder().encode(stats))
        XCTAssertEqual(loaded.pathWins[boss.id], 1, "Only the full-length win keeps its badge")
        XCTAssertEqual(loaded.sessionHistory.map(\.isQuick), [false, true])
        XCTAssertEqual(loaded.wins, 2, "Quick wins still count in the stats")

        let reloaded = try JSONDecoder().decode(PlayerStats.self, from: JSONEncoder().encode(loaded))
        XCTAssertEqual(reloaded.pathWins[boss.id], 1, "Loading again must not subtract twice")
    }

    // MARK: - Your subjects (sekce 7)

    func testDeletedSubjectCanBeRestoredWithinADay() {
        var subjects = StudySubject.defaults.map { SubjectEntry(subject: $0) }
        let deletedAt = Date(timeIntervalSince1970: 1_000_000)
        subjects.softDelete(.english, at: deletedAt)
        XCTAssertEqual(subjects.recentlyDeleted.map(\.subject), [.english])
        XCTAssertEqual(subjects.first { $0.subject == .english }?.hoursUntilPurge(now: deletedAt.addingTimeInterval(30 * 60)), 24)
        XCTAssertEqual(subjects.first { $0.subject == .english }?.hoursUntilPurge(now: deletedAt.addingTimeInterval(3_600 + 1)), 23)
        XCTAssertEqual(subjects.purgeExpired(now: deletedAt.addingTimeInterval(23 * 3_600)), [])
        subjects.restore(.english)
        XCTAssertTrue(subjects.visibleSubjects.contains(.english))
        XCTAssertTrue(subjects.recentlyDeleted.isEmpty)
    }

    func testSubjectIsPurgedWithItsStatsAfterADay() {
        var subjects = StudySubject.defaults.map { SubjectEntry(subject: $0) }
        let deletedAt = Date(timeIntervalSince1970: 1_000_000)
        subjects.softDelete(.german, at: deletedAt)
        XCTAssertEqual(subjects.purgeExpired(now: deletedAt.addingTimeInterval(24 * 3_600)), ["german"])
        XCTAssertFalse(subjects.contains { $0.subject == .german })

        var stats = PlayerStats.initial
        stats.record(SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: 20, xpEarned: 240, completedAt: Date(), flawless: true, subject: .german, bossID: "a"), bossDefeated: true)
        stats.record(SessionSummary(id: UUID(), bossName: "B", verifiedMinutes: 10, xpEarned: 120, completedAt: Date(), flawless: true, subject: .math, bossID: "b"), bossDefeated: true)
        stats.removeSubjects(["german"])
        XCTAssertEqual(stats.sessionHistory.map(\.subject), [.math])
        XCTAssertEqual(stats.bestiary.map(\.bossID), ["b"])
        XCTAssertEqual(stats.totalXP, 360, "Earned XP stays")
    }

    func testSubjectsWithStatsMissingFromTheListAreAddedBack() {
        var subjects = [SubjectEntry(subject: .math)]
        let history = [
            SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: 20, xpEarned: 0, completedAt: Date(), flawless: true, subject: StudySubject(id: "Biology")),
            SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: 20, xpEarned: 0, completedAt: Date(), flawless: true, subject: .math),
            SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: 20, xpEarned: 0, completedAt: Date(), flawless: true, subject: .general),
            SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: 20, xpEarned: 0, completedAt: Date(), flawless: true, subject: StudySubject(id: "Biology")),
            SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: 20, xpEarned: 0, completedAt: Date(), flawless: true)
        ]
        XCTAssertTrue(subjects.addMissing(from: history))
        XCTAssertEqual(subjects.map(\.id), ["math", "Biology"])
        XCTAssertFalse(subjects.addMissing(from: history), "Nothing is added twice")
    }

    // MARK: - Stats (sekce 8)

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func session(on date: Date, minutes: Int) -> SessionSummary {
        SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: minutes, xpEarned: 0, completedAt: date, flawless: true, subject: .math)
    }

    func testHabitGridHasMondayToSundayWeeksEndingThisWeek() {
        // Patek 20. 11. 2026: posledni sloupec je tyden od pondeli 16. 11., sobota a nedele jsou budoucnost.
        let now = day(2026, 11, 20)
        let history = [session(on: day(2026, 11, 20, hour: 9), minutes: 20), session(on: day(2026, 11, 20, hour: 15), minutes: 10), session(on: day(2026, 11, 16), minutes: 95), session(on: day(2026, 1, 1), minutes: 30)]
        let grid = HabitGrid.make(history: history, weeks: 15, now: now, calendar: utcCalendar)
        XCTAssertEqual(grid.weeks.count, 15)
        XCTAssertTrue(grid.weeks.allSatisfy { $0.count == 7 })
        XCTAssertEqual(grid.weeks[0][0].date, day(2026, 8, 10, hour: 0), "First column starts on a Monday 14 weeks back")
        let thisWeek = grid.weeks[14]
        XCTAssertEqual(thisWeek[0].date, day(2026, 11, 16, hour: 0))
        XCTAssertEqual(thisWeek[0].minutes, 95)
        XCTAssertEqual(thisWeek[0].level, 4)
        XCTAssertEqual(thisWeek[4].minutes, 30)
        XCTAssertEqual(thisWeek[4].level, 2)
        XCTAssertTrue(thisWeek[4].isToday)
        XCTAssertEqual(thisWeek.map(\.isFuture), [false, false, false, false, false, true, true])
        XCTAssertEqual(grid.focusDays, 2, "Sessions outside the grid do not count")
    }

    func testHabitLevelsFollowFocusMinutes() {
        XCTAssertEqual([0, 1, 24, 25, 49, 50, 89, 90, 300].map(HabitGrid.level(forMinutes:)), [0, 1, 1, 2, 2, 3, 3, 4, 4])
    }

    func testLongestStreakCountsConsecutiveDays() {
        var stats = PlayerStats.initial
        XCTAssertEqual(stats.longestStreak(calendar: utcCalendar), 0)
        stats.sessionHistory = [
            session(on: day(2026, 11, 1), minutes: 20), session(on: day(2026, 11, 2), minutes: 20), session(on: day(2026, 11, 2, hour: 18), minutes: 20),
            session(on: day(2026, 11, 3), minutes: 20), session(on: day(2026, 11, 10), minutes: 20), session(on: day(2026, 11, 11), minutes: 20)
        ]
        XCTAssertEqual(stats.longestStreak(calendar: utcCalendar), 3)
    }
}
