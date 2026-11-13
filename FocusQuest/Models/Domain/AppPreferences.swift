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
    /// Pocet porazenych uzlu na ceste kazdeho sveta (rawValue sveta -> pocet). Dalsi uzel je odemceny.
    var clearedNodesByWorld: [String: Int] = [:]
    /// Naposledy zvoleny predmet, aby ho hrac nemusel vybirat pred kazdou bitvou znovu.
    var lastSubject: StudySubject?
    var lastBossID: String?

    enum CodingKeys: String, CodingKey {
        case isHapticsEnabled, isMusicEnabled, isSFXEnabled, ambientVolume, selectedTrack, soundscape, clearedNodesByWorld, lastSubject, lastBossID
    }

    /// Kolik uzlu sveta uz hrac porazil.
    func clearedNodes(in world: BossWorld) -> Int {
        min(world.bosses.count, max(0, clearedNodesByWorld[world.rawValue] ?? 0))
    }

    /// Uzel je hratelny, pokud je porazeny nebo je prave na rade.
    func isUnlocked(_ boss: Boss) -> Bool {
        boss.nodeIndex <= clearedNodes(in: boss.world)
    }

    /// Porazeni uzlu na rade posune cestu o krok dal; opakovana vyhra nad starsim uzlem nic nemeni.
    mutating func markCleared(_ boss: Boss) {
        let world = boss.world
        guard boss.nodeIndex == clearedNodes(in: world) else { return }
        clearedNodesByWorld[world.rawValue] = boss.nodeIndex + 1
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
        // Starsi verze mely vlastni delku bitvy (bossMinutes, bossMinutesByID); ta se zamerne zahodi.
        clearedNodesByWorld = (try? container.decodeIfPresent([String: Int].self, forKey: .clearedNodesByWorld)) ?? [:]
        lastSubject = try? container.decodeIfPresent(StudySubject.self, forKey: .lastSubject)
        lastBossID = try? container.decodeIfPresent(String.self, forKey: .lastBossID)
    }
}
