import Foundation

/// Hodnost hrdiny. Neni volitelna: odvozuje se z levelu a sama se zlepsuje, jak hrac sbira XP.
struct HeroRank: Identifiable, Equatable, Sendable {
    let title: String
    let minimumLevel: Int

    var id: String { title }

    static let ladder: [HeroRank] = [
        HeroRank(title: "Novice Focuser", minimumLevel: 1),
        HeroRank(title: "Apprentice Scholar", minimumLevel: 3),
        HeroRank(title: "Deep Work Mage", minimumLevel: 5),
        HeroRank(title: "Focus Knight", minimumLevel: 8),
        HeroRank(title: "Master of Concentration", minimumLevel: 12),
        HeroRank(title: "Grandmaster of Stillness", minimumLevel: 20)
    ]

    /// Nejvyssi hodnost, na kterou hrac s danym levelem dosahne.
    static func current(forLevel level: Int) -> HeroRank {
        ladder.last { level >= $0.minimumLevel } ?? ladder[0]
    }

    /// Dalsi hodnost nad aktualnim levelem; nil = hrac uz ma nejvyssi.
    static func next(afterLevel level: Int) -> HeroRank? {
        ladder.first { $0.minimumLevel > level }
    }
}
