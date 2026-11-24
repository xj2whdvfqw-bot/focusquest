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
    private let key = AppStateStore.preferencesKey

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> AppPreferences {
        guard let data = defaults.data(forKey: key) else { return AppPreferences() }
        guard let value = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            // Predmety a nastaveni nejdou nacist: puvodni data se ulozi stranou, nez je prepise vychozi stav.
            StoredDataBackup.preserve(data, key: key, in: defaults)
            return AppPreferences()
        }
        return value
    }

    func save(_ preferences: AppPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
        AppStateStore.touch(defaults)
    }

    func reset() {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: StoredDataBackup.key(for: key))
    }
}

enum AntiCheatRules {
    /// Kolik sekund ma hrac na polozeni zvednuteho telefonu.
    static let warningSeconds = 10

    static func clockIsTampered(wallDelta: TimeInterval, monotonicDelta: TimeInterval, tolerance: TimeInterval = 2) -> Bool {
        !wallDelta.isFinite || !monotonicDelta.isFinite || abs(wallDelta - monotonicDelta) > tolerance
    }
}