import SwiftUI

// Sklenene povrchy. Dve vrstvy, stejne jako v systemovych appkach:
//  - obsah (karty) = matne sklo s jemnou hranou,
//  - ovladani (tlacitka, stitky, tab bar) = Liquid Glass na iOS 26+, na starsich iOS material.
// Vsechno, co pouziva API z iOS 26, je jen v tomhle souboru.

extension View {
    /// Karta s obsahem: matne sklo, 1px svetelna hrana a mekky stin.
    func glassCard(radius: CGFloat = FQRadius.card, tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(radius: radius, tint: tint))
    }

    /// Ovladaci prvek ve tvaru `shape`. Na iOS 26+ skutecny Liquid Glass.
    func glassControl<S: InsettableShape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassControlModifier(shape: shape, tint: tint, interactive: interactive))
    }

    /// Hlavni akce na obrazovce (vyplnene sklo v akcentove barve).
    @ViewBuilder func prominentGlassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// Hlavni akce pripnuta ke spodnimu okraji. Obsah, ktery pod ni odroluje,
    /// se plynule rozmaze do ztracena, misto aby byl ostre useknuty.
    /// Na iOS 26+ to dela system (scroll edge effect pod `safeAreaBar`),
    /// na starsich iOS vlastni rozmazany prechod.
    @ViewBuilder func pinnedBottomAction<Action: View>(@ViewBuilder _ action: () -> Action) -> some View {
        let bar = action()
            .frame(maxWidth: 640)
            .padding(.horizontal, FQSpace.lg)
            .padding(.top, FQSpace.xl)
            .padding(.bottom, FQSpace.sm)
            .frame(maxWidth: .infinity)
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: .bottom, spacing: 0) { bar }
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) {
                bar.background { ScrollFadeBackground() }
            }
        }
    }

    /// Vedlejsi akce (pruhledne sklo).
    @ViewBuilder func glassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}

struct GlassCardModifier: ViewModifier {
    let radius: CGFloat
    let tint: Color?
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        // Ve svetlem rezimu je sklo mlecne bile, v tmavem jen lehce prosvetlene.
        let isDark = colorScheme == .dark
        return content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill((tint ?? Color.white).opacity(tint == nil ? (isDark ? 0.04 : 0.36) : 0.18))
                    // Odlesk shora - dodava skleneny dojem bez tvrdych stinu.
                    shape.fill(LinearGradient(colors: [Color.white.opacity(isDark ? 0.10 : 0.45), Color.white.opacity(0)], startPoint: .top, endPoint: .center))
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(isDark ? 0.32 : 0.95), Color.white.opacity(isDark ? 0.08 : 0.50), Color.white.opacity(isDark ? 0.14 : 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
            }
            .shadow(color: isDark ? Color.black.opacity(0.18) : Color(red: 0.20, green: 0.24, blue: 0.45).opacity(0.14), radius: 16, y: 8)
    }
}

/// Rozmazany prechod pod pripnutou akci: nahore pruhledny, dole plny material.
private struct ScrollFadeBackground: View {
    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .mask {
                LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
    }
}

struct GlassControlModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(liquidGlass, in: shape)
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(.thinMaterial)
                        shape.fill((tint ?? Color.white).opacity(tint == nil ? 0.04 : 0.22))
                    }
                }
                .overlay { shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1) }
        }
    }

    @available(iOS 26.0, *)
    private var liquidGlass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}
