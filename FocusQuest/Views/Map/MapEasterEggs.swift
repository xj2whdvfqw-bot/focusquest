import SwiftUI

// Easter eggy na mape Path (B5). Kazdy jde najit jen jednou za celou hru; zadne napovedy.
// Klepnuti jsou obycejne tap gesta v obsahu UIScrollView: posun a zoom mapy maji prednost (tah
// tap zrusi), a protoze vrstva je v souradnicich mapy, plocha klepnuti roste a zmensuje se se zoomem.

extension MapEasterEgg {
    /// Levy horni pixel krizku na Farm (kresli ho MapTerrain do terenu).
    static let farmXCell = (x: 28, y: 770)

    /// Stred v bodech mapy. Rybnik a planeta jsou stavby z MapTerrain (rohove stavby Whisperwoodu a Orbitu).
    var center: CGPoint {
        let c = MapLayout.cell
        switch self {
        case .pond:
            let top = Int(MapLayout.band(of: .forest).minY / c)
            return CGPoint(x: CGFloat(60 + 30 + 23) * c, y: CGFloat(top + 16 + 6 + 13) * c)
        case .planet:
            let top = Int(MapLayout.band(of: .planets).minY / c)
            return CGPoint(x: (CGFloat(MapLayout.columns - 160 + 10 + 9) + 0.5) * c, y: (CGFloat(top + 16 + 6 + 9) + 0.5) * c)
        case .farmX:
            return CGPoint(x: (CGFloat(Self.farmXCell.x) + 3.5) * c, y: (CGFloat(Self.farmXCell.y) + 2.5) * c)
        }
    }

    /// Plocha klepnuti v bodech mapy (o neco vetsi nez kresba).
    var hitSize: CGSize {
        switch self {
        case .pond: CGSize(width: 200, height: 120)
        case .planet: CGSize(width: 104, height: 104)
        case .farmX: CGSize(width: 76, height: 76)
        }
    }
}

/// Jeden easter egg na mape: pocita klepnuti, ukaze malou animaci a nakonec truhlu (nebo rovnou odmenu).
struct MapEasterEggView: View {
    let egg: MapEasterEgg
    /// Odmena: volajici pripise mince (jen poprve) a ukaze pocitadlo.
    let onReward: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps = 0
    @State private var ripple = 0
    @State private var claimed = false

    private var chestReady: Bool { taps >= egg.tapsNeeded }

    var body: some View {
        ZStack {
            switch egg {
            case .pond: pond
            case .planet: planet
            case .farmX: farm
            }
        }
        .frame(width: egg.hitSize.width, height: egg.hitSize.height)
        .position(egg.center)
        .accessibilityHidden(true)
    }

    // MARK: - Whisperwood: rybnik

    private var pond: some View {
        ZStack {
            // Kola na vode po kazdem klepnuti.
            RippleRing(trigger: ripple)
            if chestReady && !claimed {
                PixelChest(pixel: 5)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.3, anchor: .bottom).combined(with: .offset(y: 24)).combined(with: .opacity))
                    .onTapGesture { claim() }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { tapSurface() }
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: chestReady)
        .animation(.easeOut(duration: 0.3), value: claimed)
    }

    // MARK: - Orbit: oranzova planeta

    private var planet: some View {
        ZStack {
            RippleRing(trigger: ripple, color: Color(red: 1, green: 0.75, blue: 0.4))
            if claimed { CoinBurst() }
        }
        .contentShape(Circle())
        .onTapGesture {
            guard !claimed else { return }
            taps += 1
            ripple += 1
            FQFeedback.shared.haptic(.light)
            if taps >= egg.tapsNeeded { claim() }
        }
    }

    // MARK: - Farm: krizek a vykopana truhla

    private var farm: some View {
        let stage = min(taps, egg.tapsNeeded)
        return ZStack(alignment: .bottom) {
            if stage > 0 && !claimed {
                // Truhla vykukuje z hliny: 1. klepnuti trochu, 2. vic, 3. cela venku.
                PixelChest(pixel: 4)
                    .frame(height: 32 * CGFloat(stage) / CGFloat(egg.tapsNeeded), alignment: .top)
                    .clipped()
                    .offset(y: -10)
                    .onTapGesture { if chestReady { claim() } else { dig() } }
                DirtMound()
            }
        }
        .frame(width: egg.hitSize.width, height: egg.hitSize.height)
        .contentShape(Rectangle())
        .onTapGesture { dig() }
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: taps)
        .animation(.easeOut(duration: 0.3), value: claimed)
    }

    private func dig() {
        guard !claimed, !chestReady else { return }
        taps += 1
        FQFeedback.shared.haptic(.light)
    }

    private func tapSurface() {
        guard !claimed else { return }
        ripple += 1
        if !chestReady {
            taps += 1
            FQFeedback.shared.haptic(.light)
        }
    }

    private func claim() {
        guard !claimed else { return }
        claimed = true
        FQFeedback.shared.haptic(.success)
        FQFeedback.shared.play(.coin)
        onReward()
    }
}

