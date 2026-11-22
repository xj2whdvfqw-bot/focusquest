import SwiftUI

/// Zalozka Path: velka pixelova mapa svetu, kterou hrac prochazi tazenim a pinch-zoomem.
/// Kamera po otevreni najede na aktualniho bosse, klepnuti na zastavku otevre sklenenou kartu
/// bosse s bitvou. Zamcene svety maji jemny zavoj a mekky okraj mraku u hranice.
/// Tlacitko seznamu otevre list se svety a bossy (pro VoiceOver a pro ty, kdo mapu posouvat nechteji).
struct PathTabView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    @Environment(BattlePresenter.self) private var battle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var terrain: CGImage? = MapTerrainCache.terrain
    @State private var selected: Boss?
    @State private var camera: MapCameraRequest?
    @State private var cameraToken = 0
    /// Svety, nad kterymi se prave rozplyva mlha.
    @State private var revealing: Set<BossWorld> = []
    /// List se seznamem svetu a bossu.
    @State private var showsWorldList = false
    /// Boss vybrany v seznamu: Fight sheet se otevre az po zavreni seznamu (dva listy naraz nejdou).
    @State private var pendingFight: Boss?
    @State private var viewport = MapViewport()

    /// Vyska hlavicky pod stavovym radkem (tlacitka 44 + odsazeni); mapa pod ni jde odrolovat.
    private static let headerHeight: CGFloat = 60

    private var wins: [String: Int] { profileModel.stats.pathWins }
    private var current: Boss? { model.currentMapBoss }

    var body: some View {
        mapScreen
            .sheet(isPresented: $showsWorldList, onDismiss: openPendingFight) {
                WorldListView(model: model, profileModel: profileModel) {
                    showsWorldList = false
                } onPick: { boss in
                    pendingFight = boss
                    showsWorldList = false
                }
                .presentationDragIndicator(.visible)
            }
    }

    // MARK: - Mapa

    private var mapScreen: some View {
        GeometryReader { proxy in
            // Nahore hlavicka, dole tab bar (safe area uz obsahuje rezervu pod plovouci listou).
            let insets = UIEdgeInsets(top: proxy.safeAreaInsets.top + Self.headerHeight, left: 0, bottom: proxy.safeAreaInsets.bottom + FQSpace.sm, right: 0)
            ZStack(alignment: .top) {
                // Barva hlubokeho pozadi, nez se teren vygeneruje (jinak cerna plocha).
                Color(red: 22 / 255, green: 30 / 255, blue: 40 / 255).ignoresSafeArea()
                ZoomableMapView(contentSize: MapLayout.size, insets: insets, camera: camera, viewport: viewport) { mapContent }
                    .ignoresSafeArea()
                // Nazvy svetu v souradnicich obrazovky: nikdy nejsou useknute u okraje
                // a mizi pod hlavickou a nad tab barem.
                WorldLabelsOverlay(model: model, viewport: viewport, topInset: insets.top, bottomInset: insets.bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                header
                    .zIndex(1)
            }
        }
        .overlay(alignment: .bottom) {
            if let selected {
                MapBossCard(
                    boss: selected,
                    state: state(of: selected),
                    wins: wins[selected.id] ?? 0,
                    lockedReason: lockedReason(for: selected),
                    canStart: model.isBetweenBattles,
                    onFight: { fight(selected) },
                    onClose: { close() }
                )
                .id(selected.id)
                .padding(.horizontal, FQSpace.md)
                .padding(.bottom, FQSpace.sm)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(FQMotion.spring(reduceMotion: reduceMotion), value: selected?.id)
        .task {
            if terrain == nil { terrain = await MapTerrainCache.loadTerrain { preview in terrain = preview } }
        }
        .onAppear {
            focusCurrent(intro: true)
            revealUnlockedWorlds()
        }
    }

    private var mapContent: some View {
        MapContent(
            terrain: terrain,
            model: model,
            wins: wins,
            current: current,
            selectedID: selected?.id,
            revealing: revealing,
            hero: profileModel.profile.avatar,
            heroClass: profileModel.profile.heroClass,
            onSelect: { boss in
                FQFeedback.shared.haptic(.selection)
                selected = boss
            },
            onBackground: { close() }
        )
    }

    /// Kompaktni hlavicka nad mapou: kde hrac je, navrat na aktualniho bosse, seznam svetu, Nastaveni.
    /// Tlacitka maji neinteraktivni sklo: interaktivni Liquid Glass nad UIKit mapou pohlcoval klepnuti
    /// a zustaval rozsviceny. Stisk ukazuje styl .fqPress (zmenseni a ztmaveni).
    private var header: some View {
        HStack(spacing: FQSpace.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Path").font(.fqLabel).foregroundStyle(FQColor.textSecondary)
                Text(current?.world.title ?? "Every world conquered")
                    .fqFont(size: 20, weight: .semibold, design: .rounded)
                    .foregroundStyle(FQColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: FQSpace.sm)
            headerButton("scope", label: "Go to the current boss") { focusCurrent(intro: false) }
            headerButton("list.bullet", label: "Show worlds and bosses as a list") {
                selected = nil
                showsWorldList = true
            }
            SettingsGearButton(interactiveGlass: false)
        }
        .padding(.horizontal, FQSpace.lg)
        .padding(.top, FQSpace.sm)
        .padding(.bottom, FQSpace.xl)
        .background {
            LinearGradient(colors: [Color(red: 6 / 255, green: 5 / 255, blue: 16 / 255).opacity(0.85), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        .modifier(BrightTextShadow())
    }

    private func headerButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(FQColor.textPrimary)
                .frame(width: 44, height: 44)
                .glassControl(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.fqPress)
        .accessibilityLabel(label)
    }

    // MARK: - Kamera a mlha

    /// Najede na aktualniho bosse (do stredu viditelne casti). Pri otevreni mapy z oddaleni (pruzkum), jinak primo.
    private func focusCurrent(intro: Bool) {
        let target = current ?? BossWorld.allCases.last?.bosses.last
        guard let target, let point = MapLayout.stops[target.id] else { return }
        cameraToken += 1
        camera = MapCameraRequest(point: point, zoom: 1.0, startZoom: intro ? 0.55 : nil, animated: !reduceMotion, token: cameraToken)
        #if DEBUG
        // CI screenshoty mapy: bez animace (snimek se dela po par sekundach), oddaleni a otevrena karta.
        if let mode = Self.debugMapMode {
            camera = MapCameraRequest(point: point, zoom: mode == "map-overview" ? 0.5 : 0.9, animated: false, token: cameraToken)
            if mode == "map-card" { selected = target }
        }
        #endif
    }

    #if DEBUG
    static var debugMapMode: String? {
        UserDefaults.standard.string(forKey: "initialTab").flatMap { $0.hasPrefix("map-") ? $0 : nil }
    }
    #endif

    /// Nove odemcene svety: mlha se po najezdu kamery jednou rozplyne, pak se to zapamatuje.
    private func revealUnlockedWorlds() {
        let pending = BossWorld.allCases.filter { model.needsReveal($0) && !revealing.contains($0) }
        guard !pending.isEmpty else { return }
        Task { @MainActor in
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(1_000)) }
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .easeInOut(duration: 1.4)) {
                revealing.formUnion(pending)
            }
            if !pending.isEmpty { FQFeedback.shared.play(.levelUp) }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 350 : 1_500))
            for world in pending { model.markRevealed(world) }
            revealing.subtract(pending)
        }
    }

    // MARK: - Stav zastavek

    private func state(of boss: Boss) -> MapStopState {
        MapStopState.of(boss, model: model, wins: wins, current: current)
    }

    private func lockedReason(for boss: Boss) -> String {
        MapStopState.lockedReason(for: boss, model: model)
    }

    private func fight(_ boss: Boss) {
        model.selectBoss(boss)
        battle.openFightSheet()
        selected = nil
    }

    /// Boss ze seznamu: seznam se zavrel, ted se otevre Fight sheet.
    private func openPendingFight() {
        guard let boss = pendingFight else { return }
        pendingFight = nil
        fight(boss)
    }

    private func close() {
        guard selected != nil else { return }
        selected = nil
    }
}

