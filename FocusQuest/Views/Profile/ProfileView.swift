import SwiftUI

struct ProfileView: View {
    @ObservedObject var model: ProfileViewModel
    @State private var usernameDraft = ""
    @State private var showsAppearanceEditor = false

    private var dailyProgress: Double {
        Double(model.todayVerifiedMinutes) / Double(max(1, model.profile.dailyFocusGoalMinutes))
    }

    var body: some View {
        ScreenScaffold(scene: .enchantedForest) {
            ScreenHeader(eyebrow: "Profile", title: "Hero profile")
            heroCard
            ScreenSection(title: "Rank & Level") { rankCard }
            ScreenSection(title: "Identity") { identityCard }
            ScreenSection(title: "Daily focus target") { dailyTargetCard }
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.fqSecondary)
                    .foregroundStyle(FQColor.caution)
            }
        }
        .onAppear { usernameDraft = model.profile.username }
        // Editor vzhledu zabiral pul Profilu; ted je v samostatnem listu.
        .sheet(isPresented: $showsAppearanceEditor) {
            AppearanceEditorSheet(model: model) { showsAppearanceEditor = false }
                .presentationDragIndicator(.visible)
        }
        .task { await model.refresh(); await model.refreshProgress() }
    }

    private var heroCard: some View {
        VStack(spacing: FQSpace.lg) {
            HStack(spacing: FQSpace.lg) {
                HeroAvatarView(appearance: model.profile.avatar, heroClass: model.profile.heroClass, size: 88)
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    Text(model.profile.username).font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                    Label(model.profile.heroClass.displayName, systemImage: model.profile.heroClass.symbol)
                        .font(.fqLabel)
                        .foregroundStyle(FQColor.accent)
                    Text("\(model.rank.title) · Level \(model.level)")
                        .font(.fqSecondary)
                        .foregroundStyle(FQColor.textSecondary)
                    Text("\(model.profile.coins) coins").font(.fqMeta).monospacedDigit().foregroundStyle(FQColor.textSecondary)
                }
                Spacer(minLength: 0)
                // Misto je vyhrazene stale, aby karta pri ukladani neposkakovala.
                ProgressView().controlSize(.small).opacity(model.isSaving ? 1 : 0)
            }
            .accessibilityElement(children: .combine)
            Button { showsAppearanceEditor = true } label: {
                Label("Edit Appearance", systemImage: "paintbrush.fill")
                    .font(.fqHeadline)
                    .frame(maxWidth: .infinity)
            }
            .glassButtonStyle()
            .buttonBorderShape(.roundedRectangle(radius: FQRadius.control))
            .controlSize(.large)
            .tint(FQColor.textPrimary)
        }
        .padding(FQSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// Hodnost se nevybira: roste sama s levelem. Karta ukazuje aktualni hodnost,
    /// postup k dalsimu levelu a celou cestu hodnosti.
    private var rankCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: FQSpace.lg) {
                ProgressRing(progress: Double(model.stats.xpIntoLevel) / Double(max(1, model.stats.xpForNextLevel)), lineWidth: 6) {
                    Text("\(model.level)").font(.fqHeadline).monospacedDigit().foregroundStyle(FQColor.textPrimary)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    Text(model.rank.title).font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                    Text("\(model.stats.xpIntoLevel) / \(model.stats.xpForNextLevel) XP to level \(model.level + 1)")
                        .font(.fqMeta)
                        .monospacedDigit()
                        .foregroundStyle(FQColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, FQSpace.md)
            .accessibilityElement(children: .combine)
            Text(nextRankText)
                .font(.fqSecondary)
                .foregroundStyle(FQColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, FQSpace.md)
            ForEach(HeroRank.ladder) { rank in
                HairlineDivider()
                rankRow(rank)
            }
        }
        .padding(.horizontal, FQSpace.lg)
        .padding(.vertical, FQSpace.xs)
        .glassCard()
    }

    private var nextRankText: String {
        guard let next = model.nextRank else { return "You hold the highest rank. Your title grows with every level you earn." }
        return "Your title evolves automatically as you earn XP. Reach level \(next.minimumLevel) to become \(next.title)."
    }

    private func rankRow(_ rank: HeroRank) -> some View {
        let isCurrent = rank == model.rank
        let isReached = model.level >= rank.minimumLevel
        let symbol = isCurrent ? "star.circle.fill" : (isReached ? "checkmark.seal.fill" : "lock.fill")
        return HStack(spacing: FQSpace.md) {
            IconTile(symbol: symbol, color: isReached ? FQColor.accent : FQColor.textSecondary)
            Text(rank.title)
                .font(isCurrent ? Font.fqHeadline : Font.fqBody)
                .foregroundStyle(isReached ? FQColor.textPrimary : FQColor.textSecondary)
            Spacer(minLength: FQSpace.sm)
            Text("Lv \(rank.minimumLevel)").font(.fqMeta).monospacedDigit().foregroundStyle(FQColor.textSecondary)
        }
        .padding(.vertical, FQSpace.sm)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var identityCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: FQSpace.md) {
                IconTile(symbol: "at")
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    Text("Username").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                    TextField("3-20 letters or numbers", text: $usernameDraft)
                        .font(.fqBody)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { model.updateUsername(usernameDraft) }
                }
                Button { model.updateUsername(usernameDraft) } label: {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(FQColor.accent)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Save username")
            }
            .padding(.vertical, FQSpace.sm)
            HairlineDivider()
            HStack(spacing: FQSpace.md) {
                IconTile(symbol: model.profile.heroClass.symbol)
                Text("Hero class").font(.fqBody).foregroundStyle(FQColor.textPrimary)
                Spacer(minLength: FQSpace.sm)
                ValueMenu(title: "Hero class", valueText: model.profile.heroClass.displayName, selection: Binding(get: { model.profile.heroClass }, set: { model.updateHeroClass($0) })) {
                    ForEach(HeroClass.allCases) { Text($0.displayName).tag($0) }
                }
            }
            .padding(.vertical, FQSpace.xs)
        }
        .padding(.horizontal, FQSpace.lg)
        .padding(.vertical, FQSpace.xs)
        .glassCard()
    }

    private var dailyTargetCard: some View {
        VStack(spacing: FQSpace.lg) {
            HStack(spacing: FQSpace.lg) {
                ProgressRing(progress: dailyProgress, lineWidth: 6) {
                    Text("\(model.todayVerifiedMinutes)").font(.fqLabel).monospacedDigit().foregroundStyle(FQColor.textPrimary)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    Text("\(model.profile.dailyFocusGoalMinutes) minutes a day").font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                    Text("\(model.todayVerifiedMinutes) of \(model.profile.dailyFocusGoalMinutes) min verified today")
                        .font(.fqSecondary)
                        .foregroundStyle(FQColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            Slider(
                value: Binding(get: { Double(model.profile.dailyFocusGoalMinutes) }, set: { model.updateDailyGoal(Int($0 / 15) * 15) }),
                in: 30...180,
                step: 15
            )
            .tint(FQColor.accent)
            .accessibilityLabel("Daily focus target")
            .accessibilityValue("\(model.profile.dailyFocusGoalMinutes) minutes")
        }
        .padding(FQSpace.lg)
        .glassCard()
    }
}

/// List s editorem vzhledu (kuze, vlasy, obleceni). Zmeny se ukladaji hned;
/// nahled hrdiny je pripnuty nahore, takze je videt i pri rolovani.
struct AppearanceEditorSheet: View {
    @ObservedObject var model: ProfileViewModel
    let onClose: () -> Void

    var body: some View {
        ScreenScaffold(scene: .enchantedForest) {
            HeroLookEditor(appearance: model.profile.avatar) { model.updateAvatar($0) }
                .padding(FQSpace.lg)
                .glassCard()
        }
        .pinnedTopHeader { header }
    }

    private var header: some View {
        HStack(spacing: FQSpace.lg) {
            HeroAvatarView(appearance: model.profile.avatar, heroClass: model.profile.heroClass, size: 96)
                .animation(.easeOut(duration: 0.2), value: model.profile.avatar)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: FQSpace.xs) {
                Text("Hero look").font(.fqLabel).foregroundStyle(FQColor.textSecondary)
                Text("Edit appearance").font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                Text("Changes save instantly").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(FQColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .glassControl(in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close appearance editor")
        }
        .padding(FQSpace.md)
        .glassCard()
    }
}
