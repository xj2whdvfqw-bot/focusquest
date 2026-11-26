import SwiftUI

/// S1/M1: 1px pixelovy obrys kolem spritu (hrdina, veci v obchode, zasoby, obrazy). Tenke veci (nuz, mec, hul)
/// jsou s nim videt na svetlem i tmavem pozadi. Obrys je jedna bunka mrizky kolem vsech plnych bunek
/// (4 sousedi, bez rohu, jak se obrys v pixel artu kresli), takze ma vzdy velikost jednoho pixelu spritu.
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

/// Maly pixelovy vrzeny stin pod spritem (na polici, pultu, pod obrazem): jeden radek pixelu,
/// uzsi nez sprite, s odsazenymi konci.
struct PixelDropShadow: View {
    /// Sirka spritu v pixelech.
    let width: Int
    var pixel: CGFloat = StallMetrics.pixel

    var body: some View {
        let length = max(2, Int((Double(width) * 0.8).rounded()))
        Canvas(opaque: false) { context, size in
            let left = (size.width - CGFloat(length) * pixel) / 2
            context.fill(Path(CGRect(x: left + pixel, y: 0, width: CGFloat(length - 2) * pixel, height: pixel)),
                         with: .color(.black.opacity(0.45)))
            context.fill(Path(CGRect(x: left, y: 0, width: CGFloat(length) * pixel, height: pixel)),
                         with: .color(.black.opacity(0.22)))
        }
        .frame(width: CGFloat(length) * pixel, height: pixel)
        .accessibilityHidden(true)
    }
}
