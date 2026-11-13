import SwiftUI

private enum FocusQuestTab: String, CaseIterable, Identifiable {
    case arena, village, shop, stats, profile
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .arena: "flame.fill"
        case .village: "house.fill"
        case .shop: "bag.fill"
        case .stats: "chart.bar.fill"
        case .profile: "person.crop.circle.fill"
        }
    }

    /// V debug buildu jde appku spustit s argumentem `-initialTab stats` (vychozi zalozka)
    /// nebo `-initialTab creator` (uvodni tvorba hrdiny) ci `-initialTab settings`
    /// (Profil s otevrenym Nastavenim). Pouziva to CI pro screenshoty.
    static var launchArgument: String? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "initialTab")
        #else
        return nil
        #endif
    }

    static var initial: FocusQuestTab {
        if launchArgument == "settings" { return .profile }
        return launchArgument.flatMap(FocusQuestTab.init(rawValue:)) ?? .arena
    }
}

struct MainTabView: View {
    let container: AppDIContainer
    @State private var selectedTab = FocusQuestTab.initial
    @State private var showsHeroCreator = false
    /// Ozubene kolo na kazde zalozce otevira tentyz list Nastaveni.
    @State private var settingsPresenter = SettingsPresenter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if container.isIntegrityCompromised {
                IntegrityLockdownView()
            } else {
                // Systemovy TabView: na iOS 26 dostane plovouci Liquid Glass listu sam od systemu.
                TabView(selection: $selectedTab) {
                    ArenaView(model: container.arenaViewModel, profileModel: container.profileViewModel)
                        .tabItem { Label(FocusQuestTab.arena.title, systemImage: FocusQuestTab.arena.symbol) }
                        .tag(FocusQuestTab.arena)
                    VillageView(model: container.profileViewModel)
                        .tabItem { Label(FocusQuestTab.village.title, systemImage: FocusQuestTab.village.symbol) }
                        .tag(FocusQuestTab.village)
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
                .sheet(isPresented: Binding(get: { settingsPresenter.isPresented }, set: { settingsPresenter.isPresented = $0 })) {
                    SettingsView(model: container.settingsViewModel) { settingsPresenter.isPresented = false }
                        .presentationDragIndicator(.visible)
                }
                .task {
                    container.appBlocker.startObservingScreenLock()
                    if FocusQuestTab.launchArgument == "settings" { settingsPresenter.isPresented = true }
                    await presentHeroCreatorIfNeeded()
                }
                // Odchod z appky behem bitvy: upozorneni a po 10 s propadly quest.
                .onChange(of: scenePhase) { _, phase in container.appBlocker.handleScenePhase(phase) }
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
