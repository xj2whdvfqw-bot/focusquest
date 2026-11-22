import SwiftUI

/// Obchod: za mince z bitev se kupuje vybaveni (hned videt na pixelovem hrdinovi) a pozadi.
struct ShopView: View {
    @ObservedObject var model: ProfileViewModel
    /// Gear nebo Backgrounds; drzi ho MainTabView, aby Nastaveni mohlo otevrit Backgrounds.
    @Binding var section: ShopSection
    /// Predmet, ktery si hrac prave zkousi v nahledu nahore.
    @State private var tryOnID: String?
    /// Podtrzitko vybrane zalozky obchodu klouze mezi Gear a Backgrounds.
    @Namespace private var tabUnderline
    @Environment(\.shopBackground) private var shopBackground
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum ShopSection: String, CaseIterable, Identifiable {
        case gear, backgrounds
        var id: String { rawValue }
        var title: String { self == .gear ? "Gear" : "Backgrounds" }
    }


    private var tryOn: EquipmentItem? { tryOnID.flatMap(EquipmentItem.item(withID:)) }

    /// Hrdina tak, jak by vypadal s vyzkousenym predmetem.
    private var previewAppearance: AvatarAppearance {
        var appearance = model.profile.avatar
        if let tryOn { appearance.equip(tryOn.id, in: tryOn.slot) }
        return appearance
    }

    var body: some View {
        ScreenScaffold(scene: .lanternGrove) {
            switch section {
            case .gear: gearList
            case .backgrounds: backgroundList
            }
        }
        // Kompaktni hlavicka bez velkeho nadpisu: maly stitek "Shop", mince a ozubene kolo,
        // pod tim zalozky obchodu a u vybaveni pripnuty nahled hrdiny (vyzkouseni je videt i pri rolovani).
        .pinnedTopHeader {
            VStack(alignment: .leading, spacing: FQSpace.sm) {
                HStack(spacing: FQSpace.md) {
                    Text("Shop")
                        .font(.fqLabel)
                        .foregroundStyle(FQColor.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: FQSpace.sm)
                    coinsLabel
                    SettingsGearButton()
                }
                sectionTabs
                if section == .gear {
                    previewCard.transition(.opacity)
                }
            }
        }
        // Nahled pozadi plati jen v obchode.
        .onDisappear { model.previewBackground = nil }
        // Nakup: zvuk mince a vibrace uspechu (klik a vibraci pri klepnuti dava styl tlacitek).
        .fqHaptic(.success, trigger: model.profile.coins) { old, new in new < old }
        .fqSound(.coin, trigger: model.profile.coins) { old, new in new < old }
    }

    // MARK: Zalozky

