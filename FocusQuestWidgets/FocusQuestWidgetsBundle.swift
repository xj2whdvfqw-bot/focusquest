import SwiftUI
import WidgetKit

/// Vstupni bod Widget Extension: Live Activity bitvy a widget na plochu (C1).
@main
struct FocusQuestWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FocusBattleLiveActivity()
        FocusStatusWidget()
    }
}
