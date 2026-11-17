import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile
    @Published private(set) var isSaving = false
    @Published private(set) var todayVerifiedMinutes = 0
    @Published private(set) var stats: PlayerStats = .initial
    @Published var errorMessage: String?
    private let sync: any ProfileSyncServiceProtocol

    init(profile: UserProfile, sync: any ProfileSyncServiceProtocol) { self.profile = profile; self.sync = sync }

    func updateUsername(_ value: String) {
        guard (3...20).contains(value.count), value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { errorMessage = "Use 3-20 letters or numbers."; return }
        profile.username = value
        errorMessage = nil
        save()
    }

    func updateHeroClass(_ value: HeroClass) { profile.heroClass = value; save() }
    func updateDailyGoal(_ value: Int) { profile.dailyFocusGoalMinutes = min(240, max(15, value)); save() }

    // MARK: - Hrdina

    func updateAvatar(_ value: AvatarAppearance) {
        guard value != profile.avatar else { return }
        profile.avatar = value
        save()
    }

    /// Konec uvodni tvorby hrdiny; priste se uz nezobrazi.
    func completeHeroCreation() {
        guard !profile.hasCreatedHero else { return }
        profile.hasCreatedHero = true
        save()
    }

    // MARK: - Odmeny a hodnost

    var level: Int { stats.level }
    /// Hodnost se odvozuje z levelu, hrac si ji nevybira.
    var rank: HeroRank { HeroRank.current(forLevel: stats.level) }
    var nextRank: HeroRank? { HeroRank.next(afterLevel: stats.level) }

    /// Porazeny boss: mince, pocitadlo bossu a zapis do statistik.
    func recordVictory(_ victory: BattleVictory) {
        let defeated = victory.boss.isDefeated
        profile.coins += victory.coinsEarned
        if defeated { profile.bossesDefeated += 1 }
        save()
        let summary = SessionSummary(id: UUID(), bossName: victory.boss.name, verifiedMinutes: victory.verifiedMinutes, xpEarned: victory.xpEarned, completedAt: Date(), flawless: true, subject: victory.subject, bossID: victory.boss.id)
        Task {
            do { apply(stats: try await sync.recordBattle(summary, bossDefeated: defeated)) }
            catch { errorMessage = "Battle could not be added to your stats." }
        }
    }

    /// Cile z uvodu ("Stop scrolling" ...). Ukazuji se v Profilu.
    func updateFocusGoals(_ goals: Set<FocusGoal>) {
        profile.focusGoals = FocusGoal.allCases.filter { goals.contains($0) }
        save()
    }

    /// DOCASNE pro testovani: +10 000 minci a +5 000 XP, aby slo hned zkouset obchod.
    func addDevFunds() {
        profile.coins += Self.devFundsCoins
        save()
        Task {
            do { apply(stats: try await sync.addBonusXP(Self.devFundsXP)) }
            catch { errorMessage = "Dev XP could not be added." }
        }
    }

    static let devFundsCoins = 10_000
    static let devFundsXP = 5_000

    /// Statistiky zmenene vitezstvim nebo bonusem; posila je i obrazovce Statistik.
    var onStatsChanged: ((PlayerStats) -> Void)?

    private func apply(stats updated: PlayerStats) {
        stats = updated
        onStatsChanged?(updated)
        todayVerifiedMinutes = updated.sessionHistory.filter { Calendar.current.isDateInToday($0.completedAt) }.reduce(0) { $0 + $1.verifiedMinutes }
    }

    // MARK: - Obchod s vybavenim

    func owns(_ item: EquipmentItem) -> Bool { profile.ownedEquipmentIDs.contains(item.id) }
    func isEquipped(_ item: EquipmentItem) -> Bool { profile.avatar.equippedItemID(in: item.slot) == item.id }
    func canAfford(_ item: EquipmentItem) -> Bool { profile.coins >= item.price }

    /// Koupi predmet za mince a rovnou ho nasadi, aby byl hned videt na hrdinovi.
    func buy(_ item: EquipmentItem) {
        guard !owns(item), canAfford(item) else { return }
        profile.coins -= item.price
        profile.ownedEquipmentIDs.append(item.id)
        profile.avatar.equip(item.id, in: item.slot)
        save()
    }

    /// Nasadi koupeny predmet, nebo ho sundá, pokud uz je nasazeny.
    func toggleEquip(_ item: EquipmentItem) {
        guard owns(item) else { return }
        profile.avatar.equip(isEquipped(item) ? nil : item.id, in: item.slot)
        save()
    }

    func refresh() async {
        do { profile = try await sync.loadProfile() } catch { errorMessage = "Profile sync is unavailable." }
    }

    func refreshProgress() async {
        do {
            apply(stats: try await sync.loadStats())
        } catch { errorMessage = "Verified daily progress is unavailable." }
    }

    private func save() {
        // Ulozeny titul drzi krok s hodnosti (vidi ho server i sdileny vysledek bitvy).
        if stats.totalXP > 0 { profile.title = rank.title }
        let current = profile
        Task {
            isSaving = true
            defer { isSaving = false }
            do { try await sync.saveProfile(current) } catch { errorMessage = "Changes could not be synced." }
        }
    }
}