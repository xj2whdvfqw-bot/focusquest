import XCTest
@testable import FocusQuest

/// B1: srdicka bosse po ctvrtkach.
@MainActor
final class BossHeartsTests: XCTestCase {
    func testHeartCountFollowsDifficulty() {
        XCTAssertEqual(BossHearts.heartCount(for: .novice), 3)
        XCTAssertEqual(BossHearts.heartCount(for: .adept), 4)
        XCTAssertEqual(BossHearts.heartCount(for: .elite), 5)
        XCTAssertEqual(BossHearts.heartCount(for: .mythic), 6)
    }

    func testStrikesAreEvenAndTheLastLandsAtTheEnd() {
        // Novice, 15 minut: 12 ctvrtek, uder kazdych 75 s.
        let hearts = BossHearts(tier: .novice, targetSeconds: 15 * 60)
        XCTAssertEqual(hearts.totalQuarters, 12)
        XCTAssertEqual(hearts.strikeInterval, 75, accuracy: 0.001)
        XCTAssertEqual(hearts.quartersLeft(atElapsed: 0), 12)
        XCTAssertEqual(hearts.quartersLeft(atElapsed: 74), 12)
        XCTAssertEqual(hearts.quartersLeft(atElapsed: 75), 11)
        XCTAssertEqual(hearts.quartersLeft(atElapsed: 899), 1, "The last quarter waits for the very end")
        XCTAssertEqual(hearts.quartersLeft(atElapsed: 900), 0)
        XCTAssertEqual(hearts.quartersLeft(atElapsed: 5_000), 0)
    }

    func testQuartersEmptyFromTheLastHeart() {
        // 3 srdicka, zbyva 6 ctvrtek: prvni plne, druhe pulka, treti prazdne.
        XCTAssertEqual(BossHearts.filledQuarters(inHeart: 0, quartersLeft: 6), 4)
        XCTAssertEqual(BossHearts.filledQuarters(inHeart: 1, quartersLeft: 6), 2)
        XCTAssertEqual(BossHearts.filledQuarters(inHeart: 2, quartersLeft: 6), 0)
    }

    func testHeartQuartersSplitThePixelsEvenly() {
        let counts = (0..<4).map { index in
            PixelHeart.quarterRows([index]).joined().filter { $0 == "#" }.count
        }
        XCTAssertEqual(counts.reduce(0, +), PixelHeart.rows.joined().filter { $0 == "#" }.count)
        XCTAssertEqual(Set(counts).count, 1, "Every quarter has the same number of pixels: \(counts)")
    }

    func testSpokenHealth() {
        XCTAssertEqual(BossHeartsView.spoken(quartersLeft: 11, hearts: 3), "2 and 3 quarters of 3 hearts left")
        XCTAssertEqual(BossHeartsView.spoken(quartersLeft: 8, hearts: 3), "2 of 3 hearts left")
        XCTAssertEqual(BossHeartsView.spoken(quartersLeft: 1, hearts: 3), "1 quarter of 3 hearts left")
    }

    func testExtraPausesDecodeWithDefaultAndCap() throws {
        let fresh = UserProfile.fresh(deviceID: "x")
        var data = try JSONEncoder().encode(fresh)
        var decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(decoded.extraPauses, 0)
        var stuffed = fresh
        stuffed.extraPauses = 99
        data = try JSONEncoder().encode(stuffed)
        decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(decoded.extraPauses, UserProfile.maxExtraPauses)
    }
}
