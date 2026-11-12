import SwiftUI
import UIKit

@MainActor
struct BattleReceiptRenderer {
    static func render(profile: UserProfile, boss: Boss, focusMinutes: Int, flawless: Bool) -> UIImage? {
        let view = BattleReceiptCard(profile: profile, boss: boss, focusMinutes: focusMinutes, flawless: flawless)
            .frame(width: 360, height: 640)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// Obrazek ke sdileni po vyhre. Kresli se mimo obrazovku pres ImageRenderer, ktery neumi
/// materialy (rozmazani), proto je "sklo" slozene z prechodu a prusvitnych vyplni,
/// a sprity jsou staticke (zadna animace).
struct BattleReceiptCard: View {
    let profile: UserProfile
    let boss: Boss
    let focusMinutes: Int
    let flawless: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.12), Color(red: 0.10, green: 0.08, blue: 0.22), Color(red: 0.04, green: 0.12, blue: 0.15)], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(RadialGradient(colors: [FQColor.accent.opacity(0.35), FQColor.accent.opacity(0)], center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 400, height: 400)
                .offset(x: 120, y: -220)
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.36, green: 0.38, blue: 0.98).opacity(0.4), Color.clear], center: .center, startRadius: 0, endRadius: 220))
                .frame(width: 440, height: 440)
                .offset(x: -140, y: 180)

            VStack(spacing: FQSpace.xl) {
                Text("FocusQuest battle record").font(.system(size: 13, weight: .medium)).foregroundStyle(FQColor.textSecondary)
                StaticPixelSprite(sprite: .boss(boss.pixelSpriteConfig), size: 152)
                VStack(spacing: FQSpace.xs) {
                    Text("Boss defeated").font(.system(size: 28, weight: .semibold)).foregroundStyle(FQColor.textPrimary)
                    Text(boss.name).font(.system(size: 17)).foregroundStyle(FQColor.textSecondary)
                }
                VStack(spacing: FQSpace.md) {
                    HStack(spacing: FQSpace.lg) {
                        StaticPixelSprite(sprite: .hero(profile.heroClass), size: 64)
                        VStack(alignment: .leading, spacing: FQSpace.xs) {
                            Text(profile.username).font(.system(size: 17, weight: .semibold)).foregroundStyle(FQColor.textPrimary)
                            Text(profile.title).font(.system(size: 13)).foregroundStyle(FQColor.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    Rectangle().fill(FQColor.hairline).frame(height: 1)
                    HStack {
                        Text("\(focusMinutes) min verified focus").font(.system(size: 15, weight: .medium)).foregroundStyle(FQColor.accent)
                        Spacer(minLength: FQSpace.sm)
                        if flawless { Text("Flawless").font(.system(size: 13, weight: .medium)).foregroundStyle(FQColor.textPrimary) }
                    }
                }
                .padding(FQSpace.lg)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: FQRadius.card, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: FQRadius.card, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1) }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, FQSpace.xl)
            .padding(.top, 40)
            .padding(.bottom, FQSpace.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }
}

struct BattleReceiptShareView: View {
    let image: UIImage

    var body: some View {
        ShareLink(item: Image(uiImage: image), preview: SharePreview("FocusQuest battle victory", image: Image(uiImage: image))) {
            Label("Share Victory", systemImage: "square.and.arrow.up")
                .font(.fqHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FQSpace.xs)
        }
        .glassButtonStyle()
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(FQColor.textPrimary)
    }
}
