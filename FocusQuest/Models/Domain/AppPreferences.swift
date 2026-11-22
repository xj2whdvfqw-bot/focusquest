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

/// Zvuk bitvy v Nastaveni (Off / Lo-fi / Brown noise / White noise).
enum BattleSound: String, CaseIterable, Identifiable, Sendable {
    case off, lofi, brownNoise, whiteNoise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .lofi: "Lo-fi"
        case .brownNoise: "Brown noise"
        case .whiteNoise: "White noise"
        }
    }

    var detail: String {
        switch self {
        case .off: "Silence"
        case .lofi: "Soft keys and a lazy beat"
        case .brownNoise: "Deep, like distant rain"
        case .whiteNoise: "Bright, masks chatter"
        }
    }
}

struct AppPreferences: Codable, Equatable, Sendable {
    /// Haptics: vsechny vibrace (tlacitka, vysledky bitvy, alarm pri zvednuti telefonu).
    var isHapticsEnabled = true
    var isMusicEnabled = true
    /// Tap sounds: klik pri klepnuti na tlacitka a ovladaci prvky.
    /// (Klic v ulozenych datech zustava "isSFXEnabled" kvuli starsim verzim.)
    var isSFXEnabled = true
    /// Reward sounds: mince, XP, level up. (Klic "isAchievementSoundEnabled" kvuli starsim verzim.)
    var isAchievementSoundEnabled = true
    /// Alarm sound: pipani pri zvednuti telefonu. Vypnuto = telefon jen vibruje.
    var isAlarmSoundEnabled = true
    /// Daily reminder v 17:00, kdyz se ten den jeste nebojovalo.
    var isDailyReminderEnabled = false
    /// Notifikace "Battle finished" na konci odpoctu.
    var isBattleDoneNotificationEnabled = true
    /// Notifikace "Break is over" na konci 5minutove prestavky.
    var isBreakOverNotificationEnabled = true
    var ambientVolume = 0.55
    var selectedTrack: AmbientTrack = .calmCurrents
    var soundscape: Soundscape = .lofi
    /// Pocet porazenych uzlu na ceste kazdeho sveta (rawValue sveta -> pocet). Dalsi uzel je odemceny.
    var clearedNodesByWorld: [String: Int] = [:]
    /// Naposledy zvoleny predmet, aby ho hrac nemusel vybirat pred kazdou bitvou znovu.
    var lastSubject: StudySubject?
    var lastBossID: String?
    /// Predmety hrace v pevnem poradi (poradi cipu ve Fight sheetu), vcetne skrytych a smazanych.
    var subjects: [SubjectEntry] = StudySubject.defaults.map { SubjectEntry(subject: $0) }
    /// Battle sounds: utok, zasah, vitezstvi, utek bosse a konec prestavky.
    var isBattleSoundEnabled = true
    /// Hlasitost zvukovych efektu 0...1 (hudba bitvy ma vlastni ambientVolume).
    var effectsVolume = 0.8

    enum CodingKeys: String, CodingKey {
        case isHapticsEnabled, isMusicEnabled, isSFXEnabled, ambientVolume, selectedTrack, soundscape, clearedNodesByWorld, lastSubject, lastBossID, subjects
        case isAchievementSoundEnabled, isAlarmSoundEnabled, isDailyReminderEnabled, isBattleDoneNotificationEnabled, isBreakOverNotificationEnabled
        case isBattleSoundEnabled, effectsVolume
    }

    /// Zvuk bitvy jako jedna volba: Off vypne hudbu, ostatni zapnou a vyberou zanr.
    var battleSound: BattleSound {
        get {
            guard isMusicEnabled else { return .off }
            switch soundscape {
            case .lofi: return .lofi
            case .brownNoise: return .brownNoise
            case .whiteNoise: return .whiteNoise
            }
        }
        set {
            switch newValue {
            case .off: isMusicEnabled = false
            case .lofi: isMusicEnabled = true; soundscape = .lofi
            case .brownNoise: isMusicEnabled = true; soundscape = .brownNoise
            case .whiteNoise: isMusicEnabled = true; soundscape = .whiteNoise
            }
        }
    }

    /// Kolik ze 4 zvukovych prepinacu (klepnuti, bitva, odmeny, alarm) je zapnuto.
    var soundEffectsOnCount: Int { [isSFXEnabled, isBattleSoundEnabled, isAchievementSoundEnabled, isAlarmSoundEnabled].filter { $0 }.count }

    /// Predmet, ktery se ma ve Fight sheetu predvybrat: naposledy pouzity, pokud je videt, jinak prvni viditelny.
    var preselectedSubject: StudySubject? {
        let visible = subjects.visibleSubjects
        if let last = lastSubject, let match = visible.first(where: { $0 == last }) { return match }
        return visible.first
    }

    /// Kolik uzlu sveta uz hrac porazil.
    func clearedNodes(in world: BossWorld) -> Int {
        min(world.bosses.count, max(0, clearedNodesByWorld[world.rawValue] ?? 0))
    }

    /// Porazeni uzlu na rade posune cestu o krok dal; vyhra nad jinym uzlem postup nemeni
    /// (na Path si hrac muze vybrat kohokoli, "2 / 4 cleared" pocita jen souvislou radu od zacatku).
    mutating func markCleared(_ boss: Boss) {
        // Rozcvicka nepatri do zadneho sveta a cestu nikdy neposouva.
        guard !boss.isWarmUp else { return }
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
        isAchievementSoundEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isAchievementSoundEnabled)) ?? fallback.isAchievementSoundEnabled
        isAlarmSoundEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isAlarmSoundEnabled)) ?? fallback.isAlarmSoundEnabled
        isDailyReminderEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isDailyReminderEnabled)) ?? fallback.isDailyReminderEnabled
        isBattleDoneNotificationEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isBattleDoneNotificationEnabled)) ?? fallback.isBattleDoneNotificationEnabled
        isBreakOverNotificationEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isBreakOverNotificationEnabled)) ?? fallback.isBreakOverNotificationEnabled
        // Starsi verze mely jeden prepinac "Tap and battle sounds"; bitevni zvuky prevezmou jeho hodnotu.
        isBattleSoundEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isBattleSoundEnabled)) ?? isSFXEnabled
        effectsVolume = min(1, max(0, (try? container.decodeIfPresent(Double.self, forKey: .effectsVolume)) ?? fallback.effectsVolume))
        // Starsi verze mely vlastni delku bitvy (bossMinutes, bossMinutesByID); ta se zamerne zahodi.
        clearedNodesByWorld = (try? container.decodeIfPresent([String: Int].self, forKey: .clearedNodesByWorld)) ?? [:]
        lastSubject = try? container.decodeIfPresent(StudySubject.self, forKey: .lastSubject)
        lastBossID = try? container.decodeIfPresent(String.self, forKey: .lastBossID)
        if let stored = try? container.decodeIfPresent([SubjectEntry].self, forKey: .subjects) {
            subjects = stored
        } else if let last = lastSubject, !fallback.subjects.contains(where: { $0.id == last.id }) {
            // Starsi verze nemely seznam predmetu; naposledy pouzity predmet v nem nesmi chybet.
            subjects = fallback.subjects + [SubjectEntry(subject: last)]
        } else {
            subjects = fallback.subjects
        }
    }
}
