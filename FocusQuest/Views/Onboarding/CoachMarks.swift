import SwiftUI

// Tutorial v appce (F2, 1B): coach marks misto TipKitu. Cela obrazovka ztmavne, zvyrazneny prvek je
// z tmy "vyrizly" (zaobleny vyrez s jemnou pulzujici zari) a vedle je bublina s textem.
// Pozice prvku se zjistuje pres anchorPreference (`.coachMark(_:)`), nikdy natvrdo:
// hostitel (`.coachMarkHost()`) kotvy prevede na globalni ramecky a ulozi je do CoachMarkStore.
// Pres hranici TabView a listu preference nemusi projit, proto ma kazda zalozka, lista
// a Fight sheet vlastniho hostitele.

/// Prvky, ktere tutorial umi zvyraznit.
enum CoachTarget: String, Hashable, Sendable {
    case fight, quick, streak, focusing, sound, start, tabPath, tabShop, tabStats, tabHero, gear
    /// A4: graf Habits, karta s cisly ve Stats a Daily focus target v Hero.
    case habits, statNumbers, dailyTarget

    /// Kulate a kapslove prvky maji kulaty vyrez, karty a sekce Fight sheetu zaobleny obdelnik.
    var isRound: Bool {
        switch self {
        case .focusing, .sound, .habits, .statNumbers, .dailyTarget: false
        default: true
        }
    }
}

/// Zalozka, na ktere krok tutorialu stoji (A2). Kroky ve Fight sheetu maji `nil`.
enum CoachScreen: Sendable {
    case home, path, shop, stats, hero
}

/// Kroky tutorialu v poradi, jak appku hrac poprve pouzije.
enum CoachStep: Int, CaseIterable, Sendable {
    case fight, focusing, sound, battle, quick, streak, path, shop, stats, habits, statNumbers, hero, dailyTarget, settings

    /// Pocet kroku pro hrace. Hero (klepnuti na zalozku) a Daily focus target jsou jeden krok "12 of 13".
    static let total = 13

    /// Cislo kroku pro hrace ("3 of 13").
    var number: Int { self.rawValue >= CoachStep.dailyTarget.rawValue ? self.rawValue : self.rawValue + 1 }

    var target: CoachTarget {
        switch self {
        case .fight: .fight
        case .focusing: .focusing
        case .sound: .sound
        case .battle: .start
        case .quick: .quick
        case .streak: .streak
        case .path: .tabPath
        case .shop: .tabShop
        case .stats: .tabStats
        case .habits: .habits
        case .statNumbers: .statNumbers
        case .hero: .tabHero
        case .dailyTarget: .dailyTarget
        case .settings: .gear
        }
    }

    /// Zalozka, na ktere ma hrac byt, kdyz se krok ukaze. Akcni krok zalozky stoji na predchozi zalozce
    /// (klepnutim na zvyraznenou zalozku se posune dal).
    var screen: CoachScreen? {
        switch self {
        case .fight, .quick, .streak, .path: .home
        case .focusing, .sound, .battle: nil
        case .shop: .path
        case .stats: .shop
        case .habits, .statNumbers, .hero: .stats
        case .dailyTarget, .settings: .hero
        }
    }

    /// Krok se posune az klepnutim na zvyrazneny prvek (ostatni jsou blokovane).
    var isAction: Bool {
        switch self {
        case .fight, .path, .shop, .stats, .hero: true
        default: false
        }
    }

    /// Kroky uvnitr Fight sheetu kresli overlay listu, ne hlavni obrazovka.
    var isInFightSheet: Bool { screen == nil }

    var title: String {
        switch self {
        case .fight: "Here's where focus starts"
        case .focusing: "What are you focusing on?"
        case .sound: "Music or quiet"
        case .battle: "Phone down, hero fights"
        case .quick: "Not feeling it?"
        case .streak: "Your streak"
        case .path: "The Path"
        case .shop: "The Shop"
        case .stats: "Your progress"
        case .habits: "Your habits"
        case .statNumbers: "Your numbers"
        case .hero: "Your hero"
        case .dailyTarget: "Daily focus target"
        case .settings: "Settings"
        }
    }

