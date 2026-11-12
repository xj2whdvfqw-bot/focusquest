import SwiftUI

enum PixelSprite: Hashable {
    case boss(String)
    case companion(String)
    case hero(HeroClass)
}

struct PixelArtAvatarView: View {
    let sprite: PixelSprite
    var startled = false
    var hitFlash = false
    var isEnraged = false
    var size: CGFloat = 112

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.35, paused: false)) { timeline in
            let bob = startled ? 0 : sin(timeline.date.timeIntervalSinceReferenceDate * 2.4) * 2
            Canvas(opaque: false, rendersAsynchronously: true) { context, canvasSize in
                let rows = SpritePalette.rows(for: sprite, startled: startled)
                guard let first = rows.first, !first.isEmpty else { return }
                let cell = min(canvasSize.width / CGFloat(first.count), canvasSize.height / CGFloat(rows.count))
                let left = (canvasSize.width - cell * CGFloat(first.count)) / 2
                let top = (canvasSize.height - cell * CGFloat(rows.count)) / 2
                for (y, row) in rows.enumerated() {
                    for (x, symbol) in row.enumerated() where symbol != "." {
                        let color = hitFlash ? Color.white : (isEnraged ? Color.red : SpritePalette.color(for: symbol))
                        let rect = CGRect(x: left + CGFloat(x) * cell, y: top + CGFloat(y) * cell + bob, width: cell + 0.2, height: cell + 0.2)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
            .frame(width: size, height: size)
            .accessibilityLabel(SpritePalette.label(for: sprite))
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.12), value: startled)
    }
}

private enum SpritePalette {
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
        default: .clear
        }
    }

    static func rows(for sprite: PixelSprite, startled: Bool) -> [String] {
        switch sprite {
        case .boss(let id):
            return switch id {
            case "shadow-golem": ["......SSSS......", ".....SDDDS.....", "....SDDDDS.....", "...SDDWWDDS....", "...SDDDDDDS....", "..SSDDDDDDSS...", "..SDDDDDDDDDS..", ".SSDDDDDDDDSS..", ".SDDDDDDDDDDDS.", ".SDDSSDDDDSSDS.", "..SDDSSSSDDDS..", "..SDDDDDDDDD...", "...SDDDDDDS....", "...SS....SS....", "..SS......SS...", "................"]
            case "void-dragon": ["...PP......PP...", "..PPPP....PPPP..", ".PPPPPP..PPPPPP.", "PPWWPPPPPPPPWWPP", ".PPPPPPPPPPPPPP.", "..PPPPPPPPPPPP..", "...PPPPPPPPPP...", "....PPPPPPPP....", "...PPPPPPPPPP...", "..PPPPPPPPPPPP..", ".PPPPPPPPPPPPPP.", "PP...PP..PP...PP", ".....PP..PP.....", "....PP....PP....", "...PP......PP...", "................"]
            default: ["................", "......GGGG......", "....GGGGGGGG....", "...GGGGGGGGGG...", "..GGGGGGGGGGGG..", "..GGWWGGGGWWGG..", ".GGGGGGGGGGGGGG.", ".GGGGGGGGGGGGGG.", ".GGGGGGGGGGGGGG.", "..GGGGGGGGGGGG..", "...GGGGGGGGGG...", "....GGGGGGGG....", ".....GGGGGG.....", "......GGGG......", "................", "................"]
            }
        case .companion(let id):
            if id == "ember-dragonling" { return ["................", ".....OO..OO.....", "....OOOOOOOO....", "...OOOOWWOOOO...", "...OOOOOOOOOO...", "....OOOOOOOO....", ".....OOOOOO.....", "....OOO..OOO....", "...OO......OO...", "..OO........OO..", "................", "................", "................", "................", "................", "................"] }
            return ["................", "..DD........DD..", ".DDD........DDD.", ".DDDD......DDDD.", "..DDDDDDDDDDDD..", "..DDWWDDDDWWDD..", "..DDDDDDDDDDDD..", "...DDDDDDDDDD...", "....DDDDDDDD....", "....DDDDDDDD....", ".....DDDDDD.....", "....DD......DD..", "...DD........DD.", "................", "................", "................"]
        case .hero(let hero):
            let color: Character = switch hero { case .arcaneScholar: "P"; case .cyberRonin: "B"; case .alchemist: "G"; case .voidKnight: "D" }
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