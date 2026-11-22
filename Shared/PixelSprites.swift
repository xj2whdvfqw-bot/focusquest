import SwiftUI

enum PixelSprite: Hashable, Sendable {
    case boss(String)
    case companion(String)
    case hero(HeroClass)
}

/// Staticky sprite slozeny z obycejnych tvaru. Pouziva ho Live Activity,
/// kde nebezi animace ani TimelineView; v appce je animovana verze PixelArtAvatarView.
struct StaticPixelSprite: View {
    let sprite: PixelSprite
    var size: CGFloat = 48

    var body: some View {
        let rows = SpritePalette.rows(for: sprite, startled: false)
        let symbols = Set(rows.joined()).filter { $0 != "." }.sorted()
        ZStack {
            ForEach(symbols, id: \.self) { symbol in
                PixelLayerShape(rows: rows, symbol: symbol).fill(SpritePalette.color(for: symbol))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(SpritePalette.label(for: sprite))
    }
}

/// Vsechny pixely jedne barvy jako jedna cesta.
struct PixelLayerShape: Shape {
    let rows: [String]
    let symbol: Character

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = rows.first, !first.isEmpty else { return path }
        let cell = min(rect.width / CGFloat(first.count), rect.height / CGFloat(rows.count))
        let left = rect.minX + (rect.width - cell * CGFloat(first.count)) / 2
        let top = rect.minY + (rect.height - cell * CGFloat(rows.count)) / 2
        for (y, row) in rows.enumerated() {
            for (x, value) in row.enumerated() where value == symbol {
                path.addRect(CGRect(x: left + CGFloat(x) * cell, y: top + CGFloat(y) * cell, width: cell + 0.2, height: cell + 0.2))
            }
        }
        return path
    }
}

enum SpritePalette {
    static func color(for symbol: Character) -> Color {
        switch symbol {
        case "O": Color(red: 0.95, green: 0.62, blue: 0.24)
        case "Y": Color(red: 1, green: 0.84, blue: 0.38)
        case "B": Color(red: 0.26, green: 0.72, blue: 0.82)
        case "C": Color(red: 0.46, green: 0.87, blue: 0.83)
        case "P": Color(red: 0.68, green: 0.45, blue: 0.85)
        case "R": Color(red: 0.9, green: 0.28, blue: 0.4)
        case "W": Color.white.opacity(0.92)
        case "S": Color(red: 0.24, green: 0.3, blue: 0.43)
        case "G": Color(red: 0.36, green: 0.73, blue: 0.46)
        case "D": Color(red: 0.13, green: 0.17, blue: 0.27)
        case "T": Color(red: 0.62, green: 0.40, blue: 0.20)   // drevo
        case "E": Color(red: 0.98, green: 0.93, blue: 0.80)   // smetana, slonovina
        case "K": Color(red: 0.09, green: 0.09, blue: 0.12)   // skoro cerna
        case "F": Color(red: 0.97, green: 0.80, blue: 0.64)   // kuze
        case "N": Color(red: 1.00, green: 0.60, blue: 0.78)   // ruzova
        case "A": Color(red: 0.62, green: 0.67, blue: 0.75)   // sediva
        case "L": Color(red: 0.55, green: 0.86, blue: 1.00)   // svitici modra
        case "U": Color(red: 0.17, green: 0.29, blue: 0.70)   // namornicka modra
        case "M": Color(red: 0.18, green: 0.45, blue: 0.25)   // tmave zelena (mech, listi)
        case "H": Color(red: 0.40, green: 0.24, blue: 0.12)   // tmave hneda (kura, cepice zaludu)
        default: .clear
        }
    }

    static func rows(for sprite: PixelSprite, startled: Bool) -> [String] {
        switch sprite {
        case .boss(let id):
            return bossRows[id] ?? originalBossRows[id] ?? specialBossRows[id] ?? slimeRows
        case .companion(let id):
            if id == "ember-dragonling" { return ["................", ".....OO..OO.....", "....OOOOOOOO....", "...OOOOWWOOOO...", "...OOOOOOOOOO...", "....OOOOOOOO....", ".....OOOOOO.....", "....OOO..OOO....", "...OO......OO...", "..OO........OO..", "................", "................", "................", "................", "................", "................"] }
            // Lo-fi kocka: svetle seda se zlutyma ocima, aby byla videt na tmavem pozadi.
            return ["................", "..AA........AA..", ".AAA........AAA.", ".AAAA......AAAA.", "..AAAAAAAAAAAA..", "..AAYYAAAAYYAA..", "..AAAAAAAAAAAA..", "...AAAAAAAAAA...", "....AAAAAAAA....", "....AAAAAAAA....", ".....AAAAAA.....", "....AA......AA..", "...AA........AA.", "................", "................", "................"]
        case .hero(let hero):
            let color: Character = switch hero { case .mage: "P"; case .rogue: "B"; case .archer: "G"; case .warrior: "D" }
            return ["......WWWW......", ".....W\(color)\(color)WW.....", ".....\(color)\(color)\(color)\(color)\(color)\(color).....", "....\(color)\(color)WW\(color)\(color)....", "....\(color)\(color)\(color)\(color)\(color)\(color)....", "......\(color)\(color)......", "....\(color)\(color)\(color)\(color)\(color)\(color)....", "...\(color)\(color)\(color)\(color)\(color)\(color)\(color)\(color)...", "..\(color)\(color)\(color)\(color)\(color)\(color)\(color)\(color)\(color)\(color)..", "..\(color)\(color)..\(color)\(color)..", "..\(color)\(color)..\(color)\(color)..", "..\(color)\(color)..\(color)\(color)..", "................", "................", "................", "................"]
        }
    }

    static func label(for sprite: PixelSprite) -> String {
        switch sprite {
        case .boss(let value): value.replacingOccurrences(of: "-", with: " ")
        case .companion(let value): value.replacingOccurrences(of: "-", with: " ")
        case .hero(let value): value.displayName
        }
    }
}
// MARK: - Bossove (16x16, kazdy znak = jeden pixel, "." = pruhledne)

extension SpritePalette {
    /// Zaloha pro neznameho bosse (napr. ze starsi verze appky).
    static let slimeRows = ["................", "......GGGG......", "....GGGGGGGG....", "...GGGGGGGGGG...", "..GGGGGGGGGGGG..", "..GGWWGGGGWWGG..", ".GGGGGGGGGGGGGG.", ".GGGGGGGGGGGGGG.", ".GGGGGGGGGGGGGG.", "..GGGGGGGGGGGG..", "...GGGGGGGGGG...", "....GGGGGGGG....", ".....GGGGGG.....", "......GGGG......", "................", "................"]
}

// MARK: - Rozcvicka (16x16)

extension SpritePalette {
    /// Bossove mimo svety. "warmup-wisp" = Warm-up Wisp z rychle 5minutove bitvy:
    /// maly svitici plaminek/duch se zarici modrou obrubou, tyrkysovym telem a vlnitym spodkem.
    static let specialBossRows: [String: [String]] = [
        "warmup-wisp": [
            "................", ".......LL.......", "......LWWL......", ".....LLCCLL.....",
            "....LLCCCCLL....", "....LCCCCCCL....", "...LCCCCCCCCL...", "...LCKWCCKWCL...",
            "...LCKKCCKKCL...", "...LCCCCCCCCL...", "...LCCCKKCCCL...", "....LCCCCCCL....",
            "....LCCCCCCL....", "...LCL.LL.LCL...", "...L...LL...L...", "................"
        ]
    ]
}
