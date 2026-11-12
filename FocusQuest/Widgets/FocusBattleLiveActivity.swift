import ActivityKit
import SwiftUI
import WidgetKit

struct FocusBattleAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var bossHP: Int
        var bossMaxHP: Int
        var elapsedSeconds: Int
        var warningSecondsRemaining: Int?
        var isWarning: Bool
    }
    var bossName: String
    var bossSpriteID: String
    var bossMaxHP: Int
}

@available(iOS 16.1, *)
struct FocusBattleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusBattleAttributes.self) { context in
            HStack(spacing: 12) {
                PixelArtAvatarView(sprite: .boss(context.attributes.bossSpriteID), size: 44)
                VStack(alignment: .leading, spacing: 5) {
                    Text(context.attributes.bossName).font(.system(size: 13, weight: .bold, design: .rounded))
                    liveHealth(context.state)
                }
                Spacer()
                Text(clock(context.state.elapsedSeconds)).font(.system(size: 15, weight: .semibold, design: .monospaced)).monospacedDigit()
            }
            .padding(12).background(context.state.isWarning ? Color.red.opacity(0.78) : Color(red: 0.1, green: 0.13, blue: 0.2))
            .activityBackgroundTint(Color.black.opacity(0.8)).activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { PixelArtAvatarView(sprite: .boss(context.attributes.bossSpriteID), size: 48) }
                DynamicIslandExpandedRegion(.trailing) { Text(clock(context.state.elapsedSeconds)).font(.system(.caption, design: .monospaced)).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.isWarning ? "RETURN PHONE - \(context.state.warningSecondsRemaining ?? 0)s" : context.attributes.bossName).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(context.state.isWarning ? .red : .white)
                        liveHealth(context.state)
                    }
                }
            } compactLeading: {
                PixelArtAvatarView(sprite: .boss(context.attributes.bossSpriteID), size: 24)
            } compactTrailing: {
                Text(context.state.isWarning ? "!" : clock(context.state.elapsedSeconds)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(context.state.isWarning ? .red : .white).monospacedDigit()
            } minimal: {
                Image(systemName: context.state.isWarning ? "exclamationmark.triangle.fill" : "bolt.fill").foregroundStyle(context.state.isWarning ? .red : .mint)
            }
            .keylineTint(context.state.isWarning ? .red : .mint)
        }
    }

    private func liveHealth(_ state: FocusBattleAttributes.ContentState) -> some View {
        ProgressView(value: Double(max(0, state.bossHP)), total: Double(max(1, state.bossMaxHP))).tint(state.isWarning ? .red : .mint)
    }

    private func clock(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
}

@available(iOS 16.1, *)
protocol FocusBattleActivityServiceProtocol: Sendable {
    func start(boss: Boss) async
    func update(bossHP: Int, elapsedSeconds: Int, warningSecondsRemaining: Int?) async
    func end() async
}

@available(iOS 16.1, *)
actor FocusBattleActivityController: FocusBattleActivityServiceProtocol {
    private var activity: Activity<FocusBattleAttributes>?

    func start(boss: Boss) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = FocusBattleAttributes(bossName: boss.name, bossSpriteID: boss.pixelSpriteConfig, bossMaxHP: boss.maxHP)
        let state = FocusBattleAttributes.ContentState(bossHP: boss.currentHP, bossMaxHP: boss.maxHP, elapsedSeconds: 0, warningSecondsRemaining: nil, isWarning: false)
        activity = try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
    }

    func update(bossHP: Int, elapsedSeconds: Int, warningSecondsRemaining: Int?) async {
        guard let activity else { return }
        let state = FocusBattleAttributes.ContentState(bossHP: bossHP, bossMaxHP: activity.attributes.bossMaxHP, elapsedSeconds: elapsedSeconds, warningSecondsRemaining: warningSecondsRemaining, isWarning: warningSecondsRemaining != nil)
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func end() async { await activity?.end(nil, dismissalPolicy: .immediate); activity = nil }
}