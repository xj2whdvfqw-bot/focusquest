import SwiftUI
import UserNotifications

@main
struct FocusQuestApp: App {
    @State private var container = AppDIContainer()

    init() {
        _ = RuntimeSecurityService().integrityReport()
        UNUserNotificationCenter.current().delegate = ForegroundNotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(container: container)
                // Text roste s Dynamic Type az po nejvetsi bezne velikosti a dve accessibility velikosti;
                // vetsi uz by rozbily karty a plovouci listu.
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
    }
}