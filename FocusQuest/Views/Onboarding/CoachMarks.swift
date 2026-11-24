import SwiftUI
import UIKit

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
/// K1/D3: kazdy krok se posune jen tlacitkem Next (posledni Finish). Zvyraznene prvky nejsou interaktivni;
/// zalozku a Fight sheet prepina tutorial sam a vyrez pocka, az je cilovy prvek vykresleny.
enum CoachStep: Int, CaseIterable, Sendable {
    case fight, focusing, sound, battle, quick, streak, path, shop, stats, habits, statNumbers, dailyTarget, settings

    /// Pocet kroku pro hrace.
    static let total = CoachStep.allCases.count

    /// Cislo kroku pro hrace ("3 of 13").
    var number: Int { rawValue + 1 }

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
        case .dailyTarget: .dailyTarget
        case .settings: .gear
        }
    }

    /// Zalozka, na ktere krok stoji. Kroky zalozek stoji na sve zalozce: po Next ji tutorial prepne sam.
    var screen: CoachScreen? {
        switch self {
        case .fight, .quick, .streak: .home
        case .focusing, .sound, .battle: nil
        case .path: .path
        case .shop: .shop
        case .stats, .habits, .statNumbers: .stats
        case .dailyTarget, .settings: .hero
        }
    }

    /// Kroky uvnitr Fight sheetu: list otevre a zavre tutorial sam (Next na kroku Fight, Next na kroku battle).
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
        case .dailyTarget: "Your hero"
        case .settings: "Settings"
        }
    }

    /// Nejvys dve vety.
    var text: String {
        switch self {
        case .fight: "Every boss is one focus session. Fight opens the setup for the next one."
        case .focusing: "Pick what this session is for. Stats tracks your time for each one."
        case .sound: "Choose music or quiet for the battle. It keeps playing when the screen is locked."
        case .battle: "After Start, lay your phone face down and your hero fights. Lift it and the boss escapes in 10 seconds, unless you use your free pause."
        case .quick: "Start with just 5 minutes. Small wins still count."
        case .streak: "Focus a little every day to keep the flame going."
        case .path: "Worlds full of bosses wait on the map. Each win moves you along the path."
        case .shop: "Coins from battles buy gear for your hero, backgrounds and supplies like streak freezes."
        case .stats: "Focus time, streaks and habits live on this tab."
        case .habits: "Each square is one day, starting from your first day: rows are Monday to Sunday, every week adds a column. Today has a white frame, and brighter squares mean more focus."
        case .statNumbers: "Win rate is the share of battles you won, next to bosses beaten. Longest streak counts days in a row, focus hours add up all your time."
        case .dailyTarget: "Change your hero's look on this tab any time. The ring fills with your class color as you focus today, slide to set a goal that fits you."
        case .settings: "Sounds, music and notifications are behind the gear. You're all set!"
        }
    }

    /// Popisek tlacitka: vsude Next, posledni krok Finish.
    var buttonTitle: String { self == CoachStep.allCases.last ? "Finish" : "Next" }
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
    @ObservationIgnored private var hostProbes: [UUID: WeakView] = [:]
    /// Zalozka, ktera je prave videt (nastavuje MainTabView). Vyrez kroku se ukaze jen na jeho zalozce (A2).
    var screen: CoachScreen = .home
    /// Zmena rozvrzeni (zalozka, otevreni/zavreni listu, otoceni): overlay vyrez schova a po vykresleni
    /// znovu zmeri, takze nikdy nesedi na starem miste.
    private(set) var layoutVersion = 0

    func layoutChanged() { layoutVersion &+= 1 }
    /// Next v bubline (K1/D3): kroky, ktere neco otviraji nebo zaviraji (Fight sheet), resi MainTabView;
    /// ostatni se jen posunou. Prepnuti zalozky udela MainTabView podle `screen` noveho kroku.
    @ObservationIgnored var performNext: (@MainActor (CoachStep) -> Void)?
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

    /// K1/D2: overlay je ve vlastnim okne nad vsemi listy, proto ramecky prvku jsou v souradnicich okna
    /// (UIKit), ne v `.global` SwiftUI (v listu muze byt `.global` vztazene k listu). Kazdy hostitel
    /// posle ramecky ve svem lokalnim prostoru a malou UIKit sondu, ktera je prevede do okna.
    func updateFrames(_ rects: [CoachTarget: CGRect], host: UUID) {
        guard hostFrames[host] != rects else { return }
        hostFrames[host] = rects
        refreshFrames()
    }

    func attachProbe(_ view: UIView, host: UUID) {
        hostProbes[host] = WeakView(view: view)
        refreshFrames()
    }

    func removeHost(_ host: UUID) {
        hostProbes.removeValue(forKey: host)
        guard hostFrames.removeValue(forKey: host) != nil else { return }
        refreshFrames()
    }

    /// Prepocet do souradnic okna. Overlay ho vola i pred ukazanim kroku, protoze list nebo zalozka
    /// se mohly mezitim posunout animaci (sonda o tom nedostane zpravu).
    func refreshFrames() {
        var merged: [CoachTarget: CGRect] = [:]
        for (host, rects) in hostFrames {
            guard let probe = hostProbes[host]?.view, probe.window != nil else { continue }
            for (target, rect) in rects { merged[target] = probe.convert(rect, to: nil) }
        }
        if merged != frames { frames = merged }
    }
}

