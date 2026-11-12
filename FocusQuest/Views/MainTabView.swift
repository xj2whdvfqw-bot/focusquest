import SwiftUI

private enum FocusQuestTab: String, CaseIterable, Identifiable {
    case arena, stats, profile, settings
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .arena: "flame.fill"
        case .stats: "chart.bar.fill"
        case .profile: "person.crop.circle.fill"
        case .settings: "gearshape.fill"
        }
    }

    /// V debug buildu jde vychozi zalozku zvolit argumentem `-initialTab stats`.
    /// Pouziva to CI, aby vyfotilo vsechny obrazovky v simulatoru.
    static var initial: FocusQuestTab {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "initialTab"), let tab = FocusQuestTab(rawValue: raw) { return tab }
        #endif
        return .arena
    }
}

struct MainTabView: View {
    let container: AppDIContainer
    @State private var selectedTab = FocusQuestTab.initial

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
                    StatsView(model: container.statsViewModel, profile: container.profileViewModel)
                        .tabItem { Label(FocusQuestTab.stats.title, systemImage: FocusQuestTab.stats.symbol) }
                        .tag(FocusQuestTab.stats)
                    ProfileView(model: container.profileViewModel)
                        .tabItem { Label(FocusQuestTab.profile.title, systemImage: FocusQuestTab.profile.symbol) }
                        .tag(FocusQuestTab.profile)
                    SettingsView(model: container.settingsViewModel)
                        .tabItem { Label(FocusQuestTab.settings.title, systemImage: FocusQuestTab.settings.symbol) }
                        .tag(FocusQuestTab.settings)
                }
            }
        }
        .tint(FQColor.accent)
        .preferredColorScheme(.dark)
    }
}

private struct IntegrityLockdownView: View {
    var body: some View {
        ZStack {
            FocusQuestBackdrop(alert: true)
            VStack(spacing: FQSpace.lg) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(FQColor.danger)
                    .accessibilityHidden(true)
                VStack(spacing: FQSpace.sm) {
                    Text("Integrity check failed").font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                    Text("FocusQuest has disabled battles on this device to protect account and raid integrity.")
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
