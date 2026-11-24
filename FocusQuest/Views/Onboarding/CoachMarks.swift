import SwiftUI
import UIKit

// Tutorial v appce (F2, 1B): coach marks misto TipKitu. Cela obrazovka ztmavne, zvyrazneny prvek je
// z tmy "vyrizly" (zaobleny vyrez s jemnou pulzujici zari) a vedle je bublina s textem.
// Pozice prvku se zjistuje pres anchorPreference (`.coachMark(_:)`), nikdy natvrdo:
// hostitel (`.coachMarkHost()`) kotvy prevede na ramecky v souradnicich okna a ulozi je do CoachMarkStore.
// Pres hranici TabView preference nemusi projit, proto ma kazda zalozka a lista vlastniho hostitele.
// L1/E1: tutorial nikdy neotvira listy. Kroky o Fight sheetu (Focusing, Sound, Phone down) stoji na Home
// s vyrezem na tlacitku Fight a text popise, co v listu hrac najde.

/// Prvky, ktere tutorial umi zvyraznit.
enum CoachTarget: String, Hashable, Sendable {
    case fight, quick, streak, tabPath, tabShop, tabStats, tabHero, gear
    /// A4: graf Habits, karta s cisly ve Stats a Daily focus target v Hero.
    case habits, statNumbers, dailyTarget

    /// Kulate a kapslove prvky maji kulaty vyrez, karty zaobleny obdelnik.
    var isRound: Bool {
        switch self {
        case .habits, .statNumbers, .dailyTarget: false
        default: true
        }
    }

    /// Ikony v liste zalozek jsou videt na kazde zalozce, takze vyrez na ne muze jet hned,
    /// jeste behem prepnuti zalozky (E3).
    var isInTabBar: Bool {
        switch self {
        case .tabPath, .tabShop, .tabStats, .tabHero: true
        default: false
        }
    }
}

/// Zalozka, na ktere krok tutorialu stoji (A2).
enum CoachScreen: Sendable {
    case home, path, shop, stats, hero
}

/// Kroky tutorialu v poradi, jak appku hrac poprve pouzije.
/// K1/D3: kazdy krok se posune jen tlacitkem Next (posledni Finish). Zvyraznene prvky nejsou interaktivni.
/// L1/E1: zadny krok neotvira list; kazdy stoji na sve zalozce a zalozku prepina tutorial sam.
enum CoachStep: Int, CaseIterable, Sendable {
    case fight, focusing, sound, battle, quick, streak, path, shop, stats, habits, statNumbers, dailyTarget, settings

    /// Pocet kroku pro hrace.
    static let total = CoachStep.allCases.count

    /// Cislo kroku pro hrace ("3 of 13").
    var number: Int { rawValue + 1 }

