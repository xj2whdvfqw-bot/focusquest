import SwiftUI
import UIKit
@preconcurrency import UserNotifications

/// Appka, kterou si hrac v onboardingu "zablokuje". Zatim jen maketa vyberu:
/// skutecne blokovani prijde s FamilyControls, az bude placeny Apple Developer ucet.
struct BlockableApp: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let symbol: String
}

/// Notifikace pri utoku bosse (hrac odesel z appky behem bitvy).
protocol EscapeNotifying: Sendable {
    func scheduleEscapeWarning(after seconds: TimeInterval) async
    func cancelEscapeWarning() async
    func sendQuestFailed() async
}

struct EscapeNotificationService: EscapeNotifying {
    static let warningIdentifier = "focusquest.escape.warning"
    static let failedIdentifier = "focusquest.escape.failed"

    func scheduleEscapeWarning(after seconds: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = "The boss is attacking!"
        content.body = "Return immediately! You have \(Int(AppBlockerManager.gracePeriod)) seconds before the quest fails."
        content.sound = .default
        // Kriticke upozorneni (.defaultCritical) vyzaduje entitlement od Applu; time-sensitive je nejvys, co jde bez nej.
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(0.5, seconds), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.warningIdentifier, content: content, trigger: trigger))
    }

    func cancelEscapeWarning() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.warningIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.warningIdentifier])
    }

    func sendQuestFailed() async {
        let content = UNMutableNotificationContent()
        content.title = "Quest failed"
        content.body = "You stayed away too long. The boss won this round: you lost hero HP and your daily streak."
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.failedIdentifier, content: content, trigger: nil))
    }
}

/// Hlida, jestli hrac behem bitvy neodesel z FocusQuestu.
///
/// Dnes: kdyz appka behem bitvy odejde na pozadi, prijde upozorneni "The boss is attacking!"
/// a pokud se hrac do 10 sekund nevrati, quest propadne (ztrata HP hrdiny a serie).
/// Zamceni displeje utek neni - telefon smi lezet zamceny na stole.
///
/// Pozdeji: sem pribude FamilyControls / ManagedSettings (vyzaduje placeny ucet a entitlement).
/// Zbytek appky mluvi jen s timhle manazerem, takze se nic jineho menit nebude.
@MainActor
final class AppBlockerManager: ObservableObject {
    /// Konstanta; cte ji i notifikacni sluzba mimo hlavni vlakno.
    nonisolated static let gracePeriod: TimeInterval = 10
    /// Kratka prodleva pred upozornenim: kdyz hrac jen zamkl displej, stihne se zrusit.
    static let warningDelay: TimeInterval = 1.5
    private static let selectionKey = "focusquest.blocked-apps"

    static let catalog: [BlockableApp] = [
        BlockableApp(id: "social-photos", name: "Instagram", symbol: "camera.fill"),
        BlockableApp(id: "short-video", name: "TikTok", symbol: "music.note"),
        BlockableApp(id: "video", name: "YouTube", symbol: "play.rectangle.fill"),
        BlockableApp(id: "microblog", name: "X", symbol: "bubble.left.fill"),
        BlockableApp(id: "forums", name: "Reddit", symbol: "text.bubble.fill"),
        BlockableApp(id: "snaps", name: "Snapchat", symbol: "bolt.fill"),
        BlockableApp(id: "games", name: "Games", symbol: "gamecontroller.fill"),
        BlockableApp(id: "streaming", name: "Netflix", symbol: "tv.fill"),
        BlockableApp(id: "chat", name: "Messenger", symbol: "message.fill")
    ]

    @Published private(set) var selectedAppIDs: Set<String>
    /// Kdy hrac behem bitvy odesel (monotonni cas); nil = je v appce.
    @Published private(set) var awaySince: TimeInterval?

    /// Bezi prave bitva? Dodava Arena.
    var isBattleRunning: () -> Bool = { false }
    /// Hrac se nevratil vcas: Arena bitvu ukonci a profil strhne HP a serii.
    var onEscapeTimeout: () async -> Void = {}

    private let defaults: UserDefaults
    private let notifier: any EscapeNotifying
    private let clock: () -> TimeInterval
    private var screenLocked = false
    private var timeoutTask: Task<Void, Never>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var lockObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard, notifier: any EscapeNotifying = EscapeNotificationService(), clock: @escaping () -> TimeInterval = { MonotonicClock.now }) {
        self.defaults = defaults
        self.notifier = notifier
        self.clock = clock
        selectedAppIDs = Set(defaults.stringArray(forKey: Self.selectionKey) ?? [])
    }

    var selectedApps: [BlockableApp] { Self.catalog.filter { selectedAppIDs.contains($0.id) } }

    func isSelected(_ app: BlockableApp) -> Bool { selectedAppIDs.contains(app.id) }

    func toggle(_ app: BlockableApp) {
        if selectedAppIDs.contains(app.id) { selectedAppIDs.remove(app.id) } else { selectedAppIDs.insert(app.id) }
        defaults.set(selectedAppIDs.sorted(), forKey: Self.selectionKey)
    }

    // MARK: - Hlidani bitvy

    /// Zamceni displeje (s kodem) iOS ohlasi jako "chranena data budou nedostupna" - to neni utek.
    func startObservingScreenLock() {
        guard lockObserver == nil else { return }
        lockObserver = NotificationCenter.default.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenDidLock() }
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background: appDidLeave()
        case .active: Task { await appDidReturn() }
        default: break
        }
    }

    func appDidLeave() {
        guard isBattleRunning(), awaySince == nil else { return }
        awaySince = clock()
        screenLocked = false
        beginBackgroundTime()
        Task { await notifier.scheduleEscapeWarning(after: Self.warningDelay) }
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.gracePeriod))
            guard !Task.isCancelled else { return }
            await self?.escapeTimedOut()
        }
    }

    func screenDidLock() {
        guard awaySince != nil else { return }
        screenLocked = true
        timeoutTask?.cancel()
        Task { await notifier.cancelEscapeWarning() }
        endBackgroundTime()
    }

    /// Navrat do appky. Kdyz byla appka uspana a casovac nedobehl, rozhodne se tady podle uplynuleho casu.
    func appDidReturn() async {
        guard let since = awaySince else { return }
        let away = clock() - since
        let wasLocked = screenLocked
        awaySince = nil
        screenLocked = false
        timeoutTask?.cancel()
        await notifier.cancelEscapeWarning()
        endBackgroundTime()
        if !wasLocked && away >= Self.gracePeriod && isBattleRunning() {
            await onEscapeTimeout()
        }
    }

    private func escapeTimedOut() async {
        guard awaySince != nil, !screenLocked else { return }
        awaySince = nil
        await onEscapeTimeout()
        await notifier.sendQuestFailed()
        endBackgroundTime()
    }

    /// Par sekund behu na pozadi, aby desetisekundovy limit dobehl i bez navratu do appky.
    private func beginBackgroundTime() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "focusquest.escape-watch") { [weak self] in
            MainActor.assumeIsolated { self?.endBackgroundTime() }
        }
    }

    private func endBackgroundTime() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
