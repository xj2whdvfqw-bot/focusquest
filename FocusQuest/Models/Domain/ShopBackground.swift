import Foundation

/// Pozadi z obchodu. Zvolene pozadi nahradi pixelovou krajinu na vsech obrazovkach;
/// bez nej (World scenes) ma kazdy svet svou nocni scenu.
enum ShopBackground: String, Codable, CaseIterable, Identifiable, Sendable {
    case dawn, sunset, pyramids, farm, city, cave, race, space, wind

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dawn: "Daybreak"
        case .sunset: "Sunset"
        case .pyramids: "Pyramids"
        case .farm: "Farm"
        case .city: "Neon City"
        case .cave: "Crystal Cave"
        case .race: "Race Track"
        case .space: "Deep Space"
        case .wind: "Wind Farm"
        }
    }

    /// Cena v mincich; 0 = zdarma.
    var price: Int {
        switch self {
        case .dawn, .sunset: 0
        case .pyramids, .farm: 800
        case .city, .cave: 1000
        case .race: 1200
        case .space, .wind: 1500
        }
    }

    var blurb: String {
        switch self {
        case .dawn: "Soft morning light over green hills."
        case .sunset: "Warm sky, birds heading home."
        case .pyramids: "Desert sun and a camel taking its time."
        case .farm: "Red barn, fields and lazy clouds."
        case .city: "Rooftops and a thousand lit windows."
        case .cave: "Glowing crystals, slow drips."
        case .race: "Stadium lights and cars that never stop."
        case .space: "A ringed planet and drifting stars."
        case .wind: "A meadow with turbines spinning in the breeze."
        }
    }

    var isFree: Bool { price == 0 }

    /// Svetla pozadi (sekce 12 jim pozdeji prida silnejsi stiny textu).
    var isBright: Bool { [.dawn, .sunset, .pyramids, .farm, .wind].contains(self) }

    /// Poradi v obchode: nejdriv zdarma, pak za mince od nejlevnejsiho (jako tabulka v CHANGES.md).
    static let free: [ShopBackground] = [.dawn, .sunset]
    static let forCoins: [ShopBackground] = [.pyramids, .farm, .city, .cave, .race, .space, .wind]

    static let worldName = "World scenes"
    static let worldBlurb = "Each world keeps its own night scene."
}
