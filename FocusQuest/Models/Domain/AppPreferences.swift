import Foundation

/// Lo-fi skladby pribalene v appce (FocusQuest/Resources/Audio).
/// Vsechny jsou od HoliznaCC0 pod licenci CC0 - viz CREDITS.md.
enum AmbientTrack: String, Codable, CaseIterable, Sendable, Identifiable {
    case calmCurrents, tokyoSunset, peacefulDrift

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calmCurrents: "Calm Currents"
        case .tokyoSunset: "Tokyo Sunset"
        case .peacefulDrift: "Peaceful Drift"
        }
    }

    /// Nazev .mp3 souboru v bundlu (bez pripony).
    var resourceName: String {
        switch self {
        case .calmCurrents: "calm-currents"
        case .tokyoSunset: "tokyo-sunset"
        case .peacefulDrift: "peaceful-drift"
        }
    }

    /// Dalsi skladba v playlistu; po posledni se zacina znovu od prvni.
    var next: AmbientTrack {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        return all[(index + 1) % all.count]
    }

    // Ulozene predvolby mohou obsahovat skladbu ze starsi verze (napr. "midnightRain").
    // Neznama hodnota se nahradi vychozi skladbou, aby se nezahodily ostatni predvolby.
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AmbientTrack(rawValue: raw) ?? .calmCurrents
    }
}

struct AppPreferences: Codable, Sendable {
    var isHapticsEnabled = true
    var isMusicEnabled = true
    var isSFXEnabled = true
    var ambientVolume = 0.55
    var selectedTrack: AmbientTrack = .calmCurrents
}
