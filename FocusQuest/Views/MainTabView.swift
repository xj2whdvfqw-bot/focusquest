import SwiftUI

private enum FocusQuestTab: String, CaseIterable, Identifiable {
    case arena, path, shop, stats, profile
    var id: String { rawValue }
    var title: String { self == .profile ? "Hero" : rawValue.capitalized }

    /// V debug buildu jde appku spustit s argumentem `-initialTab stats` (vychozi zalozka)
    /// nebo `-initialTab creator` (uvodni tvorba hrdiny) ci `-initialTab settings`
    /// (Profil s otevrenym Nastavenim). `battle` obrazovku
    /// bitvy pres Arenu. Pouziva to CI pro screenshoty.
    static var launchArgument: String? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "initialTab")
        #else
        return nil
        #endif
    }

    static var initial: FocusQuestTab {
        switch launchArgument {
        case "settings": return .profile
        case "battle", "fight": return .arena
        default: break
        }
        return launchArgument.flatMap(FocusQuestTab.init(rawValue:)) ?? .arena
    }
}

/// Rozmery plovouci listy zalozek (hodnoty z design/focusquest.html).
enum FQTabBarMetrics {
    static let height: CGFloat = 62
    static let sideInset: CGFloat = 22
    /// Vzdalenost od spodni hrany displeje (ne od bezpecne zony).
    static let bottom: CGFloat = 22
    static let iconSize: CGFloat = 26
    /// Mezera mezi koncem obsahu a horni hranou listy je v prototypu 24 pt. ScreenScaffold uz dole
    /// odsazuje o FQSpace.xxl (32), takze rezerva konci o 8 pt niz nez horni hrana listy.
    static let contentGap: CGFloat = 24 - FQSpace.xxl
    /// Obchod se odemkne po tolika vyhranych bitvach.
    static let shopWins = 3
}

struct MainTabView: View {
    let container: AppDIContainer
    @State private var selectedTab = FocusQuestTab.initial
    @State private var showsHeroCreator = false
    @State private var toast: String?
    /// Ozubene kolo na kazde zalozce otevira tentyz list Nastaveni.
    @State private var settingsPresenter = SettingsPresenter()
    /// Bitva bezi pres celou obrazovku nad zalozkami, takze spodni lista neni videt.
    @State private var battlePresenter = BattlePresenter()

    var body: some View {
        Group {
            if container.isIntegrityCompromised {
                IntegrityLockdownView()
            } else {
                GeometryReader { proxy in
                    // Obsah musi koncit 24 pt nad listou; bezpecna zona dole uz cast teto vysky pokryva.
                    let reserve = max(0, FQTabBarMetrics.bottom + FQTabBarMetrics.height + FQTabBarMetrics.contentGap - proxy.safeAreaInsets.bottom)
                    ZStack {
                        tabs(reserve: reserve)
                        tabChrome
                    }
                }
                .pixelToast($toast)
                .environment(settingsPresenter)
                .environment(battlePresenter)
                .sheet(isPresented: Binding(get: { settingsPresenter.isPresented }, set: { settingsPresenter.isPresented = $0 })) {
                    SettingsView(model: container.settingsViewModel) { settingsPresenter.isPresented = false }
                        .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: Binding(get: { battlePresenter.showsFightSheet }, set: { battlePresenter.showsFightSheet = $0 }), onDismiss: { startBattleAfterFightSheet() }) {
                    FightSheetView(model: container.arenaViewModel) {
                        battlePresenter.startsAfterSheet = true
                        battlePresenter.showsFightSheet = false
                    } onClose: {
                        battlePresenter.showsFightSheet = false
                    }
                }
                .fullScreenCover(isPresented: Binding(get: { battlePresenter.isPresented }, set: { battlePresenter.isPresented = $0 }), onDismiss: { openAfterBattle() }) {
                    BattleView(model: container.arenaViewModel, profileModel: container.profileViewModel, onExit: { battlePresenter.isPresented = false }, onExitTo: { destination in
                        battlePresenter.afterBattle = destination
                        battlePresenter.isPresented = false
                    })
                }
                // Bezici bitva musi byt videt vzdy, at ji hrac spustil odkudkoli.
                .onReceive(container.arenaViewModel.$state) { state in
                    switch state {
                    case .awaitingFlatPlacement, .focusing, .paused, .warningCountdown: battlePresenter.isPresented = true
                    default: break
                    }
                }
                .task {
                    if FocusQuestTab.launchArgument == "settings" { settingsPresenter.isPresented = true }
                    if FocusQuestTab.launchArgument == "battle" { battlePresenter.isPresented = true }
                    if FocusQuestTab.launchArgument == "fight" { battlePresenter.openFightSheet() }
                    await presentHeroCreatorIfNeeded()
                }
                // Odchod z appky behem bitvy se netresta: hodiny bitvy bezi dal i na pozadi.
                .fullScreenCover(isPresented: $showsHeroCreator) {
                    HeroCreatorView(model: container.profileViewModel, blocker: container.appBlocker) { showsHeroCreator = false }
                }
            }
        }
        // Pixelova krajina je nocni, proto je appka vzdy v tmavem rezimu (text na skle vynikne).
        .preferredColorScheme(.dark)
        .tint(FQColor.accent)
    }

