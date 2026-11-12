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
/// Pouziva ho Profil i uvodni tvorba hrdiny.
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
                                .background(isSelected ? FQColor.accent : FQColor.fill, in: Capsule())
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

/// Uvodni obrazovka pri prvnim spusteni: hrac si pojmenuje a oblekne hrdinu.
struct HeroCreatorView: View {
    @ObservedObject var model: ProfileViewModel
    let onDone: () -> Void
    @State private var nameDraft = ""

    var body: some View {
        ScreenScaffold {
            ScreenTitle(eyebrow: "Welcome to FocusQuest", title: "Create your hero")
            VStack(spacing: FQSpace.sm) {
                HeroAvatarView(appearance: model.profile.avatar, heroClass: model.profile.heroClass, size: 144)
                Text(model.profile.heroClass.displayName).font(.fqLabel).foregroundStyle(FQColor.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(FQSpace.lg)
            .glassCard()

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

            ScreenSection(title: "Hero class") {
                HStack(spacing: FQSpace.md) {
                    IconTile(symbol: "shield.lefthalf.filled")
                    Text("Class").font(.fqBody).foregroundStyle(FQColor.textPrimary)
                    Spacer(minLength: FQSpace.sm)
                    ValueMenu(title: "Hero class", valueText: model.profile.heroClass.displayName, selection: Binding(get: { model.profile.heroClass }, set: { model.updateHeroClass($0) })) {
                        ForEach(HeroClass.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                .padding(.horizontal, FQSpace.lg)
                .padding(.vertical, FQSpace.xs)
                .glassCard(radius: FQRadius.control)
            }

            ScreenSection(title: "Look") {
                HeroLookEditor(appearance: model.profile.avatar) { model.updateAvatar($0) }
                    .padding(FQSpace.lg)
                    .glassCard()
            }
        }
        .pinnedBottomAction {
            Button { start() } label: {
                Label("Start Adventure", systemImage: "sparkles")
                    .font(.fqHeadline)
                    .foregroundStyle(FQColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FQSpace.xs)
            }
            .prominentGlassButtonStyle()
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(FQColor.accent)
        }
        .onAppear { nameDraft = model.profile.username }
        .interactiveDismissDisabled()
    }

    private func start() {
        let name = nameDraft.trimmingCharacters(in: .whitespaces)
        if name != model.profile.username {
            model.updateUsername(name)
            // Neplatne jmeno: zustaneme na obrazovce, chyba je videt pod polem.
            guard model.profile.username == name else { return }
        }
        model.completeHeroCreation()
        onDone()
    }
}