/// Stav zastavky na mape.
enum MapStopState {
    /// Porazeny boss (vlajka); da se s nim bojovat znovu.
    case defeated
    /// Boss na rade: pulzuje a stoji u nej hrdina.
    case current
    /// Odemceny, ale neni na rade (napr. aktualni boss jineho sveta).
    case open
    /// Zamceny: nejdriv je potreba porazit predchoziho bosse nebo svet.
    case locked

    var accessibilityText: String {
        switch self {
        case .defeated: "defeated"
        case .current: "current boss"
        case .open: "open"
        case .locked: "locked"
        }
    }

    /// Kratky popisek stavu do seznamu bossu.
    var title: String {
        switch self {
        case .defeated: "Defeated"
        case .current: "Up next"
        case .open: "Open"
        case .locked: "Locked"
        }
    }

    @MainActor
    static func of(_ boss: Boss, model: ArenaViewModel, wins: [String: Int], current: Boss?) -> MapStopState {
        let count = wins[boss.id] ?? 0
        guard model.canFight(boss, wins: count) else { return .locked }
        if boss.id == current?.id { return .current }
        return boss.nodeIndex < model.clearedNodes(in: boss.world) || count > 0 ? .defeated : .open
    }

    @MainActor
    static func lockedReason(for boss: Boss, model: ArenaViewModel) -> String {
        let world = boss.world
        if !model.isUnlocked(world), let previous = world.previous, let final = previous.bosses.last {
            return "Beat \(final.name) in \(previous.title) to unlock \(world.title)."
        }
        let before = world.bosses[max(0, boss.nodeIndex - 1)]
        return "Beat \(before.name) first."
    }
}

