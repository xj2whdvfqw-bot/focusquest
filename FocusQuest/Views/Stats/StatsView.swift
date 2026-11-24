import SwiftUI

/// Stats: "Your progress". Sekce Habits (mrizka dni), metriky v jedne sklenene karte a Subjects.
/// Bestiar a battle log tu nejsou (data zustavaji v PlayerStats).
struct StatsView: View {
    @ObservedObject var model: StatsViewModel
    /// Seznam predmetu hrace (nazvy po prejmenovani, skryte, smazane) a sprava "Your focus list".
    @ObservedObject var arena: ArenaViewModel
    /// B4: hrdina a jmeno pro obrazek ke sdileni.
    @ObservedObject var profile: ProfileViewModel
    /// "▶ Start a battle" v prazdnem stavu: Arena s otevrenym Fight sheetem.
    let onStartBattle: () -> Void
    @State private var showsSubjectManager = false
    /// B4: nahled sdileni statistik.
    @State private var showsShare = false

    private enum Layout {
        static let cardPadding: CGFloat = 16
        static let metricsInset: CGFloat = 8
        static let startHeight: CGFloat = 50
    }

    var body: some View {
        ScreenScaffold(scene: .starlitPeaks) {
            ScreenHeader(eyebrow: "Stats", title: "Your progress", onShare: { showsShare = true })
            habitsSection
            metricsCard
            // C5: pod cisly, at kroky tutorialu (Habits, cisla) zustanou nahore.
            WeeklyQuestsCard(profile: profile)
            subjectsSection
            BattleLogSection(history: model.stats.sessionHistory, subjects: arena.preferences.subjects)
        }
        .task { await model.load() }
        .sheet(isPresented: $showsSubjectManager) { SubjectManagerView(model: arena) }
        .sheet(isPresented: $showsShare) {
            StatsShareSheet(snapshot: ShareSnapshot.make(stats: model.stats, profile: profile.profile, greetingName: profile.greetingName, frozenDayKeys: profile.frozenDayKeys)) {
                showsShare = false
            }
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Habits

    private var habitsSection: some View {
        let grid = HabitGrid.make(history: model.stats.sessionHistory, firstDay: profile.profile.firstUseDate, frozenDayKeys: profile.frozenDayKeys)
        let days = grid.focusDays
        return ScreenSection(title: "Habits", detail: "\(days) focus \(days == 1 ? "day" : "days")") {
            HabitsCard(grid: grid)
                .coachMark(.habits)
        }
    }

    // MARK: - Metriky

    private var focusHours: String {
        String(format: "%.1f", Double(model.stats.sessionHistory.reduce(0) { $0 + max(0, $1.verifiedMinutes) }) / 60)
    }

    private var longestStreak: String {
        let days = model.stats.longestStreak()
        return "\(days) \(days == 1 ? "day" : "days")"
    }

    /// Ctyri metriky v jedne sklenene karte, bez vnitrnich ramecku.
    private var metricsCard: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
            metric("Win rate", value: "\(Int((model.stats.winRate * 100).rounded()))%")
            metric("Bosses beaten", value: "\(model.stats.bossesBeaten)")
            metric("Longest streak", value: longestStreak)
            metric("Focus hours", value: focusHours)
        }
        .padding(Layout.metricsInset)
        .fqCard()
        .coachMark(.statNumbers)
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .fqFont(size: 22, weight: .semibold, design: .rounded)
                .monospacedDigit()
                .foregroundStyle(FQColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .fqFont(size: 13, design: .rounded)
                .foregroundStyle(FQColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Layout.cardPadding)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Predmety

    /// Minuty po predmetech bez skrytych a smazanych (jejich data zustavaji v historii).
    private var subjectProgress: [SubjectProgress] {
        let list = arena.preferences.subjects
        return SubjectProgress.summarize(model.stats.sessionHistory)
            .filter { entry in list.first { $0.id == entry.subject.id }?.isVisible ?? true }
    }

    private var subjectsSection: some View {
        let progress = subjectProgress
        let list = arena.preferences.subjects
        return VStack(alignment: .leading, spacing: FQSpace.sm) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Focus")
                if !list.isEmpty {
                    Button("Edit focus list") { showsSubjectManager = true }
                        .fqFont(size: 14, weight: .medium, design: .rounded)
                        .underline()
                        .foregroundStyle(FQColor.textSecondary)
                        .frame(minHeight: 44)
                        .padding(.trailing, FQSpace.xs)
                        .buttonStyle(.fqPress)
                }
            }
            if progress.isEmpty {
                emptyState("Pick what you're focusing on before a battle to track your time here.")
            } else {
                VStack(spacing: 12) {
                    ForEach(progress) { entry in
                        HStack(spacing: FQSpace.sm) {
                            Text(list.title(of: entry.subject))
                                .fqFont(size: 15, weight: .medium, design: .rounded)
                                .foregroundStyle(FQColor.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: FQSpace.sm)
                            Text("\(ArenaView.durationText(minutes: entry.minutes)) · \(entry.battles) \(entry.battles == 1 ? "battle" : "battles")")
                                .fqFont(size: 13, design: .rounded)
                                .monospacedDigit()
                                .foregroundStyle(FQColor.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(Layout.cardPadding)
                .fqCard()
            }
        }
    }

    // MARK: - Prazdny stav

    /// Vycentrovany text a velke zlute "▶ Start a battle".
    private func emptyState(_ text: String) -> some View {
        VStack(spacing: 12) {
            Text(text)
                .fqFont(size: 15, design: .rounded)
                .foregroundStyle(FQColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            Button(action: onStartBattle) {
                Label("Start a battle", systemImage: "play.fill")
                    .fqFont(size: 17, weight: .bold, design: .rounded)
                    .foregroundStyle(FQColor.onCta)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.startHeight)
                    .background(FQColor.cta, in: FQRadius.shape(FQRadius.inCard))
                    .compositingGroup()
            }
            .buttonStyle(.fqPress)
        }
        .padding(Layout.cardPadding)
        .fqCard()
    }
}
