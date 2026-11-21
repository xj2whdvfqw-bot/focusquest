import SwiftUI

/// List pred bitvou (Fight na Arene nebo dlazdice bosse na Path): predmet, zvuk a velke tlacitko Start.
/// Delka bitvy je dana bossem, proto tu zadny vyber delky neni.
struct FightSheetView: View {
    @ObservedObject var model: ArenaViewModel
    /// Hrac zmackl Start: list se zavre a bitva zacne az po jeho zavreni.
    let onStart: () -> Void
    let onClose: () -> Void

    @State private var showsAllSubjects = false
    @State private var isEditing = false
    @State private var pendingDelete: StudySubject?
    @State private var showsManager = false
    @State private var toast: ToastMessage?
    @State private var contentHeight: CGFloat = 480

    private enum Layout {
        static let sheetBackground = Color(red: 22 / 255, green: 20 / 255, blue: 34 / 255)
        static let sectionGap: CGFloat = 20
        static let labelGap: CGFloat = 8
        static let chipGap: CGFloat = 8
        static let startHeight: CGFloat = 72
        static let startFont: CGFloat = 22
        static let closeSize: CGFloat = 44
        static let visibleChips = 5
    }

    private var boss: Boss { model.selectedBoss }
    private var subjects: [StudySubject] { model.visibleSubjects }

