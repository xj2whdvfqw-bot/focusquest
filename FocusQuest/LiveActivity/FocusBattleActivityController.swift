@preconcurrency import ActivityKit
import Foundation

protocol FocusBattleActivityServiceProtocol: Sendable {
    func start(boss: Boss) async
    func update(bossHP: Int, elapsedSeconds: Int, warningSecondsRemaining: Int?) async
    func end() async
}

/// Spousti a aktualizuje Live Activity. Samotny vzhled je ve Widget Extension
/// (FocusQuestWidgets/FocusBattleLiveActivity.swift).
actor FocusBattleActivityController: FocusBattleActivityServiceProtocol {
    // Activity neni Sendable -> v aktoru drzime jen jeji ID a instanci si vzdy
    // dohledame lokalne (Swift 6 strict concurrency).
    private var activityID: String?
    private var bossMaxHP = 1
    private var lastState: FocusBattleAttributes.ContentState?

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

    func update(bossHP: Int, elapsedSeconds: Int, warningSecondsRemaining: Int?) async {
        guard let id = activityID else { return }
        let now = Date()
        let state = FocusBattleAttributes.ContentState(
            bossHP: bossHP,
            bossMaxHP: bossMaxHP,
            focusStartedAt: now.addingTimeInterval(-Double(elapsedSeconds)),
            warningEndsAt: warningSecondsRemaining.map { now.addingTimeInterval(Double($0)) }
        )
        // Cas na zamcene obrazovce pocita system, takze aktivitu prekreslujeme
        // jen kdyz se neco opravdu zmenilo (HP, varovani, posun casu po pauze).
        if let lastState, Self.isSameMoment(lastState, state) { return }
        guard let activity = Self.activity(withID: id) else { return }
        lastState = state
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func end() async {
        await endAllActivities()
    }

    private func endAllActivities() async {
        activityID = nil
        lastState = nil
        let ids = Activity<FocusBattleAttributes>.activities.map(\.id)
        for id in ids {
            guard let activity = Self.activity(withID: id) else { continue }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func isSameMoment(_ old: FocusBattleAttributes.ContentState, _ new: FocusBattleAttributes.ContentState) -> Bool {
        guard old.bossHP == new.bossHP, old.bossMaxHP == new.bossMaxHP, old.isWarning == new.isWarning else { return false }
        if let oldEnd = old.warningEndsAt, let newEnd = new.warningEndsAt {
            return abs(oldEnd.timeIntervalSince(newEnd)) < 1.5
        }
        guard let oldStart = old.focusStartedAt, let newStart = new.focusStartedAt else { return false }
        return abs(oldStart.timeIntervalSince(newStart)) < 1.5
    }
}
