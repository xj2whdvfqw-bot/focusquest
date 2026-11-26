import SwiftUI

// P1/I: pixelovy kupecky stanek. Vsechno je kreslene po pixelech (Canvas, mrizky znaku) stejne jako
// sprity hrdiny a bossu; zadne cizi assety. Barvy: drevo, zlata (mince, CTA zluta), kremova; zadna
// tyrkysova ani systemova modra.

/// Paleta stanku.
enum StallPalette {
    static let woodLight = Color(red: 0.72, green: 0.50, blue: 0.29)
    static let wood = Color(red: 0.58, green: 0.38, blue: 0.20)
    static let woodDark = Color(red: 0.40, green: 0.25, blue: 0.13)
    static let woodShadow = Color(red: 0.25, green: 0.15, blue: 0.08)
    /// Aktivni cedule je svetlejsi.
    static let woodActive = Color(red: 0.86, green: 0.64, blue: 0.38)
    static let woodActiveLight = Color(red: 0.95, green: 0.77, blue: 0.50)
    static let nail = Color(red: 0.20, green: 0.14, blue: 0.10)
    static let chain = Color(red: 0.62, green: 0.62, blue: 0.66)
    static let chainDark = Color(red: 0.38, green: 0.38, blue: 0.43)
    static let cream = Color(red: 0.98, green: 0.93, blue: 0.80)
    static let paper = Color(red: 0.96, green: 0.90, blue: 0.74)
    static let paperShade = Color(red: 0.82, green: 0.74, blue: 0.56)
    static let ink = Color(red: 0.30, green: 0.18, blue: 0.08)
    static let string = Color(red: 0.90, green: 0.85, blue: 0.72)
    static let yellow = FQColor.cta
    static let yellowShade = Color(red: 0.85, green: 0.66, blue: 0.16)
    static let gold = Color(red: 0.98, green: 0.78, blue: 0.25)
    static let goldDark = Color(red: 0.70, green: 0.50, blue: 0.12)
    static let goldLight = Color(red: 1.0, green: 0.92, blue: 0.58)
    static let stone = Color(red: 0.46, green: 0.44, blue: 0.52)
    static let stoneLight = Color(red: 0.62, green: 0.60, blue: 0.68)
    static let stoneDark = Color(red: 0.30, green: 0.28, blue: 0.36)
}

/// Velikost jednoho pixelu stanku v bodech (stejne hruby jako krajiny za obrazovkami).
enum StallMetrics {
    static let pixel: CGFloat = 3
}

// MARK: - Kresleni

/// Kreslici pero: obdelniky v jednotkach pixelu.
struct PixelPen {
    let context: GraphicsContext
    let p: CGFloat

    func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: Color) {
        guard w > 0, h > 0 else { return }
        context.fill(Path(CGRect(x: CGFloat(x) * p, y: CGFloat(y) * p, width: CGFloat(w) * p + 0.2, height: CGFloat(h) * p + 0.2)),
                     with: .color(color))
    }
}

/// Sprite z mrizky znaku; kazdy znak ma v palete barvu, tecka (a neznamy znak) je pruhledna.
struct PixelGridView: View {
    let rows: [String]
    let palette: [Character: Color]
    var pixel: CGFloat = StallMetrics.pixel

