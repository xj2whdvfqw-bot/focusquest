import SwiftUI

struct ProfileView: View {
    @ObservedObject var model: ProfileViewModel
    @State private var usernameDraft = ""
    @State private var showsAppearanceEditor = false
    /// Cil behem tazeni posuvniku: kruh a texty se meni zive, ulozi se az po pusteni.
    @State private var goalDraft: Int?

    private var dailyGoal: Int { goalDraft ?? model.profile.dailyFocusGoalMinutes }

    private var dailyProgress: Double {
        Double(model.todayVerifiedMinutes) / Double(max(1, dailyGoal))
    }

    var body: some View {
        ScreenScaffold(scene: .enchantedForest) {
            ScreenHeader(eyebrow: "Hero", title: "Hero profile", gearMark: .gear)
            heroCard
            ScreenSection(title: "Daily focus target") { dailyTargetCard.coachMark(.dailyTarget) }
            ScreenSection(title: "Identity") { identityCard }
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

    /// Jedna kompaktni karta ve 3 sloupcich: avatar se stetcem, jmeno a trida, kruh levelu.
    private var heroCard: some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                HeroAvatarView(appearance: model.profile.avatar, heroClass: model.profile.heroClass, size: 76)
                    .accessibilityHidden(true)
                Button { showsAppearanceEditor = true } label: {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FQColor.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.14), in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                        // Dotykova plocha 44 pt, ale karta kvuli ni nevyroste.
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.fqPress)
                .padding(.vertical, -5)
                .accessibilityLabel("Edit appearance")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(model.profile.username)
                    .fqFont(size: 22, weight: .semibold, design: .rounded)
                    .foregroundStyle(FQColor.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Label(model.profile.heroClass.displayName, systemImage: model.profile.heroClass.symbol)
                    .fqFont(size: 16, weight: .medium, design: .rounded)
                    .foregroundStyle(FQColor.accent)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            LevelBadge(level: model.level, xpInto: model.stats.xpIntoLevel, xpFor: model.stats.xpForNextLevel)
                .padding(.horizontal, -6)
        }
        .padding(FQSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fqCard()
    }

    private var identityCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: FQSpace.md) {
                IconTile(symbol: "at")
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    Text("Username").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                    TextField("Your name", text: $usernameDraft)
                        .font(.fqBody)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { model.updateUsername(usernameDraft) }
                }
                Button { model.updateUsername(usernameDraft) } label: {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(FQColor.accent)
                }
                .buttonStyle(.fqPress)
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
        .fqCard()
    }

    private var dailyTargetCard: some View {
        VStack(spacing: FQSpace.lg) {
            HStack(spacing: FQSpace.lg) {
                // Splnena cast v barve pasku zvolene tridy (stejny token, ze ktereho se kresli pasek hrdiny),
                // nesplnena tlumene seda.
                ProgressRing(progress: dailyProgress, lineWidth: 6, animationDuration: 0.15, tint: Color(rgb: AvatarSprite.classAccent(model.profile.heroClass)), track: Color.white.opacity(0.14)) {
                    Text("\(model.todayVerifiedMinutes)").font(.fqLabel).monospacedDigit().foregroundStyle(FQColor.textPrimary)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    Text("\(dailyGoal) minutes a day").font(.fqHeadline).monospacedDigit().foregroundStyle(FQColor.textPrimary)
                    Text("\(model.todayVerifiedMinutes) of \(dailyGoal) min verified today")
                        .font(.fqSecondary)
                        .monospacedDigit()
                        .foregroundStyle(FQColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
            }
            Slider(
                value: Binding(
                    get: { Double(dailyGoal) },
                    set: { goalDraft = min(180, max(30, Int(($0 / 15).rounded()) * 15)) }
                ),
                in: 30...180,
                step: 15,
                onEditingChanged: { editing in
                    guard !editing, let goal = goalDraft else { return }
                    model.updateDailyGoal(goal)
                    goalDraft = nil
                }
            )
            .tint(FQColor.accent)
            .accessibilityLabel("Daily focus target")
            .accessibilityValue("\(dailyGoal) minutes")
        }
        .padding(FQSpace.lg)
        .fqCard()
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
                .fqCard()
        }
        .pinnedTopHeader { header }
        // Zmeny se ukladaji hned, takze tah dolu muze okno zavrit vzdy.
        .fqSheetDismissal(blocked: false, close: onClose)
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
            // Krizek nahradil tah dolu; VoiceOver zavira akci "Close" nebo escape gestem.
            .fqSheetCloseAction(onClose)
            Spacer(minLength: 0)
        }
        .padding(FQSpace.md)
        .fqCard()
    }
}
