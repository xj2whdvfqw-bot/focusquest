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

struct BattleReceiptCard: View {
    let profile: UserProfile
    let boss: Boss
    let focusMinutes: Int
    let flawless: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.1, blue: 0.18), Color(red: 0.2, green: 0.1, blue: 0.19), Color(red: 0.06, green: 0.18, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 22) {
                Text("FOCUSQUEST / BATTLE RECORD").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(.white.opacity(0.65))
                PixelArtAvatarView(sprite: .boss(boss.pixelSpriteConfig), size: 150)
                Text("BOSS DEFEATED").font(.system(size: 27, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text(boss.name).font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                Rectangle().fill(.white.opacity(0.15)).frame(height: 1).padding(.horizontal, 34)
                HStack(spacing: 18) {
                    PixelArtAvatarView(sprite: .hero(profile.heroClass), size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.username).font(.system(size: 18, weight: .bold, design: .rounded))
                        Text(profile.title).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.68))
                    }
                    Spacer()
                }.padding(.horizontal, 30)
                Text("\(focusMinutes) MIN VERIFIED FOCUS").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(Color(red: 0.53, green: 0.88, blue: 0.78))
                if flawless { Text("0 PICKUPS - FLAWLESS FOCUS").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.yellow) }
                Spacer(minLength: 0)
            }.padding(.top, 36).padding(.bottom, 25)
        }
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .preferredColorScheme(.dark)
    }
}

struct BattleReceiptShareView: View {
    let image: UIImage
    var body: some View { ShareLink(item: Image(uiImage: image), preview: SharePreview("FocusQuest battle victory", image: Image(uiImage: image))) { Label("Share Victory", systemImage: "square.and.arrow.up") } }
}