import SwiftUI

// Pixelove sceny pozadi z obchodu. Port extraBg() a bgLayout() z design/focusquest.html:
// stejna mrizka 3 pt, stejne barvy, stejny generator nahody. Kresli se ve 4 vrstvach
// (obloha, animovana obloha, krajina, animovane efekty), staticke vrstvy jen jednou.

/// Barva jako v prototypu: slozky 0...1.
struct SceneRGB: Sendable {
    let r: Double, g: Double, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    var color: Color { Color(red: r, green: g, blue: b) }
    static let white = SceneRGB(1, 1, 1)
}

/// Kreslici pomucky nad mrizkou "velkych pixelu" (rect, glow, disc jako painter() v prototypu).
struct ScenePainter {
    let context: GraphicsContext
    let px: CGFloat

    func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: SceneRGB, _ a: Double = 1) {
        guard w > 0, h > 0, a > 0 else { return }
        let frame = CGRect(x: CGFloat(x) * px, y: CGFloat(y) * px, width: CGFloat(w) * px, height: CGFloat(h) * px)
        context.fill(Path(frame), with: .color(c.color.opacity(a)))
    }

    func glow(_ x: Double, _ y: Double, _ radius: Double, _ c: SceneRGB, _ opacity: Double) {
        let center = CGPoint(x: x * Double(px), y: y * Double(px))
        let reach = max(1, radius * Double(px))
        let bounds = CGRect(x: center.x - reach, y: center.y - reach, width: reach * 2, height: reach * 2)
        let gradient = Gradient(colors: [c.color.opacity(opacity), c.color.opacity(0)])
        context.fill(Path(ellipseIn: bounds), with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: reach))
    }

    func disc(_ cx: Int, _ cy: Int, _ r: Int, _ c: SceneRGB, _ a: Double = 1) {
        guard r > 0 else { return }
        for dy in -r...r {
            let half = Int(Double(r * r - dy * dy).squareRoot().rounded())
            rect(cx - half, cy + dy, half * 2 + 1, 1, c, a)
        }
    }
}

/// Stejny generator jako SeededRandom v prototypu, takze sceny vypadaji stejne.
private struct SceneRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992.0 }

    /// Cele cislo lo...hi vcetne (jako R.int v prototypu).
    mutating func int(_ lo: Int, _ hi: Int) -> Int {
        guard hi > lo else { return lo }
        return lo + Int(next() % UInt64(hi - lo + 1))
    }
}

private struct Cloud: Sendable { let x: Int, y: Int, w: Int; let sp: Double }
private struct Bird: Sendable { let x: Int, y: Int; let sp: Double }
private struct Dot: Sendable { let x: Int, y: Int; let c: SceneRGB }
private struct Star: Sendable { let x: Int, y: Int; let b: Double, ph: Double, sp: Double }
private struct Building: Sendable { let x: Int, w: Int, top: Int; let far: Bool }
private struct LitWindow: Sendable { let x: Int, y: Int; let c: SceneRGB; let ph: Double }
private struct Spike: Sendable { let x: Int, w: Int, h: Int }
private struct Speck: Sendable { let x: Int, y: Int; let light: Bool }
private struct Crystal: Sendable { let x: Int, y: Int, h: Int; let c: SceneRGB; let ph: Double }
private struct Drip: Sendable { let x: Int, top: Int; let sp: Double, off: Double }
private struct Car: Sendable { let c: SceneRGB; let lane: Int; let sp: Double }
private struct Turbine: Sendable { let x: Double, base: Double; let h: Int; let sp: Double, ph: Double }

/// Cela scena v mrizce. Spocita se jednou pro velikost obrazovky; vrstvy z ni jen kresli.
struct ShopSceneLayout: Sendable {
    let background: ShopBackground
    let px: CGFloat
    let cols: Int
    let rows: Int
    private var clouds: [Cloud] = []
    private var birds: [Bird] = []
    private var dots: [Dot] = []
    private var stars: [Star] = []
    private var buildings: [Building] = []
    private var windows: [LitWindow] = []
    private var tites: [Spike] = []
    private var mites: [Spike] = []
    private var specks: [Speck] = []
    private var crystals: [Crystal] = []
    private var drips: [Drip] = []

    private static let cars = [
        Car(c: SceneRGB(0.95, 0.25, 0.30), lane: 3, sp: 34),
        Car(c: SceneRGB(0.25, 0.60, 0.98), lane: 9, sp: 27),
        Car(c: SceneRGB(1, 0.82, 0.25), lane: 15, sp: 40),
    ]
    private static let turbines = [
        Turbine(x: 0.22, base: 0.70, h: 46, sp: 1.1, ph: 0),
        Turbine(x: 0.55, base: 0.66, h: 58, sp: 0.9, ph: 1),
        Turbine(x: 0.84, base: 0.72, h: 38, sp: 1.3, ph: 2),
    ]