/// Rozbihajici se kruh (kola na vode, zachveni planety). Kazda zmena `trigger` spusti jeden.
private struct RippleRing: View {
    let trigger: Int
    var color: Color = .white
    @State private var progress = 1.0

    var body: some View {
        Ellipse()
            .stroke(color.opacity(0.8 * (1 - progress)), lineWidth: 3)
            .scaleEffect(0.3 + 0.7 * progress)
            .allowsHitTesting(false)
            .onChange(of: trigger) {
                progress = 0
                withAnimation(.easeOut(duration: 0.7)) { progress = 1 }
            }
    }
}

/// Mince vyletujici z planety po odmene.
private struct CoinBurst: View {
    @State private var spread = false

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(FQColor.coin)
                    .offset(x: spread ? cos(angle) * 60 : 0, y: spread ? sin(angle) * 60 : 0)
                    .opacity(spread ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { spread = true } }
    }
}

/// Pixelova truhla (12 x 9 pixelu).
struct PixelChest: View {
    var pixel: CGFloat = 5

    private static let rows = [
        "..kkkkkkkk..",
        ".kyttttttyk.",
        "kttttttttttk",
        "kyyyyyyyyyyk",
        "kttttwwttttk",
        "kttttyyttttk",
        "kttttttttttk",
        "kyttttttttyk",
        "kkkkkkkkkkkk",
    ]
    private static let colors: [Character: Color] = [
        "k": Color(red: 0.16, green: 0.10, blue: 0.07),
        "t": Color(red: 0.62, green: 0.38, blue: 0.18),
        "y": Color(red: 0.98, green: 0.80, blue: 0.30),
        "w": Color(red: 1, green: 0.96, blue: 0.80),
    ]

    var body: some View {
        Canvas { context, _ in
            for (y, row) in Self.rows.enumerated() {
                for (x, char) in row.enumerated() {
                    guard let color = Self.colors[char] else { continue }
                    context.fill(Path(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: pixel, height: pixel)), with: .color(color))
                }
            }
        }
        .frame(width: 12 * pixel, height: 9 * pixel)
        .shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: 2)
    }
}

/// Hromadka vykopane hliny pod truhlou.
private struct DirtMound: View {
    var body: some View {
        Canvas { context, size in
            let pixel: CGFloat = 4
            let rows = ["...dddddd...", ".dddDDDDddd.", "ddDDDDDDDDdd"]
            for (y, row) in rows.enumerated() {
                for (x, char) in row.enumerated() where char != "." {
                    let color = char == "D" ? Color(red: 0.36, green: 0.24, blue: 0.14) : Color(red: 0.50, green: 0.34, blue: 0.20)
                    context.fill(Path(CGRect(x: CGFloat(x) * pixel, y: size.height - CGFloat(rows.count - y) * pixel, width: pixel, height: pixel)), with: .color(color))
                }
            }
        }
        .frame(width: 48, height: 12)
        .allowsHitTesting(false)
    }
}

/// Pocitadlo minci po nalezeni easter eggu: plynule dopocita z puvodniho stavu na novy.
struct CoinRewardToast: View {
    let from: Int
    let to: Int
    @State private var value: Double = 0

    var body: some View {
        HStack(spacing: FQSpace.sm) {
            Image(systemName: "dollarsign.circle.fill").foregroundStyle(FQColor.coin)
            CoinCount(value: value)
                .fqFont(size: 17, weight: .bold, design: .rounded)
                .monospacedDigit()
                .foregroundStyle(FQColor.textPrimary)
            Text("+\(to - from)")
                .fqFont(size: 15, weight: .semibold, design: .rounded)
                .foregroundStyle(FQColor.coin)
        }
        .padding(.horizontal, FQSpace.lg)
        .frame(minHeight: 44)
        .background(Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255).opacity(0.85), in: Capsule())
        .overlay { Capsule().strokeBorder(FQColor.coin.opacity(0.6), lineWidth: 1) }
        .onAppear {
            value = Double(from)
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) { value = Double(to) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Found \(to - from) coins. You have \(to) coins.")
    }
}

private struct CoinCount: View, Animatable {
    var value: Double
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View { Text("\(Int(value.rounded()))") }
}
