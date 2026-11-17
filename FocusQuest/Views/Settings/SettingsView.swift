import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    /// Nastaveni se otevira jako list ozubenym kolem na kterekoli zalozce; tohle ho zavre.
    var onClose: (() -> Void)? = nil

    var body: some View {
        ScreenScaffold {
            HStack(alignment: .center) {
                ScreenTitle(title: "Settings")
                Spacer(minLength: FQSpace.sm)
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(FQColor.textPrimary)
                            .frame(width: 44, height: 44)
                            .glassControl(in: Circle(), interactive: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close settings")
                }
            }
            .padding(.top, onClose == nil ? 0 : FQSpace.md)
            ScreenSection(title: "Sensory") { sensoryCard }
            ScreenSection(title: "Soundscape") { soundscapeCard }
            ScreenSection(title: "Privacy & fair play") { legalCard }
            ScreenSection(title: "Account & data") { accountCard }
            // DOCASNE: testovaci odmeny. Pred vydanim do App Storu odstranit.
            ScreenSection(title: "Developer", detail: "Temporary") { developerCard }
            if let message = model.statusMessage {
                Text(message).font(.fqSecondary).foregroundStyle(FQColor.textSecondary).padding(.horizontal, FQSpace.xs)
            }
        }
        .sheet(item: $model.selectedDocument) { LegalDocumentSheetView(document: $0).presentationDetents([.medium, .large]) }
        .confirmationDialog("Permanently delete your account and data?", isPresented: $model.showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) { Task { await model.deleteAccount() } }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Your account and locally stored credentials will be removed. This cannot be undone.") }
    }

    // MARK: - Karty

    private var sensoryCard: some View {
        card {
            toggleRow("Haptic vibrations", icon: "iphone.radiowaves.left.and.right", isOn: binding(\.isHapticsEnabled))
            Text("Visual anti-cheat warnings and penalties remain active when haptics are muted.")
                .font(.fqMeta)
                .foregroundStyle(FQColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, FQSpace.md)
            HairlineDivider()
            toggleRow("Lo-fi background music", icon: "music.note", isOn: binding(\.isMusicEnabled))
            HairlineDivider()
            toggleRow("8-bit sound effects & alarms", icon: "bell.fill", isOn: binding(\.isSFXEnabled))
        }
    }

    private var soundscapeCard: some View {
        card {
            HStack(spacing: FQSpace.md) {
                IconTile(symbol: "music.note.list")
                Text("Starting track").font(.fqBody).foregroundStyle(FQColor.textPrimary)
                Spacer(minLength: FQSpace.sm)
                ValueMenu(title: "Starting track", valueText: model.preferences.selectedTrack.title, selection: Binding(get: { model.preferences.selectedTrack }, set: { track in model.update { $0.selectedTrack = track } })) {
                    ForEach(AmbientTrack.allCases) { Text($0.title).tag($0) }
                }
            }
            .padding(.vertical, FQSpace.xs)
            HairlineDivider()
            HStack(spacing: FQSpace.md) {
                Image(systemName: "speaker.fill").accessibilityHidden(true)
                Slider(value: Binding(get: { model.preferences.ambientVolume }, set: { volume in model.update { $0.ambientVolume = volume } }), in: 0...1)
                    .tint(FQColor.accent)
                    .accessibilityLabel("Music volume")
                Image(systemName: "speaker.wave.3.fill").accessibilityHidden(true)
            }
            .font(.fqSecondary)
            .foregroundStyle(FQColor.textSecondary)
            .padding(.vertical, FQSpace.md)
            HairlineDivider()
            Text("Tracks play one after another during a battle. Music by HoliznaCC0, released into the public domain (CC0).")
                .font(.fqMeta)
                .foregroundStyle(FQColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, FQSpace.md)
        }
    }

    private var legalCard: some View {
        card {
            ForEach(Array(LegalDocument.allCases.enumerated()), id: \.element.id) { index, document in
                if index > 0 { HairlineDivider() }
                Button { model.selectedDocument = document } label: {
                    HStack(spacing: FQSpace.md) {
                        IconTile(symbol: icon(for: document))
                        Text(document.title).font(.fqBody).foregroundStyle(FQColor.textPrimary)
                        Spacer(minLength: FQSpace.sm)
                        Image(systemName: "chevron.right").font(.fqMeta.weight(.semibold)).foregroundStyle(FQColor.textTertiary)
                    }
                    .padding(.vertical, FQSpace.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var accountCard: some View {
        card {
            HStack(spacing: FQSpace.md) {
                IconTile(symbol: model.isSignedIn ? "icloud.fill" : "icloud.slash", color: model.isSignedIn ? FQColor.accent : FQColor.textSecondary)
                Text(model.isSignedIn ? "Cloud sync connected with Apple" : "Cloud sync not connected").font(.fqBody).foregroundStyle(FQColor.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, FQSpace.sm)
            HairlineDivider()
            Group {
                if model.isSignedIn {
                    Button { Task { await model.signOut() } } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right").font(.fqHeadline).frame(maxWidth: .infinity)
                    }
                    .glassButtonStyle()
                    .buttonBorderShape(.roundedRectangle(radius: FQRadius.control))
                    .controlSize(.large)
                    .tint(FQColor.textPrimary)
                } else {
                    SignInWithAppleButton(.signIn, onRequest: { request in request.requestedScopes = [.fullName, .email] }, onCompletion: handleAppleSignIn)
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: FQRadius.tile, style: .continuous))
                }
            }
            .padding(.vertical, FQSpace.md)
            HairlineDivider()
            Button(role: .destructive) { model.showingDeleteConfirmation = true } label: {
                HStack(spacing: FQSpace.md) {
                    IconTile(symbol: "trash.fill", color: FQColor.danger)
                    Text("Delete account and data").font(.fqBody).foregroundStyle(FQColor.danger)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, FQSpace.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// DOCASNE: +10 000 minci a +5 000 XP pro testovani obchodu.
    private var developerCard: some View {
        card {
            Button { model.addDevFunds() } label: {
                HStack(spacing: FQSpace.md) {
                    IconTile(symbol: "hammer.fill")
                    VStack(alignment: .leading, spacing: FQSpace.xs) {
                        Text("Add Dev Funds").font(.fqBody).foregroundStyle(FQColor.textPrimary)
                        Text("+10,000 coins and +5,000 XP").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(FQColor.accent)
                }
                .padding(.vertical, FQSpace.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Stavebni prvky

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, FQSpace.lg)
            .padding(.vertical, FQSpace.xs)
            .glassCard()
    }

    private func toggleRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: FQSpace.md) {
                IconTile(symbol: icon)
                Text(title).font(.fqBody).foregroundStyle(FQColor.textPrimary)
            }
        }
        .tint(FQColor.accent)
        .padding(.vertical, FQSpace.sm)
    }

    private func icon(for document: LegalDocument) -> String {
        switch document {
        case .privacy: "hand.raised.fill"
        case .terms: "doc.text.fill"
        case .antiCheat: "shield.lefthalf.filled"
        }
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
