import XCTest
@testable import FocusQuest

/// Zvuky a haptika: Battle sounds vychozi vypnute, sila haptiky a nove skladby.
final class SoundSettingsTests: XCTestCase {
    func testBattleSoundsAreOffByDefault() {
        XCTAssertFalse(AppPreferences().isBattleSoundEnabled)
        XCTAssertFalse(AppPreferences().isBattleSoundUserSet)
    }

    /// Starsi instalace mely Battle sounds vychozi zapnute; dokud je hrac sam neprepnul, jsou ted vypnute.
    func testExistingUsersWhoNeverToggledBattleSoundsStartWithThemOff() throws {
        let legacy = Data(#"{"isHapticsEnabled":true,"isMusicEnabled":true,"isSFXEnabled":true,"isBattleSoundEnabled":true}"#.utf8)
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: legacy)
        XCTAssertFalse(preferences.isBattleSoundEnabled)
        XCTAssertTrue(preferences.isSFXEnabled)
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
