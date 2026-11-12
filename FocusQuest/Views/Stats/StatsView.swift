import SwiftUI

struct StatsView: View {
    @ObservedObject var model: StatsViewModel
    @ObservedObject var profile: ProfileViewModel

    var body: some View {
        ZStack {
            FocusQuestBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Your progression").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().stroke(.white.opacity(0.14), lineWidth: 9)
                            Circle().trim(from: 0, to: Double(model.stats.xpIntoLevel) / Double(model.stats.xpForNextLevel)).stroke(Color.mint, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                            VStack(spacing: 0) { Text("LV").font(.system(size: 10, weight: .bold, design: .monospaced)); Text("\(model.stats.level)").font(.system(size: 24, weight: .bold, design: .rounded)) }
                        }.frame(width: 76, height: 76)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(profile.profile.title).font(.system(size: 18, weight: .bold, design: .rounded))
                            Text("\(model.stats.xpIntoLevel) / \(model.stats.xpForNextLevel) XP to next level").font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.68))
                            ProgressView(value: Double(model.stats.xpIntoLevel), total: Double(model.stats.xpForNextLevel)).tint(.mint)
                        }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).glassmorphic()

                    HStack(spacing: 10) {
                        metric("WIN RATE", value: "\(Int(model.stats.winRate * 100))%", icon: "scope")
                        metric("HP DEALT", value: "\(model.stats.totalHPDealt)", icon: "bolt.fill")
                    }
                    HStack(spacing: 10) {
                        metric("BEST COMBO", value: "\(model.stats.bestCombo)x", icon: "flame.fill")
                        metric("FOCUS HOURS", value: String(format: "%.1f", Double(model.stats.sessionHistory.reduce(0) { $0 + $1.verifiedMinutes }) / 60), icon: "clock")
                    }
                    HStack { SectionEyebrow(title: "Verified battle log"); Spacer(); Text("\(model.stats.sessionHistory.count) battles").font(.caption).foregroundStyle(.white.opacity(0.6)) }
                    if model.stats.sessionHistory.isEmpty {
                        Text("Your verified battles will appear here.").font(.system(size: 14, design: .rounded)).foregroundStyle(.white.opacity(0.6)).frame(maxWidth: .infinity, alignment: .leading).padding(18).glassmorphic()
                    } else {
                        ForEach(model.stats.sessionHistory) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 5) { Text(entry.bossName).font(.system(size: 14, weight: .bold, design: .rounded)); Text(entry.completedAt, style: .date).font(.caption).foregroundStyle(.white.opacity(0.58)) }
                                Spacer()
                                Text("\(entry.verifiedMinutes)m - +\(entry.xpEarned) XP").font(.system(size: 11, weight: .medium, design: .monospaced))
                            }.padding(15).glassmorphic(radius: 16)
                        }
                    }
                }.padding(18)
            }
        }.preferredColorScheme(.dark).task { await model.load() }
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.62))
            Text(value).font(.system(size: 25, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(15).glassmorphic(radius: 18)
    }
}