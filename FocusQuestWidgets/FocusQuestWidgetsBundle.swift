import SwiftUI
import WidgetKit

/// Vstupni bod Widget Extension. Zatim obsahuje jen Live Activity bitvy.
@main
struct FocusQuestWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FocusBattleLiveActivity()
    }
}
