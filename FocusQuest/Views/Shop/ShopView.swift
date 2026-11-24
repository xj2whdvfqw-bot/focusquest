import SwiftUI

/// P1/I: obchod jako pixelovy kupecky stanek (zadne seznamy karet).
/// Nahore stanek: pruhovana striska, za ni obloha a krajina (zivy nahled pozadi), hrdina velky na podstavci
/// (vyzkouseni s poskokem a jiskrami), pod stankem tri drevene cedule na retizcich (Gear, Backgrounds,
/// Supplies). Pod nimi police s vybavenim a cenovkami, obrazy pozadi na zadni stene (karusel) nebo pult
/// se zasobami. Klepnuti na vec ukaze dole kompaktni panel (nazev, popis, Buy / Equip / Unequip).
struct ShopView: View {
    @ObservedObject var model: ProfileViewModel
    /// Gear, Backgrounds nebo Supplies; drzi ho MainTabView, aby Nastaveni mohlo otevrit Backgrounds.
    @Binding var section: ShopSection
    /// Vec, jejiz panel je dole otevreny.
    @State private var pick: ShopPick?
    /// Predmet, ktery si hrdina prave zkousi.
    @State private var tryOnID: String?
    /// Kazde vyzkouseni (a nakup) = poskok hrdiny a jiskry.
    @State private var hop = 0
    /// Zhoupnuti cedule pri vyberu (pocitadlo pro kazdou zvlast).
    @State private var swings: [ShopSection: Int] = [:]
    /// Obraz uprostred karuselu (id `ShopView.backgroundID`).
    @State private var centeredBackground: String?
    /// Vyska obrazovky obchodu: na nizkem displeji (iPhone SE) je stanek mensi.
    @State private var height: CGFloat = 800
    @State private var carouselWidth: CGFloat = 360
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// K1/D4: Gear = jen vybaveni hrdiny, Supplies = spotrebni veci (Extra pause, Streak freeze).
    enum ShopSection: String, CaseIterable, Identifiable {
        case gear, backgrounds, supplies
        var id: String { rawValue }
        var title: String {
            switch self {
            case .gear: "Gear"
            case .backgrounds: "Backgrounds"
            case .supplies: "Supplies"
            }
        }
    }

    /// Zasoby na pultu.
    enum Supply: String, CaseIterable, Identifiable {
        case extraPause, streakFreeze
        var id: String { rawValue }
    }

    /// Co je vybrane (panel dole).
    enum ShopPick: Hashable {
        case gear(String)
        case supply(Supply)
    }

    private var isCompact: Bool { height < 640 }
    private var heroSize: CGFloat { isCompact ? 76 : 104 }
    private var windowHeight: CGFloat { heroSize + 32 }

    private var tryOn: EquipmentItem? { tryOnID.flatMap(EquipmentItem.item(withID:)) }

    /// Hrdina tak, jak by vypadal s vyzkousenym predmetem.
    private var previewAppearance: AvatarAppearance {
        var appearance = model.profile.avatar
        if let tryOn { appearance.equip(tryOn.id, in: tryOn.slot) }
        return appearance
    }

