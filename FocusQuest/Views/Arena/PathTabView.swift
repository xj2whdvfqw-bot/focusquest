import SwiftUI

/// Zalozka Path: "Choose a world". Vsechny svety jsou na zacatku sbalene; klepnuti na kartu
/// ji rozbali na miste a ukaze vsechny bosse sveta v mrizce 3 sloupcu. Nic neni zamcene,
/// hrac si vybere, s kym bude bojovat. Zadny "dalsi" boss se nezvyraznuje.
struct PathTabView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    @Environment(BattlePresenter.self) private var battle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Rozbaleny svet (vzdy nejvys jeden), nil = vse sbalene.
    @State private var openWorld: BossWorld? = PathTabView.initialOpenWorld

    /// Vyhry nad kazdym bossem cest (id -> pocet) z Bestiare; rychle bitvy (rozcvicka) se nepocitaji.
    private var winsByBoss: [String: Int] { profileModel.stats.pathWins }

    var body: some View {
        let wins = winsByBoss
        ScreenScaffold(scene: .enchantedForest) {
            ScreenHeader(eyebrow: "Path", title: "Choose a world")
            VStack(spacing: FQSpace.lg) {
                ForEach(BossWorld.allCases) { world in
                    WorldCard(
                        world: world,
                        cleared: model.clearedNodes(in: world),
                        wins: wins,
                        isOpen: openWorld == world,
                        canFight: model.isBetweenBattles,
                        onToggle: { toggle(world) },
                        onPick: pick
                    )
                }
            }
        }
    }

    /// Karta se plynule zvetsi a mrizka se na miste odkryje (fade + vyska, 0,25 s).
    /// S Reduce Motion se svet otevre hned, bez animace.
    private func toggle(_ world: BossWorld) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            openWorld = openWorld == world ? nil : world
        }
    }

    private func pick(_ boss: Boss) {
        model.selectBoss(boss)
        battle.openFightSheet()
    }

    /// V debug buildu `-initialTab path` rozbali prvni svet (CI screenshoty).
    static var initialOpenWorld: BossWorld? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "initialTab") == "path" ? .heroes : nil
        #else
        return nil
        #endif
    }
}

/// Karta sveta: nazev, podtitul, "2 / 4 cleared" a lista postupu v barve sveta. Bez ikony.
private struct WorldCard: View {
    let world: BossWorld
    let cleared: Int
    let wins: [String: Int]
    let isOpen: Bool
    let canFight: Bool
    let onToggle: () -> Void
    let onPick: (Boss) -> Void

    private var bosses: [Boss] { world.bosses }
    private var isComplete: Bool { cleared >= bosses.count }
    private static let columnCount = 3

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) { header }
                .buttonStyle(.plain)
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
                        BossTile(
                            boss: bosses[index],
                            number: index + 1,
                            accent: world.accent,
                            wins: max(index < cleared ? 1 : 0, wins[bosses[index].id] ?? 0),
                            action: { onPick(bosses[index]) }
                        )
                        .disabled(!canFight)
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
                    Text(world.title)
                        .fqFont(size: 17, weight: .semibold, design: .rounded)
                        .foregroundStyle(FQColor.textPrimary)
                    Text(world.tagline)
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
/// Porazeny boss ma na spritu zelenou pilulku "✓ 3×" s poctem vyher.
private struct BossTile: View {
    let boss: Boss
    let number: Int
    let accent: Color
    let wins: Int
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
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel(wins > 0 ? "\(boss.name), defeated \(wins) times. Fight again, \(boss.maxHP) minutes" : "Fight \(boss.name), \(boss.maxHP) minutes")
    }

    private var art: some View {
        ZStack {
            Circle().fill(accent.opacity(0.18))
            PixelArtAvatarView(sprite: .boss(boss.pixelSpriteConfig), size: 52)
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
            if wins > 0 { WinsPill(count: wins).offset(x: 4, y: 2) }
        }
        .accessibilityHidden(true)
    }
}

/// Zelena pilulka "✓ 3×" na spritu porazeneho bosse.
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
        .background(Color(red: 29 / 255, green: 43 / 255, blue: 38 / 255), in: Capsule())
        .overlay { Capsule().strokeBorder(Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255).opacity(0.9), lineWidth: 2).padding(-2) }
    }
}

/// Dlazdice se pri stisku malinko zmackne (0,97), jako v prototypu.
private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
