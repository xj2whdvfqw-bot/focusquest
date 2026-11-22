import CoreGraphics
import Foundation

/// Geometrie mapy na zalozce Path: velikost, pasy regionu (svetu), klikata cesta a zastavky (bossove).
/// Svety lezi nad sebou v poradi mapy (Farm dole, Orbit nahore). Cesta se v kazdem svete jednou
/// prehoupne z jedne strany mapy na druhou, takze zastavky jsou od sebe asi 200 bodu.
enum MapLayout {
    /// Cela mapa v bodech (pri zoomu 1).
    static let size = CGSize(width: 2400, height: 3600)
    /// 1 pixel terenu = 4 body mapy (pixel-art jako sprity appky).
    static let cell: CGFloat = 4
    static let columns = 600
    static let rows = 900
    /// Volny okraj nad cilem cesty.
    static let margin: CGFloat = 140
    /// Volny okraj pod startem cesty. Je vetsi, aby sli prvni bossove posunout kamerou do stredu
    /// viditelne casti (nad tab bar), a ne aby lezeli u spodni hrany mapy pod listou.
    static let bottomMargin: CGFloat = 420

    /// Svisly postup cesty pro bod mapy (0 = start dole, 1 = cil nahore).
    static func progress(y: CGFloat) -> CGFloat {
        (size.height - bottomMargin - y) / (size.height - margin - bottomMargin)
    }
    /// Jak daleko od stredu se cesta houpe do stran.
    static let amplitude: CGFloat = 780

    static let worldCount = BossWorld.allCases.count

    /// Bod cesty pro s v 0...1 (0 = start dole, 1 = cil nahore). Kazdy svet = jedna pulvlna.
    static func roadPoint(_ s: CGFloat) -> CGPoint {
        let y = size.height - bottomMargin - s * (size.height - margin - bottomMargin)
        let x = size.width / 2 + amplitude * cos(.pi * CGFloat(worldCount) * s)
        return CGPoint(x: x, y: y)
    }

    /// Husta posloupnost bodu cesty (kresli se do terenu a podle ni se rozmistuji zastavky).
    static let roadSamples: [CGPoint] = (0...4_000).map { roadPoint(CGFloat($0) / 4_000) }

    /// Kumulativni delka cesty u kazdeho vzorku.
    private static let roadLengths: [CGFloat] = {
        var lengths: [CGFloat] = [0]
        for index in 1..<roadSamples.count {
            let a = roadSamples[index - 1], b = roadSamples[index]
            lengths.append(lengths[index - 1] + hypot(b.x - a.x, b.y - a.y))
        }
        return lengths
    }()

    /// Bod cesty ve vzdalenosti `length` od startu.
    private static func point(atLength length: CGFloat) -> CGPoint {
        var low = 0, high = roadLengths.count - 1
        while low < high {
            let mid = (low + high) / 2
            if roadLengths[mid] < length { low = mid + 1 } else { high = mid }
        }
        return roadSamples[low]
    }

    /// Pozice zastavky kazdeho bosse (id -> bod mapy). V kazdem svete jsou bossove rovnomerne
    /// po delce jeho useku cesty.
    static let stops: [String: CGPoint] = {
        var result: [String: CGPoint] = [:]
        let samplesPerWorld = (roadSamples.count - 1) / worldCount
        for (index, world) in BossWorld.allCases.enumerated() {
            let start = roadLengths[index * samplesPerWorld]
            let end = roadLengths[min(roadLengths.count - 1, (index + 1) * samplesPerWorld)]
            let bosses = world.bosses
            for (order, boss) in bosses.enumerated() {
                let fraction = (CGFloat(order) + 0.5) / CGFloat(bosses.count)
                result[boss.id] = point(atLength: start + (end - start) * fraction)
            }
        }
        return result
    }()

    /// Svisly pas sveta na mape (pro mlhu a nazvy). Prvni a posledni svet sahaji az k okraji mapy.
    static func band(of world: BossWorld) -> CGRect {
        let index = CGFloat(BossWorld.allCases.firstIndex(of: world) ?? 0)
        let count = CGFloat(worldCount)
        let bottom = index == 0 ? size.height : roadPoint(index / count).y
        let top = index == count - 1 ? 0 : roadPoint((index + 1) / count).y
        return CGRect(x: 0, y: top, width: size.width, height: bottom - top)
    }