    var body: some View {
        ScreenScaffold(scene: .lanternGrove, spacing: FQSpace.lg) {
            switch section {
            case .gear: gearShelves
            case .backgrounds: backgroundWall
            case .supplies: suppliesCounter
            }
        }
        .pinnedTopHeader { header }
        // Kompaktni panel vybrane veci vyjede dole nad listou zalozek; obsah nad nim zustava dostupny.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ZStack {
                if let pick {
                    detailPanel(pick)
                        .id(pick)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(FQMotion.spring(reduceMotion: reduceMotion), value: pick)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .onChange(of: section) { _, new in
            closePanel()
            centeredBackground = new == .backgrounds ? Self.backgroundID(model.selectedBackground) : nil
        }
        .onAppear {
            if section == .backgrounds { centeredBackground = Self.backgroundID(model.selectedBackground) }
        }
        // I4: odchod z obchodu bez "Use" vrati za stanek aktualne pouzivane pozadi (cela appka se nikdy neprepina).
        .onDisappear {
            model.previewBackground = nil
            pick = nil
            tryOnID = nil
            centeredBackground = nil
        }
        // Nakup: zvuk mince a vibrace uspechu (klik a vibraci pri klepnuti dava styl tlacitek).
        .fqHaptic(.success, trigger: model.profile.coins) { old, new in new < old }
        .fqSound(.coin, trigger: model.profile.coins) { old, new in new < old }
        // I2: prepnuti cedule = jemna vibrace vyberu (klik dava styl tlacitka).
        .fqHaptic(.selection, trigger: section)
    }

    // MARK: - Hlavicka a stanek

    private var header: some View {
        VStack(spacing: FQSpace.sm) {
            // Vsechno ve vysce 44 a zarovnane nahoru: behem tutorialu stitek uhne pod "Skip tutorial" (E2),
            // mince a ozubene kolo zustavaji ve stejne vysce jako Skip.
            HStack(alignment: .top, spacing: FQSpace.md) {
                Text("Shop")
                    .font(.fqLabel)
                    .foregroundStyle(FQColor.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                    .frame(minHeight: 44)
                    .coachSkipClearance()
                Spacer(minLength: FQSpace.sm)
                coinsLabel
                    .frame(minHeight: 44)
                SettingsGearButton()
            }
            VStack(spacing: 0) {
                stall
                signboards
                    // I6: krok tutorialu o Shopu zvyrazni cedule stanku.
                    .coachMark(.shopStall)
            }
        }
    }

    /// I1: striska, sloupky, okno s oblohou a krajinou (I4: vycentrovany obraz) a hrdina na podstavci.
    private var stall: some View {
        VStack(spacing: 0) {
            StallAwning()
            HStack(spacing: 0) {
                StallPost()
                ZStack(alignment: .bottom) {
                    ZStack {
                        StallScene(background: displayedBackground)
                            .id(Self.backgroundID(displayedBackground))
                            .transition(.opacity)
                    }
                    .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.45), value: Self.backgroundID(displayedBackground))
                    VStack(spacing: -StallMetrics.pixel) {
                        hero
                        StallPedestal()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: windowHeight)
                .clipped()
                StallPost()
            }
            // Pult stanku; z nej visi cedule.
            WoodPlank(thickness: 5, nails: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stallAccessibilityLabel)
    }

    private var stallAccessibilityLabel: String {
        if let tryOn { return "Your hero trying on \(tryOn.name)" }
        if section == .backgrounds { return "Preview of \(Self.backgroundName(displayedBackground)) behind the shop" }
        return "Your hero, \(model.profile.heroClass.displayName)"
    }

    /// I1: hrdina s vyzkousenou veci. Kazde vyzkouseni = poskok a jiskry (Reduce Motion jen prolnuti).
    private var hero: some View {
        HeroAvatarView(appearance: previewAppearance, heroClass: model.profile.heroClass, size: heroSize)
            .animation(FQMotion.quick, value: previewAppearance)
            .keyframeAnimator(initialValue: 0.0, trigger: reduceMotion ? 0 : hop) { content, lift in
                content.offset(y: lift)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-16, duration: 0.14)
                    CubicKeyframe(0, duration: 0.16)
                    CubicKeyframe(-4, duration: 0.08)
                    CubicKeyframe(0, duration: 0.1)
                }
            }
            .overlay { TryOnSparkles(trigger: hop, radius: heroSize * 0.62) }
    }

    /// I4: za stankem je vycentrovany obraz (jen v Backgrounds), jinak pouzivane pozadi.
    private var displayedBackground: ShopBackground? {
        guard section == .backgrounds, let centeredBackground else { return model.selectedBackground }
        return Self.background(forID: centeredBackground)
    }

    // MARK: - Cedule (I2)

