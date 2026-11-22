import Foundation
import os
@preconcurrency import UserNotifications

/// Lokalni notifikace (zadny push/APNs: appka je sideloadovana s bezplatnym Apple ID, entitlement
/// aps-environment nema a nepotrebuje). Vsechny typy:
///  - Victory!        `focusquest.battle.victory`  na cas konce odpoctu bitvy,
///  - Break is over   `focusquest.break.over`      5 min po Collect Loot,
///  - Daily reminder  `focusquest.reminder.0…7`    v 17:00 na pristich 7 dni (kdyz je zapnuta).
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

/// Actor: planovani a ruseni se nikdy neprekryji. Driv mohlo zruseni (napr. ustup hned po startu)
/// probehnout behem planovani a "Victory!" pak prislo, i kdyz bitva neskoncila.
actor BattleNotificationService: BattleNotificationServiceProtocol {
    static let victoryIdentifier = "focusquest.battle.victory"
    static let breakIdentifier = "focusquest.break.over"
    static let reminderPrefix = "focusquest.reminder."
    static let reminderHour = 17

    private static let log = Logger(subsystem: "FocusQuest", category: "notifications")
    /// Zvysi se pri kazdem zruseni vitezstvi; planovani, ktere mezitim dobehlo, se pak samo smaze.
    private var victoryGeneration = 0

    /// Bez povoleni by se notifikace naplanovala, ale nikdy neukazala. Proto se kazde planovani
    /// nejdriv zepta (jen kdyz se iOS jeste neptal) a pri zakazu nic neplanuje.
    func requestAuthorizationIfNeeded() async {
        _ = await isAuthorized()
    }

    private func isAuthorized() async -> Bool {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                Self.log.error("requestAuthorization failed: \(error.localizedDescription, privacy: .public)")
            }
            status = await center.notificationSettings().authorizationStatus
        }
        switch status {
        case .authorized, .provisional, .ephemeral: return true
        default:
            Self.log.notice("notifications not allowed (status \(status.rawValue, privacy: .public))")
            return false
        }
    }

    private func add(_ identifier: String, title: String, body: String, trigger: UNNotificationTrigger) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "focusquest"
        do {
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        } catch {
            Self.log.error("scheduling \(identifier, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Victory

    func scheduleVictory(bossName: String, after seconds: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.victoryIdentifier])
        let generation = victoryGeneration
        guard await isAuthorized() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        await add(Self.victoryIdentifier, title: "Victory!", body: Self.victoryBody(bossName), trigger: trigger)
        // Bitva se mezitim zrusila (ustup, zvednuti, pauza): notifikace uz neplati.
        if generation != victoryGeneration {
            center.removePendingNotificationRequests(withIdentifiers: [Self.victoryIdentifier])
        }
    }

    func cancelVictory() async {
        victoryGeneration += 1
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.victoryIdentifier])
    }

    static func victoryBody(_ bossName: String) -> String {
        "\(bossName) is defeated. Open FocusQuest to collect your XP and coins."
    }

    // MARK: - Break is over

    static let breakTitle = "Break is over"
    static let breakBody = "Fresh head. Time for the next boss."

    func scheduleBreakOver(after seconds: Int) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.breakIdentifier])
        guard await isAuthorized() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        await add(Self.breakIdentifier, title: Self.breakTitle, body: Self.breakBody, trigger: trigger)
    }

    func cancelBreakOver() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.breakIdentifier])
    }

    // MARK: - Daily reminder

    static let reminderTitle = "Your boss is waiting"
    static let reminderBody = "No battle yet today. Put your phone down for a few minutes."

    func updateDailyReminder(enabled: Bool, focusedToday: Bool) async {
        let center = UNUserNotificationCenter.current()
        let identifiers = (0..<8).map { Self.reminderPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard enabled, await isAuthorized() else { return }
        // Mistni cas telefonu (Calendar.current ma aktualni casove pasmo).
        let calendar = Calendar.current
        let now = Date()
        for (offset, identifier) in identifiers.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fireDate = calendar.date(bySettingHour: Self.reminderHour, minute: 0, second: 0, of: day),
                  fireDate > now else { continue }
            // Kdo uz dnes bojoval, dnes pripominku nedostane.
            if offset == 0 && focusedToday { continue }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            await add(identifier, title: Self.reminderTitle, body: Self.reminderBody, trigger: trigger)
        }
    }

    // MARK: - Test (Debug v Nastaveni)

    /// Naplanuje kazdy typ notifikace za 5, 7 a 9 s se stejnym textem jako skutecne,
    /// ale s vlastnimi identifikatory, aby se nedotkly naplanovanych bitev a pripominek.
    /// Vraci false, kdyz iOS notifikace nepovoluje.
    func scheduleTestNotifications() async -> Bool {
        guard await isAuthorized() else { return false }
        let tests: [(String, String, String)] = [
            ("focusquest.test.victory", "Victory!", Self.victoryBody("Web-Slacker")),
            ("focusquest.test.break", Self.breakTitle, Self.breakBody),
            ("focusquest.test.reminder", Self.reminderTitle, Self.reminderBody),
        ]
        for (index, test) in tests.enumerated() {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(5 + index * 2), repeats: false)
            await add(test.0, title: test.1, body: test.2, trigger: trigger)
        }
        return true
    }

    /// Naplanovane notifikace (Debug): identifikator a cas, kdy prijdou.
    func pendingSummary() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let formatter = DateFormatter()
        formatter.dateFormat = "d.M. HH:mm:ss"
        return requests.sorted { $0.identifier < $1.identifier }.map { request in
            let date: Date? = switch request.trigger {
            case let trigger as UNTimeIntervalNotificationTrigger: trigger.nextTriggerDate()
            case let trigger as UNCalendarNotificationTrigger: trigger.nextTriggerDate()
            default: nil
            }
            return "\(request.identifier.replacingOccurrences(of: "focusquest.", with: "")) · \(date.map(formatter.string(from:)) ?? "?")"
        }
    }
}

/// Notifikace se ma ukazat i ve chvili, kdy je appka zrovna otevrena.
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = ForegroundNotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

/// Skutecny stav povoleni notifikaci v iOS (onboarding a Nastaveni ho ukazuji, ne jen predvolby).
enum NotificationPermission: Sendable {
    /// `allowed`: povoleno; `silent`: povoleno, ale v iOS vypnute bannery i zamcena obrazovka
    /// (notifikace se pak jen tise ulozi do Centra notifikaci).
    case notDetermined, allowed, silent, denied

    static func current() async -> NotificationPermission {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default:
            return settings.alertSetting == .disabled && settings.lockScreenSetting == .disabled ? .silent : .allowed
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