    init(size: CGSize, background: ShopBackground) {
        self.background = background
        // Mala nebo nulova velikost (prvni pruchod layoutu) by rozbila rozsahy nahody.
        let width = max(size.width, 120), height = max(size.height, 240)
        px = max(3, (width / 128).rounded(.down))
        cols = Int((width / px).rounded(.up)) + 1
        rows = Int((height / px).rounded(.up)) + 1

        switch background {
        case .dawn, .sunset, .pyramids, .race, .farm, .wind:
            let seeds: [ShopBackground: UInt64] = [.dawn: 21, .sunset: 23, .pyramids: 31, .race: 37, .farm: 41, .wind: 43]
            var random = SceneRandom(seed: seeds[background] ?? 1)
            for _ in 0..<6 {
                let x = random.int(0, cols), y = random.int(6, Int(Double(rows) * 0.32)), w = random.int(10, 22)
                clouds.append(Cloud(x: x, y: y, w: w, sp: 0.5 + random.unit()))
            }
            if background == .sunset {
                for _ in 0..<5 {
                    let x = random.int(0, cols), y = random.int(10, Int(Double(rows) * 0.35))
                    birds.append(Bird(x: x, y: y, sp: 2 + random.unit() * 2))
                }
            }
            if background == .race {
                let ty = Int(Double(rows) * 0.73)
                let crowd = [SceneRGB(0.9, 0.3, 0.4), SceneRGB(0.4, 0.7, 1), SceneRGB(1, 0.85, 0.3), SceneRGB(0.9, 0.9, 0.95)]
                for x in stride(from: 0, to: cols, by: 2) {
                    for r in stride(from: 0, to: 10, by: 3) {
                        if random.unit() < 0.6 { dots.append(Dot(x: x, y: ty - 13 + r, c: crowd[random.int(0, 3)])) }
                    }
                }
            }
            if background == .wind {
                let flowers = [SceneRGB(1, 0.9, 0.4), SceneRGB(1, 1, 1), SceneRGB(0.95, 0.55, 0.7)]
                for _ in 0..<70 {
                    let x = random.int(0, cols), y = random.int(Int(Double(rows) * 0.78), rows)
                    dots.append(Dot(x: x, y: y, c: flowers[random.int(0, 2)]))
                }
            }
        case .city, .cave, .space:
            let seeds: [ShopBackground: UInt64] = [.city: 5, .cave: 9, .space: 13]
            var random = SceneRandom(seed: seeds[background] ?? 1)
            let isSpace = background == .space
            for _ in 0..<(isSpace ? 160 : 50) {
                let x = random.int(0, cols - 1), y = random.int(0, Int(Double(rows) * (isSpace ? 1 : 0.35)))
                let b = 0.3 + random.unit() * 0.7, ph = random.unit() * 6.28, sp = 0.5 + random.unit()
                stars.append(Star(x: x, y: y, b: b, ph: ph, sp: sp))
            }
            if background == .city {
                var x = -2
                while x < cols {
                    let w = random.int(8, 16)
                    let h = Int(Double(rows) * (0.18 + random.unit() * 0.30))
                    let top = Int(Double(rows) * 0.9) - h
                    let far = buildings.count % 2 == 0
                    buildings.append(Building(x: x, w: w, top: top, far: far))
                    if !far {
                        var wy = top + 3
                        while Double(wy) < Double(rows) * 0.88 {
                            for wx in stride(from: x + 2, to: x + w - 1, by: 3) {
                                guard random.unit() < 0.45 else { continue }
                                let c = random.unit() < 0.7 ? SceneRGB(1, 0.78, 0.40) : SceneRGB(0.45, 0.85, 1)
                                windows.append(LitWindow(x: wx, y: wy, c: c, ph: random.unit() * 6.28))
                            }
                            wy += 3
                        }
                    }
                    x += w - (far ? 3 : 0)
                }
            }
            if background == .cave {
                var x = 0
                while x < cols {
                    let w = random.int(2, 5), h = random.int(4, Int(Double(rows) * 0.16))
                    tites.append(Spike(x: x, w: w, h: h))
                    x += random.int(3, 7)
                }
                x = 0
                while x < cols {
                    let w = random.int(2, 6), h = random.int(4, Int(Double(rows) * 0.14))
                    mites.append(Spike(x: x, w: w, h: h))
                    x += random.int(4, 9)
                }
                let floor = Int(Double(rows) * 0.80)
                for _ in 0..<260 {
                    let sx = random.int(0, cols), sy = random.int(0, rows)
                    specks.append(Speck(x: sx, y: sy, light: random.unit() < 0.5))
                }
                for i in 0..<14 {
                    let cx = random.int(2, cols - 5)
                    let base = floor + random.int(0, 2)
                    let lift = i % 3 == 0 ? random.int(10, Int(Double(rows) * 0.3)) : 0
                    let h = random.int(5, 13)
                    let c = random.unit() < 0.5 ? SceneRGB(0.45, 0.95, 0.95) : SceneRGB(0.80, 0.50, 1)
                    crystals.append(Crystal(x: cx, y: base - lift, h: h, c: c, ph: random.unit() * 6.28))
                }
                for spike in tites {
                    guard random.unit() < 0.35 else { continue }
                    let sp = 8 + random.unit() * 8
                    drips.append(Drip(x: spike.x + spike.w / 2, top: spike.h + 1, sp: sp, off: random.unit() * 40))
                }
            }
        }
    }

