import Foundation

/// Skryte odmeny na mape Path. Kazdou jde najit jen jednou za celou hru (UserProfile.foundEasterEggs).
/// Zadne tipy ani napovedy: hrac je musi objevit sam.
enum MapEasterEgg: String, CaseIterable, Identifiable, Sendable {
    /// Whisperwood: 3x klepnuti na rybnik vynori truhlu, klepnuti na truhlu = mince.
    case pond
    /// Orbit: 4x klepnuti na oranzovou planetu = mince.
    case planet
    /// Farm: krizek v levem rohu sveta; 3 klepnuti truhlu postupne vykopou, klepnuti na truhlu = mince.
    case farmX

    var id: String { rawValue }

    var coins: Int {
        switch self {
        case .pond: 150
        case .planet: 200
        case .farmX: 100
        }
    }

    /// Kolik klepnuti je potreba, nez se objevi truhla (u planety rovnou odmena).
    var tapsNeeded: Int {
        switch self {
        case .pond: 3
        case .planet: 4
        case .farmX: 3
        }
    }

    var world: BossWorld {
        switch self {
        case .pond: .forest
        case .planet: .planets
        case .farmX: .farm
        }
    }
}
