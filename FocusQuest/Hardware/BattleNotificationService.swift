import Foundation
@preconcurrency import UserNotifications

/// Lokalni notifikace "boss porazen". Planuje se na cas konce bitvy, takze prijde
/// i kdyz je appka uspana nebo je zamcena obrazovka.
protocol BattleNotificationServiceProtocol: Sendable {
    func requestAuthorizationIfNeeded() async
    func scheduleVictory(bossName: String, after seconds: Int) async
    func cancelVictory() async
}

struct BattleNotificationService: BattleNotificationServiceProtocol {
    static let victoryIdentifier = "focusquest.battle.victory"

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduleVictory(bossName: String, after seconds: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.victoryIdentifier])
        let content = UNMutableNotificationContent()
        content.title = "Victory!"
        content.body = "\(bossName) is defeated. Open FocusQuest to collect your XP and coins."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.victoryIdentifier, content: content, trigger: trigger))
    }

    func cancelVictory() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.victoryIdentifier])
    }
}

/// Notifikace o vitezstvi se ma ukazat i ve chvili, kdy je appka zrovna otevrena.
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = ForegroundNotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