// MARK: - Obsah mapy (vrstvy)

/// Vrstvy mapy: pixelovy teren (s cestou), zastavky, hrdina a mlha nad zamcenymi svety.
/// Nazvy svetu jsou nad mapou v souradnicich obrazovky (WorldLabelsOverlay).
private struct MapContent: View {
    let terrain: CGImage?
    @ObservedObject var model: ArenaViewModel
    let wins: [String: Int]
    let current: Boss?
    let selectedID: String?
    let revealing: Set<BossWorld>
    let hero: AvatarAppearance
    let heroClass: HeroClass
    let onSelect: (Boss) -> Void
    let onBackground: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            terrainLayer
            ForEach(BossWorld.allCases) { world in
                fogLayer(world)
            }
            ForEach(Boss.roster) { boss in
                if let point = MapLayout.stops[boss.id] {
                    MapStopView(
                        boss: boss,
                        state: MapStopState.of(boss, model: model, wins: wins, current: current),
                        isSelected: boss.id == selectedID,
                        action: { onSelect(boss) }
                    )
                    .position(point)
                }
            }
            // Hrdina ma stejne vrstvy jako v Shopu a Hero Profile (aktualni trida a vybaveni).
            if let current, let point = MapLayout.stops[current.id] {
                HeroAvatarView(appearance: hero, heroClass: heroClass, size: 44)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                    .position(x: point.x - 52, y: point.y - 6)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: MapLayout.size.width, height: MapLayout.size.height, alignment: .topLeading)
    }

    @ViewBuilder private var terrainLayer: some View {
        Group {
            if let terrain {
                Image(decorative: terrain, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .transition(.opacity)
            } else {
                // Nez se teren vygeneruje: jen zaklad s jemnym leskem (skeleton, ne kolecko).
                Color(red: 40 / 255, green: 70 / 255, blue: 56 / 255)
            }
        }
        .frame(width: MapLayout.size.width, height: MapLayout.size.height)
        .contentShape(Rectangle())
        .onTapGesture(perform: onBackground)
        .accessibilityHidden(true)
        .animation(.easeOut(duration: 0.3), value: terrain != nil)
    }

    /// Mlha nad zamcenym svetem: jemny zavoj pres cely svet a u prvniho zamceneho sveta mekky
    /// okraj mraku pres hranici s odemcenou krajinou. Pri odemceni se rozplyne (zpruhledni a odplyne nahoru).
    @ViewBuilder private func fogLayer(_ world: BossWorld) -> some View {
        let locked = !model.isUnlocked(world)
        let pending = model.needsReveal(world)
        let frontier = world.previous.map { model.isUnlocked($0) } ?? true
        if locked || pending, let fog = MapTerrainCache.fog(for: world, frontier: frontier) {
            let band = MapLayout.band(of: world)
            let height = band.height + MapTerrain.fogOverhang
            let dissolving = revealing.contains(world)
            Image(decorative: fog, scale: 1)
                .resizable()
                // Vyhlazeni (ne pixely): mrak plynule prechazi do krajiny.
                .interpolation(.medium)
                .frame(width: MapLayout.size.width, height: height)
                .scaleEffect(dissolving ? 1.15 : 1)
                .offset(y: dissolving ? -60 : 0)
                .opacity(dissolving ? 0 : 1)
                .position(x: MapLayout.size.width / 2, y: band.minY + height / 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Nazvy svetu nad mapou. Kazdy stitek je u spodni hrany sveta (kde cesta do sveta vstupuje),
/// vodorovne se drzi v obrazovce (nikdy neni useknuty u okraje) a schova se, kdyz by byl
/// pod hlavickou nebo pod tab barem.
private struct WorldLabelsOverlay: View {
    @ObservedObject var model: ArenaViewModel
    let viewport: MapViewport
    let topInset: CGFloat
    let bottomInset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                ForEach(BossWorld.allCases) { world in
                    let point = viewport.screenPoint(of: MapLayout.labelAnchor(of: world))
                    let unlocked = model.isUnlocked(world)
                    let halfWidth = Self.estimatedWidth(world, unlocked: unlocked) / 2
                    let margin: CGFloat = 12
                    if point.y > topInset + 24, point.y < size.height - bottomInset - 24 {
                        WorldNameLabel(world: world, unlocked: unlocked)
                            .fixedSize()
                            .position(
                                x: min(size.width - halfWidth - margin, max(halfWidth + margin, point.x)),
                                y: point.y
                            )
                    }
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    /// Odhad sirky stitku pro drzeni v obrazovce (17 pt tucne, odsazeni 14, zamek).
    static func estimatedWidth(_ world: BossWorld, unlocked: Bool) -> CGFloat {
        CGFloat(world.title.count) * 10.5 + 28 + (unlocked ? 0 : 19) + 4
    }
}

/// Stitek s nazvem sveta (sklenena kapsle v barve sveta, u zamceneho sveta zamek).
private struct WorldNameLabel: View {
    let world: BossWorld
    let unlocked: Bool

    var body: some View {
        HStack(spacing: 6) {
            if !unlocked { Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)) }
            Text(world.title).fqFont(size: 17, weight: .bold, design: .rounded).lineLimit(1)
        }
        .foregroundStyle(FQColor.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255).opacity(0.72), in: Capsule())
        .overlay { Capsule().strokeBorder(world.accent.opacity(0.8), lineWidth: 2) }
    }
}

/// Zastavka na ceste: kruh se spritem bosse. Porazeny ma vlajku, aktualni pulzuje, zamceny je sedy se zamkem.
private struct MapStopView: View {
    let boss: Boss
    let state: MapStopState
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var ring: Color {
        switch state {
        case .current: FQColor.cta
        case .locked: Color.white.opacity(0.35)
        default: Color.white.opacity(0.85)
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if state == .current {
                    Circle()
                        .stroke(FQColor.cta, lineWidth: 3)
                        .frame(width: 60, height: 60)
                        .scaleEffect(pulse ? 1.45 : 1)
                        .opacity(pulse ? 0 : 0.9)
                }
                Circle().fill(Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255).opacity(0.78))
                    .frame(width: 60, height: 60)
                Circle().strokeBorder(ring, lineWidth: state == .current ? 3 : 2)
                    .frame(width: 60, height: 60)
                StaticPixelSprite(sprite: .boss(boss.pixelSpriteConfig), size: 40)
                    .saturation(state == .locked ? 0 : 1)
                    .opacity(state == .locked ? 0.5 : 1)
            }
            .overlay(alignment: .topTrailing) { badge.offset(x: 4, y: -4) }
            .overlay(alignment: .bottom) {
                Text("\(boss.nodeIndex + 1)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.7), in: Capsule())
                    .offset(y: 10)
            }
            .frame(width: 76, height: 76)
            .scaleEffect(isSelected ? 1.15 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.fqPress)
        .animation(FQMotion.quick, value: isSelected)
        .onAppear { startPulse() }
        .onChange(of: state) { startPulse() }
        .accessibilityLabel("\(boss.name), \(boss.world.title), boss \(boss.nodeIndex + 1) of \(boss.world.bosses.count), \(ArenaView.durationText(minutes: boss.maxHP)), \(state.accessibilityText)")
        .accessibilityHint("Shows the boss card")
    }

    @ViewBuilder private var badge: some View {
        switch state {
        case .defeated:
            Image(systemName: "flag.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FQColor.onAccent)
                .frame(width: 22, height: 22)
                .background(FQColor.accent, in: Circle())
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(FQColor.textPrimary)
                .frame(width: 22, height: 22)
                .background(Color.black.opacity(0.75), in: Circle())
        default:
            EmptyView()
        }
    }

    private func startPulse() {
        guard state == .current, !reduceMotion else { pulse = false; return }
        pulse = false
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
    }
}

/// Sklenena karta bosse nad mapou: sprite, jmeno, svet a poradi, hlaska, delka a tlacitko bitvy.
/// Zavira se klepnutim do mapy nebo tahem dolu.
private struct MapBossCard: View {
    let boss: Boss
    let state: MapStopState
    let wins: Int
    let lockedReason: String
    let canStart: Bool
    let onFight: () -> Void
    let onClose: () -> Void
    @GestureState private var drag: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: FQSpace.md) {
            HStack(alignment: .top, spacing: FQSpace.md) {
                PixelArtAvatarView(sprite: .boss(boss.pixelSpriteConfig), size: 64)
                    .frame(width: 72, height: 72)
                    .background(boss.world.accent.opacity(0.18), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(boss.world.title) · Boss \(boss.nodeIndex + 1) of \(boss.world.bosses.count)")
                        .font(.fqMeta)
                        .foregroundStyle(FQColor.textSecondary)
                    Text(boss.name)
                        .font(.fqHeadline)
                        .foregroundStyle(FQColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    // Delka bitvy i u zamceneho bosse, at je videt, co hrace ceka.
                    Label(ArenaView.durationText(minutes: boss.maxHP), systemImage: "timer")
                        .font(.fqLabel.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(FQColor.textPrimary)
                        .accessibilityLabel("Battle length \(boss.maxHP) minutes")
                    Text("“\(boss.quip)”")
                        .font(.fqSecondary.italic())
                        .foregroundStyle(FQColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if wins > 0 {
                        Label("Beaten \(wins)×", systemImage: "flag.fill")
                            .font(.fqMeta)
                            .foregroundStyle(FQColor.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if state == .locked {
                Label(lockedReason, systemImage: "lock.fill")
                    .font(.fqLabel)
                    .foregroundStyle(FQColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button(action: onFight) {
                    Label("Fight · \(ArenaView.durationText(minutes: boss.maxHP))", systemImage: "play.fill")
                        .fqFont(size: 18, weight: .heavy, design: .rounded)
                        .foregroundStyle(FQColor.onCta)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .background(FQColor.cta, in: FQRadius.shape(FQRadius.inCard))
                        .compositingGroup()
                }
                .buttonStyle(.fqPress)
                .disabled(!canStart)
            }
        }
        .padding(FQSpace.lg)
        .frame(maxWidth: 520)
        .glassCard()
        .offset(y: max(0, drag))
        .gesture(
            DragGesture(minimumDistance: 12)
                .updating($drag) { value, state, _ in state = value.translation.height }
                .onEnded { value in if value.translation.height > 60 || value.predictedEndTranslation.height > 160 { onClose() } }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Close") { onClose() }
    }
}

// MARK: - Seznam svetu (list z hlavicky mapy)

/// Seznam svetu a bossu v listu z hlavicky mapy (pro VoiceOver a pro ty, kdo mapu posouvat nechteji).
/// Svety se rozbaluji na miste, kazdy boss ukazuje stav a delku bitvy; zamceny svet a zamceni
/// bossove jsou sedi a neda se s nimi bojovat. Vyber bosse list zavre a otevre Fight sheet.
struct WorldListView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    let onClose: () -> Void
    let onPick: (Boss) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Rozbaleny svet (vzdy nejvys jeden), nil = vse sbalene.
    @State private var openWorld: BossWorld? = WorldListView.initialOpenWorld

    private var winsByBoss: [String: Int] { profileModel.stats.pathWins }

    var body: some View {
        let wins = winsByBoss
        ScreenScaffold(scene: .enchantedForest) {
            HStack(alignment: .top, spacing: FQSpace.sm) {
                ScreenTitle(eyebrow: "Path", title: "Worlds and bosses")
                Spacer(minLength: FQSpace.sm)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(FQColor.textPrimary)
                        .frame(width: 44, height: 44)
                        .glassControl(in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.fqPress)
                .accessibilityLabel("Close the list")
            }
            VStack(spacing: FQSpace.lg) {
                ForEach(BossWorld.allCases) { world in
                    WorldCard(
                        world: world,
                        cleared: model.clearedNodes(in: world),
                        isUnlocked: model.isUnlocked(world),
                        wins: wins,
                        isOpen: openWorld == world,
                        canFight: model.isBetweenBattles,
                        canFightBoss: { model.canFight($0, wins: wins[$0.id] ?? 0) },
                        onToggle: { toggle(world) },
                        onPick: onPick
                    )
                }
            }
        }
        // Svet, ve kterem hrac prave je, je rovnou rozbaleny.
        .onAppear { if openWorld == nil { openWorld = model.currentMapBoss?.world } }
    }

    /// Karta se plynule zvetsi a mrizka se na miste odkryje (fade + vyska, 0,25 s).
    /// S Reduce Motion se svet otevre hned, bez animace.
    private func toggle(_ world: BossWorld) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            openWorld = openWorld == world ? nil : world
        }
    }

    /// V debug buildu `-initialTab path` rozbali prvni svet (CI screenshoty seznamu).
    static var initialOpenWorld: BossWorld? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "initialTab") == "path" ? BossWorld.allCases.first : nil
        #else
        return nil
        #endif
    }
}

/// Karta sveta: nazev, podtitul, "2 / 7 cleared" a lista postupu v barve sveta. Bez ikony.
private struct WorldCard: View {
    let world: BossWorld
    let cleared: Int
    let isUnlocked: Bool
    let wins: [String: Int]
    let isOpen: Bool
    let canFight: Bool
    let canFightBoss: (Boss) -> Bool
    let onToggle: () -> Void
    let onPick: (Boss) -> Void

    private var bosses: [Boss] { world.bosses }
    private var isComplete: Bool { cleared >= bosses.count }
    private static let columnCount = 3

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) { header }
                .buttonStyle(.fqPress)
                .accessibilityAddTraits(isOpen ? .isSelected : [])
                .accessibilityHint(isOpen ? "Hides the bosses" : "Shows the bosses")
            if isOpen {
                bossGrid
                    .padding(.top, FQSpace.lg)
                    // Jen fade na miste; vysku odkryva rostouci karta (orez nize). Zadny pohyb odjinud.
                    .transition(.opacity)
            }
        }
        // Behem rozbalovani je mrizka videt jen v rostouci karte, takze se "rozbali" smerem dolu.
        .clipped()
        .padding(FQSpace.lg)
        .glassCard(tint: world.accent.opacity(0.077))
    }

    /// Mrizka 3 sloupcu z obycejnych radku. LazyVGrid tu nebyl: jeho dlazdice se pri animovanem
    /// otevreni vytvarely postupne a priletaly shora pres obrazovku.
    private var bossGrid: some View {
        let indices = Array(bosses.indices)
        let rows = stride(from: 0, to: indices.count, by: Self.columnCount).map { Array(indices[$0..<min($0 + Self.columnCount, indices.count)]) }
        return VStack(spacing: FQSpace.sm) {
            ForEach(rows, id: \.first) { row in
                HStack(alignment: .top, spacing: FQSpace.sm) {
                    ForEach(row, id: \.self) { index in
                        let boss = bosses[index]
                        let fightable = canFightBoss(boss)
                        BossTile(
                            boss: boss,
                            number: index + 1,
                            accent: world.accent,
                            wins: max(index < cleared ? 1 : 0, wins[boss.id] ?? 0),
                            isLocked: !fightable,
                            action: { onPick(boss) }
                        )
                        .disabled(!canFight || !fightable)
                    }
                    // Neuplny posledni radek drzi sirku sloupcu.
                    ForEach(0..<(Self.columnCount - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FQSpace.md) {
            HStack(alignment: .top, spacing: FQSpace.md) {
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    HStack(spacing: 6) {
                        if !isUnlocked {
                            Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).accessibilityLabel("Locked")
                        }
                        Text(world.title)
                            .fqFont(size: 17, weight: .semibold, design: .rounded)
                    }
                    .foregroundStyle(FQColor.textPrimary)
                    Text(isUnlocked ? world.tagline : unlockHint)
                        .fqFont(size: 13, design: .rounded)
                        .foregroundStyle(FQColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FQColor.textSecondary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .accessibilityHidden(true)
            }
            HStack(spacing: FQSpace.sm) {
                if isComplete {
                    Text("World cleared")
                        .fqFont(size: 15, weight: .semibold, design: .rounded)
                        .foregroundStyle(FQColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("\(cleared) / \(bosses.count) cleared")
                    .fqFont(size: 15, weight: .medium, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textPrimary)
            }
            ProgressBar(fraction: bosses.isEmpty ? 0 : Double(cleared) / Double(bosses.count), color: world.accent)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var unlockHint: String {
        guard let previous = world.previous, let final = previous.bosses.last else { return world.tagline }
        return "Beat \(final.name) in \(previous.title) to unlock."
    }
}

/// Lista postupu sveta: 4 pt vysoka, svetla stopa, vypln v barve sveta.
private struct ProgressBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule().fill(color).frame(width: proxy.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// Dlazdice bosse: cislo, sprite, jmeno (max 2 radky) a delka "20 min".
/// Porazeny boss ma na spritu pilulku "✓ 3×" s poctem vyher, zamceny je sedy se zamkem.
private struct BossTile: View {
    let boss: Boss
    let number: Int
    let accent: Color
    let wins: Int
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FQSpace.xs) {
                art
                Text(boss.name)
                    .fqFont(size: 13, weight: .semibold, design: .rounded)
                    .foregroundStyle(FQColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.85)
                Text(ArenaView.durationText(minutes: boss.maxHP))
                    .fqFont(size: 12, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textSecondary)
                    .lineLimit(1)
            }
            .padding(.top, FQSpace.md)
            .padding(.horizontal, FQSpace.xs)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.05), in: FQRadius.shape(FQRadius.inCard))
            .contentShape(FQRadius.shape(FQRadius.inCard))
            .opacity(isLocked ? 0.55 : 1)
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel(label)
    }

    private var label: String {
        if isLocked { return "\(boss.name), locked, \(boss.maxHP) minutes" }
        return wins > 0 ? "\(boss.name), defeated \(wins) times. Fight again, \(boss.maxHP) minutes" : "Fight \(boss.name), \(boss.maxHP) minutes"
    }

    private var art: some View {
        ZStack {
            Circle().fill(accent.opacity(0.18))
            PixelArtAvatarView(sprite: .boss(boss.pixelSpriteConfig), size: 52)
                .saturation(isLocked ? 0 : 1)
        }
        .frame(width: 64, height: 64)
        .overlay(alignment: .topLeading) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(FQColor.textSecondary)
                .padding(.horizontal, 5)
                .frame(minWidth: 20, minHeight: 20)
                .background(Color.black.opacity(0.55), in: Capsule())
                .offset(x: -2, y: -2)
        }
        .overlay(alignment: .bottomTrailing) {
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FQColor.textPrimary)
                    .frame(width: 22, height: 22)
                    .background(Color.black.opacity(0.75), in: Circle())
                    .offset(x: 4, y: 2)
            } else if wins > 0 {
                WinsPill(count: wins).offset(x: 4, y: 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Pilulka "✓ 3×" na spritu porazeneho bosse (neutralni, bez tyrkysove).
private struct WinsPill: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(FQColor.onAccent, FQColor.accent)
            Text("\(count)×")
                .fqFont(size: 12, weight: .bold, design: .rounded)
                .monospacedDigit()
                .foregroundStyle(FQColor.accent)
        }
        .padding(.leading, 5)
        .padding(.trailing, 7)
        .padding(.vertical, 2)
        .background(Color(red: 34 / 255, green: 32 / 255, blue: 48 / 255), in: Capsule())
        .overlay { Capsule().strokeBorder(Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255).opacity(0.9), lineWidth: 2).padding(-2) }
    }
}

/// Dlazdice se pri stisku malinko zmackne (0,97), jako v prototypu.
private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .modifier(TapFeedback(isPressed: configuration.isPressed))
    }
}
