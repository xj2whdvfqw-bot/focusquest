import SwiftUI

// Spolecne animace a mikroanimace. Vsechno kratke (0,2–0,35 s), aby appka nepusobila pomalu.
// S Reduce Motion jen prolnuti nebo nic (zadne zmenseni, posun ani pruzina).

enum FQMotion {
    /// Rychla zmena stavu (vyber, prepinac).
    static var quick: Animation { .easeOut(duration: 0.2) }
    /// Pruzina pro objeveni oken a presun zvyrazneni (kratka, bez prekmitu do strany).
    static var pop: Animation { .spring(response: 0.32, dampingFraction: 0.82) }

    /// Pruzina, nebo s Reduce Motion jen kratke prolnuti.
    static func spring(reduceMotion: Bool) -> Animation { reduceMotion ? quick : pop }
}

/// Spolecny styl vsech tlacitek appky: pri stisku se jemne zmensi (0,97) a malinko ztmavne
/// (s Reduce Motion jen ztmavne) a FQFeedback prehraje klik a jemnou vibraci
/// (podle prepinacu Tap sounds a Haptics v Nastaveni).
struct FQPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration, scale: scale)
    }

    private struct PressBody: View {
        let configuration: ButtonStyleConfiguration
        let scale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
                .opacity(configuration.isPressed ? 0.88 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
                .modifier(TapFeedback(isPressed: configuration.isPressed))
        }
    }
}

/// Klik a vibrace v okamziku dotyku tlacitka (jako klavesnice iOS). Pouzivaji ho vsechny styly tlacitek.
struct TapFeedback: ViewModifier {
    let isPressed: Bool
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.onChange(of: isPressed) { _, pressed in
            if pressed && isEnabled { FQFeedback.shared.tap() }
        }
    }
}

extension ButtonStyle where Self == FQPressStyle {
    /// Tlacitko bez systemoveho vzhledu, ktere se pri stisku jemne zmensi.
    static var fqPress: FQPressStyle { FQPressStyle() }
}

/// Vysledkove okno (utek bosse, vitezstvi, chyba, konec hovoru): jemne ztmaveni sceny
/// a sklenena karta uprostred. Karta se objevi s pruzinou (0,92 → 1), s Reduce Motion jen prolnutim.
struct ResultDialog<Content: View>: View {
    /// Ztmaveni sceny za kartou; jemne, aby bylo videt, kde hrac je.
    static var dim: Double { 0.28 }

    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(Self.dim)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            content()
                .padding(FQSpace.xl)
                .frame(maxWidth: 360)
                .glassCard(radius: FQRadius.dialog)
                .padding(.horizontal, FQSpace.xl)
                .scaleEffect(shown || reduceMotion ? 1 : 0.92)
                .opacity(shown ? 1 : 0)
        }
        .accessibilityAddTraits(.isModal)
        .onAppear { withAnimation(FQMotion.spring(reduceMotion: reduceMotion)) { shown = true } }
    }
}

// MARK: - Prechod mezi zalozkami

/// Stav prepinani zalozek, ktery MainTabView posila obrazovkam (ScreenScaffold).
struct TabMotion: Equatable {
    /// Zvysi se pri kazdem prepnuti zalozky (spousti prechod obsahu).
    var switches = 0
    /// +1 = nova zalozka je vpravo (obsah prijede zprava), -1 = vlevo.
    var direction: CGFloat = 1
    /// Jak daleko hrac prave tahne obsah prstem (vodorovny swipe mezi zalozkami).
    var drag: CGFloat = 0
}

private struct TabMotionKey: EnvironmentKey {
    static let defaultValue = TabMotion()
}

extension EnvironmentValues {
    var fqTabMotion: TabMotion {
        get { self[TabMotionKey.self] }
        set { self[TabMotionKey.self] = newValue }
    }
}

/// Swipe mezi zalozkami nesmi prebit vnitrni vodorovna gesta (posuvnik denniho cile).
/// Ovladaci prvek si ho behem tazeni zamkne.
@MainActor
enum TabSwipeLock {
    static var isLocked = false
    /// Na zalozce Path je mapa: vodorovny tah ji posouva, ne prepina zalozky.
    static var isMapVisible = false
}

/// Obsah nove zalozky vyjede ve smeru poradi zalozek (o 48 bodu) a prolne se, 0,3 s s pruzinou.
/// Behem tazeni prstem jde obsah s prstem. Pozadi (krajina) stoji, hybe se jen obsah.
/// S Reduce Motion jen prolnuti, zadny posun.
struct TabSwitchEntrance: ViewModifier {
    @Environment(\.fqTabMotion) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let travel: CGFloat = reduceMotion ? 0 : 48 * motion.direction
        content
            .offset(x: reduceMotion ? 0 : motion.drag)
            .keyframeAnimator(initialValue: 1.0, trigger: motion.switches) { view, progress in
                view
                    .opacity(0.25 + 0.75 * progress)
                    .offset(x: (1 - progress) * travel)
            } keyframes: { _ in
                KeyframeTrack {
                    MoveKeyframe(0.0)
                    SpringKeyframe(1.0, duration: 0.3, spring: .snappy)
                }
            }
    }
}
