import ActivityKit
import Foundation

/// Data Live Activity. Soubor je ve slozce Shared, protoze stejny typ musi znat
/// appka (spousti aktivitu) i Widget Extension (kresli ji na zamcene obrazovce).
///
/// Appka na pozadi nebezi, takze widget nedostava kazdou sekundu nova data. Cas i HP bar
/// proto kresli system sam z data zacatku a konce bitvy (Text(timerInterval:),
/// ProgressView(timerInterval:)). Appka posila novy stav jen pri zmene: pauza, varovani, konec.
struct FocusBattleAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var bossHP: Int
        var bossMaxHP: Int
        /// Zacatek soustredeni posunuty o pauzy. nil = ceka se na polozeni telefonu.
        var focusStartedAt: Date?
        /// Konec varovneho odpoctu po zvednuti telefonu. nil = zadne varovani.
        var warningEndsAt: Date?
        /// Kdy bitva skonci, kdyz hodiny pobezi dal (zacatek + delka bitvy). HP bar a odpocet z nej
        /// pocita system. Starsi stavy pole nemaji, proto je volitelne.
        var focusEndsAt: Date? = nil
        /// Hodiny stoji (pauza, hovor, zvednuty telefon): kolik sekund bitvy zbyva. nil = hodiny bezi.
        var frozenRemainingSeconds: Int? = nil
        /// Bitva skoncila: vysledek na zamcene obrazovce, nez aktivita zmizi.
        var outcome: Outcome? = nil

        var isWarning: Bool { warningEndsAt != nil && outcome == nil }
        var isFrozen: Bool { frozenRemainingSeconds != nil }
    }

    /// Vysledek bitvy pro posledni stav Live Activity.
    enum Outcome: String, Codable, Hashable {
        case victory, escaped
    }

    var bossName: String
    var bossSpriteID: String
    var bossMaxHP: Int
}