    private func row(_ fraction: Double) -> Int { Int(Double(rows) * fraction) }
    private func col(_ fraction: Double) -> Int { Int(Double(cols) * fraction) }

    private func bands(_ p: ScenePainter, _ list: [SceneRGB], _ top: Int, _ bottom: Int) {
        let bandHeight = max(1, Int((Double(bottom - top) / Double(list.count)).rounded(.up)))
        for (i, c) in list.enumerated() { p.rect(0, top + i * bandHeight, cols, bandHeight + 1, c) }
    }

    private func hill(_ p: ScenePainter, _ base: Double, _ amp: Double, _ freq: Double, _ ph: Double, _ c: SceneRGB) {
        for x in 0..<cols {
            let y = Int(base + sin(Double(x) * freq + ph) * amp)
            p.rect(x, y, 1, rows - y, c)
        }
    }

    private func tri(_ p: ScenePainter, _ cx: Int, _ top: Int, _ h: Int, _ c: SceneRGB, _ shade: SceneRGB) {
        for r in 0..<h {
            p.rect(cx - r, top + r, r + 1, 1, c)
            p.rect(cx + 1, top + r, r, 1, shade)
        }
    }

    private func drawClouds(_ p: ScenePainter, _ t: Double, _ a: Double) {
        for cloud in clouds {
            let x = Int((Double(cloud.x) + t * cloud.sp).truncatingRemainder(dividingBy: Double(cols + 30))) - 15
            p.rect(x, cloud.y, cloud.w, 2, .white, a)
            p.rect(x + 3, cloud.y - 1, cloud.w - 7, 1, .white, a)
            p.rect(x + 2, cloud.y + 2, cloud.w - 4, 1, .white, a * 0.7)
        }
    }

    private func twinkle(_ p: ScenePainter, _ t: Double) {
        for star in stars {
            let wave = 0.5 + 0.5 * sin(t * star.sp * 1.6 + star.ph)
            p.rect(star.x, star.y, 1, 1, SceneRGB(0.93, 0.92, 1), star.b * (0.35 + 0.65 * wave * wave))
        }
    }

    // MARK: Vrstvy

