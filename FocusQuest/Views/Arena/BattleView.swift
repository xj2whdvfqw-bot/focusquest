import SwiftUI

/// Bitva pres celou obrazovku (bez spodni listy): jedna plovouci karta uprostred
/// s bossem, jmenem, obrim odpoctem a kulatymi tlacitky. Nic dalsiho behem bitvy nerusi.
struct BattleView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    /// Zavola se po zavreni vysledku bitvy nebo krizkem pred bitvou (zavre celou obrazovku).
    let onExit: () -> Void
    /// Zavre obrazovku a pak otevre Fight sheet nebo zalozku Path (z prestavky).
    var onExitTo: (BattlePresenter.AfterBattle) -> Void = { _ in }
    @State private var showsRetreatConfirm = false
    /// Po "Collect Loot" se misto vitezstvi ukaze spodni panel prestavky.
    @State private var showsBreak = false
    /// 0 -> 1 behem 0,9 s: XP a mince na obrazovce vitezstvi se nacitaji.
    @State private var rewardProgress = 0.0
    /// Po konci bitvy chvili hraje zaverecna scena (financi uder / utek bosse), az pak prijde okno vysledku.
    @State private var playsFinale = false
    /// Hrac odchazi z vysledku (zpet, Path, Fight sheet): karta bitvy se uz neukaze ani na chvili
    /// (driv pri zavirani na ~1 s problikla s tlacitkem "Begin Battle").
    @State private var isLeaving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Rozmery ladene v Battle Card Lab (webovy prototyp). Pill je tu vlastni, aby se nezmenily ostatni obrazovky.
    private enum Layout {
        static let screenGutter: CGFloat = 15
        static let stackGap: CGFloat = 12
        static let topIcon: CGFloat = 56
        static let cardPadX: CGFloat = 15
        static let cardPadTop: CGFloat = 26
        static let cardPadBottom: CGFloat = 46
        static let cardSpacing: CGFloat = 29
        static let cardBorder: Double = 0.10
        /// Scena hrdina vs. boss (BattleStage).
        static let stageHeight: CGFloat = 150
        static let spriteSize: CGFloat = 120
        static let bossGap: CGFloat = 8
        static let timerSize: CGFloat = 114
        static let timerSizeLong: CGFloat = 89
        static let timerGap: CGFloat = 3
        static let actionSize: CGFloat = 69
        static let actionGap: CGFloat = 50
    }

    /// Tlacitka na obrazovce ustupu (bez karty).
    private var pill: RoundedRectangle { RoundedRectangle(cornerRadius: FQRadius.battleButton, style: .continuous) }
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: FQRadius.battleCard, style: .continuous) }
    private var boss: Boss { model.selectedBoss }
    private var world: BossWorld { boss.world }
    private var isWarning: Bool { if case .warningCountdown = model.state { true } else { false } }
    private var isPaused: Bool {
        switch model.state {
        case .paused, .callPaused: true
        default: false
        }
    }
    private var isIdle: Bool { if case .idle = model.state { true } else { false } }
    private var isVictory: Bool { if case .victory = model.state { true } else { false } }
    private var isDefeat: Bool { if case .defeated = model.state { true } else { false } }
    /// Vysledek bitvy (vyhra, utek bosse, chyba): karta bitvy pod oknem uz neni videt.
    private var showsResult: Bool {
        switch model.state {
        case .victory, .defeated: !playsFinale
        case .penalized: true
        default: false
        }
    }
    private var showsVictoryResult: Bool { isVictory && !playsFinale }

    /// Bezela bitva (hrdina byl na scene videt)?
    private static func wasFighting(_ state: ArenaState) -> Bool {
        switch state {
        case .focusing, .paused, .warningCountdown, .callPaused: true
        default: false
        }
    }
    private var elapsed: Int {
        switch model.state {
        case .focusing(let value): value
        case .paused(let value, _): value
        case .warningCountdown(_, let value): value
        case .callPaused(let value, _): value
        default: 0
        }
    }
    /// Odpocet do konce bitvy; pred bitvou ukazuje celou delku.
    private var remaining: Int { max(0, model.targetSeconds - elapsed) }
    /// "24:59", nad hodinu "1:29:59" - obri cislice se tak vejdou na sirku telefonu.
    private var clockText: String {
        let hours = remaining / 3600, minutes = (remaining / 60) % 60, seconds = remaining % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
    }
    private var durationText: String { ArenaView.durationText(minutes: boss.maxHP) }
    private var battleTitle: String { model.isCustomBattle ? "Quick battle" : "Boss \(boss.nodeIndex + 1) of \(world.bosses.count) · \(world.title)" }

    var body: some View {
        ZStack {
            FocusQuestBackdrop(alert: false, scene: boss.scene)
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: Layout.stackGap) {
                        topBar
                        battleCard
                        #if targetEnvironment(simulator)
                        simulatorControls
                        #endif
                    }
                    .padding(.horizontal, Layout.screenGutter)
                    .padding(.vertical, FQSpace.lg)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
                // Pod vysledkovym oknem karta bitvy neni (driv pod nim prosvitalo "Begin Battle").
                .opacity(showsResult || isLeaving ? 0 : 1)
            }
            // Bitva roluje pod stavovy radek stejne jako zalozky.
            StatusBarFade()
            if showsRetreatConfirm { retreatDialog.transition(.opacity) }
            if case let .warningCountdown(seconds, _) = model.state {
                PhoneLiftedAlarm(seconds: seconds, bossName: boss.name) {
                    model.retreat()
                }
            }
            if case .callPaused(_, true) = model.state, !showsRetreatConfirm { callEndedOverlay.transition(.opacity) }
            if case let .penalized(reason) = model.state {
                resultOverlay(icon: "exclamationmark.triangle.fill", title: "Battle stopped", detail: "\(reason) Nothing was taken from you.")
            }
            if case let .defeated(defeat) = model.state, !playsFinale { defeatOverlay(defeat) }
            if case let .victory(victory) = model.state, !playsFinale {
                // B3: prestavka je sheet se dvema vyskami (viz breakSheet); pod nim zustane jen ztmaveni.
                if showsBreak {
                    Color.black.opacity(ResultDialog<EmptyView>.dim).ignoresSafeArea().accessibilityHidden(true)
                } else {
                    victoryOverlay(victory)
                }
            }
            #if DEBUG
            // Jen Debug build: male tlacitko vlevo dole, bitva hned skonci vyhrou vcetne odmen.
            if model.isBattleRunning, !isWarning, !showsRetreatConfirm { debugWinNowButton }
            #endif
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.25), value: showsResult)
        // Zvuky a haptika pres FQFeedback: vyhra = fanfara a uspech, utek bosse = sestup a varovani.
        // Fanfara az s oknem vyhry (po financim uderu na scene).
        .fqHaptic(.success, trigger: showsVictoryResult) { _, now in now }
        .fqSound(.victory, trigger: showsVictoryResult) { _, now in now }
        .fqHaptic(.warning, trigger: isDefeat) { _, now in now }
        .fqSound(.escape, trigger: isDefeat) { _, now in now }
        // Novy level po vyhre.
        .fqSound(.levelUp, trigger: profileModel.level) { old, new in new > old }
        .animation(FQMotion.spring(reduceMotion: reduceMotion), value: showsBreak)
        // B3: panel prestavky jako sheet se dvema vyskami. Stahnout dolu ho nejde, zavre se jen tlacitky.
        .sheet(isPresented: Binding(get: { showsBreakSheet }, set: { _ in })) {
            if case let .victory(victory) = model.state {
                breakPanel(victory)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsRetreatConfirm)
        .onChange(of: model.state) { old, value in
            // Ustupovy dialog nema smysl, kdyz bitva mezitim skoncila.
            if !model.isBattleRunning { showsRetreatConfirm = false }
            // Nova bitva (napr. "Next boss" z prestavky) zase ukaze kartu.
            if case .awaitingFlatPlacement = value { isLeaving = false }
            let ended: Bool = switch value {
            case .victory, .defeated: true
            default: false
            }
            // Konec bitvy na obrazovce: nejdriv zaverecna scena, pak okno vysledku.
            // S Reduce Motion nebo kdyz se bitva dohrala na pozadi, prijde vysledek hned.
            if ended, Self.wasFighting(old), !reduceMotion, scenePhase == .active {
                playsFinale = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(BattleStage.finaleSeconds))
                    finishFinale()
                }
            } else if !ended {
                playsFinale = false
            }
            // Odmenu uz pripsal model; obrazovka jen napocita XP a mince.
            if case .victory = value {
                if !playsFinale { countUpRewards() }
            } else {
                showsBreak = false
                rewardProgress = 0
            }
        }
    }

    private func finishFinale() {
        guard playsFinale else { return }
        playsFinale = false
        if isVictory { countUpRewards() }
    }

    /// XP a mince se nacitaji od nuly 0,9 s se zpomalenim (s Reduce Motion hned cele).
    /// Az se dopocitaji (po vitezne fanfare), zazni zvuk XP (Reward sounds).
    private func countUpRewards() {
        rewardProgress = 0
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_100))
            if isVictory { FQFeedback.shared.play(.xp) }
        }
        if reduceMotion { rewardProgress = 1; return }
        withAnimation(.easeOut(duration: 0.9).delay(0.2)) { rewardProgress = 1 }
    }

    private func closeResult() {
        isLeaving = true
        model.stopSession()
        onExit()
    }

    /// Odchod z vysledku na jine misto (Fight sheet, Path, Home): karta bitvy zustane skryta.
    private func leave(to destination: BattlePresenter.AfterBattle, prepare: () -> Void = {}) {
        // B3: z prestavky (sheet) nejdriv zavrit sheet, az pak celou obrazovku bitvy (dve prezentace naraz se zasekaly).
        let fromBreakSheet = showsBreakSheet
        isLeaving = true
        model.stopSession()
        prepare()
        if fromBreakSheet {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(380))
                onExitTo(destination)
            }
        } else {
            onExitTo(destination)
        }
    }

    #if DEBUG
    /// Debug: male tlacitko v levem dolnim rohu obrazovky (mimo kartu bitvy).
    private var debugWinNowButton: some View {
        Button { model.debugWinNow() } label: {
            Label("Win now", systemImage: "bolt.fill")
                .font(.fqMeta.weight(.semibold))
                .foregroundStyle(FQColor.accent)
                .padding(.horizontal, FQSpace.md)
                .frame(minHeight: 32)
                .background(Color.black.opacity(0.55), in: Capsule())
                .overlay { Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1) }
        }
        .buttonStyle(.fqPress)
        .padding(.leading, FQSpace.md)
        .padding(.bottom, FQSpace.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityHint("Debug build only")
    }
    #endif

    /// Krizek pred bitvou: vlastni bitva se zrusi a obrazovka se zavre.
    private func closeBeforeBattle() {
        model.endCustomBattle()
        onExit()
    }

    // MARK: - Horni lista

    /// Jen krizek pred bitvou a nazev; behem bitvy zadna tlacitka nahore.
    private var topBar: some View {
        HStack(spacing: FQSpace.md) {
            if isIdle {
                Button(action: closeBeforeBattle) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(FQColor.textPrimary)
                        .frame(width: Layout.topIcon, height: Layout.topIcon)
                        .glassControl(in: Circle(), interactive: true)
                }
                .buttonStyle(.fqPress)
                .accessibilityLabel("Close")
            } else {
                Color.clear.frame(width: Layout.topIcon, height: Layout.topIcon)
            }
            Spacer(minLength: 0)
            Text(battleTitle)
                .font(.fqLabel)
                .foregroundStyle(FQColor.textSecondary)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
            Spacer(minLength: 0)
            Color.clear.frame(width: Layout.topIcon, height: Layout.topIcon)
        }
    }

    // MARK: - Hlavni karta

    private var battleCard: some View {
        VStack(spacing: Layout.cardSpacing) {
            bossHeader
            VStack(spacing: Layout.timerGap) {
                timer
                statusLine
            }
            controls
        }
        .padding(.horizontal, Layout.cardPadX)
        .padding(.top, Layout.cardPadTop)
        .padding(.bottom, Layout.cardPadBottom)
        .frame(maxWidth: .infinity)
        .fqContainer(radius: FQRadius.battleCard)
        .background(.ultraThinMaterial, in: cardShape)
        .background(boss.accent.opacity(0.06), in: cardShape)
        .overlay { cardShape.strokeBorder(Color.white.opacity(Layout.cardBorder), lineWidth: 1) }
        .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
    }

    private var bossHeader: some View {
        VStack(spacing: Layout.bossGap) {
            // Hrdina z profilu (vcetne vybaveni z obchodu) proti bossovi; viz BattleStage.
            BattleStage(
                boss: stageBoss,
                appearance: profileModel.profile.avatar,
                heroClass: profileModel.profile.heroClass,
                phase: stagePhase,
                elapsed: elapsed,
                targetSeconds: stageBoss.maxHP * 60,
                bossSize: Layout.spriteSize
            )
            .frame(height: Layout.stageHeight)
            // Kazda bitva ma cerstvou scenu: zadne K.O. ani lezici boss z minule bitvy.
            .id(model.battleSerial)
            .accessibilityHidden(true)
            VStack(spacing: 2) {
                Text(stageBoss.name)
                    .font(.fqHeadline)
                    .foregroundStyle(FQColor.textPrimary)
                    .lineLimit(1)
                Text("\(stageBoss.tierTitle) · \(ArenaView.durationText(minutes: stageBoss.maxHP))")
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
            }
            // B1: pixelova srdicka po ctvrtkach misto HP cary.
            BossHeartsView(hearts: stageHearts.hearts, quartersLeft: bossQuartersLeft)
                .padding(.top, FQSpace.xs)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stageBoss.name), \(stageBoss.tierTitle), \(ArenaView.durationText(minutes: stageBoss.maxHP)), \(BossHeartsView.spoken(quartersLeft: bossQuartersLeft, hearts: stageHearts.hearts))")
    }

    private var stageHearts: BossHearts { BossHearts(tier: stageBoss.tier, targetSeconds: stageBoss.maxHP * 60) }

    /// B1: behem bitvy ubyvaji ctvrtky po pravidelnych uderech; po vyhre nic, po uteku kolik zbylo.
    private var bossQuartersLeft: Int {
        let hearts = stageHearts
        switch model.state {
        case .focusing, .paused, .warningCountdown, .callPaused:
            return hearts.quartersLeft(atElapsed: elapsed)
        case .victory:
            return 0
        case let .defeated(defeat):
            return hearts.quartersLeft(atElapsed: defeat.focusedMinutes * 60)
        default:
            return hearts.totalQuarters
        }
    }

    /// Boss na scene: po vyhre ten porazeny (model uz mohl vybrat dalsiho), po uteku ten, co utekl.
    private var stageBoss: Boss {
        switch model.state {
        case let .victory(victory): model.lastBeaten ?? victory.boss
        case let .defeated(defeat): defeat.boss
        default: boss
        }
    }

    private var stagePhase: BattleStage.Phase {
        switch model.state {
        case .focusing, .warningCountdown: .fighting
        case .paused, .callPaused: .paused
        case .victory: .won
        case .defeated: .escaped
        default: .waiting
        }
    }

    /// Obri odpocet: hlavni informace obrazovky.
    private var timer: some View {
        Text(clockText)
            .font(.system(size: remaining >= 3600 ? Layout.timerSizeLong : Layout.timerSize, weight: .light, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(isPaused ? FQColor.textSecondary : FQColor.textPrimary)
            .contentTransition(.numericText())
            .animation(.default, value: elapsed)
            .accessibilityLabel(isPaused ? "Paused, \(clockText) left" : "Time left \(clockText)")
    }

    /// Jeden tichy radek pod odpoctem: co se prave deje.
    @ViewBuilder private var statusLine: some View {
        switch model.state {
        case let .paused(_, secondsLeft):
            CenteredIconText("Paused · back in \(Self.minutesSeconds(secondsLeft)) or the boss escapes", systemImage: "pause.fill")
                .font(.fqLabel)
                .monospacedDigit()
                .foregroundStyle(FQColor.caution)
                .multilineTextAlignment(.center)
        case .callPaused:
            CenteredIconText("Paused for a call · no time limit", systemImage: "phone.fill")
                .font(.fqLabel)
                .foregroundStyle(FQColor.caution)
                .multilineTextAlignment(.center)
        case .focusing, .warningCountdown:
            HStack(spacing: FQSpace.sm) {
                PixelArtAvatarView(sprite: .companion("lo-fi-cat"), size: 24)
                Text("Phone down. The boss is losing.").font(.fqLabel).foregroundStyle(FQColor.textSecondary)
            }
        case .awaitingFlatPlacement:
            PlacementHint { model.startWithoutSensor() }
        default:
            EmptyView()
        }
    }

    static func minutesSeconds(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    // MARK: - Ovladani

    @ViewBuilder private var controls: some View {
        switch model.state {
        case .idle, .penalized, .victory, .defeated:
            // Mimo bitvu (K.O. scena, utek bosse, zavirani) zadne tlacitko: bitva se spousti jen pres
            // Fight sheet. Neviditelne misto drzi vysku karty, aby scena neposkocila.
            BattleActionButton(symbol: "pause.fill", caption: " ", tone: .neutral) { }
                .hidden()
                .accessibilityHidden(true)
        case .awaitingFlatPlacement:
            // Hodiny jeste nebezi, takze zruseni nic nestoji: bitva se zrusi a obrazovka zavre.
            BattleActionButton(symbol: "xmark", caption: "Cancel", tone: .neutral) {
                model.retreat()
                onExit()
            }
        case .callPaused:
            // Hovor pauzu nespotrebuje; jedine, co jde udelat, je ustoupit.
            BattleActionButton(symbol: "flag.fill", caption: "Retreat", tone: .danger) { showsRetreatConfirm = true }
        case .focusing, .paused, .warningCountdown:
            // Pause a Retreat vycentrovane v karte, pod nimi stav pauz (B2).
            VStack(spacing: FQSpace.md) {
                HStack(spacing: Layout.actionGap) {
                    if isPaused {
                        BattleActionButton(symbol: "play.fill", caption: "Resume", tone: .accent) { model.resumeBattle() }
                    } else {
                        // Po vycerpani zustane tlacitko videt, ale neaktivni.
                        BattleActionButton(symbol: "pause.fill", caption: pauseCaption, tone: .neutral) { model.pauseBattle() }
                            .disabled(model.hasUsedPause)
                            .opacity(model.hasUsedPause ? 0.45 : 1)
                            .accessibilityHint(pauseHint)
                    }
                    BattleActionButton(symbol: "flag.fill", caption: "Retreat", tone: .danger) { showsRetreatConfirm = true }
                }
                pauseSummary
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Pauzy (B2)

    /// Extra pauzy v inventari (zive z profilu, odecitaji se pri pouziti).
    private var ownedExtraPauses: Int { profileModel.profile.extraPauses }

    /// Popisek tlacitka: dalsi pauza je zdarma, extra (z Shopu), nebo zadna.
    private var pauseCaption: String {
        if model.freePausesLeft > 0 { return "Pause" }
        if model.canUseExtraPause { return "Extra pause" }
        return "No pauses"
    }

    private var pauseHint: String {
        if model.freePausesLeft > 0 { return "Uses your free pause. Up to 2 minutes." }
        if model.canUseExtraPause { return "Uses 1 extra pause from the Shop. Up to 2 minutes." }
        return model.extraPausesUsed > 0 ? "You already used 1 extra pause in this battle" : "No pauses left in this battle"
    }

    /// "Pause: 1 free + 2 extra"; extra = pauzy z Shopu (v jedne bitve jde pouzit nejvys jedna).
    private var pauseSummary: some View {
        let free = model.freePausesLeft
        let extra = ownedExtraPauses
        let freeText = free > 0 ? "\(free) free" : "free used"
        let extraText = model.extraPausesUsed >= ArenaViewModel.maxExtraPausesPerBattle
            ? "extra used"
            : "\(extra) extra"
        return Text("Pause: \(freeText) + \(extraText)")
            .font(.fqMeta)
            .monospacedDigit()
            .foregroundStyle(FQColor.textSecondary)
            .accessibilityLabel(free > 0
                ? "1 free pause\(extra > 0 ? ", plus \(extra) extra from the Shop, 1 usable per battle" : "")"
                : (model.canUseExtraPause ? "Free pause used. 1 extra pause usable, \(extra) owned" : "No pauses left in this battle"))
    }

    // MARK: - Ustup

    /// Varovani pred ustupem pres celou obrazovku: rozmazane pozadi, vyrazne "Stay and Fight"
    /// a nenapadne "Retreat Anyway" pod nim.
    private var retreatDialog: some View {
        let focused = ArenaView.durationText(minutes: elapsed / 60)
        return ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()
            VStack(spacing: FQSpace.xxl) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [FQColor.danger.opacity(0.35), Color.clear], center: .center, startRadius: 0, endRadius: 90))
                        .frame(width: 180, height: 180)
                    PixelArtAvatarView(sprite: .boss(boss.pixelSpriteConfig), hitFlash: false, size: 112)
                        .bossBreathing()
                }
                .frame(height: 140)
                .accessibilityHidden(true)
                VStack(spacing: FQSpace.md) {
                    Text("Don't let \(boss.name) win")
                        .fqFont(size: 30, weight: .bold, design: .rounded)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textPrimary)
                    Text(elapsed >= 60
                         ? "You've already focused for \(focused). Only \(clockText) to go. Stay and the loot is yours."
                         : "The battle has only just begun.")
                        .font(.fqBody)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textSecondary)
                }
                CenteredIconText("The boss escapes: no XP and no coins for this battle", systemImage: "xmark")
                    .font(.fqLabel)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(FQColor.danger)
                VStack(spacing: FQSpace.md) {
                    Button { showsRetreatConfirm = false } label: {
                        Text("Stay and Fight")
                            .font(.fqHeadline)
                            .foregroundStyle(FQColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 58)
                            .background(FQColor.accent, in: pill)
                    }
                    .buttonStyle(.fqPress)
                    Button {
                        showsRetreatConfirm = false
                        model.retreat()
                    } label: {
                        Text("Retreat Anyway")
                            .font(.fqLabel)
                            .foregroundStyle(FQColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.fqPress)
                }
            }
            .padding(.horizontal, FQSpace.xxl)
            .frame(maxWidth: 440)
        }
        .accessibilityAddTraits(.isModal)
    }

    #if targetEnvironment(simulator)
    private var simulatorControls: some View {
        HStack(spacing: FQSpace.sm) {
            Button("Simulate Down") { Task { await model.setSimulatedPosture(.lyingStill) } }
            Button("Simulate Lift") { Task { await model.setSimulatedPosture(.lifted) } }
        }
        .font(.fqMeta)
        .buttonStyle(.bordered)
        .tint(FQColor.textSecondary)
        .frame(maxWidth: .infinity)
    }
    #endif

    // MARK: - Prekryvy

    /// Vitezstvi ve stejnem sklenenem okne jako ostatni vysledky (ResultDialog): sprite se zari v barve sveta,
    /// "Victory!", sklenene dlazdice +XP/+Coins (cisla se napocitaji), zlute "Collect Loot".
    /// Po rozcvicce navic "Keep going" na nejkratsiho neporazeneho bosse.
    private func victoryOverlay(_ victory: BattleVictory) -> some View {
        // Boss ulozeny pred posunem cesty; obrazovka nikdy neukaze az toho dalsiho.
        let beaten = model.lastBeaten ?? victory.boss
        let keepGoing = victory.isQuickBattle ? model.keepGoingBoss(pathWins: profileModel.stats.pathWins) : nil
        return ResultDialog {
            VStack(spacing: FQSpace.lg) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [beaten.accent.opacity(0.45), Color.clear], center: .center, startRadius: 0, endRadius: 90))
                        .frame(width: 180, height: 150)
                    PixelArtAvatarView(sprite: .boss(beaten.pixelSpriteConfig), size: 112)
                        .bossBreathing()
                }
                .frame(width: 180, height: 150)
                .accessibilityHidden(true)
                VStack(spacing: FQSpace.xs) {
                    Text("Victory!")
                        .fqFont(size: 34, weight: .bold, design: .rounded)
                        .foregroundStyle(FQColor.textPrimary)
                    Text("\(beaten.name) defeated · \(victory.subject.title), \(ArenaView.durationText(minutes: victory.verifiedMinutes))")
                        .font(.fqSecondary)
                        .foregroundStyle(FQColor.textSecondary)
                    // Jen kdyz vyhra posunula cestu (porazeny boss byl na rade).
                    if let next = victory.nextUp {
                        Text("Next up: \(next.name) · \(ArenaView.durationText(minutes: next.maxHP))")
                            .font(.fqLabel)
                            .foregroundStyle(beaten.accent)
                            .padding(.top, FQSpace.xs)
                    }
                }
                .multilineTextAlignment(.center)
                HStack(spacing: FQSpace.sm) {
                    rewardTile(amount: victory.xpEarned, label: "XP", symbol: "sparkles")
                    rewardTile(amount: victory.coinsEarned, label: "Coins", symbol: "dollarsign.circle.fill")
                }
                VStack(spacing: FQSpace.sm) {
                    Button { showsBreak = true } label: {
                        Text("Collect Loot")
                            .font(.fqHeadline)
                            .foregroundStyle(FQColor.onCta)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                            // Rohy soustredne s oknem vysledku.
                            .background(FQColor.cta, in: FQRadius.shape(FQRadius.inDialog))
                            .contentShape(FQRadius.shape(FQRadius.inDialog))
                    }
                    .buttonStyle(.fqPress)
                    .fqHaptic(.medium, trigger: showsBreak) { _, now in now }
                    .fqSound(.coin, trigger: showsBreak) { _, now in now }
                    if let keepGoing {
                        Button { openKeepGoing(keepGoing) } label: {
                            Label("Keep going · \(keepGoing.name) · \(ArenaView.durationText(minutes: keepGoing.maxHP))", systemImage: "play.fill")
                                .font(.fqLabel)
                                .foregroundStyle(FQColor.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, FQSpace.md)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .fqInnerTile(in: FQRadius.shape(FQRadius.inDialog))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.fqPress)
                        .accessibilityLabel("Keep going: fight \(keepGoing.name), \(keepGoing.maxHP) minutes")
                    }
                }
            }
        }
    }

    /// "Keep going" po rozcvicce: zavre vysledek a otevre Fight sheet nejkratsiho neporazeneho bosse.
    private func openKeepGoing(_ next: Boss) {
        leave(to: .fightSheet) { model.selectBoss(next) }
    }

    /// Sklenena dlazdice odmeny: pruhledne sklo (bila 8 % + rozmazani) s jemnym okrajem, cislo se napocita.
    private func rewardTile(amount: Int, label: String, symbol: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous)
        return VStack(spacing: FQSpace.xs) {
            Image(systemName: symbol).font(.fqLabel).foregroundStyle(symbol.hasPrefix("dollarsign") ? FQColor.coin : FQColor.accent).accessibilityHidden(true)
            CountUpNumber(value: Double(amount) * rewardProgress)
                .font(.fqTitle)
                .monospacedDigit()
                .foregroundStyle(FQColor.textPrimary)
            Text(label).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FQSpace.md)
        .fqInnerTile(in: shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("+\(amount) \(label)")
    }

    // MARK: - Prestavka

    /// Sheet prestavky je videt po "Collect Loot", dokud je vyhra na obrazovce a hrac neodchazi.
    private var showsBreakSheet: Bool { showsBreak && isVictory && !playsFinale && !isLeaving }

    /// Spodni panel prestavky po "Collect Loot". Odmena uz je pripsana, tady se jen vybira, co dal.
    private func breakPanel(_ victory: BattleVictory) -> some View {
        let beaten = model.lastBeaten ?? Boss.find(victory.boss.id) ?? victory.boss
        return BreakPanel(
            nextBoss: model.upcomingPathBoss,
            sameAgain: beaten,
            hero: profileModel.profile.avatar,
            heroClass: profileModel.profile.heroClass,
            accent: beaten.accent,
            onNextBoss: { boss in
                model.startNextBoss(boss)
            },
            onSameAgain: {
                leave(to: .fightSheet) { model.selectBoss(beaten) }
            },
            onChangeBoss: {
                leave(to: .path)
            },
            // "Done for today" vede domu (Arena), ne na Path.
            onDone: { leave(to: .home) },
            onBreakOver: { model.announceBreakOver() }
        )
        // Notifikace "Break is over" prijde i se zamcenou obrazovkou; po odchodu z prestavky se zrusi.
        .onAppear { model.breakStarted(seconds: BreakPanel.breakSeconds) }
        .onDisappear { model.breakEnded() }
    }

    /// Obrazovka prohry: boss utekl. Jediny trest je, ze bitva nic neprinese;
    /// serie a mince zustavaji. Boss je videt naplno (nikdy nebledne) a dycha.
    private func defeatOverlay(_ defeat: BattleDefeat) -> some View {
        ResultDialog {
            VStack(spacing: FQSpace.lg) {
                PixelArtAvatarView(sprite: .boss(defeat.boss.pixelSpriteConfig), size: 96)
                    .bossBreathing()
                    .frame(height: 112)
                    .accessibilityHidden(true)
                VStack(spacing: FQSpace.sm) {
                    Text("\(defeat.boss.name) escaped")
                        .font(.fqTitle)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textPrimary)
                    Text(defeat.reason.text)
                        .font(.fqHeadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.danger)
                    Text("No loot this time, your streak and coins are safe.")
                        .font(.fqSecondary)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
                Button(action: closeResult) {
                    Text("Back")
                        .font(.fqHeadline)
                        .foregroundStyle(FQColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FQSpace.xs)
                }
                .prominentGlassButtonStyle()
                .buttonBorderShape(.roundedRectangle(radius: FQRadius.inDialog))
                .controlSize(.large)
                .tint(FQColor.accent)
            }
        }
    }

    /// Technicka chyba (server, hodiny): nic se nebere, jen tlacitko "Back".
    /// Po hovoru: bitva stoji, dokud hrac nepolozi telefon zase displejem dolu.
    private var callEndedOverlay: some View {
        ResultDialog {
            VStack(spacing: FQSpace.lg) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(FQColor.accent)
                    .accessibilityHidden(true)
                VStack(spacing: FQSpace.sm) {
                    Text("Call ended – continue the battle?")
                        .font(.fqTitle)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(model.isSensorBypassed
                         ? "The call didn't use your pause. \(clockText) left against \(boss.name)."
                         : "Put your phone face-down to keep fighting. The call didn't use your pause, \(clockText) left.")
                        .font(.fqSecondary)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if model.isSensorBypassed {
                    Button { model.continueAfterCall() } label: {
                        Text("Continue battle")
                            .font(.fqHeadline)
                            .foregroundStyle(FQColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FQSpace.xs)
                    }
                    .prominentGlassButtonStyle()
                    .buttonBorderShape(.roundedRectangle(radius: FQRadius.inDialog))
                    .controlSize(.large)
                    .tint(FQColor.accent)
                } else {
                    Label("Waiting for the phone to lie face-down", systemImage: "iphone.gen3")
                        .font(.fqLabel)
                        .foregroundStyle(FQColor.textSecondary)
                }
                Button("Retreat") { showsRetreatConfirm = true }
                    .font(.fqLabel)
                    .foregroundStyle(FQColor.textSecondary)
                    .frame(minHeight: 44)
                    .buttonStyle(.fqPress)
            }
        }
    }

    private func resultOverlay(icon: String, title: String, detail: String) -> some View {
        ResultDialog {
            VStack(spacing: FQSpace.lg) {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(FQColor.danger)
                    .accessibilityHidden(true)
                VStack(spacing: FQSpace.sm) {
                    Text(title).font(.fqTitle).multilineTextAlignment(.center).foregroundStyle(FQColor.textPrimary)
                    Text(detail).font(.fqSecondary).multilineTextAlignment(.center).foregroundStyle(FQColor.textSecondary)
                }
                Button(action: closeResult) {
                    Text("Back")
                        .font(.fqHeadline)
                        .foregroundStyle(FQColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FQSpace.xs)
                }
                .prominentGlassButtonStyle()
                .buttonBorderShape(.roundedRectangle(radius: FQRadius.inDialog))
                .controlSize(.large)
                .tint(FQColor.accent)
            }
        }
    }
}

