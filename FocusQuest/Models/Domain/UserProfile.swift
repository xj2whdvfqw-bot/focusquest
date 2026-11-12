import Foundation

struct UserProfile: Codable, Sendable {
    let userID: String
    var username: String
    var title: String
    var heroClass: HeroClass
    var avatarMatrix: [Int]
    var dailyFocusGoalMinutes: Int
    var equippedLootIDs: [String]
    var unlockedLootIDs: [String]

    static func fresh(deviceID: String) -> UserProfile {
        UserProfile(userID: deviceID, username: "NewFocuser", title: "Novice Focuser", heroClass: .arcaneScholar, avatarMatrix: [], dailyFocusGoalMinutes: 60, equippedLootIDs: [], unlockedLootIDs: [])
    }
}