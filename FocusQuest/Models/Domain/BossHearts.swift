import Foundation

/// B1: zdravi bosse v bitve jako srdicka po ctvrtkach (misto plynule HP cary).
///
/// Pocet srdicek podle obtiznosti (Novice 3, Adept 4, Elite 5, Mythic 6), kazde ma 4 ctvrtky.
/// Kazdy pravidelny uder hrdiny ubere jednu ctvrtku. Rozestup uderu = delka bitvy / pocet ctvrtek,
/// takze posledni ctvrtka (financi uder) padne presne na konci bitvy. Kosmeticke tukani nic neubira.
/// Live Activity si nechava plynuly pruh podle casu.
struct BossHearts: Equatable, Sendable {
    static let quartersPerHeart = 4

    let hearts: Int
    let targetSeconds: Int

    init(tier: BossTier, targetSeconds: Int) {
        hearts = Self.heartCount(for: tier)
        self.targetSeconds = max(0, targetSeconds)
    }

    static func heartCount(for tier: BossTier) -> Int {
        switch tier {
        case .novice: 3
        case .adept: 4
        case .elite: 5
        case .mythic: 6
        }
    }

    var totalQuarters: Int { hearts * Self.quartersPerHeart }

    /// Rozestup pravidelnych uderu v sekundach.
    var strikeInterval: Double {
        totalQuarters > 0 ? Double(targetSeconds) / Double(totalQuarters) : 0
    }

    /// Kolik uderu (ctvrtek) uz padlo po `elapsed` sekundach bitvy. Uder k padne v k × delka / ctvrtky,
    /// posledni presne na konci.
    func strikes(atElapsed elapsed: Int) -> Int {
        guard targetSeconds > 0 else { return totalQuarters }
        return min(totalQuarters, max(0, elapsed * totalQuarters / targetSeconds))
    }

    func quartersLeft(atElapsed elapsed: Int) -> Int { totalQuarters - strikes(atElapsed: elapsed) }

    /// Plnych ctvrtek v srdicku `index` (0 = nejlevejsi), kdyz zbyva `quartersLeft`.
    /// Ubyva se od posledniho srdicka vpravo.
    static func filledQuarters(inHeart index: Int, quartersLeft: Int) -> Int {
        min(quartersPerHeart, max(0, quartersLeft - index * quartersPerHeart))
    }
}
