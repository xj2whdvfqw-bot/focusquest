import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        ZStack {
            FocusQuestBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Settings").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 14) {
                        SectionEyebrow(title: "Sensory")
                        Toggle("Haptic vibrations", isOn: binding(\.isHapticsEnabled))
                        Text("Visual anti-cheat warnings and penalties remain active when haptics are muted.").font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.62))
                        Toggle("Lo-Fi background music", isOn: binding(\.isMusicEnabled))
                        Toggle("8-bit sound effects & alarms", isOn: binding(\.isSFXEnabled))
                    }.toggleStyle(SwitchToggleStyle(tint: .mint)).padding(16).glassmorphic()

                    VStack(alignment: .leading, spacing: 12) {
                        SectionEyebrow(title: "Soundscape")
                        Picker("Ambient track", selection: Binding(get: { model.preferences.selectedTrack }, set: { track in model.update { $0.selectedTrack = track } })) {
                            ForEach(AmbientTrack.allCases) { Text($0.title).tag($0) }
                        }.tint(.white)
                        HStack { Image(systemName: "speaker.fill"); Slider(value: Binding(get: { model.preferences.ambientVolume }, set: { volume in model.update { $0.ambientVolume = volume } }), in: 0...1).tint(.mint); Image(systemName: "speaker.wave.3.fill") }.font(.caption)
                    }.padding(16).glassmorphic()

                    VStack(alignment: .leading, spacing: 9) {
                        SectionEyebrow(title: "Privacy & fair play")
                        ForEach(LegalDocument.allCases) { document in
                            Button { model.selectedDocument = document } label: { HStack { Text(document.title); Spacer(); Image(systemName: "arrow.up.right").font(.caption) }.font(.system(size: 14, weight: .medium, design: .rounded)).padding(10) }
                                .buttonStyle(.plain)
                        }
                    }.padding(16).glassmorphic()

                    VStack(alignment: .leading, spacing: 12) {
                        SectionEyebrow(title: "Account & data")
                        Label(model.isSignedIn ? "Cloud sync: connected with Apple" : "Cloud sync: not connected", systemImage: model.isSignedIn ? "icloud.fill" : "icloud.slash").font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                        if model.isSignedIn {
                            Button { Task { await model.signOut() } } label: { Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right").font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading).padding(10) }
                                .buttonStyle(.plain)
                        } else {
                            SignInWithAppleButton(.signIn, onRequest: { request in request.requestedScopes = [.fullName, .email] }, onCompletion: handleAppleSignIn)
                                .signInWithAppleButtonStyle(.white).frame(height: 44).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Button(role: .destructive) { model.showingDeleteConfirmation = true } label: { Label("Delete account and data", systemImage: "trash").font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading).padding(13).background(.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 12)) }
                    }.padding(16).glassmorphic()
                    if let message = model.statusMessage { Text(message).font(.caption).foregroundStyle(.white.opacity(0.7)) }
                }.padding(18)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $model.selectedDocument) { LegalDocumentSheetView(document: $0).presentationDetents([.medium, .large]) }
        .confirmationDialog("Permanently delete your account and data?", isPresented: $model.showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) { Task { await model.deleteAccount() } }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Your account and locally stored credentials will be removed. This cannot be undone.") }
    }

    private func binding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(get: { model.preferences[keyPath: keyPath] }, set: { value in model.update { $0[keyPath: keyPath] = value } })
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard case let .success(authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            if case let .failure(error) = result { model.statusMessage = error.localizedDescription }
            return
        }
        Task { await model.signInWithApple(identityToken: token) }
    }
}