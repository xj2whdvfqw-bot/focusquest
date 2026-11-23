import AppIntents
import Foundation

// C4: App Intents pro Siri, Spotlight, appku Zkratky a Action button. Bez entitlementu (funguje i se sideloadem).
// Intenty bezi v procesu appky: "Start battle" appku otevre, "Show streak" a "Pause battle" odpovi bez otevreni.

/// Prikazy z intentu a z deep linku (widget, focusquest://fight), ktere vykona MainTabView.
@MainActor
@Observable
final class AppCommandCenter {
    static let shared = AppCommandCenter()

    enum Command: Equatable {
        /// Vyber pred bitvou (Fight sheet): dalsi boss cesty, nebo vlastni delka v minutach.
        case fight(minutes: Int?)
    }

    /// Prikaz, ktery ceka na MainTabView (vykona ho a vynuluje).
    var pending: Command?
    /// Bitva pro "Pause battle" (nastavuje AppDIContainer).
    weak var arena: ArenaViewModel?

    func request(_ command: Command) { pending = command }

    /// Deep link: focusquest://fight (widget), focusquest://fight?minutes=25.
    static let scheme = "focusquest"

    static func command(for url: URL) -> Command? {
        guard url.scheme == scheme, url.host == "fight" else { return nil }
        let minutes = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first { $0.name == "minutes" }?.value.flatMap(Int.init)
        return .fight(minutes: minutes)
    }
}

/// "Start battle": otevre appku na vyberu pred bitvou (dalsi boss, nebo zvolena delka).
struct StartBattleIntent: AppIntent {
    static var title: LocalizedStringResource { "Start battle" }
    static var description: IntentDescription? { IntentDescription("Opens FocusQuest ready to fight your next boss, or a battle of the length you choose.") }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Length (minutes)", description: "Leave empty to fight your next boss.", inclusiveRange: (5, 240))
    var minutes: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Start a battle of \(\.$minutes) minutes")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppCommandCenter.shared.request(.fight(minutes: minutes))
        return .result()
    }
}

/// "Show streak": rekne aktualni serii (ze stavu ulozeneho v telefonu), appka se neotevre.
struct ShowStreakIntent: AppIntent {
    static var title: LocalizedStringResource { "Show streak" }
    static var description: IntentDescription? { IntentDescription("Tells you your current FocusQuest streak.") }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Int> {
        let snapshot = WidgetSnapshot.current()
        let days = snapshot.streak
        let text: String
        switch days {
        case 0: text = "No streak right now. One battle today starts a new one."
        case 1: text = "Your streak is 1 day. Keep it going tomorrow!"
        default: text = "Your streak is \(days) days. Keep the flame going!"
        }
        return .result(value: days, dialog: IntentDialog(stringLiteral: text))
    }
}

/// "Pause battle": pouzije pauzu zdarma (nebo extra) v bezici bitve. Kdyz bitva nebezi, rekne to.
struct PauseBattleIntent: AppIntent {
    static var title: LocalizedStringResource { "Pause battle" }
    static var description: IntentDescription? { IntentDescription("Pauses the running battle for up to 2 minutes, using your free pause first.") }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let arena = AppCommandCenter.shared.arena, arena.isBattleRunning else {
            return .result(dialog: "No battle is running right now.")
        }
        if case .paused = arena.state { return .result(dialog: "Your battle is already paused.") }
        guard arena.pausesLeft > 0 else { return .result(dialog: "No pauses left in this battle.") }
        arena.pauseBattle()
        if case .paused = arena.state {
            return .result(dialog: "Battle paused. Come back within 2 minutes or the boss escapes.")
        }
        return .result(dialog: "The battle can't be paused right now.")
    }
}

/// Fraze pro Siri a Spotlight; v appce Zkratky a na Action buttonu jsou hned k dispozici.
struct FocusQuestShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartBattleIntent(),
            phrases: [
                "Start a battle in \(.applicationName)",
                "Start a \(.applicationName) battle",
                "Fight my next boss in \(.applicationName)",
            ],
            shortTitle: "Start battle",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: ShowStreakIntent(),
            phrases: [
                "Show my \(.applicationName) streak",
                "What is my \(.applicationName) streak",
            ],
            shortTitle: "Show streak",
            systemImageName: "flame.fill"
        )
        AppShortcut(
            intent: PauseBattleIntent(),
            phrases: [
                "Pause my \(.applicationName) battle",
                "Pause \(.applicationName)",
            ],
            shortTitle: "Pause battle",
            systemImageName: "pause.fill"
        )
    }
}