    /// Obloha (staticka).
    func drawSky(_ p: ScenePainter) {
        switch background {
        case .dawn:
            bands(p, [SceneRGB(0.42, 0.60, 0.84), SceneRGB(0.52, 0.68, 0.89), SceneRGB(0.65, 0.77, 0.92), SceneRGB(0.80, 0.84, 0.91), SceneRGB(0.96, 0.87, 0.80)], 0, row(0.72))
            p.rect(0, row(0.7), cols, rows, SceneRGB(0.96, 0.87, 0.80))
            p.glow(Double(cols) * 0.7, Double(rows) * 0.62, Double(cols) * 0.55, SceneRGB(1, 0.9, 0.6), 0.4)
            p.disc(col(0.7), row(0.62), 8, SceneRGB(1, 0.95, 0.78))
        case .sunset:
            bands(p, [SceneRGB(0.20, 0.10, 0.32), SceneRGB(0.42, 0.16, 0.40), SceneRGB(0.72, 0.26, 0.38), SceneRGB(0.95, 0.45, 0.32), SceneRGB(1, 0.66, 0.36)], 0, row(0.74))
            p.rect(0, row(0.72), cols, rows, SceneRGB(1, 0.66, 0.36))
            p.glow(Double(cols) * 0.5, Double(rows) * 0.72, Double(cols) * 0.7, SceneRGB(1, 0.55, 0.3), 0.45)
            p.disc(col(0.5), row(0.72), 14, SceneRGB(1, 0.82, 0.45))
        case .pyramids:
            let gy = row(0.64)
            bands(p, [SceneRGB(0.38, 0.62, 0.88), SceneRGB(0.55, 0.73, 0.90), SceneRGB(0.78, 0.84, 0.86), SceneRGB(0.97, 0.86, 0.66)], 0, gy)
            p.rect(0, gy - 2, cols, rows, SceneRGB(0.97, 0.86, 0.66))
            p.glow(Double(cols) * 0.22, Double(rows) * 0.2, Double(cols) * 0.4, SceneRGB(1, 0.95, 0.7), 0.5)
            p.disc(col(0.22), row(0.2), 7, SceneRGB(1, 0.97, 0.82))
        case .race:
            bands(p, [SceneRGB(0.04, 0.05, 0.14), SceneRGB(0.07, 0.08, 0.22), SceneRGB(0.12, 0.12, 0.30), SceneRGB(0.20, 0.16, 0.36)], 0, row(0.73))
            for x in [0.15, 0.5, 0.85] { p.glow(Double(cols) * x, Double(rows) * 0.14, Double(cols) * 0.3, SceneRGB(1, 0.95, 0.8), 0.28) }
        case .farm:
            let gy = row(0.62)
            bands(p, [SceneRGB(0.40, 0.64, 0.90), SceneRGB(0.52, 0.72, 0.93), SceneRGB(0.68, 0.82, 0.95), SceneRGB(0.84, 0.90, 0.95)], 0, gy)
            p.glow(Double(cols) * 0.82, Double(rows) * 0.14, Double(cols) * 0.35, SceneRGB(1, 0.95, 0.7), 0.5)
            p.disc(col(0.82), row(0.14), 7, SceneRGB(1, 0.96, 0.76))
        case .wind:
            bands(p, [SceneRGB(0.36, 0.60, 0.90), SceneRGB(0.48, 0.70, 0.93), SceneRGB(0.64, 0.80, 0.95), SceneRGB(0.82, 0.90, 0.96)], 0, row(0.72))
            p.rect(0, row(0.7), cols, rows, SceneRGB(0.82, 0.90, 0.96))
        case .city:
            bands(p, [SceneRGB(0.04, 0.03, 0.12), SceneRGB(0.07, 0.04, 0.18), SceneRGB(0.12, 0.05, 0.25), SceneRGB(0.22, 0.07, 0.33), SceneRGB(0.40, 0.12, 0.40)], 0, row(0.75))
            p.rect(0, row(0.75), cols, rows, SceneRGB(0.40, 0.12, 0.40))
            p.glow(Double(cols) / 2, Double(rows) * 0.8, Double(cols) * 0.8, SceneRGB(1, 0.35, 0.65), 0.25)
        case .cave:
            bands(p, [SceneRGB(0.07, 0.05, 0.09), SceneRGB(0.11, 0.08, 0.13), SceneRGB(0.15, 0.10, 0.17), SceneRGB(0.13, 0.09, 0.15), SceneRGB(0.09, 0.07, 0.11)], 0, rows)
            for speck in specks { p.rect(speck.x, speck.y, 2, 1, speck.light ? SceneRGB(0.24, 0.18, 0.27) : SceneRGB(0.05, 0.04, 0.06), 0.6) }
            p.glow(Double(cols) * 0.5, Double(rows) * 0.62, Double(cols) * 0.7, SceneRGB(0.35, 0.55, 0.95), 0.16)
        case .space:
            bands(p, [SceneRGB(0.01, 0.01, 0.04), SceneRGB(0.02, 0.02, 0.07), SceneRGB(0.04, 0.02, 0.10), SceneRGB(0.03, 0.02, 0.08)], 0, rows)
            p.glow(Double(cols) * 0.25, Double(rows) * 0.6, Double(cols) * 0.55, SceneRGB(0.55, 0.20, 0.75), 0.28)
            p.glow(Double(cols) * 0.7, Double(rows) * 0.75, Double(cols) * 0.45, SceneRGB(0.15, 0.45, 0.85), 0.22)
        }
    }

    /// Animovana obloha za krajinou: mraky, ptaci, hvezdy.
    func drawSkyEffects(_ p: ScenePainter, time t: Double) {
        switch background {
        case .dawn, .farm: drawClouds(p, t, 0.9)
        case .wind: drawClouds(p, t, 0.85)
        case .sunset:
            let ink = SceneRGB(0.15, 0.06, 0.15)
            for bird in birds {
                let x = Int((Double(bird.x) + t * bird.sp).truncatingRemainder(dividingBy: Double(cols + 10))) - 5
                let lift = sin(t * 6 + Double(bird.x)) > 0 ? 1 : 0
                p.rect(x, bird.y, 1, 1, ink)
                p.rect(x - 1, bird.y - lift, 1, 1, ink)
                p.rect(x + 1, bird.y - lift, 1, 1, ink)
            }
        case .city, .space: twinkle(p, t)
        case .pyramids, .race, .cave: break
        }
    }