    private var signboards: some View {
        HStack(alignment: .top, spacing: FQSpace.sm) {
            ForEach(ShopSection.allCases) { item in
                let selected = item == section
                Button {
                    selectSection(item)
                } label: {
                    HangingSign(title: item.title, icon: item, active: selected, swing: swings[item, default: 0])
                }
                .buttonStyle(.fqPress)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, FQSpace.sm)
    }

    private func selectSection(_ item: ShopSection) {
        guard item != section else { return }
        if !reduceMotion { swings[item, default: 0] += 1 }
        withAnimation(FQMotion.spring(reduceMotion: reduceMotion)) { section = item }
    }

    private var coinsLabel: some View {
        HStack(spacing: 6) {
            PixelCoin(pixel: 3)
            Text("\(model.profile.coins)")
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.fqLabel)
        .foregroundStyle(FQColor.textPrimary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.profile.coins) coins")
    }

    // MARK: - Gear na policich (I3)

    @ViewBuilder private var gearShelves: some View {
        ForEach(EquipmentSlot.shopOrder, id: \.self) { slot in
            let items = EquipmentItem.catalog.filter { $0.slot == slot }
            VStack(spacing: 0) {
                ShelfSign(title: slot.displayName)
                    .padding(.bottom, FQSpace.xs)
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(items) { item in
                        shelfItem(item).frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, FQSpace.sm)
                WoodPlank(thickness: 4, nails: true)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(items) { item in
                        PriceTag(label: model.owns(item) ? .owned : .price(item.price))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, FQSpace.sm)
            }
        }
    }

    private func shelfItem(_ item: EquipmentItem) -> some View {
        let owned = model.owns(item)
        let equipped = model.isEquipped(item)
        let selected = pick == .gear(item.id)
        let crop = ItemSprite.crop(item.layers)
        let pixel = max(3, min(6, (56 / CGFloat(max(crop.width, crop.height))).rounded(.down)))
        return Button {
            pickGear(item)
        } label: {
            ZStack(alignment: .bottom) {
                // Vybrana vec: zluta zare za ni; nasazena: bila.
                if selected || equipped {
                    Ellipse()
                        .fill(RadialGradient(colors: [(selected ? StallPalette.yellow : Color.white).opacity(0.45), .clear],
                                             center: .center, startRadius: 2, endRadius: 40))
                        .frame(width: 80, height: 56)
                        .offset(y: -8)
                }
                ItemSprite(item: item, pixel: pixel)
                    .padding(.bottom, 2)
                    .offset(y: selected && !reduceMotion ? -4 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .bottom)
            .overlay(alignment: .topTrailing) {
                if equipped {
                    PixelStar(pixel: 3).padding(.trailing, FQSpace.md)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.fqPress)
        .accessibilityLabel(item.name)
        .accessibilityValue(equipped ? "Equipped" : (owned ? "Owned" : "\(item.price) coins"))
        .accessibilityHint("Tries it on and shows details")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Klepnuti na vec: hrdina si ji hned vyzkousi (poskok a jiskry, ne kdyz ji uz ma) a vyjede panel.
    /// Druhe klepnuti panel zavre.
    private func pickGear(_ item: EquipmentItem) {
        if pick == .gear(item.id) {
            closePanel()
            return
        }
        withAnimation(FQMotion.spring(reduceMotion: reduceMotion)) {
            pick = .gear(item.id)
            tryOnID = model.isEquipped(item) ? nil : item.id
        }
        if !model.isEquipped(item) { hop += 1 }
    }

    private func closePanel() {
        withAnimation(FQMotion.spring(reduceMotion: reduceMotion)) {
            pick = nil
            tryOnID = nil
        }
    }

    // MARK: - Obrazy na stene (I4)

    /// Vsechna pozadi v poradi obchodu: World scenes, zdarma, za mince.
    static let wall: [ShopBackground?] = [nil] + (ShopBackground.free + ShopBackground.forCoins).map { Optional($0) }

    static func backgroundID(_ background: ShopBackground?) -> String { background?.rawValue ?? "world" }
    static func background(forID id: String) -> ShopBackground? { ShopBackground(rawValue: id) }
    static func backgroundName(_ background: ShopBackground?) -> String { background?.name ?? ShopBackground.worldName }

    private var paintingWidth: CGFloat { min(isCompact ? 170 : 220, carouselWidth * 0.58) }

    private var backgroundWall: some View {
        let centered = centeredBackground.flatMap(Self.background(forID:)) ?? (centeredBackground == nil ? model.selectedBackground : nil)
        return VStack(spacing: FQSpace.md) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: FQSpace.md) {
                    ForEach(Self.wall, id: \.self) { background in
                        Button {
                            withAnimation(FQMotion.spring(reduceMotion: reduceMotion)) {
                                centeredBackground = Self.backgroundID(background)
                            }
                        } label: {
                            painting(background)
                        }
                        .buttonStyle(.fqPress)
                        .id(Self.backgroundID(background))
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.8)
                                .opacity(phase.isIdentity ? 1 : 0.7)
                        }
                        .accessibilityLabel(Self.backgroundName(background))
                        .accessibilityValue(paintingState(background))
                        .accessibilityHint("Shows it behind the shop")
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredBackground)
            .contentMargins(.horizontal, max(0, (carouselWidth - paintingWidth) / 2), for: .scrollContent)
            .frame(height: paintingWidth * 1.3 + 16)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { carouselWidth = $0 }
            .background { PlankWall().padding(.vertical, -FQSpace.sm) }
            // Snap na dalsi obraz: jemna vibrace vyberu (podle prepinace Haptics).
            .fqHaptic(.selection, trigger: centeredBackground)

            VStack(spacing: 6) {
                Text(Self.backgroundName(centered))
                    .font(.fqHeadline)
                    .foregroundStyle(FQColor.textPrimary)
                Text(centered?.blurb ?? ShopBackground.worldBlurb)
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                backgroundAction(centered)
                    .padding(.top, FQSpace.xs)
            }
            .frame(maxWidth: .infinity)
            .contentTransition(.opacity)
            .animation(FQMotion.quick, value: centeredBackground)
        }
    }

    private func painting(_ background: ShopBackground?) -> some View {
        let inUse = model.selectedBackground == background
        let inset = CGFloat(PixelFrame.thicknessInPixels) * StallMetrics.pixel
        return ZStack(alignment: .topTrailing) {
            PaintingScene(background: background)
                .padding(inset)
            PixelFrame()
            // Visacka na ramu: Free, cena nebo Owned.
            PriceTag(label: paintingTag(background), stringLength: 6)
                .padding(.trailing, FQSpace.md)
                .offset(y: -6)
            if inUse {
                PixelStar(pixel: 3)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: paintingWidth, height: paintingWidth * 1.3)
        .padding(.top, 8)
    }

    private func paintingTag(_ background: ShopBackground?) -> PriceTag.Label {
        guard let background else { return .free }
        if background.isFree { return .free }
        return model.owns(background) ? .owned : .price(background.price)
    }

    private func paintingState(_ background: ShopBackground?) -> String {
        if model.selectedBackground == background { return "In use" }
        guard let background else { return "Free" }
        if background.isFree { return "Free" }
        return model.owns(background) ? "Owned" : "\(background.price) coins"
    }

    @ViewBuilder private func backgroundAction(_ background: ShopBackground?) -> some View {
        let inUse = model.selectedBackground == background
        let owned = background.map { model.owns($0) } ?? true
        if inUse {
            Text("In use")
                .fqFont(size: 15, weight: .semibold, design: .rounded)
                .foregroundStyle(FQColor.textSecondary)
                .frame(minHeight: 44)
        } else if owned {
            Button("Use") { withAnimation(.easeOut(duration: 0.3)) { model.useBackground(background) } }
                .buttonStyle(ShopCTAButtonStyle())
                .accessibilityLabel("Use \(Self.backgroundName(background))")
        } else if let background {
            let short = background.price - model.profile.coins
            if short > 0 {
                needMore(short)
                    .accessibilityLabel("\(background.name) costs \(background.price) coins. You need \(short) more.")
            } else {
                Button { withAnimation(.easeOut(duration: 0.3)) { model.buy(background) } } label: {
                    buyLabel(background.price)
                }
                .buttonStyle(ShopCTAButtonStyle())
                .accessibilityLabel("Buy \(background.name) for \(background.price) coins")
            }
        }
    }

    // MARK: - Zasoby na pultu (I5)

    private var suppliesCounter: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Supply.allCases) { supply in
                    supplyItem(supply).frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, FQSpace.lg)
            WoodPlank(thickness: 5, nails: true)
            HStack(alignment: .top, spacing: 0) {
                ForEach(Supply.allCases) { supply in
                    VStack(spacing: 2) {
                        Text(title(supply))
                            .fqFont(size: 14, weight: .bold, design: .rounded)
                            .foregroundStyle(StallPalette.cream)
                        Text("\(owned(supply)) / \(maximum(supply))")
                            .fqFont(size: 12, weight: .medium, design: .rounded)
                            .monospacedDigit()
                            .foregroundStyle(StallPalette.cream.opacity(0.75))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                }
            }
            .padding(.vertical, FQSpace.md)
            .background { CounterFront() }
        }
    }

    private func supplyItem(_ supply: Supply) -> some View {
        let selected = pick == .supply(supply)
        let count = owned(supply)
        return Button {
            withAnimation(FQMotion.spring(reduceMotion: reduceMotion)) {
                pick = selected ? nil : .supply(supply)
                tryOnID = nil
            }
        } label: {
            ZStack(alignment: .bottom) {
                if selected {
                    Ellipse()
                        .fill(RadialGradient(colors: [StallPalette.yellow.opacity(0.45), .clear], center: .center, startRadius: 2, endRadius: 44))
                        .frame(width: 96, height: 70)
                        .offset(y: -10)
                }
                Group {
                    switch supply {
                    case .extraPause: HourglassSprite(pixel: 5)
                    case .streakFreeze: IceCrystalSprite(pixel: 5)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Text("×\(count)")
                        .fqFont(size: 12, weight: .heavy, design: .rounded)
                        .monospacedDigit()
                        .foregroundStyle(count > 0 ? Color.white : FQColor.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(StallPalette.woodShadow))
                        .overlay(Capsule().stroke(StallPalette.cream.opacity(0.6), lineWidth: 1))
                        .lineLimit(1)
                        .fixedSize()
                        .offset(x: 18, y: -6)
                        .contentTransition(.numericText())
                }
                .padding(.bottom, 2)
                .offset(y: selected && !reduceMotion ? -4 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.fqPress)
        .accessibilityLabel(title(supply))
        .accessibilityValue("You have \(count) of \(maximum(supply)), \(price(supply)) coins")
        .accessibilityHint("Shows details")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func title(_ supply: Supply) -> String {
        switch supply {
        case .extraPause: "Extra pause"
        case .streakFreeze: "Streak freeze"
        }
    }

    private func detail(_ supply: Supply) -> String {
        switch supply {
        case .extraPause: "Every battle has 1 free pause. An extra pause gives you a second one; 1 per battle."
        case .streakFreeze: "Miss a day and a freeze is used for you, so your streak stays alive."
        }
    }

    private func owned(_ supply: Supply) -> Int {
        switch supply {
        case .extraPause: model.profile.extraPauses
        case .streakFreeze: model.profile.streakFreezes
        }
    }

    private func maximum(_ supply: Supply) -> Int {
        switch supply {
        case .extraPause: UserProfile.maxExtraPauses
        case .streakFreeze: StreakFreeze.maxOwned
        }
    }

    private func price(_ supply: Supply) -> Int {
        switch supply {
        case .extraPause: UserProfile.extraPausePrice
        case .streakFreeze: StreakFreeze.price
        }
    }

    private func buy(_ supply: Supply) {
        switch supply {
        case .extraPause: model.buyExtraPause()
        case .streakFreeze: model.buyStreakFreeze()
        }
    }

    // MARK: - Panel (I3, I5)

    private func detailPanel(_ pick: ShopPick) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch pick {
            case let .gear(id):
                if let item = EquipmentItem.item(withID: id) {
                    panelText(title: item.name, detail: item.summary)
                    gearAction(item)
                }
            case let .supply(supply):
                panelText(title: title(supply), detail: detail(supply))
                supplyAction(supply)
            }
        }
        .padding(FQSpace.lg)
        .frame(maxWidth: 640, alignment: .leading)
        .fqGlassPanel(radius: FQRadius.smallCard)
        .padding(.horizontal, FQSpace.lg)
        .padding(.bottom, FQSpace.sm)
        // Zavreni tahem dolu (bez krizku) nebo druhym klepnutim na vec; VoiceOver gestem escape.
        .gesture(DragGesture(minimumDistance: 12).onEnded { value in
            if value.translation.height > 30 { closePanel() }
        })
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape) { closePanel() }
    }

    private func panelText(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.fqHeadline)
                .foregroundStyle(FQColor.textPrimary)
            Text(detail)
                .font(.fqMeta)
                .foregroundStyle(FQColor.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func gearAction(_ item: EquipmentItem) -> some View {
        if model.owns(item), model.isEquipped(item) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    model.toggleEquip(item)
                    tryOnID = nil
                }
            } label: {
                Text("Unequip").frame(maxWidth: .infinity)
            }
            .buttonStyle(ShopButtonStyle(fullWidth: true))
            .accessibilityLabel("Unequip \(item.name)")
        } else if model.owns(item) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    model.toggleEquip(item)
                    tryOnID = nil
                }
                hop += 1
            } label: {
                Text("Equip").frame(maxWidth: .infinity)
            }
            .buttonStyle(ShopCTAButtonStyle(fullWidth: true))
            .accessibilityLabel("Equip \(item.name)")
        } else if model.canAfford(item) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    model.buy(item)
                    tryOnID = nil
                }
                hop += 1
            } label: {
                buyLabel(item.price).frame(maxWidth: .infinity)
            }
            .buttonStyle(ShopCTAButtonStyle(fullWidth: true))
            .accessibilityLabel("Buy \(item.name) for \(item.price) coins")
        } else {
            needMore(item.price - model.profile.coins)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(item.name) costs \(item.price) coins. You need \(item.price - model.profile.coins) more.")
        }
    }

    @ViewBuilder private func supplyAction(_ supply: Supply) -> some View {
        let count = owned(supply)
        let limit = maximum(supply)
        let cost = price(supply)
        if count >= limit {
            Text("You hold the maximum of \(limit)")
                .fqFont(size: 15, weight: .semibold, design: .rounded)
                .foregroundStyle(FQColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        } else if model.profile.coins >= cost {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { buy(supply) }
            } label: {
                buyLabel(cost).frame(maxWidth: .infinity)
            }
            .buttonStyle(ShopCTAButtonStyle(fullWidth: true))
            .accessibilityLabel("Buy \(title(supply)) for \(cost) coins. You have \(count) of \(limit).")
        } else {
            needMore(cost - model.profile.coins)
                .frame(maxWidth: .infinity)
        }
    }

    private func buyLabel(_ price: Int) -> some View {
        HStack(spacing: 6) {
            Text("Buy ·")
            PixelCoin(pixel: 2)
            Text("\(price)").monospacedDigit()
        }
    }

    /// Chybi mince: sede "Need 40 more", zadne tlacitko.
    private func needMore(_ short: Int) -> some View {
        Text("Need \(short) more")
            .fqFont(size: 15, weight: .semibold, design: .rounded)
            .monospacedDigit()
            .foregroundStyle(FQColor.textSecondary)
            .frame(minHeight: 44)
    }
}

