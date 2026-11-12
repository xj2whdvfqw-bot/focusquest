import SwiftUI

private enum FocusQuestTab: String, CaseIterable, Identifiable {
    case arena, stats, profile, settings
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self { case .arena: "sparkles.rectangle.stack"; case .stats: "chart.bar.xaxis"; case .profile: "person.crop.square"; case .settings: "slider.horizontal.3" }
    }
}

struct MainTabView: View {
    let container: AppDIContainer
    @State private var selectedTab: FocusQuestTab = .arena

    var body: some View {
        Group {
            if container.isIntegrityCompromised {
                IntegrityLockdownView()
            } else { switch selectedTab {
            case .arena: ArenaView(model: container.arenaViewModel, profileModel: container.profileViewModel)
            case .stats: StatsView(model: container.statsViewModel, profile: container.profileViewModel)
            case .profile: ProfileView(model: container.profileViewModel)
            case .settings: SettingsView(model: container.settingsViewModel)
            } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 6) {
                ForEach(FocusQuestTab.allCases) { tab in
                    Button { selectedTab = tab } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.symbol).font(.system(size: 17, weight: .semibold))
                            Text(tab.title).font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(selectedTab == tab ? Color.mint : Color.white.opacity(0.58))
                        .frame(maxWidth: .infinity).frame(height: 51)
                        .background(selectedTab == tab ? Color.white.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 13))
                    }.buttonStyle(.plain).accessibilityLabel(tab.title)
                }
            }
            .padding(7).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 22).padding(.bottom, 6)
        }
        .preferredColorScheme(.dark)
    }
}

private struct IntegrityLockdownView: View {
    var body: some View {
        ZStack {
            FocusQuestBackdrop(alert: true)
            VStack(spacing: 14) {
                Image(systemName: "lock.shield.fill").font(.system(size: 42)).foregroundStyle(.red)
                Text("Integrity check failed").font(.system(size: 22, weight: .bold, design: .rounded))
                Text("FocusQuest has disabled battles on this device to protect account and raid integrity.").font(.system(size: 14, design: .rounded)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7))
            }.padding(28).glassmorphic()
        }.preferredColorScheme(.dark)
    }
}