    var body: some View {
        let columns = rows.map { $0.count }.max() ?? 0
        Canvas(opaque: false) { context, _ in
            for (y, row) in rows.enumerated() {
                for (x, symbol) in row.enumerated() {
                    guard let color = palette[symbol] else { continue }
                    context.fill(Path(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: pixel + 0.2, height: pixel + 0.2)),
                                 with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(columns) * pixel, height: CGFloat(rows.count) * pixel)
        .accessibilityHidden(true)
    }
}

// MARK: - Ikony

/// Pixelove ikony cedulí, minci, hvezdicky a zasob.
enum StallIcon {
    static let sword: [String] = [
        ".......kkk",
        "......kwwk",
        ".....kwsk.",
        "....kwsk..",
        ".k.kwsk...",
        ".kkwsk....",
        "..kgk.....",
        ".kbkgk....",
        "kbk.kk....",
        "kk........"
    ]
    static let picture: [String] = [
        "gggggggggg",
        "gsssssssyg",
        "gssssssssg",
        "gsshhssssg",
        "gshhhhsshg",
        "ghhhhhhhhg",
        "gggggggggg"
    ]
    static let potion: [String] = [
        "...kk...",
        "...cc...",
        "..kssk..",
        "..kssk..",
        ".kswssk.",
        "kppppppk",
        "kppwpppk",
        "kppppppk",
        ".kppppk.",
        "..kkkk.."
    ]
    static let coin: [String] = [
        ".ooo.",
        "oyYyo",
        "oYyyo",
        "oyyyo",
        ".ooo."
    ]
    static let star: [String] = [
        "..y..",
        ".yYy.",
        "yyYyy",
        ".yyy.",
        ".y.y."
    ]

    static let palette: [Character: Color] = [
        "k": Color(red: 0.12, green: 0.10, blue: 0.16),
        "w": Color(red: 0.92, green: 0.95, blue: 1.0),
        "s": Color(red: 0.66, green: 0.72, blue: 0.82),
        "g": StallPalette.gold,
        "b": StallPalette.woodDark,
        "y": StallPalette.gold,
        "Y": StallPalette.goldLight,
        "o": StallPalette.goldDark,
        "h": Color(red: 0.30, green: 0.58, blue: 0.36),
        "c": StallPalette.woodLight,
        "p": Color(red: 0.90, green: 0.30, blue: 0.42)
    ]

    /// Ikona pro paletu, kde "s" na obrazu je obloha (svetla), ne ocel.
    static let picturePalette: [Character: Color] = [
        "g": StallPalette.gold,
        "s": Color(red: 0.62, green: 0.80, blue: 0.96),
        "y": StallPalette.goldLight,
        "h": Color(red: 0.30, green: 0.58, blue: 0.36)
    ]

    /// Lahvicka: "s" je sklo.
    static let potionPalette: [Character: Color] = [
        "k": Color(red: 0.12, green: 0.10, blue: 0.16),
        "c": StallPalette.woodLight,
        "s": Color(red: 0.82, green: 0.86, blue: 0.94),
        "w": Color.white,
        "p": Color(red: 0.90, green: 0.30, blue: 0.42)
    ]
}

/// Mince z pixelu (vedle ceny).
struct PixelCoin: View {
    var pixel: CGFloat = 2
    var body: some View { PixelGridView(rows: StallIcon.coin, palette: StallIcon.palette, pixel: pixel) }
}

/// Mala hvezdicka (nasazeny predmet).
struct PixelStar: View {
    var pixel: CGFloat = 2
    var body: some View { PixelGridView(rows: StallIcon.star, palette: StallIcon.palette, pixel: pixel) }
}

// MARK: - Drevo

/// Drevene prkno: horni svetla hrana, letokruhy, spodni stin. Roztahuje se na sirku.
struct WoodPlank: View {
    /// Vyska v pixelech.
    var thickness: Int = 4
    var active = false
    var nails = false

    var body: some View {
        let p = StallMetrics.pixel
        Canvas(opaque: false) { context, size in
            let pen = PixelPen(context: context, p: p)
            let w = Int((size.width / p).rounded(.up))
            let base = active ? StallPalette.woodActive : StallPalette.wood
            let light = active ? StallPalette.woodActiveLight : StallPalette.woodLight
            pen.fill(0, 0, w, thickness, base)
            pen.fill(0, 0, w, 1, light)
            pen.fill(0, thickness - 1, w, 1, StallPalette.woodShadow)
            // Letokruhy: kratke tmave carky v pravidelnem rytmu (bez nahody, stejne pri kazdem prekresleni).
            if thickness >= 4 {
                var x = 3
                var row = 1
                while x < w - 2 {
                    pen.fill(x, row + 1, 4, 1, StallPalette.woodDark.opacity(0.55))
                    x += 9
                    row = (row + 1) % max(1, thickness - 2)
                }
            }
            if nails {
                pen.fill(1, 1, 1, 1, StallPalette.nail)
                pen.fill(w - 2, 1, 1, 1, StallPalette.nail)
            }
        }
        .frame(height: CGFloat(thickness) * p)
        .accessibilityHidden(true)
    }
}

/// Deska cedule: drevo s tmavym okrajem, svetlou horni hranou a hrebiky v rozich.
struct WoodBoard: View {
    var active = false

    var body: some View {
        let p = StallMetrics.pixel
        Canvas(opaque: false) { context, size in
            let pen = PixelPen(context: context, p: p)
            let w = Int((size.width / p).rounded(.down))
            let h = Int((size.height / p).rounded(.down))
            let base = active ? StallPalette.woodActive : StallPalette.wood
            let light = active ? StallPalette.woodActiveLight : StallPalette.woodLight
            // Zkosene rohy (pixelove zaobleni).
            pen.fill(1, 0, w - 2, h, StallPalette.woodShadow)
            pen.fill(0, 1, w, h - 2, StallPalette.woodShadow)
            pen.fill(1, 1, w - 2, h - 2, base)
            pen.fill(2, 1, w - 4, 1, light)
            pen.fill(1, h - 2, w - 2, 1, StallPalette.woodDark)
            // Spara mezi dvema prkny.
            pen.fill(2, h / 2, w - 4, 1, StallPalette.woodDark.opacity(0.45))
            pen.fill(2, 2, 1, 1, StallPalette.nail)
            pen.fill(w - 3, 2, 1, 1, StallPalette.nail)
            if active {
                // Jemny zlaty lem aktivni cedule.
                pen.fill(1, 0, w - 2, 1, StallPalette.yellow)
                pen.fill(1, h - 1, w - 2, 1, StallPalette.yellowShade)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Retizek (svisle clanky) mezi tramem a cedulí.
struct PixelChain: View {
    var links = 3

    var body: some View {
        PixelGridView(rows: (0..<links).flatMap { _ in ["kk", "c.", "kk", ".c"] }.map { $0 },
                      palette: ["k": StallPalette.chainDark, "c": StallPalette.chain], pixel: 2)
    }
}

// MARK: - Strisky a podstavec

/// Strisky stanku: pruhovana plachta (zluta a kremova), tmavy tram nahore a obloucky dole.
struct StallAwning: View {
    static let heightInPixels = 11

    var body: some View {
        let p = StallMetrics.pixel
        Canvas(opaque: false) { context, size in
            let pen = PixelPen(context: context, p: p)
            let w = Int((size.width / p).rounded(.up))
            let stripe = 6
            // Tram.
            pen.fill(0, 0, w, 2, StallPalette.woodDark)
            pen.fill(0, 0, w, 1, StallPalette.wood)
            // Pruhy plachty.
            var x = 0
            var index = 0
            while x < w {
                let yellow = index % 2 == 0
                let color = yellow ? StallPalette.yellow : StallPalette.cream
                let shade = yellow ? StallPalette.yellowShade : StallPalette.paperShade
                pen.fill(x, 2, stripe, 6, color)
                pen.fill(x, 7, stripe, 1, shade)
                // Oblouk: spodni lem jednoho pruhu (uzsi o pixel na kazde strane, pak jeste uzsi).
                pen.fill(x, 8, stripe, 1, color)
                pen.fill(x + 1, 9, stripe - 2, 1, color)
                pen.fill(x + 2, 10, stripe - 4, 1, shade)
                x += stripe
                index += 1
            }
            // Stin pod tramem.
            pen.fill(0, 2, w, 1, Color.black.opacity(0.18))
        }
        .frame(height: CGFloat(Self.heightInPixels) * StallMetrics.pixel)
        .accessibilityHidden(true)
    }
}

/// R1: pevne rozmery stanku. Hrdina je vzdy stejne velky a cely (postava ~110 bodu, 16 x 16 pixelu po 7 bodech),
/// okno nad pultem ma nad hlavou misto na poskok pri zkouseni a pod nohama podstavec. Nic se pri rolovani nemeni.
enum StallLayout {
    /// Mezera mezi radkem Shop · mince · ozubene kolo a strisku stanku.
    static let topGap: CGFloat = 16
    /// Vzduch mezi spodkem ceduli a horni hranou listy zalozek.
    static let signsBottomGap: CGFloat = 12
    /// Ramecek hrdiny (sprite 16 x 16 pixelu, postava vcetne klobouku).
    static let heroSize: CGFloat = 112
    /// Misto nad hlavou (poskok pri zkouseni je 16 bodu).
    static let heroHeadroom: CGFloat = 20
    /// Okno s krajinou: misto nad hlavou + hrdina + podstavec (prekryva se s hrdinou o 1 pixel).
    static var heroWindowHeight: CGFloat {
        heroHeadroom + heroSize + CGFloat(StallPedestal.heightInPixels - 1) * StallMetrics.pixel
    }
}

/// Maly kamenny podstavec pod hrdinou.
struct StallPedestal: View {
    static let heightInPixels = 6
    var pixel: CGFloat = StallMetrics.pixel

    var body: some View {
        PixelGridView(rows: [
            "..llllllllllllllllll..",
            ".lsssssssssssssssssssl",
            ".ssssssssssssssssssss.",
            "..dddddddddddddddddd..",
            ".dddddddddddddddddddd.",
            "dddddddddddddddddddddd"
        ].map { String($0.prefix(22)) },
        palette: ["l": StallPalette.stoneLight, "s": StallPalette.stone, "d": StallPalette.stoneDark],
        pixel: pixel)
    }
}

/// Drevene sloupky stanku po stranach okna.
struct StallPost: View {
    var body: some View {
        let p = StallMetrics.pixel
        Canvas(opaque: false) { context, size in
            let pen = PixelPen(context: context, p: p)
            let h = Int((size.height / p).rounded(.up))
            pen.fill(0, 0, 4, h, StallPalette.wood)
            pen.fill(0, 0, 1, h, StallPalette.woodLight)
            pen.fill(3, 0, 1, h, StallPalette.woodShadow)
            var y = 5
            while y < h - 2 {
                pen.fill(1, y, 2, 1, StallPalette.woodDark.opacity(0.6))
                y += 11
            }
        }
        .frame(width: 4 * StallMetrics.pixel)
        .accessibilityHidden(true)
    }
}

// MARK: - Scena za stankem

/// Obloha a krajina za stankem: scena pozadi (nebo noc sveta), zmensena na sirku okna a zarovnana tak,
/// aby byl videt horizont. Pozadi z obchodu se pomalu hybe (12 snimku/s); s Reduce Motion a na pozadi stoji.
struct StallScene: View {
    /// nil = World scenes.
    let background: ShopBackground?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let still = reduceMotion || scenePhase != .active || background == nil
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: still)) { timeline in
            let time = still ? 3 : ShopSceneBackdrop.sceneTime(timeline.date)
            Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                Self.draw(context, size: size, background: background, time: time)
            }
        }
        .background(Color(red: 11 / 255, green: 9 / 255, blue: 24 / 255))
        .accessibilityHidden(true)
    }

    /// Scena telefonu (402 x 874) zmensena na sirku okna; spodni hrana okna lezi v 80 % vysky sceny
    /// (horizont a kus oblohy nad nim).
    static func draw(_ context: GraphicsContext, size: CGSize, background: ShopBackground?, time: Double) {
        let scene = ShopSceneThumbnail.sceneSize
        let scale = max(size.width / scene.width, size.height / (scene.height * 0.8))
        var scaled = context
        scaled.translateBy(x: (size.width - scene.width * scale) / 2, y: size.height - scene.height * 0.8 * scale)
        scaled.scaleBy(x: scale, y: scale)
        if let background {
            let layout = ShopSceneLayout(size: scene, background: background)
            let painter = ScenePainter(context: scaled, px: layout.px)
            layout.drawSky(painter)
            layout.drawSkyEffects(painter, time: time)
            layout.drawLand(painter)
            layout.drawEffects(painter, time: time)
        } else {
            WorldSceneThumbnail.draw(scaled, size: scene, scene: .lanternGrove)
        }
    }
}

/// Obraz pozadi: cela scena telefonu zmensena a zarovnana dolu (jako drivejsi nahled v karte).
struct PaintingScene: View {
    let background: ShopBackground?

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let scene = ShopSceneThumbnail.sceneSize
            let scale = max(size.width / scene.width, size.height / scene.height)
            var scaled = context
            scaled.translateBy(x: (size.width - scene.width * scale) / 2, y: size.height - scene.height * scale)
            scaled.scaleBy(x: scale, y: scale)
            if let background {
                let layout = ShopSceneLayout(size: scene, background: background)
                let painter = ScenePainter(context: scaled, px: layout.px)
                layout.drawSky(painter)
                layout.drawSkyEffects(painter, time: 3)
                layout.drawLand(painter)
                layout.drawEffects(painter, time: 3)
            } else {
                WorldSceneThumbnail.draw(scaled, size: scene, scene: .lanternGrove)
            }
        }
        .background(Color(red: 11 / 255, green: 9 / 255, blue: 24 / 255))
        .accessibilityHidden(true)
    }
}