    /// Krajina (staticka).
    func drawLand(_ q: ScenePainter) {
        switch background {
        case .dawn:
            hill(q, Double(rows) * 0.67, 4, 0.05, 1, SceneRGB(0.62, 0.76, 0.68))
            hill(q, Double(rows) * 0.75, 5, 0.07, 3, SceneRGB(0.44, 0.65, 0.48))
            hill(q, Double(rows) * 0.85, 4, 0.04, 0, SceneRGB(0.30, 0.52, 0.36))
        case .sunset:
            hill(q, Double(rows) * 0.70, 5, 0.06, 2, SceneRGB(0.30, 0.12, 0.30))
            hill(q, Double(rows) * 0.78, 6, 0.045, 5, SceneRGB(0.18, 0.07, 0.20))
            hill(q, Double(rows) * 0.88, 3, 0.05, 1, SceneRGB(0.10, 0.04, 0.12))
        case .pyramids:
            let gy = row(0.64)
            tri(q, col(0.24), gy - 40, 42, SceneRGB(0.90, 0.72, 0.42), SceneRGB(0.72, 0.52, 0.28))
            tri(q, col(0.64), gy - 56, 58, SceneRGB(0.93, 0.76, 0.46), SceneRGB(0.74, 0.55, 0.30))
            tri(q, col(0.92), gy - 26, 28, SceneRGB(0.88, 0.70, 0.40), SceneRGB(0.70, 0.50, 0.27))
            hill(q, Double(gy), 2, 0.08, 0, SceneRGB(0.92, 0.76, 0.48))
            hill(q, Double(rows) * 0.84, 4, 0.05, 2, SceneRGB(0.86, 0.68, 0.40))
            hill(q, Double(rows) * 0.93, 3, 0.07, 4, SceneRGB(0.78, 0.60, 0.34))
        case .race: drawRaceTrack(q)
        case .farm: drawFarm(q)
        case .wind:
            hill(q, Double(rows) * 0.66, 4, 0.05, 2, SceneRGB(0.56, 0.78, 0.50))
            hill(q, Double(rows) * 0.74, 5, 0.06, 4, SceneRGB(0.44, 0.70, 0.40))
            hill(q, Double(rows) * 0.86, 4, 0.04, 1, SceneRGB(0.34, 0.60, 0.32))
            for dot in dots { q.rect(dot.x, dot.y, 1, 1, dot.c) }
            for turbine in Self.turbines {
                let x = col(turbine.x), base = row(turbine.base)
                for r in 0..<turbine.h {
                    let upper = Double(r) > Double(turbine.h) * 0.6
                    q.rect(x - (upper ? 1 : 0), base - r, upper ? 3 : 2, 1, SceneRGB(0.96, 0.97, 1))
                }
                q.rect(x - 1, base - turbine.h - 1, 4, 3, SceneRGB(0.92, 0.93, 0.96))
            }
        case .city:
            for b in buildings where b.far { q.rect(b.x, b.top - 6, b.w, rows, SceneRGB(0.10, 0.07, 0.20)) }
            for b in buildings where !b.far {
                q.rect(b.x, b.top, b.w, rows, SceneRGB(0.05, 0.04, 0.11))
                q.rect(b.x, b.top, b.w, 1, SceneRGB(0.30, 0.20, 0.45))
                if b.w > 10 { q.rect(b.x + b.w / 2, b.top - 4, 1, 4, SceneRGB(0.05, 0.04, 0.11)) }
            }
            q.rect(0, row(0.9), cols, rows, SceneRGB(0.03, 0.02, 0.07))
        case .cave: drawCave(q)
        case .space: drawPlanet(q)
        }
    }

