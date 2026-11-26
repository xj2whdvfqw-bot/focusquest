import SwiftUI

extension Color {
    init(rgb: RGB) { self.init(red: rgb.red, green: rgb.green, blue: rgb.blue) }
}

/// Hrdina slozeny z prekryvajicich se vrstev (kuze, obleceni, vlasy...).
/// Az budou hotove skutecne assety a vybaveni, staci vymenit vrstvy v `AvatarSprite`.
struct HeroAvatarView: View {
    let appearance: AvatarAppearance
    let heroClass: HeroClass
    var size: CGFloat = 112
    /// S1/M1, N1: tenky obrys (1 pt) a jemny stin v bodech obrazovky, aby se hrdina neztracel na svetlem pozadi.
    /// Od N1 vsude (stanek, Hero tab, onboarding, mapa, bitva), jen sdileci karty ho vypinaji.
    var outlined = true

    var body: some View {
        let layers = AvatarSprite.layers(for: appearance, heroClass: heroClass)
        PixelLayerStack(layers: layers)
            .frame(width: size, height: size)
            .spriteOutline(enabled: outlined)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your hero, \(heroClass.displayName)")
    }
}

/// Vykresli vrstvy pixel artu pres sebe; kazda vrstva je jedna barva.
struct PixelLayerStack: View {
    let layers: [AvatarLayer]

    var body: some View {
        ZStack {
            ForEach(layers) { layer in
                PixelLayerShape(rows: layer.rows, symbol: "#").fill(Color(rgb: layer.rgb))
            }
        }
    }
}
