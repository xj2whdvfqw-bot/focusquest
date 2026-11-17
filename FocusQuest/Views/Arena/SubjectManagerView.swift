import SwiftUI

/// "Your subjects": sprava predmetu (dlouhy stisk cipu ve Fight sheetu). Radek = upravitelny nazev,
/// Hide/Show a kos. Skryti i smazani data zachovaji; obnoveni smazanych a Undo doplni sekce 7.
struct SubjectManagerView: View {
    @ObservedObject var model: ArenaViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: StudySubject?

    private enum Layout {
        static let sheetBackground = Color(red: 22 / 255, green: 20 / 255, blue: 34 / 255)
        static let rowHeight: CGFloat = 52
        static let rowGap: CGFloat = 8
        static let iconSize: CGFloat = 44
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FQSpace.lg) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your subjects")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(FQColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    Button { dismiss() } label: {
                        Label("Done", systemImage: "checkmark")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(FQColor.onCta)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(FQColor.cta, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Text("Hidden subjects disappear from fights and Stats. Nothing is lost, tap Show to bring them back.")
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: Layout.rowGap) {
                    ForEach(model.managedSubjects) { entry in
                        if pendingDelete == entry.subject {
                            confirmRow(entry.subject)
                        } else {
                            SubjectRow(entry: entry, model: model) { pendingDelete = entry.subject }
                        }
                    }
                }
                if model.managedSubjects.isEmpty {
                    Text("No subjects yet. Add one with + Subject in the fight sheet.")
                        .font(.fqMeta)
                        .foregroundStyle(FQColor.textSecondary)
                }
            }
            .padding(.horizontal, FQSpace.gutter)
            .padding(.vertical, FQSpace.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Layout.sheetBackground)
        .presentationCornerRadius(FQRadius.card)
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.18), value: pendingDelete)
    }

    /// Cerveny radek s potvrzenim smazani (mekke smazani, data zustanou).
    private func confirmRow(_ subject: StudySubject) -> some View {
        HStack(spacing: FQSpace.sm) {
            Text("Delete \(subject.title)? You can restore it for 24 hours.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Cancel") { pendingDelete = nil }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(minWidth: 44, minHeight: 44)
                .buttonStyle(.plain)
            Button("Delete") {
                pendingDelete = nil
                model.deleteSubject(subject)
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(FQColor.alarm)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(.white, in: Capsule())
            .buttonStyle(.plain)
        }
        .padding(.horizontal, FQSpace.md)
        .frame(minHeight: Layout.rowHeight)
        .background(FQColor.alarm.opacity(0.85), in: RoundedRectangle(cornerRadius: FQRadius.tile, style: .continuous))
    }
}

/// Radek predmetu: nazev se ulozi po odeslani nebo po odchodu z pole.
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
        HStack(spacing: FQSpace.sm) {
            TextField("Subject name", text: $name)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(entry.isHidden ? FQColor.textSecondary : FQColor.textPrimary)
                .strikethrough(entry.isHidden && !focused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
                .accessibilityLabel("Name of \(entry.subject.title)")
            Button(entry.isHidden ? "Show" : "Hide") {
                model.setSubjectHidden(entry.subject, hidden: !entry.isHidden)
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(FQColor.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .overlay { Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1) }
            .frame(minHeight: 44)
            .buttonStyle(.plain)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FQColor.alarm)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(entry.subject.title)")
        }
        .padding(.leading, FQSpace.md)
        .padding(.trailing, FQSpace.xs)
        .frame(minHeight: 52)
        .background(Color.white.opacity(entry.isHidden ? 0.05 : 0.10), in: RoundedRectangle(cornerRadius: FQRadius.tile, style: .continuous))
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