    var target: CoachTarget {
        switch self {
        // E1: kroky o Fight sheetu ukazuji tlacitko Fight na Home, list se neotvira.
        case .fight, .focusing, .sound, .battle: .fight
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

    /// Zalozka, na ktere krok stoji. Po Next ji tutorial prepne sam ve stejne animaci jako bublinu (E3).
    var screen: CoachScreen {
        switch self {
        case .fight, .focusing, .sound, .battle, .quick, .streak: .home
        case .path: .path
        case .shop: .shop
        case .stats, .habits, .statNumbers: .stats
        case .dailyTarget, .settings: .hero
        }
    }

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
        case .focusing: "In that setup you pick what the session is for. Stats tracks your time for each one."
        case .sound: "You also pick music or quiet there. It keeps playing when the screen is locked."
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
/// tutorial pokracuje od posledniho kroku.
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
    /// Zmerene ramecky prvku (souradnice okna) od vsech hostitelu.
    private(set) var frames: [CoachTarget: CGRect] = [:]
    @ObservationIgnored private var hostFrames: [UUID: [CoachTarget: CGRect]] = [:]
    @ObservationIgnored private var hostProbes: [UUID: WeakView] = [:]
    /// Zalozka, ktera je prave videt (nastavuje MainTabView). Vyrez kroku sedi jen na jeho zalozce (A2).
    var screen: CoachScreen = .home
    /// Next v bubline: MainTabView posune krok a prepne zalozku ve stejne animaci (E3).
    @ObservationIgnored var performNext: (@MainActor (CoachStep) -> Void)?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        onboardingDone = defaults.bool(forKey: Keys.onboardingDone)
        step = (defaults.object(forKey: Keys.tutorialStep) as? Int).flatMap(CoachStep.init(rawValue:))
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

    /// Posun o jeden krok, jen kdyz krok jeste plati (dvojite klepnuti ho neposune dvakrat).
    /// E1: kroky se nikdy nepreskakuji; preskocit jde jen celym tutorialem pres Skip.
    func advance(from current: CoachStep) {
        guard step == current else { return }
        set(CoachStep(rawValue: current.rawValue + 1))
    }

    /// Tlacitko Next (posledni krok Finish) v bubline.
    func next(from current: CoachStep) {
        guard step == current else { return }
        if let performNext {
            performNext(current)
        } else {
            advance(from: current)
        }
    }

    func skipTutorial() { set(nil) }

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

    /// K1/D2: overlay je ve vlastnim okne nad hlavnim oknem, proto ramecky prvku jsou v souradnicich okna
    /// (UIKit), ne v `.global` SwiftUI. Kazdy hostitel posle ramecky ve svem lokalnim prostoru a malou
    /// UIKit sondu, ktera je prevede do okna.
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

    /// Prepocet do souradnic okna. Overlay ho vola pravidelne, dokud tutorial bezi: zalozka nebo scroll
    /// se mohly posunout a sonda o tom zpravu nedostane. Hostitel mimo okno (skryta zalozka) se vynecha.
    func refreshFrames() {
        guard !framesFixedForTesting else { return }
        var merged: [CoachTarget: CGRect] = [:]
        for (host, rects) in hostFrames {
            guard let probe = hostProbes[host]?.view, probe.window != nil else { continue }
            for (target, rect) in rects { merged[target] = probe.convert(rect, to: nil) }
        }
        if merged != frames { frames = merged }
    }

    /// Jen pro testy: ramecky prvku bez UIKit sond (sledovani v overlayi je pak neprepise).
    func setFramesForTesting(_ rects: [CoachTarget: CGRect]) {
        framesFixedForTesting = true
        frames = rects
    }
    @ObservationIgnored private var framesFixedForTesting = false
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
    /// Prvek, ktery tutorial muze zvyraznit. `id` dovoli obrazovce s rolovanim prvek odrolovat do zorneho pole.
    func coachMark(_ target: CoachTarget) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { [target: $0] }
            .id(target)
    }

    /// Prevede kotvy prvku pod sebou na ramecky pro tutorial.
    func coachMarkHost() -> some View { modifier(CoachMarkHost()) }

    /// E2: nadpis vlevo nahore uhne behem tutorialu dolu pod "Skip tutorial". Ozubene kolo vpravo zustava,
    /// Skip stoji ve stejne vysce jako ono.
    func coachSkipClearance() -> some View { modifier(CoachSkipClearanceModifier()) }
}

private struct CoachSkipClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// E2: o kolik nadpis zalozky uhne dolu, dokud bezi tutorial (jinak 0).
    var coachSkipClearance: CGFloat {
        get { self[CoachSkipClearanceKey.self] }
        set { self[CoachSkipClearanceKey.self] = newValue }
    }
}

private struct CoachSkipClearanceModifier: ViewModifier {
    @Environment(\.coachSkipClearance) private var clearance

