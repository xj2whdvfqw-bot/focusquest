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
        guard let name = UserProfile.cleanName(value) else { errorMessage = "Use 1-20 letters, numbers or spaces."; return }
        profile.username = name
        errorMessage = nil
        save()
    }

    /// Jmeno z onboardingu; prazdne nebo neplatne = "Hero".
    func updateDisplayName(_ value: String) {
        profile.username = UserProfile.cleanName(value) ?? "Hero"
        errorMessage = nil
        save()
    }

    /// Pozdrav na Home ("Hi, Adam"); nil, dokud si hrac jmeno nezadal.
    var greetingName: String? {
        profile.username == UserProfile.defaultUsername ? nil : profile.username
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

    // MARK: - Odmeny a level

    var level: Int { stats.level }

    /// Porazeny boss: mince, pocitadlo bossu a zapis do statistik.
    func recordVictory(_ victory: BattleVictory) {
        let defeated = victory.boss.isDefeated
        profile.coins += victory.coinsEarned
        if defeated { profile.bossesDefeated += 1 }
        save()
        let summary = SessionSummary(id: UUID(), bossName: victory.boss.name, verifiedMinutes: victory.verifiedMinutes, xpEarned: victory.xpEarned, completedAt: Date(), flawless: true, subject: victory.subject, bossID: victory.boss.id, isQuick: victory.boss.isWarmUp)
        lastVictorySessionID = summary.id
        Task {
            do { apply(stats: try await sync.recordBattle(summary, bossDefeated: defeated)) }
            catch { errorMessage = "Battle could not be added to your stats." }
        }
    }

    /// C6: bitva posledni vyhry (pro poznamku na obrazovce vitezstvi).
    @Published private(set) var lastVictorySessionID: UUID?

    /// C6: ulozi poznamku k posledni vyhre (prazdna = bez poznamky).
    func saveVictoryNote(_ text: String) {
        guard let id = lastVictorySessionID else { return }
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(SessionSummary.noteLimit))
        Task {
            do { apply(stats: try await sync.setNote(trimmed.isEmpty ? nil : trimmed, forSession: id)) }
            catch { errorMessage = "The note could not be saved." }
        }
    }

    /// Cile z uvodu ("Stop scrolling" ...). Ukazuji se v Profilu.
    func updateFocusGoals(_ goals: Set<FocusGoal>) {
        profile.focusGoals = FocusGoal.allCases.filter { goals.contains($0) }
        save()
    }

    // MARK: - Easter eggy

    /// Easter egg na mape: jen poprve pripise mince a ulozi, ze je nalezeny. Vraci false, kdyz uz byl nalezeny.
    @discardableResult
    func claimEasterEgg(_ egg: MapEasterEgg) -> Bool {
        guard !hasFound(egg) else { return false }
        profile.foundEasterEggs.append(egg.rawValue)
        profile.coins += egg.coins
        save()
        return true
    }

    func hasFound(_ egg: MapEasterEgg) -> Bool { profile.foundEasterEggs.contains(egg.rawValue) }

    #if DEBUG
    // MARK: - Ladeni (jen v Debug buildu, ne ve vydani)

    /// Debug: easter eggy jdou najit znovu (mince zustavaji).
    func debugResetEasterEggs() {
        profile.foundEasterEggs = []
        save()
    }

    func debugAddCoins(_ amount: Int) {
        profile.coins += amount
        save()
    }

    func debugResetCoins() {
        profile.coins = 0
        save()
    }

    func debugSetLevel(_ level: Int) {
        let target = max(1, level)
        Task {
            do { apply(stats: try await sync.setLevel(target)) }
            catch { errorMessage = "Level could not be changed." }
        }
    }
    #endif

    /// Predmety smazane pred vic nez 24 h: jejich bitvy zmizi i ze statistik.
    func removeSubjectStats(_ subjectIDs: Set<String>) async {
        guard !subjectIDs.isEmpty else { return }
        do { apply(stats: try await sync.removeSubjectStats(subjectIDs)) }
        catch { errorMessage = "Deleted items could not be removed from your stats." }
    }

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

    // MARK: - Extra pauzy (B2)

    var canBuyExtraPause: Bool {
        profile.extraPauses < UserProfile.maxExtraPauses && profile.coins >= UserProfile.extraPausePrice
    }

    /// Koupi jednu extra pauzu za 40 minci (drzet jde nejvys 5).
    func buyExtraPause() {
        guard canBuyExtraPause else { return }
        profile.coins -= UserProfile.extraPausePrice
        profile.extraPauses += 1
        save()
    }

    /// Bitva pouzila extra pauzu (vola ArenaViewModel pres AppDIContainer).
    func consumeExtraPause() {
        guard profile.extraPauses > 0 else { return }
        profile.extraPauses -= 1
        save()
    }

    func debugAddExtraPauses(_ amount: Int) {
        profile.extraPauses = min(UserProfile.maxExtraPauses, profile.extraPauses + amount)
        save()
    }

    // MARK: - Serie a Streak freeze (C0, C2)

    /// Dny zachranene Streak freeze.
    var frozenDayKeys: Set<String> { Set(profile.frozenDays) }

    /// Aktualni serie z historie dni (zamrzle dny ji nepreruseji).
    var currentStreak: Int { stats.currentStreak(frozenDayKeys: frozenDayKeys) }

    var canBuyStreakFreeze: Bool {
        profile.streakFreezes < StreakFreeze.maxOwned && profile.coins >= StreakFreeze.price
    }

    /// Koupi Streak freeze za 150 minci (v zasobe nejvys 2).
    func buyStreakFreeze() {
        guard canBuyStreakFreeze else { return }
        profile.coins -= StreakFreeze.price
        profile.streakFreezes += 1
        save()
    }

    /// Vynechane dny od posledni bitvy: kdyz na ne zasoba staci, freeze se spotrebuje a serie nespadne.
    /// Vraci pocet pouzitych freeze (0 = nic). Vola se pri spusteni a navratu do appky.
    @discardableResult
    func applyStreakFreezes(now: Date = Date()) -> Int {
        let days = StreakFreeze.daysToFreeze(stats: stats, frozenDayKeys: frozenDayKeys, available: profile.streakFreezes, now: now)
        guard !days.isEmpty else { return 0 }
        profile.streakFreezes -= days.count
        profile.frozenDays = Array(Set(profile.frozenDays).union(days)).sorted()
        save()
        return days.count
    }

    /// Prvni den pouzivani (sloupec 1 Habits). Stavajici hrac: den prvni bitvy, jinak dnesek.
    func ensureFirstUseDate() {
        let earliest = stats.sessionHistory.map(\.completedAt).min()
        if let current = profile.firstUseDate {
            // Starsi bitva nez ulozeny den (napr. obnovena data): mrizka zacne od ni.
            guard let earliest, earliest < current else { return }
            profile.firstUseDate = earliest
        } else {
            profile.firstUseDate = earliest ?? Date()
        }
        save()
    }

    func debugAddStreakFreeze() {
        profile.streakFreezes = min(StreakFreeze.maxOwned, profile.streakFreezes + 1)
        save()
    }

    // MARK: - Tydenni ukoly (C5)

    /// 3 ukoly tohoto tydne (z historie, stejne po cely tyden).
    var weeklyQuests: [WeeklyQuest] { WeeklyQuests.make(history: stats.sessionHistory) }

    /// Bitvy tohoto tydne (postup ukolu).
    var weekSessions: [SessionSummary] { WeeklyQuests.sessions(in: stats.sessionHistory, weekOf: Date()) }

    func isClaimed(_ quest: WeeklyQuest) -> Bool { profile.claimedQuests.contains(quest.id) }

    func isComplete(_ quest: WeeklyQuest) -> Bool { quest.progress(in: weekSessions) >= quest.target }

    /// Otevre truhlu splneneho ukolu: mince do profilu. Vraci pripsane mince (0 = nic).
    @discardableResult
    func claim(_ quest: WeeklyQuest) -> Int {
        guard isComplete(quest), !isClaimed(quest) else { return 0 }
        profile.coins += quest.reward
        // Jen poslednich ~5 tydnu (15 ukolu), at seznam neroste donekonecna.
        profile.claimedQuests = Array((profile.claimedQuests + [quest.id]).suffix(15))
        save()
        return quest.reward
    }

    // MARK: - Pozadi

    /// Pozadi, ktere si hrac prave zkousi (Preview). Neuklada se a po odchodu z obchodu zmizi.
    @Published var previewBackground: ShopBackground?

    /// Zvolene pozadi; nil = World scenes.
    var selectedBackground: ShopBackground? { profile.backgroundID.flatMap(ShopBackground.init(rawValue:)) }
    /// Co je prave videt za obrazovkami: nahled ma prednost pred zvolenym pozadim.
    var activeBackground: ShopBackground? { previewBackground ?? selectedBackground }

    func owns(_ background: ShopBackground) -> Bool { background.isFree || profile.ownedBackgroundIDs.contains(background.rawValue) }
    func canAfford(_ background: ShopBackground) -> Bool { profile.coins >= background.price }

    /// Pouzije vlastnene pozadi (nil = World scenes).
    func useBackground(_ background: ShopBackground?) {
        if let background, !owns(background) { return }
        previewBackground = nil
        profile.backgroundID = background?.rawValue
        save()
    }

    /// Koupi pozadi za mince a rovnou ho pouzije.
    func buy(_ background: ShopBackground) {
        guard !owns(background), canAfford(background) else { return }
        profile.coins -= background.price
        profile.ownedBackgroundIDs.append(background.rawValue)
        previewBackground = nil
        profile.backgroundID = background.rawValue
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

    /// Po Reset progress: nacte cerstvy profil a statistiky (hrdina znovu projde onboardingem).
    func reloadAfterReset() async {
        previewBackground = nil
        errorMessage = nil
        await refresh()
        await refreshProgress()
    }

    private func save() {
        let current = profile
        Task {
            isSaving = true
            defer { isSaving = false }
            do { try await sync.saveProfile(current) } catch { errorMessage = "Changes could not be synced." }
        }
    }
}