    /// Animovane efekty pred krajinou: velbloud, auta, vrtule, okna, krystaly, kapky, kometa.
    func drawEffects(_ f: ScenePainter, time t: Double) {
        switch background {
        case .pyramids:
            let x = Int(Double(cols) - (t * 2).truncatingRemainder(dividingBy: Double(cols + 20)))
            let y = row(0.82) - 1
            let c = SceneRGB(0.35, 0.24, 0.14)
            f.rect(x, y - 4, 6, 3, c); f.rect(x + 1, y - 5, 2, 1, c); f.rect(x + 3, y - 6, 2, 2, c)
            f.rect(x - 2, y - 7, 2, 4, c); f.rect(x - 3, y - 8, 2, 2, c)
            let step = sin(t * 5) > 0 ? 1 : 0
            f.rect(x + step, y - 1, 1, 3, c); f.rect(x + 4 - step, y - 1, 1, 3, c)
        case .race:
            let ty = row(0.73), tyre = SceneRGB(0.05, 0.05, 0.05)
            for car in Self.cars {
                let x = Int((t * car.sp).truncatingRemainder(dividingBy: Double(cols + 20))) - 12, y = ty + car.lane
                f.rect(x, y, 9, 2, car.c); f.rect(x + 2, y - 1, 4, 1, car.c); f.rect(x + 3, y - 1, 2, 1, SceneRGB(0.6, 0.85, 1))
                f.rect(x + 1, y + 2, 2, 1, tyre); f.rect(x + 6, y + 2, 2, 1, tyre); f.rect(x - 4, y + 1, 3, 1, .white, 0.25)
            }
        case .wind:
            for turbine in Self.turbines {
                let hx = col(turbine.x) + 1, hy = row(turbine.base) - turbine.h, length = Int(Double(turbine.h) * 0.45)
                for k in 0..<3 {
                    let angle = t * turbine.sp + turbine.ph + Double(k) * 2.094
                    for i in 1...max(1, length) {
                        let x = Int((Double(hx) + cos(angle) * Double(i)).rounded())
                        let y = Int((Double(hy) + sin(angle) * Double(i)).rounded())
                        f.rect(x, y, Double(i) < Double(length) * 0.6 ? 2 : 1, 1, .white)
                    }
                }
                f.rect(hx - 1, hy - 1, 3, 3, SceneRGB(0.80, 0.82, 0.88))
            }
        case .city:
            for window in windows where sin(t * 0.4 + window.ph * 3) > -0.85 { f.rect(window.x, window.y, 1, 1, window.c, 0.85) }
            // Letadlo s blikajicim svetlem.
            let cx = (t * 6).truncatingRemainder(dividingBy: Double(cols + 20)) - 10
            if sin(t * 6) > 0 { f.rect(Int(cx), row(0.2), 2, 1, SceneRGB(1, 0.3, 0.3), 0.9) }
        case .cave:
            let floor = row(0.80)
            for crystal in crystals {
                f.glow(Double(crystal.x) + 1.5, Double(crystal.y) - Double(crystal.h) / 2, 14, crystal.c, 0.30 + 0.14 * sin(t * 1.3 + crystal.ph))
            }
            for drip in drips {
                let fall = Double(max(1, floor - drip.top))
                let y = Double(drip.top) + (t * drip.sp + drip.off).truncatingRemainder(dividingBy: fall)
                f.rect(drip.x, Int(y), 1, 2, SceneRGB(0.55, 0.80, 1), 0.7)
            }
        case .space:
            // Kometa jednou za 7 s.
            let loop = t.truncatingRemainder(dividingBy: 7)
            if loop < 1 {
                let hx = Double(cols) * (0.1 + loop * 0.5), hy = Double(rows) * (0.12 + loop * 0.1)
                for i in 0..<10 {
                    f.rect(Int(hx) - i * 2, Int(hy - Double(i) * 0.5), 2, 1, SceneRGB(0.9, 0.95, 1), (1 - Double(i) / 10) * (1 - loop * 0.5))
                }
            }
        case .dawn, .sunset, .farm: break
        }
    }

    // MARK: Slozitejsi krajiny

    private func drawRaceTrack(_ q: ScenePainter) {
        let ty = row(0.73), poleTop = row(0.12)
        let white = SceneRGB(0.95, 0.95, 0.95), red = SceneRGB(0.9, 0.2, 0.25), paint = SceneRGB(0.9, 0.9, 0.9)
        for x in [0.15, 0.5, 0.85] {
            let lx = col(x)
            q.rect(lx, poleTop, 1, ty - poleTop, SceneRGB(0.25, 0.25, 0.32))
            q.rect(lx - 3, poleTop, 7, 2, SceneRGB(1, 0.96, 0.82))
        }
        for r in 0..<14 { q.rect(0, ty - 14 + r, cols, 1, r % 3 == 0 ? SceneRGB(0.18, 0.16, 0.26) : SceneRGB(0.12, 0.11, 0.19)) }
        for dot in dots { q.rect(dot.x, dot.y, 1, 1, dot.c, 0.8) }
        q.rect(0, ty, cols, 2, white)
        for x in stride(from: 0, to: cols, by: 4) { q.rect(x, ty, 2, 2, red) }
        q.rect(0, ty + 2, cols, 20, SceneRGB(0.22, 0.22, 0.26))
        for x in stride(from: 0, to: cols, by: 8) {
            q.rect(x, ty + 8, 4, 1, paint, 0.8)
            q.rect(x + 4, ty + 14, 4, 1, paint, 0.8)
        }
        q.rect(0, ty + 22, cols, 2, white)
        for x in stride(from: 2, to: cols, by: 4) { q.rect(x, ty + 22, 2, 2, red) }
        q.rect(0, ty + 24, cols, rows, SceneRGB(0.16, 0.38, 0.20))
        // Cilova cara.
        for r in 0..<20 { q.rect(col(0.7) + r % 2, ty + 2 + r, 1, 1, r % 2 == 1 ? SceneRGB(0.1, 0.1, 0.1) : .white) }
    }

