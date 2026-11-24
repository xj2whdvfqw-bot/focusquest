import SwiftUI

/// C5: karta tydennich ukolu ve Stats. Kazdy ukol: ikona, nazev, postup a truhla.
/// Splneny ukol ma zlute "Open chest"; po otevreni truhla poskoci, vyletne "+N coins", zazni mince
/// a vibrace. Po vsech trech truhlach "All done, new quests on Monday". Reduce Motion: jen prolnuti.
struct WeeklyQuestsCard: View {
    @ObservedObject var profile: ProfileViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Prave otevrena truhla (animace "+N coins").
    @State private var opened: String?
    @State private var bounce = 0

    var body: some View {
        let quests = profile.weeklyQuests
        let week = profile.weekSessions
        let allClaimed = quests.allSatisfy { profile.isClaimed($0) }
        VStack(alignment: .leading, spacing: FQSpace.sm) {
            SectionHeader(title: "Weekly quests", detail: allClaimed ? "All done" : "New every Monday")
            VStack(spacing: 0) {
                ForEach(Array(quests.enumerated()), id: \.element.id) { index, quest in
                    if index > 0 { HairlineDivider() }
                    row(quest, progress: quest.progress(in: week))
                }
                if allClaimed {
                    HairlineDivider()
                    Text("All chests opened. New quests on Monday.")
                        .fqFont(size: 13, design: .rounded)
                        .foregroundStyle(FQColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .fqCard()
        }
    }

    private func row(_ quest: WeeklyQuest, progress: Int) -> some View {
        let complete = progress >= quest.target
        let claimed = profile.isClaimed(quest)
        let fraction: CGFloat = CGFloat(min(progress, quest.target)) / CGFloat(max(1, quest.target))
        return HStack(spacing: FQSpace.md) {
            Image(systemName: quest.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(complete ? FQColor.accent : FQColor.textSecondary)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.08), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(quest.title)
                    .fqFont(size: 15, weight: .semibold, design: .rounded)
                    .foregroundStyle(FQColor.textPrimary)
                    .lineLimit(2)
                HStack(spacing: FQSpace.sm) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(complete ? FQColor.accent : FQColor.textSecondary)
                                .frame(width: proxy.size.width * fraction)
                        }
                    }
                    .frame(height: 5)
                    Text("\(progress)/\(quest.target)")
                        .fqFont(size: 12, design: .rounded)
                        .monospacedDigit()
                        .foregroundStyle(FQColor.textSecondary)
                        .fixedSize()
                }
            }
            chest(quest, complete: complete, claimed: claimed)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func chest(_ quest: WeeklyQuest, complete: Bool, claimed: Bool) -> some View {
        if claimed {
            VStack(spacing: 1) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(FQColor.textTertiary)
                Text("+\(quest.reward)")
                    .fqFont(size: 11, weight: .bold, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textTertiary)
            }
            .frame(width: 64)
            .overlay(alignment: .top) {
                if opened == quest.id && !reduceMotion {
                    FloatingCoins(amount: quest.reward)
                }
            }
            .keyframeAnimator(initialValue: 1.0, trigger: opened == quest.id ? bounce : 0) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1.3, duration: 0.12)
                    SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Chest opened, \(quest.reward) coins")
        } else if complete {
            Button {
                let coins = profile.claim(quest)
                guard coins > 0 else { return }
                opened = quest.id
                bounce += 1
                FQFeedback.shared.play(.coin)
                FQFeedback.shared.haptic(.success)
                AccessibilityNotification.Announcement("Chest opened: \(coins) coins").post()
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "shippingbox.fill").font(.system(size: 16, weight: .bold))
                    Text("Open").fqFont(size: 11, weight: .heavy, design: .rounded)
                }
                .foregroundStyle(FQColor.onCta)
                .frame(width: 64, height: 44)
                .background(FQColor.cta, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.fqPress)
            .accessibilityLabel("Open chest, \(quest.reward) coins")
        } else {
            VStack(spacing: 1) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 18))
                    .foregroundStyle(FQColor.coin.opacity(0.8))
                Text("\(quest.reward)")
                    .fqFont(size: 11, weight: .bold, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textSecondary)
            }
            .frame(width: 64)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reward \(quest.reward) coins")
        }
    }
}

/// "+50" s mincemi, ktere vyletnou z otevrene truhly a zmizi (0,9 s).
private struct FloatingCoins: View {
    let amount: Int
    @State private var progress = 0.0

    var body: some View {
        Text("+\(amount)")
            .fqFont(size: 15, weight: .heavy, design: .rounded)
            .monospacedDigit()
            .foregroundStyle(FQColor.coin)
            .shadow(color: .black.opacity(0.6), radius: 0, x: 1, y: 1)
            .offset(y: -10 - 26 * progress)
            .opacity(1 - progress)
            .onAppear { withAnimation(.easeOut(duration: 0.9)) { progress = 1 } }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
