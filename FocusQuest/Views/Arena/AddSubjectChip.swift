import SwiftUI

/// "+ Subject" se po klepnuti zmeni primo v radku na textove pole (zadny modal).
/// Navrh se doplnuje sedym textem za kurzorem: → / Tab / klepnuti na sedy text ho doplni,
/// Enter nebo Add prida predmet tak, jak je v poli videt (vcetne sedeho navrhu).
/// Pouziva ho Fight sheet (v rade cipu) i "Your subjects" (dole pod seznamem).
struct AddSubjectChip: View {
    @ObservedObject var model: ArenaViewModel
    /// Predmety, ktere hrac uz ma; ty se jako navrh nenabizi.
    let taken: [StudySubject]
    /// Predmet se pridal (`.created`), nebo uz existoval a jen se vybral (`.existing`).
    let onAdded: (SubjectAddResult) -> Void

    @State private var isAdding = false
    @State private var newSubject = ""
    @FocusState private var fieldFocused: Bool

    private enum Layout {
        static let fieldWidth: CGFloat = 160
        static let fieldFont = Font.system(size: 15, weight: .medium, design: .rounded)
    }

    /// Navrh doplneny primo v poli ("m" -> "Microeconomics").
    private var completion: String? { StudySubject.completion(for: newSubject, taken: taken) }
    /// Sedy zbytek navrhu za kurzorem.
    private var completionRest: String? { completion.map { String($0.dropFirst(newSubject.count)) } }

    var body: some View {
        Group {
            if isAdding { field } else { addButton }
        }
        .animation(.easeOut(duration: 0.18), value: isAdding)
    }

    private var field: some View {
        HStack(spacing: 6) {
            TextField("Subject name", text: $newSubject)
                .font(Layout.fieldFont)
                .foregroundStyle(FQColor.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($fieldFocused)
                .overlay(alignment: .leading) { completionGhost }
                .frame(width: Layout.fieldWidth)
                .clipped()
                .onSubmit { add(completion ?? newSubject) }
                .onKeyPress(.tab) { acceptCompletion() ? .handled : .ignored }
                .onKeyPress(.rightArrow) { acceptCompletion() ? .handled : .ignored }
                .accessibilityLabel("New subject")
                .accessibilityHint(completion.map { "Suggestion: \($0)" } ?? "")
                .accessibilityAction(named: "Use suggestion") { _ = acceptCompletion() }
            Button("Add") { add(completion ?? newSubject) }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(FQColor.onCta)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(FQColor.cta, in: Capsule())
                .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: FQChipMetrics.height)
        .background(Color.white.opacity(0.12), in: Capsule())
        .onAppear { fieldFocused = true }
        .onChange(of: fieldFocused) { _, focused in
            // Prazdne pole po odchodu z klavesnice se vrati zpet na "+ Subject".
            if !focused, newSubject.trimmingCharacters(in: .whitespaces).isEmpty { isAdding = false }
        }
    }

    private var addButton: some View {
        Button {
            newSubject = ""
            isAdding = true
        } label: {
            Label("Subject", systemImage: "plus")
                .labelStyle(ChipLabelStyle())
        }
        .buttonStyle(.plain)
        .modifier(GhostChip())
        .accessibilityLabel("Add subject")
    }

    /// Sedy zbytek navrhu hned za napsanym textem. Napsana cast je jen neviditelna podlozka pro zarovnani,
    /// klepnuti na ni jde do pole; klepnuti na sedy zbytek navrh doplni.
    @ViewBuilder private var completionGhost: some View {
        if let rest = completionRest {
            HStack(spacing: 0) {
                Text(newSubject).hidden().allowsHitTesting(false)
                Text(rest)
                    .foregroundStyle(FQColor.textTertiary)
                    .contentShape(Rectangle())
                    .onTapGesture { _ = acceptCompletion() }
            }
            .font(Layout.fieldFont)
            .lineLimit(1)
            .fixedSize()
            .accessibilityHidden(true)
        }
    }

    /// Doplni navrh do pole. Vrati false, kdyz zadny navrh neni.
    private func acceptCompletion() -> Bool {
        guard let completion else { return false }
        newSubject = completion
        return true
    }

    private func add(_ name: String) {
        guard let result = model.addSubject(named: name) else { return }
        newSubject = ""
        isAdding = false
        fieldFocused = false
        onAdded(result)
    }
}

/// Pruhledny cip s jemnym okrajem ("More…", "+ Subject").
struct GhostChip: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(FQColor.textSecondary)
            .padding(.horizontal, FQChipMetrics.padding)
            .frame(height: FQChipMetrics.height)
            .overlay { Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1) }
            .contentShape(Capsule())
    }
}

/// Ikona a text tesne vedle sebe (ikona "+" u "Subject").
struct ChipLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 13, weight: .bold))
            configuration.title
        }
    }
}
