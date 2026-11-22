import ActivityKit
import SwiftUI
import WidgetKit

struct FocusBattleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusBattleAttributes.self) { context in
            LockScreenBattleView(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(context.state.isWarning ? Color(red: 0.45, green: 0.04, blue: 0.10).opacity(0.85) : Color.black.opacity(0.45))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StaticPixelSprite(sprite: .boss(context.attributes.bossSpriteID), size: 44)
                        .spritePlatter()
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BattleTimerText(state: context.state)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(context.state.isWarning ? FQColor.alarm : .white)
                        .frame(width: 72, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(BattleCopy.title(attributes: context.attributes, state: context.state))
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        BattleHealthBar(state: context.state)
                        Text(BattleCopy.subtitle(state: context.state, isStale: context.isStale))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                StaticPixelSprite(sprite: .boss(context.attributes.bossSpriteID), size: 22)
            } compactTrailing: {
                BattleTimerText(state: context.state)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(context.state.isWarning ? FQColor.alarm : FQColor.liveAccent)
                    .frame(width: 44, alignment: .trailing)
            } minimal: {
                Image(systemName: context.state.isWarning ? "exclamationmark.triangle.fill" : "bolt.fill")
                    .foregroundStyle(context.state.isWarning ? FQColor.alarm : FQColor.liveAccent)
            }
            .keylineTint(context.state.isWarning ? FQColor.alarm : FQColor.liveAccent)
        }
    }
}

/// Podoba na zamcene obrazovce a v banneru.
private struct LockScreenBattleView: View {
    let attributes: FocusBattleAttributes
    let state: FocusBattleAttributes.ContentState
    var isStale = false

    var body: some View {
        HStack(spacing: 12) {
            StaticPixelSprite(sprite: .boss(attributes.bossSpriteID), size: 48)
                .spritePlatter()
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(BattleCopy.title(attributes: attributes, state: state, isStale: isStale))
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if state.outcome == nil {
                        VStack(alignment: .trailing, spacing: 0) {
                            BattleTimerText(state: state)
                                .font(.title2.weight(.semibold))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 96, alignment: .trailing)
                            Text(BattleCopy.timerLabel(state: state))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                BattleHealthBar(state: state)
                Text(BattleCopy.subtitle(state: state, isStale: isStale))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .foregroundStyle(.white)
        .padding(FQRadius.Inset.liveActivity)
    }
}

/// Cas kresli system sam (Text(timerInterval:)), proto se hybe i kdyz appka nebezi.
/// Bezici bitva ukazuje odpocet do konce, varovani odpocet do uteku bosse, pauza stojici cas.
private struct BattleTimerText: View {
    let state: FocusBattleAttributes.ContentState

    var body: some View {
        if let warningEnd = state.warningEndsAt {
            let now = Date()
            Text(timerInterval: now...max(warningEnd, now), countsDown: true)
        } else if let frozen = state.frozenRemainingSeconds {
            Text(BattleCopy.clock(seconds: frozen))
        } else if let end = state.focusEndsAt {
            let now = Date()
            Text(timerInterval: now...max(end, now), countsDown: true)
        } else if let start = state.focusStartedAt {
            Text(timerInterval: start...start.addingTimeInterval(86_400), countsDown: false)
        } else {
            Text("--:--")
        }
    }
}

/// HP bosse = zbyvajici cas bitvy. Kdyz hodiny bezi, bar ubyva sam (ProgressView(timerInterval:)),
/// takze HP klesa i se zamcenym telefonem. Pri pauze a varovani stoji.
private struct BattleHealthBar: View {
    let state: FocusBattleAttributes.ContentState

    private var tint: Color { state.isWarning ? FQColor.alarm : FQColor.liveAccent }

    var body: some View {
        let total = Double(max(1, state.bossMaxHP * 60))
        Group {
            if state.outcome == .victory {
                ProgressView(value: 0, total: total)
            } else if let frozen = state.frozenRemainingSeconds {
                ProgressView(value: Double(min(Int(total), max(0, frozen))), total: total)
            } else if let start = state.focusStartedAt, let end = state.focusEndsAt, end > start {
                ProgressView(timerInterval: start...end, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            } else {
                ProgressView(value: Double(min(max(0, state.bossHP), max(1, state.bossMaxHP))), total: Double(max(1, state.bossMaxHP)))
            }
        }
        .tint(tint)
        .accessibilityLabel("Boss health")
    }
}

private enum BattleCopy {
    static func title(attributes: FocusBattleAttributes, state: FocusBattleAttributes.ContentState, isStale: Bool = false) -> String {
        switch state.outcome {
        case .victory: return "Victory! \(attributes.bossName) is down"
        case .escaped: return "\(attributes.bossName) escaped"
        case nil: break
        }
        if state.isWarning { return "Return phone to desk" }
        return attributes.bossName
    }

    static func timerLabel(state: FocusBattleAttributes.ContentState) -> String {
        if state.isWarning { return "to put it down" }
        if state.isFrozen { return "left · paused" }
        return state.focusStartedAt == nil ? "" : "left"
    }

    static func subtitle(state: FocusBattleAttributes.ContentState, isStale: Bool = false) -> String {
        switch state.outcome {
        case .victory: return "Open FocusQuest to collect your loot"
        case .escaped: return "No loot this time. Try again!"
        case nil: break
        }
        if state.isWarning { return "Put it back or the boss escapes" }
        if state.focusStartedAt == nil { return "Lay iPhone face-down to start" }
        if state.isFrozen { return "Battle paused · boss HP holds" }
        if isStale { return "Time’s up! Open FocusQuest to claim your win" }
        return "Boss HP drains while you focus"
    }

    /// Stojici cas "12:05" (nebo "1:02:05").
    static func clock(seconds: Int) -> String {
        let value = max(0, seconds)
        let h = value / 3600, m = (value % 3600) / 60, s = value % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

private extension View {
    /// Jemna podlozka pod spritem bosse. ContainerRelativeShape ma rohy soustredne se systemovym
    /// tvarem Live Activity a Dynamic Islandu (vnejsi polomer − odsazeni), na iOS 17 i 26.
    /// Samotny sprite zustava pixelovy se schodovitymi okraji.
    func spritePlatter() -> some View {
        padding(FQRadius.Inset.spritePlatter)
            .background(ContainerRelativeShape().fill(Color.white.opacity(0.10)))
    }
}