    /// Systemovy TabView drzi stav kazde zalozky; jeho vlastni lista je skryta, kreslime FocusQuestTabBar.
    private func tabs(reserve: CGFloat) -> some View {
        TabView(selection: $selectedTab) {
            ArenaView(model: container.arenaViewModel, profileModel: container.profileViewModel) { selectedTab = .path }
                .tabPage(reserve: reserve)
                .tag(FocusQuestTab.arena)
            PathTabView(model: container.arenaViewModel, profileModel: container.profileViewModel)
                .tabPage(reserve: reserve)
                .tag(FocusQuestTab.path)
            ShopView(model: container.profileViewModel)
                .tabPage(reserve: reserve)
                .tag(FocusQuestTab.shop)
            StatsView(model: container.statsViewModel, profile: container.profileViewModel, arena: container.arenaViewModel)
                .tabPage(reserve: reserve)
                .tag(FocusQuestTab.stats)
            ProfileView(model: container.profileViewModel)
                .tabPage(reserve: reserve)
                .tag(FocusQuestTab.profile)
        }
    }

    /// Prechod do tmy pod listou + samotna lista, obe merene od spodni hrany displeje.
    private var tabChrome: some View {
        ZStack(alignment: .bottom) {
            TabBarFade()
            FocusQuestTabBar(selection: $selectedTab, profile: container.profileViewModel) { wins in
                withAnimation(.easeOut(duration: 0.2)) {
                    toast = "The Shop opens after \(FQTabBarMetrics.shopWins) wins (\(wins)/\(FQTabBarMetrics.shopWins))"
                }
            }
            .padding(.horizontal, FQTabBarMetrics.sideInset)
            .padding(.bottom, FQTabBarMetrics.bottom)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
    }

    /// Start ve Fight sheetu: list se zavrel, ted zacne bitva (polozeni telefonu) pres celou obrazovku.
    /// Prestavka zavrela bitvu s cilem: Fight sheet posledniho bosse, nebo zalozka Path.
    private func openAfterBattle() {
        guard let destination = battlePresenter.afterBattle else { return }
        battlePresenter.afterBattle = nil
        switch destination {
        case .fightSheet: battlePresenter.openFightSheet()
        case .path: selectedTab = .path
        }
    }

    private func startBattleAfterFightSheet() {
        guard battlePresenter.startsAfterSheet else { return }
        battlePresenter.startsAfterSheet = false
        container.arenaViewModel.startSession()
        battlePresenter.isPresented = true
    }

    /// Pri prvnim spusteni si hrac vytvori hrdinu. Screenshoty zalozek v CI tuhle obrazovku preskakuji.
    private func presentHeroCreatorIfNeeded() async {
        await container.profileViewModel.refresh()
        await container.profileViewModel.refreshProgress()
        let argument = FocusQuestTab.launchArgument
        guard argument == nil || argument == "creator" else { return }
        if !container.profileViewModel.profile.hasCreatedHero { showsHeroCreator = true }
    }
}

private extension View {
    /// Skryje systemovou listu a necha dole misto, aby posledni karta nekoncila pod plovouci listou.
    func tabPage(reserve: CGFloat) -> some View {
        toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: reserve) }
    }
}

/// Plovouci sklenena lista: jen ikony (popisky zustavaji pro VoiceOver).
private struct FocusQuestTabBar: View {
    @Binding var selection: FocusQuestTab
    @ObservedObject var profile: ProfileViewModel
    /// Klepnuti na zamceny Obchod; parametr je pocet vyher (max 3).
    let onLockedTap: (Int) -> Void

