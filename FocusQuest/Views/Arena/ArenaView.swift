import SwiftUI

/// Kam se v Arene da dojit: vyber sveta -> cesta sveta -> bitva.
enum ArenaRoute: Hashable {
    case path(BossWorld)
    case battle
}

/// Arena: uvodni menu svetu. Kazdy svet ma vlastni cestu bossu jako v Duolingu.
struct ArenaView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    @State private var route: [ArenaRoute] = ArenaView.initialRoute

    var body: some View {
        NavigationStack(path: $route) {
            ScreenScaffold(scene: .lanternGrove) {
                ScreenHeader(eyebrow: "Arena", title: "Choose a world")
                heroStatus
                ForEach(BossWorld.allCases) { world in
                    NavigationLink(value: ArenaRoute.path(world)) { WorldCard(world: world, cleared: model.clearedNodes(in: world)) }
                        .buttonStyle(.plain)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ArenaRoute.self) { destination in
                switch destination {
                case .path(let world):
                    WorldPathView(model: model, world: world) { route.append(.battle) }
                case .battle:
                    BattleView(model: model, profileModel: profileModel) {
                        // Po vitezstvi nebo prohre zpatky na cestu, kde je videt odemceny dalsi uzel.
                        if route.last == .battle { route.removeLast() }
                    }
                }
            }
        }
        .onChange(of: model.isBattleRunning) { _, running in
            // Bezici bitva musi byt videt, i kdyby ji hrac spustil a pak odesel o obrazovku zpet.
            if running, route.last != .battle { route = [.path(model.selectedBoss.world), .battle] }
        }
    }

    /// Kratky prehled hrdiny nad svety: serie dni a zdravi.
    private var heroStatus: some View {
        let stats = profileModel.stats
        return HStack(spacing: FQSpace.md) {
            StreakBadge(days: stats.currentStreak())
            HeroHealthBar(hp: stats.heroHP, maxHP: PlayerStats.maxHeroHP)
        }
        .padding(FQSpace.lg)
        .glassCard()
    }

    /// V debug buildu: `-initialTab path` otevre cestu prvniho sveta, `-initialTab battle` rovnou bitvu (CI screenshoty).
    static var initialRoute: [ArenaRoute] {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "initialTab") {
        case "path": return [.path(.heroes)]
        case "battle": return [.path(.heroes), .battle]
        default: return []
        }
        #else
        return []
        #endif
    }

    /// "25 min" nebo "1 h 30 min".
    static func durationText(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(rest) min"
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
