import SwiftUI

/// Pixelova krajina za obrazovkou. Kazda zalozka ma vlastni variantu.
enum BackdropScene: Sendable, CaseIterable {
    /// Zacarovany les za soumraku s lucernami a vzdalenym hradem.
    case enchantedForest
    /// Zamlzene trosky zalaru, hrad v dalce.
    case dungeonRuins
    /// Velky hrad nad vesnici.
    case castleKeep
    /// Haj plny lucern.
    case lanternGrove
    /// Vysoke hory pod hvezdnou oblohou.
    case starlitPeaks
}

/// Pozadi vsech obrazovek: temna fantasy pixel-art krajina (hvezdna obloha, mesic, hory,
/// silueta hradu, trosky, mlha, pokrouceny les a svitici lucerny). Kresli se kodem pres Canvas,
/// takze nepotrebuje obrazky. Staticke vrstvy se kresli jednou, animuji se jen hvezdy,
/// mlha, lucerny, okna hradu a svetlusky. Sklenene karty krajinu rozmazou.
struct FocusQuestBackdrop: View {
    var alert = false
    var scene: BackdropScene = .enchantedForest
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// Pozadi z obchodu nahradi krajinu sveta na vsech obrazovkach.
    @Environment(\.shopBackground) private var shopBackground

    /// Animace stoji pri Omezit pohyb a kdyz appka neni v popredi.
    private var paused: Bool { reduceMotion || scenePhase != .active }

