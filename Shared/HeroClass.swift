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
