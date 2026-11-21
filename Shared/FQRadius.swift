import SwiftUI

/// Vsechny polomery rohu appky i Live Activity na jednom miste.
///
/// Pravidlo koncentrickych rohu: prvek uvnitr zaobleneho kontejneru ma polomer
/// `vnejsi polomer − odsazeni od okraje`, takze oba rohy maji spolecny stred.
/// Vnitrni polomery se proto nezadavaji cisly, ale odvozuji z kontejneru a odsazeni:
/// zmena karty nebo odsazeni se propise do vsech vnorenych tlacitek.
///
/// iOS 26+: `FQRadius.shape` vraci `ConcentricRectangle` a kontejnery nastavuji `.containerShape`,
/// takze rohy dopocita system podle skutecne polohy prvku. iOS 17–25: stejny polomer z `concentric`.
///
/// Pixelove bubliny, toasty a sprity sem nepatri: maji schvalne schodovite rohy.
enum FQRadius {
    // MARK: - Odsazeni (vzdalenost vnoreneho prvku od okraje kontejneru)

    enum Inset {
        /// Plovouci lista zalozek od boku i spodku displeje.
        static let tabBar: CGFloat = 22
        /// Vybrana zalozka uvnitr listy.
        static let tabHighlight: CGFloat = 4
        /// Obsah sklenene karty (FQSpace.lg).
        static let card: CGFloat = 16
        /// Obsah dialogu pres obrazovku: porazka, hovor, vysledek (FQSpace.xl).
        static let dialog: CGFloat = 24
        /// Obsah karty predmetu v obchodu (FQSpace.md).
        static let smallCard: CGFloat = 12
        /// Obsah karty pozadi v obchodu.
        static let backgroundCard: CGFloat = 10
        /// Okraj listu: Fight sheet, Your subjects (FQSpace.gutter).
        static let sheet: CGFloat = 20
        /// Panel prestavky od boku a spodku displeje (FQSpace.sm).
        static let breakPanel: CGFloat = 8
        /// Obsah karty bitvy od jejiho boku.
        static let battleCard: CGFloat = 15
        /// Obsah Live Activity na zamcene obrazovce.
        static let liveActivity: CGFloat = 16
        /// Plosinka pod spritem bosse v Live Activity.
        static let spritePlatter: CGFloat = 6
    }

    // MARK: - Vnejsi kontejnery

    /// Roh displeje iPhonu bez tlacitka Home (priblizne; iOS 26 zna presnou hodnotu sam).
    static let display: CGFloat = 55
    /// Sklenena karta a listy (Fight sheet, Your subjects).
    static let card: CGFloat = 32
    /// Tlacitko v dialogu; dialog je o odsazeni vetsi, aby byly rohy soustredne.
    static let control: CGFloat = 20
    /// Dialog pres obrazovku (porazka, "Call ended", vysledek): 20 + 24.
    static let dialog: CGFloat = control + Inset.dialog
    /// Mala karta v obchodu (predmet, pozadi).
    static let smallCard: CGFloat = 24
    /// Karta bitvy.
    static let battleCard: CGFloat = 45
    /// Panel prestavky lezi 8 bodu od rohu displeje.
    static let breakPanel = concentric(display, inset: Inset.breakPanel)
    /// Plovouci lista zalozek u spodnich rohu displeje (vyska 62 = polokruhove konce).
    static let tabBar = concentric(display, inset: Inset.tabBar)

    // MARK: - Vnorene prvky (odvozene)

    /// Prvek ve sklenene karte (tlacitko Start ve Stats, dlazdice bossu na Path).
    static let inCard = concentric(card, inset: Inset.card)
    /// Tlacitko v dialogu.
    static let inDialog = concentric(dialog, inset: Inset.dialog)
    /// Nahled a tlacitko v karte predmetu.
    static let inSmallCard = concentric(smallCard, inset: Inset.smallCard)
    /// Nahled scenerie a tlacitka v karte pozadi.
    static let inBackgroundCard = concentric(smallCard, inset: Inset.backgroundCard)
    /// Radek v listu (Your subjects).
    static let inSheet = concentric(card, inset: Inset.sheet)
    /// Tlacitko Start dole ve Fight sheetu: spodek listu konci u rohu displeje.
    static let sheetBottomButton = concentric(display, inset: Inset.sheet)
    /// Tlacitko v karte bitvy.
    static let inBattleCard = concentric(battleCard, inset: Inset.battleCard)
    /// Tlacitko "Next boss" v panelu prestavky (16 od boku).
    static let inBreakPanel = concentric(breakPanel, inset: Inset.card)
    /// Dlazdice na spodnim okraji panelu prestavky (24 od spodku).
    static let breakPanelBottom = concentric(breakPanel, inset: Inset.dialog)
    /// Vybrana zalozka v liste.
    static let tabHighlight = concentric(tabBar, inset: Inset.tabHighlight)

    // MARK: - Samostatne prvky (nejsou v zaoblenem kontejneru)

    /// Velke zlute tlacitko na obrazovce (Fight v Arene, onboarding, vitezstvi).
    static let pill: CGFloat = 26
    /// Tlacitka na obrazovce ustupu (rozmazane pozadi, bez karty).
    static let battleButton: CGFloat = 15
    /// Pilulka (serie v Arene): polomer vetsi nez polovina vysky = polokruhove konce.
    static let capsule: CGFloat = 1_000
    /// Male ctvercove dlazdice s ikonou a stitky.
    static let tile: CGFloat = 12
    /// Nejmensi polomer vnoreneho prvku, aby nikdy nebyl hranaty.
    static let minimum: CGFloat = 10

    // MARK: - Vypocet

    /// Vnitrni polomer = vnejsi − odsazeni (nikdy pod `minimum`).
    static func concentric(_ outer: CGFloat, inset: CGFloat) -> CGFloat {
        max(minimum, outer - inset)
    }

    /// Tvar vnoreneho prvku s polomerem `radius` (z `concentric`).
    /// iOS 26+: ConcentricRectangle vuci nejblizsimu `containerShape` (karta, list, displej),
    /// nejmene `radius`. iOS 17–25: zaobleny obdelnik s presne timto polomerem.
    static func shape(_ radius: CGFloat) -> AnyShape {
        if #available(iOS 26.0, *) {
            return AnyShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(radius)), isUniform: true))
        }
        return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    /// Zaobleny kontejner: vnorene `FQRadius.shape` (na iOS 26 ConcentricRectangle) jsou s nim soustredne.
    /// Na iOS 17–25 neni potreba: vnorene prvky tam maji polomer spocitany v `FQRadius`.
    @ViewBuilder func fqContainer(radius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            containerShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            self
        }
    }
}
