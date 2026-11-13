import SwiftUI

private enum FocusQuestTab: String, CaseIterable, Identifiable {
    case arena, path, shop, stats, profile
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .arena: "flame.fill"
        case .path: "map.fill"
        case .shop: "bag.fill"
        case .stats: "chart.bar.fill"
        case .profile: "person.crop.circle.fill"
        }
    }

    /// V debug buildu jde appku spustit s argumentem `-initialTab stats` (vychozi zalozka)
    /// nebo `-initialTab creator` (uvodni tvorba hrdiny) ci `-initialTab settings`
    /// (Profil s otevrenym Nastavenim). `village` otevre Obchod na vesnici, `battle` obrazovku
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
        case "village": return .shop
        case "battle": return .arena
        default: break
        }
        return launchArgument.flatMap(FocusQuestTab.init(rawValue:)) ?? .arena
    }
}

struct MainTabView: View {
    let container: AppDIContainer
    @State private var selectedTab = FocusQuestTab.initial
    @State private var showsHeroCreator = false
    /// Ozubene kolo na kazde zalozce otevira tentyz list Nastaveni.
    @State private var settingsPresenter = SettingsPresenter()
    /// Bitva bezi pres celou obrazovku nad zalozkami, takze spodni lista neni videt.
    @State private var battlePresenter = BattlePresenter()

    var body: some View {
        Group {
            if container.isIntegrityCompromised {
                IntegrityLockdownView()
            } else {
                // Systemovy TabView: na iOS 26 dostane plovouci Liquid Glass listu sam od systemu.
                TabView(selection: $selectedTab) {
                    ArenaView(model: container.arenaViewModel, profileModel: container.profileViewModel) { selectedTab = .path }
                        .tabItem { Label(FocusQuestTab.arena.title, systemImage: FocusQuestTab.arena.symbol) }
                        .tag(FocusQuestTab.arena)
                    PathTabView(model: container.arenaViewModel)
                        .tabItem { Label(FocusQuestTab.path.title, systemImage: FocusQuestTab.path.symbol) }
                        .tag(FocusQuestTab.path)
                    ShopView(model: container.profileViewModel)
                        .tabItem { Label(FocusQuestTab.shop.title, systemImage: FocusQuestTab.shop.symbol) }
                        .tag(FocusQuestTab.shop)
                    StatsView(model: container.statsViewModel, profile: container.profileViewModel)
                        .tabItem { Label(FocusQuestTab.stats.title, systemImage: FocusQuestTab.stats.symbol) }
                        .tag(FocusQuestTab.stats)
                    ProfileView(model: container.profileViewModel)
                        .tabItem { Label(FocusQuestTab.profile.title, systemImage: FocusQuestTab.profile.symbol) }
                        .tag(FocusQuestTab.profile)
                }
                .environment(settingsPresenter)
                .environment(battlePresenter)
                .sheet(isPresented: Binding(get: { settingsPresenter.isPresented }, set: { settingsPresenter.isPresented = $0 })) {
                    SettingsView(model: container.settingsViewModel) { settingsPresenter.isPresented = false }
                        .presentationDragIndicator(.visible)
                }
                .fullScreenCover(isPresented: Binding(get: { battlePresenter.isPresented }, set: { battlePresenter.isPresented = $0 })) {
                    BattleView(model: container.arenaViewModel, profileModel: container.profileViewModel) { battlePresenter.isPresented = false }
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

    /// Pri prvnim spusteni si hrac vytvori hrdinu. Screenshoty zalozek v CI tuhle obrazovku preskakuji.
    private func presentHeroCreatorIfNeeded() async {
        await container.profileViewModel.refresh()
        await container.profileViewModel.refreshProgress()
        let argument = FocusQuestTab.launchArgument
        guard argument == nil || argument == "creator" else { return }
        if !container.profileViewModel.profile.hasCreatedHero { showsHeroCreator = true }
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