    var body: some View {
        ZStack {
            if let shopBackground {
                ShopSceneBackdrop(background: shopBackground, paused: paused, frozen: reduceMotion)
            } else {
                worldScene
            }
            scrims
            // Varovani pri zvednuti telefonu: cela plocha zcervena.
            LinearGradient(colors: [FQColor.alarm.opacity(0.55), FQColor.danger.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .opacity(alert ? 1 : 0)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: alert)
        .accessibilityHidden(true)
    }

    private var worldScene: some View {
        GeometryReader { proxy in
            let layout = PixelLayout(size: proxy.size, scene: scene)
            ZStack {
                Canvas(opaque: true, rendersAsynchronously: true) { context, _ in
                    PixelPainter(context: context, px: layout.px).drawSky(layout)
                }
                TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: paused)) { timeline in
                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    Canvas(opaque: false, rendersAsynchronously: true) { context, _ in
                        PixelPainter(context: context, px: layout.px).drawStars(layout, time: time)
                    }
                }
                Canvas(opaque: false, rendersAsynchronously: true) { context, _ in
                    PixelPainter(context: context, px: layout.px).drawLandscape(layout)
                }
                TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: paused)) { timeline in
                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    Canvas(opaque: false, rendersAsynchronously: true) { context, _ in
                        PixelPainter(context: context, px: layout.px).drawEffects(layout, time: time)
                    }
                }
            }
        }
    }

    /// Ztmaveni nahore (nadpisy) a dole (lista zalozek), aby text vzdy vynikl.
    @ViewBuilder private var scrims: some View {
        if shopBackground?.isLight == true {
            // Svetla pozadi (Daybreak, Pyramids, Farm, Wind Farm): silnejsi ztmaveni nahore a dole.
            LinearGradient(
                stops: [
                    .init(color: Self.lightScrim.opacity(0.55), location: 0),
                    .init(color: Self.lightScrim.opacity(0.18), location: 0.26),
                    .init(color: Self.lightScrim.opacity(0.12), location: 0.60),
                    .init(color: Self.lightScrim.opacity(0.55), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            darkScrims
        }
    }

    private static let lightScrim = Color(red: 5 / 255, green: 4 / 255, blue: 16 / 255)

    private var darkScrims: some View {
        ZStack {
            Color.black.opacity(0.10)
            LinearGradient(
                stops: [.init(color: Color.black.opacity(0.50), location: 0), .init(color: Color.black.opacity(0), location: 0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                stops: [.init(color: Color.black.opacity(0), location: 0.70), .init(color: Color.black.opacity(0.55), location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Paleta

private enum PixelPalette {
    /// Obloha od zenitu k obzoru: temne modra -> fialova -> ruzovy soumrak.
    static let sky: [Color] = [
        Color(red: 0.035, green: 0.031, blue: 0.098),
        Color(red: 0.051, green: 0.043, blue: 0.137),
        Color(red: 0.071, green: 0.055, blue: 0.180),
        Color(red: 0.102, green: 0.071, blue: 0.231),
        Color(red: 0.141, green: 0.086, blue: 0.275),
        Color(red: 0.196, green: 0.106, blue: 0.310),
        Color(red: 0.263, green: 0.129, blue: 0.329),
        Color(red: 0.341, green: 0.165, blue: 0.341)
    ]
    static let star = Color(red: 0.93, green: 0.92, blue: 1.00)
    static let moon = Color(red: 0.93, green: 0.90, blue: 0.78)
    static let moonShade = Color(red: 0.74, green: 0.70, blue: 0.62)
    static let moonGlow = Color(red: 0.78, green: 0.74, blue: 1.00)
    static let farMountain = Color(red: 0.149, green: 0.110, blue: 0.251)
    static let farRim = Color(red: 0.239, green: 0.188, blue: 0.369)
    static let snow = Color(red: 0.471, green: 0.431, blue: 0.620)
    static let castle = Color(red: 0.094, green: 0.071, blue: 0.180)
    static let window = Color(red: 1.00, green: 0.76, blue: 0.38)
    static let midHill = Color(red: 0.075, green: 0.059, blue: 0.141)
    static let ruin = Color(red: 0.180, green: 0.153, blue: 0.282)
    static let ruinLight = Color(red: 0.290, green: 0.255, blue: 0.420)
    static let mist = Color(red: 0.72, green: 0.66, blue: 0.94)
    static let near = Color(red: 0.035, green: 0.027, blue: 0.071)
    static let rim = Color(red: 0.165, green: 0.145, blue: 0.290)
    static let lanternFrame = Color(red: 0.20, green: 0.13, blue: 0.10)
    static let lanternCore = Color(red: 1.00, green: 0.80, blue: 0.42)
    static let lanternGlow = Color(red: 1.00, green: 0.66, blue: 0.30)
    static let firefly = Color(red: 0.86, green: 1.00, blue: 0.55)
}

// MARK: - Geometrie sceny

private struct GridRect: Sendable {
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

private struct GridPoint: Sendable {
    let x: Int
    let y: Int
}

private struct LanternSpot: Sendable {
    /// Stred tela lucerny a jeho horni radek.
    let x: Int
    let y: Int
    /// Delka provazku nad lucernou.
    let drop: Int
}

private struct StarSpec: Sendable {
    let x: Int
    let y: Int
    let brightness: Double
    let phase: Double
    let speed: Double
    let isBright: Bool
}

private struct FireflySpec: Sendable {
    let x: Double
    let y: Double
    let range: Double
    let speedX: Double
    let speedY: Double
    let phase: Double
}

private struct MistWisp: Sendable {
    let row: Int
    let length: Int
    let speed: Double
    let offset: Double
    let opacity: Double
}

/// Nastaveni jedne varianty krajiny.
private struct SceneConfig {
    let seed: UInt64
    let moonX: Double
    let castleX: Double?
    let castleScale: Int
    let ruinsX: Double?
    let bareTrees: [Double]
    let lanternPosts: [Double]
    let mountainHeight: Double
    let mist: Double
}

extension BackdropScene {
    // Mesic je vzdy vpravo mezi koncem nadpisu a ozubenym kolem (0.75-0.77 sirky)
    // a nad radkem nadpisu (viz moonY), aby nikdy nebyl za textem.
    fileprivate var config: SceneConfig {
        switch self {
        case .enchantedForest:
            SceneConfig(seed: 11, moonX: 0.76, castleX: 0.30, castleScale: 1, ruinsX: nil, bareTrees: [0.34, 0.66], lanternPosts: [0.50], mountainHeight: 0.10, mist: 1.0)
        case .dungeonRuins:
            SceneConfig(seed: 23, moonX: 0.75, castleX: 0.74, castleScale: 1, ruinsX: 0.46, bareTrees: [0.28, 0.78], lanternPosts: [0.62], mountainHeight: 0.08, mist: 1.6)
        case .castleKeep:
            SceneConfig(seed: 37, moonX: 0.77, castleX: 0.44, castleScale: 2, ruinsX: nil, bareTrees: [0.76], lanternPosts: [0.22, 0.58], mountainHeight: 0.09, mist: 1.0)
        case .lanternGrove:
            SceneConfig(seed: 53, moonX: 0.76, castleX: nil, castleScale: 1, ruinsX: 0.70, bareTrees: [0.24, 0.48, 0.76], lanternPosts: [0.36, 0.62], mountainHeight: 0.07, mist: 1.2)
        case .starlitPeaks:
            SceneConfig(seed: 71, moonX: 0.76, castleX: 0.28, castleScale: 1, ruinsX: nil, bareTrees: [0.58], lanternPosts: [], mountainHeight: 0.16, mist: 0.8)
        }
    }
}

/// Deterministicky generator nahody: stejna scena vypada pokazde stejne.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / 9_007_199_254_740_992.0
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let count = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % count)
    }
}

/// Cela krajina v mrizce "velkych pixelu". Spocita se jednou pro danou velikost obrazovky;
/// statické i animovane vrstvy z ni jen kresli.
private struct PixelLayout: Sendable {
    let px: CGFloat
    let cols: Int
    let rows: Int
    let skyBottom: Int
    let moonX: Int
    let moonY: Int
    let moonRadius: Int
    let farRidge: [Int]
    let snowLine: Int
    let midRidge: [Int]
    let groundRidge: [Int]
    let castleRects: [GridRect]
    let castleWindows: [GridPoint]
    let ruinRects: [GridRect]
    let ruinLights: [GridRect]
    let treeRects: [GridRect]
    let rimRects: [GridRect]
    let lanterns: [LanternSpot]
    let grass: [GridRect]
    let stars: [StarSpec]
    let fireflies: [FireflySpec]
    let wisps: [MistWisp]
    let mistRow: Int
    let mistStrength: Double

    init(size: CGSize, scene: BackdropScene) {
        let config = scene.config
        var random = SeededRandom(seed: config.seed)
        let pixel: CGFloat = max(3, (size.width / 128).rounded(.down))
        let cols = max(16, Int((size.width / pixel).rounded(.up)) + 1)
        let rows = max(32, Int((size.height / pixel).rounded(.up)) + 1)
        let rowsD = Double(rows)
        px = pixel
        self.cols = cols
        self.rows = rows
        skyBottom = Int(rowsD * 0.46)

        // Mesic
        // Mensi a vys nez drive: sedi vedle nadtitulku, nad radkem velkeho nadpisu
        // (drive zasahoval do konce dlouhych nadpisu jako "Choose a world").
        moonRadius = max(5, cols / 16)
        moonX = Int(Double(cols) * config.moonX)
        moonY = Int(rowsD * 0.075)

        // Vzdalene hory: spicate hrebeny ze slozenych sinusovek.
        let farBase = rowsD * 0.33
        let farAmplitude = rowsD * config.mountainHeight
        let phaseA = random.unit() * 6.28
        let phaseB = random.unit() * 6.28
        let phaseC = random.unit() * 6.28
        var far: [Int] = []
        far.reserveCapacity(cols)
        for x in 0..<cols {
            let fx = Double(x) * 0.055
            let peak: Double = 1 - abs(sin(fx + phaseA))
            let detail: Double = sin(fx * 3.1 + phaseB) * 0.18 + sin(fx * 7.3 + phaseC) * 0.07
            far.append(Int((farBase - farAmplitude * (peak * 0.8 + detail)).rounded()))
        }
        farRidge = far
        snowLine = Int(farBase - farAmplitude * 0.62)

        // Blizsi kopce (mekci)
        let midBase = rowsD * 0.43
        let midPhase = random.unit() * 6.28
        var mid: [Int] = []
        mid.reserveCapacity(cols)
        for x in 0..<cols {
            let fx = Double(x) * 0.08
            let wave: Double = sin(fx + midPhase) * 0.6 + sin(fx * 2.7 + midPhase * 2) * 0.4
            mid.append(Int((midBase - rowsD * 0.025 * wave).rounded()))
        }
        midRidge = mid
        mistRow = Int(midBase) - 4
        mistStrength = config.mist

        // Zeme s travou
        let groundBase = rowsD * 0.90
        var ground: [Int] = []
        var grassRects: [GridRect] = []
        for x in 0..<cols {
            let wave: Double = sin(Double(x) * 0.17 + phaseA) * 1.2
            let top = Int((groundBase + wave).rounded())
            ground.append(top)
            if random.unit() < 0.4 {
                let height = random.int(1...2)
                grassRects.append(GridRect(x: x, y: top - height, w: 1, h: height))
            }
        }
        groundRidge = ground
        grass = grassRects

        // Hrad
        if let castleFraction = config.castleX {
            let centerX = Int(Double(cols) * castleFraction)
            let base = mid[min(cols - 1, max(0, centerX))] + 2
            let castle = PixelLayout.castle(centerX: centerX, base: base, scale: config.castleScale)
            castleRects = castle.rects
            castleWindows = castle.windows
        } else {
            castleRects = []
            castleWindows = []
        }

        // Trosky
        if let ruinsFraction = config.ruinsX {
            let centerX = Int(Double(cols) * ruinsFraction)
            let base = Int(rowsD * 0.62)
            let ruins = PixelLayout.ruins(centerX: centerX, base: base, bottom: rows)
            ruinRects = ruins.rects
            ruinLights = ruins.lights
        } else {
            ruinRects = []
            ruinLights = []
        }

        // Stromy: dva velke po okrajich (ramuji obrazovku) a pokroucene holé stromy mezi nimi.
        var trees: [GridRect] = []
        var rims: [GridRect] = []
        var tips: [GridPoint] = []
        let canopy = max(8, cols / 7)
        let edgeTop = Int(rowsD * 0.08)
        let leftX = 3
        let rightX = cols - 4
        PixelLayout.edgeTree(x: leftX, base: ground[min(cols - 1, leftX)], top: edgeTop, canopy: canopy, inward: 1, random: &random, rects: &trees, rims: &rims)
        PixelLayout.edgeTree(x: rightX, base: ground[min(cols - 1, max(0, rightX))], top: edgeTop + 6, canopy: canopy, inward: -1, random: &random, rects: &trees, rims: &rims)
        for fraction in config.bareTrees {
            let x = Int(Double(cols) * fraction)
            let base = ground[min(cols - 1, max(0, x))]
            let height = Int(rowsD * (0.24 + random.unit() * 0.10))
            PixelLayout.bareTree(x: x, base: base, height: height, random: &random, rects: &trees, tips: &tips)
        }
        rimRects = rims

        // Lucerny visi z konce vetvi a stoji na sloupcich.
        var spots: [LanternSpot] = []
        for tip in tips where tip.y + 6 < Int(groundBase) {
            spots.append(LanternSpot(x: tip.x, y: tip.y + 4, drop: 3))
        }
        for fraction in config.lanternPosts {
            let x = Int(Double(cols) * fraction)
            let base = ground[min(cols - 1, max(0, x))]
            let postTop = base - 13
            trees.append(GridRect(x: x, y: postTop, w: 1, h: 13))
            trees.append(GridRect(x: x, y: postTop, w: 4, h: 1))
            spots.append(LanternSpot(x: x + 3, y: postTop + 2, drop: 1))
        }
        treeRects = trees
        lanterns = spots

        // Hvezdy jen na obloze, mimo mesic.
        var starList: [StarSpec] = []
        let starCount = max(40, cols * Int(rowsD * 0.40) / 260)
        for _ in 0..<starCount {
            let x = random.int(0...(cols - 1))
            let y = random.int(0...max(1, Int(rowsD * 0.40)))
            let dx = x - moonX
            let dy = y - moonY
            if dx * dx + dy * dy < (moonRadius + 4) * (moonRadius + 4) { continue }
            starList.append(StarSpec(
                x: x,
                y: y,
                brightness: 0.35 + random.unit() * 0.65,
                phase: random.unit() * 6.28,
                speed: 0.8 + random.unit() * 2.4,
                isBright: random.unit() < 0.10
            ))
        }
        stars = starList

        // Svetlusky v dolni polovine.
        var flies: [FireflySpec] = []
        for _ in 0..<14 {
            flies.append(FireflySpec(
                x: random.unit() * Double(cols),
                y: rowsD * (0.52 + random.unit() * 0.36),
                range: 2 + random.unit() * 5,
                speedX: 0.25 + random.unit() * 0.5,
                speedY: 0.3 + random.unit() * 0.6,
                phase: random.unit() * 6.28
            ))
        }
        fireflies = flies

        // Pruhy mlhy, ktere pomalu plynou.
        var mistList: [MistWisp] = []
        let mistRows: [Double] = [0.38, 0.42, 0.47, 0.70, 0.84]
        for row in mistRows {
            mistList.append(MistWisp(
                row: Int(rowsD * row),
                length: Int(Double(cols) * (0.30 + random.unit() * 0.35)),
                speed: 0.6 + random.unit() * 1.0,
                offset: random.unit() * Double(cols),
                opacity: 0.05 + random.unit() * 0.05
            ))
        }
        wisps = mistList
    }

    // MARK: Stavitele

    /// Silueta hradu: hradba s cimbuřím, hlavni vez s vezickou a dve krajni veze se spicatou strechou.
    static func castle(centerX: Int, base: Int, scale: Int) -> (rects: [GridRect], windows: [GridPoint]) {
        let s = max(1, scale)
        var rects: [GridRect] = []
        var windows: [GridPoint] = []
        let wallWidth = 24 * s
        let wallHeight = 7 * s
        let wallLeft = centerX - wallWidth / 2
        rects.append(GridRect(x: wallLeft, y: base - wallHeight, w: wallWidth, h: wallHeight + 30))
        var notch = wallLeft
        while notch < wallLeft + wallWidth {
            rects.append(GridRect(x: notch, y: base - wallHeight - s, w: s, h: s))
            notch += 2 * s
        }
        // Hlavni vez
        let keepWidth = 9 * s
        let keepHeight = 17 * s
        let keepLeft = centerX - keepWidth / 2
        rects.append(GridRect(x: keepLeft, y: base - keepHeight, w: keepWidth, h: keepHeight))
        var keepNotch = keepLeft
        while keepNotch < keepLeft + keepWidth {
            rects.append(GridRect(x: keepNotch, y: base - keepHeight - s, w: s, h: s))
            keepNotch += 2 * s
        }
        // Vezicka na hlavni vezi se spicatou strechou a vlajkou
        let spireWidth = 3 * s
        let spireLeft = centerX - spireWidth / 2
        let spireTop = base - keepHeight - 6 * s
        rects.append(GridRect(x: spireLeft, y: spireTop, w: spireWidth, h: 6 * s))
        appendRoof(left: spireLeft, width: spireWidth, top: spireTop, height: 5 * s, into: &rects)
        rects.append(GridRect(x: centerX, y: spireTop - 5 * s - 3 * s, w: 1, h: 3 * s))
        rects.append(GridRect(x: centerX + 1, y: spireTop - 5 * s - 3 * s, w: 2 * s, h: s))
        // Krajni veze
        let towerWidth = 5 * s
        let towerHeight = 13 * s
        let towers = [wallLeft - 1, wallLeft + wallWidth - towerWidth + 1]
        for towerLeft in towers {
            rects.append(GridRect(x: towerLeft, y: base - towerHeight, w: towerWidth, h: towerHeight))
            appendRoof(left: towerLeft, width: towerWidth, top: base - towerHeight, height: 6 * s, into: &rects)
            windows.append(GridPoint(x: towerLeft + towerWidth / 2, y: base - towerHeight + 3 * s))
        }
        // Okna hlavni veze
        windows.append(GridPoint(x: centerX - 2 * s, y: base - keepHeight + 4 * s))
        windows.append(GridPoint(x: centerX + 2 * s, y: base - keepHeight + 4 * s))
        windows.append(GridPoint(x: centerX, y: base - keepHeight + 9 * s))
        windows.append(GridPoint(x: wallLeft + 4 * s, y: base - wallHeight + 3 * s))
        windows.append(GridPoint(x: wallLeft + wallWidth - 5 * s, y: base - wallHeight + 3 * s))
        return (rects, windows)
    }

    /// Spicata strecha (trojuhelnik po radcich) nad obdelnikem.
    static func appendRoof(left: Int, width: Int, top: Int, height: Int, into rects: inout [GridRect]) {
        let fullWidth = width + 2
        for row in 0..<height {
            let rowWidth = max(1, fullWidth - (row * fullWidth) / max(1, height))
            let rowLeft = left - 1 + (fullWidth - rowWidth) / 2
            rects.append(GridRect(x: rowLeft, y: top - row - 1, w: rowWidth, h: 1))
        }
    }

    /// Trosky: polorozpadly oblouk, zlomene sloupy a sutiny.
    static func ruins(centerX: Int, base: Int, bottom: Int) -> (rects: [GridRect], lights: [GridRect]) {
        var rects: [GridRect] = []
        var lights: [GridRect] = []
        let depth = bottom - base
        // Oblouk ze dvou pilířu
        let leftPillar = centerX - 7
        let rightPillar = centerX + 4
        let pillarTop = base - 15
        rects.append(GridRect(x: leftPillar, y: pillarTop, w: 3, h: 15 + depth))
        rects.append(GridRect(x: rightPillar, y: pillarTop + 3, w: 3, h: 12 + depth))
        lights.append(GridRect(x: leftPillar, y: pillarTop, w: 1, h: 15))
        lights.append(GridRect(x: rightPillar, y: pillarTop + 3, w: 1, h: 12))
        for step in 0..<4 {
            rects.append(GridRect(x: leftPillar + step, y: pillarTop - step - 1, w: 3, h: 1))
            lights.append(GridRect(x: leftPillar + step, y: pillarTop - step - 1, w: 1, h: 1))
        }
        // Prava pulka oblouku je zricena - zbyl jen pahyl.
        rects.append(GridRect(x: rightPillar - 1, y: pillarTop + 2, w: 3, h: 1))
        // Zlomene sloupy
        let columns: [(Int, Int)] = [(centerX - 13, 8), (centerX + 10, 10), (centerX + 15, 5)]
        for (columnX, height) in columns {
            rects.append(GridRect(x: columnX, y: base - height, w: 2, h: height + depth))
            rects.append(GridRect(x: columnX - 1, y: base - height, w: 4, h: 1))
            lights.append(GridRect(x: columnX, y: base - height + 1, w: 1, h: height - 1))
        }
        // Sutiny
        rects.append(GridRect(x: centerX - 2, y: base - 2, w: 3, h: 2 + depth))
        rects.append(GridRect(x: centerX + 7, y: base - 1, w: 2, h: 1 + depth))
        rects.append(GridRect(x: centerX - 10, y: base - 1, w: 2, h: 1 + depth))
        return (rects, lights)
    }

    /// Velky strom u okraje: pokrouceny kmen, vetve a koruna z nepravidelnych chomacu.
    static func edgeTree(x: Int, base: Int, top: Int, canopy: Int, inward: Int, random: inout SeededRandom, rects: inout [GridRect], rims: inout [GridRect]) {
        let phase = random.unit() * 6.28
        appendTrunk(x: x, base: base, top: top, width: 5, phase: phase, into: &rects)
        let height = base - top
        let branchHeights: [Double] = [0.35, 0.55, 0.72]
        for (index, fraction) in branchHeights.enumerated() {
            let startY = base - Int(Double(height) * fraction)
            let length = canopy / 2 + random.int(2...6)
            let tip = appendBranch(x: x + trunkWobble(y: startY, phase: phase), y: startY, direction: inward, length: length, rise: 2 + index % 2, into: &rects)
            appendBlob(centerX: tip.x, centerY: tip.y - 1, radius: max(3, canopy / 3), random: &random, rects: &rects, rims: &rims)
        }
        let topX = x + trunkWobble(y: top, phase: phase)
        appendBlob(centerX: topX, centerY: top, radius: canopy, random: &random, rects: &rects, rims: &rims)
        appendBlob(centerX: topX + inward * canopy * 4 / 5, centerY: top + canopy / 3, radius: canopy * 3 / 4, random: &random, rects: &rects, rims: &rims)
        appendBlob(centerX: topX - inward * canopy / 3, centerY: top + canopy / 2 + 3, radius: canopy * 2 / 3, random: &random, rects: &rects, rims: &rims)
    }

    /// Holý pokrouceny strom; konce jeho vetvi slouzi jako hacky na lucerny.
    static func bareTree(x: Int, base: Int, height: Int, random: inout SeededRandom, rects: inout [GridRect], tips: inout [GridPoint]) {
        let phase = random.unit() * 6.28
        let top = base - height
        appendTrunk(x: x, base: base, top: top, width: 3, phase: phase, into: &rects)
        let fractions: [Double] = [0.48, 0.62, 0.76, 0.88]
        for (index, fraction) in fractions.enumerated() {
            let startY = base - Int(Double(height) * fraction)
            let direction = index % 2 == 0 ? -1 : 1
            let length = random.int(5...9)
            let tip = appendBranch(x: x + trunkWobble(y: startY, phase: phase), y: startY, direction: direction, length: length, rise: 2, into: &rects)
            if index < 2 { tips.append(tip) }
        }
        // Rozvetvena spicka
        let topX = x + trunkWobble(y: top, phase: phase)
        rects.append(GridRect(x: topX - 2, y: top - 3, w: 1, h: 3))
        rects.append(GridRect(x: topX + 2, y: top - 4, w: 1, h: 4))
        rects.append(GridRect(x: topX - 1, y: top - 1, w: 3, h: 1))
    }

    static func trunkWobble(y: Int, phase: Double) -> Int {
        Int((sin(Double(y) * 0.21 + phase) * 1.4).rounded())
    }

    static func appendTrunk(x: Int, base: Int, top: Int, width: Int, phase: Double, into rects: inout [GridRect]) {
        guard base > top else { return }
        for y in top...base {
            let flare = max(0, 3 - (base - y))
            let rowWidth = width + flare * 2
            let left = x + trunkWobble(y: y, phase: phase) - rowWidth / 2
            rects.append(GridRect(x: left, y: y, w: rowWidth, h: 1))
        }
    }

    /// Vetev roste sikmo nahoru; u kmene je silnejsi. Vraci jeji konec.
    static func appendBranch(x: Int, y: Int, direction: Int, length: Int, rise: Int, into rects: inout [GridRect]) -> GridPoint {
        var branchX = x
        var branchY = y
        for step in 0..<max(1, length) {
            branchX += direction
            if step % max(1, rise) == rise - 1 { branchY -= 1 }
            let thickness = step < length / 2 ? 2 : 1
            rects.append(GridRect(x: branchX, y: branchY, w: 1, h: thickness))
        }
        rects.append(GridRect(x: branchX, y: branchY - 2, w: 1, h: 2))
        return GridPoint(x: branchX, y: branchY)
    }

    /// Chomac listi: kruh s otrepanym okrajem a mesicnim odleskem vlevo nahore.
    static func appendBlob(centerX: Int, centerY: Int, radius: Int, random: inout SeededRandom, rects: inout [GridRect], rims: inout [GridRect]) {
        guard radius > 0 else { return }
        for dy in -radius...radius {
            let span = Double(radius * radius - dy * dy)
            let half = Int(span.squareRoot().rounded()) + random.int(-1...1)
            guard half > 0 else { continue }
            rects.append(GridRect(x: centerX - half, y: centerY + dy, w: half * 2 + 1, h: 1))
            if dy < -radius / 3 {
                rims.append(GridRect(x: centerX - half, y: centerY + dy, w: min(2, half), h: 1))
            }
        }
    }
}

// MARK: - Kresleni

private struct PixelPainter {
    let context: GraphicsContext
    let px: CGFloat

    func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: Color) {
        guard w > 0, h > 0 else { return }
        let frame = CGRect(x: CGFloat(x) * px, y: CGFloat(y) * px, width: CGFloat(w) * px, height: CGFloat(h) * px)
        context.fill(Path(frame), with: .color(color))
    }

    func fill(_ item: GridRect, _ color: Color) {
        rect(item.x, item.y, item.w, item.h, color)
    }

    /// Mekka zare (jedine nepixelove prvky: svetlo lucern, oken a mesice).
    func glow(x: Double, y: Double, radius: Double, color: Color, opacity: Double) {
        let center = CGPoint(x: x * Double(px), y: y * Double(px))
        let reach = radius * Double(px)
        let bounds = CGRect(x: center.x - reach, y: center.y - reach, width: reach * 2, height: reach * 2)
        let gradient = Gradient(colors: [color.opacity(opacity), color.opacity(0)])
        context.fill(Path(ellipseIn: bounds), with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: reach))
    }

    func disc(centerX: Int, centerY: Int, radius: Int, color: Color) {
        guard radius > 0 else { return }
        for dy in -radius...radius {
            let half = Int(Double(radius * radius - dy * dy).squareRoot().rounded())
            rect(centerX - half, centerY + dy, half * 2 + 1, 1, color)
        }
    }

    // MARK: Vrstvy

    /// Obloha v pasech s pixelovym ditheringem na prechodech.
    func drawSky(_ layout: PixelLayout) {
        let bands = PixelPalette.sky
        let bandHeight = max(1, layout.skyBottom / bands.count)
        for (index, color) in bands.enumerated() {
            let top = index * bandHeight
            let height = index == bands.count - 1 ? layout.rows - top : bandHeight
            rect(0, top, layout.cols, height, color)
        }
        for index in 1..<bands.count {
            let boundary = index * bandHeight
            var x = 0
            while x < layout.cols {
                rect(x, boundary - 1, 1, 1, bands[index])
                rect(x + 1, boundary, 1, 1, bands[index - 1])
                if x % 4 == 0 { rect(x, boundary - 2, 1, 1, bands[index]) }
                x += 2
            }
        }
        // Slaby nachovy svit nad obzorem.
        glow(x: Double(layout.cols) / 2, y: Double(layout.skyBottom), radius: Double(layout.cols) * 0.7, color: Color(red: 0.62, green: 0.28, blue: 0.52), opacity: 0.30)
    }

    /// Mihotajici se hvezdy a obcas padajici hvezda.
    func drawStars(_ layout: PixelLayout, time: Double) {
        for star in layout.stars {
            let twinkle = 0.55 + 0.45 * sin(time * star.speed + star.phase)
            let alpha = star.brightness * twinkle
            rect(star.x, star.y, 1, 1, PixelPalette.star.opacity(alpha))
            if star.isBright {
                let arm = PixelPalette.star.opacity(alpha * 0.45)
                rect(star.x - 1, star.y, 1, 1, arm)
                rect(star.x + 1, star.y, 1, 1, arm)
                rect(star.x, star.y - 1, 1, 1, arm)
                rect(star.x, star.y + 1, 1, 1, arm)
            }
        }
        guard time > 0 else { return }
        let cycle = 9.0
        let local = time.truncatingRemainder(dividingBy: cycle)
        guard local < 0.8 else { return }
        let index = Int(time / cycle)
        let startFraction = Double(index % 7) / 10.0 + 0.10
        let progress = local / 0.8
        let headX = Double(layout.cols) * (startFraction + progress * 0.35)
        let headY = Double(layout.rows) * (0.04 + progress * 0.08)
        for trail in 0..<9 {
            let fade = 1.0 - Double(trail) / 9.0
            let x = Int(headX) - trail * 2
            let y = Int(headY - Double(trail) * 0.5)
            rect(x, y, 2, 1, PixelPalette.star.opacity(fade * (1 - progress * 0.5)))
        }
    }

    /// Mesic, hory, hrad, kopce, trosky, mlha, les, lucerny a zeme.
    func drawLandscape(_ layout: PixelLayout) {
        // Mesic s pixelovou svatozari
        let moonX = layout.moonX
        let moonY = layout.moonY
        let radius = layout.moonRadius
        glow(x: Double(moonX) + 0.5, y: Double(moonY) + 0.5, radius: Double(radius) * 3.4, color: PixelPalette.moonGlow, opacity: 0.20)
        disc(centerX: moonX, centerY: moonY, radius: radius + 2, color: PixelPalette.moonGlow.opacity(0.12))
        disc(centerX: moonX, centerY: moonY, radius: radius + 1, color: PixelPalette.moonGlow.opacity(0.18))
        disc(centerX: moonX, centerY: moonY, radius: radius, color: PixelPalette.moon)
        for dy in -radius...radius {
            let half = Int(Double(radius * radius - dy * dy).squareRoot().rounded())
            let shade = max(0, half / 3)
            rect(moonX + half - shade + 1, moonY + dy, shade, 1, PixelPalette.moonShade)
        }
        rect(moonX - radius / 3, moonY - radius / 4, 2, 2, PixelPalette.moonShade)
        rect(moonX + radius / 5, moonY + radius / 3, 3, 2, PixelPalette.moonShade)
        rect(moonX - radius / 2, moonY + radius / 3, 1, 1, PixelPalette.moonShade)

        // Vzdalene hory se snehem a nasvicenou hranou
        for x in 0..<layout.cols {
            let top = layout.farRidge[x]
            rect(x, top, 1, layout.rows - top, PixelPalette.farMountain)
            if top < layout.snowLine {
                rect(x, top, 1, 2, PixelPalette.snow)
            } else if x > 0, layout.farRidge[x - 1] > top {
                rect(x, top, 1, 1, PixelPalette.farRim)
            }
        }

        // Hrad
        for item in layout.castleRects { fill(item, PixelPalette.castle) }
        for window in layout.castleWindows { rect(window.x, window.y, 1, 2, PixelPalette.window.opacity(0.75)) }

        // Blizsi kopce
        for x in 0..<layout.cols {
            let top = layout.midRidge[x]
            rect(x, top, 1, layout.rows - top, PixelPalette.midHill)
        }

        // Zakladni vrstva mlhy nad kopci
        let mistLevels: [Double] = [0.03, 0.05, 0.07, 0.08, 0.06, 0.04]
        for (offset, level) in mistLevels.enumerated() {
            rect(0, layout.mistRow + offset, layout.cols, 1, PixelPalette.mist.opacity(level * layout.mistStrength))
        }

        // Trosky
        for item in layout.ruinRects { fill(item, PixelPalette.ruin) }
        for item in layout.ruinLights { fill(item, PixelPalette.ruinLight) }

        // Zeme a trava
        for x in 0..<layout.cols {
            let top = layout.groundRidge[x]
            rect(x, top, 1, layout.rows - top, PixelPalette.near)
        }
        for item in layout.grass { fill(item, PixelPalette.near) }

        // Les
        for item in layout.treeRects { fill(item, PixelPalette.near) }
        for item in layout.rimRects { fill(item, PixelPalette.rim) }

        // Lucerny: provazek, ramecek a tlumene jadro (zari se pridava v animovane vrstve)
        for spot in layout.lanterns {
            rect(spot.x, spot.y - spot.drop, 1, spot.drop, PixelPalette.near)
            rect(spot.x - 1, spot.y, 3, 4, PixelPalette.lanternFrame)
            rect(spot.x - 1, spot.y - 1, 3, 1, PixelPalette.near)
            rect(spot.x, spot.y + 1, 1, 2, PixelPalette.lanternCore.opacity(0.8))
        }
    }

    /// Plynouci mlha, plapolajici lucerny, okna hradu a svetlusky.
    func drawEffects(_ layout: PixelLayout, time: Double) {
        for wisp in layout.wisps {
            let travel = Double(layout.cols + wisp.length)
            let position = (wisp.offset + time * wisp.speed).truncatingRemainder(dividingBy: travel)
            let left = Int(position) - wisp.length
            let strength = wisp.opacity * layout.mistStrength
            rect(left, wisp.row, wisp.length, 1, PixelPalette.mist.opacity(strength))
            rect(left + 3, wisp.row - 1, max(0, wisp.length - 6), 1, PixelPalette.mist.opacity(strength * 0.6))
            rect(left + 5, wisp.row + 1, max(0, wisp.length - 10), 1, PixelPalette.mist.opacity(strength * 0.5))
        }

        for (index, window) in layout.castleWindows.enumerated() {
            let flicker = 0.75 + 0.25 * sin(time * 2.3 + Double(index) * 1.7)
            glow(x: Double(window.x) + 0.5, y: Double(window.y) + 1, radius: 3, color: PixelPalette.window, opacity: 0.30 * flicker)
            rect(window.x, window.y, 1, 2, PixelPalette.window.opacity(flicker))
        }

        for (index, spot) in layout.lanterns.enumerated() {
            let seed = Double(index)
            let flicker = 0.80 + 0.12 * sin(time * 7.3 + seed) + 0.08 * sin(time * 12.7 + seed * 2.3)
            glow(x: Double(spot.x) + 0.5, y: Double(spot.y) + 2, radius: 10, color: PixelPalette.lanternGlow, opacity: 0.42 * flicker)
            rect(spot.x, spot.y + 1, 1, 2, PixelPalette.lanternCore.opacity(min(1, flicker + 0.1)))
        }

        for fly in layout.fireflies {
            let x = fly.x + sin(time * fly.speedX + fly.phase) * fly.range
            let y = fly.y + cos(time * fly.speedY + fly.phase) * fly.range * 0.6
            let pulse = 0.5 + 0.5 * sin(time * 2.2 + fly.phase * 3)
            guard pulse > 0.15 else { continue }
            glow(x: x + 0.5, y: y + 0.5, radius: 2.5, color: PixelPalette.firefly, opacity: 0.45 * pulse)
            rect(Int(x), Int(y), 1, 1, PixelPalette.firefly.opacity(pulse))
        }
    }
}

/// Staticky nahled sceny sveta (karta World scenes v obchode).
enum WorldSceneThumbnail {
    static func draw(_ context: GraphicsContext, size: CGSize, scene: BackdropScene) {
        let layout = PixelLayout(size: size, scene: scene)
        let painter = PixelPainter(context: context, px: layout.px)
        painter.drawSky(layout)
        painter.drawStars(layout, time: 0)
        painter.drawLandscape(layout)
        painter.drawEffects(layout, time: 3)
    }
}
