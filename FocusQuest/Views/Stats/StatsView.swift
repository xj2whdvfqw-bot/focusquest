import SwiftUI

struct StatsView: View {
    @ObservedObject var model: StatsViewModel
    @ObservedObject var profile: ProfileViewModel

    private var focusHours: String {
        String(format: "%.1f", Double(model.stats.sessionHistory.reduce(0) { $0 + $1.verifiedMinutes }) / 60)
    }

    var body: some View {
        ScreenScaffold {
            ScreenTitle(eyebrow: "Stats", title: "Your progression")
            levelCard
            LazyVGrid(columns: [GridItem(.flexible(), spacing: FQSpace.md), GridItem(.flexible())], spacing: FQSpace.md) {
                metric("Win rate", value: "\(Int(model.stats.winRate * 100))%", icon: "scope")
                metric("HP dealt", value: "\(model.stats.totalHPDealt)", icon: "bolt.fill")
                metric("Best combo", value: "\(model.stats.bestCombo)x", icon: "flame.fill")
                metric("Focus hours", value: focusHours, icon: "clock.fill")
            }
            ScreenSection(title: "Subjects") { subjectsCard }
            ScreenSection(title: "Verified battle log", detail: "\(model.stats.sessionHistory.count) battles") {
                battleLog
            }
        }
        .task { await model.load() }
    }

    /// Kolik minut hrac venoval kteremu predmetu.
    @ViewBuilder private var subjectsCard: some View {
        let progress = SubjectProgress.summarize(model.stats.sessionHistory)
        let maxMinutes = max(1, progress.first?.minutes ?? 1)
        if progress.isEmpty {
            Label("Pick a subject before a battle to track your study time here.", systemImage: "books.vertical.fill")
                .font(.fqSecondary)
                .foregroundStyle(FQColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FQSpace.lg)
                .glassCard()
        } else {
            VStack(spacing: FQSpace.md) {
                ForEach(progress) { entry in
                    VStack(alignment: .leading, spacing: FQSpace.xs) {
                        HStack {
                            Label(entry.subject.title, systemImage: entry.subject.symbol).font(.fqLabel).foregroundStyle(FQColor.textPrimary)
                            Spacer(minLength: FQSpace.sm)
                            Text("\(ArenaView.durationText(minutes: entry.minutes)) · \(entry.battles) \(entry.battles == 1 ? "battle" : "battles")")
                                .font(.fqMeta)
                                .monospacedDigit()
                                .foregroundStyle(FQColor.textSecondary)
                        }
                        ProgressView(value: Double(entry.minutes), total: Double(maxMinutes)).tint(FQColor.accent)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(FQSpace.lg)
            .glassCard()
        }
    }

    private var levelCard: some View {
        HStack(spacing: FQSpace.lg) {
            ProgressRing(progress: Double(model.stats.xpIntoLevel) / Double(max(1, model.stats.xpForNextLevel))) {
                VStack(spacing: 0) {
                    Text("Level").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                    Text("\(model.stats.level)").font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                }
            }
            .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: FQSpace.sm) {
                Text(profile.profile.title).font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                Text("\(model.stats.xpIntoLevel) / \(model.stats.xpForNextLevel) XP to next level")
                    .font(.fqSecondary)
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textSecondary)
                ProgressView(value: Double(model.stats.xpIntoLevel), total: Double(max(1, model.stats.xpForNextLevel)))
                    .tint(FQColor.accent)
            }
        }
        .padding(FQSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var battleLog: some View {
        if model.stats.sessionHistory.isEmpty {
            VStack(alignment: .leading, spacing: FQSpace.xs) {
                Text("No battles yet").font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                Text("Win a focus battle in the Arena and it will show up here.")
                    .font(.fqSecondary)
                    .foregroundStyle(FQColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FQSpace.lg)
            .glassCard()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(model.stats.sessionHistory.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { HairlineDivider() }
                    HStack(spacing: FQSpace.md) {
                        VStack(alignment: .leading, spacing: FQSpace.xs) {
                            Text(entry.bossName).font(.fqBody).foregroundStyle(FQColor.textPrimary)
                            Text(entry.completedAt, style: .date).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                        }
                        Spacer(minLength: FQSpace.sm)
                        VStack(alignment: .trailing, spacing: FQSpace.xs) {
                            Text("+\(entry.xpEarned) XP").font(.fqLabel).monospacedDigit().foregroundStyle(FQColor.accent)
                            Text("\(entry.verifiedMinutes) min").font(.fqMeta).monospacedDigit().foregroundStyle(FQColor.textSecondary)
                        }
                    }
                    .padding(.vertical, FQSpace.md)
                }
            }
            .padding(.horizontal, FQSpace.lg)
            .padding(.vertical, FQSpace.xs)
            .glassCard()
        }
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: FQSpace.md) {
            IconTile(symbol: icon)
            VStack(alignment: .leading, spacing: FQSpace.xs) {
                Text(value).font(.fqTitle).monospacedDigit().foregroundStyle(FQColor.textPrimary)
                Text(title).font(.fqSecondary).foregroundStyle(FQColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FQSpace.lg)
        .glassCard(radius: FQRadius.control + 4)
        .accessibilityElement(children: .combine)
    }
}
