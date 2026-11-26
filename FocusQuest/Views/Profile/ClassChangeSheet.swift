import SwiftUI

extension HeroClass {
    /// "a Mage", "an Archer" (potvrzeni zmeny tridy).
    var withArticle: String {
        self == .archer ? "an \(displayName)" : "a \(displayName)"
    }
}

/// S1/M4: vyber tridy: tytez karty (cipy) v onboardingu ("Create your hero") i v listu Class Potion.
struct HeroClassPicker: View {
    @Binding var selection: HeroClass

    var body: some View {
        FadingHorizontalScroll {
            HStack(spacing: FQSpace.sm) {
                ForEach(HeroClass.allCases) { heroClass in
                    FQChip(title: heroClass.displayName, isSelected: heroClass == selection, compact: true) {
                        selection = heroClass
                    }
                    .accessibilityLabel("Class \(heroClass.displayName)")
                }
            }
        }
    }
}

/// S1/M4: list s vyberem nove tridy po koupi nebo pouziti Class Potion (a v Debug buildu zdarma z Nastaveni).
/// Nahore nahled hrdiny ve vybrane tride (s vychozi zbrani nove tridy), pod nim tytez karty trid jako v onboardingu.
/// Potvrzeni "Become a Mage?" upozorni, ze se lektvar spotrebuje; zruseni ani zavreni listu ho nespotrebuje.
struct ClassChangeSheet: View {
    enum Mode {
        /// Za Class Potion (spotrebuje se potvrzenim).
        case potion
        /// Debug "Change class (free)" v Nastaveni.
        case debugFree
    }

    @ObservedObject var model: ProfileViewModel
    let mode: Mode
    let onClose: () -> Void
    @State private var choice: HeroClass?
    @State private var confirming = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var current: HeroClass { model.profile.heroClass }
    private var selected: HeroClass { choice ?? current }

    /// Nahled: po zmene tridy drzi hrdina vychozi zbran nove tridy, ostatni sloty zustanou.
    private var preview: AvatarAppearance {
        var look = model.profile.avatar
        if selected != current { look.equip(nil, in: .mainHand) }
        return look
    }

    var body: some View {
        ScreenScaffold(scene: .enchantedForest) {
            VStack(alignment: .leading, spacing: FQSpace.md) {
                Text("New class").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                HeroClassPicker(selection: Binding(get: { selected }, set: { choice = $0 }))
                Text(selected.tagline)
                    .font(.fqBody)
                    .foregroundStyle(FQColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(note)
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(FQSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fqCard()
            Button {
                confirming = true
            } label: {
                Text(selected == current ? "Pick a new class" : "Become \(selected.withArticle)")
            }
            .buttonStyle(ShopCTAButtonStyle(fullWidth: true))
            .disabled(selected == current || (mode == .potion && model.profile.classPotions == 0))
        }
        .pinnedTopHeader { header }
        // Zavreni (tah dolu) lektvar nespotrebuje.
        .fqSheetDismissal(blocked: false, close: onClose)
        .alert("Become \(selected.withArticle)?", isPresented: $confirming) {
            Button("Become \(selected.withArticle)") {
                if model.changeClass(to: selected, usingPotion: mode == .potion) { onClose() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
    }

    private var note: String {
        switch mode {
        case .potion: "Your Class Potion is used up only when you confirm. Weapons you bought stay yours."
        case .debugFree: "Debug: changes the class for free, no potion used."
        }
    }

    private var confirmMessage: String {
        let weapon = EquipmentItem.defaultWeapon(for: selected).name
        switch mode {
        case .potion: return "Your Class Potion will be used up. Your hero starts with the \(weapon); weapons you bought stay yours."
        case .debugFree: return "Debug: free change. Your hero starts with the \(weapon)."
        }
    }

    private var header: some View {
        HStack(spacing: FQSpace.lg) {
            HeroAvatarView(appearance: preview, heroClass: selected, size: 96, outlined: true)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: selected)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: FQSpace.xs) {
                Text(mode == .potion ? "Class Potion" : "Debug").font(.fqLabel).foregroundStyle(FQColor.textSecondary)
                Text("Change class").font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                Text("Now: \(current.displayName)").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .fqSheetCloseAction(onClose)
            Spacer(minLength: 0)
        }
        .padding(FQSpace.md)
        .fqCard()
    }
}
