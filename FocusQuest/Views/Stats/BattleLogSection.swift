import SwiftUI

/// C6: historie bitev ve Stats. Kazdy radek: datum, boss, focus oblast, delka a poznamka po vyhre.
/// Nahore filtr podle focus oblasti (jen oblasti, ktere v historii jsou). Ukazuje se 10 poslednich,
/// "Show more" pridava po 20.
struct BattleLogSection: View {
    let history: [SessionSummary]
    /// Seznam focus oblasti hrace (nazvy po prejmenovani).
    let subjects: [SubjectEntry]

    /// nil = vsechny oblasti.
    @State private var filter: String?
    @State private var shown = 10

    private var areas: [StudySubject] {
        var seen = Set<String>()
        return history.compactMap(\.subject).filter { seen.insert($0.id).inserted }
    }

    private var filtered: [SessionSummary] {
        guard let filter else { return history }
        return history.filter { $0.subject?.id == filter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FQSpace.sm) {
            SectionHeader(title: "Battle log", detail: history.isEmpty ? nil : "\(history.count) \(history.count == 1 ? "battle" : "battles")")
            if history.isEmpty {
                Text("Your battles and notes will show up here.")
                    .fqFont(size: 15, design: .rounded)
                    .foregroundStyle(FQColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .fqCard()
            } else {
                if areas.count > 1 {
                    ScrollView(.horizontal) {
                        HStack(spacing: FQSpace.sm) {
                            chip(title: "All", id: nil)
                            ForEach(areas, id: \.id) { area in
                                chip(title: subjects.title(of: area), id: area.id)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }
                VStack(spacing: 0) {
                    let rows = Array(filtered.prefix(shown))
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, session in
                        if index > 0 { HairlineDivider() }
                        row(session)
                    }
                    if filtered.count > shown {
                        HairlineDivider()
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { shown += 20 }
                        } label: {
                            Text("Show more")
                                .fqFont(size: 14, weight: .semibold, design: .rounded)
                                .foregroundStyle(FQColor.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.fqPress)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .fqCard()
            }
        }
    }

    private func chip(title: String, id: String?) -> some View {
        let selected = filter == id
        return Text(title)
            .fqChip(selected: selected, compact: true)
            .onTapGesture {
                FQFeedback.shared.tap()
                withAnimation(.easeOut(duration: 0.15)) {
                    filter = id
                    shown = 10
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func row(_ session: SessionSummary) -> some View {
        let area = session.subject.map { subjects.title(of: $0) }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: FQSpace.sm) {
                Text(session.bossName)
                    .fqFont(size: 15, weight: .semibold, design: .rounded)
                    .foregroundStyle(FQColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: FQSpace.sm)
                Text(ArenaView.durationText(minutes: session.verifiedMinutes))
                    .fqFont(size: 13, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textSecondary)
            }
            Text([Self.dateText(session.completedAt), area].compactMap { $0 }.joined(separator: " · "))
                .fqFont(size: 13, design: .rounded)
                .foregroundStyle(FQColor.textSecondary)
            if let note = session.note, !note.isEmpty {
                Text("“\(note)”")
                    .fqFont(size: 14, design: .rounded)
                    .foregroundStyle(FQColor.textPrimary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    static func dateText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today, " + date.formatted(date: .omitted, time: .shortened) }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
