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

/// Zanr zvuku pri soustredeni. Lo-fi jsou nahravky z bundlu, sumy se generuji primo v appce.
enum Soundscape: String, Codable, CaseIterable, Sendable, Identifiable {
    case lofi, whiteNoise, brownNoise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lofi: "Lo-fi beats"
        case .whiteNoise: "White noise"
        case .brownNoise: "Brown noise"
        }
    }

    var shortTitle: String {
        switch self {
        case .lofi: "Lo-fi"
        case .whiteNoise: "White"
        case .brownNoise: "Brown"
        }
    }
}

struct AppPreferences: Codable, Equatable, Sendable {
    var isHapticsEnabled = true
    var isMusicEnabled = true
    var isSFXEnabled = true
    var ambientVolume = 0.55
    var selectedTrack: AmbientTrack = .calmCurrents
    var soundscape: Soundscape = .lofi
    /// HP kazdeho bosse zvlast (ID bosse -> minuty). Chybejici boss ma svoje vychozi HP.
    var bossMinutesByID: [String: Int] = [:]
    /// Naposledy zvoleny predmet, aby ho hrac nemusel vybirat pred kazdou bitvou znovu.
    var lastSubject: StudySubject?
    var lastBossID: String?

    enum CodingKeys: String, CodingKey {
        case isHapticsEnabled, isMusicEnabled, isSFXEnabled, ambientVolume, selectedTrack, soundscape, bossMinutesByID, lastSubject, lastBossID
    }

    /// HP (minuty) konkretniho bosse.
    func bossMinutes(for bossID: String) -> Int {
        bossMinutesByID[bossID].map(Boss.clampedMinutes) ?? Boss.defaultMinutes(for: bossID)
    }
}

extension AppPreferences {
    // Predvolby ulozene starsi verzi nektera pole nemaji; chybejici hodnoty se doplni vychozimi.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppPreferences()
        isHapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isHapticsEnabled) ?? fallback.isHapticsEnabled
        isMusicEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMusicEnabled) ?? fallback.isMusicEnabled
        isSFXEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSFXEnabled) ?? fallback.isSFXEnabled
        ambientVolume = try container.decodeIfPresent(Double.self, forKey: .ambientVolume) ?? fallback.ambientVolume
        selectedTrack = try container.decodeIfPresent(AmbientTrack.self, forKey: .selectedTrack) ?? fallback.selectedTrack
        soundscape = (try? container.decodeIfPresent(Soundscape.self, forKey: .soundscape)) ?? fallback.soundscape
        // Starsi verze mela jedno HP pro vsechny bosse ("bossMinutes"); to se zamerne zahodi.
        let storedMinutes = (try? container.decodeIfPresent([String: Int].self, forKey: .bossMinutesByID)) ?? nil
        bossMinutesByID = (storedMinutes ?? [:]).mapValues(Boss.clampedMinutes)
        lastSubject = try? container.decodeIfPresent(StudySubject.self, forKey: .lastSubject)
        lastBossID = try? container.decodeIfPresent(String.self, forKey: .lastBossID)
    }
}