    /// Pevne poradi seznamu. Prvnich 5; vybrany predmet nize v seznamu se ukaze na 5. miste.
    private var shownSubjects: [StudySubject] {
        guard !showsAllSubjects, !isEditing, subjects.count > Layout.visibleChips else { return subjects }
        let first = Array(subjects.prefix(Layout.visibleChips))
        guard let selected = model.selectedSubject, subjects.contains(selected), !first.contains(selected) else { return first }
        return Array(first.prefix(Layout.visibleChips - 1)) + [selected]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionGap) {
                header
                studyingSection
                soundSection
                startButton
            }
            .padding(.horizontal, FQSpace.gutter)
            .padding(.top, FQSpace.xl)
            .padding(.bottom, FQSpace.xl)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .pixelToast($toast)
        .presentationDetents([.height(min(contentHeight, 720)), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Layout.sheetBackground)
        .presentationCornerRadius(FQRadius.card)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsManager) { SubjectManagerView(model: model) }
        .animation(.easeOut(duration: 0.18), value: isEditing)
        .animation(.easeOut(duration: 0.18), value: showsAllSubjects)
    }

    // MARK: - Hlavicka

    private var header: some View {
        HStack(alignment: .top, spacing: FQSpace.md) {
            Text("Fight \(boss.name)")
                .fqFont(size: 26, weight: .bold, design: .rounded)
                .foregroundStyle(FQColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(FQColor.textPrimary)
                    .frame(width: Layout.closeSize, height: Layout.closeSize)
                    .glassControl(in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Predmety

    private var studyingSection: some View {
        VStack(alignment: .leading, spacing: Layout.labelGap) {
            HStack {
                sectionLabel("Studying")
                Spacer(minLength: 0)
                if !subjects.isEmpty {
                    Button(isEditing ? "Done" : "Edit") {
                        pendingDelete = nil
                        isEditing.toggle()
                    }
                    .fqFont(size: 13, weight: .semibold, design: .rounded)
                    .foregroundStyle(FQColor.textSecondary)
                    .frame(minHeight: 32)
                }
            }
            ChipFlow(spacing: Layout.chipGap, rowSpacing: Layout.chipGap) {
                ForEach(shownSubjects) { subject in
                    if isEditing { deleteChip(subject) } else { subjectChip(subject) }
                }
                if !isEditing, !showsAllSubjects, subjects.count > Layout.visibleChips {
                    Button("More…") { showsAllSubjects = true }
                        .buttonStyle(.plain)
                        .modifier(GhostChip())
                }
                if !isEditing {
                    AddSubjectChip(model: model, taken: subjects) { result in
                        if case let .existing(subject) = result {
                            toast = ToastMessage(text: "You already have \(subject.title). Picked it.")
                        }
                    }
                }
            }
            if subjects.isEmpty {
                Text("Add what you're studying so it shows up in Stats.")
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
            }
        }
    }

    private func subjectChip(_ subject: StudySubject) -> some View {
        let isSelected = subject == model.selectedSubject
        return Text(subject.title)
            .fqChip(selected: isSelected)
            .onTapGesture { model.selectSubject(subject) }
            .onLongPressGesture(minimumDuration: 0.5) { showsManager = true }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(subject.title)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { model.selectSubject(subject) }
            .accessibilityAction(named: "Edit subjects") { showsManager = true }
    }

    /// Rezim Edit: prvni klepnuti se zepta ("Delete Math?"), druhe predmet smaze (mekke smazani).
    private func deleteChip(_ subject: StudySubject) -> some View {
        let isConfirming = pendingDelete == subject
        return Button {
            if isConfirming {
                pendingDelete = nil
                model.deleteSubject(subject)
                if model.visibleSubjects.isEmpty { isEditing = false }
                toast = .undo("Deleted \(subject.title). You can restore it for 24 hours.") { model.restoreSubject(subject) }
            } else {
                pendingDelete = subject
            }
        } label: {
            HStack(spacing: 6) {
                Text(isConfirming ? "Delete \(subject.title)?" : subject.title)
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(isConfirming ? Color.black.opacity(0.25) : FQColor.alarm.opacity(0.85), in: Circle())
            }
            .fqFont(size: 15, weight: .semibold, design: .rounded)
            .foregroundStyle(FQColor.textPrimary)
            .lineLimit(1)
            .padding(.leading, FQChipMetrics.padding)
            .padding(.trailing, 10)
            .frame(height: FQChipMetrics.height)
            .background(isConfirming ? FQColor.alarm : FQColor.alarm.opacity(0.14), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isConfirming ? "Tap again to delete \(subject.title)" : "Delete \(subject.title)")
    }

    // MARK: - Zvuk

    private enum SoundChoice: CaseIterable, Identifiable {
        case off, lofi, brownNoise, whiteNoise
        var id: Self { self }
        var title: String {
            switch self {
            case .off: "Off"
            case .lofi: "Lo-fi"
            case .brownNoise: "Brown noise"
            case .whiteNoise: "White noise"
            }
        }
        var soundscape: Soundscape? {
            switch self {
            case .off: nil
            case .lofi: .lofi
            case .brownNoise: .brownNoise
            case .whiteNoise: .whiteNoise
            }
        }
    }

    private var currentSound: SoundChoice {
        guard model.preferences.isMusicEnabled else { return .off }
        switch model.preferences.soundscape {
        case .lofi: return .lofi
        case .brownNoise: return .brownNoise
        case .whiteNoise: return .whiteNoise
        }
    }

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: Layout.labelGap) {
            sectionLabel("Sound")
            ChipFlow(spacing: Layout.chipGap, rowSpacing: Layout.chipGap) {
                ForEach(SoundChoice.allCases) { choice in
                    FQChip(title: choice.title, isSelected: currentSound == choice, compact: true) { select(choice) }
                }
            }
        }
    }

    private func select(_ choice: SoundChoice) {
        if let soundscape = choice.soundscape {
            model.setSoundscape(soundscape)
            model.setMusicEnabled(true)
        } else {
            model.setMusicEnabled(false)
        }
    }

    // MARK: - Start

    private var startButton: some View {
        let canStart = model.selectedSubject != nil && model.isBetweenBattles
        return Button(action: onStart) {
            Label("Start \(boss.maxHP) min Battle", systemImage: "play.fill")
                .font(.system(size: Layout.startFont, weight: .bold, design: .rounded))
                .foregroundStyle(FQColor.onCta)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: Layout.startHeight)
                .background(FQColor.cta, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canStart)
        .opacity(canStart ? 1 : 0.35)
        .accessibilityHint(model.selectedSubject == nil ? "Add a subject first" : "")
        .padding(.top, FQSpace.xs)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .fqFont(size: 13, weight: .semibold, design: .rounded)
            .foregroundStyle(FQColor.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}
