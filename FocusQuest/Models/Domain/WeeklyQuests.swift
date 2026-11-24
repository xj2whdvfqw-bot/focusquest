import Foundation

/// C5: tydenni ukoly. Kazde pondeli 3 nove, generovane lokalne z historie (zadny server).
/// Obtiznost podle prumeru poslednich 4 tydnu pred timto pondelim, takze se behem tydne nemeni.
/// Za kazdy splneny ukol truhla s mincemi (`reward`), vyzvedne se klepnutim.
struct WeeklyQuest: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case beatBosses, focusMinutes, focusDays, focusAreas, longBattle
    }

    let kind: Kind
    let target: Int
    let reward: Int
    /// Tyden (pondeli "2026-11-23") + druh: stejny ukol ma vzdy stejne id.
    let id: String

    var title: String {
        switch kind {
        case .beatBosses: "Beat \(target) \(target == 1 ? "boss" : "bosses")"
        case .focusMinutes: "Focus \(target) min"
        case .focusDays: "Focus on \(target) different days"
        case .focusAreas: "Focus on \(target) different areas"
        case .longBattle: "Win a \(target) min battle"
        }
    }

    var symbol: String {
        switch kind {
        case .beatBosses: "crown.fill"
        case .focusMinutes: "clock.fill"
        case .focusDays: "calendar"
        case .focusAreas: "square.grid.2x2.fill"
        case .longBattle: "hourglass"
        }
    }

    /// Postup v tydnu (0 … target).
    func progress(in week: [SessionSummary], calendar: Calendar = .current) -> Int {
        let value: Int = switch kind {
        case .beatBosses: week.filter { $0.isQuick != true }.count
        case .focusMinutes: week.reduce(0) { $0 + max(0, $1.verifiedMinutes) }
        case .focusDays: Set(week.map { calendar.startOfDay(for: $0.completedAt) }).count
        case .focusAreas: Set(week.compactMap { $0.subject?.id }).count
        case .longBattle: week.contains { $0.verifiedMinutes >= target } ? target : 0
        }
        return min(target, value)
    }
}

enum WeeklyQuests {
    /// Mince za jeden splneny ukol; tezsi ukol dava vic.
    static let baseReward = 40

    /// Pondeli tydne s `date` (stejne jako sloupce Habits).
    static func weekStart(_ date: Date, calendar: Calendar = .current) -> Date {
        HabitGrid.weekStart(of: date, calendar: calendar)
    }

    static func weekKey(_ date: Date, calendar: Calendar = .current) -> String {
        PlayerStats.dayKey(weekStart(date, calendar: calendar), calendar: calendar)
    }

    /// Bitvy tohoto tydne (od pondeli).
    static func sessions(in history: [SessionSummary], weekOf date: Date, calendar: Calendar = .current) -> [SessionSummary] {
        let start = weekStart(date, calendar: calendar)
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return [] }
        return history.filter { $0.completedAt >= start && $0.completedAt < end }
    }

    /// 3 ukoly tydne. Vzdy minuty a dny, treti se stridá (bossove, oblasti, dlouha bitva).
    static func make(history: [SessionSummary], now: Date = Date(), calendar: Calendar = .current) -> [WeeklyQuest] {
        let start = weekStart(now, calendar: calendar)
        let key = PlayerStats.dayKey(start, calendar: calendar)
        // Prumer poslednich 4 tydnu pred timto pondelim (tydny bez bitev se pocitaji jako nula,
        // ale jen od prvni bitvy, aby novacek nemel nulove cile).
        let past = (1...4).compactMap { calendar.date(byAdding: .day, value: -7 * $0, to: start) }
        let firstBattle = history.map(\.completedAt).min()
        var weekCount = 0
        var totalMinutes = 0
        var totalDays = 0
        var totalBattles = 0
        for week in past {
            guard let firstBattle, let weekEnd = calendar.date(byAdding: .day, value: 7, to: week), weekEnd > firstBattle else { continue }
            let list = sessions(in: history, weekOf: week, calendar: calendar)
            weekCount += 1
            totalMinutes += list.reduce(0) { sum, session in sum + max(0, session.verifiedMinutes) }
            totalDays += Set(list.map { calendar.startOfDay(for: $0.completedAt) }).count
            totalBattles += list.filter { $0.isQuick != true }.count
        }
        let count = Double(max(1, weekCount))
        let avgMinutes = Double(totalMinutes) / count
        let avgDays = Double(totalDays) / count
        let avgBattles = Double(totalBattles) / count
        let areas = Set(history.compactMap { $0.subject?.id }).count

        // O kousek vic nez obvykle, zaokrouhleno; novacek ma male cile.
        let minutes = clamp(Int((avgMinutes * 1.15 / 15).rounded()) * 15, 60, 600)
        let days = clamp(Int(avgDays.rounded()) + 1, 3, 7)
        let bosses = clamp(Int(avgBattles.rounded()) + 1, 2, 12)

        let third: (WeeklyQuest.Kind, Int)
        let rotation = (calendar.component(.weekOfYear, from: start) + calendar.component(.yearForWeekOfYear, from: start)) % 3
        switch rotation {
        case 0: third = (.beatBosses, bosses)
        case 1 where areas >= 2: third = (.focusAreas, min(3, areas))
        default: third = (.longBattle, avgMinutes >= 150 ? 30 : 20)
        }
        return [
            quest(.focusMinutes, minutes, key: key, difficulty: Double(minutes) / 120),
            quest(.focusDays, days, key: key, difficulty: Double(days) / 4),
            quest(third.0, third.1, key: key, difficulty: third.0 == .beatBosses ? Double(third.1) / 4 : 1),
        ]
    }

    private static func quest(_ kind: WeeklyQuest.Kind, _ target: Int, key: String, difficulty: Double) -> WeeklyQuest {
        // 40 minci za bezny ukol, az 100 za tezsi (zaokrouhleno na 10).
        let reward = clamp(Int((Double(baseReward) * max(1, difficulty) / 10).rounded()) * 10, baseReward, 100)
        return WeeklyQuest(kind: kind, target: target, reward: reward, id: "\(key).\(kind.rawValue)")
    }

    private static func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int { min(high, max(low, value)) }
}
