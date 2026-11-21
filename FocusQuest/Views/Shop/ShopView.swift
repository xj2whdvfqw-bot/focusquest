import SwiftUI

/// Obchod: za mince z bitev se kupuje vybaveni (hned videt na pixelovem hrdinovi) a pozadi.
struct ShopView: View {
    @ObservedObject var model: ProfileViewModel
    @State private var section: ShopSection = .gear
    /// Predmet, ktery si hrac prave zkousi v nahledu nahore.
    @State private var tryOnID: String?
    @Environment(\.shopBackground) private var shopBackground

    enum ShopSection: String, CaseIterable, Identifiable {
        case gear, backgrounds
        var id: String { rawValue }
        var title: String { self == .gear ? "Gear" : "Backgrounds" }
        var heading: String { self == .gear ? "Gear up" : "Change the scenery" }
    }

    private var isBright: Bool { shopBackground?.isBright == true }

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
        // Nadpis je stejny jako na ostatnich zalozkach. Pod nim jsou zalozky obchodu
        // a u vybaveni pripnuty nahled hrdiny, aby bylo vyzkouseni videt i pri rolovani.
        .pinnedTopHeader {
            VStack(alignment: .leading, spacing: FQSpace.md) {
                ScreenHeader(eyebrow: "Shop", title: section.heading)
                sectionTabs
                if section == .gear { previewCard }
            }
        }
        // Nahled pozadi plati jen v obchode.
        .onDisappear { model.previewBackground = nil }
    }

    // MARK: Zalozky

    private var sectionTabs: some View {
        HStack(spacing: 24) {
            ForEach(ShopSection.allCases) { item in
                let selected = item == section
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { section = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 17, weight: selected ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(selected ? FQColor.textPrimary : FQColor.textSecondary)
                        .padding(.horizontal, 2)
                        .frame(height: 44)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(FQColor.textPrimary).frame(height: 2).opacity(selected ? 1 : 0)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
        HStack(spacing: FQSpace.lg) {
            HeroAvatarView(appearance: previewAppearance, heroClass: model.profile.heroClass, size: 72)
                .animation(.easeOut(duration: 0.2), value: previewAppearance)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: FQSpace.xs) {
                Text(tryOn.map { "Trying on \($0.name)" } ?? "Tap an item to try it on")
                    .font(.fqHeadline)
                    .foregroundStyle(FQColor.textPrimary)
                    .lineLimit(2)
                coinsLabel
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
        }
        .padding(FQSpace.md)
        .glassCard()
    }

    private var coinsLabel: some View {
        Label("\(model.profile.coins) coins", systemImage: "dollarsign.circle.fill")
            .font(.fqLabel)
            .monospacedDigit()
            .foregroundStyle(FQColor.accent)
            .contentTransition(.numericText())
    }

    private func itemCard(_ item: EquipmentItem) -> some View {
        let owned = model.owns(item)
        let equipped = model.isEquipped(item)
        let isTryingOn = tryOnID == item.id
        return VStack(alignment: .leading, spacing: FQSpace.sm) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { tryOnID = isTryingOn ? nil : item.id }
            } label: {
                ZStack(alignment: .topTrailing) {
                    // Mini hrdina uz s timto predmetem - je hned videt, jak bude vypadat.
                    HeroAvatarView(appearance: wearing(item), heroClass: model.profile.heroClass, size: 72)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FQSpace.sm)
                        .background(FQColor.fill, in: RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous))
                    if equipped {
                        Image(systemName: "checkmark.circle.fill").font(.fqLabel).foregroundStyle(FQColor.accent).padding(FQSpace.xs)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Try on \(item.name)")
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.fqLabel).foregroundStyle(FQColor.textPrimary).lineLimit(1)
                Text(item.summary).font(.fqMeta).foregroundStyle(FQColor.textSecondary).lineLimit(2, reservesSpace: true)
            }
            gearButton(item, owned: owned, equipped: equipped)
        }
        .padding(FQSpace.md)
        .glassCard(radius: FQRadius.control, tint: isTryingOn ? FQColor.accent : nil)
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
                Label("\(item.price)", systemImage: "dollarsign.circle.fill")
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
            coinsLabel.padding(.horizontal, 4)
            sectionLabel("Free")
            backgroundCard(nil)
            ForEach(ShopBackground.free) { backgroundCard($0) }
            sectionLabel("For coins").padding(.top, FQSpace.sm)
            ForEach(ShopBackground.forCoins) { backgroundCard($0) }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .bold, design: .rounded))
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
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return HStack(alignment: .top, spacing: 14) {
            ShopSceneThumbnail(background: background)
            VStack(alignment: .leading, spacing: 4) {
                Text(background?.name ?? ShopBackground.worldName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(FQColor.textPrimary)
                Text(background?.blurb ?? ShopBackground.worldBlurb)
                    .font(.system(size: 13, design: .rounded))
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
        .padding(10)
        .background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                // Na svetlych pozadich tmave sklo rgba(13,11,28,.40), jinak jemne svetle.
                shape.fill(isBright ? Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255).opacity(0.40) : Color.white.opacity(0.06))
            }
        }
        .overlay {
            shape.strokeBorder(inUse ? FQColor.accent : Color.white.opacity(0.10), lineWidth: inUse ? 2 : 1)
        }
    }

    @ViewBuilder private func backgroundAction(_ background: ShopBackground?, inUse: Bool, owned: Bool) -> some View {
        if inUse {
            Label("In use", systemImage: "checkmark")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(FQColor.accent)
                .frame(minHeight: 36)
        } else if owned {
            Button("Use") { withAnimation(.easeOut(duration: 0.3)) { model.useBackground(background) } }
                .buttonStyle(ShopButtonStyle())
                .accessibilityLabel("Use \(background?.name ?? ShopBackground.worldName)")
        } else if let background {
            let short = background.price - model.profile.coins
            if short > 0 {
                Label("\(background.price) · need \(short) more", systemImage: "dollarsign.circle.fill")
                    .font(.system(size: 13, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textSecondary)
                    .frame(minHeight: 36)
                    .accessibilityLabel("\(background.name) costs \(background.price) coins. You need \(short) more.")
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.3)) { model.buy(background) }
                } label: {
                    Label("Buy for \(background.price)", systemImage: "dollarsign.circle.fill").monospacedDigit()
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

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: fullWidth ? FQRadius.control : 18, style: .continuous)
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
                    shape.strokeBorder(highlighted ? FQColor.accent : Color.white.opacity(0.25), lineWidth: highlighted ? 2 : 1)
                }
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
