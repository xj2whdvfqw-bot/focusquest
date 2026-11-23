import Foundation

/// Prepinace funkci, ktere potrebuji placeny Apple Developer ucet (viz design/DEVELOPER_ACCOUNT_TODO.md).
/// Build vzdy projde i bez techto capabilities: kod je hotovy, ale vypnuty.
enum FeatureFlags {
    /// C1: sdileni dat appka ↔ widget pres App Group. Kdyz je zapnuty a App Group entitlement opravdu
    /// v aplikaci je (overuje se za behu), widget ukazuje skutecne hodnoty. Jinak ukazuje vyzvu "Open FocusQuest".
    static let appGroupWidgetSync = true
    /// C7: synchronizace pres iCloud Key-Value Store. Vychozi OFF; zapnout az s iCloud entitlementem.
    static let iCloudSync = false

    static let appGroupID = "group.com.focusquest.app"
}

/// C1: co widget ukazuje. Appka ho zapise po kazde zmene (bitva, navrat do appky); widget ho jen cte.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    var streak: Int
    var todayMinutes: Int
    var dailyGoalMinutes: Int
    var nextBossName: String?
    /// PixelSprite config bosse (StaticPixelSprite(sprite: .boss(id))).
    var nextBossSpriteID: String?
    var nextBossMinutes: Int?
    var nextBossWorld: String?
    var updatedAt: Date

    static let storageKey = "fq.widgetSnapshot"

    /// Ukazkova data (galerie widgetu, nahled v Debug).
    static let sample = WidgetSnapshot(streak: 7, todayMinutes: 35, dailyGoalMinutes: 60, nextBossName: "Procrasti-Hen", nextBossSpriteID: nil, nextBossMinutes: 20, nextBossWorld: "Farm", updatedAt: Date())

    /// Uloziste sdilene s widgetem: App Group, kdyz je v aplikaci opravdu k dispozici; jinak nil.
    /// Bez entitlementu vraci containerURL nil (UserDefaults(suiteName:) by tise ukladal jen do vlastniho kontejneru).
    static var sharedDefaults: UserDefaults? {
        guard FeatureFlags.appGroupWidgetSync,
              FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: FeatureFlags.appGroupID) != nil else { return nil }
        return UserDefaults(suiteName: FeatureFlags.appGroupID)
    }

    /// Je sdileni s widgetem aktivni (App Group je v aplikaci)?
    static var isSharingAvailable: Bool { sharedDefaults != nil }

    /// Posledni ulozeny snimek: ze sdileneho uloziste, v appce i z vlastniho (pro "Show streak").
    static func current() -> WidgetSnapshot {
        stored() ?? WidgetSnapshot(streak: 0, todayMinutes: 0, dailyGoalMinutes: 60, nextBossName: nil, nextBossSpriteID: nil, nextBossMinutes: nil, nextBossWorld: nil, updatedAt: Date())
    }

    static func stored() -> WidgetSnapshot? {
        for defaults in [sharedDefaults, UserDefaults.standard].compactMap({ $0 }) {
            if let data = defaults.data(forKey: storageKey), let value = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) {
                return value
            }
        }
        return nil
    }

    /// Ulozi snimek do vlastniho uloziste appky a, kdyz je, i do App Group pro widget.
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        Self.sharedDefaults?.set(data, forKey: Self.storageKey)
    }

    /// Serie plati jen do konce zitrka od posledniho zapisu; widget ji podle data sam vynuluje.
    func streak(at date: Date, calendar: Calendar = .current) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: updatedAt), to: calendar.startOfDay(for: date)).day ?? 0
        return days <= 1 ? streak : 0
    }

    /// Dnesni minuty plati jen v den zapisu.
    func todayMinutes(at date: Date, calendar: Calendar = .current) -> Int {
        calendar.isDate(updatedAt, inSameDayAs: date) ? todayMinutes : 0
    }
}
