import CoreGraphics
import Foundation

/// Pixel-art teren mapy generovany v kodu: kazdy pixel bitmapy je 4 x 4 body mapy (MapLayout.cell).
/// Cela mapa je jen 600 x 900 px (asi 2 MB), zobrazuje se bez vyhlazovani, takze zustava ostra
/// pri kazdem zoomu. Zadny obri obrazek ani soubor. Vrstvy nad ni (cesta je v bitmape, zastavky,
/// hrdina, nazvy a mlha) kresli SwiftUI.
/// Generuje se jednou na pozadi (render je cista funkce bez stavu) a drzi se v MapTerrainCache.
enum MapTerrain {
    struct RGB: Sendable {
        let r: UInt8, g: UInt8, b: UInt8
        init(_ r: UInt8, _ g: UInt8, _ b: UInt8) { self.r = r; self.g = g; self.b = b }
    }

    // MARK: - Nahodnost (deterministicka, aby mapa vypadala pokazde stejne)

    static func hash(_ x: Int, _ y: Int, _ seed: Int) -> Double {
        var h = UInt64(bitPattern: Int64(x &* 374_761_393 &+ y &* 668_265_263 &+ seed &* 1_274_126_177))
        h = (h ^ (h >> 13)) &* 1_103_515_245
        h ^= h >> 16
        h = h &* 2_654_435_761
        h ^= h >> 15
        return Double(h & 0xFF_FFFF) / Double(0xFF_FFFF)
    }

