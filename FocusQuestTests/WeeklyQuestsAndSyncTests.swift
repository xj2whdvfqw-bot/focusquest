import XCTest
@testable import FocusQuest

/// C5 tydenni ukoly a C7 slouceni stavu z iCloudu.
final class WeeklyQuestsAndSyncTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func session(_ date: Date, minutes: Int, subject: StudySubject = .math, quick: Bool = false) -> SessionSummary {
        SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: minutes, xpEarned: 0, completedAt: date, flawless: true, subject: subject, isQuick: quick)
    }

    func testNewPlayerGetsThreeEasyQuestsThatStayAllWeek() {
        let monday = day(2026, 11, 23)
        let quests = WeeklyQuests.make(history: [], now: monday, calendar: calendar)
        XCTAssertEqual(quests.count, 3)
        XCTAssertEqual(quests[0].kind, .focusMinutes)
        XCTAssertEqual(quests[0].target, 60)
        XCTAssertEqual(quests[1].kind, .focusDays)
        XCTAssertEqual(quests[1].target, 3)
        XCTAssertTrue(quests.allSatisfy { $0.reward >= WeeklyQuests.baseReward })
        // Stejne ukoly i v nedeli (obtiznost z tydnu pred pondelim).
        let sunday = WeeklyQuests.make(history: [session(day(2026, 11, 25), minutes: 300)], now: day(2026, 11, 29), calendar: calendar)
        XCTAssertEqual(sunday.map(\.id), quests.map(\.id))
        XCTAssertEqual(sunday.map(\.target), quests.map(\.target))
    }

    func testTargetsGrowWithHistoryAndProgressCounts() {
        // 4 tydny po 200 minutach na 4 dnech.
        var history: [SessionSummary] = []
        for week in 1...4 {
            for offset in 0..<4 {
                history.append(session(day(2026, 11, 23).addingTimeInterval(TimeInterval(-week * 7 + offset) * 86_400), minutes: 50))
            }
        }
        let monday = day(2026, 11, 23)
        let quests = WeeklyQuests.make(history: history, now: monday, calendar: calendar)
        XCTAssertEqual(quests[0].target, 225, "About 15 % above the usual 200 minutes, rounded to 15")
        XCTAssertEqual(quests[1].target, 5)
        let week = [session(monday, minutes: 100), session(day(2026, 11, 24), minutes: 130, subject: .english), session(day(2026, 11, 24), minutes: 5, quick: true)]
        XCTAssertEqual(quests[0].progress(in: week, calendar: calendar), 225, "Progress is capped at the target")
        XCTAssertEqual(quests[1].progress(in: week, calendar: calendar), 2)
    }

    func testMergeKeepsNewerStateButNeverLosesProgress() {
        var local = AppState(formatVersion: 1, modifiedAt: day(2026, 11, 20), profile: .fresh(deviceID: "a"), stats: .initial, preferences: AppPreferences())
        var remote = local
        remote.modifiedAt = day(2026, 11, 21)

        local.profile.coins = 500
        local.profile.ownedEquipmentIDs = ["wooden-sword"]
        local.preferences.clearedNodesByWorld = ["farm": 7, "forest": 2]
        let shared = session(day(2026, 11, 19), minutes: 20)
        local.stats.sessionHistory = [session(day(2026, 11, 20), minutes: 30), shared]
        local.stats.totalXP = 5_000

        remote.profile.coins = 120
        remote.profile.ownedBackgroundIDs = ["dusk"]
        remote.preferences.clearedNodesByWorld = ["farm": 5]
        remote.stats.sessionHistory = [session(day(2026, 11, 21), minutes: 25), shared]
        remote.stats.totalXP = 3_000

        let merged = CloudSync.merge(local: local, remote: remote)
        XCTAssertEqual(merged.profile.coins, 120, "The newer state wins")
        XCTAssertEqual(Set(merged.profile.ownedEquipmentIDs), ["wooden-sword"], "Unlocked gear is never lost")
        XCTAssertEqual(Set(merged.profile.ownedBackgroundIDs), ["dusk"])
        XCTAssertEqual(merged.preferences.clearedNodesByWorld["farm"], 7, "Higher world progress is kept")
        XCTAssertEqual(merged.preferences.clearedNodesByWorld["forest"], 2)
        XCTAssertEqual(merged.stats.sessionHistory.count, 3, "History is the union by id")
        XCTAssertEqual(merged.stats.sessionHistory.first?.completedAt, day(2026, 11, 21))
        XCTAssertEqual(merged.stats.totalXP, 5_000)
        XCTAssertEqual(merged.modifiedAt, day(2026, 11, 21))
    }
}
