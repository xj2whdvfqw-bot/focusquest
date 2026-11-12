import Foundation

@MainActor
protocol PreferencesStoreProtocol: AnyObject {
    func load() -> AppPreferences
    func save(_ preferences: AppPreferences)
    func reset()
}

@MainActor
final class PreferencesStore: PreferencesStoreProtocol {
    private let defaults: UserDefaults
    private let key = "focusquest.sensory-preferences"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> AppPreferences {
        guard let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(AppPreferences.self, from: data) else { return AppPreferences() }
        return value
    }

    func save(_ preferences: AppPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }

    func reset() { defaults.removeObject(forKey: key) }
}

enum AntiCheatRules {
    static func warningDuration(equippedLootIDs: [String], graceAlreadyUsed: Bool) -> Int {
        5 + (equippedLootIDs.contains("chronos-shield") && !graceAlreadyUsed ? 1 : 0)
    }

    static func clockIsTampered(wallDelta: TimeInterval, monotonicDelta: TimeInterval, tolerance: TimeInterval = 2) -> Bool {
        !wallDelta.isFinite || !monotonicDelta.isFinite || abs(wallDelta - monotonicDelta) > tolerance
    }
}