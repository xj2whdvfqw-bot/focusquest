import SwiftUI

/// "Your subjects": sprava predmetu (dlouhy stisk cipu ve Fight sheetu nebo "Edit subjects" ve Stats).
/// Radek = upravitelny nazev, Hide/Show a kos. Skryti i smazani data zachovaji; smazany predmet
/// jde 24 h obnovit v "Recently deleted", pak zmizi i se statistikami (MainTabView.maintainSubjects).
struct SubjectManagerView: View {
    @ObservedObject var model: ArenaViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: StudySubject?
    @State private var toast: ToastMessage?
    /// Rozepsany novy predmet: tah dolu okno nezavre, nejdriv se zepta.
    @State private var hasSubjectDraft = false
    @State private var asksDiscardDraft = false

    private enum Layout {
        static let sheetBackground = Color(red: 22 / 255, green: 20 / 255, blue: 34 / 255)
        static let sectionGap: CGFloat = 18
        static let rowGap: CGFloat = 8
        static let doneHeight: CGFloat = 52
        static let doneMinWidth: CGFloat = 140
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionGap) {
                header
                Text("Hidden items disappear from battles and Stats. Nothing is lost, tap Show to bring them back.")
                    .fqFont(size: 15, design: .rounded)
                    .foregroundStyle(FQColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                list
                recentlyDeleted
                AddSubjectChip(model: model, taken: model.managedSubjects.map(\.subject), hasDraft: $hasSubjectDraft) { result in
                    if case let .existing(subject) = result {
                        toast = ToastMessage(text: "You already have \(subject.title). Picked it.")
                    }
                }
                doneButton
            }
            .padding(.horizontal, FQSpace.gutter)
            .padding(.vertical, FQSpace.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .pixelToast($toast)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Layout.sheetBackground)
        .presentationCornerRadius(FQRadius.card)
        .preferredColorScheme(.dark)
        // Zavreni tahem dolu; ne behem potvrzeni smazani a ne s rozepsanym predmetem.
        .fqSheetDismissal(blocked: pendingDelete != nil || hasSubjectDraft, onBlockedAttempt: blockedCloseAttempt) { dismiss() }
        .confirmationDialog("Discard the new focus?", isPresented: $asksDiscardDraft, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) { }
        }
        .animation(.easeOut(duration: 0.18), value: pendingDelete)
        .animation(.easeOut(duration: 0.18), value: model.preferences.subjects)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: FQSpace.md) {
            Text("Your focus list")
                .fqFont(size: 26, weight: .bold, design: .rounded)
                .foregroundStyle(FQColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        // Krizek nahradil tah dolu; VoiceOver zavira akci "Close" nebo escape gestem.
        .fqSheetCloseAction(requestClose)
    }

    /// Zavreni pres VoiceOver: stejna pravidla jako tah dolu.
    private func requestClose() {
        if pendingDelete != nil || hasSubjectDraft { blockedCloseAttempt() } else { dismiss() }
    }

    /// Pokus zavrit zablokovane okno: rozepsany predmet se zepta, potvrzeni smazani se zrusi.
    private func blockedCloseAttempt() {
        if hasSubjectDraft { asksDiscardDraft = true } else { pendingDelete = nil }
    }

    @ViewBuilder private var list: some View {
        let entries = model.managedSubjects
        if entries.isEmpty {
            Text("Nothing here yet.")
                .fqFont(size: 15, design: .rounded)
                .foregroundStyle(FQColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: Layout.rowGap) {
                ForEach(entries) { entry in
                    if pendingDelete == entry.subject {
                        confirmRow(entry.subject)
                    } else {
                        SubjectRow(entry: entry, model: model) { pendingDelete = entry.subject }
                    }
                }
            }
        }
    }

    /// Cervene potvrzeni smazani primo v radku. Smazani je mekke: predmet jde 24 h obnovit.
    private func confirmRow(_ subject: StudySubject) -> some View {
        HStack(spacing: FQSpace.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Delete \(subject.title)?")
                    .fqFont(size: 15, weight: .bold, design: .rounded)
                    .foregroundStyle(FQColor.textPrimary)
                    .lineLimit(1)
                Text("You can restore it for 24 hours.")
                    .fqFont(size: 13, design: .rounded)
                    .foregroundStyle(FQColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button("Cancel") { pendingDelete = nil }
                .buttonStyle(ManagerButtonStyle())
            Button("Delete") { delete(subject) }
                .buttonStyle(ManagerButtonStyle(tone: .danger))
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(FQColor.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: FQRadius.inSheet, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FQRadius.inSheet, style: .continuous).strokeBorder(FQColor.danger.opacity(0.4), lineWidth: 1)
        }
    }

    private func delete(_ subject: StudySubject) {
        pendingDelete = nil
        model.deleteSubject(subject)
        toast = .undo("Deleted \(subject.title). You can restore it for 24 hours.") { model.restoreSubject(subject) }
    }

    /// Smazane predmety: jdou obnovit, dokud neuplyne 24 h.
    @ViewBuilder private var recentlyDeleted: some View {
        let deleted = model.deletedSubjects
        if !deleted.isEmpty {
            VStack(alignment: .leading, spacing: Layout.rowGap) {
                Text("Recently deleted")
                    .fqFont(size: 13, weight: .semibold, design: .rounded)
                    .foregroundStyle(FQColor.textTertiary)
                    .accessibilityAddTraits(.isHeader)
                // Odpocet hodin se obnovuje kazdou minutu.
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    VStack(spacing: Layout.rowGap) {
                        ForEach(deleted) { entry in deletedRow(entry, now: context.date) }
                    }
                }
            }
        }
    }

    private func deletedRow(_ entry: SubjectEntry, now: Date) -> some View {
        HStack(spacing: FQSpace.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.subject.title)
                    .fqFont(size: 15, weight: .bold, design: .rounded)
                    .foregroundStyle(FQColor.textSecondary)
                    .lineLimit(1)
                Text("Gone for good in \(entry.hoursUntilPurge(now: now)) h, with its stats")
                    .fqFont(size: 13, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button("Restore") { model.restoreSubject(entry.subject) }
                .buttonStyle(ManagerButtonStyle(tone: .cta))
                .accessibilityLabel("Restore \(entry.subject.title)")
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: FQRadius.inSheet, style: .continuous))
    }

    /// Kompaktni obrysove "✓ Done" uprostred (ne pres celou sirku).
    private var doneButton: some View {
        Button { dismiss() } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FQColor.textSecondary)
                Text("Done")
            }
            .fqFont(size: 16, weight: .bold, design: .rounded)
            .foregroundStyle(FQColor.textPrimary)
            .padding(.horizontal, 28)
            .frame(minWidth: Layout.doneMinWidth)
            .frame(height: Layout.doneHeight)
            .overlay {
                RoundedRectangle(cornerRadius: FQRadius.inSheet, style: .continuous).strokeBorder(Color.white.opacity(0.28), lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: FQRadius.inSheet, style: .continuous))
        }
        .buttonStyle(.fqPress)
        .frame(maxWidth: .infinity)
    }
}

