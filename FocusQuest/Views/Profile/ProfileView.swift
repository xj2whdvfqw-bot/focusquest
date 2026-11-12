import SwiftUI

struct ProfileView: View {
    @ObservedObject var model: ProfileViewModel
    @State private var usernameDraft = ""

    private let titles = ["Novice Focuser", "Deep Work Mage", "Grandmaster of Stillness"]
    private var dailyProgress: Double {
        Double(model.todayVerifiedMinutes) / Double(max(1, model.profile.dailyFocusGoalMinutes))
    }

    var body: some View {
        ScreenScaffold {
            ScreenTitle(eyebrow: "Profile", title: "Hero profile")
            heroCard
            ScreenSection(title: "Identity") { identityCard }
            ScreenSection(title: "Hero look") {
                HeroLookEditor(appearance: model.profile.avatar) { model.updateAvatar($0) }
                    .padding(FQSpace.lg)
                    .glassCard()
            }
            ScreenSection(title: "Hero class") { heroClassGrid }
            ScreenSection(title: "Daily focus target") { dailyTargetCard }
            ScreenSection(title: "Relics", detail: "Equip up to 2") { relicsCard }
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.fqSecondary)
                    .foregroundStyle(FQColor.caution)
            }
        }
        .onAppear { usernameDraft = model.profile.username }
        .task { await model.refresh(); await model.refreshProgress() }
    }

    private var heroCard: some View {
        HStack(spacing: FQSpace.lg) {
            HeroAvatarView(appearance: model.profile.avatar, heroClass: model.profile.heroClass, size: 88)
            VStack(alignment: .leading, spacing: FQSpace.xs) {
                Text(model.profile.username).font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                Text(model.profile.title).font(.fqSecondary).foregroundStyle(FQColor.textSecondary)
                Text(model.profile.heroClass.displayName).font(.fqMeta.weight(.medium)).foregroundStyle(FQColor.accent)
                Text("Level \(model.level) · \(model.profile.coins) coins").font(.fqMeta).monospacedDigit().foregroundStyle(FQColor.textSecondary)
            }
            Spacer(minLength: 0)
            // Misto je vyhrazene stale, aby karta pri ukladani neposkakovala.
            ProgressView().controlSize(.small).opacity(model.isSaving ? 1 : 0)
        }
        .padding(FQSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
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
                IconTile(symbol: "rosette")
                Text("Title").font(.fqBody).foregroundStyle(FQColor.textPrimary)
                Spacer(minLength: FQSpace.sm)
                ValueMenu(title: "Title", valueText: model.profile.title, selection: Binding(get: { model.profile.title }, set: { model.updateTitle($0) })) {
                    ForEach(titles, id: \.self) { Text($0).tag($0) }
                }
            }
            .padding(.vertical, FQSpace.xs)
        }
        .padding(.horizontal, FQSpace.lg)
        .padding(.vertical, FQSpace.xs)
        .glassCard()
    }

    private var heroClassGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: FQSpace.md), GridItem(.flexible())], spacing: FQSpace.md) {
            ForEach(HeroClass.allCases) { hero in
                let isSelected = hero == model.profile.heroClass
                Button { model.updateHeroClass(hero) } label: {
                    VStack(spacing: FQSpace.sm) {
                        HeroAvatarView(appearance: model.profile.avatar, heroClass: hero, size: 56)
                        Text(hero.displayName).font(.fqLabel).foregroundStyle(FQColor.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(FQSpace.md)
                    .glassCard(radius: FQRadius.control, tint: isSelected ? FQColor.accent : nil)
                    .overlay {
                        RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous)
                            .strokeBorder(isSelected ? FQColor.accent : Color.clear, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
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

    private var relicsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(LootItem.catalog.enumerated()), id: \.element.id) { index, item in
                let isEquipped = model.profile.equippedLootIDs.contains(item.id)
                let isUnlocked = model.profile.unlockedLootIDs.contains(item.id)
                if index > 0 { HairlineDivider() }
                Button { model.toggleLoot(item.id) } label: {
                    HStack(spacing: FQSpace.md) {
                        IconTile(symbol: isEquipped ? "checkmark.seal.fill" : (isUnlocked ? "seal" : "lock.fill"), color: isEquipped ? FQColor.accent : FQColor.textSecondary)
                        VStack(alignment: .leading, spacing: FQSpace.xs) {
                            Text(item.name).font(.fqBody).foregroundStyle(FQColor.textPrimary)
                            Text(item.description).font(.fqSecondary).foregroundStyle(FQColor.textSecondary)
                        }
                        Spacer(minLength: FQSpace.sm)
                        Text(item.rarity.rawValue.capitalized).font(.fqMeta.weight(.medium)).foregroundStyle(FQColor.textSecondary)
                    }
                    .padding(.vertical, FQSpace.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isUnlocked && !isEquipped)
                .opacity(isUnlocked || isEquipped ? 1 : 0.55)
            }
        }
        .padding(.horizontal, FQSpace.lg)
        .padding(.vertical, FQSpace.xs)
        .glassCard()
    }
}
