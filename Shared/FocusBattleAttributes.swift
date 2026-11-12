import ActivityKit
import Foundation

/// Data Live Activity. Soubor je ve slozce Shared, protoze stejny typ musi znat
/// appka (spousti aktivitu) i Widget Extension (kresli ji na zamcene obrazovce).
struct FocusBattleAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var bossHP: Int
        var bossMaxHP: Int
        /// Zacatek soustredeni posunuty o pauzy. Cas z nej pocita primo system,
        /// takze bezi i kdyz je appka na pozadi. nil = ceka se na polozeni telefonu.
        var focusStartedAt: Date?
        /// Konec varovneho odpoctu po zvednuti telefonu. nil = zadne varovani.
        var warningEndsAt: Date?

        var isWarning: Bool { warningEndsAt != nil }
    }

    var bossName: String
    var bossSpriteID: String
    var bossMaxHP: Int
}
