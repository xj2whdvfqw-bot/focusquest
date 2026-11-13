import Foundation

/// Hrdinske povolani. Vybira se pri uvodni tvorbe hrdiny; meni barvu a pasek pixeloveho hrdiny.
enum HeroClass: String, Codable, CaseIterable, Sendable, Identifiable {
    case warrior, mage, archer, rogue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warrior: "Warrior"
        case .mage: "Mage"
        case .archer: "Archer"
        case .rogue: "Rogue"
        }
    }

    /// Kratky popis na karte povolani.
    var tagline: String {
        switch self {
        case .warrior: "Shield up, push through long sessions."
        case .mage: "Turns quiet hours into arcane power."
        case .archer: "Patient aim, one target at a time."
        case .rogue: "Slips past every distraction."
        }
    }

    var symbol: String {
        switch self {
        case .warrior: "shield.lefthalf.filled"
        case .mage: "wand.and.stars"
        case .archer: "scope"
        case .rogue: "moon.stars.fill"
        }
    }

    /// Profily ze starsi verze maji puvodni povolani; prevedou se na nejblizsi nove.
    /// Nezname povolani nesmi zahodit cely ulozeny profil.
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = HeroClass.migrating(raw)
    }

    static func migrating(_ raw: String) -> HeroClass {
        if let value = HeroClass(rawValue: raw) { return value }
        switch raw {
        case "voidKnight": return .warrior
        case "arcaneScholar": return .mage
        case "alchemist": return .archer
        case "cyberRonin": return .rogue
        default: return .warrior
        }
    }
}