    private func drawFarm(_ q: ScenePainter) {
        let gy = row(0.62), bx = col(0.58), bw = 30, bh = 20
        let white = SceneRGB(0.95, 0.95, 0.95), barn = SceneRGB(0.72, 0.16, 0.16), dark = SceneRGB(0.45, 0.12, 0.12)
        hill(q, Double(gy - 2), 3, 0.04, 1, SceneRGB(0.50, 0.72, 0.42))
        if gy + 2 < rows {
            for r in (gy + 2)..<rows { q.rect(0, r, cols, 1, ((r - gy) / 4) % 2 == 1 ? SceneRGB(0.86, 0.74, 0.36) : SceneRGB(0.42, 0.66, 0.34)) }
        }
        let top = gy + 6 - bh
        q.rect(bx, top, bw, bh, barn)
        for r in 0..<10 { q.rect(bx - 2 + r, top - r, bw + 4 - r * 2, 1, r == 0 ? white : dark) }
        q.rect(bx + 11, top + 8, 8, 12, white)
        q.rect(bx + 12, top + 9, 6, 11, SceneRGB(0.55, 0.12, 0.12))
        for i in 0..<6 {
            q.rect(bx + 12 + i, top + 9 + i * 2, 1, 2, white)
            q.rect(bx + 17 - i, top + 9 + i * 2, 1, 2, white)
        }
        q.rect(bx + 13, top - 6, 4, 4, white)
        q.rect(bx + 14, top - 5, 2, 2, dark)
        // Silo.
        q.rect(bx - 12, top + 2, 8, bh - 2, SceneRGB(0.85, 0.85, 0.82))
        q.disc(bx - 8, top + 2, 4, SceneRGB(0.70, 0.72, 0.78))
        // Plot.
        let fy = gy + 10, rail = SceneRGB(0.75, 0.58, 0.38)
        q.rect(0, fy, cols, 1, rail)
        q.rect(0, fy + 3, cols, 1, rail)
        for x in stride(from: 1, to: cols, by: 6) { q.rect(x, fy - 1, 1, 6, SceneRGB(0.62, 0.45, 0.28)) }
    }

    private func drawCave(_ q: ScenePainter) {
        let rock = SceneRGB(0.20, 0.15, 0.21), edge = SceneRGB(0.34, 0.27, 0.36), floor = row(0.80)
        for spike in tites {
            for r in 0..<spike.h {
                let w = max(1, spike.w - (r * spike.w) / spike.h)
                q.rect(spike.x + (spike.w - w) / 2, r, w, 1, rock)
            }
            q.rect(spike.x, 0, 1, max(1, spike.h - 2), edge)
        }
        q.rect(0, floor, cols, rows, rock)
        q.rect(0, floor, cols, 1, edge)
        for spike in mites {
            for r in 0..<spike.h {
                let w = max(1, (r * spike.w) / spike.h + 1)
                q.rect(spike.x + (spike.w - w) / 2, floor - spike.h + r, w, 1, rock)
            }
        }
        for crystal in crystals {
            for r in 0..<crystal.h {
                let w = r < 2 ? 1 : r < 4 ? 3 : 4
                q.rect(crystal.x + (w == 1 ? 1 : w == 3 ? 0 : -1) + 1, crystal.y - crystal.h + r, w, 1, crystal.c, 0.95)
                if r > 1 && r < crystal.h - 2 { q.rect(crystal.x + 1, crystal.y - crystal.h + r, 1, 1, .white, 0.35) }
            }
        }
    }

