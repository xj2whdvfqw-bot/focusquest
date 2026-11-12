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

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill((tint ?? Color.white).opacity(tint == nil ? 0.04 : 0.18))
                    // Odlesk shora - dodava skleneny dojem bez tvrdych stinu.
                    shape.fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0)], startPoint: .top, endPoint: .center))
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.32), Color.white.opacity(0.08), Color.white.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)
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
