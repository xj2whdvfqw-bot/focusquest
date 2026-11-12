import Foundation

enum HeroClass: String, Codable, CaseIterable, Sendable, Identifiable {
    case arcaneScholar, cyberRonin, alchemist, voidKnight
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .arcaneScholar: "Arcane Scholar"
        case .cyberRonin: "Cyber Ronin"
        case .alchemist: "Alchemist"
        case .voidKnight: "Void Knight"
        }
    }
}

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