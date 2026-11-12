import Combine
import Foundation

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var stats: PlayerStats = .initial
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let profileSync: any ProfileSyncServiceProtocol

    init(profileSync: any ProfileSyncServiceProtocol) { self.profileSync = profileSync }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { stats = try await profileSync.loadStats(); errorMessage = nil }
        catch { errorMessage = "Verified progression is unavailable." }
    }

    func replace(with value: PlayerStats) { stats = value }
}