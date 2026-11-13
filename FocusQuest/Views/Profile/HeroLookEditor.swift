import SwiftUI

/// Volba, ktera se v editoru ukazuje jako barevne kolecko.
protocol SwatchOption: Identifiable, Equatable {
    var rgb: RGB { get }
    var displayName: String { get }
}

extension SkinTone: SwatchOption { }
extension HairColor: SwatchOption { }
extension GearColor: SwatchOption { }

/// Editor vzhledu hrdiny: kuze, uces, barva vlasu, obleceni a boty.
/// Pouziva ho list Upravit vzhled v Profilu i uvodni tvorba hrdiny.
struct HeroLookEditor: View {
    let appearance: AvatarAppearance
    let onChange: (AvatarAppearance) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FQSpace.md) {
            swatchRow("Skin", options: SkinTone.allCases, selected: appearance.skin) { value in change { $0.skin = value } }
            HairlineDivider()
            hairStyleRow
            swatchRow("Hair color", options: HairColor.allCases, selected: appearance.hairColor) { value in change { $0.hairColor = value } }
                .disabled(appearance.hairStyle == .bald)
                .opacity(appearance.hairStyle == .bald ? 0.4 : 1)
            HairlineDivider()
            swatchRow("Outfit", options: GearColor.allCases, selected: appearance.outfitColor) { value in change { $0.outfitColor = value } }
            swatchRow("Boots", options: GearColor.allCases, selected: appearance.bootsColor) { value in change { $0.bootsColor = value } }
        }
    }

    private func change(_ edit: (inout AvatarAppearance) -> Void) {
        var copy = appearance
        edit(&copy)
        onChange(copy)
    }

    private var hairStyleRow: some View {
        VStack(alignment: .leading, spacing: FQSpace.xs) {
            Text("Hair style").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FQSpace.sm) {
                    ForEach(HairStyle.allCases) { style in
                        let isSelected = style == appearance.hairStyle
                        Button { change { $0.hairStyle = style } } label: {
                            Text(style.displayName)
                                .font(.fqLabel)
                                .foregroundStyle(isSelected ? FQColor.onAccent : FQColor.textPrimary)
                                .padding(.horizontal, FQSpace.lg)
                                .frame(minHeight: 36)
                                .background(isSelected ? FQColor.accent : FQColor.fill, in: RoundedRectangle(cornerRadius: FQRadius.tile, style: .continuous))
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Hair style \(style.displayName)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func swatchRow<Option: SwatchOption>(_ title: String, options: [Option], selected: Option, select: @escaping (Option) -> Void) -> some View {
        VStack(alignment: .leading, spacing: FQSpace.xs) {
            Text(title).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(options) { option in
                        let isSelected = option == selected
                        Button { select(option) } label: {
                            Circle()
                                .fill(Color(rgb: option.rgb))
                                .frame(width: 28, height: 28)
                                .overlay { Circle().strokeBorder(FQColor.hairline, lineWidth: 1) }
                                .padding(FQSpace.xs)
                                .overlay { Circle().strokeBorder(isSelected ? FQColor.accent : Color.clear, lineWidth: 2) }
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(title) \(option.displayName)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
    }
}

/// Uvodni obrazovka pri prvnim spusteni: cil, hrdina a appky, ktere hrace rozptyluji.
struct HeroCreatorView: View {
    @ObservedObject var model: ProfileViewModel
    @ObservedObject var blocker: AppBlockerManager
    let onDone: () -> Void
    @State private var nameDraft = ""
    @State private var goals: Set<FocusGoal> = []

    var body: some View {
        ScreenScaffold(scene: .enchantedForest) {
            ScreenSection(title: "Hero name") {
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    TextField("3-20 letters or numbers", text: $nameDraft)
                        .font(.fqBody)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .frame(minHeight: 44)
                    if let error = model.errorMessage {
                        Text(error).font(.fqMeta).foregroundStyle(FQColor.caution)
                    }
                }
                .padding(.horizontal, FQSpace.lg)
                .padding(.vertical, FQSpace.xs)
                .glassCard(radius: FQRadius.control)
            }

            ScreenSection(title: "What do you want to change?", detail: "Pick any") { goalList }

            ScreenSection(title: "Choose your class") { classGrid }

            ScreenSection(title: "Look") {
                HeroLookEditor(appearance: model.profile.avatar) { model.updateAvatar($0) }
                    .padding(FQSpace.lg)
                    .glassCard()
            }

            ScreenSection(title: "Apps that distract you", detail: blocker.selectedAppIDs.isEmpty ? nil : "\(blocker.selectedAppIDs.count) selected") { appPicker }
        }
        // Nahled hrdiny je pripnuty nahore, takze je videt i pri rolovani barev a uceu.
        .pinnedTopHeader { avatarHeader }
        .pinnedBottomAction {
            Button { start() } label: {
                Label("Start Adventure", systemImage: "sparkles")
                    .font(.fqHeadline)
                    .foregroundStyle(FQColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FQSpace.xs)
            }
            .prominentGlassButtonStyle()
            .buttonBorderShape(.roundedRectangle(radius: FQRadius.control))
            .controlSize(.large)
            .tint(FQColor.accent)
        }
        .onAppear {
            nameDraft = model.profile.username
            goals = Set(model.profile.focusGoals)
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Cile

    private var goalList: some View {
        VStack(spacing: 0) {
            ForEach(Array(FocusGoal.allCases.enumerated()), id: \.element) { index, goal in
                if index > 0 { HairlineDivider() }
                goalRow(goal)
            }
        }
        .padding(.horizontal, FQSpace.lg)
        .padding(.vertical, FQSpace.xs)
        .glassCard()
    }

    private func goalRow(_ goal: FocusGoal) -> some View {
        let isSelected = goals.contains(goal)
        return Button {
            if isSelected { goals.remove(goal) } else { goals.insert(goal) }
        } label: {
            HStack(spacing: FQSpace.md) {
                IconTile(symbol: goal.symbol)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title).font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                    Text(goal.detail)
                        .font(.fqMeta)
                        .foregroundStyle(FQColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: FQSpace.sm)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? FQColor.accent : FQColor.textSecondary)
            }
            .padding(.vertical, FQSpace.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Appky (zatim maketa bez FamilyControls)

    private var appPicker: some View {
        VStack(alignment: .leading, spacing: FQSpace.md) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: FQSpace.sm), count: 3), spacing: FQSpace.sm) {
                ForEach(AppBlockerManager.catalog) { app in appTile(app) }
            }
            Label("Real app blocking arrives in a later update. Until then, leaving FocusQuest mid-battle for more than \(Int(AppBlockerManager.gracePeriod)) seconds fails the quest.", systemImage: "info.circle")
                .font(.fqMeta)
                .foregroundStyle(FQColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FQSpace.lg)
        .glassCard()
    }

    private func appTile(_ app: BlockableApp) -> some View {
        let isSelected = blocker.isSelected(app)
        return Button { blocker.toggle(app) } label: {
            VStack(spacing: FQSpace.xs) {
                Image(systemName: isSelected ? "lock.fill" : app.symbol)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? FQColor.onAccent : FQColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? FQColor.accent : FQColor.fill, in: RoundedRectangle(cornerRadius: FQRadius.tile, style: .continuous))
                Text(app.name)
                    .font(.fqMeta)
                    .foregroundStyle(isSelected ? FQColor.textPrimary : FQColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(app.name)
        .accessibilityValue(isSelected ? "Blocked during battles" : "Not blocked")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Povolani jako karty s nahledem hrdiny a kratkym popisem.
    private var classGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: FQSpace.md), GridItem(.flexible())], spacing: FQSpace.md) {
            ForEach(HeroClass.allCases) { hero in classCard(hero) }
        }
    }

    private func classCard(_ hero: HeroClass) -> some View {
        let isSelected = hero == model.profile.heroClass
        return Button { model.updateHeroClass(hero) } label: {
            VStack(alignment: .leading, spacing: FQSpace.sm) {
                HStack(alignment: .top) {
                    HeroAvatarView(appearance: model.profile.avatar, heroClass: hero, size: 56)
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : hero.symbol)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? FQColor.accent : FQColor.textSecondary)
                }
                Text(hero.displayName).font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                Text(hero.tagline)
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .padding(FQSpace.md)
            .glassCard(radius: FQRadius.control, tint: isSelected ? FQColor.accent : nil)
            .overlay {
                RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous)
                    .strokeBorder(isSelected ? FQColor.accent : Color.clear, lineWidth: 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hero.displayName). \(hero.tagline)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var avatarHeader: some View {
        HStack(spacing: FQSpace.lg) {
            HeroAvatarView(appearance: model.profile.avatar, heroClass: model.profile.heroClass, size: 112)
            VStack(alignment: .leading, spacing: FQSpace.xs) {
                Text("Welcome to FocusQuest").font(.fqLabel).foregroundStyle(FQColor.textSecondary)
                Text("Create your hero").font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                Text(nameDraft.isEmpty ? model.profile.heroClass.displayName : "\(nameDraft) · \(model.profile.heroClass.displayName)")
                    .font(.fqLabel)
                    .foregroundStyle(FQColor.accent)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(FQSpace.md)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func start() {
        let name = nameDraft.trimmingCharacters(in: .whitespaces)
        if name != model.profile.username {
            model.updateUsername(name)
            // Neplatne jmeno: zustaneme na obrazovce, chyba je videt pod polem.
            guard model.profile.username == name else { return }
        }
        model.updateFocusGoals(goals)
        model.completeHeroCreation()
        onDone()
    }
}
