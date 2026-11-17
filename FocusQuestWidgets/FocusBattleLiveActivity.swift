import ActivityKit
import SwiftUI
import WidgetKit

struct FocusBattleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusBattleAttributes.self) { context in
            LockScreenBattleView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(context.state.isWarning ? Color(red: 0.45, green: 0.04, blue: 0.10).opacity(0.85) : Color.black.opacity(0.45))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StaticPixelSprite(sprite: .boss(context.attributes.bossSpriteID), size: 44)
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
                        Text(BattleCopy.subtitle(state: context.state))
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
                    .foregroundStyle(context.state.isWarning ? FQColor.alarm : FQColor.mint)
                    .frame(width: 44, alignment: .trailing)
            } minimal: {
                Image(systemName: context.state.isWarning ? "exclamationmark.triangle.fill" : "bolt.fill")
                    .foregroundStyle(context.state.isWarning ? FQColor.alarm : FQColor.mint)
            }
            .keylineTint(context.state.isWarning ? FQColor.alarm : FQColor.mint)
        }
    }
}

/// Podoba na zamcene obrazovce a v banneru.
private struct LockScreenBattleView: View {
    let attributes: FocusBattleAttributes
    let state: FocusBattleAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            StaticPixelSprite(sprite: .boss(attributes.bossSpriteID), size: 48)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(BattleCopy.title(attributes: attributes, state: state))
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    BattleTimerText(state: state)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 96, alignment: .trailing)
                }
                BattleHealthBar(state: state)
                Text(BattleCopy.subtitle(state: state))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

/// Cas kresli system sam (Text(timerInterval:)), proto se hybe i kdyz appka nebezi.
private struct BattleTimerText: View {
    let state: FocusBattleAttributes.ContentState

    var body: some View {
        if let warningEnd = state.warningEndsAt {
            let now = Date()
            Text(timerInterval: now...max(warningEnd, now), countsDown: true)
        } else if let start = state.focusStartedAt {
            Text(timerInterval: start...start.addingTimeInterval(86_400), countsDown: false)
        } else {
            Text("--:--")
        }
    }
}

private struct BattleHealthBar: View {
    let state: FocusBattleAttributes.ContentState

    var body: some View {
        ProgressView(value: Double(min(max(0, state.bossHP), max(1, state.bossMaxHP))), total: Double(max(1, state.bossMaxHP)))
            .tint(state.isWarning ? FQColor.alarm : FQColor.mint)
    }
}

private enum BattleCopy {
    static func title(attributes: FocusBattleAttributes, state: FocusBattleAttributes.ContentState) -> String {
        state.isWarning ? "Return phone to desk" : attributes.bossName
    }

    static func subtitle(state: FocusBattleAttributes.ContentState) -> String {
        if state.isWarning { return "Put it back or the boss escapes" }
        if state.focusStartedAt == nil { return "Lay iPhone face-down to start" }
        return "Boss health \(max(0, state.bossHP)) / \(state.bossMaxHP)"
    }
}
