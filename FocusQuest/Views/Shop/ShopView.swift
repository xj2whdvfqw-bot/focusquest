import SwiftUI

/// Obe casti jednoho obchodu: vybaveni hrdiny a stavby ve vesnici.
enum ShopSection: String, CaseIterable, Identifiable {
    case gear, village
    var id: String { rawValue }
    var title: String { self == .gear ? "Gear" : "Village" }

    /// V debug buildu `-initialTab village` otevre obchod rovnou na vesnici (CI screenshoty).
    static var initial: ShopSection {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "initialTab") == "village" ? .village : .gear
        #else
        return .gear
        #endif
    }
}

/// Obchod: za mince z bitev se kupuje vybaveni (hned videt na pixelovem hrdinovi)
/// a stavi se vesnice. Obe casti prepina prepinac pod nadpisem.
struct ShopView: View {
    @ObservedObject var model: ProfileViewModel
    @State private var section = ShopSection.initial
    /// Predmet, ktery si hrac prave zkousi v nahledu nahore.
    @State private var tryOnID: String?

    private var tryOn: EquipmentItem? { tryOnID.flatMap(EquipmentItem.item(withID:)) }

    /// Hrdina tak, jak by vypadal s vyzkousenym predmetem.
    private var previewAppearance: AvatarAppearance {
        var appearance = model.profile.avatar
        if let tryOn { appearance.equip(tryOn.id, in: tryOn.slot) }
        return appearance
    }

    var body: some View {
        ScreenScaffold(scene: section == .gear ? .lanternGrove : .castleKeep) {
            switch section {
            case .gear:
                ForEach(EquipmentSlot.shopOrder, id: \.self) { slot in
                    ScreenSection(title: slot.displayName) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: FQSpace.md), GridItem(.flexible())], spacing: FQSpace.md) {
                            ForEach(EquipmentItem.catalog.filter { $0.slot == slot }) { itemCard($0) }
                        }
                    }
                }
            case .village:
                VillagePanel(model: model)
            }
        }
        // Nadpis je stejny jako na ostatnich zalozkach (nadtitulek, velky nadpis, ozubene kolo vpravo)
        // a sedi na stejnem miste. Pod nim zustava pripnuty prepinac a u vybaveni i nahled hrdiny,
        // aby bylo vyzkouseni predmetu videt i pri rolovani obchodu.
        .pinnedTopHeader {
            VStack(alignment: .leading, spacing: FQSpace.md) {
                ScreenHeader(eyebrow: "Shop", title: section == .gear ? "Gear up" : "Build your village")
                Picker("Shop section", selection: $section) {
                    ForEach(ShopSection.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if section == .gear { previewCard }
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
                Label("\(model.profile.coins) coins", systemImage: "dollarsign.circle.fill")
                    .font(.fqLabel)
                    .monospacedDigit()
                    .foregroundStyle(FQColor.accent)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
        }
        .padding(FQSpace.md)
        .glassCard()
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
            actionButton(item, owned: owned, equipped: equipped)
        }
        .padding(FQSpace.md)
        .glassCard(radius: FQRadius.control, tint: isTryingOn ? FQColor.accent : nil)
    }

    @ViewBuilder private func actionButton(_ item: EquipmentItem, owned: Bool, equipped: Bool) -> some View {
        if owned {
            Button { withAnimation(.easeOut(duration: 0.2)) { model.toggleEquip(item); tryOnID = nil } } label: {
                Text(equipped ? "Unequip" : "Equip")
                    .font(.fqLabel)
                    .frame(maxWidth: .infinity)
            }
            .glassButtonStyle()
            .buttonBorderShape(.roundedRectangle(radius: FQRadius.control))
            .tint(FQColor.accent)
        } else {
            Button { withAnimation(.easeOut(duration: 0.2)) { model.buy(item); tryOnID = nil } } label: {
                Label("\(item.price)", systemImage: "dollarsign.circle.fill")
                    .font(.fqLabel)
                    .monospacedDigit()
                    .foregroundStyle(model.canAfford(item) ? FQColor.onAccent : FQColor.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .prominentGlassButtonStyle()
            .buttonBorderShape(.roundedRectangle(radius: FQRadius.control))
            .tint(FQColor.accent)
            .disabled(!model.canAfford(item))
            .accessibilityLabel(model.canAfford(item) ? "Buy \(item.name) for \(item.price) coins" : "\(item.name) costs \(item.price) coins, not enough coins")
        }
    }

    private func wearing(_ item: EquipmentItem) -> AvatarAppearance {
        var appearance = model.profile.avatar
        appearance.equip(item.id, in: item.slot)
        return appearance
    }
}
