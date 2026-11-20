import SwiftUI

/// Barva kruhu levelu podle stupne: plna barva, bez prechodu a odlesku. Od zlata vys ma kruh kridla.
enum LevelTier: Equatable {
    case bronze, silver, gold, sapphire, rainbow

    init(level: Int) {
        switch level {
        case ..<5: self = .bronze
        case 5..<10: self = .silver
        case 10..<15: self = .gold
        case 15..<20: self = .sapphire
        default: self = .rainbow
        }
    }

    var color: Color {
        switch self {
        case .bronze: Color(red: 201 / 255, green: 122 / 255, blue: 62 / 255)   // #C97A3E
        case .silver: Color(red: 185 / 255, green: 194 / 255, blue: 210 / 255)  // #B9C2D2
        case .gold: Color(red: 1, green: 194 / 255, blue: 51 / 255)              // #FFC233
        case .sapphire: Color(red: 74 / 255, green: 163 / 255, blue: 1)          // #4AA3FF
        case .rainbow: Color(red: 162 / 255, green: 116 / 255, blue: 1)          // #A274FF
        }
    }

    var hasWings: Bool { self == .gold || self == .sapphire || self == .rainbow }
}

/// Leve kridlo: 3 pera v souradnicich 200 x 140 (stejne cesty jako rankBlock() v prototypu).
private struct LevelWingShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 200, sy = rect.height / 140
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(56, 56))
        path.addCurve(to: p(6, 40), control1: p(40, 38), control2: p(22, 34))
        path.addCurve(to: p(54, 66), control1: p(20, 48), control2: p(36, 56))
        path.closeSubpath()
        path.move(to: p(54, 68))
        path.addCurve(to: p(8, 66), control1: p(36, 58), control2: p(20, 58))
        path.addCurve(to: p(54, 80), control1: p(22, 72), control2: p(38, 76))
        path.closeSubpath()
        path.move(to: p(56, 82))
        path.addCurve(to: p(22, 92), control1: p(42, 80), control2: p(30, 84))
        path.addCurve(to: p(58, 90), control1: p(34, 94), control2: p(46, 92))
        path.closeSubpath()
        return path
    }
}

/// Kruh levelu jen s cislem (bez "LEVEL"), od zlata s kridly. Plocha 120 x 84 = viewBox 200 x 140.
struct LevelRing: View {
    let level: Int

    private static let size = CGSize(width: 120, height: 84)
    private static let scale: CGFloat = 120 / 200

    var body: some View {
        let tier = LevelTier(level: level)
        let s = Self.scale
        ZStack {
            if tier.hasWings {
                LevelWingShape().fill(tier.color)
                LevelWingShape().fill(tier.color).scaleEffect(x: -1, y: 1)
            }
            Circle()
                .fill(Color(red: 10 / 255, green: 8 / 255, blue: 24 / 255).opacity(0.55))
                .frame(width: 80 * s, height: 80 * s)
            Circle()
                .stroke(tier.color, lineWidth: 13 * s)
                .frame(width: 92 * s, height: 92 * s)
            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 1.5 * s)
                .frame(width: 79 * s, height: 79 * s)
            Text("\(level)")
                .font(.system(size: level >= 100 ? 22 : 30, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(width: 70 * s)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 7, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level)")
    }
}

/// Pravy sloupec karty hrdiny: kruh levelu, kratka lista XP v barve kruhu a "340 / 1000 XP to 8".
struct LevelBadge: View {
    let level: Int
    let xpInto: Int
    let xpFor: Int

    private var progress: Double { min(1, max(0, Double(xpInto) / Double(max(1, xpFor)))) }

    var body: some View {
        let color = LevelTier(level: level).color
        VStack(spacing: 4) {
            LevelRing(level: level)
            Capsule()
                .fill(Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255).opacity(0.55))
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule().fill(color).frame(width: proxy.size.width * progress)
                    }
                }
                .overlay { Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1) }
                .frame(width: 74, height: 7)
                .clipShape(Capsule())
                .accessibilityHidden(true)
            Text("\(xpInto) / \(xpFor) XP to \(level + 1)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
                .fixedSize()
                .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
        }
        .frame(width: 118)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level)")
        .accessibilityValue("\(xpInto) of \(xpFor) XP to level \(level + 1)")
    }
}
