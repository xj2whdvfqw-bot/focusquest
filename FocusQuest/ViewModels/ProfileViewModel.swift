import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile
    @Published private(set) var isSaving = false
    @Published private(set) var todayVerifiedMinutes = 0
    @Published var errorMessage: String?
    private let sync: any ProfileSyncServiceProtocol

    init(profile: UserProfile, sync: any ProfileSyncServiceProtocol) { self.profile = profile; self.sync = sync }

    func updateUsername(_ value: String) {
        guard (3...20).contains(value.count), value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { errorMessage = "Use 3-20 letters or numbers."; return }
        profile.username = value
        errorMessage = nil
        save()
    }

    func updateTitle(_ value: String) { profile.title = value; save() }
    func updateHeroClass(_ value: HeroClass) { profile.heroClass = value; save() }
    func updateDailyGoal(_ value: Int) { profile.dailyFocusGoalMinutes = min(240, max(15, value)); save() }

    func unlockLoot(_ item: LootItem?) {
        guard let item, !profile.unlockedLootIDs.contains(item.id) else { return }
        profile.unlockedLootIDs.append(item.id)
        save()
    }

    func toggleLoot(_ id: String) {
        if profile.equippedLootIDs.contains(id) { profile.equippedLootIDs.removeAll { $0 == id } }
        else if profile.equippedLootIDs.count < 2 && profile.unlockedLootIDs.contains(id) { profile.equippedLootIDs.append(id) }
        save()
    }

    func refresh() async {
        do { profile = try await sync.loadProfile() } catch { errorMessage = "Profile sync is unavailable." }
    }

    func refreshProgress() async {
        do {
            let stats = try await sync.loadStats()
            todayVerifiedMinutes = stats.sessionHistory.filter { Calendar.current.isDateInToday($0.completedAt) }.reduce(0) { $0 + $1.verifiedMinutes }
        } catch { errorMessage = "Verified daily progress is unavailable." }
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