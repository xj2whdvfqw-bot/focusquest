import Foundation

/// Predmet, ktery se hrac v bitve uci. Hrac si predmety sam pridava, prejmenovava a maze.
/// Ulozi se jen jako `id` (retezec), takze historie bitev ze starsich verzi (kdy predmety
/// byly pevny vycet "math", "english" ...) se nacte beze zmeny.
struct StudySubject: Hashable, Codable, Sendable, Identifiable {
    /// Stabilni klic. Puvodni predmety maji stara id ("math"), nove id podle prvniho nazvu.
    let id: String
    /// Zobrazovany nazev. Pri nacitani z historie se doplni z vychoziho seznamu, jinak je to id.
    var title: String

    init(id: String, title: String? = nil) {
        self.id = id
        self.title = title ?? Self.builtInTitles[id] ?? id
    }

    // Rovnost a hash jen podle id: prejmenovany predmet je porad tentyz predmet.
    static func == (lhs: StudySubject, rhs: StudySubject) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(from decoder: any Decoder) throws {
        self.init(id: try decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }

    static let math = StudySubject(id: "math")
    static let english = StudySubject(id: "english")
    static let czech = StudySubject(id: "czech")
    static let german = StudySubject(id: "german")
    static let economics = StudySubject(id: "economics")
    static let history = StudySubject(id: "history")
    static let it = StudySubject(id: "it")
    /// Bitva bez predmetu (stare zaznamy, nebo kdyz predmet chybi) se pocita sem.
    static let general = StudySubject(id: "general")

    /// Nazvy predmetu ze starsich verzi (pevny vycet).
    private static let builtInTitles = [
        "math": "Math", "english": "English", "czech": "Czech", "german": "German",
        "economics": "Economics", "history": "History", "it": "IT", "general": "General"
    ]

    /// Predmety noveho hrace.
    static let defaults: [StudySubject] = [.math, .english, .czech, .german, .economics]

    /// Navrhy pri pridavani predmetu ve Fight sheetu.
    static let suggestions = [
        "Math", "English", "Economics", "Microeconomics", "Macroeconomics", "Accounting", "Statistics",
        "Finance", "Marketing", "Management", "Law", "Programming", "Biology", "Chemistry", "Physics",
        "History", "Geography", "German", "Czech", "Spanish", "French", "Philosophy", "Psychology", "Design"
    ]

    /// Inline doplneni pri psani noveho predmetu: prvni navrh, ktery zacina napsanym textem
    /// (bez ohledu na velikost pismen a diakritiku) a hrac ho jeste nema. Nil = nic se nenabidne.
    /// Vraci cely nazev navrhu; sedy zbytek v poli je `completion.dropFirst(typed.count)`.
    static func completion(for typed: String, taken: [StudySubject]) -> String? {
        guard !typed.isEmpty, typed.first?.isWhitespace == false else { return nil }
        let typedKey = prefixKey(typed)
        let takenKeys = Set(taken.map { matchKey($0.title) })
        return suggestions.first { suggestion in
            let key = prefixKey(suggestion)
            return key.count > typedKey.count && key.hasPrefix(typedKey) && !takenKeys.contains(matchKey(suggestion))
        }
    }

    /// Mala pismena bez diakritiky, ale se zachovanou delkou (mezery zustavaji), aby sel spocitat sedy zbytek.
    private static func prefixKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US")).lowercased()
    }

    /// Klic pro porovnani nazvu: mala pismena bez diakritiky, jen pismena a cislice ("Čeština" -> "cestina").
    static func matchKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .lowercased()
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }
}

/// Polozka seznamu predmetu hrace. Skryte a smazane predmety si drzi data (historii bitev).
struct SubjectEntry: Codable, Equatable, Sendable, Identifiable {
    var subject: StudySubject
    var isHidden = false
    /// Mekke smazani: predmet zmizi z bitev i ze Stats, ale jde obnovit.
    var deletedAt: Date?

    var id: String { subject.id }
    var isVisible: Bool { !isHidden && deletedAt == nil }

