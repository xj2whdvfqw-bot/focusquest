import SwiftUI

/// B1: zdravi bosse jako rada pixelovych srdicek (misto HP cary). Kazde srdicko ma 4 ctvrtky;
/// ubyva se od posledniho srdicka vpravo. Pri ztrate ctvrtky se srdicko otrese a ctvrtka se rozpadne
/// na pixely. S Reduce Motion ctvrtka jen zmizi.
struct BossHeartsView: View {
    let hearts: Int
    let quartersLeft: Int
    var heartSize: CGFloat = 24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Posledni ztracena ctvrtka (srdicko, ctvrtka) a pocitadlo pro animaci.
    @State private var loss: Loss?
    @State private var lossCounter = 0
    /// Pocet otresu kazdeho srdicka (spoustec animace jen pro srdicko, ktere ctvrtku ztratilo).
    @State private var shakes: [Int: Int] = [:]

    private struct Loss: Equatable {
        let id: Int
        let heart: Int
        let quarter: Int
    }

    var body: some View {
        HStack(spacing: heartSize * 0.18) {
            ForEach(0..<hearts, id: \.self) { index in
                let filled = BossHearts.filledQuarters(inHeart: index, quartersLeft: quartersLeft)
                PixelHeart(filled: filled)
                    .frame(width: heartSize, height: heartSize * 7 / 8)
                    .modifier(HeartShake(trigger: shakes[index, default: 0], enabled: !reduceMotion))
                    .overlay {
                        if !reduceMotion, let loss, loss.heart == index {
                            QuarterBurst(quarter: loss.quarter)
                                .id(loss.id)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .onChange(of: quartersLeft) { old, new in
            // Jen ubyvani v bezici bitve; nova bitva (vic ctvrtek) se ukaze bez animace.
            guard new < old, new >= 0 else { loss = nil; return }
            lossCounter += 1
            let heart = max(0, new / BossHearts.quartersPerHeart)
            let quarter = new % BossHearts.quartersPerHeart
            let target = min(heart, max(0, hearts - 1))
            loss = Loss(id: lossCounter, heart: target, quarter: quarter)
            shakes[target, default: 0] += 1
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Boss health")
        .accessibilityValue(Self.spoken(quartersLeft: quartersLeft, hearts: hearts))
    }

    /// "2 and 3 quarters of 4 hearts left".
    static func spoken(quartersLeft: Int, hearts: Int) -> String {
        let whole = quartersLeft / BossHearts.quartersPerHeart
        let rest = quartersLeft % BossHearts.quartersPerHeart
        let restText = rest == 0 ? "" : (rest == 1 ? "1 quarter" : "\(rest) quarters")
        let amount = whole == 0 ? (rest == 0 ? "0" : restText) : (rest == 0 ? "\(whole)" : "\(whole) and \(restText)")
        return "\(amount) of \(hearts) hearts left"
    }
}

/// Pixelove srdicko 8 × 7 rozdelene na 4 ctvrtky: vlevo nahore, vpravo nahore, vpravo dole, vlevo dole.
/// Plne ctvrtky jsou cervene (`filled` prvnich v tomto poradi), prazdne tmave.
struct PixelHeart: View {
    let filled: Int

    static let rows = [
        ".##..##.",
        "########",
        "########",
        "########",
        ".######.",
        "..####..",
        "...##...",
    ]

    /// Ctvrtky v poradi plneni; ubyva se od posledni (vlevo dole) k prvni (vlevo nahore).
    static let quarterCells: [(columns: Range<Int>, rows: Range<Int>)] = [
        (0..<4, 0..<3), (4..<8, 0..<3), (4..<8, 3..<7), (0..<4, 3..<7),
    ]

    static func quarterRows(_ quarters: [Int]) -> [String] {
        rows.enumerated().map { y, row in
            String(row.enumerated().map { x, cell -> Character in
                guard cell == "#" else { return "." }
                let inside = quarters.contains { index in
                    let area = quarterCells[index]
                    return area.columns.contains(x) && area.rows.contains(y)
                }
                return inside ? "#" : "."
            })
        }
    }

    private static let red = Color(red: 1.0, green: 0.30, blue: 0.40)
    private static let empty = Color(red: 0.18, green: 0.15, blue: 0.28)
    private static let outline = Color(red: 0.06, green: 0.05, blue: 0.12)

    var body: some View {
        let full = PixelLayerShape(rows: Self.rows, symbol: "#")
        let lit = PixelLayerShape(rows: Self.quarterRows(Array(0..<max(0, min(4, filled)))), symbol: "#")
        ZStack {
            // Tmavy obrys z posunutych kopii tvaru (pixelovy vzhled, bez rozmazani).
            full.fill(Self.outline).offset(x: -1.5)
            full.fill(Self.outline).offset(x: 1.5)
            full.fill(Self.outline).offset(y: -1.5)
            full.fill(Self.outline).offset(y: 1.5)
            full.fill(Self.empty)
            lit.fill(Self.red)
            // Odlesk v levem hornim pixelu, jen kdyz je ctvrtka vlevo nahore plna.
            if filled > 0 {
                PixelLayerShape(rows: [
                    "........",
                    ".#......",
                    "........",
                    "........",
                    "........",
                    "........",
                    "........",
                ], symbol: "#").fill(Color.white.opacity(0.75))
            }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: 2)
    }
}

/// Otres srdicka pri ztrate ctvrtky.
private struct HeartShake: ViewModifier {
    let trigger: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, value in
                view.offset(x: value).rotationEffect(.degrees(value * 1.5))
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0, duration: 0.01)
                    LinearKeyframe(-3, duration: 0.06)
                    LinearKeyframe(3, duration: 0.08)
                    LinearKeyframe(-2, duration: 0.08)
                    LinearKeyframe(1, duration: 0.08)
                    LinearKeyframe(0, duration: 0.08)
                }
            }
        } else {
            content
        }
    }
}

/// Ztracena ctvrtka se rozpadne na 6 pixelu, ktere odletnou od jejiho stredu a zmizi (0,6 s).
private struct QuarterBurst: View {
    let quarter: Int
    @State private var progress = 0.0

    var body: some View {
        GeometryReader { proxy in
            let area = PixelHeart.quarterCells[min(max(0, quarter), 3)]
            let cell = proxy.size.width / 8
            let center = CGPoint(
                x: CGFloat(area.columns.lowerBound + area.columns.upperBound) / 2 * cell,
                y: CGFloat(area.rows.lowerBound + area.rows.upperBound) / 2 * cell
            )
            let outward: CGFloat = area.columns.lowerBound == 0 ? -1 : 1
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) / 6 * 2 * .pi
                let dx = CGFloat(cos(angle)) * 10 + outward * 6
                let dy = CGFloat(sin(angle)) * 8 - 8
                Rectangle()
                    .fill(index.isMultiple(of: 2) ? Color(red: 1.0, green: 0.30, blue: 0.40) : Color(red: 1.0, green: 0.62, blue: 0.68))
                    .frame(width: cell, height: cell)
                    .position(x: center.x + dx * progress, y: center.y + dy * progress + 10 * progress * progress)
                    .opacity(1 - progress)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { progress = 1 } }
    }
}
