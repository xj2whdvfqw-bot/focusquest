import SwiftUI

struct BossHealthBarView: View {
    let currentHP: Int
    let maxHP: Int
    var segments = 18
    private var filledSegments: Int {
        guard maxHP > 0 else { return 0 }
        return Int((Double(max(0, currentHP)) / Double(maxHP) * Double(segments)).rounded(.down))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FQSpace.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Boss integrity").font(.fqLabel).foregroundStyle(FQColor.textSecondary)
                Spacer(minLength: FQSpace.sm)
                Text("\(max(0, currentHP)) / \(maxHP) HP").font(.fqLabel).monospacedDigit().foregroundStyle(FQColor.textPrimary)
            }
            HStack(spacing: FQSpace.xs) {
                ForEach(0..<max(1, segments), id: \.self) { index in
                    RoundedRectangle(cornerRadius: FQRadius.tile, style: .continuous).fill(index < filledSegments ? FQColor.danger : FQColor.track)
                        .frame(maxWidth: .infinity).frame(height: 8)
                        .animation(.easeOut(duration: 0.3), value: filledSegments)
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Boss health \(max(0, currentHP)) of \(maxHP)")
    }
}
