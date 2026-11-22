import SwiftUI

// Sklenene povrchy. Dve vrstvy, stejne jako v systemovych appkach:
//  - obsah (karty) = matne sklo s jemnou hranou,
//  - ovladani (tlacitka, stitky, tab bar) = Liquid Glass na iOS 26+, na starsich iOS material.
// Vsechno, co pouziva API z iOS 26, je jen v tomhle souboru.

extension View {
    /// Karta s obsahem: tmave matne sklo (rozmazani + FQColor.card) a mekky stin.
    /// `prominent` = hustsi sklo (.regularMaterial) pro dialogy a vysledky bitvy.
    func glassCard(radius: CGFloat = FQRadius.card, tint: Color? = nil, prominent: Bool = false) -> some View {
        modifier(GlassCardModifier(radius: radius, tint: tint, prominent: prominent))
    }

    /// Ovladaci prvek ve tvaru `shape`. Na iOS 26+ skutecny Liquid Glass.
    func glassControl<S: InsettableShape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassControlModifier(shape: shape, tint: tint, interactive: interactive))
    }

    /// Hlavni akce na obrazovce (vyplnene sklo v akcentove barve). Klik a vibrace pres FQFeedback.
    @ViewBuilder func prominentGlassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent).simultaneousGesture(TapGesture().onEnded { FQFeedback.shared.tap() })
        } else {
            buttonStyle(.borderedProminent).simultaneousGesture(TapGesture().onEnded { FQFeedback.shared.tap() })
        }
    }

    /// Hlavni akce pripnuta ke spodnimu okraji. Obsah, ktery pod ni odroluje,
    /// se plynule rozmaze do ztracena, misto aby byl ostre useknuty.
    /// Matny prechod je pod tlacitkem na vsech iOS: samotny scroll edge effect z iOS 26
    /// je nad pixelovou krajinou skoro neviditelny a karty pak presvitaly kolem tlacitka.
    /// Bar zaroven odsadi obsah, takze posledni karta jde vzdy odrolovat nad tlacitko.
    @ViewBuilder func pinnedBottomAction<Action: View>(@ViewBuilder _ action: () -> Action) -> some View {
        let bar = action()
            .frame(maxWidth: 640)
            .padding(.horizontal, FQSpace.lg)
            .padding(.top, FQSpace.xl)
            .padding(.bottom, FQSpace.sm)
            .frame(maxWidth: .infinity)
            .background { ScrollFadeBackground() }
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: .bottom, spacing: 0) { bar }
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) { bar }
        }
    }

    /// Hlavicka pripnuta k hornimu okraji; obsah pod ni roluje a rozmaze se.
    /// Prechod do pruhledna pod hlavickou je soucasti odsazeni obsahu: na zacatku je obsah cely
    /// pod nim (nic nepodjizdi), pri rolovani pod nim plynule mizi.
    @ViewBuilder func pinnedTopHeader<Header: View>(@ViewBuilder _ header: () -> Header) -> some View {
        let bar = header()
            .frame(maxWidth: 640)
            .padding(.horizontal, FQSpace.lg)
            .padding(.top, FQSpace.sm)
            .padding(.bottom, FQSpace.sm)
            .frame(maxWidth: .infinity)
            .modifier(BrightTextShadow())
            .padding(.bottom, SoftHeaderBackground.fade)
            .background { SoftHeaderBackground() }
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: .top, spacing: 0) { bar }
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            safeAreaInset(edge: .top, spacing: 0) { bar }
        }
    }

    /// Vedlejsi akce (pruhledne sklo).
    @ViewBuilder func glassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass).simultaneousGesture(TapGesture().onEnded { FQFeedback.shared.tap() })
        } else {
            buttonStyle(.bordered).simultaneousGesture(TapGesture().onEnded { FQFeedback.shared.tap() })
        }
    }
}

struct GlassCardModifier: ViewModifier {
    let radius: CGFloat
    let tint: Color?
    var prominent = false
    @Environment(\.shopBackground) private var shopBackground

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        // Na svetlych pozadich je sklo tmavsi (.78, kvuli kontrastu WCAG AA) a stin vetsi (0 12 30 rgba(0,0,0,.32)).
        let bright = shopBackground?.isBright == true
        // Tmave sklo: rozmazani + rgba(13,11,28,.60). Bez svetle hrany a odlesku, text na nem vynikne.
        return content
            // Vnorena tlacitka a nahledy (FQRadius.shape) maji rohy soustredne s kartou.
            .fqContainer(radius: radius)
            .background {
                ZStack {
                    if prominent { shape.fill(.regularMaterial) } else { shape.fill(.ultraThinMaterial) }
                    shape.fill(bright ? FQColor.cardOnBright : FQColor.card)
                    if let tint { shape.fill(tint.opacity(0.22)) }
                }
            }
            .shadow(color: Color.black.opacity(bright ? 0.32 : 0.24), radius: bright ? 15 : 12, y: 12)
    }
}

/// Rozmazany prechod pod pripnutou listou: u obsahu pruhledny, u okraje obrazovky plny material.
/// Pozadi pripnute hlavicky bez ostre hrany: tmave rozmazane sklo sahá az pod stavovy radek
/// a ve spodnich 24 pt (`fade`, uz zapocitanych ve vysce listy) plynule mizi do pruhledna.
/// Driv prechod presahoval 60 pt pod listu a zakryval nadpis prvni sekce.
private struct SoftHeaderBackground: View {
    static let fade: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let total = proxy.size.height
            let solid = max(0, (total - Self.fade) / max(1, total))
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(red: 9 / 255, green: 8 / 255, blue: 24 / 255).opacity(0.62)
            }
            .frame(height: total)
            .mask {
                LinearGradient(
                    stops: [.init(color: .black, location: 0), .init(color: .black, location: solid), .init(color: .clear, location: 1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

private struct ScrollFadeBackground: View {
    var edge: VerticalEdge = .bottom

    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .mask {
                LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3)],
                    startPoint: edge == .bottom ? .top : .bottom,
                    endPoint: edge == .bottom ? .bottom : .top
                )
            }
            .ignoresSafeArea(edges: edge == .bottom ? .bottom : .top)
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