    func body(content: Content) -> some View {
        content
            .padding(.top, clearance)
            .animation(.easeInOut(duration: 0.3), value: clearance)
    }
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

/// K1/D2: overlay tutorialu ve vlastnim UIWindow nad hlavnim oknem, takze ho nic neprekryje
/// a "Skip tutorial" je vzdy na stejnem miste. Okno je videt jen behem tutorialu
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

// MARK: - Rozvrzeni (ciste vypocty, testuji se)

/// Rozmery overlaye mimo View, aby sly pouzit v cistych vypoctech i v testech.
enum CoachMetrics {
    /// "Skip tutorial" stoji vlevo nahore ve stejne vysce jako ozubene kolo zalozek:
    /// horni hrana 8 bodu pod bezpecnou zonou, vyska 44 (E2).
    static let skipTop: CGFloat = FQSpace.sm
    static let skipRowHeight: CGFloat = 44
    /// O tolik nadpis zalozky behem tutorialu uhne dolu, aby ho Skip neprekryl.
    static let skipClearance: CGFloat = skipRowHeight + FQSpace.sm
    /// Vyrez je o 8 bodu vetsi nez prvek.
    static let holePadding: CGFloat = 8
    /// Mezera mezi vyrezem a bublinou.
    static let bubbleGap: CGFloat = FQSpace.md
    static let bubbleMaxWidth: CGFloat = 340
    /// Odhad vysky bubliny, nez se zmeri.
    static let bubbleEstimate: CGFloat = 168
    /// E1: prvek, ktery se do 1 s nenajde, = bublina uprostred bez vyrezu.
    static let fallbackSeconds: TimeInterval = 1
}

/// Plocha overlaye: cela obrazovka (souradnice okna) a jeji bezpecna zona.
struct CoachSpace: Equatable, Sendable {
    var size: CGSize
    var safeTop: CGFloat
    var safeBottom: CGFloat
    var safeLeading: CGFloat = 0

    /// Spodni hrana radku se "Skip tutorial".
    var skipRowBottom: CGFloat { safeTop + CoachMetrics.skipTop + CoachMetrics.skipRowHeight }
    /// Bublina nikdy nezajede do radku se Skip ani pod domovsky indikator.
    var bubbleTop: CGFloat { skipRowBottom + FQSpace.sm }
    var bubbleBottom: CGFloat { size.height - max(safeBottom, FQSpace.lg) }
    var bubbleWidth: CGFloat { max(0, min(CoachMetrics.bubbleMaxWidth, size.width - 2 * FQSpace.lg)) }

    /// Prvek je zmereny a aspon zcasti na obrazovce pod stavovym radkem.
    func isUsable(_ frame: CGRect) -> Bool {
        frame.width > 1 && frame.height > 1
            && frame.maxY > safeTop + 1 && frame.minY < size.height
            && frame.maxX > 0 && frame.minX < size.width
    }
}

/// Co overlay ukazuje: vyrez (prazdny = bez vyrezu) a obdelnik bubliny.
struct CoachLayout: Equatable, Sendable {
    var hole: CGRect
    var radius: CGFloat
    var bubble: CGRect
    /// Bublina je nad prvkem: drzi spodni hranu (pri prolnuti textu roste nahoru, ne do prvku).
    var bubbleAbove: Bool
    var isCentered: Bool

    var hasHole: Bool { hole.width > 1 && hole.height > 1 }

    enum Resolution: Equatable {
        /// Prvek je zmereny: vyrez a bublina u nej.
        case anchored(CGRect)
        /// Prvek jeste neni (prave se prepina zalozka): bublina zustane, kde je, s novym textem.
        case waiting
        /// E1 pojistka: prvek se do 1 s nenasel (nebo jeste nic neni videt): bublina uprostred bez vyrezu.
        case centered
    }

    /// Bublina je videt vzdy: bez predchoziho rozvrzeni rovnou uprostred, jinak nejdeleji 1 s ceka na prvek.
    static func resolve(frame: CGRect?, elapsed: TimeInterval, hasLayout: Bool) -> Resolution {
        if let frame { return .anchored(frame) }
        if !hasLayout || elapsed >= CoachMetrics.fallbackSeconds { return .centered }
        return .waiting
    }

