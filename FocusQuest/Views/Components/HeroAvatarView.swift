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
    /// S1/M1: tmavy 1px obrys kolem hrdiny (stanek, Hero tab, onboarding), aby se neztracel na svetlem pozadi.
    /// Obrys presahuje ram o jeden pixel hrdiny a rozlozeni nemeni.
    var outlined = false

    var body: some View {
        let layers = AvatarSprite.layers(for: appearance, heroClass: heroClass)
        PixelLayerStack(layers: layers)
            .frame(width: size, height: size)
            .background {
                if outlined {
                    let cell = size / CGFloat(AvatarSprite.gridSize)
                    PixelLayerShape(rows: PixelOutline.ring(PixelOutline.mask(layers)), symbol: "#")
                        .fill(PixelOutline.ink)
                        .frame(width: size + 2 * cell, height: size + 2 * cell)
                }
            }
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