    /// Nejvys dve vety.
    var text: String {
        switch self {
        case .fight: "Every boss is one focus session. Tap Fight to set one up."
        case .focusing: "Pick what this session is for. Stats tracks your time for each one."
        case .sound: "Choose music or quiet for the battle. It keeps playing when the screen is locked."
        case .battle: "After Start, lay your phone face down and your hero fights. Lift it and the boss escapes in 10 seconds, unless you use one of 2 pauses."
        case .quick: "Start with just 5 minutes. Small wins still count."
        case .streak: "Focus a little every day to keep the flame going."
        case .path: "Worlds full of bosses wait on the map. Tap Path to take a look."
        case .shop: "Coins from battles buy gear and backgrounds. Tap Shop."
        case .stats: "Focus time, streaks and habits live here. Tap Stats."
        case .habits: "Each square is one day, and the brighter it glows, the more minutes you focused. Today is the first square, top left."
        case .statNumbers: "Win rate is the share of battles you won, next to bosses beaten. Longest streak counts days in a row, focus hours add up all your time."
        case .hero: "Change your hero's look any time. Tap Hero."
        case .dailyTarget: "The ring fills with your class color as you focus today. Slide to set a goal that fits you."
        case .settings: "Sounds, music and notifications are behind the gear. You're all set!"
        }
    }

    /// Popisek tlacitka u informacnich kroku.
    var buttonTitle: String {
        switch self {
        case .battle: "Got it"
        case .settings: "Done"
        default: "Next"
        }
    }
}

/// Stav onboardingu a tutorialu. Uklada se po kazdem kroku, takze po padu nebo zavreni appky
/// tutorial pokracuje od posledniho kroku (kroky uvnitr Fight sheetu od kroku 1).
@Observable
@MainActor
final class CoachMarkStore {
    private enum Keys {
        static let onboardingDone = "focusquest.onboarding.done"
        static let tutorialStep = "focusquest.tutorial.step"
    }

    /// Uvodni onboarding (1A) je hotovy.
    private(set) var onboardingDone: Bool
    /// Aktualni krok tutorialu; nil = tutorial nebezi.
    private(set) var step: CoachStep?
    /// Zmerene ramecky prvku (globalni souradnice) od vsech hostitelu.
    private(set) var frames: [CoachTarget: CGRect] = [:]
    @ObservationIgnored private var hostFrames: [UUID: [CoachTarget: CGRect]] = [:]
    /// Zalozka, ktera je prave videt (nastavuje MainTabView). Vyrez kroku se ukaze jen na jeho zalozce (A2).
    var screen: CoachScreen = .home
    /// Zmena rozvrzeni (zalozka, otevreni/zavreni listu, otoceni): overlay vyrez schova a po vykresleni
    /// znovu zmeri, takze nikdy nesedi na starem miste.
    private(set) var layoutVersion = 0

    func layoutChanged() { layoutVersion &+= 1 }
    /// Akce akcniho kroku pro VoiceOver (vyrez se hlasovym ovladanim neda klepnout): otevre Fight sheet,
    /// prepne zalozku. Nastavuje MainTabView.
    @ObservationIgnored var performAction: (@MainActor (CoachStep) -> Void)?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        onboardingDone = defaults.bool(forKey: Keys.onboardingDone)
        let saved = (defaults.object(forKey: Keys.tutorialStep) as? Int).flatMap(CoachStep.init(rawValue:))
        // Fight sheet po spusteni neni otevreny: kroky v nem zacnou znovu od Fight.
        step = saved?.isInFightSheet == true ? .fight : saved
    }

    /// Konec onboardingu; tutorial se spusti az po zavreni obrazovky onboardingu (`startTutorial`).
    func finishOnboarding() {
        onboardingDone = true
        defaults.set(true, forKey: Keys.onboardingDone)
    }

    /// Hrac, ktery uz appku pouziva (ma odehrane bitvy): onboarding ani tutorial se mu neukazou.
    func markExistingPlayer() {
        finishOnboarding()
    }

    func startTutorial() { set(.fight) }

    /// Posun dal, jen kdyz krok jeste plati (dvojite klepnuti ho neposune dvakrat).
    func advance(from current: CoachStep) {
        guard step == current else { return }
        set(CoachStep(rawValue: current.rawValue + 1))
    }

    func skipTutorial() { set(nil) }

    /// Fight sheet se zavrel uprostred kroku v nem: tutorial pokracuje na Home ("Just 5 minutes").
    func leaveFightSheet() {
        guard step?.isInFightSheet == true else { return }
        set(.quick)
    }

    /// Debug "Reset onboarding": znovu 1A i 1B od zacatku.
    func resetOnboarding() {
        onboardingDone = false
        defaults.set(false, forKey: Keys.onboardingDone)
        set(nil)
    }

    private func set(_ value: CoachStep?) {
        step = value
        if let value { defaults.set(value.rawValue, forKey: Keys.tutorialStep) } else { defaults.removeObject(forKey: Keys.tutorialStep) }
    }

    // MARK: - Ramecky prvku

    func updateFrames(_ rects: [CoachTarget: CGRect], host: UUID) {
        guard hostFrames[host] != rects else { return }
        hostFrames[host] = rects
        mergeFrames()
    }

    func removeHost(_ host: UUID) {
        guard hostFrames.removeValue(forKey: host) != nil else { return }
        mergeFrames()
    }

    private func mergeFrames() {
        var merged: [CoachTarget: CGRect] = [:]
        for rects in hostFrames.values { merged.merge(rects) { $1 } }
        if merged != frames { frames = merged }
    }
}