    /// Vyrez kolem prvku a bublina pod nim (kdyz se tam vejde nebo je tam vic mista), jinak nad nim;
    /// vodorovne u prvku, ale cela na obrazovce.
    static func anchored(to frame: CGRect, target: CoachTarget, bubbleHeight: CGFloat, in space: CoachSpace) -> CoachLayout {
        let hole = frame.insetBy(dx: -CoachMetrics.holePadding, dy: -CoachMetrics.holePadding)
        let radius = target.isRound ? min(hole.width, hole.height) / 2 : 20
        let width = space.bubbleWidth
        let top = space.bubbleTop
        let bottom = space.bubbleBottom
        let room = CoachMetrics.bubbleGap
        let spaceBelow = bottom - hole.maxY - room
        let spaceAbove = hole.minY - room - top
        let below = spaceBelow >= bubbleHeight || spaceBelow >= spaceAbove
        var y = below ? hole.maxY + room : hole.minY - room - bubbleHeight
        y = min(max(y, top), max(top, bottom - bubbleHeight))
        let x = min(max(hole.midX - width / 2, FQSpace.lg), max(FQSpace.lg, space.size.width - FQSpace.lg - width))
        return CoachLayout(hole: hole, radius: radius, bubble: CGRect(x: x, y: y, width: width, height: bubbleHeight),
                           bubbleAbove: !below, isCentered: false)
    }

    /// E1 pojistka: bublina uprostred viditelne plochy, vyrez zavreny do bodu (`closingAt` = stred
    /// predchoziho vyrezu, at se plynule zavre na miste).
    static func centered(bubbleHeight: CGFloat, in space: CoachSpace, closingAt point: CGPoint? = nil) -> CoachLayout {
        let width = space.bubbleWidth
        let middle = (space.bubbleTop + space.bubbleBottom) / 2
        let y = max(space.bubbleTop, middle - bubbleHeight / 2)
        let bubble = CGRect(x: (space.size.width - width) / 2, y: y, width: width, height: bubbleHeight)
        let center = point ?? CGPoint(x: bubble.midX, y: bubble.midY)
        return CoachLayout(hole: CGRect(origin: center, size: .zero), radius: 0, bubble: bubble, bubbleAbove: false, isCentered: true)
    }

    func isClose(to other: CoachLayout) -> Bool {
        isCentered == other.isCentered && bubbleAbove == other.bubbleAbove
            && hole.coachIsClose(to: other.hole) && bubble.coachIsClose(to: other.bubble)
            && abs(radius - other.radius) < 0.5
    }
}

fileprivate extension CGRect {
    func coachIsClose(to other: CGRect, tolerance: CGFloat = 0.5) -> Bool {
        abs(minX - other.minX) < tolerance && abs(minY - other.minY) < tolerance
            && abs(width - other.width) < tolerance && abs(height - other.height) < tolerance
    }

    /// Klic pro prolnuti s Reduce Motion (novy vyrez nebo pozice bubliny = nova vrstva).
    var coachKey: String {
        "\(Int(minX.rounded())),\(Int(minY.rounded())),\(Int(width.rounded())),\(Int(height.rounded()))"
    }
}

// MARK: - Overlay

/// Ztmaveni s vyrezem, zare, bublina a "Skip tutorial". Kresli se ve vlastnim okne (`CoachOverlayWindow`).
/// L1/E3: jedna stala bublina. Po Next se text hned prolne a bublina i vyrez (pozice, velikost, zaobleni)
/// odjedou pruzinou ~0,35 s na novy prvek; zadna prazdna pauza. E1: bublina je videt vzdy, kdyz tutorial bezi;
/// prvek, ktery se do 1 s nenajde, = bublina uprostred bez vyrezu. Reduce Motion: jen prolnuti.
struct CoachMarkOverlay: View {
    @Environment(CoachMarkStore.self) private var coach
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Plocha overlaye zmerena v body (pro sledovani prvku mimo body).
    @State private var space: CoachSpace?
    /// Ukazane rozvrzeni. nil = jeste nic: body pak prvni rozvrzeni spocita samo, takze bublina je videt hned.
    @State private var layout: CoachLayout?
    /// Krok, jehoz text bublina ukazuje (po Next se prolne).
    @State private var shownStep: CoachStep?
    @State private var bubbleHeight: CGFloat = 0
    @AccessibilityFocusState private var bubbleFocused: Bool

