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

/// Tlacitko se pri stisku jemne zmenši (0,96) a malinko ztmavne. S Reduce Motion jen ztmavne.
struct FQPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96

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

private struct TabSwitchKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    /// Zvysi se pri kazdem prepnuti zalozky; obsah obrazovky (ScreenScaffold) se pak plynule objevi.
    var fqTabSwitch: Int {
        get { self[TabSwitchKey.self] }
        set { self[TabSwitchKey.self] = newValue }
    }
}

/// Obsah nove zalozky se prolne (0 → 1) a jemne vyjede o 10 bodu zdola, 0,25 s.
/// Pozadi (krajina) stoji, hybe se jen obsah. S Reduce Motion jen prolnuti.
struct TabSwitchEntrance: ViewModifier {
    @Environment(\.fqTabSwitch) private var trigger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, progress in
            view
                .opacity(progress)
                .offset(y: reduceMotion ? 0 : (1 - progress) * 10)
        } keyframes: { _ in
            KeyframeTrack {
                MoveKeyframe(0.0)
                CubicKeyframe(1.0, duration: 0.25)
            }
        }
    }
}
