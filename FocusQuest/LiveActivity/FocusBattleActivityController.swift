@preconcurrency import ActivityKit
import Foundation

protocol FocusBattleActivityServiceProtocol: Sendable {
    func start(boss: Boss) async
    /// `frozen` = hodiny bitvy stoji (pauza, hovor). Pri varovani stoji vzdy.
    func update(bossHP: Int, elapsedSeconds: Int, warningSecondsRemaining: Int?, frozen: Bool) async
    /// Konec bitvy. S vysledkem zustane aktivita chvili na zamcene obrazovce, bez nej hned zmizi.
    func end(outcome: FocusBattleAttributes.Outcome?) async
}

extension FocusBattleActivityServiceProtocol {
    func update(bossHP: Int, elapsedSeconds: Int, warningSecondsRemaining: Int?) async {
        await update(bossHP: bossHP, elapsedSeconds: elapsedSeconds, warningSecondsRemaining: warningSecondsRemaining, frozen: false)
    }

    func end() async { await end(outcome: nil) }
}

/// Spousti a aktualizuje Live Activity. Samotny vzhled je ve Widget Extension
/// (FocusQuestWidgets/FocusBattleLiveActivity.swift).
actor FocusBattleActivityController: FocusBattleActivityServiceProtocol {
    // Activity neni Sendable -> v aktoru drzime jen jeji ID a instanci si vzdy
    // dohledame lokalne (Swift 6 strict concurrency).
    private var activityID: String?
    private var bossMaxHP = 1
    private var lastState: FocusBattleAttributes.ContentState?

    /// Jak dlouho zustane vysledek bitvy na zamcene obrazovce.
    private static let resultLinger: TimeInterval = 15 * 60

    private static func activity(withID id: String) -> Activity<FocusBattleAttributes>? {
        Activity<FocusBattleAttributes>.activities.first { $0.id == id }
    }

    func start(boss: Boss) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Uklid aktivit, ktere mohly zustat viset po nasilnem ukonceni appky.
        await endAllActivities()
        let attributes = FocusBattleAttributes(bossName: boss.name, bossSpriteID: boss.pixelSpriteConfig, bossMaxHP: boss.maxHP)
        let state = FocusBattleAttributes.ContentState(bossHP: boss.currentHP, bossMaxHP: boss.maxHP, focusStartedAt: nil, warningEndsAt: nil)
        bossMaxHP = boss.maxHP
        lastState = state
        activityID = (try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil)))?.id
    }

    func update(bossHP: Int, elapsedSeconds: Int, warningSecondsRemaining: Int?, frozen: Bool) async {
        guard let id = activityID else { return }
        let now = Date()
        let total = bossMaxHP * 60
        let start = now.addingTimeInterval(-Double(elapsedSeconds))
        let end = start.addingTimeInterval(Double(total))
        let stopped = frozen || warningSecondsRemaining != nil
        let state = FocusBattleAttributes.ContentState(
            bossHP: bossHP,
            bossMaxHP: bossMaxHP,
            focusStartedAt: start,
            warningEndsAt: warningSecondsRemaining.map { now.addingTimeInterval(Double($0)) },
            focusEndsAt: end,
            frozenRemainingSeconds: stopped ? max(0, total - elapsedSeconds) : nil
        )
        // Cas i HP bar na zamcene obrazovce pocita system, takze aktivitu prekreslujeme
        // jen kdyz se neco opravdu zmenilo (varovani, pauza, posun casu po pauze).
        if let lastState, Self.isSameMoment(lastState, state) { return }
        guard let activity = Self.activity(withID: id) else { return }
        lastState = state
        // Kdyz hodiny bezi, po konci bitvy je stav zastaraly: widget ukaze "Time's up", i kdyz appka spi.
        await activity.update(ActivityContent(state: state, staleDate: stopped ? nil : end))
    }

    func end(outcome: FocusBattleAttributes.Outcome?) async {
        if let outcome, let id = activityID, let activity = Self.activity(withID: id), var state = lastState {
            state.outcome = outcome
            state.warningEndsAt = nil
            state.frozenRemainingSeconds = outcome == .victory ? 0 : (state.frozenRemainingSeconds ?? state.focusEndsAt.map { max(0, Int($0.timeIntervalSinceNow)) })
            if outcome == .victory { state.bossHP = 0 }
            activityID = nil
            lastState = nil
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(Self.resultLinger)))
        }
        await endAllActivities(keepingResult: outcome != nil)
    }

    private func endAllActivities(keepingResult: Bool = false) async {
        activityID = nil
        lastState = nil
        let ids = Activity<FocusBattleAttributes>.activities.map(\.id)
        for id in ids {
            guard let activity = Self.activity(withID: id) else { continue }
            // Prave ukoncena aktivita s vysledkem uz ma vlastni casovac zmizeni.
            if keepingResult, activity.activityState == .ended { continue }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func isSameMoment(_ old: FocusBattleAttributes.ContentState, _ new: FocusBattleAttributes.ContentState) -> Bool {
        guard old.bossHP == new.bossHP, old.bossMaxHP == new.bossMaxHP, old.isWarning == new.isWarning, old.isFrozen == new.isFrozen else { return false }
        if let oldEnd = old.warningEndsAt, let newEnd = new.warningEndsAt {
            return abs(oldEnd.timeIntervalSince(newEnd)) < 1.5
        }
        guard let oldStart = old.focusStartedAt, let newStart = new.focusStartedAt else { return false }
        return abs(oldStart.timeIntervalSince(newStart)) < 1.5
    }
}
