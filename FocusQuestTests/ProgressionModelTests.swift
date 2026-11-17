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
        XCTAssertTrue(preferences.isUnlocked(BossWorld.heroes.bosses[0]))
        XCTAssertFalse(preferences.isUnlocked(BossWorld.heroes.bosses[1]))
    }

    func testPathUnlocksOneNodeAtATimeInEachWorld() {
        var preferences = AppPreferences()
        let heroes = BossWorld.heroes.bosses
        let villains = BossWorld.villains.bosses
        XCTAssertTrue(preferences.isUnlocked(heroes[0]))
        XCTAssertFalse(preferences.isUnlocked(heroes[1]))

        // Vyhra nad uzlem mimo poradi cestu neposune.
        preferences.markCleared(heroes[2])
        XCTAssertEqual(preferences.clearedNodes(in: .heroes), 0)

        preferences.markCleared(heroes[0])
        XCTAssertEqual(preferences.clearedNodes(in: .heroes), 1)
        XCTAssertTrue(preferences.isUnlocked(heroes[1]))
        XCTAssertFalse(preferences.isUnlocked(heroes[2]))
        XCTAssertEqual(BossWorld.heroes.frontierBoss(cleared: 1)?.id, heroes[1].id)

        // Opakovana vyhra nad starsim uzlem nic nemeni.
        preferences.markCleared(heroes[0])
        XCTAssertEqual(preferences.clearedNodes(in: .heroes), 1)

        // Kazdy svet ma vlastni cestu.
        XCTAssertTrue(preferences.isUnlocked(villains[0]))
        XCTAssertFalse(preferences.isUnlocked(villains[1]))

        // Dobyty svet uz nema dalsi uzel.
        for boss in villains { preferences.markCleared(boss) }
        XCTAssertEqual(preferences.clearedNodes(in: .villains), villains.count)
        XCTAssertNil(BossWorld.villains.frontierBoss(cleared: villains.count))
    }

    func testPreferencesRoundTripKeepsSoundscapePathProgressAndSubject() throws {
        var preferences = AppPreferences()
        preferences.soundscape = .brownNoise
        preferences.clearedNodesByWorld = [BossWorld.heroes.rawValue: 3, BossWorld.brainrot.rawValue: 1]
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
        XCTAssertEqual(progress.map(\.subject), [.math, .german])
        XCTAssertEqual(progress.first?.minutes, 45)
        XCTAssertEqual(progress.first?.battles, 2)
    }

    // MARK: - Hrdina a profil

    func testProfileFromOlderVersionGetsDefaultHeroAndVillage() throws {
        let legacy = Data(#"{"userID":"u1","username":"Adam","title":"Novice Focuser","heroClass":"cyberRonin","avatarMatrix":[],"dailyFocusGoalMinutes":60,"equippedLootIDs":[],"unlockedLootIDs":["scholars-tome"]}"#.utf8)
        let profile = try JSONDecoder().decode(UserProfile.self, from: legacy)
        XCTAssertEqual(profile.username, "Adam")
        XCTAssertEqual(profile.unlockedLootIDs, ["scholars-tome"])
        XCTAssertEqual(profile.avatar, AvatarAppearance())
        XCTAssertEqual(profile.village.stage, .woodenHut)
        XCTAssertEqual(profile.coins, 0)
        XCTAssertFalse(profile.hasCreatedHero)
    }

    func testProfileRoundTripKeepsHeroLookAndVillage() throws {
        var profile = UserProfile.fresh(deviceID: "test")
        profile.avatar.skin = .umber
        profile.avatar.hairStyle = .mohawk
        profile.avatar.equip("excalibur", in: .weapon)
        profile.village.stage = .castle
        profile.coins = 321
        profile.hasCreatedHero = true
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(decoded.avatar, profile.avatar)
        XCTAssertEqual(decoded.avatar.equippedItemID(in: .weapon), "excalibur")
        XCTAssertEqual(decoded.village, profile.village)
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

    // MARK: - Vesnice a odmeny

    func testVillageUpgradeNeedsLevelBossesAndCoins() {
        var village = VillageState()
        XCTAssertFalse(village.canUpgrade(level: 1, bossesDefeated: 0, coins: 500))
        XCTAssertFalse(village.canUpgrade(level: 1, bossesDefeated: 1, coins: 49))
        XCTAssertNil(village.upgrade(level: 1, bossesDefeated: 1, coins: 49))
        XCTAssertEqual(village.stage, .woodenHut)

        XCTAssertEqual(village.upgrade(level: 1, bossesDefeated: 1, coins: 50), 50)
        XCTAssertEqual(village.stage, .brickCottage)
        XCTAssertNotNil(village.builtAt[DwellingStage.brickCottage.rawValue])
        // Na kamenny dum uz level 1 nestaci.
        XCTAssertFalse(village.canUpgrade(level: 1, bossesDefeated: 10, coins: 10_000))
    }

    func testVillageStopsAtTheLastStage() {
        var village = VillageState()
        village.stage = .city
        XCTAssertNil(village.nextStage)
        XCTAssertNil(village.upgrade(level: 99, bossesDefeated: 999, coins: 99_999))
        XCTAssertEqual(village.stage, .city)
    }

    func testCoinRewardCountsMinutesAndBossBonus() {
        XCTAssertEqual(RewardRules.coins(verifiedMinutes: 25, bossDefeated: true), 35)
        XCTAssertEqual(RewardRules.coins(verifiedMinutes: 25, bossDefeated: false), 25)
        XCTAssertEqual(RewardRules.coins(verifiedMinutes: -5, bossDefeated: false), 0)
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

    // MARK: - HP hrdiny a serie

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

    func testFailedQuestResetsStreak() {
        let calendar = Calendar(identifier: .gregorian)
        let dayOne = Date(timeIntervalSince1970: 1_700_000_000)
        var stats = PlayerStats.initial

        stats.record(SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: 10, xpEarned: 100, completedAt: dayOne, flawless: true), bossDefeated: true, calendar: calendar)
        XCTAssertEqual(stats.currentStreak(now: dayOne, calendar: calendar), 1)

        stats.recordQuestFailure(at: dayOne.addingTimeInterval(60))
        XCTAssertEqual(stats.currentStreak(now: dayOne.addingTimeInterval(120), calendar: calendar), 0)

        // Dalsi vyhra serii zacne znovu od jedne.
        stats.record(SessionSummary(id: UUID(), bossName: "B", verifiedMinutes: 10, xpEarned: 100, completedAt: dayOne.addingTimeInterval(3_600), flawless: true), bossDefeated: true, calendar: calendar)
        XCTAssertEqual(stats.streakDays, 1)
    }

    func testQuestFailureSurvivesEncodingAndOldHeroHPIsIgnored() throws {
        var stats = PlayerStats.initial
        stats.recordQuestFailure(at: Date(timeIntervalSince1970: 1_700_000_000))
        let decoded = try JSONDecoder().decode(PlayerStats.self, from: JSONEncoder().encode(stats))
        XCTAssertEqual(decoded.lastQuestFailedAt, stats.lastQuestFailedAt)

        // Statistiky ze starsi verze s Hero HP se musi nacist dal.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stats)) as? [String: Any])
        json["heroHP"] = 40
        let legacy = try JSONDecoder().decode(PlayerStats.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.wins, stats.wins)
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

    func testRankFollowsLevel() {
        XCTAssertEqual(HeroRank.current(forLevel: 1).title, "Novice Focuser")
        XCTAssertEqual(HeroRank.current(forLevel: 4).title, "Apprentice Scholar")
        XCTAssertEqual(HeroRank.current(forLevel: 5).title, "Deep Work Mage")
        XCTAssertEqual(HeroRank.next(afterLevel: 5)?.minimumLevel, 8)
        XCTAssertEqual(HeroRank.current(forLevel: 99).title, "Grandmaster of Stillness")
        XCTAssertNil(HeroRank.next(afterLevel: 99))
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
        let peak = brown.map { abs(Int($0)) }.max() ?? 0
        XCTAssertGreaterThan(peak, 10_000)
    }
}
