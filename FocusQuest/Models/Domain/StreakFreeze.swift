import Foundation

/// C2: Streak freeze. Hrac ho koupi v Shopu (150 minci, v zasobe nejvys 2). Kdyz vynecha den, freeze
/// se spotrebuje automaticky (pri dalsim otevreni appky) a serie nespadne. Zamrzle dny jsou v profilu
/// (`UserProfile.frozenDays`) a v Habits maji ikonku ledu.
enum StreakFreeze {
    static let price = 150
    static let maxOwned = 2

    /// Ktere vynechane dny maji zamrznout, aby serie nespadla. Prazdne pole = nic (zadna mezera,
    /// serie uz neni co zachranit, nebo na mezeru nestaci zasoba; pak se freeze nespotrebuje).
    /// Dnesek se nikdy nezmrazi (hrac jeste muze bojovat).
    static func daysToFreeze(stats: PlayerStats, frozenDayKeys: Set<String>, available: Int, now: Date = Date(), calendar: Calendar = .current) -> [String] {
        guard available > 0 else { return [] }
        let focus = stats.focusDayKeys(calendar: calendar)
        guard !focus.isEmpty else { return [] }
        func key(_ date: Date) -> String { PlayerStats.dayKey(date, calendar: calendar) }
        let today = calendar.startOfDay(for: now)
        guard var day = calendar.date(byAdding: .day, value: -1, to: today) else { return [] }
        var missing: [String] = []
        // Od vcerejska zpet: sbirej dny bez bitvy, dokud nenarazis na aktivni den.
        while !(focus.contains(key(day)) || frozenDayKeys.contains(key(day))) {
            missing.append(key(day))
            guard missing.count <= available, let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return [] }
            day = previous
        }
        guard !missing.isEmpty else { return [] }
        // Aktivni den pred mezerou musi byt soucasti serie (aspon jeden den s bitvou).
        guard stats.currentStreak(frozenDayKeys: frozenDayKeys, now: day, calendar: calendar) > 0 else { return [] }
        return missing
    }

    /// Je v aktualni serii za poslednich 7 dni zamrzly den? (Home ukaze ikonku ledu.)
    static func recentlyFrozen(frozenDayKeys: Set<String>, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let today = calendar.startOfDay(for: now)
        return (1...7).contains { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
            return frozenDayKeys.contains(PlayerStats.dayKey(day, calendar: calendar))
        }
    }
}