private struct WeakView {
    weak var view: UIView?
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
                // Ramecky v lokalnim prostoru hostitele; sonda vyplnuje presne tentyz prostor.
                let rects = anchors.mapValues { proxy[$0] }
                CoachWindowProbe { view in coach?.attachProbe(view, host: id) }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .onAppear { coach?.updateFrames(rects, host: id) }
                    .onChange(of: rects) { _, new in coach?.updateFrames(new, host: id) }
                    .onDisappear { coach?.removeHost(id) }
            }
        }
    }
}

/// Neviditelny UIView v miste hostitele: umi prevest lokalni ramecek do souradnic okna.
private struct CoachWindowProbe: UIViewRepresentable {
    let onWindow: (UIView) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onWindow = onWindow
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.onWindow = onWindow
    }

    final class ProbeView: UIView {
        var onWindow: ((UIView) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { onWindow?(self) }
        }
    }
}

// MARK: - Vlastni okno

/// K1/D2: overlay tutorialu ve vlastnim UIWindow nad hlavnim oknem, takze ho zadny list (Fight sheet)
/// neprekryje ani neposune a "Skip tutorial" je vzdy na stejnem miste. Okno je videt jen behem tutorialu
/// a pohlcuje vsechna klepnuti (zvyraznene prvky nejsou interaktivni, D3); projdou jen Next a Skip.
struct CoachOverlayWindow: UIViewRepresentable {
    let coach: CoachMarkStore
    let isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.isUserInteractionEnabled = false
        view.onWindow = { [weak coordinator = context.coordinator] scene in coordinator?.install(in: scene, coach: coach) }
        return view
    }

    func updateUIView(_ view: AnchorView, context: Context) {
        context.coordinator.setActive(isActive)
    }

    static func dismantleUIView(_ view: AnchorView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    final class AnchorView: UIView {
        var onWindow: ((UIWindowScene) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene { onWindow?(scene) }
        }
    }

    @MainActor
    final class Coordinator {
        private var window: UIWindow?
        private var isActive = false
        private var hideTask: Task<Void, Never>?

        func install(in scene: UIWindowScene, coach: CoachMarkStore) {
            guard window == nil else { return }
            let host = UIHostingController(rootView: CoachMarkOverlay().environment(coach))
            host.view.backgroundColor = .clear
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .normal + 5
            window.backgroundColor = .clear
            window.overrideUserInterfaceStyle = .dark
            window.rootViewController = host
            window.isHidden = !isActive
            self.window = window
        }

        func setActive(_ active: Bool) {
            guard active != isActive else { return }
            isActive = active
            hideTask?.cancel()
            if active {
                window?.isHidden = false
            } else {
                // Overlay nejdriv prolne do ztracena, pak se okno schova.
                hideTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(320))
                    guard !Task.isCancelled, let self, !self.isActive else { return }
                    self.window?.isHidden = true
                }
            }
        }

        func tearDown() {
            hideTask?.cancel()
            window?.isHidden = true
            window = nil
        }
    }
}