    private var sectionTabs: some View {
        HStack(spacing: 24) {
            ForEach(ShopSection.allCases) { item in
                let selected = item == section
                Button {
                    withAnimation(FQMotion.spring(reduceMotion: reduceMotion)) { section = item }
                } label: {
                    Text(item.title)
                        .fqFont(size: 17, weight: selected ? .semibold : .medium, design: .rounded)
                        .foregroundStyle(selected ? FQColor.textPrimary : FQColor.textSecondary)
                        .padding(.horizontal, 2)
                        .frame(height: 44)
                        .overlay(alignment: .bottom) {
                            // Jedno podtrzitko, ktere pri prepnuti klouze na druhou zalozku.
                            if selected {
                                Rectangle()
                                    .fill(FQColor.textPrimary)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "underline", in: tabUnderline)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.fqPress)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(FQColor.hairline).frame(height: 1) }
    }

    // MARK: Vybaveni

    private var gearList: some View {
        ForEach(EquipmentSlot.shopOrder, id: \.self) { slot in
            ScreenSection(title: slot.displayName) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: FQSpace.md), GridItem(.flexible())], spacing: FQSpace.md) {
                    ForEach(EquipmentItem.catalog.filter { $0.slot == slot }) { itemCard($0) }
                }
            }
        }
    }

    private var previewCard: some View {
        // Kompaktni: mensi hrdina a jeden radek textu, aby zbylo vic mista na predmety.
        HStack(spacing: FQSpace.md) {
            HeroAvatarView(appearance: previewAppearance, heroClass: model.profile.heroClass, size: 52)
                .animation(FQMotion.quick, value: previewAppearance)
                .accessibilityHidden(true)
            Text(tryOn.map { "Trying on \($0.name)" } ?? "Tap an item to try it on")
                .font(.fqLabel)
                .foregroundStyle(FQColor.textPrimary)
                .lineLimit(2)
                .contentTransition(.opacity)
                .animation(FQMotion.quick, value: tryOnID)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, FQSpace.md)
        .padding(.vertical, FQSpace.sm)
        .fqCard()
    }

    private var coinsLabel: some View {
        CoinLabel("\(model.profile.coins) coins")
            .font(.fqLabel)
            .monospacedDigit()
            .foregroundStyle(FQColor.textPrimary)
            .contentTransition(.numericText())
    }

    private func itemCard(_ item: EquipmentItem) -> some View {
        let owned = model.owns(item)
        let equipped = model.isEquipped(item)
        let isTryingOn = tryOnID == item.id
        return VStack(alignment: .leading, spacing: FQSpace.sm) {
            Button {
                withAnimation(FQMotion.spring(reduceMotion: reduceMotion)) { tryOnID = isTryingOn ? nil : item.id }
            } label: {
                // Mini hrdina uz s timto predmetem - je hned videt, jak bude vypadat.
                HeroAvatarView(appearance: wearing(item), heroClass: model.profile.heroClass, size: 72)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FQSpace.sm)
                    .background(FQColor.fill, in: FQRadius.shape(FQRadius.inSmallCard))
            }
            .buttonStyle(.fqPress)
            .accessibilityLabel("Try on \(item.name)")
            .accessibilityAddTraits(isTryingOn ? .isSelected : [])
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.fqLabel).foregroundStyle(FQColor.textPrimary).lineLimit(1)
                Text(item.summary).font(.fqMeta).foregroundStyle(FQColor.textSecondary).lineLimit(2, reservesSpace: true)
            }
            gearButton(item, owned: owned, equipped: equipped)
        }
        .padding(FQSpace.md)
        // Stejna karta jako Backgrounds; nasazeny predmet ma jen bily okraj (bez fajfky).
        .fqCard(selected: equipped)
        .accessibilityElement(children: .contain)
        .accessibilityValue(equipped ? "Equipped" : "")
        // Zkouseny predmet se jemne zvedne (s Reduce Motion beze zmeny).
        .scaleEffect(isTryingOn && !reduceMotion ? 1.02 : 1)
    }

    @ViewBuilder private func gearButton(_ item: EquipmentItem, owned: Bool, equipped: Bool) -> some View {
        if owned {
            Button { withAnimation(.easeOut(duration: 0.2)) { model.toggleEquip(item); tryOnID = nil } } label: {
                Text(equipped ? "Unequip" : "Equip").frame(maxWidth: .infinity)
            }
            .buttonStyle(ShopButtonStyle(fullWidth: true))
        } else {
            let affordable = model.canAfford(item)
            Button { withAnimation(.easeOut(duration: 0.2)) { model.buy(item); tryOnID = nil } } label: {
                CoinLabel("\(item.price)")
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ShopButtonStyle(fullWidth: true))
            .disabled(!affordable)
            .accessibilityLabel(affordable ? "Buy \(item.name) for \(item.price) coins" : "\(item.name) costs \(item.price) coins, not enough coins")
        }
    }

    private func wearing(_ item: EquipmentItem) -> AvatarAppearance {
        var appearance = model.profile.avatar
        appearance.equip(item.id, in: item.slot)
        return appearance
    }

    // MARK: Pozadi

    private var backgroundList: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Free")
            backgroundCard(nil)
            ForEach(ShopBackground.free) { backgroundCard($0) }
            sectionLabel("For coins").padding(.top, FQSpace.sm)
            ForEach(ShopBackground.forCoins) { backgroundCard($0) }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .fqFont(size: 13, weight: .bold, design: .rounded)
            .tracking(0.8)
            .foregroundStyle(FQColor.textSecondary)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }

    /// Karta pozadi: nahled, jmeno, popisek, tlacitko (Use / In use / Buy for N / need N more) a Preview.
    /// `background` nil = World scenes.
    private func backgroundCard(_ background: ShopBackground?) -> some View {
        let inUse = model.selectedBackground == background
        let owned = background.map { model.owns($0) } ?? true
        let previewing = background != nil && model.previewBackground == background
        return HStack(alignment: .top, spacing: 14) {
            ShopSceneThumbnail(background: background)
            VStack(alignment: .leading, spacing: 4) {
                Text(background?.name ?? ShopBackground.worldName)
                    .fqFont(size: 16, weight: .semibold, design: .rounded)
                    .foregroundStyle(FQColor.textPrimary)
                Text(background?.blurb ?? ShopBackground.worldBlurb)
                    .fqFont(size: 13, design: .rounded)
                    .foregroundStyle(FQColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: FQSpace.sm)
                VStack(alignment: .leading, spacing: 8) {
                    backgroundAction(background, inUse: inUse, owned: owned)
                    if let background, !owned {
                        Button {
                            withAnimation(.easeOut(duration: 0.3)) { model.previewBackground = previewing ? nil : background }
                        } label: {
                            Text(previewing ? "Stop preview" : "Preview")
                        }
                        .buttonStyle(ShopButtonStyle(outlined: true, highlighted: previewing))
                        .accessibilityHint("Shows this background behind every screen until you leave the shop")
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(.vertical, 4)
        }
        .padding(FQRadius.Inset.backgroundCard)
        // Vzor jednotne karty appky (fqCard); pouzivane pozadi ma jen bily okraj.
        .fqCard(selected: inUse)
    }

    @ViewBuilder private func backgroundAction(_ background: ShopBackground?, inUse: Bool, owned: Bool) -> some View {
        if inUse {
            Text("In use")
                .fqFont(size: 14, weight: .semibold, design: .rounded)
                .foregroundStyle(FQColor.textSecondary)
                .frame(minHeight: 36)
        } else if owned {
            Button("Use") { withAnimation(.easeOut(duration: 0.3)) { model.useBackground(background) } }
                .buttonStyle(ShopButtonStyle())
                .accessibilityLabel("Use \(background?.name ?? ShopBackground.worldName)")
        } else if let background {
            let short = background.price - model.profile.coins
            if short > 0 {
                CoinLabel("\(background.price) · need \(short) more")
                    .fqFont(size: 13, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textSecondary)
                    .frame(minHeight: 36)
                    .accessibilityLabel("\(background.name) costs \(background.price) coins. You need \(short) more.")
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.3)) { model.buy(background) }
                } label: {
                    CoinLabel("Buy for \(background.price)").monospacedDigit()
                }
                .buttonStyle(ShopButtonStyle())
                .accessibilityLabel("Buy \(background.name) for \(background.price) coins")
            }
        }
    }
}

