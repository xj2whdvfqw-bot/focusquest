import Foundation

struct SessionSummary: Identifiable, Codable, Sendable {
    let id: UUID
    var bossName: String
    let verifiedMinutes: Int
    let xpEarned: Int
    let completedAt: Date
    let flawless: Bool
    /// Predmet bitvy; starsi zaznamy ho nemaji.
    var subject: StudySubject? = nil
    /// ID bosse pro Bestiar; starsi zaznamy ho nemaji.
    var bossID: String? = nil
    /// Rychla 5minutova bitva ("Just 5 minutes"). Nil = zaznam ze starsi verze, jeste neoznaceny.
    var isQuick: Bool? = nil
    /// C6: volitelna poznamka po vyhre ("What did you get done?"), jeden radek.
    var note: String? = nil

    /// Nejdelsi poznamka (znaku).
    static let noteLimit = 120
}

/// Jeden radek Bestiare: kolikrat hrac porazil daneho bosse pri danem predmetu.
struct BestiaryEntry: Identifiable, Codable, Equatable, Sendable {
    let bossID: String
    var bossName: String
    let subject: StudySubject?
    var defeats: Int

    var id: String { "\(subject?.id ?? "none")|\(bossID)" }
}

/// Porazeni bossove jednoho predmetu, serazeni od nejcastejsiho.
struct BestiaryGroup: Identifiable, Equatable, Sendable {
    let subject: StudySubject?
    let entries: [BestiaryEntry]

    var id: String { subject?.id ?? "none" }
    var totalDefeats: Int { entries.reduce(0) { $0 + $1.defeats } }

    /// Skupiny podle predmetu: nejvic porazenych nahore, bitvy bez predmetu na konci.
    static func groups(from entries: [BestiaryEntry]) -> [BestiaryGroup] {
        var bySubject: [String: [BestiaryEntry]] = [:]
        for entry in entries where entry.defeats > 0 {
            bySubject[entry.subject?.id ?? "none", default: []].append(entry)
        }
        let groups: [BestiaryGroup] = bySubject.values.map { list in
            let sorted = list.sorted { left, right in
                left.defeats == right.defeats ? left.bossName < right.bossName : left.defeats > right.defeats
            }
            return BestiaryGroup(subject: sorted[0].subject, entries: sorted)
        }
        return groups.sorted { left, right in
            if (left.subject == nil) != (right.subject == nil) { return left.subject != nil }
            if left.totalDefeats != right.totalDefeats { return left.totalDefeats > right.totalDefeats }
            return left.id < right.id
        }
    }
}

struct PlayerStats: Codable, Sendable {
    var level: Int
    var totalXP: Int
    var wins: Int
    var battles: Int
    var streakDays: Int
    var totalHPDealt: Int
    var sessionHistory: [SessionSummary]
    /// Porazeni bossove podle predmetu. Uklada se spolu se statistikami (UserDefaults).
    var bestiary: [BestiaryEntry] = []

    var winRate: Double { battles > 0 ? Double(wins) / Double(battles) : 0 }
    var xpIntoLevel: Int { totalXP % 1000 }
    var xpForNextLevel: Int { 1000 }

    static let initial = PlayerStats(level: 1, totalXP: 0, wins: 0, battles: 0, streakDays: 0, totalHPDealt: 0, sessionHistory: [])

    enum CodingKeys: String, CodingKey {
        case level, totalXP, wins, battles, streakDays, totalHPDealt, sessionHistory, bestiary
    }
}

extension PlayerStats {
    // Statistiky ze starsi verze Bestiar nemaji; bez tohohle by se cele zahodily.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        level = try container.decode(Int.self, forKey: .level)
        totalXP = try container.decode(Int.self, forKey: .totalXP)
        wins = try container.decode(Int.self, forKey: .wins)
        battles = try container.decode(Int.self, forKey: .battles)
        streakDays = try container.decode(Int.self, forKey: .streakDays)
        totalHPDealt = try container.decode(Int.self, forKey: .totalHPDealt)
        sessionHistory = try container.decode([SessionSummary].self, forKey: .sessionHistory)
        bestiary = (try? container.decodeIfPresent([BestiaryEntry].self, forKey: .bestiary)) ?? []
        excludeLegacyQuickWins()
        retireRemovedBosses()
        // Starsi verze ukladaly i heroHP, bestCombo a lastQuestFailedAt (ustup mazal serii).
        // Nic z toho uz v appce neni, klice se pri cteni ignoruji a serie z nich nikdy nespadne.
    }
}

extension PlayerStats {
    static let xpPerLevel = 1000