    // StudySubject se porovnava jen podle id; tady se musi projevit i prejmenovani, jinak by se neulozilo.
    static func == (lhs: SubjectEntry, rhs: SubjectEntry) -> Bool {
        lhs.subject.id == rhs.subject.id && lhs.subject.title == rhs.subject.title
            && lhs.isHidden == rhs.isHidden && lhs.deletedAt == rhs.deletedAt
    }

    init(subject: StudySubject, isHidden: Bool = false, deletedAt: Date? = nil) {
        self.subject = subject
        self.isHidden = isHidden
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey { case id, title, isHidden, deletedAt }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        subject = StudySubject(id: id, title: try container.decodeIfPresent(String.self, forKey: .title))
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(subject.id, forKey: .id)
        try container.encode(subject.title, forKey: .title)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
}

/// Vysledek pridani predmetu: novy, nebo uz existujici (duplicita), ktery se jen vybral.
enum SubjectAddResult: Equatable, Sendable {
    case created(StudySubject)
    case existing(StudySubject)

    var subject: StudySubject {
        switch self {
        case .created(let subject), .existing(let subject): subject
        }
    }
}

extension Array where Element == SubjectEntry {
    /// Predmety, ktere se ukazuji ve Fight sheetu (v poradi seznamu).
    var visibleSubjects: [StudySubject] { filter(\.isVisible).map(\.subject) }

    /// Existujici predmet se stejnym nazvem: shoda bez ohledu na velikost pismen a diakritiku,
    /// nebo zacatek nazvu, kdyz hrac napsal aspon 4 pismena ("econ" najde Economics).
    func duplicate(of name: String) -> SubjectEntry? {
        let key = StudySubject.matchKey(name)
        guard !key.isEmpty else { return nil }
        let candidates = sorted { ($0.deletedAt == nil ? 0 : 1) < ($1.deletedAt == nil ? 0 : 1) }
        return candidates.first { StudySubject.matchKey($0.subject.title) == key }
            ?? (key.count >= 4 ? candidates.first { StudySubject.matchKey($0.subject.title).hasPrefix(key) } : nil)
    }

    /// Prida predmet podle napsaneho nazvu. Duplicitu nevytvori: existujici predmet zviditelni
    /// (i skryty nebo smazany) a vrati ho jako `.existing`.
    mutating func add(named raw: String) -> SubjectAddResult? {
        let name = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty, !StudySubject.matchKey(name).isEmpty else { return nil }
        if let found = duplicate(of: name), let index = firstIndex(where: { $0.id == found.id }) {
            self[index].isHidden = false
            self[index].deletedAt = nil
            return .existing(self[index].subject)
        }
        let title = name.prefix(1).uppercased() + name.dropFirst()
        var id = title
        var suffix = 2
        while contains(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) {
            id = "\(title) \(suffix)"
            suffix += 1
        }
        let subject = StudySubject(id: id, title: title)
        append(SubjectEntry(subject: subject))
        return .created(subject)
    }

    /// Mekke smazani predmetu (data zustanou, predmet jde obnovit).
    mutating func softDelete(_ subject: StudySubject, at date: Date = Date()) {
        guard let index = firstIndex(where: { $0.id == subject.id }) else { return }
        self[index].deletedAt = date
    }

    /// Aktualni nazev predmetu ze seznamu (po prejmenovani), jinak ulozeny.
    func title(of subject: StudySubject) -> String {
        first { $0.id == subject.id }?.subject.title ?? subject.title
    }
}

/// Minuty soustredeni podle predmetu, serazene od nejvic procvicovaneho.
struct SubjectProgress: Identifiable, Equatable, Sendable {
    let subject: StudySubject
    let minutes: Int
    let battles: Int
    var id: String { subject.id }

    static func summarize(_ history: [SessionSummary]) -> [SubjectProgress] {
        var minutes: [StudySubject: Int] = [:]
        var battles: [StudySubject: Int] = [:]
        for entry in history {
            let subject = entry.subject ?? .general
            minutes[subject, default: 0] += max(0, entry.verifiedMinutes)
            battles[subject, default: 0] += 1
        }
        return battles
            .map { SubjectProgress(subject: $0.key, minutes: minutes[$0.key] ?? 0, battles: $0.value) }
            .sorted { $0.minutes == $1.minutes ? $0.subject.title < $1.subject.title : $0.minutes > $1.minutes }
    }
}
