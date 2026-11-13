import SwiftUI

/// Svisla cesta bossu jednoho sveta (jako lekce v Duolingu).
/// Uzel N trva 10 + 5*(N-1) minut; dalsi uzel se odemkne porazenim predchoziho.
struct WorldPathView: View {
    @ObservedObject var model: ArenaViewModel
    let world: BossWorld
    let onStartBattle: () -> Void

    private static let rowHeight: CGFloat = 150
    /// Vodorovny posun uzlu - cesta se vlni zleva doprava.
    private static let swing: [CGFloat] = [0, 0.55, 0.85, 0.55, 0, -0.55, -0.85, -0.55]

    private var cleared: Int { model.clearedNodes(in: world) }

    var body: some View {
        ScreenScaffold(scene: world.scene) {
            header
            path
        }
        .navigationTitle(world.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: FQSpace.md) {
            Image(systemName: world.symbol)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(world.accent)
                .frame(width: 48, height: 48)
                .background(world.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: FQSpace.xs) {
                Text(world.tagline).font(.fqSecondary).foregroundStyle(FQColor.textPrimary)
                Text("\(cleared) of \(world.bosses.count) bosses defeated · fixed timers \(world.durationRange)")
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
            }
        }
        .padding(FQSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: world.accent.opacity(0.3))
    }

    private var path: some View {
        let bosses = world.bosses
        return GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                connector(count: bosses.count + 1, width: width)
                ForEach(Array(bosses.enumerated()), id: \.element.id) { index, boss in
                    node(boss, index: index)
                        .position(center(index: index, width: width))
                }
                finishChest
                    .position(center(index: bosses.count, width: width))
            }
        }
        .frame(height: Self.rowHeight * CGFloat(bosses.count + 1))
    }

    private func center(index: Int, width: CGFloat) -> CGPoint {
        let reach = min(110, width / 2 - 70)
        let offset = Self.swing[index % Self.swing.count] * reach
        return CGPoint(x: width / 2 + offset, y: Self.rowHeight * (CGFloat(index) + 0.5))
    }

    /// Teckovana cesta mezi uzly; prosla cast je ve barve sveta.
    private func connector(count: Int, width: CGFloat) -> some View {
        Canvas { context, _ in
            for index in 0..<(count - 1) {
                let from = center(index: index, width: width)
                let to = center(index: index + 1, width: width)
                var segment = Path()
                segment.move(to: from)
                segment.addCurve(to: to, control1: CGPoint(x: from.x, y: from.y + Self.rowHeight * 0.5), control2: CGPoint(x: to.x, y: to.y - Self.rowHeight * 0.5))
                let color = index < cleared ? world.accent : Color.white.opacity(0.25)
                context.stroke(segment, with: .color(color), style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [0.1, 14]))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func node(_ boss: Boss, index: Int) -> some View {
        let isCleared = index < cleared
        let isCurrent = index == cleared
        let isLocked = index > cleared
        Button {
            model.selectBoss(boss)
            onStartBattle()
        } label: {
            VStack(spacing: FQSpace.xs) {
                ZStack {
                    if isCurrent { PulseRing(color: world.accent) }
                    Circle()
                        .fill(isLocked ? AnyShapeStyle(Material.ultraThinMaterial) : AnyShapeStyle(world.accent.gradient))
                        .overlay { Circle().strokeBorder(Color.white.opacity(isLocked ? 0.18 : 0.55), lineWidth: 1) }
                        .shadow(color: (isLocked ? Color.black : world.accent).opacity(0.45), radius: 10, y: 6)
                        .frame(width: 78, height: 78)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(FQColor.textSecondary)
                    } else {
                        PixelArtAvatarView(sprite: .boss(boss.pixelSpriteConfig), size: 56)
                    }
                    if isCleared {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white, FQColor.accent)
                            .offset(x: 28, y: -28)
                    }
                }
                .frame(width: 96, height: 90)
                Text(isLocked ? "Node \(index + 1)" : boss.name)
                    .font(.fqLabel)
                    .foregroundStyle(isLocked ? FQColor.textSecondary : FQColor.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: 170)
                Text(ArenaView.durationText(minutes: boss.maxHP))
                    .font(.fqMeta)
                    .monospacedDigit()
                    .foregroundStyle(isCurrent ? world.accent : FQColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked || !model.isBetweenBattles)
        .accessibilityLabel(isLocked ? "Locked node \(index + 1), \(boss.maxHP) minutes" : "\(boss.name), \(boss.maxHP) minute battle")
        .accessibilityValue(isCleared ? "Defeated" : (isCurrent ? "Next battle" : "Locked"))
    }

    private var finishChest: some View {
        let isComplete = cleared >= world.bosses.count
        return VStack(spacing: FQSpace.xs) {
            Image(systemName: isComplete ? "crown.fill" : "shippingbox.fill")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(isComplete ? world.accent : FQColor.textSecondary)
                .frame(width: 78, height: 78)
                .glassControl(in: Circle())
            Text(isComplete ? "World conquered" : "World chest")
                .font(.fqLabel)
                .foregroundStyle(isComplete ? FQColor.textPrimary : FQColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Pulzujici prstenec kolem uzlu, ktery je na rade.
private struct PulseRing: View {
    let color: Color
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .stroke(color.opacity(expanded ? 0 : 0.7), lineWidth: 4)
            .frame(width: expanded ? 104 : 82, height: expanded ? 104 : 82)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { expanded = true }
            }
            .accessibilityHidden(true)
    }
}