// MARK: - Kulate tlacitko bitvy

/// Velke kulate tlacitko s popiskem pod nim. Tmava poloprusvitna vypln, aby bylo citelne
/// i na svetlem pozadi sveta; popisek bily se silnym stinem.
struct BattleActionButton: View {
    enum Tone { case neutral, accent, danger }

    let symbol: String
    let caption: String
    let tone: Tone
    let action: () -> Void

    private var fill: Color {
        switch tone {
        case .neutral: Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255).opacity(0.55)
        case .danger: Color(red: 60 / 255, green: 8 / 255, blue: 20 / 255).opacity(0.6)
        case .accent: Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255).opacity(0.7)
        }
    }

    private var rim: Color {
        switch tone {
        case .neutral: Color.white.opacity(0.18)
        case .danger: Color(red: 1, green: 84 / 255, blue: 102 / 255).opacity(0.45)
        case .accent: Color.white.opacity(0.45)
        }
    }

    private var iconColor: Color {
        switch tone {
        case .neutral: .white
        case .danger: FQColor.danger
        case .accent: FQColor.accent
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: FQSpace.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(iconColor)
                    .frame(width: 69, height: 69)
                    .background(.ultraThinMaterial, in: Circle())
                    .background(fill, in: Circle())
                    .overlay { Circle().strokeBorder(rim, lineWidth: 1) }
                    .shadow(color: .black.opacity(0.45), radius: 11, y: 8)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                Text(caption)
                    .font(.fqLabel)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.9), radius: 1, y: 1)
                    .shadow(color: .black.opacity(0.6), radius: 6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.fqPress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Zvednuty telefon

/// Alarm zvednuteho telefonu: staticka tmave cervena bez blikani, pomalu pulzuje jen cislo.
/// Alarm skonci sam, az senzor hlasi, ze telefon lezi v klidu. Dole je vedlejsi tlacitko Retreat
/// s potvrzenim primo u tlacitka (action sheet, v iOS 26 vyrusta z tlacitka).
private struct PhoneLiftedAlarm: View {
    let seconds: Double
    let bossName: String
    let onRetreat: () -> Void
    @State private var confirmsRetreat = false

    private let title = "Put it back on the desk"
    /// Odpocet bezi jen jednou: kdo telefon nepolozi do konce, tomu boss uteče.
    private var detail: String { "Lay it face-down before the countdown ends, or \(bossName) escapes with your loot." }

    var body: some View {
        ZStack {
            Color(red: 0x4A / 255, green: 0x07 / 255, blue: 0x10 / 255).ignoresSafeArea()
            VStack(spacing: 18) {
                CenteredIconText("Phone lifted", systemImage: "iphone.gen3")
                    .font(.fqLabel.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.white)
                PulsingCount(text: "\(Int(ceil(seconds)))")
                VStack(spacing: FQSpace.sm) {
                    Text(title)
                        .fqFont(size: 28, weight: .bold, design: .rounded)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text(detail)
                        .font(.fqSecondary)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                }
                CenteredIconText("The alarm stops by itself when the phone lies still.", systemImage: "iphone.gen3")
                    .font(.fqSecondary)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                retreatButton.padding(.top, FQSpace.md)
            }
            .padding(.horizontal, FQSpace.xl)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .environment(\.colorScheme, .dark)
    }

    /// Vedlejsi tlacitko (obrys, bez vyplne), aby nesoutezilo s hlavnim pokynem "polozit telefon".
    private var retreatButton: some View {
        Button { confirmsRetreat = true } label: {
            Label("Retreat", systemImage: "flag.fill")
                .font(.fqLabel.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, FQSpace.xl)
                .frame(minHeight: 44)
                .overlay { Capsule().strokeBorder(Color.white.opacity(0.45), lineWidth: 1) }
                .contentShape(Capsule())
        }
        .buttonStyle(.fqPress)
        .accessibilityHint("Give up this battle. The boss escapes.")
        .confirmationDialog("Retreat from the battle?", isPresented: $confirmsRetreat, titleVisibility: .visible) {
            Button("Retreat", role: .destructive) { FQFeedback.shared.tap(); onRetreat() }
            Button("Keep fighting", role: .cancel) { FQFeedback.shared.tap() }
        } message: {
            Text("\(bossName) escapes and this battle gives no loot.")
        }
    }
}

/// Cislo odpoctu: pomalu dycha (pruhlednost 1 -> 0,55 -> 1, cely cyklus 2,4 s, ease-in-out), velikost stoji.
/// Pruhlednost se pocita z hodin (TimelineView), ne z repeatForever animace: obrazovka se prekresluje
/// kazdych 0,1 s s odpoctem a ta by animaci zrusila (proto driv cislo nepulzovalo). S Reduce Motion stoji.
private struct PulsingCount: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let period: TimeInterval = 2.4
    static let dimmest = 0.55

    /// Kosinus je ease-in-out: v 0 s je 1, v pulce cyklu 0,55, na konci zase 1.
    static func opacity(at time: TimeInterval) -> Double {
        let phase = time.truncatingRemainder(dividingBy: period) / period
        return dimmest + (1 - dimmest) * (1 + cos(2 * .pi * phase)) / 2
    }

    var body: some View {
        if reduceMotion {
            number.opacity(1)
        } else {
            TimelineView(.animation) { context in
                number.opacity(Self.opacity(at: context.date.timeIntervalSinceReferenceDate))
            }
        }
    }

    private var number: some View {
        Text(text)
            .font(.system(size: 136, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
    }
}

// MARK: - Dychani bosse

private struct BossBreathing: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inhale = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(inhale ? 1.02 : 1, anchor: UnitPoint(x: 0.5, y: 0.92))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { inhale = true }
            }
    }
}

