import XCTest
@testable import FocusQuest

final class ProgressionModelTests: XCTestCase {
    // MARK: - HP bosse

    func testBossHPFollowsChosenMinutesAndStaysInRange() {
        let boss = Boss.roster[0].withHP(minutes: 37)
        XCTAssertEqual(boss.maxHP, 37)
        XCTAssertEqual(boss.currentHP, 37)
        XCTAssertEqual(Boss.roster[0].withHP(minutes: 0).maxHP, Boss.minutesRange.lowerBound)
        XCTAssertEqual(Boss.roster[0].withHP(minutes: 9_999).maxHP, Boss.minutesRange.upperBound)
    }

    func testSimulatedBackendUsesCustomHPForEachBattle() async throws {
        let backend = SimulatedSecureBackendService()
        let session = try await backend.startSession(bossID: Boss.roster[0].id, mode: .solo, targetMinutes: 12)
        let result = try await backend.completeSession(sessionID: session.sessionID)
        XCTAssertEqual(result.boss.maxHP, 12)
        XCTAssertEqual(result.boss.currentHP, 12)
    }

    // MARK: - Predvolby

    func testPreferencesSavedByOlderVersionKeepTheirValues() throws {
        let legacy = Data(#"{"isHapticsEnabled":false,"isMusicEnabled":true,"isSFXEnabled":true,"ambientVolume":0.3,"selectedTrack":"tokyoSunset"}"#.utf8)
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: legacy)
        XCTAssertFalse(preferences.isHapticsEnabled)
        XCTAssertEqual(preferences.ambientVolume, 0.3, accuracy: 0.0001)
        XCTAssertEqual(preferences.selectedTrack, .tokyoSunset)
        XCTAssertEqual(preferences.soundscape, .lofi)
        XCTAssertEqual(preferences.bossMinutes, Boss.defaultMinutes)
    }

    func testPreferencesRoundTripKeepsSoundscapeAndBossMinutes() throws {
        var preferences = AppPreferences()
        preferences.soundscape = .brownNoise
        preferences.bossMinutes = 90
        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        XCTAssertEqual(decoded, preferences)
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
            let layers = AvatarSprite.layers(for: appearance, heroClass: .voidKnight)
            let hasHair = layers.contains(where: { $0.id == "hair" })
            XCTAssertEqual(hasHair, style != .bald)
            for layer in layers {
                XCTAssertEqual(layer.rows.count, AvatarSprite.gridSize)
                XCTAssertTrue(layer.rows.allSatisfy({ $0.count == AvatarSprite.gridSize }))
                XCTAssertTrue(layer.rows.contains(where: { $0.contains("#") }), "Layer \(layer.id) is empty")
            }
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

    func testLocalProfileSurvivesRelaunch() async throws {
        let suiteName = "focusquest.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))

        var profile = UserProfile.fresh(deviceID: "local-preview")
        profile.avatar.hairColor = .mint
        profile.coins = 77
        let firstLaunch = LocalProfileSyncService(defaults: defaults)
        try await firstLaunch.saveProfile(profile)
        let summary = SessionSummary(id: UUID(), bossName: "Slime", verifiedMinutes: 25, xpEarned: 250, completedAt: Date(), flawless: true)
        _ = try await firstLaunch.recordBattle(summary, bossDefeated: true)

        let secondLaunch = LocalProfileSyncService(defaults: defaults)
        let restored = try await secondLaunch.loadProfile()
        let restoredStats = try await secondLaunch.loadStats()
        defaults.removePersistentDomain(forName: suiteName)

        XCTAssertEqual(restored.avatar.hairColor, .mint)
        XCTAssertEqual(restored.coins, 77)
        XCTAssertEqual(restoredStats.wins, 1)
        XCTAssertEqual(restoredStats.totalXP, 250)
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
