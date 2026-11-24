import XCTest
@testable import FocusQuest

/// Zvuky a haptika: vse vychozi zapnute (K1/D6), sila haptiky a nove skladby.
final class SoundSettingsTests: XCTestCase {
    func testAllSoundsAndHapticsAreOnByDefault() {
        let preferences = AppPreferences()
        XCTAssertTrue(preferences.isBattleSoundEnabled)
        XCTAssertTrue(preferences.isSFXEnabled, "Tap sounds")
        XCTAssertTrue(preferences.isHapticsEnabled)
        XCTAssertTrue(preferences.isAchievementSoundEnabled)
        XCTAssertTrue(preferences.isAlarmSoundEnabled)
        XCTAssertFalse(preferences.isBattleSoundUserSet)
    }

    /// Ulozena data bez rucniho prepnuti dostanou vychozi stav (zapnuto); rucni vypnuti plati.
    func testBattleSoundsFollowTheDefaultUntilTheUserTogglesThem() throws {
        let untouched = Data(#"{"isHapticsEnabled":true,"isMusicEnabled":true,"isSFXEnabled":true,"isBattleSoundEnabled":false}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(AppPreferences.self, from: untouched).isBattleSoundEnabled)
        let switchedOff = Data(#"{"isHapticsEnabled":true,"isMusicEnabled":true,"isSFXEnabled":true,"isBattleSoundEnabled":false,"isBattleSoundUserSet":true}"#.utf8)
        XCTAssertFalse(try JSONDecoder().decode(AppPreferences.self, from: switchedOff).isBattleSoundEnabled)
    }

    func testManuallyEnabledBattleSoundsSurviveARoundTrip() throws {
        var preferences = AppPreferences()
        preferences.isBattleSoundEnabled = true
        preferences.isBattleSoundUserSet = true
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertTrue(decoded.isBattleSoundEnabled)
        XCTAssertTrue(decoded.isBattleSoundUserSet)
    }

    func testHapticStrengthDefaultsToMediumAndRoundTrips() throws {
        XCTAssertEqual(AppPreferences().hapticStrength, .medium)
        var preferences = AppPreferences()
        preferences.hapticStrength = .strong
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(decoded.hapticStrength, .strong)
        XCTAssertLessThan(HapticStrength.light.scale, HapticStrength.medium.scale)
        XCTAssertLessThan(HapticStrength.medium.scale, HapticStrength.strong.scale)
    }

    func testNewMusicTracksMapToLoopingSoundscapes() {
        var preferences = AppPreferences()
        preferences.battleSound = .fireplacePiano
        XCTAssertTrue(preferences.isMusicEnabled)
        XCTAssertEqual(preferences.soundscape, .fireplacePiano)
        XCTAssertEqual(preferences.soundscape.loopResource, "fireplace-piano")
        preferences.battleSound = .studyFlow
        XCTAssertEqual(preferences.battleSound, .studyFlow)
        XCTAssertEqual(preferences.soundscape.loopResource, "study-flow")
        XCTAssertNil(Soundscape.lofi.loopResource)
        for sound in BattleSound.allCases where sound != .off {
            XCTAssertEqual(sound.soundscape.map(BattleSound.init(soundscape:)), sound)
        }
    }

    #if DEBUG
    func testDebugUnlockOpensEveryWorld() {
        var preferences = AppPreferences()
        XCTAssertFalse(BossWorld.allCases.allSatisfy { preferences.isUnlocked($0) })
        preferences.debugUnlockAllWorlds = true
        XCTAssertTrue(BossWorld.allCases.allSatisfy { preferences.isUnlocked($0) })
    }
    #endif
}
