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
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                SectionEyebrow(title: "Boss integrity")
                Spacer()
                Text("\(max(0, currentHP)) / \(maxHP) HP").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
            }
            HStack(spacing: 3) {
                ForEach(0..<max(1, segments), id: \.self) { index in
                    Capsule().fill(index < filledSegments ? Color(red: 0.96, green: 0.35, blue: 0.39) : Color.white.opacity(0.12))
                        .frame(maxWidth: .infinity).frame(height: 12)
                        .animation(.easeOut(duration: 0.3), value: filledSegments)
                }
            }
            .accessibilityLabel("Boss health \(currentHP) of \(maxHP)")
        }
    }
}