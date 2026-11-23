import AppIntents
import Foundation
@preconcurrency import UserNotifications

/// C3: stav iOS Focus rezimu, do ktereho si hrac FocusQuest pridal (Nastaveni › Focus › Focus filters).
/// Uklada ho Focus Filter (bezi v procesu appky, i kdyz je appka zavrena) a cte Home a planovani pripominek.
struct FocusModeState: Codable, Equatable, Sendable {
    /// Home nabidne rovnou bitvu.
    var suggestsBattle = false
    /// Vlastni pripominky appky (Daily reminder, Streak in danger) jsou ztlumene.
    var mutesReminders = false

    var isActive: Bool { suggestsBattle || mutesReminders }

    static let storageKey = "fq.focusModeState"
    /// Zmena stavu za behu appky (Home a pripominky se obnovi).
    static let didChange = Notification.Name("fq.focusModeStateDidChange")

    static func load(defaults: UserDefaults = .standard) -> FocusModeState {
        guard let data = defaults.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(FocusModeState.self, from: data) else { return FocusModeState() }
        return value
    }

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// Focus Filter: v iOS Nastaveni › Focus › (napr. Study) › Add Filter › FocusQuest.
/// Kdyz se rezim zapne, iOS zavola `perform()` s nastavenymi hodnotami; kdyz se vypne, zavola ho
/// s vychozimi hodnotami (obe vypnute), takze stav se sam vrati do normalu.
struct FocusQuestFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource { "FocusQuest" }
    static var description: IntentDescription? { IntentDescription("Suggest a battle on Home and mute FocusQuest reminders while this Focus is on.") }

    @Parameter(title: "Suggest a battle", default: false)
    var suggestBattle: Bool

    @Parameter(title: "Mute reminders", default: false)
    var muteReminders: Bool

    var displayRepresentation: DisplayRepresentation {
        let parts = [suggestBattle ? "Suggests a battle" : nil, muteReminders ? "Mutes reminders" : nil].compactMap { $0 }
        return DisplayRepresentation(title: "FocusQuest", subtitle: LocalizedStringResource(stringLiteral: parts.isEmpty ? "Off" : parts.joined(separator: " · ")))
    }

    func perform() async throws -> some IntentResult {
        let state = FocusModeState(suggestsBattle: suggestBattle, mutesReminders: muteReminders)
        state.save()
        if muteReminders {
            // Ztlumeni plati hned, i kdyz appka nebezi: naplanovane pripominky pryc.
            let identifiers = (0..<8).map { "focusquest.reminder." + String($0) } + ["focusquest.streak.0", "focusquest.streak.1"]
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
        // Bezici appka obnovi Home a znovu naplanuje pripominky (po vypnuti rezimu).
        await MainActor.run { NotificationCenter.default.post(name: FocusModeState.didChange, object: nil) }
        return .result()
    }
}
