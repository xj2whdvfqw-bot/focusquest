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

        // 1. Zakladni teren kazdeho sveta (vlnita hranice jako MapLayout.worldIndex).
        let worldCount = Double(worlds.count)
        var wave = [Double](repeating: 0, count: cols)
        for x in 0..<cols {
            let xp = (Double(x) + 0.5) * cell
            wave[x] = 40 * sin(xp / 92) + 24 * sin(xp / 36 + 1.3)
        }
        let planets = MapLayout.band(of: .planets)
        let sky = (top: Double(planets.minY), height: Double(max(1, planets.height)))
        for y in 0..<rows {
            let yp = (Double(y) + 0.5) * cell
            for x in 0..<cols {
                let t = Double(MapLayout.progress(y: CGFloat(yp + wave[x])))
                let world = min(worlds.count - 1, max(0, Int((t * worldCount).rounded(.down))))
                worldOf[y * cols + x] = UInt8(world)
                set(x, y, ground(worlds[world], x: x * step, y: y * step, sky: sky))
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

    // MARK: - Mlha nad zamcenym svetem

    /// O kolik bodu mlha presahuje spodni hranici sveta do odemcene krajiny (mekky prechod).
    static let fogOverhang: CGFloat = 96

    /// Mlha nad zamcenym svetem (1 pixel = 16 bodu, kresli se s vyhlazovanim, takze je mekka):
    ///  - jemny tmavy zavoj pres cely svet (krajina je videt, jen ztlumena),
    ///  - u prvniho zamceneho sveta (`frontier`) pas mraku pres hranici s odemcenou krajinou:
    ///    nejhustsi primo na hranici, do 160 bodu nahoru a 96 bodu dolu plynule ridne.
    /// Vraci (sirka, vyska, premultiplied RGBA).
    static func fog(for world: BossWorld, frontier: Bool) -> (width: Int, height: Int, pixels: [UInt8]) {
        let band = MapLayout.band(of: world)
        let scale: CGFloat = 16
        let width = Int(MapLayout.size.width / scale)
        let height = Int(((band.height + fogOverhang) / scale).rounded(.up))
        // Radek, kde je hranice sveta (spodni okraj pasu).
        let border = Double(band.height / scale)
        let above = 10.0, below = Double(fogOverhang / scale)
        let seed = (BossWorld.allCases.firstIndex(of: world) ?? 0) * 17 + 40
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            // Kladne = nad hranici (v zamcenem svete), zaporne = pod ni (v odemcene krajine).
            let distance = border - (Double(y) + 0.5)
            let veilBase = 0.34
            let veil: Double = distance >= 0 ? veilBase : (frontier ? veilBase * max(0, 1 + distance / below) : 0)
            for x in 0..<width {
                var cloud = 0.0
                if frontier {
                    let reach = distance >= 0 ? above : below
                    let falloff = max(0, 1 - abs(distance) / reach)
                    let n = noise(x, y, scale: 5, seed: seed)
                    cloud = min(1, max(0, (n * 0.9 + falloff - 0.78) * 2.4))
                }
                let cloudAlpha = cloud * 0.9
                let alpha = max(veil, cloudAlpha)
                guard alpha > 0.01 else { continue }
                // Barva: tmave modry zavoj, svetle mraky (s jemnym stinovanim podle sumu).
                let mix = alpha > 0 ? cloudAlpha / alpha : 0
                let shade = 214 + 30 * noise(x, y, scale: 3, seed: seed + 7)
                let r = 22 + (shade - 22) * mix
                let g = 24 + (shade - 22) * mix
                let b = 44 + (shade + 12 - 44) * mix
                let a = min(1, alpha)
                let i = (y * width + x) * 4
                pixels[i] = UInt8(min(255, r * a))
                pixels[i + 1] = UInt8(min(255, g * a))
                pixels[i + 2] = UInt8(min(255, b * a))
                pixels[i + 3] = UInt8(a * 255)
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

/// Hotove obrazky mapy (teren a mlha).
/// Teren: kdyz je ulozeny v Caches z minula, nacte se hned. Jinak se nejdriv za zlomek sekundy
/// spocita hruby nahled (1 px = 16 bodu) a ukaze se, pak se na pozadi dopocita plna mapa a ulozi se.
@MainActor
enum MapTerrainCache {
    static var terrain: CGImage?
    private static var fogImages: [String: CGImage] = [:]

    /// Pri zmene vzhledu terenu zvysit verzi, aby se stara mapa z Caches nepouzila.
    private static let fileName = "map-terrain-v2.rgba"

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

    static func fog(for world: BossWorld, frontier: Bool) -> CGImage? {
        let key = world.rawValue + (frontier ? "-edge" : "")
        if let cached = fogImages[key] { return cached }
        let fog = MapTerrain.fog(for: world, frontier: frontier)
        let image = MapTerrain.makeImage(width: fog.width, height: fog.height, pixels: fog.pixels)
        fogImages[key] = image
        return image
    }
}