extension View {
    /// Boss jen jemne dycha (meritko 1,02). Nikdy nebledne: pruhlednost zustava 1.
    func bossBreathing() -> some View { modifier(BossBreathing()) }
}

extension Boss {
    /// Uroven bosse podle poradi na ceste sveta ("Novice", "Adept", "Elite", "Mythic").
    /// Rozcvicka ma misto urovne "Warm-up" (hlavicka bitvy pak ukaze "Warm-up · 5 min").
    var tierTitle: String {
        if isWarmUp { return "Warm-up" }
        return switch nodeIndex {
        case ..<2: "Novice"
        case ..<4: "Adept"
        case ..<6: "Elite"
        default: "Mythic"
        }
    }
}

/// "Lay the phone…" a po 8 s bez reakce senzoru nenapadne tlacitko "Start without sensor".
private struct PlacementHint: View {
    static let fallbackDelay: Duration = .seconds(8)
    let onStartWithoutSensor: () -> Void
    @State private var showsFallback = false

    var body: some View {
        VStack(spacing: FQSpace.sm) {
            CenteredIconText("Lay the phone face-down. The battle starts when it lies still.", systemImage: "iphone.gen3")
                .font(.fqLabel)
                .foregroundStyle(FQColor.textPrimary)
                .multilineTextAlignment(.center)
            if showsFallback {
                Button("Start without sensor", action: onStartWithoutSensor)
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
                    .underline()
                    .frame(minHeight: 44)
                    .buttonStyle(.fqPress)
                    .accessibilityHint("Starts the battle now. Lifting the phone is not checked.")
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: Self.fallbackDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { showsFallback = true }
        }
    }
}

/// Cislo, ktere se pri animaci "nacita" (XP a mince na obrazovce vitezstvi).
/// `animatableData` je nonisolated, aby shoda s Animatable neprekracovala do MainActor (Swift 6).
private struct CountUpNumber: View, Animatable {
    var value: Double
    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View { Text("+\(Int(value.rounded()))") }
}

/// Prestavka po vyhre (B3): sheet se dvema vyskami. Kompaktni = BREAK, odpocet 5:00 (v 0:00 "Break's over",
/// zluty cas a zvuk) a zlute tlacitko na dalsiho bosse. Vytazeni nahoru navic ukaze Same again, Change boss,
/// Done for today a malou scenu odpocivajiciho hrdiny. Mezi vyskami se tahne plynule (systemove detenty);
/// uplne stahnout panel nejde, zavre se jen tlacitky.
private struct BreakPanel: View {
    let nextBoss: Boss?
    let sameAgain: Boss
    let hero: AvatarAppearance
    let heroClass: HeroClass
    let accent: Color
    let onNextBoss: (Boss) -> Void
    let onSameAgain: () -> Void
    let onChangeBoss: () -> Void
    let onDone: () -> Void
    let onBreakOver: () -> Void