    /// Hladky sum 0...1 (value noise) s velikosti skvrn `scale` pixelu.
    static func noise(_ x: Int, _ y: Int, scale: Double, seed: Int) -> Double {
        let fx = Double(x) / scale, fy = Double(y) / scale
        let x0 = Int(fx.rounded(.down)), y0 = Int(fy.rounded(.down))
        let tx = fx - Double(x0), ty = fy - Double(y0)
        let sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty)
        let a = hash(x0, y0, seed), b = hash(x0 + 1, y0, seed)
        let c = hash(x0, y0 + 1, seed), d = hash(x0 + 1, y0 + 1, seed)
        let top = a + (b - a) * sx, bottom = c + (d - c) * sx
        return top + (bottom - top) * sy
    }

    // MARK: - Malé pixelove dekorace (1 znak = 1 pixel terenu, "." = pruhledne)

    private static let stampColors: [Character: RGB] = [
        "g": RGB(120, 196, 96), "G": RGB(66, 140, 70), "d": RGB(36, 92, 50), "t": RGB(118, 78, 44),
        "r": RGB(196, 64, 60), "w": RGB(240, 236, 224), "k": RGB(40, 36, 48), "y": RGB(250, 210, 90),
        "o": RGB(236, 140, 60), "p": RGB(240, 120, 160), "s": RGB(150, 150, 164), "S": RGB(110, 110, 126),
        "h": RGB(226, 190, 96), "b": RGB(90, 150, 230), "m": RGB(206, 70, 70), "n": RGB(90, 70, 130),
    ]

    private static let tree = [".ggg.", "gGGGg", "GGGGG", "GGdGG", ".GGG.", "..t..", "..t.."]
    private static let pine = ["..d..", ".dGd.", "..d..", ".dGd.", "dGGGd", ".dGd.", "..t.."]
    private static let barn = ["...rrr...", "..rrrrr..", ".rrrrrrr.", "rrwrrrwrr", "rrrrwrrrr", "rrrwwwrrr", "rrrwkwrrr"]
    private static let hay = [".hh.", "hhhh", "hhhh"]
    private static let mushroom = ["mwm", "mmm", ".w."]
    private static let coral = ["p.p", "ppp", ".p.", ".p."]
    private static let coralOrange = ["o.o", ".o.", "ooo", ".o."]
    private static let palm = ["g...g", ".ggg.", "g.t.g", "..t..", "..t..", "..t.."]
    private static let wreck = ["...t.....", "...t.....", "..ttt....", "ttttttt..", ".kkkkk...", "..kkk...."]
    private static let pagoda = ["...r...", ".rrrrr.", "..yyy..", "rrrrrrr", ".yyyyy.", ".ykkky.", ".ykkky."]
    private static let lantern = ["kk", "yo", "kk"]
    private static let torii = ["rrrrrrr", ".r...r.", "rrrrrrr", ".r...r.", ".r...r.", ".r...r."]
    private static let blossom = [".pp.", "pppp", "pppp", ".tt.", ".t.."]
    private static let house = ["..rr..", ".rrrr.", "rrrrrr", "wwwwww", "wkwwkw", "wwkkww"]
    private static let tower = ["s.s.s", "sssss", "sskss", "sssss", "sssss", "sskss", "sssss", "SSSSS"]
    private static let dome = ["..www..", ".wwkww.", "wwwwwww", "sssssss", "skssssk", "sssssss"]

    // MARK: - Render

    /// RGBA bajty terenu (MapLayout.columns x MapLayout.rows, nepruhledne). Bezi mimo hlavni vlakno.
    static func render() -> [UInt8] {
        let cols = MapLayout.columns, rows = MapLayout.rows
        var pixels = [UInt8](repeating: 255, count: cols * rows * 4)
        var worldOf = [UInt8](repeating: 0, count: cols * rows)

        func set(_ x: Int, _ y: Int, _ color: RGB) {
            guard x >= 0, y >= 0, x < cols, y < rows else { return }
            let i = (y * cols + x) * 4
            pixels[i] = color.r; pixels[i + 1] = color.g; pixels[i + 2] = color.b; pixels[i + 3] = 255
        }

        // 1. Zakladni teren kazdeho sveta.
        for y in 0..<rows {
            for x in 0..<cols {
                let world = MapLayout.worldIndex(x: (CGFloat(x) + 0.5) * MapLayout.cell, y: (CGFloat(y) + 0.5) * MapLayout.cell)
                worldOf[y * cols + x] = UInt8(world)
                set(x, y, ground(world: world, x: x, y: y))
            }
        }

        // 2. Okoli cesty: tam se nekresli dekorace ani stavby.
        var nearRoad = [Bool](repeating: false, count: cols * rows)
        let clearance = 12
        var lastCell = (-99, -99)
        for point in MapLayout.roadSamples {
            let cx = Int(point.x / MapLayout.cell), cy = Int(point.y / MapLayout.cell)
            guard (cx, cy) != lastCell else { continue }
            lastCell = (cx, cy)
            for dy in -clearance...clearance {
                for dx in -clearance...clearance where dx * dx + dy * dy <= clearance * clearance {
                    let x = cx + dx, y = cy + dy
                    if x >= 0, y >= 0, x < cols, y < rows { nearRoad[y * cols + x] = true }
                }
            }
        }

        func stamp(_ art: [String], _ x: Int, _ y: Int, force: Bool = false) {
            let height = art.count, width = art.first?.count ?? 0
            if !force {
                for dy in 0..<height { for dx in 0..<width {
                    let px = x + dx, py = y + dy
                    guard px >= 0, py >= 0, px < cols, py < rows, !nearRoad[py * cols + px] else { return }
                } }
            }
            for (dy, row) in art.enumerated() {
                for (dx, char) in row.enumerated() where char != "." {
                    if let color = stampColors[char] { set(x + dx, y + dy, color) }
                }
            }
        }

        func fillRect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: (Int, Int) -> RGB?) {
            for py in y..<(y + h) { for px in x..<(x + w) {
                if let c = color(px - x, py - y) { set(px, py, c) }
            } }
        }

        // 3. Rozhazene dekorace podle sveta (na mrizce s nahodnym posunem, mimo cestu).
        let grid = 9
        for gy in stride(from: 0, to: rows, by: grid) {
            for gx in stride(from: 0, to: cols, by: grid) {
                let x = gx + Int(hash(gx, gy, 11) * Double(grid - 4))
                let y = gy + Int(hash(gx, gy, 12) * Double(grid - 4))
                guard x < cols, y < rows else { continue }
                let world = Int(worldOf[y * cols + x])
                let roll = hash(gx, gy, 13)
                switch BossWorld.allCases[world] {
                case .farm:
                    if roll < 0.18 { stamp(tree, x, y) } else if roll < 0.24 { stamp(hay, x, y) }
                case .forest:
                    if roll < 0.42 { stamp(pine, x, y) } else if roll < 0.62 { stamp(tree, x, y) } else if roll < 0.68 { stamp(mushroom, x, y) }
                case .reef:
                    let land = noise(x, y, scale: 22, seed: 31) > 0.64
                    if land { if roll < 0.25 { stamp(palm, x, y) } }
                    else if roll < 0.10 { stamp(coral, x, y) } else if roll < 0.16 { stamp(coralOrange, x, y) }
                case .dojo:
                    if roll < 0.16 { stamp(blossom, x, y) } else if roll < 0.22 { stamp(lantern, x, y) } else if roll < 0.30 { stamp(tree, x, y) }
                case .highSchool:
                    if roll < 0.12 { stamp(tree, x, y) }
                case .history:
                    if roll < 0.16 { stamp(house, x, y) } else if roll < 0.22 { stamp(tree, x, y) }
                case .planets:
                    break
                }
            }
        }

        // 4. Velke stavby v rozich pasu, kam cesta nevede.
        for (index, world) in BossWorld.allCases.enumerated() {
            let band = MapLayout.band(of: world)
            let top = Int(band.minY / MapLayout.cell), bottom = Int(band.maxY / MapLayout.cell)
            // Cesta v sudem svete vede zprava dole doleva nahoru, v lichem obracene.
            let even = index % 2 == 0
            let bottomCornerX = even ? 60 : cols - 160
            let topCornerX = even ? cols - 160 : 60
            let lowY = bottom - 60, highY = top + 16
            switch world {
            case .farm:
                stamp(barn, bottomCornerX + 30, lowY + 10, force: true)
                stamp(barn, topCornerX + 50, highY + 14, force: true)
                for i in 0..<6 { stamp(hay, bottomCornerX + 10 + i * 9, lowY + 24, force: true) }
            case .forest:
                for i in 0..<5 { stamp(mushroom, bottomCornerX + 20 + i * 12, lowY + 16 + (i % 2) * 6, force: true) }
                fillRect(topCornerX + 30, highY + 6, 46, 26) { dx, dy in
                    let ex = Double(dx - 23) / 23, ey = Double(dy - 13) / 13
                    return ex * ex + ey * ey <= 1 ? RGB(64, 110, 170) : nil
                }
            case .reef:
                stamp(wreck, bottomCornerX + 30, lowY + 14, force: true)
                fillRect(topCornerX + 40, highY + 8, 40, 20) { dx, dy in
                    let ex = Double(dx - 20) / 20, ey = Double(dy - 10) / 10
                    let d = ex * ex + ey * ey
                    return d <= 0.55 ? RGB(78, 160, 84) : (d <= 1 ? RGB(232, 208, 146) : nil)
                }
                stamp(palm, topCornerX + 56, highY + 8, force: true)
            case .dojo:
                stamp(pagoda, bottomCornerX + 40, lowY + 12, force: true)
                stamp(torii, topCornerX + 50, highY + 14, force: true)
                for i in 0..<4 { stamp(lantern, bottomCornerX + 30 + i * 8, lowY + 26, force: true) }
            case .highSchool:
                // Budova skoly: cihly, okna, seda strecha, vchod.
                fillRect(bottomCornerX + 8, lowY - 6, 84, 44) { dx, dy in
                    if dy < 6 { return RGB(92, 92, 104) }
                    if dy > 36, (38...45).contains(dx) { return RGB(60, 44, 40) }
                    if dy % 6 >= 2, dy % 6 <= 4, dx % 6 >= 2, dx % 6 <= 4, dy < 34 { return RGB(238, 224, 150) }
                    return (dx + dy / 3) % 7 == 0 ? RGB(150, 70, 54) : RGB(178, 86, 66)
                }
                // Hriste s dvorem a bezeckou drahou.
                fillRect(topCornerX - 10, highY, 110, 52) { dx, dy in
                    let ex = Double(dx - 55) / 55, ey = Double(dy - 26) / 26
                    let d = ex * ex + ey * ey
                    if d > 1 { return nil }
                    if d > 0.72 { return RGB(190, 92, 72) }
                    if d > 0.66 { return RGB(240, 236, 224) }
                    if (dx - 15) % 10 == 0, d < 0.6 { return RGB(240, 236, 224) }
                    return (dx / 5) % 2 == 0 ? RGB(78, 152, 74) : RGB(70, 140, 68)
                }
            case .history:
                // Hrad: hradby s vezemi a nadvorim.
                fillRect(bottomCornerX + 10, lowY - 10, 72, 46) { dx, dy in
                    let wall = dx < 4 || dx > 67 || dy < 4 || dy > 41
                    if wall { return (dx + dy) % 4 == 0 ? RGB(120, 120, 134) : RGB(146, 146, 160) }
                    return (dx * 3 + dy) % 9 == 0 ? RGB(150, 134, 104) : RGB(176, 160, 128)
                }
                for (tx, ty) in [(0, -6), (66, -6), (0, 32), (66, 32)] { stamp(tower, bottomCornerX + 10 + tx, lowY - 10 + ty, force: true) }
                for i in 0..<3 { stamp(house, topCornerX + 20 + i * 12, highY + 12, force: true) }
            case .planets:
                stamp(dome, bottomCornerX + 40, lowY + 14, force: true)
                for (i, color) in [RGB(240, 170, 90), RGB(150, 120, 220), RGB(110, 170, 240)].enumerated() {
                    let radius = 9 - i * 2
                    fillRect(topCornerX + 10 + i * 40, highY + 6 + (i % 2) * 18, radius * 2 + 1, radius * 2 + 1) { dx, dy in
                        let ex = dx - radius, ey = dy - radius
                        return ex * ex + ey * ey <= radius * radius ? (ex + ey < -radius / 2 ? RGB(250, 240, 220) : color) : nil
                    }
                }
            }
        }

        // 5. Cesta: hlinena, pres vodu drevene mustky, ve vesmiru svitici kameny.
        let roadRadius = 5, borderRadius = 6
        lastCell = (-99, -99)
        var roadCells: [(Int, Int)] = []
        for point in MapLayout.roadSamples {
            let cx = Int(point.x / MapLayout.cell), cy = Int(point.y / MapLayout.cell)
            guard (cx, cy) != lastCell else { continue }
            lastCell = (cx, cy)
            roadCells.append((cx, cy))
        }
        for pass in 0..<2 {
            let radius = pass == 0 ? borderRadius : roadRadius
            for (cx, cy) in roadCells {
                for dy in -radius...radius {
                    for dx in -radius...radius where dx * dx + dy * dy <= radius * radius {
                        let x = cx + dx, y = cy + dy
                        guard x >= 0, y >= 0, x < cols, y < rows else { continue }
                        let world = BossWorld.allCases[Int(worldOf[y * cols + x])]
                        set(x, y, pass == 0 ? roadBorder(world) : roadSurface(world, x: x, y: y))
                    }
                }
            }
        }
        return pixels
    }

    /// Zakladni barva terenu sveta v pixelu (x, y).
    private static func ground(world index: Int, x: Int, y: Int) -> RGB {
        let fine = hash(x, y, 7)
        switch BossWorld.allCases[index] {
        case .farm:
            let field = noise(x, y, scale: 34, seed: 3)
            if field > 0.64 { return (y % 4 < 2) ? RGB(214, 180, 92) : RGB(196, 160, 76) }
            if field > 0.6 { return RGB(70, 128, 62) }
            if noise(x, y, scale: 20, seed: 4) > 0.72 { return (x % 3 == 0) ? RGB(140, 100, 62) : RGB(156, 114, 72) }
            return fine > 0.5 ? RGB(110, 176, 84) : RGB(102, 166, 78)
        case .forest:
            let canopy = noise(x, y, scale: 12, seed: 5)
            if canopy > 0.48 { return fine > 0.86 ? RGB(70, 138, 74) : RGB(34, 86, 48) }
            if fine > 0.997 { return RGB(250, 230, 120) }
            return fine > 0.5 ? RGB(58, 118, 66) : RGB(52, 108, 60)
        case .reef:
            let land = noise(x, y, scale: 22, seed: 31)
            if land > 0.7 { return fine > 0.5 ? RGB(78, 160, 84) : RGB(70, 150, 78) }
            if land > 0.64 { return fine > 0.5 ? RGB(232, 208, 146) : RGB(222, 196, 134) }
            if land > 0.57 { return RGB(64, 140, 200) }
            if fine > 0.985 { return RGB(150, 200, 236) }
            let deep = noise(x, y, scale: 40, seed: 32)
            return deep > 0.5 ? RGB(34, 86, 150) : RGB(40, 98, 164)
        case .dojo:
            let terrace = sin(Double(y) * 0.45 + noise(x, y, scale: 30, seed: 8) * 6)
            if noise(x, y, scale: 10, seed: 9) > 0.74 { return fine > 0.5 ? RGB(236, 170, 196) : RGB(222, 150, 182) }
            if terrace > 0.92 { return RGB(98, 124, 70) }
            return fine > 0.5 ? RGB(124, 156, 88) : RGB(116, 146, 82)
        case .highSchool:
            if x % 50 < 3 || y % 46 < 3 { return RGB(128, 128, 138) }
            if x % 50 < 5 || y % 46 < 5 { return RGB(196, 196, 200) }
            return fine > 0.5 ? RGB(96, 164, 86) : RGB(90, 156, 80)
        case .history:
            if noise(x, y, scale: 16, seed: 10) > 0.7 { return fine > 0.5 ? RGB(110, 160, 84) : RGB(100, 150, 78) }
            let brick = (y % 4 == 0) || ((x + (y / 4 % 2) * 2) % 4 == 0)
            return brick ? RGB(160, 144, 116) : (fine > 0.5 ? RGB(186, 170, 140) : RGB(180, 164, 134))
        case .planets:
            let band = MapLayout.band(of: .planets)
            let local = (Double(y) * Double(MapLayout.cell) - Double(band.minY)) / Double(max(1, band.height))
            let ridge = 0.62 + 0.14 * sin(Double(x) / 21) + 0.08 * sin(Double(x) / 7 + 2)
            if local > ridge {
                if local < ridge + 0.03 { return RGB(220, 220, 236) }
                return fine > 0.5 ? RGB(74, 66, 104) : RGB(66, 58, 94)
            }
            if fine > 0.994 { return RGB(250, 250, 255) }
            if fine > 0.99 { return RGB(250, 220, 140) }
            return local > 0.4 ? RGB(30, 26, 66) : RGB(20, 20, 50)
        }
    }

    private static func roadBorder(_ world: BossWorld) -> RGB {
        switch world {
        case .reef: RGB(92, 62, 36)
        case .planets: RGB(80, 70, 130)
        case .highSchool: RGB(96, 96, 108)
        default: RGB(120, 92, 60)
        }
    }

    private static func roadSurface(_ world: BossWorld, x: Int, y: Int) -> RGB {
        switch world {
        case .reef: return (x + y) % 4 == 0 ? RGB(112, 76, 46) : RGB(150, 104, 62)
        case .planets: return hash(x, y, 21) > 0.8 ? RGB(190, 180, 240) : RGB(150, 140, 200)
        case .highSchool: return RGB(170, 170, 178)
        default: return hash(x, y, 22) > 0.85 ? RGB(178, 142, 96) : RGB(200, 166, 116)
        }
    }

    // MARK: - Mlha nad zamcenym svetem

    /// Pixelove mraky pres pas sveta: 1 pixel = 16 bodu, okraje se rozpadaji do ztracena.
    /// Vraci (sirka, vyska, premultiplied RGBA).
    static func fog(for world: BossWorld) -> (width: Int, height: Int, pixels: [UInt8]) {
        let band = MapLayout.band(of: world)
        let scale: CGFloat = 16
        let width = Int(MapLayout.size.width / scale)
        let height = Int((band.height + 120) / scale)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let seed = (BossWorld.allCases.firstIndex(of: world) ?? 0) * 17 + 40
        for y in 0..<height {
            let edge = min(y, height - 1 - y)
            for x in 0..<width {
                let n = noise(x, y, scale: 6, seed: seed)
                // U horniho a dolniho okraje mraky ridnou (dithering), uprostred zakryji vse.
                if edge < 4, hash(x, y, seed + 1) > Double(edge) / 4 * 0.9 + 0.05 { continue }
                let color: (UInt8, UInt8, UInt8) = n > 0.62 ? (238, 238, 246) : (n > 0.45 ? (206, 208, 224) : (172, 174, 196))
                let alpha: UInt8 = 246
                let i = (y * width + x) * 4
                pixels[i] = UInt8(Int(color.0) * Int(alpha) / 255)
                pixels[i + 1] = UInt8(Int(color.1) * Int(alpha) / 255)
                pixels[i + 2] = UInt8(Int(color.2) * Int(alpha) / 255)
                pixels[i + 3] = alpha
            }
        }
        return (width, height, pixels)
    }

    /// Obrazek z RGBA bajtu (premultiplied alpha).
    static func makeImage(width: Int, height: Int, pixels: [UInt8]) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}

/// Hotove obrazky mapy (teren a mlha); vyrabi se jednou za beh appky.
@MainActor
enum MapTerrainCache {
    static var terrain: CGImage?
    private static var fogImages: [BossWorld: CGImage] = [:]

    /// Teren se generuje na pozadi; dalsi otevreni mapy uz ho ma hned.
    static func loadTerrain() async -> CGImage? {
        if let terrain { return terrain }
        let pixels = await Task.detached(priority: .userInitiated) { MapTerrain.render() }.value
        let image = MapTerrain.makeImage(width: MapLayout.columns, height: MapLayout.rows, pixels: pixels)
        terrain = image
        return image
    }

    static func fog(for world: BossWorld) -> CGImage? {
        if let cached = fogImages[world] { return cached }
        let fog = MapTerrain.fog(for: world)
        let image = MapTerrain.makeImage(width: fog.width, height: fog.height, pixels: fog.pixels)
        fogImages[world] = image
        return image
    }
}