    /// Kde cesta do sveta vstupuje (start useku) - tam je stitek s nazvem sveta.
    static func entrance(of world: BossWorld) -> CGPoint {
        let index = CGFloat(BossWorld.allCases.firstIndex(of: world) ?? 0)
        return roadPoint(index / CGFloat(worldCount))
    }

    /// Kde stoji stitek s nazvem sveta: uprostred sirky mapy, kousek nad spodni hranou sveta
    /// (u prvniho sveta tesne pod startem cesty). Vodorovne ho WorldLabelsOverlay drzi v obrazovce.
    static func labelAnchor(of world: BossWorld) -> CGPoint {
        let band = band(of: world)
        let bottom = min(band.maxY, entrance(of: world).y + 110)
        return CGPoint(x: size.width / 2, y: bottom - 56)
    }

    /// Posun hranice mezi svety v bodech pro pixel terenu (cx, cy): dlouha vlna pres mapu a organicky sum,
    /// takze hranice neni nikde rovna cara pres celou sirku (pobrezi, okraj lesa). Bez nahodneho jitteru:
    /// ten pridava jen teren (rozmichani pixelu na hranici), aby mlha a mraky sedely na stejnou hranici.
    static func boundaryShift(cellX: Int, cellY: Int) -> Double {
        let x = (Double(cellX) + 0.5) * Double(cell)
        let wave = 40 * sin(x / 92) + 24 * sin(x / 36 + 1.3)
        let warp = (MapTerrain.noise(cellX, cellY, scale: 26, seed: 61) - 0.5) * 110
            + (MapTerrain.noise(cellX, cellY, scale: 7, seed: 62) - 0.5) * 44
        return wave + warp
    }

    /// Index sveta pro pixel terenu (cx, cy) s organickou hranici; `jitter` v bodech rozmicha pixely na hranici.
    static func worldIndex(cellX: Int, cellY: Int, jitter: Double = 0) -> Int {
        let y = (Double(cellY) + 0.5) * Double(cell)
        let t = Double(progress(y: CGFloat(y + boundaryShift(cellX: cellX, cellY: cellY) + jitter)))
        return min(worldCount - 1, max(0, Int((t * Double(worldCount)).rounded(.down))))
    }

    /// Index sveta pro bod mapy (v bodech).
    static func worldIndex(x: CGFloat, y: CGFloat) -> Int {
        worldIndex(cellX: Int(x / cell), cellY: Int(y / cell))
    }

    /// Jak daleko muze organicka hranice sveta vybocit z rovneho pasu (body). Mlha a mraky se kresli s rezervou.
    static let boundaryReach: CGFloat = 160

    // MARK: - Pixelovy pergamen (okraj mapy)

    /// Hloubka pixelu terenu (cx, cy) od zubateho okraje mapy: < 0 = mimo mapu (pruhledne),
    /// 0–1 tmave hnedy lem, 2–3 svetly lem, dal teren. Rohy jsou mirne otrhane (sikme useknuti se sumem).
    static func parchmentDepth(cellX x: Int, cellY y: Int) -> Int {
        let left = x, right = columns - 1 - x, top = y, bottom = rows - 1 - y
        let distance = min(left, right, top, bottom)
        let edge: Int, along: Int
        if distance == left { edge = 0; along = y } else if distance == right { edge = 1; along = y } else if distance == top { edge = 2; along = x } else { edge = 3; along = x }
        let jag = 2 + Int(MapTerrain.noise(along, edge * 97, scale: 5, seed: 71) * 4) + (MapTerrain.hash(along / 2, edge, 72) > 0.82 ? 1 : 0)
        var depth = distance - jag
        // Otrhane rohy: sikme useknuti (manhattanska vzdalenost od rohu) s nepravidelnym okrajem.
        let cx = min(left, right), cy = min(top, bottom)
        let corner = (left < right ? 0 : 1) + (top < bottom ? 0 : 2)
        let tear = 15 + Int(MapTerrain.hash(corner, 0, 73) * 9) + Int(MapTerrain.noise(cx - cy, corner * 31, scale: 3, seed: 74) * 5)
        depth = min(depth, cx + cy - tear)
        return depth
    }
}