    static let breakSeconds = 5 * 60
    /// Kompaktni vyska: madlo, BREAK, odpocet a Next boss.
    static let compact = PresentationDetent.height(330)
    /// Roztazena vyska: navic dlazdice, Done for today a scena hrdiny.
    static let expanded = PresentationDetent.height(640)

    /// Konec prestavky podle hodin, takze odpocet sedi i po navratu z pozadi.
    @State private var endsAt = Date().addingTimeInterval(TimeInterval(BreakPanel.breakSeconds))
    @State private var detent = BreakPanel.compact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isExpanded: Bool { detent == Self.expanded }

    var body: some View {
        // ScrollView jen kvuli zarovnani nahoru: obsah ma prirozenou vysku a sheet ho orizne podle detentu.
        ScrollView {
            VStack(spacing: FQSpace.lg) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    countdown(secondsLeft: max(0, Int(ceil(endsAt.timeIntervalSince(context.date)))))
                }
                if let nextBoss {
                    nextBossButton(nextBoss)
                } else {
                    // Vsechny svety dobyte: hlavni akce je zopakovat posledniho bosse.
                    tile(symbol: "arrow.counterclockwise", title: "Same again", detail: sameAgain.name, action: onSameAgain)
                }
                VStack(spacing: FQSpace.md) {
                    if nextBoss != nil {
                        HStack(spacing: FQSpace.sm) {
                            tile(symbol: "arrow.counterclockwise", title: "Same again", detail: sameAgain.name, action: onSameAgain)
                            tile(symbol: "map.fill", title: "Change boss", detail: "Pick on the Path", action: onChangeBoss)
                        }
                    } else {
                        tile(symbol: "map.fill", title: "Change boss", detail: "Pick on the Path", action: onChangeBoss)
                    }
                    Button(action: onDone) {
                        Text("Done for today")
                            .font(.fqLabel)
                            .foregroundStyle(FQColor.textPrimary)
                            .padding(.horizontal, FQSpace.xl)
                            .frame(minHeight: 44)
                            .overlay(Capsule().strokeBorder(FQColor.textSecondary.opacity(0.55), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.fqPress)
                    RestingHeroScene(hero: hero, heroClass: heroClass, accent: accent)
                }
                // V kompaktni vysce je cast pod okrajem: prolne se, az se panel vytahne.
                .opacity(isExpanded ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: isExpanded)
                .accessibilityHidden(!isExpanded)
            }
            .padding(.horizontal, FQSpace.lg)
            .padding(.top, FQSpace.xl)
            .padding(.bottom, FQSpace.xl)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDisabled(true)
        .scrollIndicators(.hidden)
        .presentationDetents([Self.compact, Self.expanded], selection: $detent)
        .presentationDragIndicator(.visible)
        // Stahnout dolu nejde (jen mezi vyskami); zavreni jen tlacitky.
        .interactiveDismissDisabled()
        .presentationBackgroundInteraction(.disabled)
        .presentationCornerRadius(FQRadius.breakPanel)
        .presentationBackground(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .task {
            // Zvuk prijde jednou, az odpocet opravdu dobehne.
            let left = endsAt.timeIntervalSinceNow
            if left > 0 { try? await Task.sleep(for: .seconds(left)) }
            guard !Task.isCancelled else { return }
            onBreakOver()
        }
    }

    private func countdown(secondsLeft: Int) -> some View {
        let over = secondsLeft == 0
        return VStack(spacing: FQSpace.xs) {
            Text(over ? "Break's over" : "Break")
                .font(.fqLabel)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(over ? FQColor.cta : FQColor.textSecondary)
            Text(BattleView.minutesSeconds(secondsLeft))
                .font(.system(size: 76, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(over ? FQColor.cta : FQColor.textPrimary)
                .contentTransition(.numericText(countsDown: true))
            Text("Stand up, drink some water. The next boss waits.")
                .font(.fqSecondary)
                .multilineTextAlignment(.center)
                .foregroundStyle(FQColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// Zlute tlacitko ze tri casti: ▶ kolecko · "NEXT BOSS" + jmeno · pilulka s minutami.
    private func nextBossButton(_ boss: Boss) -> some View {
        Button { onNextBoss(boss) } label: {
            HStack(spacing: FQSpace.md) {
                ZStack {
                    Circle().fill(FQColor.onCta)
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(FQColor.cta)
                        .offset(x: 1)
                }
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Next boss")
                        .fqFont(size: 11, weight: .bold, design: .rounded)
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .opacity(0.72)
                    Text(boss.name)
                        .fqFont(size: 18, weight: .heavy, design: .rounded)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: FQSpace.xs)
                Text(ArenaView.durationText(minutes: boss.maxHP))
                    .fqFont(size: 13, weight: .bold, design: .rounded)
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(FQColor.onCta.opacity(0.14), in: Capsule())
            }
            .foregroundStyle(FQColor.onCta)
            .padding(.horizontal, FQSpace.sm)
            .frame(height: 60)
            .background(FQColor.cta, in: FQRadius.shape(FQRadius.inBreakPanel))
            .contentShape(FQRadius.shape(FQRadius.inBreakPanel))
        }
        .buttonStyle(.fqPress)
        .accessibilityLabel("Next boss: \(boss.name), \(ArenaView.durationText(minutes: boss.maxHP))")
    }

    private func tile(symbol: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FQColor.accent)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.fqHeadline)
                    .foregroundStyle(FQColor.textPrimary)
                Text(detail)
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(FQSpace.md)
            .fqInnerTile(in: FQRadius.shape(FQRadius.breakPanelBottom))
            .contentShape(FQRadius.shape(FQRadius.breakPanelBottom))
        }
        .buttonStyle(.fqPress)
    }
}

/// B3: mala scena v roztazenem panelu prestavky: hrdina odpociva u pixeloveho ohne a nad nim plujou "z".
/// S Reduce Motion stoji (ohen neplapola, "z" stoji).
private struct RestingHeroScene: View {
    let hero: AvatarAppearance
    let heroClass: HeroClass
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 8, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .bottom) {
                // Zem a jemna zare ohne.
                Capsule()
                    .fill(Color.black.opacity(0.25))
                    .frame(height: 14)
                    .padding(.horizontal, FQSpace.xl)
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.6, blue: 0.2).opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 70))
                    .frame(width: 140, height: 140)
                    .offset(x: 34, y: 40)
                HStack(alignment: .bottom, spacing: FQSpace.lg) {
                    ZStack(alignment: .topTrailing) {
                        HeroAvatarView(appearance: hero, heroClass: heroClass, size: 72)
                            // Pomale dychani.
                            .scaleEffect(x: 1, y: 1 + 0.02 * sin(t * 1.6), anchor: .bottom)
                        ForEach(0..<3, id: \.self) { index in
                            let phase = (t * 0.45 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                            Text("z")
                                .fqFont(size: 11 + CGFloat(index) * 3, weight: .heavy, design: .rounded)
                                .foregroundStyle(FQColor.textSecondary)
                                .opacity(reduceMotion ? 0.8 : 1 - phase)
                                .offset(x: 6 + CGFloat(index) * 8 + (reduceMotion ? 0 : CGFloat(phase) * 6),
                                        y: -4 - CGFloat(index) * 10 - (reduceMotion ? 0 : CGFloat(phase) * 14))
                        }
                    }
                    PixelCampfire(time: t)
                        .frame(width: 36, height: 42)
                }
                .padding(.bottom, 6)
            }
        }
        .frame(height: 110)
        .frame(maxWidth: .infinity)
        .background(accent.opacity(0.08), in: FQRadius.shape(FQRadius.inBreakPanel))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your hero rests by the fire")
    }
}

/// Pixelovy taborak: polena a plamen, ktery se kazdou 1/8 s maly zmeni.
private struct PixelCampfire: View {
    let time: TimeInterval

    private static let frames: [[String]] = [
        ["...Y..", "..YO..", ".YOOY.", ".ORRO.", "ORRRRO", "BB..BB"],
        ["..Y...", "..OY..", ".YOOY.", ".OROO.", "ORRRRO", "BB..BB"],
        ["....Y.", "..YO..", ".YOOO.", ".ORRO.", "OORRRO", "BB..BB"],
    ]

    var body: some View {
        let rows = Self.frames[Int(time * 8) % Self.frames.count]
        ZStack {
            PixelLayerShape(rows: rows, symbol: "B").fill(Color(red: 0.45, green: 0.28, blue: 0.16))
            PixelLayerShape(rows: rows, symbol: "R").fill(Color(red: 0.95, green: 0.30, blue: 0.15))
            PixelLayerShape(rows: rows, symbol: "O").fill(Color(red: 1.0, green: 0.60, blue: 0.20))
            PixelLayerShape(rows: rows, symbol: "Y").fill(Color(red: 1.0, green: 0.88, blue: 0.40))
        }
    }
}
