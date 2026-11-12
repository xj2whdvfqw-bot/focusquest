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

    var body: some View {
        PixelLayerStack(layers: AvatarSprite.layers(for: appearance, heroClass: heroClass))
            .frame(width: size, height: size)
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