// MARK: - Kotvy

struct CoachAnchorKey: PreferenceKey {
    static let defaultValue: [CoachTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachTarget: Anchor<CGRect>], nextValue: () -> [CoachTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Prvek, ktery tutorial muze zvyraznit.
    func coachMark(_ target: CoachTarget) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { [target: $0] }
    }

    /// Prevede kotvy prvku pod sebou na globalni ramecky pro tutorial.
    func coachMarkHost() -> some View { modifier(CoachMarkHost()) }
}

private struct CoachMarkHost: ViewModifier {
    @Environment(CoachMarkStore.self) private var coach: CoachMarkStore?
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content.backgroundPreferenceValue(CoachAnchorKey.self) { anchors in
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                let rects = anchors.mapValues { proxy[$0].offsetBy(dx: origin.x, dy: origin.y) }
                Color.clear
                    .onAppear { coach?.updateFrames(rects, host: id) }
                    .onChange(of: rects) { _, new in coach?.updateFrames(new, host: id) }
                    .onDisappear { coach?.removeHost(id) }
            }
        }
    }
}

// MARK: - Overlay

/// Ztmaveni s vyrezem, zare, bublina a "Skip tutorial". Hlavni obrazovka a Fight sheet maji kazdy svuj overlay;
/// kazdy kresli jen sve kroky. Krok se ukaze az po ustaleni (prechod zalozky, zavreni listu), takze vyrez
/// nikdy neproblikne na spatnem miste. Kdyz se prvek do ~2 s nenajde, krok se tise preskoci.
struct CoachMarkOverlay: View {
    enum Placement { case main, fightSheet }

    let placement: Placement
    /// Konec kroku "battle" ve Fight sheetu: list se zavre (bitva se nespusti).
    var closeSheet: (() -> Void)?

    @Environment(CoachMarkStore.self) private var coach
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    /// Krok, jehoz prvek je zmereny a vyrez je videt.
    @State private var shown: CoachStep?
    @AccessibilityFocusState private var bubbleFocused: Bool

    /// Krok patri tomuto overlayi.
    private var ownStep: CoachStep? {
        guard let step = coach.step, step.isInFightSheet == (placement == .fightSheet) else { return nil }
        return step
    }

    var body: some View {
        ZStack {
            if ownStep != nil {
                GeometryReader { proxy in
                    let origin = proxy.frame(in: .global).origin
                    let bounds = CGRect(origin: .zero, size: proxy.size)
                    if let step = shown, let frame = coach.frames[step.target] {
                        let hole = Self.hole(for: frame.offsetBy(dx: -origin.x, dy: -origin.y), target: step.target)
                        stage(step: step, hole: hole, bounds: bounds)
                    } else {
                        // Mezi kroky (a pred prvnim): pruhledna vrstva jen blokuje klepnuti.
                        Color.black.opacity(0.001)
                            .onTapGesture { }
                            .accessibilityHidden(true)
                    }
                }
                .ignoresSafeArea()
                if shown != nil && shown != .settings {
                    skipButton
                }
            }
        }
        // VoiceOver cte jen bublinu a Skip, ne obrazovku pod ztmavenim.
        .accessibilityAddTraits(shown != nil ? .isModal : [])
        // Otoceni nebo jina velikost: vyrez se prepocita.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in coach.layoutChanged() }
        // Novy krok, zmena zalozky nebo listu: vyrez se schova a zmeri znovu az po vykresleni (A2).
        .task(id: ResolveKey(step: coach.step, layout: coach.layoutVersion, screen: coach.screen)) { await resolve() }
    }

    private struct ResolveKey: Equatable {
        let step: CoachStep?
        let layout: Int
        let screen: CoachScreen
    }