    /// Pripocte dokoncenou bitvu: XP, level, vyhry, historii, Bestiar a serii dni.
    mutating func record(_ summary: SessionSummary, bossDefeated: Bool, calendar: Calendar = .current) {
        let previousDay = sessionHistory.first?.completedAt
        battles += 1
        if bossDefeated {
            wins += 1
            recordDefeat(bossID: summary.bossID ?? summary.bossName, bossName: summary.bossName, subject: summary.subject)
        }
        totalXP += max(0, summary.xpEarned)
        level = max(1, totalXP / Self.xpPerLevel + 1)
        totalHPDealt += max(0, summary.verifiedMinutes)
        sessionHistory.insert(summary, at: 0)

        if let previousDay {
            if calendar.isDate(previousDay, inSameDayAs: summary.completedAt) {
                streakDays = max(1, streakDays)
            } else if let dayAfter = calendar.date(byAdding: .day, value: 1, to: previousDay), calendar.isDate(dayAfter, inSameDayAs: summary.completedAt) {
                streakDays += 1
            } else {
                streakDays = 1
            }
        } else {
            streakDays = 1
        }
    }

    // MARK: - Serie

    /// Serie, ktera plati dnes: kdyz hrac vcera ani dnes nebojoval, uz neplati.
    /// Od J1 (C2, C7) se serie pocita z historie dni, ne z ulozeneho pocitadla: pocet po sobe jdoucich dni
    /// s bitvou, ktera konci dneskem nebo vcerejskem. Dny zachranene Streak freeze (`frozenDayKeys`) radu
    /// nepreruseji, ale do poctu se nepocitaji.
    func currentStreak(frozenDayKeys: Set<String> = [], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let focus = focusDayKeys(calendar: calendar)
        guard !focus.isEmpty else { return 0 }
        var day = calendar.startOfDay(for: now)
        func key(_ date: Date) -> String { Self.dayKey(date, calendar: calendar) }
        func isActive(_ date: Date) -> Bool { focus.contains(key(date)) || frozenDayKeys.contains(key(date)) }
        // Dnes jeste bez bitvy: serie plati od vcerejska.
        if !isActive(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        var steps = 0
        while isActive(day), steps < 3_650 {
            if focus.contains(key(day)) { count += 1 }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
            steps += 1
        }
        return count
    }

    /// Dny s aspon jednou bitvou ("2026-11-23").
    func focusDayKeys(calendar: Calendar = .current) -> Set<String> {
        Set(sessionHistory.map { Self.dayKey($0.completedAt, calendar: calendar) })
    }

    /// Den ve tvaru "2026-11-23" (oslava serie se pamatuje po dnech).
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// 2D: oslava serie na Home. Plati, kdyz dnes uz probehla bitva (prvni dnesni serii zvysila),
    /// serie plati a dnes jeste oslava nebyla (`lastCelebratedDay` = dayKey posledni oslavy).
    func isStreakCelebrationDue(lastCelebratedDay: String, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let last = sessionHistory.first?.completedAt,
              calendar.isDate(last, inSameDayAs: now),
              currentStreak(now: now, calendar: calendar) > 0 else { return false }
        return lastCelebratedDay != Self.dayKey(now, calendar: calendar)
    }

    /// Overene minuty po dnech za poslednich `days` dni, od nejstarsiho po dnesek.
    func dailyFocusMinutes(days: Int = 7, now: Date = Date(), calendar: Calendar = .current) -> [DailyFocus] {
        let today = calendar.startOfDay(for: now)
        let starts = (0..<max(1, days)).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        var minutesByDay: [Date: Int] = [:]
        for session in sessionHistory {
            minutesByDay[calendar.startOfDay(for: session.completedAt), default: 0] += max(0, session.verifiedMinutes)
        }
        return starts.map { DailyFocus(day: $0, minutes: minutesByDay[$0] ?? 0) }
    }

    /// Trvale smazani predmetu po 24 h: zmizi jeho bitvy z historie i z Bestiare.
    /// XP, level, pocet vyher a serie zustavaji (hrac si je vybojoval).
    mutating func removeSubjects(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        sessionHistory.removeAll { $0.subject.map { ids.contains($0.id) } ?? false }
        bestiary.removeAll { $0.subject.map { ids.contains($0.id) } ?? false }
    }

    /// Prida XP mimo bitvu (vyvojarske testovaci odmeny) a prepocita level.
    mutating func grantBonusXP(_ amount: Int) {
        totalXP += max(0, amount)
        level = max(1, totalXP / Self.xpPerLevel + 1)
    }

    /// Ladeni: nastavi level primo (XP na zacatek levelu). Bitvy a vyhry se nemeni.
    mutating func setLevel(_ target: Int) {
        let clamped = max(1, target)
        totalXP = (clamped - 1) * Self.xpPerLevel
        level = clamped
    }

    // MARK: - Odznaky na Path

    /// Vyhry nad bossy cest (id -> pocet) pro odznak "✓ N×". Rozcvicka (Warm-up Wisp) se nepocita.
    var pathWins: [String: Int] {
        bestiary.reduce(into: [:]) { result, entry in
            guard let boss = Boss.find(entry.bossID), !boss.isWarmUp else { return }
            result[boss.id, default: 0] += entry.defeats
        }
    }

    /// Porazeni bossove cest celkem (metrika Bosses beaten ve Stats); rozcvicka se nepocita.
    var bossesBeaten: Int { pathWins.values.reduce(0, +) }

    /// Starsi verze pocitaly rychlou 5minutovou bitvu proti bossovi z Path a pripsaly mu odznak.
    /// Takove zaznamy se oznaci jako rychle a jejich vyhra se z Bestiare (a tedy z odznaku) odecte.
    /// Bossove cest trvaji aspon 10 minut, takze 5minutova vyhra nad nimi byla vzdy rychla bitva.
    /// Bezi jen pro neoznacene zaznamy, takze opakovane nacteni nic neodecte dvakrat.
    mutating func excludeLegacyQuickWins() {
        for index in sessionHistory.indices where sessionHistory[index].isQuick == nil {
            let session = sessionHistory[index]
            let pathBoss = Boss.find(session.bossID).flatMap { $0.isWarmUp ? nil : $0 }
            let wasQuick = pathBoss != nil && session.verifiedMinutes == Boss.quickBattleMinutes
            sessionHistory[index].isQuick = wasQuick
            guard wasQuick, let rawID = session.bossID else { continue }
            let matches = bestiary.indices.filter { bestiary[$0].bossID == rawID && bestiary[$0].defeats > 0 }
            guard let entry = matches.first(where: { bestiary[$0].subject == session.subject }) ?? matches.first else { continue }
            bestiary[entry].defeats -= 1
        }
        bestiary.removeAll { $0.defeats <= 0 }
    }

    /// Jmeno bosse ze starsi verze, ktery uz v appce neni (zaznam si necha minuty, XP a predmet).
    static let retiredBossName = "Retired boss"
    static let retiredBossID = "retired"

    /// Bossove, kteri uz v appce nejsou (odstranene svety a stara id), se v historii a Bestiari
    /// prejmenuji na "Retired boss" a jejich radky v Bestiari se slouci po predmetech.
    /// Odznaky na mape je nepocitaji (pathWins zna jen existujici bosse).
    mutating func retireRemovedBosses() {
        let knownNames = Set(Boss.allBosses.map(\.name))
        for index in sessionHistory.indices {
            let session = sessionHistory[index]
            let known = session.bossID.map { Boss.find($0) != nil } ?? knownNames.contains(session.bossName)
            if !known {
                sessionHistory[index].bossName = Self.retiredBossName
                if session.bossID != nil { sessionHistory[index].bossID = Self.retiredBossID }
            }
        }
        var merged: [BestiaryEntry] = []
        for entry in bestiary {
            guard Boss.find(entry.bossID) == nil else { merged.append(entry); continue }
            if let index = merged.firstIndex(where: { $0.bossID == Self.retiredBossID && $0.subject == entry.subject }) {
                merged[index].defeats += entry.defeats
            } else {
                merged.append(BestiaryEntry(bossID: Self.retiredBossID, bossName: Self.retiredBossName, subject: entry.subject, defeats: entry.defeats))
            }
        }
        bestiary = merged
    }

    private mutating func recordDefeat(bossID: String, bossName: String, subject: StudySubject?) {
        if let index = bestiary.firstIndex(where: { $0.bossID == bossID && $0.subject == subject }) {
            bestiary[index].defeats += 1
            bestiary[index].bossName = bossName
        } else {
            bestiary.append(BestiaryEntry(bossID: bossID, bossName: bossName, subject: subject, defeats: 1))
        }
    }
}

/// Vyplata za vyhranou bitvu: minuta overeneho soustredeni = 12 XP a 3 mince.
/// Utek bosse dava 0 (o to se stara volajici); mince se nikdy neberou.
enum RewardRules {
    static let xpPerVerifiedMinute = 12
    static let coinsPerVerifiedMinute = 3

