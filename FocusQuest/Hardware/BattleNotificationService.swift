import Foundation
@preconcurrency import UserNotifications

/// Lokalni notifikace "boss porazen". Planuje se na cas konce bitvy, takze prijde
/// i kdyz je appka uspana nebo je zamcena obrazovka.
protocol BattleNotificationServiceProtocol: Sendable {
    func requestAuthorizationIfNeeded() async
    func scheduleVictory(bossName: String, after seconds: Int) async
    func cancelVictory() async
    /// "Break is over" po zadanem poctu sekund (konec 5minutove prestavky).
    func scheduleBreakOver(after seconds: Int) async
    func cancelBreakOver() async
    /// Denni pripominka v 17:00 na pristich 7 dni; dnesni se vynecha, kdyz uz hrac dnes bojoval.
    func updateDailyReminder(enabled: Bool, focusedToday: Bool) async
}

extension BattleNotificationServiceProtocol {
    func scheduleBreakOver(after seconds: Int) async { }
    func cancelBreakOver() async { }
    func updateDailyReminder(enabled: Bool, focusedToday: Bool) async { }
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

    static let breakIdentifier = "focusquest.break.over"
    static let reminderPrefix = "focusquest.reminder."
    static let reminderHour = 17

    func scheduleBreakOver(after seconds: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.breakIdentifier])
        let content = UNMutableNotificationContent()
        content.title = "Break is over"
        content.body = "Fresh head. Time for the next boss."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.breakIdentifier, content: content, trigger: trigger))
    }

    func cancelBreakOver() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.breakIdentifier])
    }

    func updateDailyReminder(enabled: Bool, focusedToday: Bool) async {
        let center = UNUserNotificationCenter.current()
        let identifiers = (0..<8).map { Self.reminderPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard enabled else { return }
        await requestAuthorizationIfNeeded()
        let calendar = Calendar.current
        let now = Date()
        for (offset, identifier) in identifiers.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fireDate = calendar.date(bySettingHour: Self.reminderHour, minute: 0, second: 0, of: day),
                  fireDate > now else { continue }
            // Kdo uz dnes bojoval, dnes pripominku nedostane.
            if offset == 0 && focusedToday { continue }
            let content = UNMutableNotificationContent()
            content.title = "Your boss is waiting"
            content.body = "No battle yet today. Put your phone down for a few minutes."
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }
}

/// Notifikace o vitezstvi se ma ukazat i ve chvili, kdy je appka zrovna otevrena.
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = ForegroundNotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// Skutecny stav povoleni notifikaci v iOS (onboarding a Nastaveni ho ukazuji, ne jen predvolby).
enum NotificationPermission: Sendable {
    case notDetermined, allowed, denied

    static func current() async -> NotificationPermission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .allowed
        }
    }

    /// Systemovy dotaz (jen kdyz se jeste neptal); vraci novy stav.
    static func request() async -> NotificationPermission {
        let center = UNUserNotificationCenter.current()
        if await current() == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        return await current()
    }
}