    // MARK: Rozvrzeni

    @ViewBuilder
    private func stage(step: CoachStep, hole: CoachHole, bounds: CGRect) -> some View {
        let isLive = step == coach.step
        ZStack {
            CoachDimShape(hole: hole.rect, radius: hole.radius)
                .fill(Color.black.opacity(0.72), style: FillStyle(eoFill: true))
                // Akcni krok: klepnuti do vyrezu projde na prvek, jinde se zahodi.
                .contentShape(CoachDimShape(hole: step.isAction && isLive ? hole.rect : .zero, radius: hole.radius), eoFill: true)
                .onTapGesture { }
                .accessibilityHidden(true)
            CoachGlow(rect: hole.rect, radius: hole.radius, pulsing: !reduceMotion)
            bubble(step: step, hole: hole.rect, bounds: bounds)
        }
    }

    private func bubble(step: CoachStep, hole: CGRect, bounds: CGRect) -> some View {
        let below = bounds.maxY - hole.maxY >= hole.minY - bounds.minY
        let width = min(340, bounds.width - 2 * FQSpace.lg)
        return VStack(alignment: .leading, spacing: FQSpace.sm) {
            HStack(spacing: FQSpace.sm) {
                if step == .battle { PhoneFlipIcon() }
                Text(step.title)
                    .fqFont(size: 17, weight: .bold, design: .rounded)
                    .foregroundStyle(FQColor.textPrimary)
                Spacer(minLength: FQSpace.sm)
                Text("\(step.number) of \(CoachStep.total)")
                    .font(.fqMeta)
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textSecondary)
            }
            Text(step.text)
                .font(.fqSecondary)
                .foregroundStyle(FQColor.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            if !step.isAction || voiceOver {
                HStack {
                    Spacer()
                    Button { next(step) } label: {
                        Text(step.isAction ? "Open" : step.buttonTitle)
                            .fqFont(size: 16, weight: .heavy, design: .rounded)
                            .foregroundStyle(FQColor.onCta)
                            .padding(.horizontal, FQSpace.xl)
                            .frame(minHeight: 44)
                            .background(FQColor.cta, in: Capsule())
                    }
                    .buttonStyle(.fqPress)
                }
            }
        }
        .padding(FQSpace.lg)
        .frame(width: width)
        // Stejne sklo jako vysledky bitvy a karty v Shop › Backgrounds (2B).
        .fqGlassPanel(radius: FQRadius.smallCard)
        .accessibilityElement(children: .contain)
        .accessibilityFocused($bubbleFocused)
        .id(step)
        .transition(.opacity)
        // Bublina pod prvkem, kdyz je tam vic mista, jinak nad nim; vodorovne u prvku, ale cela na obrazovce.
        .offset(x: min(max(hole.midX, width / 2 + FQSpace.lg), bounds.width - width / 2 - FQSpace.lg) - bounds.width / 2)
        .padding(below ? Edge.Set.top : Edge.Set.bottom, below ? hole.maxY + FQSpace.md : bounds.height - hole.minY + FQSpace.md)
        .frame(width: bounds.width, height: bounds.height, alignment: below ? .top : .bottom)
    }