/// Tlacitka obchodu: nikdy zluta. Pozadi bila 14 %, bily text; obrysova varianta pro Preview.
struct ShopButtonStyle: ButtonStyle {
    var fullWidth = false
    var outlined = false
    var highlighted = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        // Plna sirka = spodek karty predmetu, jinak tlacitko v karte pozadi (soustredne s kartou).
        let shape = FQRadius.shape(fullWidth ? FQRadius.inSmallCard : FQRadius.inBackgroundCard)
        let border: CGFloat = highlighted ? 2 : 1
        return configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(highlighted ? FQColor.accent : (isEnabled ? Color.white : FQColor.textSecondary))
            .padding(.horizontal, 14)
            .frame(minHeight: fullWidth ? 40 : 36)
            .background {
                if !outlined { shape.fill(Color.white.opacity(configuration.isPressed ? 0.22 : 0.14)) }
            }
            .overlay {
                if outlined {
                    // Obrys uvnitr tvaru (AnyShape neumi strokeBorder).
                    shape.stroke(highlighted ? FQColor.accent : Color.white.opacity(0.25), lineWidth: border).padding(border / 2)
                }
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.6)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .modifier(TapFeedback(isPressed: configuration.isPressed))
    }
}

/// Castka v mincich: zlata ikona mince a text v barve okoli (mince nikdy nejsou tyrkysove).
struct CoinLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(FQColor.coin)
                .accessibilityHidden(true)
        }
    }
}