/// Pixelovy ram obrazu: zlata lista se svetlou a tmavou hranou a ozdobou v rozich.
struct PixelFrame: View {
    static let thicknessInPixels = 4

    var body: some View {
        let p = StallMetrics.pixel
        Canvas(opaque: false) { context, size in
            let pen = PixelPen(context: context, p: p)
            let w = Int((size.width / p).rounded(.down))
            let h = Int((size.height / p).rounded(.down))
            let t = Self.thicknessInPixels
            // Lista.
            pen.fill(0, 0, w, t, StallPalette.gold)
            pen.fill(0, h - t, w, t, StallPalette.gold)
            pen.fill(0, 0, t, h, StallPalette.gold)
            pen.fill(w - t, 0, t, h, StallPalette.gold)
            // Svetla vnejsi a tmava vnitrni hrana.
            pen.fill(0, 0, w, 1, StallPalette.goldLight)
            pen.fill(0, 0, 1, h, StallPalette.goldLight)
            pen.fill(0, h - 1, w, 1, StallPalette.goldDark)
            pen.fill(w - 1, 0, 1, h, StallPalette.goldDark)
            pen.fill(t - 1, t - 1, w - 2 * t + 2, 1, StallPalette.goldDark)
            pen.fill(t - 1, t - 1, 1, h - 2 * t + 2, StallPalette.goldDark)
            pen.fill(t - 1, h - t, w - 2 * t + 2, 1, StallPalette.goldLight)
            pen.fill(w - t, t - 1, 1, h - 2 * t + 2, StallPalette.goldLight)
            // Ozdoba v rozich.
            for (cx, cy) in [(1, 1), (w - 3, 1), (1, h - 3), (w - 3, h - 3)] {
                pen.fill(cx, cy, 2, 2, StallPalette.goldDark)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Predmety

/// Predmet z obchodu jako samostatny sprite: jen jeho pixely z mrizky hrdiny, oriznute na obrys.
struct ItemSprite: View {
    let item: EquipmentItem
    /// Velikost jednoho pixelu predmetu.
    var pixel: CGFloat = 4

    var body: some View {
        let crop = Self.crop(item.layers)
        ZStack(alignment: .topLeading) {
            ForEach(crop.layers) { layer in
                PixelLayerShape(rows: layer.rows, symbol: "#").fill(Color(rgb: layer.rgb))
            }
        }
        .frame(width: CGFloat(crop.width) * pixel, height: CGFloat(crop.height) * pixel)
        .accessibilityHidden(true)
    }

    /// Vrstvy oriznute na spolecny obrys vsech pixelu predmetu.
    static func crop(_ layers: [AvatarLayer]) -> (layers: [AvatarLayer], width: Int, height: Int) {
        var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
        for layer in layers {
            for (y, row) in layer.rows.enumerated() {
                for (x, cell) in row.enumerated() where cell == "#" {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard minX <= maxX else { return ([], 1, 1) }
        let cropped = layers.map { layer in
            AvatarLayer(id: layer.id, rows: layer.rows[minY...maxY].map { row in
                String(Array(row)[minX...maxX])
            }, rgb: layer.rgb)
        }
        return (cropped, maxX - minX + 1, maxY - minY + 1)
    }
}

/// Presypaci hodiny (Extra pause): pisek se pomalu presypa (4 faze), s Reduce Motion stoji.
struct HourglassSprite: View {
    var pixel: CGFloat = 4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.45, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 1 : Int(timeline.date.timeIntervalSinceReferenceDate / 0.45) % 4
            PixelGridView(rows: Self.rows(phase: phase), palette: Self.palette, pixel: pixel)
        }
        .accessibilityHidden(true)
    }

    static let palette: [Character: Color] = [
        "w": StallPalette.woodDark, "W": StallPalette.woodLight,
        "g": Color(red: 0.80, green: 0.86, blue: 0.95).opacity(0.55), "G": Color.white.opacity(0.8),
        "s": StallPalette.gold, "S": StallPalette.goldDark
    ]

    /// 11 x 13: drevene vicko a dno, sklo, pisek nahore ubyva, dole pribyva, tenky pramen v hrdle.
    static let glass: [String] = [
        "WWWWWWWWWWW",
        ".wwwwwwwww.",
        ".gGggggggg.",
        "..gGggggg..",
        "...gGggg...",
        "....ggg....",
        ".....g.....",
        "....ggg....",
        "...ggggg...",
        "..ggggggg..",
        ".ggggggggg.",
        ".wwwwwwwww.",
        "WWWWWWWWWWW"
    ]

    static func rows(phase: Int) -> [String] {
        var grid = glass.map { Array($0) }
        // Pisek nahore lezi u hrdla (radky 5 az 2) a ubyva, dole se sype od dna (radky 10 az 7).
        let topRows = [5, 4, 3, 2].prefix(max(1, 4 - phase))
        let bottomRows = [10, 9, 8, 7].prefix(min(4, 1 + phase))
        for row in topRows { fillSand(&grid[row]) }
        for row in bottomRows { fillSand(&grid[row]) }
        // Pramen v hrdle se trpyti.
        grid[6][5] = phase % 2 == 0 ? "s" : "S"
        return grid.map { String($0) }
    }

    private static func fillSand(_ row: inout [Character]) {
        for index in row.indices where row[index] == "g" || row[index] == "G" {
            row[index] = index % 3 == 0 ? "S" : "s"
        }
    }
}

/// Ledovy krystal (Streak freeze): jemny trpyt (jiskry se stridaji), s Reduce Motion stoji.
struct IceCrystalSprite: View {
    var pixel: CGFloat = 4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.6, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : Int(timeline.date.timeIntervalSinceReferenceDate / 0.6) % 3
            PixelGridView(rows: Self.rows(phase: phase), palette: Self.palette, pixel: pixel)
        }
        .accessibilityHidden(true)
    }

    static let palette: [Character: Color] = [
        "d": Color(red: 0.36, green: 0.56, blue: 0.86),
        "m": Color(red: 0.55, green: 0.76, blue: 0.98),
        "l": Color(red: 0.80, green: 0.92, blue: 1.0),
        "w": Color.white
    ]

    static func rows(phase: Int) -> [String] {
        var rows = [
            ".....l.....",
            "....lml....",
            "...lmmmd...",
            "..lmmlmmd..",
            "..lmlmmmd..",
            ".lmmlmmmmd.",
            ".lmlmmmmmd.",
            ".lmmmmmmdd.",
            "..lmmmmmd..",
            "..lmmmmdd..",
            "...lmmmd...",
            "...lmmdd...",
            "....lmd....",
            ".....d....."
        ]
        // Trpyt: jedna ze tri jisker.
        let sparkles = [(1, 2), (9, 4), (2, 10)]
        let (x, y) = sparkles[phase % sparkles.count]
        var chars = Array(rows[y])
        chars[x] = "w"
        rows[y] = String(chars)
        return rows
    }
}

// MARK: - Cenovka a odznaky

/// Cenovka na provazku pod predmetem: papirovy stitek s minci a cenou, "Owned" u vlastneneho predmetu.
struct PriceTag: View {
    enum Label: Equatable {
        case price(Int)
        case owned
        case free
    }

    let label: Label
    var stringLength: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(StallPalette.string)
                .frame(width: 2, height: stringLength)
            HStack(spacing: 3) {
                switch label {
                case let .price(amount):
                    PixelCoin(pixel: 2)
                    Text("\(amount)").monospacedDigit()
                case .owned:
                    Text("Owned")
                case .free:
                    Text("Free")
                }
            }
            .fqFont(size: 12, weight: .bold, design: .rounded)
            .foregroundStyle(StallPalette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                // Papirovy stitek s pixelovymi rohy a dirkou pro provazek.
                ZStack(alignment: .top) {
                    PixelTagShape().fill(StallPalette.paper)
                    PixelTagShape().stroke(StallPalette.paperShade, lineWidth: 1)
                    Rectangle().fill(StallPalette.paperShade).frame(width: 3, height: 3).padding(.top, 2)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityHidden(true)
    }
}

/// Obdelnik se zkosenymi (pixelovymi) rohy.
struct PixelTagShape: Shape {
    var corner: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY + corner))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.minY + corner))
        path.closeSubpath()
        return path
    }
}

