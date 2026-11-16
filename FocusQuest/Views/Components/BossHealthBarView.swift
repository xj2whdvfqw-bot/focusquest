import SwiftUI

/// Zdravi bosse v bitve: tenky pruh v barve sveta a pod nim "18 / 25 HP".
struct BossHealthBarView: View {
    let currentHP: Int
    let maxHP: Int
    /// Podil zbyvajiciho zdravi 0...1. Bitva ho pocita po sekundach, aby pruh ubyval plynule,
    /// i kdyz HP v textu klesa po celych minutach.
    let fraction: Double
    var tint: Color = FQColor.accent

    private var clamped: Double { min(1, max(0, fraction)) }

    var body: some View {
        VStack(spacing: FQSpace.xs) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(FQColor.track)
                    Capsule().fill(tint).frame(width: proxy.size.width * clamped)
                }
            }
            .frame(height: 6)
            .animation(.linear(duration: 1), value: clamped)
            Text("\(max(0, currentHP)) / \(maxHP) HP")
                .font(.fqMeta)
                .monospacedDigit()
                .foregroundStyle(FQColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Boss health \(max(0, currentHP)) of \(maxHP)")
    }
}
