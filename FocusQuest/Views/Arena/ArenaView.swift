import SwiftUI

/// Otevira bitvu pres celou obrazovku (bez spodni listy) odkudkoli: z Areny, z cesty sveta
/// nebo z Custom Focus. MainTabView ho vlozi do prostredi a sam bitvu prezentuje.
@Observable
@MainActor
final class BattlePresenter {
    var isPresented = false
    /// Fight sheet (predmet, zvuk, Start) pred bitvou z Areny nebo z dlazdice bosse na Path.
    var showsFightSheet = false
    /// Hrac zmackl Start: bitva zacne az po zavreni listu (dve prezentace naraz SwiftUI neumi).
    var startsAfterSheet = false
    /// Co otevrit, az se obrazovka bitvy zavre (z prestavky: "Same again" a "Change boss").
    var afterBattle: AfterBattle?

    enum AfterBattle { case fightSheet, path }

    /// Otevre Fight sheet pro uz vybraneho bosse.
    func openFightSheet() {
        startsAfterSheet = false
        showsFightSheet = true
    }
}

/// Arena: domovska obrazovka. Nahore nadpis a pilulka serie, dole v dosahu palce
/// dalsi boss cesty s tlacitkem Fight. Samotne svety s cestami jsou na zalozce Path.
/// Dva easter eggy: klepani na bosse (bublina s hlaskou) a 5 rychlych klepnuti na serii (ohen).
struct ArenaView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    /// Prepne na zalozku Path se vsemi svety.
    let openPath: () -> Void
    @Environment(BattlePresenter.self) private var battle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.shopBackground) private var shopBackground

    // 2a: klepani na bosse.
    @State private var poke: Poke?
    @State private var pokeSerial = 0
    @State private var pokeCount = 0
    @State private var lastPoke = Date.distantPast
    @State private var bobs = 0
    @State private var shakes = 0

    // 2b: serie v plamenech.
    @State private var streakTaps = 0
    @State private var lastStreakTap = Date.distantPast
    @State private var bumps = 0
    @State private var fireStart: Date?

    private struct Poke: Equatable {
        let id: Int
        let text: String
        let angry: Bool
    }

    /// Svet, ve kterem hrac naposledy bojoval, a jeho dalsi neporazeny boss.
    private var world: BossWorld { model.arenaPathBoss.world }
    private var cleared: Int { model.clearedNodes(in: world) }
    private var nextNode: Boss? { cleared < world.bosses.count ? world.bosses[cleared] : nil }

    /// Spodni hrana pilulky serie a horni hrana ramecku bosse (globalne): kolik mista ma bublina nad bossem.
    @State private var pillBottom: CGFloat = 0
    @State private var bossFrameTop: CGFloat = 0

    /// Ramecek bosse je 168 bodu, sprite 128, takze sprite zacina 20 bodu pod hornim okrajem.
    /// Spodek bubliny je 2 body nad hlavou, spicka ocasku tak miri tesne nad bosse.
    /// Na nizkem displeji (iPhone SE) je ramecek mensi, aby se Fight vesel nad listu zalozek.
    private var bossFrame: CGFloat { isCompact ? 140 : 168 }
    private var bubbleAnchor: CGFloat { (bossFrame - 128) / 2 - 2 }

    /// Vyska obrazovky Areny (bez listy zalozek); pod 620 bodu se mezery zmensi (iPhone SE, velke pismo).
    @State private var availableHeight: CGFloat = 0
    private var isCompact: Bool { availableHeight > 0 && availableHeight < 620 }

    /// Vyska, kterou bublina smi zabrat: od hlavy bosse po pilulku serie.
    private var bubbleRoom: CGFloat? {
        guard pillBottom > 0, bossFrameTop > 0 else { return nil }
        return max(56, bossFrameTop + bubbleAnchor - pillBottom - FQSpace.sm)
    }

    var body: some View {
        ScreenScaffold(scene: .lanternGrove, fillsHeight: true, spacing: isCompact ? FQSpace.sm : FQSpace.xl) {
            ScreenHeader(title: "Ready to focus?")
            streakPill
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { pillBottom = $0 }
            // Volne misto: 1 dil nad bossem, 2 dily pod nim. Boss tak sedi blizko stredu obrazovky
            // a mezi nim a tlacitkem Fight je vzduch. Kdyz se obsah nevejde (SE, velke pismo),
            // spacery maji jen minimum a obrazovka roluje.
            Spacer(minLength: isCompact ? FQSpace.xs : FQSpace.md)
            bossSection
            Spacer(minLength: isCompact ? FQSpace.sm : FQSpace.lg)
            Spacer(minLength: 0)
            actionSection
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { availableHeight = $0 }
        .task(id: poke?.id) {
            guard let current = poke else { return }
            try? await Task.sleep(for: .seconds(current.angry ? 2.6 : 2.2))
            guard !Task.isCancelled, poke?.id == current.id else { return }
            withAnimation(.easeOut(duration: 0.2)) { poke = nil }
        }
        .task(id: fireStart) {
            // Ohen se po ~4,5 s vzdy uklidi, i kdyz se mezitim znovu zapalil a zase dohorel.
            guard let started = fireStart else { return }
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled, fireStart == started else { return }
            fireStart = nil
        }
    }

    // MARK: - Serie

    private var streakPill: some View {
        let days = profileModel.stats.currentStreak()
        let burning = fireStart != nil
        return Button(action: tapStreak) {
            StreakBadge(days: days, burning: burning)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .glassCard(radius: FQRadius.capsule)
                .overlay {
                    Capsule()
                        .strokeBorder(Self.ember.opacity(0.55), lineWidth: 3)
                        .padding(-3)
                        .opacity(burning ? 1 : 0)
                        .animation(.easeOut(duration: 0.4), value: burning)
                }
                .overlay {
                    if let fireStart {
                        StreakFire(start: fireStart).padding(-StreakFire.pad)
                    }
                }
                .keyframeAnimator(initialValue: 1.0, trigger: bumps) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        MoveKeyframe(1.0)
                        CubicKeyframe(1.06, duration: 0.09)
                        CubicKeyframe(1.0, duration: 0.09)
                    }
                }
        }
        .buttonStyle(.fqPress)
        .accessibilityLabel(days == 1 ? "1 day streak" : "\(days) days streak")
    }

    /// Kazde klepnuti pilulku nafoukne; 5 klepnuti s rozestupem do 600 ms ji zapali.
    private func tapStreak() {
        let now = Date()
        streakTaps = now.timeIntervalSince(lastStreakTap) < 0.6 ? streakTaps + 1 : 1
        lastStreakTap = now
        if !reduceMotion { bumps += 1 }
        guard streakTaps >= 5 else { return }
        streakTaps = 0
        fireStart = now
        FQFeedback.shared.play(.levelUp)
    }

    /// #EB5016, oranzovy okraj horici pilulky.
    private static let ember = Color(red: 235 / 255, green: 80 / 255, blue: 22 / 255)

    // MARK: - Dalsi boss

    /// Stred obrazovky: "Continue your path", sprite, jmeno a "Boss 1 of 7".
    private var bossSection: some View {
        // Popisek, boss a jmeno drzi pohromade jako jeden blok.
        VStack(spacing: isCompact ? FQSpace.xs : FQSpace.sm) {
            Text("Continue your path")
                .font(.fqLabel)
                .foregroundStyle(FQColor.textSecondary)
                .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
            if let node = nextNode {
                VStack(spacing: FQSpace.xs) {
                    bossButton(node)
                    Text(node.name)
                        .fqFont(size: 24, weight: .bold, design: .rounded)
                        .foregroundStyle(FQColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
                    Text("Boss \(node.nodeIndex + 1) of \(world.bosses.count) · \(world.title)")
                        .font(.fqSecondary)
                        .foregroundStyle(FQColor.textSecondary)
                        .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
                }
            } else {
                Label("\(world.title) conquered", systemImage: "checkmark.seal.fill")
                    .font(.fqHeadline)
                    .foregroundStyle(world.accent)
            }
        }
        .frame(maxWidth: .infinity)
        // Bublina nad bossem lezi nad ostatnim obsahem (i nad nadpisem), nikdy pod nim.
        .zIndex(1)
    }

    /// Dole u palce: Fight a "Just 5 minutes" (nebo "Pick a world", kdyz je svet dobyty).
    private var actionSection: some View {
        VStack(spacing: isCompact ? FQSpace.xs : FQSpace.lg) {
            if let node = nextNode {
                fightButton(node)
                Button {
                    // Fight sheet s rozcvickou (Warm-up Wisp) na pevnych 5 minut.
                    model.prepareQuickBattle()
                    battle.openFightSheet()
                } label: {
                    Text("Not feeling it? Just 5 minutes")
                        .fqFont(size: 15, weight: .semibold, design: .rounded)
                        .underline()
                        .foregroundStyle(FQColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.fqPress)
                .disabled(!model.isBetweenBattles)
            } else {
                Button(action: openPath) { ctaLabel("Pick a world", symbol: "map.fill") }
                    .buttonStyle(.fqPress)
            }
        }
        .frame(maxWidth: .infinity)
        // Fight a "Just 5 minutes" nesedi nalepene na liste zalozek (po testu #54 o 24 pt vys).
        .padding(.bottom, isCompact ? FQSpace.sm : FQSpace.xl)
    }

    private func fightButton(_ node: Boss) -> some View {
        Button {
            model.selectBoss(node)
            battle.openFightSheet()
        } label: {
            ctaLabel("Fight · \(ArenaView.durationText(minutes: node.maxHP))", symbol: "play.fill")
        }
        .buttonStyle(.fqPress)
        .disabled(!model.isBetweenBattles)
    }

    /// Zlute hlavni tlacitko: zaoblene pismo, velke jen prvni pismeno.
    private func ctaLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .fqFont(size: 20, weight: .heavy, design: .rounded)
            .foregroundStyle(FQColor.onCta)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(FQColor.cta, in: RoundedRectangle(cornerRadius: FQRadius.pill, style: .continuous))
            // Tmavy text na zlute nedostane stin svetlych pozadi.
            .compositingGroup()
    }

    // MARK: - 2a: klepani na bosse

    /// Sprite 128 pt bez karty a kruhu. Klepnuti = bublina a poskoceni,
    /// 4+ rychla klepnuti = nastvany boss (tres, cervena zare, zvuk zasahu).
    private func bossButton(_ node: Boss) -> some View {
        let angry = poke?.angry == true
        return Button { pokeBoss(node) } label: {
            PixelArtAvatarView(sprite: .boss(node.pixelSpriteConfig), size: 128)
                .saturation(angry ? 1.4 : 1)
                .shadow(color: FQColor.danger.opacity(angry ? 0.8 : 0), radius: 10)
                // Na svetlych pozadich stoji boss bez kruhu jen s vrzenym stinem (0 6 10 rgba(0,0,0,.35)).
                .shadow(color: Color.black.opacity(shopBackground?.isLight == true ? 0.35 : 0), radius: 5, y: 6)
                .keyframeAnimator(initialValue: 0.0, trigger: bobs) { content, phase in
                    // Dve poskoceni: nahoru o 8 bodu s naklonem -3°, kazde 0,5 s.
                    let lift = sin(.pi * phase) * sin(.pi * phase)
                    content.offset(y: -8 * lift).rotationEffect(.degrees(-3 * lift))
                } keyframes: { _ in
                    KeyframeTrack {
                        MoveKeyframe(0.0)
                        LinearKeyframe(2.0, duration: 1.0)
                    }
                }
                .keyframeAnimator(initialValue: 0.0, trigger: shakes) { content, phase in
                    // 8 kmitu po 0,09 s: ±5 bodu a ±4°.
                    let swing = sin(2 * .pi * phase)
                    content.offset(x: -5 * swing).rotationEffect(.degrees(-4 * swing))
                } keyframes: { _ in
                    KeyframeTrack {
                        MoveKeyframe(0.0)
                        LinearKeyframe(8.0, duration: 0.72)
                    }
                }
                .frame(width: bossFrame, height: bossFrame)
                .background {
                    // Mekka cervena zare bez ostre hrany.
                    RadialGradient(
                        stops: [
                            .init(color: FQColor.danger.opacity(0.5), location: 0),
                            .init(color: FQColor.danger.opacity(0.22), location: 0.5),
                            .init(color: FQColor.danger.opacity(0.06), location: 0.8),
                            .init(color: FQColor.danger.opacity(0), location: 1),
                        ],
                        center: .center, startRadius: 0, endRadius: 84
                    )
                    .opacity(angry ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: angry)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PokeButtonStyle())
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { bossFrameTop = $0 }
        .overlay(alignment: .top) {
            // Neviditelna kotva tesne nad hlavou bosse; bublina na ni sedi spodni hranou,
            // takze roste nahoru a sprite nikdy neprekryje (ani nastvana, ani dlouha hlaska).
            Color.clear
                .frame(width: bossFrame, height: bubbleAnchor)
                .overlay(alignment: .bottom) {
                    if let poke {
                        PixelSpeechBubble(text: poke.text, angry: poke.angry, maxHeight: bubbleRoom)
                            .id(poke.id)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Poke \(node.name)")
    }

    private func pokeBoss(_ node: Boss) {
        let now = Date()
        pokeCount = now.timeIntervalSince(lastPoke) < 1.5 ? pokeCount + 1 : 1
        lastPoke = now
        let angry = pokeCount >= 4
        let pool = (angry ? Self.angryLines : Self.talkLines)
            .map { $0.replacingOccurrences(of: "{m}", with: "\(node.maxHP)") }
        // Nikdy dvakrat stejna hlaska po sobe.
        var text = pool.randomElement() ?? ""
        while pool.count > 1, text == poke?.text { text = pool.randomElement() ?? "" }
        pokeSerial += 1
        withAnimation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.55)) {
            poke = Poke(id: pokeSerial, text: text, angry: angry)
        }
        if !reduceMotion {
            if angry { shakes += 1 } else { bobs += 1 }
        }
        FQFeedback.shared.play(angry ? .hit : .tap)
        AccessibilityNotification.Announcement(text).post()
    }

    private static let talkLines = [
        "Oh, you again? Your notes miss you.",
        "I've napped through {m} minutes before. Try me.",
        "Bet you'll check your phone in 3 minutes.",
        "Studying later? That's my favourite word.",
        "I feed on open tabs. Keep them coming.",
        "Psst. Just one more video. Trust me.",
        "You won't last {m} minutes. Nobody does.",
        "Phone down? Ha. Prove it.",
    ]

    private static let angryLines = [
        "STOP. POKING. ME.",
        "Poke me once more and I'm adding 5 minutes.",
        "You poke like you study. Badly.",
        "Enough! Fight me if you dare.",
    ]

    /// "25 min" nebo "1 h 30 min".
    static func durationText(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(rest) min"
    }
}

/// Sprite se pri stisku malinko zmackne (0,94), jako v prototypu.
private struct PokeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Vzhled svetu

extension Boss {
    /// Barva bosse na obrazovce bitvy: barva jeho sveta, rozcvicka ma vlastni svitici modrou.
    var accent: Color { isWarmUp ? Color(red: 0.55, green: 0.86, blue: 1.0) : world.accent }
    /// Krajina za bitvou: krajina sveta, rozcvicka pod hvezdami.
    var scene: BackdropScene { isWarmUp ? .starlitPeaks : world.scene }
}

extension BossWorld {
    var accent: Color {
        switch self {
        case .heroes: Color(red: 0.95, green: 0.35, blue: 0.38)
        case .villains: Color(red: 0.66, green: 0.47, blue: 0.95)
        case .dojo: Color(red: 0.38, green: 0.82, blue: 0.48)
        case .fairyTale: Color(red: 0.98, green: 0.78, blue: 0.36)
        case .farm: Color(red: 0.96, green: 0.58, blue: 0.70)
        case .history: Color(red: 0.45, green: 0.72, blue: 0.98)
        case .planets: Color(red: 0.98, green: 0.62, blue: 0.30)
        }
    }

    var scene: BackdropScene {
        switch self {
        case .heroes: .castleKeep
        case .villains: .dungeonRuins
        case .dojo: .lanternGrove
        case .fairyTale: .enchantedForest
        case .farm: .enchantedForest
        case .history: .castleKeep
        case .planets: .starlitPeaks
        }
    }
}

// MARK: - Sdilene stavebni bloky

/// Serie dni s ohnem; sedy plamen = dnes jeste zadna bitva.
struct StreakBadge: View {
    let days: Int
    /// Easter egg v Arene: plamen zari oranzove, dokud pilulka hori.
    var burning = false

    var body: some View {
        HStack(spacing: FQSpace.sm) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(days > 0 ? AnyShapeStyle(LinearGradient(colors: [Color.yellow, Color.orange, Color.red], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(FQColor.textSecondary))
                .shadow(color: Color(red: 1, green: 138 / 255, blue: 31 / 255).opacity(burning ? 1 : 0), radius: 6)
                .animation(.easeOut(duration: 0.4), value: burning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(days)").font(.fqTitle).monospacedDigit().foregroundStyle(FQColor.textPrimary)
                Text(days == 1 ? "day streak" : "days streak").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