// MARK: - Overlay

/// Ztmaveni s vyrezem, zare, bublina a "Skip tutorial". Od K1 je jediny a kresli se ve vlastnim okne
/// (`CoachOverlayWindow`) nad hlavni obrazovkou i Fight sheetem. Krok se ukaze az po ustaleni (prechod
/// zalozky, otevreni listu) a az je cilovy prvek vykresleny; kdyz se do ~2 s nenajde, tise se preskoci.
struct CoachMarkOverlay: View {
    /// Vyska pasu pro "Skip tutorial" pod horni bezpecnou zonou. Bublina do nej nikdy nezasahne
    /// a obsah zalozek se behem tutorialu odsune pod nej (`tutorialTopReserve`), takze Skip nic neprekryje.
    static let skipBand: CGFloat = 56

    @Environment(CoachMarkStore.self) private var coach
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    /// Krok, jehoz prvek je zmereny a vyrez je videt.
    @State private var shown: CoachStep?
    @AccessibilityFocusState private var bubbleFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size)
            let skipBottom = proxy.safeAreaInsets.top + Self.skipBand
            let hole = currentHole(in: bounds)
            ZStack(alignment: .topLeading) {
                if coach.step != nil {
                    // Jedna stala vrstva: mezi kroky je vyrez zavreny do bodu u dalsiho prvku a pri ukazani
                    // kroku se z nej pruzne otevre. Klepnuti kamkoli (i do vyrezu) se zahodi: zvyraznene
                    // prvky nejsou interaktivni (D3), projde jen Next a Skip.
                    CoachDimShape(hole: hole.rect, radius: hole.radius)
                        .fill(Color.black.opacity(0.72), style: FillStyle(eoFill: true))
                        .contentShape(Rectangle())
                        .onTapGesture { }
                        .accessibilityHidden(true)
                        .transition(.opacity)
                    if let step = shown, hole.rect.width > 0 {
                        CoachGlow(rect: hole.rect, radius: hole.radius, pulsing: !reduceMotion)
                            .transition(.opacity)
                        bubble(step: step, hole: hole.rect, bounds: bounds, skipBottom: skipBottom)
                    }
                    skipButton
                        .padding(.top, proxy.safeAreaInsets.top + 6)
                        .padding(.leading, max(proxy.safeAreaInsets.leading, FQSpace.lg))
                }
            }
            .frame(width: bounds.width, height: bounds.height)
        }
        .ignoresSafeArea()
        // VoiceOver cte jen bublinu a Skip, ne obrazovku pod ztmavenim.
        .accessibilityAddTraits(coach.step != nil ? .isModal : [])
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

    /// Vyrez ukazaneho kroku; jinak bod (nulova velikost) uprostred prvku, na ktery se ceka.
    private func currentHole(in bounds: CGRect) -> CoachHole {
        if let step = shown, let frame = coach.frames[step.target] {
            return Self.hole(for: frame, target: step.target)
        }
        let center = coach.step.flatMap { coach.frames[$0.target] }.map { CGPoint(x: $0.midX, y: $0.midY) }
            ?? CGPoint(x: bounds.midX, y: bounds.midY)
        return CoachHole(rect: CGRect(origin: center, size: .zero), radius: 0)
    }

    private func bubble(step: CoachStep, hole: CGRect, bounds: CGRect, skipBottom: CGFloat) -> some View {
        // Nad prvkem se pocita jen misto pod pasem Skip: bublina nikdy nezajede pod Skip.
        let spaceAbove = hole.minY - skipBottom
        let below = bounds.maxY - hole.maxY >= spaceAbove
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
            HStack {
                Spacer()
                Button { next(step) } label: {
                    Text(step.buttonTitle)
                        .fqFont(size: 16, weight: .heavy, design: .rounded)
                        .foregroundStyle(FQColor.onCta)
                        .padding(.horizontal, FQSpace.xl)
                        .frame(minHeight: 44)
                        .background(FQColor.cta, in: Capsule())
                }
                .buttonStyle(.fqPress)
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
        // Bublina pod prvkem, kdyz je tam vic mista, jinak nad nim (ale pod pasem Skip);
        // vodorovne u prvku, ale cela na obrazovce.
        .offset(x: min(max(hole.midX, width / 2 + FQSpace.lg), bounds.width - width / 2 - FQSpace.lg) - bounds.width / 2)
        .padding(below ? Edge.Set.top : Edge.Set.bottom, below ? max(hole.maxY + FQSpace.md, skipBottom) : bounds.height - hole.minY + FQSpace.md)
        .padding(.top, below ? 0 : skipBottom)
        .frame(width: bounds.width, height: bounds.height, alignment: below ? .top : .bottom)
    }

    /// D2: samostatna pilulka vlevo nahore v bezpecne zone, vzdy na stejnem miste ve vsech krocich,
    /// i kdyz je otevreny Fight sheet (overlay je ve vlastnim okne nad nim). Plne pozadi a stin.
    private var skipButton: some View {
        let ink = Color(red: 10 / 255, green: 9 / 255, blue: 20 / 255)
        return Button { withAnimation(.easeOut(duration: 0.25)) { coach.skipTutorial() } } label: {
            Text("Skip tutorial")
                .fqFont(size: 15, weight: .semibold, design: .rounded)
                .foregroundStyle(FQColor.textPrimary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, FQSpace.lg)
                .frame(height: 40)
                .background(ink.opacity(0.94), in: Capsule())
                .overlay { Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1) }
                .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                .frame(minHeight: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.fqPress)
    }

    // MARK: Logika

    private func next(_ step: CoachStep) {
        guard step == coach.step else { return }
        if let performNext = coach.performNext {
            performNext(step)
        } else {
            withAnimation(.easeOut(duration: 0.2)) { coach.advance(from: step) }
        }
    }

    /// Ceka, az se prvek kroku zmeri a obrazovka se ustali; pak vyrez ukaze. Nenalezeny prvek = krok se preskoci.
    private func resolve() async {
        guard let step = coach.step else {
            withAnimation(.easeOut(duration: 0.2)) { shown = nil }
            return
        }
        // Jina zalozka, nez krok potrebuje (MainTabView ji prave prepina), nebo zmena rozvrzeni:
        // stary vyrez hned pryc, aby nesedel na prazdnem miste.
        if let screen = step.screen, screen != coach.screen {
            withAnimation(.easeOut(duration: 0.15)) { shown = nil }
            return
        }
        if shown != nil {
            withAnimation(.easeOut(duration: 0.15)) { shown = nil }
        }
        // Prechod zalozky, otevreni nebo zavreni listu: pockat, at vyrez nesedi na pohybujicim se prvku.
        try? await Task.sleep(for: .milliseconds(step.isInFightSheet ? 600 : 480))
        var lastFrame: CGRect?
        for _ in 0..<14 {
            guard !Task.isCancelled else { return }
            if let screen = step.screen, screen != coach.screen { return }
            coach.refreshFrames()
            if let frame = coach.frames[step.target], frame.width > 1, frame.height > 1 {
                // Prvek musi stat: dve mereni po sobe na stejnem miste (list nebo zalozka dojela).
                if let lastFrame, abs(lastFrame.minY - frame.minY) < 1, abs(lastFrame.minX - frame.minX) < 1 {
                    if reduceMotion {
                        withAnimation(.easeIn(duration: 0.2)) { shown = step }
                    } else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { shown = step }
                    }
                    try? await Task.sleep(for: .milliseconds(250))
                    bubbleFocused = true
                    return
                }
                lastFrame = frame
            }
            try? await Task.sleep(for: .milliseconds(140))
        }
        guard !Task.isCancelled else { return }
        // Prvek neni (napr. vsechny svety dobyte, Fight chybi): krok se tise preskoci, appka nezamrzne.
        // Fight a battle otviraji a zaviraji list, proto jdou pres MainTabView jako Next.
        if let performNext = coach.performNext, step == .fight || step == .battle {
            performNext(step)
        } else {
            coach.advance(from: step)
        }
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
