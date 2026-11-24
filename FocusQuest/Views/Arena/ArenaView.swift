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

    enum AfterBattle { case fightSheet, path, home }

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

    // 2D: oslava serie po prvni bitve dne.
    @AppStorage(StreakCelebration.storageKey) private var celebratedDay = ""
    /// Pred oslavou pilulka ukazuje puvodni cislo, aby bylo videt, jak naskoci.
    @State private var shownStreak: Int?
    @State private var celebrationRequest = 0
    @State private var flares = 0
    @State private var sparksStart: Date?
    @State private var isOnScreen = false
    /// B4: milniky serie (7, 30, 100), po kterych uz Home sdileni nabidl.
    @AppStorage(StreakMilestone.storageKey) private var offeredMilestones = ""
    /// B4: milnik, pro ktery je prave otevrena nabidka sdileni.
    @State private var milestoneShare: Int?
    /// C3: iOS Focus rezim s FocusQuest filtrem ("Suggest a battle").
    @State private var focusMode = FocusModeState.load()

    private struct Poke: Equatable {
        let id: Int
        let text: String
        let angry: Bool
    }

    /// Aktualni boss mapy (stejny, u ktereho na mape stoji hrdina) a jeho svet.
    /// Po finalnim bossovi sveta je to prvni boss nove odemceneho sveta.
    private var nextNode: Boss? { model.currentMapBoss }
    private var world: BossWorld { nextNode?.world ?? BossWorld.allCases[BossWorld.allCases.count - 1] }

    /// Spodni hrana pilulky serie a horni hrana ramecku bosse (globalne): kolik mista ma bublina nad bossem.
    @State private var pillBottom: CGFloat = 0
    @State private var bossFrameTop: CGFloat = 0

    /// L1/E4: Home se neroluje. Vyska obrazovky (bez listy zalozek) a zmerene bloky (hlavicka se serii,
    /// texty u bosse, tlacitka) urci velikost bosse a mezery, takze se vse vejde od iPhonu SE po Pro Max.
    @State private var availableHeight: CGFloat = 0
    @State private var topBlockHeight: CGFloat = 0
    @State private var bossTextHeight: CGFloat = 0
    @State private var actionHeight: CGFloat = 0
    @Environment(CoachMarkStore.self) private var coach: CoachMarkStore?

    private var layout: ArenaLayout {
        ArenaLayout(available: availableHeight, top: topBlockHeight, bossText: bossTextHeight, actions: actionHeight)
    }

    private var isCompact: Bool { layout.compact }
    /// Ramecek bosse (sprite je 128/168 ramecku); spodek bubliny je 2 body nad hlavou, spicka ocasku
    /// tak miri tesne nad bosse.
    private var bossFrame: CGFloat { layout.bossFrame }
    private var bubbleAnchor: CGFloat { (bossFrame - layout.spriteSize) / 2 - 2 }

    /// Vyska, kterou bublina smi zabrat: od hlavy bosse po pilulku serie.
    private var bubbleRoom: CGFloat? {
        guard pillBottom > 0, bossFrameTop > 0 else { return nil }
        return max(56, bossFrameTop + bubbleAnchor - pillBottom - FQSpace.sm)
    }

    var body: some View {
        ScreenScaffold(scene: .lanternGrove, fixed: true, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Pozdrav se jmenem z onboardingu.
                ScreenHeader(eyebrow: profileModel.greetingName.map { "Hi, \($0)" }, title: "Ready to focus?")
                streakPill
                    .coachMark(.streak)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { pillBottom = $0 }
                    .padding(.top, isCompact ? FQSpace.sm : FQSpace.lg)
                if focusMode.suggestsBattle, let node = nextNode, model.isBetweenBattles {
                    focusSuggestion(node)
                        .padding(.top, FQSpace.sm)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topBlockHeight = $0 }
            // Volne misto: 1 dil nad bossem, 2 dily pod nim. Boss tak sedi blizko stredu obrazovky
            // a mezi nim a tlacitkem Fight je vzduch.
            Spacer(minLength: layout.minGap)
            bossSection
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    bossTextHeight = max(0, height - (nextNode == nil ? 0 : bossFrame))
                }
            Spacer(minLength: layout.minGap)
            Spacer(minLength: layout.minGap)
            actionSection
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { availableHeight = $0 }
        .task(id: poke?.id) {
            guard let current = poke else { return }
            try? await Task.sleep(for: .seconds(current.angry ? 2.6 : 2.2))
            guard !Task.isCancelled, poke?.id == current.id else { return }
            withAnimation(.easeOut(duration: 0.2)) { poke = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: FocusModeState.didChange)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { focusMode = FocusModeState.load() }
        }
        .onAppear {
            focusMode = FocusModeState.load()
            isOnScreen = true
            requestStreakCelebration()
        }
        .onDisappear {
            isOnScreen = false
            shownStreak = nil
        }
        // Navrat z bitvy (nebo zavreni Fight sheetu po "Same again"): oslava serie, kdyz je na rade.
        .onChange(of: battle.isPresented) { _, open in if !open { requestStreakCelebration() } }
        .onChange(of: battle.showsFightSheet) { _, open in if !open { requestStreakCelebration() } }
        .task(id: celebrationRequest) {
            guard celebrationRequest > 0 else { return }
            // Az dojede zavirani bitvy nebo listu.
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            guard canCelebrateStreak else {
                shownStreak = nil
                return
            }
            celebrateStreak()
            // B4: po oslave milniku serie (7, 30, 100 dni) jednou nabidnout sdileni.
            guard let milestone = StreakMilestone.due(streak: profileModel.currentStreak, offered: offeredMilestones) else { return }
            try? await Task.sleep(for: .seconds(StreakCelebration.sparkSeconds + 0.4))
            guard !Task.isCancelled, isOnScreen, !battle.isPresented, !battle.showsFightSheet else { return }
            offeredMilestones = StreakMilestone.adding(milestone, to: offeredMilestones)
            milestoneShare = milestone
        }
        .sheet(isPresented: Binding(get: { milestoneShare != nil }, set: { if !$0 { milestoneShare = nil } })) {
            StatsShareSheet(
                snapshot: ShareSnapshot.make(stats: profileModel.stats, profile: profileModel.profile, frozenDayKeys: profileModel.frozenDayKeys),
                initialTemplate: .streak,
                headline: "\(milestoneShare ?? 0)-day streak!"
            ) { milestoneShare = nil }
            .presentationDragIndicator(.visible)
        }
        .task(id: sparksStart) {
            guard let started = sparksStart else { return }
            try? await Task.sleep(for: .seconds(StreakCelebration.sparkSeconds + 0.1))
            guard !Task.isCancelled, sparksStart == started else { return }
            sparksStart = nil
        }
        .task(id: fireStart) {
            // Ohen se po ~4,5 s vzdy uklidi, i kdyz se mezitim znovu zapalil a zase dohorel.
            guard let started = fireStart else { return }
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled, fireStart == started else { return }
            fireStart = nil
        }
    }

    // MARK: - Focus rezim (C3)

    /// Aktivni iOS Focus s FocusQuest filtrem: kompaktni nabidka bitvy pod serii.
    private func focusSuggestion(_ node: Boss) -> some View {
        Button {
            model.selectBoss(node)
            battle.openFightSheet()
        } label: {
            HStack(spacing: FQSpace.md) {
                Image(systemName: "moon.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(red: 0.62, green: 0.55, blue: 1.0))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Focus is on")
                        .fqFont(size: 15, weight: .semibold, design: .rounded)
                        .foregroundStyle(FQColor.textPrimary)
                    Text("Perfect time for a battle. Tap to start.")
                        .fqFont(size: 13, design: .rounded)
                        .foregroundStyle(FQColor.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FQColor.onCta)
                    .frame(width: 34, height: 34)
                    .background(FQColor.cta, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FQSpace.md)
            .padding(.vertical, FQSpace.sm)
            .fqCard()
        }
        .buttonStyle(.fqPress)
        .accessibilityLabel("Your Focus is on. Start a battle")
        .transition(.opacity)
    }

    // MARK: - Serie

    private var streakPill: some View {
        let days = shownStreak ?? profileModel.currentStreak
        let burning = fireStart != nil
        let frozen = StreakFreeze.recentlyFrozen(frozenDayKeys: profileModel.frozenDayKeys)
        return Button(action: tapStreak) {
            HStack(spacing: 8) {
                StreakBadge(days: days, burning: burning, flare: flares)
                // C2: Streak freeze v poslednim tydnu zachranil den: ledova vlocka u serie.
                if frozen {
                    Image(systemName: "snowflake")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.55, green: 0.82, blue: 1.0))
                        .accessibilityHidden(true)
                }
            }
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
                .overlay(alignment: .leading) {
                    // Jiskry z plaminku (stred plaminku je 14 + 11 bodu od leveho okraje pilulky).
                    if let sparksStart {
                        StreakSparks(start: sparksStart)
                            .frame(width: 200, height: 160)
                            .offset(x: 25 - 100)
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
        .accessibilityLabel((days == 1 ? "1 day streak" : "\(days) days streak") + (frozen ? ", a streak freeze kept it alive" : ""))
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

    // MARK: - 2D: oslava serie

    /// Home je videt a nic ho nezakryva (bitva, Fight sheet, tutorial) a dnes je oslava na rade.
    private var canCelebrateStreak: Bool {
        isOnScreen && !battle.isPresented && !battle.showsFightSheet && coach?.step == nil
            && profileModel.stats.isStreakCelebrationDue(lastCelebratedDay: celebratedDay)
    }

    /// Pripravi oslavu: pilulka hned ukaze vcerejsi cislo, oslava prijde po zavreni bitvy.
    private func requestStreakCelebration() {
        guard canCelebrateStreak else { return }
        shownStreak = max(0, profileModel.currentStreak - 1)
        celebrationRequest += 1
    }

    /// Plaminek se rozhori, cislo naskoci, jiskry, vibrace a zvuk odmeny (Reward sounds, Haptics).
    /// S Reduce Motion jen prolnuti cisla, bez zvetseni a jisker. Jednou za den.
    private func celebrateStreak() {
        let days = profileModel.currentStreak
        celebratedDay = PlayerStats.dayKey(Date())
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.4)) { shownStreak = nil }
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { shownStreak = nil }
            flares += 1
            bumps += 1
            sparksStart = Date()
        }
        FQFeedback.shared.haptic(.success)
        FQFeedback.shared.play(.levelUp)
        AccessibilityNotification.Announcement(days == 1 ? "Streak started: 1 day" : "Streak up: \(days) days").post()
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
                Label("Every world conquered", systemImage: "checkmark.seal.fill")
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
        VStack(spacing: layout.actionSpacing) {
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
                        .padding(.horizontal, FQSpace.md)
                        .frame(minHeight: 44)
                        // Krok 5 tutorialu zvyrazni primo odkaz, ne celou sirku radku.
                        .coachMark(.quick)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.fqPress)
                .disabled(!model.isBetweenBattles)
            } else {
                // Vsechny svety dobyte: krok 1 tutorialu ukazuje tohle tlacitko misto Fight.
                Button(action: openPath) { ctaLabel("Pick a world", symbol: "map.fill") }
                    .buttonStyle(.fqPress)
                    .coachMark(.fight)
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { actionHeight = $0 }
        // Fight a "Not feeling it?" cele nad listou zalozek s odstupem (E4).
        .padding(.bottom, layout.bottomPadding)
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
        .coachMark(.fight)
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
            PixelArtAvatarView(sprite: .boss(node.pixelSpriteConfig), size: layout.spriteSize)
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
                        center: .center, startRadius: 0, endRadius: bossFrame / 2
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
        // Klik a vibrace vzdy (i u nastvaneho bosse; driv ho nahradil zvuk zasahu, ktery patri
        // do Battle sounds, takze se zvuky bitvy vypnutymi bylo ticho). Nastvany boss navic zasah.
        FQFeedback.shared.tap()
        if angry { FQFeedback.shared.play(.hit) }
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

/// L1/E4: rozvrzeni Home bez rolovani. Z vysky obrazovky nad listou zalozek a zmerenych bloku (hlavicka
/// se serii, texty u bosse, tlacitka) spocita velikost bosse a mezery tak, aby Fight i "Not feeling it?"
/// byly cele nad listou s odstupem: od iPhonu SE (3. gen.) po Pro Max, i behem tutorialu, kdy nadpis
/// uhne pod "Skip tutorial". Bloky se meri, takze s vetsim pismem se zmensi boss, ne tlacitka.
struct ArenaLayout: Equatable {
    /// Bezpecna zona Home konci 8 bodu pod horni hranou listy zalozek (FQTabBarMetrics.contentGap).
    static let tabBarOverlap: CGFloat = max(0, -FQTabBarMetrics.contentGap)
    static let minBoss: CGFloat = 84
    static let maxBoss: CGFloat = 220
    /// Boss zabere nejvys 26 % vysky; zbytek jsou mezery (1 dil nad bossem, 2 dily pod nim).
    static let bossShare: CGFloat = 0.26
    /// Odhady bloku, nez se zmeri (bezna velikost pisma).
    static let topEstimate: CGFloat = 136
    static let bossTextEstimate: CGFloat = 81
    static let actionsEstimate: CGFloat = 108

    /// Nizka obrazovka (iPhone SE, velke pismo): mensi mezery.
    let compact: Bool
    /// Ramecek bosse; sprite je 128/168 ramecku.
    let bossFrame: CGFloat
    /// Nejmensi mezera nad bossem a pod nim.
    let minGap: CGFloat
    /// Mezera mezi Fight a "Not feeling it?".
    let actionSpacing: CGFloat
    /// Od spodku "Not feeling it?" ke spodku bezpecne zony (8 bodu pod listou + odstup od listy).
    let bottomPadding: CGFloat

    init(available: CGFloat, top: CGFloat, bossText: CGFloat, actions: CGFloat) {
        compact = available > 0 && available < 640
        minGap = compact ? FQSpace.xs : FQSpace.md
        actionSpacing = compact ? FQSpace.xs : FQSpace.md
        bottomPadding = Self.tabBarOverlap + (compact ? FQSpace.md : FQSpace.xl)
        guard available > 0 else {
            bossFrame = 168
            return
        }
        let fixed = Self.fixedHeight(top: top > 0 ? top : Self.topEstimate,
                                     bossText: bossText > 0 ? bossText : Self.bossTextEstimate,
                                     actions: actions > 0 ? actions : Self.actionsEstimate,
                                     minGap: minGap, bottomPadding: bottomPadding)
        let room = available - fixed
        bossFrame = min(Self.maxBoss, max(Self.minBoss, min(available * Self.bossShare, room))).rounded(.down)
    }

    var spriteSize: CGFloat { (bossFrame * 128 / 168).rounded() }

    /// Vyska vseho krome bosse a volnych mezer: horni okraj, bloky, tri nejmensi mezery, spodni odstup.
    static func fixedHeight(top: CGFloat, bossText: CGFloat, actions: CGFloat, minGap: CGFloat, bottomPadding: CGFloat) -> CGFloat {
        FQSpace.sm + top + bossText + actions + 3 * minGap + bottomPadding
    }

    /// Cely obsah Home s nejmensimi mezerami (test: musi se vejit do dostupne vysky).
    func minimumHeight(top: CGFloat, bossText: CGFloat, actions: CGFloat) -> CGFloat {
        Self.fixedHeight(top: top, bossText: bossText, actions: actions, minGap: minGap, bottomPadding: bottomPadding) + bossFrame
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
        case .farm: Color(red: 0.96, green: 0.58, blue: 0.70)
        case .forest: Color(red: 0.55, green: 0.85, blue: 0.40)
        case .reef: Color(red: 0.38, green: 0.62, blue: 1.00)
        case .dojo: Color(red: 0.38, green: 0.82, blue: 0.48)
        case .highSchool: Color(red: 0.98, green: 0.78, blue: 0.36)
        case .history: Color(red: 0.45, green: 0.72, blue: 0.98)
        case .planets: Color(red: 0.98, green: 0.62, blue: 0.30)
        }
    }

    var scene: BackdropScene {
        switch self {
        case .farm: .enchantedForest
        case .forest: .enchantedForest
        case .reef: .dungeonRuins
        case .dojo: .lanternGrove
        case .highSchool: .castleKeep
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
    /// 2D: kazda zmena = plaminek se rozhori (oslava prvni bitvy dne).
    var flare = 0
    @State private var flaring = false

    var body: some View {
        HStack(spacing: FQSpace.sm) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(days > 0 ? AnyShapeStyle(LinearGradient(colors: [Color.yellow, Color.orange, Color.red], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(FQColor.textSecondary))
                .shadow(color: Color(red: 1, green: 138 / 255, blue: 31 / 255).opacity(burning || flaring ? 1 : 0), radius: flaring ? 10 : 6)
                .animation(.easeOut(duration: 0.4), value: burning)
                .animation(.easeOut(duration: 0.35), value: flaring)
                .keyframeAnimator(initialValue: 1.0, trigger: flare) { content, scale in
                    content.scaleEffect(scale, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        MoveKeyframe(1.0)
                        CubicKeyframe(1.65, duration: 0.22)
                        SpringKeyframe(1.0, duration: 0.6, spring: .bouncy)
                    }
                }
                .task(id: flare) {
                    guard flare > 0 else { return }
                    flaring = true
                    try? await Task.sleep(for: .seconds(1.2))
                    guard !Task.isCancelled else { return }
                    flaring = false
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(days)").font(.fqTitle).monospacedDigit().foregroundStyle(FQColor.textPrimary)
                    .contentTransition(.numericText(value: Double(days)))
                Text(days == 1 ? "day streak" : "days streak").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
