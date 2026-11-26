import SwiftUI

/// S1/M1: pixelova maska a obrys spritu v bunkach mrizky (pouzivaji testy). Od N1 se obrys na obrazovce kresli
/// v bodech pres `SpriteOutline`, ne v pixelech spritu.
enum PixelOutline {
    /// Tmavy obrys #1a1a2e.
    static let ink = Color(red: 0x1a / 255, green: 0x1a / 255, blue: 0x2e / 255)
    /// Vybrana vec v obchode ma misto tmaveho bily obrys.
    static let selected = Color.white

    /// Maska plnych bunek ze vsech vrstev ("#").
    static func mask(_ layers: [AvatarLayer]) -> [[Bool]] {
        let height = layers.map(\.rows.count).max() ?? 0
        let width = layers.flatMap(\.rows).map(\.count).max() ?? 0
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        for layer in layers {
            for (y, row) in layer.rows.enumerated() {
                for (x, cell) in row.enumerated() where cell == "#" { mask[y][x] = true }
            }
        }
        return mask
    }

    /// Maska sprite z mrizky znaku: plna je kazda bunka, ktera ma v palete barvu.
    static func mask(rows: [String], palette: [Character: Color]) -> [[Bool]] {
        let width = rows.map(\.count).max() ?? 0
        return rows.map { row in
            let cells = Array(row)
            return (0..<width).map { x in x < cells.count && palette[cells[x]] != nil }
        }
    }

    /// Obrys masky jako mrizka o 1 bunku vetsi na kazdou stranu ("#" = bunka obrysu).
    static func ring(_ mask: [[Bool]]) -> [String] {
        let height = mask.count
        let width = mask.map(\.count).max() ?? 0
        func filled(_ x: Int, _ y: Int) -> Bool {
            y >= 0 && y < height && x >= 0 && x < mask[y].count && mask[y][x]
        }
        return (-1...height).map { y in
            String((-1...width).map { x -> Character in
                guard !filled(x, y) else { return "." }
                let edge = filled(x - 1, y) || filled(x + 1, y) || filled(x, y - 1) || filled(x, y + 1)
                return edge ? "#" : "."
            })
        }
    }
}

/// N1: obrys a stin spritu v bodech obrazovky, nezavisle na zvetseni spritu (driv 1 pixel spritu = 3-10 bodu,
/// tlusty obrys a cerny blok pod veci). Obrys = silueta obsahu posunuta do 8 smeru o `width` bodu pod spritem,
/// cela vrstva slozena dohromady a pak zpruhlednena (prekryvy se nescitaji). Stin je jemny, rozmazany, bez tvaru.
struct SpriteOutline: ViewModifier {
    enum Style {
        /// Trvaly tmavy obrys: 1 pt, #1a1a2e na 70 %.
        case ink
        /// Vybrana vec v obchode: bily obrys 1,25 pt, bez aury a zare.
        case selected

        var color: Color { self == .ink ? PixelOutline.ink : PixelOutline.selected }
        var opacity: Double { self == .ink ? 0.7 : 1 }
        var width: CGFloat { self == .ink ? 1 : 1.25 }
    }

    var style: Style = .ink
    /// Jemny vrzeny stin (offset 0,1.5 pt, blur 1.5 pt, cerna 35 %).
    var shadow = true
    /// Bez obrysu i stinu (napr. sdileci karty).
    var enabled = true

    @ViewBuilder func body(content: Content) -> some View {
        if !enabled {
            content
        } else {
            outlined(content)
        }
    }

    private func outlined(_ content: Content) -> some View {
        content
            .background {
                ZStack {
                    ForEach(0..<8, id: \.self) { index in
                        let angle = Double(index) * .pi / 4
                        style.color
                            .mask { content }
                            .offset(x: CGFloat(cos(angle)) * style.width, y: CGFloat(sin(angle)) * style.width)
                    }
                }
                .compositingGroup()
                .opacity(style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(shadow ? 0.35 : 0), radius: shadow ? 1.5 : 0, x: 0, y: shadow ? 1.5 : 0)
    }
}

extension View {
    /// N1: tenky obrys a jemny stin v bodech obrazovky (hrdina, veci, zasoby, obrazy).
    func spriteOutline(_ style: SpriteOutline.Style = .ink, shadow: Bool = true, enabled: Bool = true) -> some View {
        modifier(SpriteOutline(style: style, shadow: shadow, enabled: enabled))
    }
}
