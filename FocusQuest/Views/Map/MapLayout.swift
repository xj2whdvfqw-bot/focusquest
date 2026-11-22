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

    /// Index sveta pro bod terenu (y v bodech), s vlnitou hranici mezi svety.
    static func worldIndex(x: CGFloat, y: CGFloat) -> Int {
        let wave = 40 * sin(x / 92) + 24 * sin(x / 36 + 1.3)
        let t = progress(y: y + wave)
        return min(worldCount - 1, max(0, Int(floor(t * CGFloat(worldCount)))))
    }
}