    static func xp(verifiedMinutes: Int) -> Int { max(0, verifiedMinutes) * xpPerVerifiedMinute }
    static func coins(verifiedMinutes: Int) -> Int { max(0, verifiedMinutes) * coinsPerVerifiedMinute }
}

extension PlayerStats {
    /// Nejdelsi rada po sobe jdoucich dni s aspon jednou bitvou ("Longest streak").
    func longestStreak(calendar: Calendar = .current) -> Int {
        let days = Set(sessionHistory.map { calendar.startOfDay(for: $0.completedAt) }).sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for day in days {
            if let previous, let next = calendar.date(byAdding: .day, value: 1, to: previous), calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }
}

/// Ctverecek Habits mrizky: jeden den a jeho overene minuty.
struct HabitDay: Identifiable, Equatable, Sendable {
    let date: Date
    let minutes: Int
    let isToday: Bool
    let isFuture: Bool
    /// Den pred prvnim dnem pouzivani appky (zacatek prvniho tydne): ctverecek se nekresli.
    var isBeforeStart = false
    /// C2: den zachraneny Streak freeze (ikonka ledu).
    var isFrozen = false

    var id: Date { date }

    /// Sytost barvy 0–4 podle minut (0, pod 25, pod 50, pod 90, 90+), stejne jako v prototypu.
    var level: Int { HabitGrid.level(forMinutes: minutes) }
}

/// Habits mrizka ve Stats (C0): pevna, nic se neposouva.
/// - Radky jsou pevne dny v tydnu shora dolu: pondeli az nedele.
/// - Sloupce jsou tydny; sloupec 0 je tyden prvniho dne pouzivani appky, dalsi tydny doprava.
/// - Dny pred prvnim dnem (v prvnim tydnu) se nekresli, dny po dnesku jsou prazdne (`isFuture`).
/// - Dnesek se kazdy den posune o ctverecek dal (dolu, na konci tydne nahoru do dalsiho sloupce).
struct HabitGrid: Equatable, Sendable {
    let weeks: [[HabitDay]]
    /// Pismena radku: vzdy M, T, W, T, F, S, S.
    var rowLetters: [String] = HabitGrid.weekdayLetters
    /// Sloupec s dneskem (podle nej se mrizka pri otevreni posune).
    var todayWeek: Int = 0

