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
        "x": RGB(150, 36, 30), "X": RGB(96, 22, 20),
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
    /// Krizek na Farm (easter egg MapEasterEgg.farmX).
    private static let treasureMark = ["xX...xX", ".xX.xX.", "..xXX..", ".xX.xX.", "xX...xX"]

    // MARK: - Render

    /// RGBA bajty terenu. `step` 1 = plna mapa (MapLayout.columns x rows); 4 = rychly hruby nahled
    /// (bez dekoraci a staveb), ktery se ukaze, nez se dopocita plna mapa. Bezi mimo hlavni vlakno.
    /// Kresli primo do pameti (bez kontrol poli), aby byl rychly i v Debug buildu z CI.
    static func render(step: Int = 1) -> (width: Int, height: Int, pixels: [UInt8]) {
        let cols = MapLayout.columns / step, rows = MapLayout.rows / step
        let count = cols * rows
        let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: count * 4)
        pixels.initialize(repeating: 255, count: count * 4)
        let worldOf = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        worldOf.initialize(repeating: 0, count: count)
        let nearRoad = UnsafeMutablePointer<Bool>.allocate(capacity: count)
        nearRoad.initialize(repeating: false, count: count)
        defer {
            pixels.deallocate()
            worldOf.deallocate()
            nearRoad.deallocate()
        }
        let worlds = BossWorld.allCases
        let cell = Double(MapLayout.cell) * Double(step)

        func set(_ x: Int, _ y: Int, _ color: RGB) {
            guard x >= 0, y >= 0, x < cols, y < rows else { return }
            let i = (y * cols + x) * 4
            pixels[i] = color.r; pixels[i + 1] = color.g; pixels[i + 2] = color.b
        }

        // 1. Zakladni teren kazdeho sveta. Hranice je organicka (MapLayout.worldIndex: dlouha vlna + sum)
        // a pixely na ni se nahodne promichaji (jitter), takze svety do sebe prechazeji bez rovnych svu.
        let planets = MapLayout.band(of: .planets)
        let sky = (top: Double(planets.minY), height: Double(max(1, planets.height)))
        for y in 0..<rows {
            for x in 0..<cols {
                let jitter = (hash(x * step, y * step, 63) - 0.5) * 22
                let world = MapLayout.worldIndex(cellX: x * step, cellY: y * step, jitter: jitter)
                worldOf[y * cols + x] = UInt8(world)
                set(x, y, ground(worlds[world], x: x * step, y: y * step, sky: sky))
            }
        }

        // 1b. Pobrezi: kolem Reefu pas pisku na souši a melcina ve vode, takze trava prechazi v pisek a vodu.
        if let reefIndex = worlds.firstIndex(of: .reef) {
            let reef = UInt8(reefIndex)
            let reach = max(1, 4 / step)
            for y in 0..<rows {
                for x in 0..<cols {
                    let own = worldOf[y * cols + x]
                    let ownReef = own == reef
                    var nearest = Int.max
                    var d = 1
                    while d <= reach, nearest == .max {
                        if y - d >= 0, (worldOf[(y - d) * cols + x] == reef) != ownReef { nearest = d }
                        else if y + d < rows, (worldOf[(y + d) * cols + x] == reef) != ownReef { nearest = d }
                        else if x - d >= 0, (worldOf[y * cols + x - d] == reef) != ownReef { nearest = d }
                        else if x + d < cols, (worldOf[y * cols + x + d] == reef) != ownReef { nearest = d }
                        d += 1
                    }
                    guard nearest != .max else { continue }
                    let fine = hash(x * step, y * step, 64)
                    if ownReef {
                        if nearest * step <= 2 { set(x, y, fine > 0.5 ? RGB(232, 208, 146) : RGB(222, 196, 134)) }
                        else { set(x, y, RGB(64, 140, 200)) }
                    } else if nearest * step <= 3 {
                        set(x, y, fine > 0.5 ? RGB(232, 208, 146) : RGB(222, 196, 134))
                    }
                }
            }
        }

        // Body cesty v pixelech teto bitmapy (bez opakovani).
        var roadCells: [(Int, Int)] = []
        var lastCell = (-99, -99)
        for point in MapLayout.roadSamples {
            let roadCell = (Int(Double(point.x) / cell), Int(Double(point.y) / cell))
            guard roadCell != lastCell else { continue }
            lastCell = roadCell
            roadCells.append(roadCell)
        }

        func disc(_ cx: Int, _ cy: Int, radius: Int, _ body: (Int, Int) -> Void) {
            for dy in -radius...radius {
                for dx in -radius...radius where dx * dx + dy * dy <= radius * radius {
                    let x = cx + dx, y = cy + dy
                    if x >= 0, y >= 0, x < cols, y < rows { body(x, y) }
                }
            }
        }

        if step == 1 {
            // 2. Okoli cesty: tam se nekresli dekorace ani stavby (kruhy se prekryvaji, staci kazdy 3. bod).
            for (index, (cx, cy)) in roadCells.enumerated() where index % 3 == 0 {
                disc(cx, cy, radius: 12) { x, y in nearRoad[y * cols + x] = true }
            }

            func stamp(_ art: [String], _ x: Int, _ y: Int, force: Bool = false) {
                let rowsOfArt = art.map { Array($0) }
                let artHeight = rowsOfArt.count, artWidth = rowsOfArt.first?.count ?? 0
                if !force {
                    for dy in 0..<artHeight {
                        for dx in 0..<artWidth {
                            let px = x + dx, py = y + dy
                            guard px >= 0, py >= 0, px < cols, py < rows, !nearRoad[py * cols + px] else { return }
                        }
                    }
                }
                for (dy, row) in rowsOfArt.enumerated() {
                    for (dx, char) in row.enumerated() where char != "." {
                        if let color = stampColors[char] { set(x + dx, y + dy, color) }
                    }
                }
            }

            func fillRect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: (Int, Int) -> RGB?) {
                for py in y..<(y + h) {
                    for px in x..<(x + w) {
                        if let c = color(px - x, py - y) { set(px, py, c) }
                    }
                }
            }

            // 3. Rozhazene dekorace podle sveta (na mrizce s nahodnym posunem, mimo cestu).
            let grid = 9
            for gy in stride(from: 0, to: rows, by: grid) {
                for gx in stride(from: 0, to: cols, by: grid) {
                    let x = gx + Int(hash(gx, gy, 11) * Double(grid - 4))
                    let y = gy + Int(hash(gx, gy, 12) * Double(grid - 4))
                    guard x < cols, y < rows else { continue }
                    let roll = hash(gx, gy, 13)
                    switch worlds[Int(worldOf[y * cols + x])] {
                    case .farm:
                        if roll < 0.18 { stamp(tree, x, y) } else if roll < 0.24 { stamp(hay, x, y) }
                    case .forest:
                        if roll < 0.42 { stamp(pine, x, y) } else if roll < 0.62 { stamp(tree, x, y) } else if roll < 0.68 { stamp(mushroom, x, y) }
                    case .reef:
                        if noise(x, y, scale: 22, seed: 31) > 0.64 {
                            if roll < 0.25 { stamp(palm, x, y) }
                        } else if roll < 0.10 {
                            stamp(coral, x, y)
                        } else if roll < 0.16 {
                            stamp(coralOrange, x, y)
                        }
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
            for (index, world) in worlds.enumerated() {
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
                    // Hriste s travnikem a bezeckou drahou.
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
                            guard ex * ex + ey * ey <= radius * radius else { return nil }
                            return ex + ey < -radius / 2 ? RGB(250, 240, 220) : color
                        }
                    }
                }
            }
        }

        if step == 1 {
            // Easter egg: krizek v levem dolnim rohu Farm.
            let mark = MapEasterEgg.farmXCell
            for (dy, row) in treasureMark.enumerated() {
                for (dx, char) in row.enumerated() where char != "." {
                    if let color = stampColors[char] { set(mark.x + dx, mark.y + dy, color) }
                }
            }
        }

        // 5. Cesta: hlinena, pres vodu drevene mustky, ve vesmiru svitici kameny.
        // Kruhy se prekryvaji, staci kazdy druhy bod.
        let borderRadius = max(1, 6 / step), roadRadius = max(1, 5 / step)
        for pass in 0..<2 {
            for (index, (cx, cy)) in roadCells.enumerated() where index % 2 == 0 || step > 1 {
                disc(cx, cy, radius: pass == 0 ? borderRadius : roadRadius) { x, y in
                    let world = worlds[Int(worldOf[y * cols + x])]
                    set(x, y, pass == 0 ? roadBorder(world) : roadSurface(world, x: x * step, y: y * step))
                }
            }
        }
        // 6. Okraj mapy jako pixelovy pergamen: zubaty okraj, tmave hnedy a svetly lem, otrhane rohy.
        // Mimo mapu je pruhledno (vidi se tmave pozadi).
        for y in 0..<rows {
            for x in 0..<cols {
                let depth = MapLayout.parchmentDepth(cellX: x * step, cellY: y * step)
                guard depth < 4 else { continue }
                let i = (y * cols + x) * 4
                if depth < 0 {
                    pixels[i] = 0; pixels[i + 1] = 0; pixels[i + 2] = 0; pixels[i + 3] = 0
                } else if depth < 2 {
                    set(x, y, hash(x * step, y * step, 75) > 0.5 ? RGB(86, 54, 30) : RGB(74, 46, 26))
                } else {
                    set(x, y, hash(x * step, y * step, 76) > 0.5 ? RGB(222, 194, 138) : RGB(206, 176, 120))
                }
            }
        }
        return (cols, rows, Array(UnsafeBufferPointer(start: pixels, count: count * 4)))
    }

    /// Zakladni barva terenu sveta v pixelu (x, y) plne mapy. `sky` = pas Orbitu (pro hory a nebe).
    private static func ground(_ world: BossWorld, x: Int, y: Int, sky: (top: Double, height: Double)) -> RGB {
        let fine = hash(x, y, 7)
        switch world {
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
            return noise(x, y, scale: 40, seed: 32) > 0.5 ? RGB(34, 86, 150) : RGB(40, 98, 164)
        case .dojo:
            if noise(x, y, scale: 10, seed: 9) > 0.74 { return fine > 0.5 ? RGB(236, 170, 196) : RGB(222, 150, 182) }
            let terrace = sin(Double(y) * 0.45 + noise(x, y, scale: 30, seed: 8) * 6)
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
            let local = (Double(y) * Double(MapLayout.cell) - sky.top) / sky.height
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

    // MARK: - Zamcene svety: zavoj a mraky

    /// Obrazek prekryvu mapy a kam patri (v bodech mapy).
    struct Overlay: Sendable {
        let width: Int
        let height: Int
        let pixels: [UInt8]
        let frame: CGRect
    }

    /// O kolik bodu mraky presahuji spodni hranici sveta do krajiny pod nim (oble chomacky).
    static let cloudOverhang: CGFloat = 96

    /// Jemny tmavy zavoj pres prvni zamceny svet (krajina je videt, jen ztmavena). Sleduje stejnou
    /// organickou hranici jako teren (MapLayout.worldIndex), takze nikde neni rovny vodorovny okraj.
    /// 1 pixel = 8 bodu, kresli se s vyhlazovanim (mekky okraj). Premultiplied RGBA.
    static func veil(for world: BossWorld) -> Overlay {
        let scale: CGFloat = 8
        let index = BossWorld.allCases.firstIndex(of: world) ?? 0
        let band = MapLayout.band(of: world)
        let top = max(0, band.minY - MapLayout.boundaryReach)
        let bottom = min(MapLayout.size.height, band.maxY + MapLayout.boundaryReach)
        let width = Int(MapLayout.size.width / scale)
        let height = Int(((bottom - top) / scale).rounded(.up))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let alpha = 0.5
        for y in 0..<height {
            let py = top + (CGFloat(y) + 0.5) * scale
            for x in 0..<width {
                let px = (CGFloat(x) + 0.5) * scale
                let cellX = Int(px / MapLayout.cell), cellY = Int(py / MapLayout.cell)
                guard MapLayout.worldIndex(cellX: cellX, cellY: cellY) == index,
                      MapLayout.parchmentDepth(cellX: cellX, cellY: cellY) >= 0 else { continue }
                let i = (y * width + x) * 4
                pixels[i] = UInt8(10 * alpha); pixels[i + 1] = UInt8(10 * alpha); pixels[i + 2] = UInt8(26 * alpha)
                pixels[i + 3] = UInt8(alpha * 255)
            }
        }
        return Overlay(width: width, height: height, pixels: pixels, frame: CGRect(x: 0, y: top, width: MapLayout.size.width, height: CGFloat(height) * scale))
    }

    /// Plne nepruhledne pixelove mraky pres svet (a vse nad nim zakryji mraky vyssich svetu):
    /// zadni bossove ani cesta neprosvitaji. Spodni okraj tvori oble chomacky (pulkruhy ruzne velikosti)
    /// pod organickou hranici sveta, mraky maji tmavsi obrys, stin u spodku a svetle skvrny.
    /// 1 pixel = 8 bodu, kresli se bez vyhlazovani (pixel-art). Okraj mapy (pergamen) nechavaji volny.
    static func clouds(for world: BossWorld) -> Overlay {
        let scale: CGFloat = 8
        let index = BossWorld.allCases.firstIndex(of: world) ?? 0
        let band = MapLayout.band(of: world)
        let top = max(0, band.minY - MapLayout.boundaryReach)
        let bottom = min(MapLayout.size.height, band.maxY + MapLayout.boundaryReach + cloudOverhang)
        let width = Int(MapLayout.size.width / scale)
        let height = Int(((bottom - top) / scale).rounded(.up))
        let seed = index * 19 + 80

        // Nejnizsi radek sveta v kazdem sloupci (organicka hranice).
        var boundary = [Int](repeating: -1, count: width)
        for x in 0..<width {
            let cellX = Int((CGFloat(x) + 0.5) * scale / MapLayout.cell)
            for y in stride(from: height - 1, through: 0, by: -1) {
                let cellY = Int((top + (CGFloat(y) + 0.5) * scale) / MapLayout.cell)
                if MapLayout.worldIndex(cellX: cellX, cellY: cellY) >= index { boundary[x] = y; break }
            }
        }
        // Chomacky: pulkruhy s nahodnym polomerem 3–7 pixelu kazdych ~7 pixelu.
        var puff = [Double](repeating: 1, count: width)
        var center = -4
        while center < width + 8 {
            let radius = 3 + hash(center, index, seed) * 4
            let low = max(0, center - Int(radius)), high = min(width - 1, center + Int(radius))
            if low <= high {
                for x in low...high {
                    let dx = Double(x - center)
                    puff[x] = max(puff[x], max(0, radius * radius - dx * dx).squareRoot())
                }
            }
            center += 5 + Int(hash(center, index, seed + 1) * 4)
        }
        var inside = [Bool](repeating: false, count: width * height)
        for x in 0..<width where boundary[x] >= 0 {
            let limit = Double(boundary[x]) + 1 + puff[x]
            for y in 0..<height where Double(y) <= limit {
                let cellX = Int((CGFloat(x) + 0.5) * scale / MapLayout.cell)
                let cellY = Int((top + (CGFloat(y) + 0.5) * scale) / MapLayout.cell)
                if MapLayout.parchmentDepth(cellX: cellX, cellY: cellY) >= 4 { inside[y * width + x] = true }
            }
        }
        func isCloud(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, y >= 0, x < width, y < height else { return y < 0 }
            return inside[y * width + x]
        }
        let outline = RGB(132, 140, 182), shadow = RGB(190, 198, 226), fill = RGB(232, 236, 248)
        let light = RGB(250, 251, 255), dim = RGB(214, 220, 240)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width where inside[y * width + x] {
                let color: RGB
                if !isCloud(x, y + 1) || !isCloud(x - 1, y) || !isCloud(x + 1, y) {
                    color = outline
                } else if !isCloud(x, y + 2) || !isCloud(x, y + 3) {
                    color = shadow
                } else {
                    let n = noise(x, y, scale: 4, seed: seed + 2)
                    color = n > 0.66 ? light : (n < 0.3 ? dim : fill)
                }
                let i = (y * width + x) * 4
                pixels[i] = color.r; pixels[i + 1] = color.g; pixels[i + 2] = color.b; pixels[i + 3] = 255
            }
        }
        return Overlay(width: width, height: height, pixels: pixels, frame: CGRect(x: 0, y: top, width: MapLayout.size.width, height: CGFloat(height) * scale))
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

/// Hotove obrazky mapy (teren, zavoj a mraky).
/// Teren: kdyz je ulozeny v Caches z minula, nacte se hned. Jinak se nejdriv za zlomek sekundy
/// spocita hruby nahled (1 px = 16 bodu) a ukaze se, pak se na pozadi dopocita plna mapa a ulozi se.
@MainActor
enum MapTerrainCache {
    static var terrain: CGImage?
    private static var overlays: [String: (image: CGImage, frame: CGRect)] = [:]

    /// Pri zmene vzhledu terenu zvysit verzi, aby se stara mapa z Caches nepouzila.
    private static let fileName = "map-terrain-v3.rgba"

    private static var fileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }

    static func loadTerrain(onPreview: (CGImage) -> Void) async -> CGImage? {
        if let terrain { return terrain }
        let expected = MapLayout.columns * MapLayout.rows * 4
        let url = fileURL
        if let url, let data = await Task.detached(priority: .userInitiated, operation: { try? Data(contentsOf: url) }).value,
           data.count == expected,
           let image = MapTerrain.makeImage(width: MapLayout.columns, height: MapLayout.rows, pixels: [UInt8](data)) {
            terrain = image
            return image
        }
        let preview = await Task.detached(priority: .userInitiated) { MapTerrain.render(step: 4) }.value
        if let image = MapTerrain.makeImage(width: preview.width, height: preview.height, pixels: preview.pixels) {
            onPreview(image)
        }
        let full = await Task.detached(priority: .userInitiated) { MapTerrain.render(step: 1) }.value
        let image = MapTerrain.makeImage(width: full.width, height: full.height, pixels: full.pixels)
        terrain = image
        if let url {
            let bytes = full.pixels
            Task.detached(priority: .utility) { try? Data(bytes).write(to: url, options: .atomic) }
        }
        return image
    }

    /// Zavoj prvniho zamceneho sveta.
    static func veil(for world: BossWorld) -> (image: CGImage, frame: CGRect)? {
        overlay(key: "veil-" + world.rawValue) { MapTerrain.veil(for: world) }
    }

    /// Plne mraky nad svetem dal nez jeden za poslednim odemcenym.
    static func clouds(for world: BossWorld) -> (image: CGImage, frame: CGRect)? {
        overlay(key: "clouds-" + world.rawValue) { MapTerrain.clouds(for: world) }
    }

    private static func overlay(key: String, make: () -> MapTerrain.Overlay) -> (image: CGImage, frame: CGRect)? {
        if let cached = overlays[key] { return cached }
        let overlay = make()
        guard let image = MapTerrain.makeImage(width: overlay.width, height: overlay.height, pixels: overlay.pixels) else { return nil }
        overlays[key] = (image, overlay.frame)
        return (image, overlay.frame)
    }
}