    var body: some View {
        // Vnejsi GeometryReader respektuje bezpecnou zonu a zna jeji velikost; vnitrni ji ignoruje a kresli
        // pres celou obrazovku. (GeometryReader s .ignoresSafeArea() hlasi bezpecnou zonu 0: proto byl Skip
        // driv pres hodiny ve stavovem radku.)
        GeometryReader { safe in
            let insets = safe.safeAreaInsets
            GeometryReader { full in
                let current = CoachSpace(size: full.size, safeTop: insets.top, safeBottom: insets.bottom, safeLeading: insets.leading)
                overlay(in: current)
                    .onAppear { space = current }
                    .onChange(of: current) { _, new in space = new }
            }
            .ignoresSafeArea()
        }
        // VoiceOver cte jen bublinu a Skip, ne obrazovku pod ztmavenim.
        .accessibilityAddTraits(coach.step != nil ? .isModal : [])
        .task(id: coach.step) { await track() }
    }

    @ViewBuilder
    private func overlay(in space: CoachSpace) -> some View {
        ZStack(alignment: .topLeading) {
            if let step = coach.step {
                let shown = layout ?? firstLayout(for: step, in: space)
                dim(shown)
                if shown.hasHole { glow(shown) }
                bubble(step: shownStep ?? step, layout: shown, in: space)
                skipButton
                    .padding(.top, space.safeTop + CoachMetrics.skipTop)
                    .padding(.leading, max(space.safeLeading, FQSpace.lg))
                    .transition(.opacity)
            }
        }
        .frame(width: space.size.width, height: space.size.height, alignment: .topLeading)
    }

    // MARK: Vrstvy

    /// Jedna stala vrstva ztmaveni; vyrez se pruzne presouva. Klepnuti kamkoli (i do vyrezu) se zahodi:
    /// zvyraznene prvky nejsou interaktivni (D3), projde jen Next a Skip.
    private func dim(_ layout: CoachLayout) -> some View {
        CoachDimShape(hole: layout.hole, radius: layout.radius)
            .fill(Color.black.opacity(0.72), style: FillStyle(eoFill: true))
            .contentShape(Rectangle())
            .onTapGesture { }
            .accessibilityHidden(true)
            // Reduce Motion: vyrez se nepresouva, stary a novy se prolnou.
            .id(reduceMotion ? AnyHashable(layout.hole.coachKey) : AnyHashable("dim"))
            .transition(.opacity)
    }

    private func glow(_ layout: CoachLayout) -> some View {
        CoachGlow(rect: layout.hole, radius: layout.radius, pulsing: !reduceMotion)
            .id(reduceMotion ? AnyHashable(layout.hole.coachKey) : AnyHashable("glow"))
            .transition(.opacity)
    }

    /// Jedna bublina pro vsechny kroky: obsah (text a Next) se prolne, ramecek odjede na nove misto.
    private func bubble(step: CoachStep, layout: CoachLayout, in space: CoachSpace) -> some View {
        ZStack(alignment: .topLeading) {
            CoachBubbleContent(step: step) { next(step) }
                .id(step)
                .transition(.opacity)
        }
        .frame(width: layout.bubble.width, alignment: .topLeading)
        // Stejne sklo jako vysledky bitvy a karty v Shop › Backgrounds (2B).
        .fqGlassPanel(radius: FQRadius.smallCard)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bubbleHeight = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityFocused($bubbleFocused)
        // Nad prvkem drzi bublina spodni hranu, jinak horni; pri zmene vysky (prolnuti textu) tak
        // nikdy nezajede do vyrezu.
        .offset(x: layout.bubble.minX, y: layout.bubbleAbove ? layout.bubble.maxY - space.size.height : layout.bubble.minY)
        .frame(width: space.size.width, height: space.size.height, alignment: layout.bubbleAbove ? .bottomLeading : .topLeading)
        // Reduce Motion: bublina neodjede, na novem miste se objevi nova a stara zmizi (prolnuti).
        .id(reduceMotion ? AnyHashable("\(step.rawValue)|\(layout.bubble.coachKey)") : AnyHashable("bubble"))
        .transition(.opacity)
    }