// MARK: - Cedule, police, stena a pult

/// I2: drevena vyvesni cedule na dvou retizcich s pixelovou ikonou a napisem. Aktivni je svetlejsi
/// a pri vyberu se zhoupne (s Reduce Motion stoji).
struct HangingSign: View {
    let title: String
    let icon: ShopView.ShopSection
    let active: Bool
    let swing: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PixelChain(links: 2)
                Spacer(minLength: 0)
                PixelChain(links: 2)
            }
            .padding(.horizontal, 16)
            VStack(spacing: 3) {
                iconView
                Text(title)
                    .fqFont(size: 13, weight: .bold, design: .rounded)
                    .foregroundStyle(active ? StallPalette.ink : StallPalette.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background { WoodBoard(active: active) }
        }
        .keyframeAnimator(initialValue: 0.0, trigger: swing) { content, angle in
            content.rotationEffect(.degrees(angle), anchor: .top)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(7, duration: 0.12)
                CubicKeyframe(-5, duration: 0.2)
                CubicKeyframe(3, duration: 0.18)
                CubicKeyframe(-1, duration: 0.14)
                CubicKeyframe(0, duration: 0.14)
            }
        }
        .animation(FQMotion.quick, value: active)
    }

    @ViewBuilder private var iconView: some View {
        switch icon {
        case .gear: PixelGridView(rows: StallIcon.sword, palette: StallIcon.palette, pixel: 2)
        case .backgrounds: PixelGridView(rows: StallIcon.picture, palette: StallIcon.picturePalette, pixel: 2)
        case .supplies: PixelGridView(rows: StallIcon.potion, palette: StallIcon.potionPalette, pixel: 2)
        }
    }
}

