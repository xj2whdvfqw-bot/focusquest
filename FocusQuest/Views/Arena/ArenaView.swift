import SwiftUI

/// Otevira bitvu pres celou obrazovku (bez spodni listy) odkudkoli: z Areny, z cesty sveta
/// nebo z Custom Focus. MainTabView ho vlozi do prostredi a sam bitvu prezentuje.
@Observable
@MainActor
final class BattlePresenter {
    var isPresented = false
}

/// Arena: domovska obrazovka. Nahore velke tlacitko Custom Focus, pod nim stav hrdiny
/// a dalsi uzel cesty. Samotne svety s cestami jsou na zalozce Path.
struct ArenaView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    /// Prepne na zalozku Path se vsemi svety.
    let openPath: () -> Void
    @Environment(BattlePresenter.self) private var battle
    @State private var showsCustomFocus = false
    /// Zvolena delka a predmet. Bitva zacne az po zavreni listu: bezici bitva se hned
    /// prezentuje pres celou obrazovku a dve prezentace naraz SwiftUI neumi.
    @State private var pendingCustom: (minutes: Int, subject: StudySubject)?

    /// Svet, ve kterem hrac naposledy bojoval, a jeho dalsi neporazeny uzel.
    private var world: BossWorld { model.selectedBoss.world }
    private var cleared: Int { model.clearedNodes(in: world) }
    private var nextNode: Boss? { cleared < world.bosses.count ? world.bosses[cleared] : nil }

    var body: some View {
        ScreenScaffold(scene: .lanternGrove) {
            ScreenHeader(eyebrow: "Arena", title: "Ready to focus?")
            customFocusButton
            heroStatus
            continueCard
        }
        .sheet(isPresented: $showsCustomFocus, onDismiss: {
            guard let pending = pendingCustom else { return }
            pendingCustom = nil
            model.startCustomBattle(minutes: pending.minutes, subject: pending.subject)
            battle.isPresented = true
        }) {
            CustomFocusSheet(model: model) { minutes, subject in
                pendingCustom = (minutes, subject)
                showsCustomFocus = false
            }
        }
    }

    /// Hlavni akce domovske obrazovky: vlastni delka a nahodny boss.
    private var customFocusButton: some View {
        Button { showsCustomFocus = true } label: {
            HStack(spacing: FQSpace.lg) {
                Image(systemName: "timer")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(FQColor.onAccent)
                    .frame(width: 60, height: 60)
                    .background(FQColor.accent, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    Text("Custom Focus").font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                    Text("25 min, 50 min or 1 h against a random boss")
                        .font(.fqSecondary)
                        .foregroundStyle(FQColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: FQSpace.sm)
                Image(systemName: "chevron.right")
                    .font(.fqLabel)
                    .foregroundStyle(FQColor.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FQSpace.xl)
            .padding(.vertical, FQSpace.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(tint: FQColor.accent.opacity(0.25))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!model.isBetweenBattles)
        .accessibilityHint("Choose a length and start a battle")
    }

    /// Kratky prehled hrdiny: serie dni a zdravi.
    private var heroStatus: some View {
        let stats = profileModel.stats
        return HStack(spacing: FQSpace.lg) {
            StreakBadge(days: stats.currentStreak())
            HeroHealthBar(hp: stats.heroHP, maxHP: PlayerStats.maxHeroHP)
        }
        .padding(FQSpace.xl)
        .glassCard()
    }

    /// Dalsi uzel cesty jednim klepnutim; vsechny svety jsou na zalozce Path.
    private var continueCard: some View {
        VStack(alignment: .leading, spacing: FQSpace.lg) {
            Text("Continue your path").font(.fqLabel).foregroundStyle(FQColor.textSecondary)
            if let node = nextNode {
                HStack(spacing: FQSpace.lg) {
                    PixelArtAvatarView(sprite: .boss(node.pixelSpriteConfig), size: 56)
                        .frame(width: 72, height: 72)
                        .background(world.accent.opacity(0.16), in: Circle())
                    VStack(alignment: .leading, spacing: FQSpace.xs) {
                        Text(node.name).font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                        Text("Node \(node.nodeIndex + 1) · \(world.title) · \(ArenaView.durationText(minutes: node.maxHP))")
                            .font(.fqMeta)
                            .foregroundStyle(FQColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                Button {
                    model.selectBoss(node)
                    battle.isPresented = true
                } label: {
                    Label("Fight", systemImage: "play.fill")
                        .font(.fqHeadline)
                        .foregroundStyle(FQColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(world.accent, in: RoundedRectangle(cornerRadius: FQRadius.pill, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!model.isBetweenBattles)
            } else {
                Label("\(world.title) conquered", systemImage: "checkmark.seal.fill")
                    .font(.fqHeadline)
                    .foregroundStyle(world.accent)
            }
            Button(action: openPath) {
                Text("See all worlds")
                    .font(.fqLabel)
                    .foregroundStyle(FQColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(FQSpace.xl)
        .glassCard()
    }

    /// "25 min" nebo "1 h 30 min".
    static func durationText(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(rest) min"
    }
}

/// List Custom Focus: delka 25 / 50 / 60 minut a predmet, pak bitva s nahodnym odemcenym bossem.
struct CustomFocusSheet: View {
    @ObservedObject var model: ArenaViewModel
    /// Hrac zvolil delku a predmet; volajici zavre list a spusti bitvu.
    let onStart: (Int, StudySubject) -> Void
    @State private var minutes = 25
    @State private var subject: StudySubject?

    static let options = [25, 50, 60]

    var body: some View {
        VStack(spacing: FQSpace.xxl) {
            VStack(spacing: FQSpace.sm) {
                Text("Custom Focus").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(FQColor.textPrimary)
                Text("A random boss you've unlocked. Custom battles don't move you along the path.")
                    .font(.fqSecondary)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(FQColor.textSecondary)
            }
            HStack(spacing: FQSpace.md) {
                ForEach(Self.options, id: \.self) { option in
                    let isSelected = option == minutes
                    Button { minutes = option } label: {
                        VStack(spacing: 2) {
                            Text(option == 60 ? "1" : "\(option)")
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Text(option == 60 ? "hour" : "min").font(.fqMeta)
                        }
                        .foregroundStyle(isSelected ? FQColor.onAccent : FQColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 96)
                        .background(isSelected ? AnyShapeStyle(FQColor.accent) : AnyShapeStyle(FQColor.fill), in: RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ArenaView.durationText(minutes: option))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            VStack(spacing: FQSpace.md) {
                Text("What are you studying?").font(.fqLabel).foregroundStyle(FQColor.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FQSpace.sm) {
                        ForEach(StudySubject.allCases) { item in
                            let isSelected = item == subject
                            Button { subject = item } label: {
                                Label(item.title, systemImage: item.symbol)
                                    .font(.fqLabel)
                                    .foregroundStyle(isSelected ? FQColor.onAccent : FQColor.textPrimary)
                                    .padding(.horizontal, FQSpace.lg)
                                    .frame(height: 40)
                                    .background(isSelected ? AnyShapeStyle(FQColor.accent) : AnyShapeStyle(FQColor.fill), in: RoundedRectangle(cornerRadius: FQRadius.pill, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .scrollClipDisabled()
            }
            Button {
                guard let subject else { return }
                onStart(minutes, subject)
            } label: {
                Label("Start \(ArenaView.durationText(minutes: minutes)) Focus", systemImage: "play.fill")
                    .font(.fqHeadline)
                    .foregroundStyle(FQColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(FQColor.accent, in: RoundedRectangle(cornerRadius: FQRadius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(subject == nil)
            .opacity(subject == nil ? 0.35 : 1)
        }
        .padding(.horizontal, FQSpace.xl)
        .padding(.top, FQSpace.xxl)
        .padding(.bottom, FQSpace.lg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .onAppear { subject = model.selectedSubject }
    }
}

/// Zalozka Path: seznam svetu, kazdy s vlastni cestou bossu jako v Duolingu.
struct PathTabView: View {
    @ObservedObject var model: ArenaViewModel
    @Environment(BattlePresenter.self) private var battle
    @State private var route: [BossWorld] = PathTabView.initialRoute

    var body: some View {
        NavigationStack(path: $route) {
            ScreenScaffold(scene: .enchantedForest) {
                ScreenHeader(eyebrow: "Path", title: "Choose a world")
                ForEach(BossWorld.allCases) { world in
                    NavigationLink(value: world) { WorldCard(world: world, cleared: model.clearedNodes(in: world)) }
                        .buttonStyle(.plain)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: BossWorld.self) { world in
                WorldPathView(model: model, world: world) { battle.isPresented = true }
            }
        }
    }

    /// V debug buildu `-initialTab path` otevre cestu prvniho sveta (CI screenshoty).
    static var initialRoute: [BossWorld] {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "initialTab") == "path" ? [.heroes] : []
        #else
        return []
        #endif
    }
}

// MARK: - Vzhled svetu

extension BossWorld {
    var accent: Color {
        switch self {
        case .heroes: Color(red: 0.95, green: 0.35, blue: 0.38)
        case .villains: Color(red: 0.66, green: 0.47, blue: 0.95)
        case .sewerDojo: Color(red: 0.38, green: 0.82, blue: 0.48)
        case .fairyTale: Color(red: 0.98, green: 0.78, blue: 0.36)
        case .brainrot: Color(red: 0.36, green: 0.80, blue: 0.92)
        }
    }

    var scene: BackdropScene {
        switch self {
        case .heroes: .castleKeep
        case .villains: .dungeonRuins
        case .sewerDojo: .lanternGrove
        case .fairyTale: .enchantedForest
        case .brainrot: .starlitPeaks
        }
    }

    /// "10-40 min" - rozsah pevnych delek uzlu ve svete.
    var durationRange: String {
        guard let first = bosses.first, let last = bosses.last else { return "" }
        return "\(first.maxHP)–\(last.maxHP) min"
    }
}

private struct WorldCard: View {
    let world: BossWorld
    let cleared: Int

    private var total: Int { world.bosses.count }
    private var isComplete: Bool { cleared >= total }

    var body: some View {
        VStack(alignment: .leading, spacing: FQSpace.md) {
            HStack(alignment: .top, spacing: FQSpace.md) {
                Image(systemName: world.symbol)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(world.accent)
                    .frame(width: 44, height: 44)
                    .background(world.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    Text(world.title).font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                    Text(world.tagline).font(.fqMeta).foregroundStyle(FQColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: FQSpace.sm)
                Image(systemName: "chevron.right")
                    .font(.fqLabel)
                    .foregroundStyle(FQColor.textSecondary)
                    .accessibilityHidden(true)
            }
            HStack(spacing: -FQSpace.sm) {
                ForEach(Array(world.bosses.prefix(5))) { boss in
                    PixelArtAvatarView(sprite: .boss(boss.pixelSpriteConfig), size: 36)
                        .padding(2)
                        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: FQRadius.tile, style: .continuous))
                }
                Spacer(minLength: FQSpace.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(isComplete ? "Conquered" : "\(cleared) / \(total) cleared")
                        .font(.fqLabel)
                        .foregroundStyle(isComplete ? world.accent : FQColor.textPrimary)
                    Text(world.durationRange).font(.fqMeta).monospacedDigit().foregroundStyle(FQColor.textSecondary)
                }
            }
            ProgressView(value: Double(cleared), total: Double(max(1, total)))
                .tint(world.accent)
        }
        .padding(FQSpace.lg)
        .glassCard(tint: world.accent.opacity(0.35))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the boss path")
    }
}

// MARK: - Sdilene stavebni bloky (Arena, Stats)

/// Serie dni s ohnem; sedy plamen = dnes jeste zadna bitva.
struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: FQSpace.sm) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(days > 0 ? AnyShapeStyle(LinearGradient(colors: [Color.yellow, Color.orange, Color.red], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(FQColor.textSecondary))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(days)").font(.fqTitle).monospacedDigit().foregroundStyle(FQColor.textPrimary)
                Text(days == 1 ? "day streak" : "days streak").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Zdravi hrdiny; utek z bitvy ho snizuje, vyhry ho doplnuji.
struct HeroHealthBar: View {
    let hp: Int
    let maxHP: Int

    private var fraction: Double { maxHP > 0 ? Double(hp) / Double(maxHP) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: FQSpace.xs) {
            HStack {
                Label("Hero HP", systemImage: "heart.fill")
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
                Spacer()
                Text("\(hp) / \(maxHP)").font(.fqMeta).monospacedDigit().foregroundStyle(FQColor.textPrimary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(FQColor.track)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fraction > 0.3 ? FQColor.accent : FQColor.danger)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hero HP \(hp) of \(maxHP)")
    }
}
