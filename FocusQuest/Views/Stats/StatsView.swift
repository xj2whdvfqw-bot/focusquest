import SwiftUI

struct StatsView: View {
    @ObservedObject var model: StatsViewModel
    @ObservedObject var profile: ProfileViewModel
    /// Seznam predmetu hrace (nazvy po prejmenovani, skryte) a sprava "Your subjects".
    @ObservedObject var arena: ArenaViewModel
    @State private var showsSubjectManager = false

    private var focusHours: String {
        String(format: "%.1f", Double(model.stats.sessionHistory.reduce(0) { $0 + $1.verifiedMinutes }) / 60)
    }

    var body: some View {
        ScreenScaffold(scene: .starlitPeaks) {
            ScreenHeader(eyebrow: "Stats", title: "Your progress")
            levelCard
            LazyVGrid(columns: [GridItem(.flexible(), spacing: FQSpace.md), GridItem(.flexible())], spacing: FQSpace.md) {
                metric("Win rate", value: "\(Int(model.stats.winRate * 100))%")
                metric("HP dealt", value: "\(model.stats.totalHPDealt)")
                metric("Day streak", value: "\(model.stats.currentStreak())")
                metric("Focus hours", value: focusHours)
            }
            VStack(alignment: .leading, spacing: FQSpace.sm) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Subjects")
                    Button("Edit subjects") { showsSubjectManager = true }
                        .font(.fqMeta.weight(.semibold))
                        .foregroundStyle(FQColor.textSecondary)
                        .frame(minHeight: 44)
                        .padding(.trailing, FQSpace.xs)
                }
                subjectsCard
            }
            ScreenSection(title: "Bestiary", detail: bestiaryDetail) { bestiaryCard }
            ScreenSection(title: "Verified battle log", detail: "\(model.stats.sessionHistory.count) battles") {
                battleLog
            }
        }
        .task { await model.load() }
        .sheet(isPresented: $showsSubjectManager) { SubjectManagerView(model: arena) }
    }

    /// Kolik minut hrac venoval kteremu predmetu.
    @ViewBuilder private var subjectsCard: some View {
        // Skryte a smazane predmety ve Stats nejsou; data zustavaji v historii.
        let list = arena.preferences.subjects
        let progress = SubjectProgress.summarize(model.stats.sessionHistory)
            .filter { entry in list.first { $0.id == entry.subject.id }?.isVisible ?? true }
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
                            Text(list.title(of: entry.subject)).font(.fqLabel).foregroundStyle(FQColor.textPrimary)
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

    // MARK: - Bestiar

    private var bestiaryGroups: [BestiaryGroup] { BestiaryGroup.groups(from: model.stats.bestiary) }

    private var bestiaryDetail: String? {
        let total = model.stats.bestiary.reduce(0) { $0 + $1.defeats }
        return total == 0 ? nil : "\(total) defeated"
    }

    /// Porazeni bossove po predmetech, napr. "English: 4x Banana Bandit".
    @ViewBuilder private var bestiaryCard: some View {
        let groups = bestiaryGroups
        if groups.isEmpty {
            Label("Win a battle in the Arena and the boss you beat is recorded here, sorted by subject.", systemImage: "book.closed.fill")
                .font(.fqSecondary)
                .foregroundStyle(FQColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FQSpace.lg)
                .glassCard()
        } else {
            VStack(spacing: FQSpace.md) {
                ForEach(groups) { group in bestiaryGroupCard(group) }
            }
        }
    }

    private func bestiaryGroupCard(_ group: BestiaryGroup) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: FQSpace.sm) {
                Text(group.subject?.title ?? "No subject")
                    .font(.fqHeadline)
                    .foregroundStyle(FQColor.textPrimary)
                Spacer(minLength: FQSpace.sm)
                Text("\(group.totalDefeats)x").font(.fqLabel).monospacedDigit().foregroundStyle(FQColor.accent)
            }
            .padding(.vertical, FQSpace.md)
            .accessibilityElement(children: .combine)
            ForEach(group.entries) { entry in
                HairlineDivider()
                bestiaryRow(entry)
            }
        }
        .padding(.horizontal, FQSpace.lg)
        .padding(.vertical, FQSpace.xs)
        .glassCard()
    }

    private func bestiaryRow(_ entry: BestiaryEntry) -> some View {
        let spriteID = Boss.find(entry.bossID)?.pixelSpriteConfig
        return HStack(spacing: FQSpace.md) {
            Group {
                if let spriteID {
                    PixelArtAvatarView(sprite: .boss(spriteID), size: 32)
                } else {
                    IconTile(symbol: "xmark.shield.fill")
                }
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
            Text(entry.bossName).font(.fqBody).foregroundStyle(FQColor.textPrimary)
            Spacer(minLength: FQSpace.sm)
            Text("\(entry.defeats)x").font(.fqHeadline).monospacedDigit().foregroundStyle(FQColor.textPrimary)
        }
        .padding(.vertical, FQSpace.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.bossName), defeated \(entry.defeats) \(entry.defeats == 1 ? "time" : "times")")
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
                Text(HeroRank.current(forLevel: model.stats.level).title).font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
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

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: FQSpace.xs) {
            Text(value).font(.fqTitle).monospacedDigit().foregroundStyle(FQColor.textPrimary)
            Text(title).font(.fqSecondary).foregroundStyle(FQColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FQSpace.lg)
        .glassCard(radius: FQRadius.control + 4)
        .accessibilityElement(children: .combine)
    }
}