/// I3: mala drevena cedulka nad polici (Helmets & hats, Weapons...).
struct ShelfSign: View {
    let title: String

    var body: some View {
        Text(title)
            .fqFont(size: 12, weight: .bold, design: .rounded)
            .foregroundStyle(StallPalette.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background { WoodBoard() }
            .accessibilityAddTraits(.isHeader)
    }
}

/// I4: zadni stena stanku ze svislych prken za obrazy.
struct PlankWall: View {
    var body: some View {
        let p = StallMetrics.pixel
        Canvas(opaque: false) { context, size in
            let pen = PixelPen(context: context, p: p)
            let w = Int((size.width / p).rounded(.up))
            let h = Int((size.height / p).rounded(.up))
            var x = 0
            var index = 0
            while x < w {
                let board = 10
                pen.fill(x, 0, board, h, (index % 2 == 0 ? StallPalette.woodDark : StallPalette.wood).opacity(0.55))
                pen.fill(x, 0, 1, h, StallPalette.woodShadow.opacity(0.6))
                x += board
                index += 1
            }
        }
        .accessibilityHidden(true)
    }
}

/// I5: predni stena pultu (svisla prkna).
struct CounterFront: View {
    var body: some View {
        let p = StallMetrics.pixel
        Canvas(opaque: false) { context, size in
            let pen = PixelPen(context: context, p: p)
            let w = Int((size.width / p).rounded(.up))
            let h = Int((size.height / p).rounded(.up))
            pen.fill(0, 0, w, h, StallPalette.woodDark)
            var x = 0
            while x < w {
                pen.fill(x, 0, 1, h, StallPalette.woodShadow)
                pen.fill(x + 1, 0, 1, h, StallPalette.wood.opacity(0.5))
                x += 8
            }
            pen.fill(0, h - 1, w, 1, StallPalette.woodShadow)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Tlacitka

/// Hlavni akce v obchode (Buy, Equip, Use): zluta jako ostatni hlavni akce appky.
struct ShopCTAButtonStyle: ButtonStyle {
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = FQRadius.shape(FQRadius.inSmallCard)
        return configuration.label
            .fqFont(size: 16, weight: .heavy, design: .rounded)
            .foregroundStyle(FQColor.onCta)
            .padding(.horizontal, FQSpace.xl)
            .frame(minHeight: 44)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(shape.fill(FQColor.cta.opacity(configuration.isPressed ? 0.85 : 1)))
            .contentShape(shape)
            .compositingGroup()
            .opacity(isEnabled ? 1 : 0.6)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .modifier(TapFeedback(isPressed: configuration.isPressed))
    }
}

/// Vedlejsi tlacitka obchodu (Unequip): bila 14 %, bily text; obrysova varianta.
struct ShopButtonStyle: ButtonStyle {
    var fullWidth = false
    var outlined = false
    var highlighted = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = FQRadius.shape(fullWidth ? FQRadius.inSmallCard : FQRadius.inBackgroundCard)
        let border: CGFloat = highlighted ? 2 : 1
        return configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(highlighted ? FQColor.accent : (isEnabled ? Color.white : FQColor.textSecondary))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
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
