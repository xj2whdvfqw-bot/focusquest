import SwiftUI

struct ProfileView: View {
    @ObservedObject var model: ProfileViewModel
    @State private var usernameDraft = ""

    var body: some View {
        ZStack {
            FocusQuestBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    Text("Hero profile").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    HStack(spacing: 15) {
                        PixelArtAvatarView(sprite: .hero(model.profile.heroClass), size: 90)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.profile.username).font(.system(size: 21, weight: .bold, design: .rounded))
                            Text(model.profile.title).font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.65))
                            if model.isSaving { ProgressView().controlSize(.small) }
                        }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).glassmorphic()

                    sectionTitle("Identity")
                    HStack {
                        TextField("Username", text: $usernameDraft).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.done).onSubmit { model.updateUsername(usernameDraft) }
                        Button { model.updateUsername(usernameDraft) } label: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.mint) }.accessibilityLabel("Save username")
                    }.padding(13).glassmorphic(radius: 16)
                    Picker("Title", selection: Binding(get: { model.profile.title }, set: model.updateTitle)) {
                        ForEach(["Novice Focuser", "Deep Work Mage", "Grandmaster of Stillness"], id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu).padding(.horizontal, 12).padding(.vertical, 5).glassmorphic(radius: 16)

                    sectionTitle("Hero class")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        ForEach(HeroClass.allCases) { hero in
                            Button { model.updateHeroClass(hero) } label: {
                                VStack(spacing: 6) { PixelArtAvatarView(sprite: .hero(hero), size: 58); Text(hero.displayName).font(.system(size: 11, weight: .semibold, design: .rounded)) }
                                    .frame(maxWidth: .infinity).padding(9).overlay(RoundedRectangle(cornerRadius: 16).stroke(hero == model.profile.heroClass ? Color.mint : .clear, lineWidth: 1.5)).glassmorphic(radius: 16)
                            }.buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 13) {
                        ZStack {
                            Circle().stroke(.white.opacity(0.13), lineWidth: 6)
                            Circle().trim(from: 0, to: min(1, Double(model.todayVerifiedMinutes) / Double(max(1, model.profile.dailyFocusGoalMinutes)))).stroke(.mint, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                            Text("\(model.todayVerifiedMinutes)").font(.system(size: 12, weight: .bold, design: .monospaced))
                        }.frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            sectionTitle("Daily focus target")
                            Text("\(model.todayVerifiedMinutes)m of \(model.profile.dailyFocusGoalMinutes)m verified today").font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                        }
                    }.padding(12).glassmorphic(radius: 16)
                    sectionTitle("Daily target - \(model.profile.dailyFocusGoalMinutes)m")
                    Slider(value: Binding(get: { Double(model.profile.dailyFocusGoalMinutes) }, set: { model.updateDailyGoal(Int($0 / 15) * 15) }), in: 30...180, step: 15).tint(.mint).padding(14).glassmorphic(radius: 16)

                    sectionTitle("Relics - Equip up to 2")
                    ForEach(LootItem.catalog) { item in
                        Button { model.toggleLoot(item.id) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: model.profile.equippedLootIDs.contains(item.id) ? "checkmark.seal.fill" : "seal").foregroundStyle(model.profile.equippedLootIDs.contains(item.id) ? .mint : .white.opacity(0.55))
                                VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.system(size: 14, weight: .bold, design: .rounded)); Text(item.description).font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.62)) }
                                Spacer(); Text(item.rarity.rawValue.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.yellow)
                            }.padding(13).glassmorphic(radius: 16)
                        }.buttonStyle(.plain).disabled(!model.profile.unlockedLootIDs.contains(item.id) && !model.profile.equippedLootIDs.contains(item.id))
                    }
                    if let error = model.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
                }.padding(18)
            }
        }.preferredColorScheme(.dark).onAppear { usernameDraft = model.profile.username }.task { await model.refresh(); await model.refreshProgress() }
    }

    private func sectionTitle(_ title: String) -> some View { Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.86)) }
}