/// Male tlacitko v radku spravy predmetu (Hide, Show, Cancel, Delete, Restore): 34 pt vysoke,
/// dotykova plocha 44 pt.
private struct ManagerButtonStyle: ButtonStyle {
    enum Tone { case plain, cta, danger }
    var tone: Tone = .plain

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fqFont(size: 14, weight: .semibold, design: .rounded)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(background, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch tone {
        case .plain: FQColor.textSecondary
        case .cta: FQColor.cta
        case .danger: .white
        }
    }

    private var background: Color { tone == .danger ? FQColor.danger : Color.white.opacity(0.16) }
}

/// Radek predmetu: nazev se ulozi po odeslani nebo po odchodu z pole.
/// Skryty predmet: sedy prazdnejsi radek, preskrtnuty nazev a zlute "Show".
private struct SubjectRow: View {
    let entry: SubjectEntry
    @ObservedObject var model: ArenaViewModel
    let onDelete: () -> Void
    @State private var name: String
    @FocusState private var focused: Bool

    init(entry: SubjectEntry, model: ArenaViewModel, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.model = model
        self.onDelete = onDelete
        _name = State(initialValue: entry.subject.title)
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("Focus name", text: $name)
                .fqFont(size: 16, weight: .medium, design: .rounded)
                .foregroundStyle(entry.isHidden ? FQColor.textTertiary : FQColor.textPrimary)
                .strikethrough(entry.isHidden && !focused, color: Color.white.opacity(0.25))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .frame(minHeight: 40)
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
                .accessibilityLabel("Rename \(entry.subject.title)")
                .accessibilityValue(entry.isHidden ? "Hidden" : "")
            Button(entry.isHidden ? "Show" : "Hide") {
                model.setSubjectHidden(entry.subject, hidden: !entry.isHidden)
            }
            .buttonStyle(ManagerButtonStyle(tone: entry.isHidden ? .cta : .plain))
            .accessibilityLabel("\(entry.isHidden ? "Show" : "Hide") \(entry.subject.title)")
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FQColor.textSecondary)
                    .frame(width: 40, height: 34)
                    .background(Color.white.opacity(0.16), in: Capsule())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.fqPress)
            .accessibilityLabel("Delete \(entry.subject.title)")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 2)
        .background(Color.white.opacity(entry.isHidden ? 0.025 : 0.06), in: RoundedRectangle(cornerRadius: FQRadius.inSheet, style: .continuous))
        .onChange(of: entry.subject.title) { _, title in if !focused { name = title } }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == entry.subject.title {
            name = entry.subject.title
        } else {
            model.renameSubject(entry.subject, to: trimmed)
        }
    }
}
