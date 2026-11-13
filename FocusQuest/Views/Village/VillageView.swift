import SwiftUI

/// Zalozka Vesnice: obydli, ktere roste s porazenymi bossy.
struct VillageView: View {
    @ObservedObject var model: ProfileViewModel

    private var village: VillageState { model.profile.village }
    private var stageNumber: Int { (DwellingStage.allCases.firstIndex(of: village.stage) ?? 0) + 1 }

    var body: some View {
        ScreenScaffold(scene: .castleKeep) {
            ScreenHeader(eyebrow: "Village", title: "Your base")
            dwellingCard
            ScreenSection(title: "Evolution", detail: "Stage \(stageNumber) of \(DwellingStage.allCases.count)") { evolutionStrip }
            HStack(spacing: FQSpace.md) {
                resource("Coins", value: "\(model.profile.coins)", icon: "dollarsign.circle.fill")
                resource("Bosses", value: "\(model.profile.bossesDefeated)", icon: "trophy.fill")
                resource("Level", value: "\(model.level)", icon: "star.fill")
            }
            ScreenSection(title: "Next upgrade") { upgradeCard }
            ScreenSection(title: "Building path") { pathCard }
        }
        .task { await model.refreshProgress() }
    }

    /// Cela cesta od chatrce po mesto na jeden pohled: postavene barevne, zamcene jako silueta.
    private var evolutionStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FQSpace.xs) {
                    ForEach(Array(DwellingStage.allCases.enumerated()), id: \.element.id) { index, stage in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.fqMeta.weight(.semibold))
                                .foregroundStyle(index < stageNumber ? FQColor.accent : FQColor.textTertiary)
                                .accessibilityHidden(true)
                        }
                        evolutionTile(stage, isBuilt: index < stageNumber, isCurrent: stage == village.stage)
                            .id(stage)
                    }
                }
                .padding(FQSpace.md)
            }
            .glassCard()
            .onAppear { proxy.scrollTo(village.stage, anchor: .center) }
        }
    }

    private func evolutionTile(_ stage: DwellingStage, isBuilt: Bool, isCurrent: Bool) -> some View {
        VStack(spacing: FQSpace.xs) {
            DwellingArtView(stage: stage, size: 64, isLocked: !isBuilt)
                .frame(width: 72, height: 72)
                .background(isCurrent ? FQColor.accent.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous)
                        .strokeBorder(isCurrent ? FQColor.accent : Color.clear, lineWidth: 2)
                }
                .overlay(alignment: .topTrailing) {
                    if !isBuilt {
                        Image(systemName: "lock.fill").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(FQColor.textSecondary).padding(FQSpace.xs)
                    }
                }
            Text(stage.displayName).font(.fqMeta.weight(isCurrent ? .semibold : .regular)).foregroundStyle(isBuilt ? FQColor.textPrimary : FQColor.textSecondary).lineLimit(1)
            Text(isBuilt ? (isCurrent ? "You are here" : "Built") : "Level \(stage.requirement.level)")
                .font(.fqMeta)
                .foregroundStyle(isCurrent ? FQColor.accent : FQColor.textTertiary)
        }
        .frame(width: 96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stage.displayName), \(isBuilt ? (isCurrent ? "current" : "built") : "locked, needs level \(stage.requirement.level)")")
    }

    private static let nightSky: [Color] = [
        Color(red: 0.10, green: 0.10, blue: 0.26),
        Color(red: 0.26, green: 0.20, blue: 0.42)
    ]
    private static let nightHill: [Color] = [
        Color(red: 0.20, green: 0.42, blue: 0.32),
        Color(red: 0.10, green: 0.24, blue: 0.20)
    ]

    private var dwellingCard: some View {
        VStack(spacing: FQSpace.md) {
            // Obydli stoji v male nocni scene (ladi s pixelovou krajinou za obrazovkou):
            // hvezdna obloha a kopec v mesicnim svetle.
            ZStack(alignment: .bottom) {
                LinearGradient(colors: Self.nightSky, startPoint: .top, endPoint: .bottom)
                VillageStars()
                Ellipse()
                    .fill(LinearGradient(colors: Self.nightHill, startPoint: .top, endPoint: .bottom))
                    .frame(height: 64)
                    .offset(y: 30)
                DwellingArtView(stage: village.stage, size: 176)
                    .offset(y: -8)
                    .id(village.stage)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous))
            VStack(spacing: FQSpace.xs) {
                Text(village.stage.displayName).font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                Text(village.stage.summary)
                    .font(.fqSecondary)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(FQColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(FQSpace.lg)
        .glassCard()
    }

    private func resource(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: FQSpace.sm) {
            IconTile(symbol: icon)
            VStack(alignment: .leading, spacing: FQSpace.xs) {
                Text(value).font(.fqHeadline).monospacedDigit().foregroundStyle(FQColor.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                Text(title).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FQSpace.md)
        .glassCard(radius: FQRadius.control)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var upgradeCard: some View {
        if let next = village.nextStage {
            let requirement = next.requirement
            VStack(alignment: .leading, spacing: FQSpace.md) {
                HStack(spacing: FQSpace.md) {
                    DwellingArtView(stage: next, size: 56)
                    VStack(alignment: .leading, spacing: FQSpace.xs) {
                        Text(next.displayName).font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                        Text(next.summary).font(.fqSecondary).foregroundStyle(FQColor.textSecondary)
                    }
                }
                HairlineDivider()
                VStack(spacing: FQSpace.sm) {
                    requirementRow("Hero level", current: model.level, needed: requirement.level)
                    requirementRow("Bosses defeated", current: model.profile.bossesDefeated, needed: requirement.bossesDefeated)
                    requirementRow("Coins", current: model.profile.coins, needed: requirement.coins)
                }
                Button { withAnimation(.easeOut(duration: 0.3)) { model.upgradeVillage() } } label: {
                    Label("Build \(next.displayName)", systemImage: "hammer.fill")
                        .font(.fqHeadline)
                        .foregroundStyle(model.canUpgradeVillage ? FQColor.onAccent : FQColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FQSpace.xs)
                }
                .prominentGlassButtonStyle()
                .buttonBorderShape(.roundedRectangle(radius: FQRadius.control))
                .controlSize(.large)
                .tint(FQColor.accent)
                .disabled(!model.canUpgradeVillage)
                if !model.canUpgradeVillage {
                    Text("Win focus battles to earn coins and unlock this build.")
                        .font(.fqMeta)
                        .foregroundStyle(FQColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(FQSpace.lg)
            .glassCard()
        } else {
            Label("Your city is complete. New buildings arrive in a future update.", systemImage: "checkmark.seal.fill")
                .font(.fqSecondary)
                .foregroundStyle(FQColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FQSpace.lg)
                .glassCard()
        }
    }

    private func requirementRow(_ title: String, current: Int, needed: Int) -> some View {
        let isMet = current >= needed
        return HStack(spacing: FQSpace.md) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isMet ? FQColor.accent : FQColor.textTertiary)
                .accessibilityHidden(true)
            Text(title).font(.fqBody).foregroundStyle(FQColor.textPrimary)
            Spacer(minLength: FQSpace.sm)
            Text("\(min(current, needed)) / \(needed)").font(.fqLabel).monospacedDigit().foregroundStyle(isMet ? FQColor.accent : FQColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(current) of \(needed)\(isMet ? ", done" : "")")
    }

    private var pathCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(DwellingStage.allCases.enumerated()), id: \.element.id) { index, stage in
                let isBuilt = index < stageNumber
                let isCurrent = stage == village.stage
                if index > 0 { HairlineDivider() }
                HStack(spacing: FQSpace.md) {
                    DwellingArtView(stage: stage, size: 40).opacity(isBuilt ? 1 : 0.45)
                    Text(stage.displayName).font(.fqBody).foregroundStyle(isBuilt ? FQColor.textPrimary : FQColor.textSecondary)
                    Spacer(minLength: FQSpace.sm)
                    if isCurrent {
                        Text("Current").font(.fqMeta.weight(.medium)).foregroundStyle(FQColor.accent)
                    } else if isBuilt {
                        Image(systemName: "checkmark").font(.fqMeta.weight(.semibold)).foregroundStyle(FQColor.textSecondary).accessibilityLabel("Built")
                    } else {
                        Label("\(stage.requirement.coins)", systemImage: "lock.fill").font(.fqMeta.weight(.medium)).monospacedDigit().foregroundStyle(FQColor.textTertiary)
                            .accessibilityLabel("Locked, costs \(stage.requirement.coins) coins")
                    }
                }
                .padding(.vertical, FQSpace.sm)
            }
        }
        .padding(.horizontal, FQSpace.lg)
        .padding(.vertical, FQSpace.xs)
        .glassCard()
    }
}

/// Obrazek obydli. Zatim jednoduchy pixel art slozeny z vrstev;
/// skutecne assety (hrady, vesnice) se pozdeji vymeni jen tady.
struct DwellingArtView: View {
    let stage: DwellingStage
    var size: CGFloat = 160
    /// Zamceny stupen se kresli jako tmava silueta.
    var isLocked = false

    var body: some View {
        art
            .colorMultiply(isLocked ? Color.black : Color.white)
            .opacity(isLocked ? 0.3 : 1)
    }

    private var art: some View {
        Group {
            switch stage {
            case .woodenHut: building(.hut, scale: 1)
            case .brickCottage: building(.brick, scale: 1)
            case .stoneHouse: building(.stone, scale: 1)
            case .castle: building(.castle, scale: 1)
            case .village:
                HStack(alignment: .bottom, spacing: 0) {
                    building(.hut, scale: 0.28)
                    building(.castle, scale: 0.44)
                    building(.brick, scale: 0.28)
                }
            case .city:
                HStack(alignment: .bottom, spacing: 0) {
                    building(.stone, scale: 0.18)
                    building(.brick, scale: 0.18)
                    building(.castle, scale: 0.28)
                    building(.stone, scale: 0.18)
                    building(.hut, scale: 0.18)
                }
            }
        }
        .frame(width: size, height: size, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stage.displayName)
    }

    private func building(_ kind: BuildingSprite, scale: CGFloat) -> some View {
        PixelLayerStack(layers: kind.layers).frame(width: size * scale, height: size * scale)
    }
}

private enum BuildingSprite {
    case hut, brick, stone, castle

    private static let wood = RGB(0.60, 0.42, 0.26)
    private static let door = RGB(0.36, 0.24, 0.15)
    private static let glow = RGB(1.00, 0.88, 0.55)
    private static let rock = RGB(0.62, 0.65, 0.72)
    private static let shade = RGB(0.20, 0.22, 0.32)

    var layers: [AvatarLayer] {
        switch self {
        case .hut: Self.house(roof: RGB(0.87, 0.72, 0.38), walls: Self.wood, chimney: false)
        case .brick: Self.house(roof: RGB(0.30, 0.33, 0.45), walls: RGB(0.74, 0.36, 0.30), chimney: true)
        case .stone: Self.house(roof: RGB(0.36, 0.42, 0.62), walls: Self.rock, chimney: true)
        case .castle: Self.castleLayers
        }
    }

    private static func house(roof: RGB, walls: RGB, chimney: Bool) -> [AvatarLayer] {
        var wallSpans: [Int: [ClosedRange<Int>]] = [:]
        for y in 8...13 { wallSpans[y] = [4...11] }
        if chimney { wallSpans[3] = [10...10]; wallSpans[4] = [10...10] }
        return [
            AvatarLayer(id: "walls", rows: AvatarSprite.grid(wallSpans), rgb: walls),
            AvatarLayer(id: "roof", rows: AvatarSprite.grid([3: [7...8], 4: [6...9], 5: [5...10], 6: [4...11], 7: [3...12]]), rgb: roof),
            AvatarLayer(id: "door", rows: AvatarSprite.grid([11: [7...8], 12: [7...8], 13: [7...8]]), rgb: door),
            AvatarLayer(id: "windows", rows: AvatarSprite.grid([9: [5...6, 9...10]]), rgb: glow)
        ]
    }

    private static var castleLayers: [AvatarLayer] {
        var stoneSpans: [Int: [ClosedRange<Int>]] = [2: [2...2, 4...4, 11...11, 13...13], 6: [2...5, 7...8, 10...13]]
        for y in 3...5 { stoneSpans[y] = [2...4, 11...13] }
        for y in 7...13 { stoneSpans[y] = [2...13] }
        return [
            AvatarLayer(id: "stone", rows: AvatarSprite.grid(stoneSpans), rgb: rock),
            AvatarLayer(id: "shade", rows: AvatarSprite.grid([2: [7...7], 3: [7...7], 4: [7...7], 5: [3...3, 7...7, 12...12], 9: [5...5, 10...10], 11: [7...8], 12: [7...8], 13: [7...8]]), rgb: shade),
            AvatarLayer(id: "flag", rows: AvatarSprite.grid([2: [8...9], 3: [8...9]]), rgb: RGB(0.85, 0.25, 0.33))
        ]
    }
}

/// Par pixelovych hvezd na nocni obloze nad obydlim.
private struct VillageStars: View {
    // Pozice jako zlomky sirky a vysky, velikost v bodech.
    private static let stars: [(x: Double, y: Double, size: Double)] = [
        (0.08, 0.12, 3), (0.20, 0.30, 2), (0.31, 0.08, 2), (0.70, 0.10, 3),
        (0.82, 0.28, 2), (0.92, 0.14, 2), (0.58, 0.22, 2), (0.14, 0.50, 2), (0.88, 0.48, 2)
    ]

    var body: some View {
        Canvas { context, size in
            for star in Self.stars {
                let rect = CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)
                context.fill(Path(rect), with: .color(.white.opacity(0.8)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
