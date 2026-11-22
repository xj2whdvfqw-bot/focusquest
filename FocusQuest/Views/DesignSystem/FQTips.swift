import Foundation
import SwiftUI
import TipKit

/// Kratky tutorial pres TipKit misto onboardingu. Kazdy tip je popover primo u prvku, ukaze se,
/// az je prvek opravdu na obrazovce, jen jednou, a po zavreni (nebo provedeni akce) se nevraci.
/// Poradi odpovida prvnimu pouziti appky:
///  1. Home: Fight,
///  2. Fight sheet: na co se soustredis a hudba,
///  3. bitva pred polozenim telefonu: pauzy a utek pri zvednuti,
///  4. okno vyhry: mince do Shopu,
///  5. Path: mapa svetu (az po prvni vyhre),
///  6. Hero: uprava hrdiny (az po prvni vyhre).
enum FQTips {
    /// Prvni (a kazda dalsi) vyhrana bitva. Tipy 5 a 6 cekaji na prvni vyhru, aby tutorial sel popořadě.
    static let battleWon = Tips.Event(id: "focusquest.battleWon")

    /// Debug „Reset tips“: datastore TipKitu jde smazat jen pred `Tips.configure`, proto se to provede pri dalsim spusteni.
    static let resetOnLaunchKey = "focusquest.resetTipsOnLaunch"

    /// Volano jednou pri startu appky.
    static func configure() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: resetOnLaunchKey) {
            defaults.removeObject(forKey: resetOnLaunchKey)
            try? Tips.resetDatastore()
        }
        try? Tips.configure([.displayFrequency(.immediate), .datastoreLocation(.applicationDefault)])
        #if DEBUG
        // CI screenshoty (-initialTab …) bez popoveru pres obsah.
        if defaults.string(forKey: "initialTab") != nil { Tips.hideAllTipsForTesting() }
        #endif
    }

    /// Debug: tipy se ukazi znovu od zacatku (po restartu appky).
    static func resetOnNextLaunch() {
        UserDefaults.standard.set(true, forKey: resetOnLaunchKey)
    }

    /// Zapise vyhru pro pravidla tipu 5 a 6.
    static func recordVictory() {
        Task { await battleWon.donate() }
    }
}

/// 1. Home: tlacitko Fight.
struct FightTip: Tip {
    var title: Text { Text("Beat the boss by focusing") }
    var message: Text? { Text("Tap Fight, put your phone face-down and the boss loses HP while you focus.") }
    var image: Image? { Image(systemName: "play.fill") }
}

/// 2. Fight sheet: predmet a hudba.
struct FightSetupTip: Tip {
    var title: Text { Text("What are you focusing on?") }
    var message: Text? { Text("Pick a subject and the music for this battle. Your choice is remembered for next time.") }
    var image: Image? { Image(systemName: "music.note") }
}

/// 3. Bitva pred polozenim telefonu: pauzy a utek.
struct PhoneDownTip: Tip {
    var title: Text { Text("Face-down starts the battle") }
    var message: Text? { Text("You get 2 pauses per battle. If you pick the phone up, the boss escapes.") }
    var image: Image? { Image(systemName: "iphone.gen3") }
}

/// 4. Okno vyhry: mince do Shopu.
struct CoinsTip: Tip {
    var title: Text { Text("Coins for the Shop") }
    var message: Text? { Text("Spend them on gear and backgrounds in the Shop tab.") }
    var image: Image? { Image(systemName: "bag.fill") }
}

/// 5. Path: mapa svetu (po prvni vyhre).
struct PathTip: Tip {
    var title: Text { Text("Your world map") }
    var message: Text? { Text("Drag and pinch to explore. Beat every boss in a world to unlock the next one.") }
    var image: Image? { Image(systemName: "map.fill") }
    var rules: [Rule] {
        #Rule(FQTips.battleWon) { $0.donations.count >= 1 }
    }
}

/// 6. Hero: uprava hrdiny (po prvni vyhre).
struct HeroTip: Tip {
    var title: Text { Text("Make the hero yours") }
    var message: Text? { Text("Change the look here. Class and gear are on this tab and in the Shop.") }
    var image: Image? { Image(systemName: "paintbrush.fill") }
    var rules: [Rule] {
        #Rule(FQTips.battleWon) { $0.donations.count >= 1 }
    }
}