    private var wins: Int { min(FQTabBarMetrics.shopWins, profile.stats.wins) }
    private var isShopLocked: Bool { profile.stats.wins < FQTabBarMetrics.shopWins }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FocusQuestTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .frame(height: FQTabBarMetrics.height)
        .background {
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color(red: 40 / 255, green: 40 / 255, blue: 48 / 255).opacity(0.45))
            }
            .shadow(color: .black.opacity(0.35), radius: 15, y: 10)
        }
    }

    private func tabButton(_ tab: FocusQuestTab) -> some View {
        let isOn = selection == tab
        let isLocked = tab == .shop && isShopLocked
        return Button {
            if isLocked { onLockedTap(wins) } else { selection = tab }
        } label: {
            TabIcon(tab: tab)
                .frame(width: FQTabBarMetrics.iconSize, height: FQTabBarMetrics.iconSize)
                .foregroundStyle(isOn ? FQColor.cta : FQColor.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { if isOn { Capsule().fill(Color.white.opacity(0.14)) } }
                .overlay(alignment: .topTrailing) {
                    if isLocked {
                        Text("🔒 \(wins)/\(FQTabBarMetrics.shopWins)")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(FQColor.textPrimary)
                            .padding(.top, 4)
                            .padding(.trailing, 6)
                    }
                }
                .opacity(isLocked ? 0.45 : 1)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLocked ? "\(tab.title), locked, \(wins) of \(FQTabBarMetrics.shopWins) wins" : tab.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Ikony zalozek. Arena a Hero jsou obrysove kresby z prototypu, ostatni zustavaji plne SF Symbols.
private struct TabIcon: View {
    let tab: FocusQuestTab

    var body: some View {
        // V prototypu je tah 2 v mrizce 24 bodu, prepocteno na 26 bodu.
        let stroke = StrokeStyle(lineWidth: 2 * FQTabBarMetrics.iconSize / 24, lineCap: .round, lineJoin: .round)
        switch tab {
        case .arena: ArenaHouseShape().stroke(style: stroke)
        case .profile: HeroCircleShape().stroke(style: stroke)
        case .path: symbol("map.fill")
        case .shop: symbol("bag.fill")
        case .stats: symbol("chart.bar.fill")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 21, weight: .semibold))
            .accessibilityHidden(true)
    }
}

/// Domek s oblymi dvermi (SVG z prototypu v mrizce 24 x 24).
private struct ArenaHouseShape: Shape {
    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 24
        let o = CGPoint(x: rect.midX - 12 * k, y: rect.midY - 12 * k)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * k, y: o.y + y * k) }
        // Ctvrtkruh polomeru 3 jako kubicka krivka (0,5523 * 3).
        let c: CGFloat = 1.657
        var path = Path()
        path.move(to: p(4, 10.5))
        path.addLine(to: p(12, 4))
        path.addLine(to: p(20, 10.5))
        path.addLine(to: p(20, 19))
        path.addQuadCurve(to: p(18.5, 20.5), control: p(20, 20.5))
        path.addLine(to: p(15, 20.5))
        path.addLine(to: p(15, 15.5))
        path.addCurve(to: p(12, 12.5), control1: p(15, 15.5 - c), control2: p(12 + c, 12.5))
        path.addCurve(to: p(9, 15.5), control1: p(12 - c, 12.5), control2: p(9, 15.5 - c))
        path.addLine(to: p(9, 20.5))
        path.addLine(to: p(5.5, 20.5))
        path.addQuadCurve(to: p(4, 19), control: p(4, 20.5))
        path.closeSubpath()
        return path
    }
}

/// Postava v kruhu (SVG z prototypu v mrizce 24 x 24).
private struct HeroCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 24
        let o = CGPoint(x: rect.midX - 12 * k, y: rect.midY - 12 * k)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * k, y: o.y + y * k) }
        var path = Path()
        path.addEllipse(in: CGRect(x: o.x + 2.5 * k, y: o.y + 2.5 * k, width: 19 * k, height: 19 * k))
        path.addEllipse(in: CGRect(x: o.x + 9 * k, y: o.y + 7 * k, width: 6 * k, height: 6 * k))
        path.move(to: p(6.6, 18.4))
        path.addCurve(to: p(12, 15.4), control1: p(7.9, 16.4), control2: p(9.7, 15.4))
        path.addCurve(to: p(17.4, 18.4), control1: p(14.3, 15.4), control2: p(16.1, 16.4))
        return path
    }
}

/// Obsah pod listou plynule mizi do tmy: pruhledna -> 92 % ve 45 % -> plna #060510 v 70 %.
private struct TabBarFade: View {
    var body: some View {
        let ink = Color(red: 6 / 255, green: 5 / 255, blue: 16 / 255)
        LinearGradient(
            stops: [
                .init(color: ink.opacity(0), location: 0),
                .init(color: ink.opacity(0.92), location: 0.45),
                .init(color: ink, location: 0.70),
                .init(color: ink, location: 1),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: FQTabBarMetrics.height + FQTabBarMetrics.bottom + 36)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct IntegrityLockdownView: View {
    var body: some View {
        ZStack {
            FocusQuestBackdrop(alert: true, scene: .dungeonRuins)
            VStack(spacing: FQSpace.lg) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(FQColor.danger)
                    .accessibilityHidden(true)
                VStack(spacing: FQSpace.sm) {
                    Text("Integrity check failed").font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                    Text("FocusQuest has disabled battles on this device to protect account integrity.")
                        .font(.fqSecondary)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textSecondary)
                }
            }
            .padding(FQSpace.xl)
            .frame(maxWidth: 360)
            .glassCard()
            .padding(.horizontal, FQSpace.xl)
        }
    }
}