// MARK: - Jiskry pri vyzkouseni

/// Jiskry kolem hrdiny pri vyzkouseni predmetu: 8 pixelovych hvezdicek vyleti a zhasne (0,6 s).
/// V klidu nejsou videt. S Reduce Motion se nekresli vubec.
struct TryOnSparkles: View {
    let trigger: Int
    var radius: CGFloat = 70
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Value {
        var opacity = 0.0
        var scale = 0.4
        var distance = 0.0
    }

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(0..<8, id: \.self) { index in
                    let angle = Double(index) / 8 * 2 * .pi + 0.3
                    PixelStar(pixel: index % 2 == 0 ? 3 : 2)
                        .keyframeAnimator(initialValue: Value(), trigger: trigger) { content, value in
                            content
                                .scaleEffect(value.scale)
                                .opacity(value.opacity)
                                .offset(x: cos(angle) * value.distance, y: sin(angle) * value.distance)
                        } keyframes: { _ in
                            KeyframeTrack(\.opacity) {
                                LinearKeyframe(1, duration: 0.08)
                                LinearKeyframe(1, duration: 0.27)
                                LinearKeyframe(0, duration: 0.25)
                            }
                            KeyframeTrack(\.scale) {
                                SpringKeyframe(1, duration: 0.3)
                                LinearKeyframe(0.5, duration: 0.3)
                            }
                            KeyframeTrack(\.distance) {
                                LinearKeyframe(radius * 0.35, duration: 0.01)
                                CubicKeyframe(radius, duration: 0.59)
                            }
                        }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