    /// E2: samostatna pilulka vlevo nahore v bezpecne zone, ve vysce ozubeneho kola, vzdy na stejnem miste.
    /// Nadpisy zalozek pod ni behem tutorialu uhnou (`coachSkipClearance`), takze nic neprekryva.
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
                .frame(height: CoachMetrics.skipRowHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(.fqPress)
    }

    // MARK: Logika

    private var moveAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.35, dampingFraction: 0.86)
    }

    private func next(_ step: CoachStep) {
        coach.next(from: step)
    }

    /// Prvek kroku, kdyz je zmereny na spravne zalozce (lista zalozek je videt vsude).
    private func visibleFrame(for step: CoachStep, in space: CoachSpace) -> CGRect? {
        guard step.target.isInTabBar || step.screen == coach.screen, let frame = coach.frames[step.target] else { return nil }
        return space.isUsable(frame) ? frame : nil
    }

    private var currentBubbleHeight: CGFloat { bubbleHeight > 0 ? bubbleHeight : CoachMetrics.bubbleEstimate }

    /// Prvni rozvrzeni (pred prvnim merenim v `track`): u prvku, nebo rovnou uprostred.
    private func firstLayout(for step: CoachStep, in space: CoachSpace) -> CoachLayout {
        if let frame = visibleFrame(for: step, in: space) {
            return .anchored(to: frame, target: step.target, bubbleHeight: currentBubbleHeight, in: space)
        }
        return .centered(bubbleHeight: currentBubbleHeight, in: space)
    }

    /// Sleduje prvek aktualniho kroku: text se prolne hned, bublina a vyrez odjedou, jakmile prvek stoji.
    /// Bezi, dokud krok trva, takze vyrez sedi i po odrolovani nebo prijezdu zalozky.
    private func track() async {
        guard let step = coach.step else {
            withAnimation(.easeOut(duration: 0.25)) { shownStep = nil }
            layout = nil
            return
        }
        withAnimation(.easeInOut(duration: 0.22)) { shownStep = step }
        let started = Date()
        var lastFrame: CGRect?
        var focused = false
        while !Task.isCancelled {
            if let space {
                coach.refreshFrames()
                let frame = visibleFrame(for: step, in: space)
                let elapsed = Date().timeIntervalSince(started)
                switch CoachLayout.resolve(frame: frame, elapsed: elapsed, hasLayout: layout != nil) {
                case let .anchored(found):
                    // Prvek musi stat: dve mereni po sobe na stejnem miste (zalozka nebo scroll dojely),
                    // at vyrez nehoni prijizdejici obsah. Prvni ukazani bez cekani.
                    if layout == nil || lastFrame.map({ $0.coachIsClose(to: found, tolerance: 1) }) == true {
                        apply(.anchored(to: found, target: step.target, bubbleHeight: currentBubbleHeight, in: space))
                    }
                    lastFrame = found
                case .waiting:
                    lastFrame = nil
                case .centered:
                    lastFrame = nil
                    let closing = layout.map { CGPoint(x: $0.hole.midX, y: $0.hole.midY) }
                    apply(.centered(bubbleHeight: currentBubbleHeight, in: space, closingAt: closing))
                }
                if !focused, elapsed > 0.3 {
                    focused = true
                    bubbleFocused = true
                }
                try? await Task.sleep(for: .milliseconds(elapsed < 1.5 ? 50 : 150))
            } else {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func apply(_ new: CoachLayout) {
        if let layout, layout.isClose(to: new) { return }
        withAnimation(moveAnimation) { layout = new }
    }
}

/// Obsah bubliny jednoho kroku: titulek, "3 of 13", nejvys dve vety a Next (posledni Finish).
struct CoachBubbleContent: View {
    let step: CoachStep
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FQSpace.sm) {
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
                Button(action: onNext) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Cela plocha minus zaobleny vyrez (vyplnuje se pravidlem even-odd). Vyrez animuje pozici, velikost i zaobleni.
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
        if hole.width > 0, hole.height > 0 {
            let corner = min(radius, hole.width / 2, hole.height / 2)
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: corner, height: corner), style: .continuous)
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