    static let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    /// Aspon tolik sloupcu, at mrizka nevypada prazdne; dalsi tydny prodlouzi mrizku doprava.
    static let minimumWeeks = 15

    /// Kolik dni ma aspon minutu soustredeni.
    var focusDays: Int { weeks.joined().filter { $0.minutes > 0 }.count }

    static func level(forMinutes minutes: Int) -> Int {
        switch minutes {
        case ...0: 0
        case ..<25: 1
        case ..<50: 2
        case ..<90: 3
        default: 4
        }
    }

    /// Pondeli tydne, ve kterem je `date`.
    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        // weekday: nedele = 1, pondeli = 2 … sobota = 7.
        let back = (calendar.component(.weekday, from: day) + 5) % 7
        return calendar.date(byAdding: .day, value: -back, to: day) ?? day
    }

    /// `firstDay` = prvni den pouzivani appky; kdyz je v historii starsi bitva, zacne se od ni.
    static func make(history: [SessionSummary], firstDay: Date? = nil, frozenDayKeys: Set<String> = [], minimumWeeks: Int = HabitGrid.minimumWeeks, now: Date = Date(), calendar: Calendar = .current) -> HabitGrid {
        let today = calendar.startOfDay(for: now)
        var minutesByDay: [Date: Int] = [:]
        for session in history {
            minutesByDay[calendar.startOfDay(for: session.completedAt), default: 0] += max(0, session.verifiedMinutes)
        }
        let earliest = ([firstDay].compactMap { $0 } + history.map(\.completedAt)).min() ?? today
        let start = min(calendar.startOfDay(for: earliest), today)
        let firstWeek = weekStart(of: start, calendar: calendar)
        let daysToToday = calendar.dateComponents([.day], from: firstWeek, to: today).day ?? 0
        let todayWeek = max(0, daysToToday / 7)
        let count = max(minimumWeeks, todayWeek + 1)
        let weeks = (0..<count).map { week in
            (0..<7).compactMap { offset -> HabitDay? in
                guard let date = calendar.date(byAdding: .day, value: week * 7 + offset, to: firstWeek) else { return nil }
                let day = calendar.startOfDay(for: date)
                return HabitDay(
                    date: day,
                    minutes: minutesByDay[day] ?? 0,
                    isToday: day == today,
                    isFuture: day > today,
                    isBeforeStart: day < start,
                    isFrozen: frozenDayKeys.contains(PlayerStats.dayKey(day, calendar: calendar))
                )
            }
        }
        return HabitGrid(weeks: weeks, todayWeek: todayWeek)
    }

    /// Poslednich `count` tydnu az po tyden s dneskem (mini Habits na obrazku ke sdileni).
    func recentWeeks(_ count: Int) -> HabitGrid {
        let end = min(weeks.count, todayWeek + 1)
        let start = max(0, end - count)
        return HabitGrid(weeks: Array(weeks[start..<end]), rowLetters: rowLetters, todayWeek: end - start - 1)
    }
}

/// Jeden sloupec tydenniho grafu soustredeni.
struct DailyFocus: Identifiable, Equatable, Sendable {
    let day: Date
    let minutes: Int

    var id: Date { day }
    var hours: Double { Double(minutes) / 60 }
}
