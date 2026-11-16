import Foundation

/// Predmet, ktery se hrac v bitve uci. Vybira se pred kazdou bitvou a pocita se do profilu.
enum StudySubject: String, Codable, CaseIterable, Sendable, Identifiable {
    case math, english, czech, german, economics, history, it

    var id: String { rawValue }

    var title: String {
        switch self {
        case .math: "Math"
        case .english: "English"
        case .czech: "Czech"
        case .german: "German"
        case .economics: "Economics"
        case .history: "History"
        case .it: "IT"
        }
    }

    var symbol: String {
        switch self {
        case .math: "function"
        case .english: "textformat.abc"
        case .czech: "character.book.closed"
        case .german: "text.book.closed"
        case .economics: "chart.line.uptrend.xyaxis"
        case .history: "building.columns"
        case .it: "desktopcomputer"
        }
    }

    // Neznamy predmet z novejsi verze nesmi zahodit celou historii bitev.
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = StudySubject(rawValue: raw) ?? .math
    }
}

/// Minuty soustredeni podle predmetu, serazene od nejvic procvicovaneho.
struct SubjectProgress: Identifiable, Equatable, Sendable {
    let subject: StudySubject
    let minutes: Int
    let battles: Int
    var id: StudySubject { subject }

    static func summarize(_ history: [SessionSummary]) -> [SubjectProgress] {
        var minutes: [StudySubject: Int] = [:]
        var battles: [StudySubject: Int] = [:]
        for entry in history {
            guard let subject = entry.subject else { continue }
            minutes[subject, default: 0] += max(0, entry.verifiedMinutes)
            battles[subject, default: 0] += 1
        }
        return StudySubject.allCases
            .compactMap { subject in battles[subject].map { SubjectProgress(subject: subject, minutes: minutes[subject] ?? 0, battles: $0) } }
            .sorted { $0.minutes == $1.minutes ? $0.subject.title < $1.subject.title : $0.minutes > $1.minutes }
    }
}