    private func drawPlanet(_ q: ScenePainter) {
        let px0 = col(0.66), py0 = row(0.32), pr = max(10, cols / 7)
        q.disc(px0, py0, pr, SceneRGB(0.85, 0.52, 0.30))
        // Pruhy jen uvnitr planety.
        for dy in stride(from: -pr, through: pr, by: 3) {
            let half = Int(Double(pr * pr - dy * dy).squareRoot().rounded())
            q.rect(px0 - half, py0 + dy, half * 2 + 1, 1, SceneRGB(0.70, 0.38, 0.24), 0.45)
        }
        for dy in -pr...pr {
            let half = Int(Double(pr * pr - dy * dy).squareRoot().rounded()), shade = max(0, half / 2)
            q.rect(px0 + half - shade + 1, py0 + dy, shade, 1, SceneRGB(0.25, 0.12, 0.18), 0.55)
        }
        // Prstenec: za planetou se schova horni pulka.
        for x in (-pr * 2)...(pr * 2) {
            let y = Int(Double(py0) + Double(x) * 0.18)
            let behind = abs(x) < pr && y < py0 + 1
            if !behind { q.rect(px0 + x, y, 1, 1, SceneRGB(0.95, 0.85, 0.65), 0.85) }
        }
        q.disc(col(0.2), row(0.82), 5, SceneRGB(0.55, 0.58, 0.68))
    }
}

/// Pozadi z obchodu pres celou obrazovku. Animace bezi 12 snimku za sekundu
/// a zastavi se, kdyz je appka na pozadi nebo je zapnute Omezit pohyb.
struct ShopSceneBackdrop: View {
    let background: ShopBackground
    let paused: Bool
    /// Omezit pohyb: scena stoji v pocatecnim stavu.
    let frozen: Bool

    var body: some View {
        GeometryReader { proxy in
            let layout = ShopSceneLayout(size: proxy.size, background: background)
            ZStack {
                Canvas(opaque: true, rendersAsynchronously: true) { context, _ in
                    layout.drawSky(ScenePainter(context: context, px: layout.px))
                }
                TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: paused)) { timeline in
                    let time = frozen ? 0 : Self.sceneTime(timeline.date)
                    Canvas(opaque: false, rendersAsynchronously: true) { context, _ in
                        layout.drawSkyEffects(ScenePainter(context: context, px: layout.px), time: time)
                    }
                }
                Canvas(opaque: false, rendersAsynchronously: true) { context, _ in
                    layout.drawLand(ScenePainter(context: context, px: layout.px))
                }
                TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: paused)) { timeline in
                    let time = frozen ? 0 : Self.sceneTime(timeline.date)
                    Canvas(opaque: false, rendersAsynchronously: true) { context, _ in
                        layout.drawEffects(ScenePainter(context: context, px: layout.px), time: time)
                    }
                }
            }
        }
    }

    /// Mensi cisla nez cas od roku 2001, aby sin() a zbytky po deleni zustaly presne.
    static func sceneTime(_ date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86_400) + 100
    }
}

/// Staticky nahled pozadi v obchode (92 x 132): scena pro telefon 402 x 874, zmensena a zarovnana dolu.
struct ShopSceneThumbnail: View {
    /// nil = World scenes (nahled jedne ze scen svetu).
    let background: ShopBackground?

    static let sceneSize = CGSize(width: 402, height: 874)

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let scale = size.width / Self.sceneSize.width
            var scaled = context
            scaled.translateBy(x: 0, y: size.height - Self.sceneSize.height * scale)
            scaled.scaleBy(x: scale, y: scale)
            if let background {
                let layout = ShopSceneLayout(size: Self.sceneSize, background: background)
                let painter = ScenePainter(context: scaled, px: layout.px)
                layout.drawSky(painter)
                layout.drawSkyEffects(painter, time: 3)
                layout.drawLand(painter)
                layout.drawEffects(painter, time: 3)
            } else {
                WorldSceneThumbnail.draw(scaled, size: Self.sceneSize, scene: .lanternGrove)
            }
        }
        .frame(width: 92, height: 132)
        .background(Color(red: 11 / 255, green: 9 / 255, blue: 24 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Prostredi

private struct ShopBackgroundKey: EnvironmentKey {
    static let defaultValue: ShopBackground? = nil
}

extension EnvironmentValues {
    /// Pozadi z obchodu, ktere nahradi krajiny svetu (nil = World scenes).
    var shopBackground: ShopBackground? {
        get { self[ShopBackgroundKey.self] }
        set { self[ShopBackgroundKey.self] = newValue }
    }
}

/// Posila zvolene (nebo prave zkousene) pozadi vsem obrazovkam pod sebou.
struct ActiveShopBackground: ViewModifier {
    @ObservedObject var model: ProfileViewModel

    func body(content: Content) -> some View {
        content.environment(\.shopBackground, model.activeBackground)
    }
}