    /// A3: samostatna pilulka vlevo nahore v bezpecne zone. Pod ni je jemny tmavsi prechod, ktery
    /// ztlumi nadpisy obrazovky, takze se text pilulky s nicim neplete; pilulka ma vlastni plne pozadi a stin.
    private var skipButton: some View {
        let ink = Color(red: 10 / 255, green: 9 / 255, blue: 20 / 255)
        return VStack(spacing: 0) {
            HStack {
                Button { withAnimation(.easeOut(duration: 0.25)) { coach.skipTutorial() } } label: {
                    Text("Skip tutorial")
                        .fqFont(size: 15, weight: .semibold, design: .rounded)
                        .foregroundStyle(FQColor.textPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, FQSpace.lg)
                        .frame(minHeight: 40)
                        .background(ink.opacity(0.94), in: Capsule())
                        .overlay { Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1) }
                        .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                        .frame(minHeight: 44)
                        .contentShape(Capsule())
                }
                .buttonStyle(.fqPress)
                Spacer()
            }
            .padding(.horizontal, FQSpace.lg)
            .padding(.top, placement == .fightSheet ? FQSpace.md : FQSpace.xs)
            .padding(.bottom, FQSpace.md)
            .background(alignment: .top) {
                LinearGradient(colors: [ink.opacity(0.85), ink.opacity(0.55), ink.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .padding(.top, -80)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: Logika

    private func next(_ step: CoachStep) {
        if step.isAction {
            coach.performAction?(step)
            return
        }
        withAnimation(.easeOut(duration: 0.2)) { coach.advance(from: step) }
        if step == .battle { closeSheet?() }
    }

    /// Ceka, az se prvek kroku zmeri a obrazovka se ustali; pak vyrez ukaze. Nenalezeny prvek = krok se preskoci.
    private func resolve() async {
        guard let step = ownStep else {
            withAnimation(.easeOut(duration: 0.2)) { shown = nil }
            return
        }
        // Jina zalozka, nez krok potrebuje (MainTabView ji prave prepina), nebo zmena rozvrzeni:
        // stary vyrez hned pryc, aby nesedel na prazdnem miste.
        if let screen = step.screen, screen != coach.screen {
            withAnimation(.easeOut(duration: 0.15)) { shown = nil }
            return
        }
        if shown != nil && shown == step {
            withAnimation(.easeOut(duration: 0.15)) { shown = nil }
        }
        // Prechod zalozky, zavreni onboardingu nebo listu: chvili pockat, at vyrez nesedi na pohybujicim se prvku.
        try? await Task.sleep(for: .milliseconds(shown == nil ? 450 : 350))
        for _ in 0..<10 {
            guard !Task.isCancelled else { return }
            if let screen = step.screen, screen != coach.screen { return }
            if let frame = coach.frames[step.target], frame.width > 1, frame.height > 1 {
                if reduceMotion {
                    // Reduce Motion: zadny presun vyrezu, jen prolnuti.
                    withAnimation(.easeOut(duration: 0.15)) { shown = nil }
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation(.easeIn(duration: 0.2)) { shown = step }
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { shown = step }
                }
                try? await Task.sleep(for: .milliseconds(250))
                bubbleFocused = true
                return
            }
            try? await Task.sleep(for: .milliseconds(160))
        }
        guard !Task.isCancelled else { return }
        // Prvek neni (napr. vsechny svety dobyte, Fight chybi): krok se tise preskoci, appka nezamrzne.
        coach.advance(from: step)
    }

    static func hole(for frame: CGRect, target: CoachTarget) -> CoachHole {
        let rect = frame.insetBy(dx: -8, dy: -8)
        return CoachHole(rect: rect, radius: target.isRound ? rect.height / 2 : 20)
    }
}

struct CoachHole {
    let rect: CGRect
    let radius: CGFloat
}

/// Cela plocha minus zaobleny vyrez (vyplnuje se pravidlem even-odd). Vyrez se pruzne presouva.
struct CoachDimShape: Shape {
    var hole: CGRect
    var radius: CGFloat

    nonisolated var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>> {
        get { AnimatablePair(AnimatablePair(hole.origin.x, hole.origin.y), AnimatablePair(AnimatablePair(hole.size.width, hole.size.height), radius)) }
        set {
            hole = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first.first, height: newValue.second.first.second)
            radius = newValue.second.second
        }
    }

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -400, dy: -400))
        if hole.width > 0 {
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        }
        return path
    }
}

/// Jemna zare kolem vyrezu; pulzuje, s Reduce Motion stoji.
private struct CoachGlow: View {
    let rect: CGRect
    let radius: CGFloat
    let pulsing: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Group {
            if pulsing {
                shape
                    .strokeBorder(FQColor.cta.opacity(0.85), lineWidth: 2)
                    .phaseAnimator([false, true]) { view, phase in
                        view
                            .shadow(color: FQColor.cta.opacity(phase ? 0.7 : 0.25), radius: phase ? 14 : 6)
                            .scaleEffect(phase ? 1.03 : 1)
                    } animation: { _ in .easeInOut(duration: 1.1) }
            } else {
                shape
                    .strokeBorder(FQColor.cta.opacity(0.85), lineWidth: 2)
                    .shadow(color: FQColor.cta.opacity(0.45), radius: 10)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Mini animace v kroku bitvy: telefon se otoci displejem dolu.
private struct PhoneFlipIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "iphone")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(FQColor.cta)
            .phaseAnimator(reduceMotion ? [false] : [false, true]) { view, flipped in
                view.rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 1, y: 0, z: 0))
            } animation: { _ in .easeInOut(duration: 0.9).delay(0.6) }
            .frame(width: 22)
            .accessibilityHidden(true)
    }
}
