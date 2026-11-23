import SwiftUI
import WidgetKit

/// C1: widget na plochu (maly a stredni): serie, dalsi boss a dnesni minuty vs. Daily focus target.
/// Data zapisuje appka do App Group (WidgetSnapshot). Bez App Group (bezplatny ucet) widget data nema
/// a ukaze vyzvu "Open FocusQuest"; klepnuti vzdy otevre vyber pred bitvou (focusquest://fight).
struct FocusStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct FocusStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusStatusEntry {
        FocusStatusEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusStatusEntry) -> Void) {
        // Galerie widgetu ukaze ukazku, kdyz jeste nejsou skutecna data.
        let stored = WidgetSnapshot.stored()
        completion(FocusStatusEntry(date: Date(), snapshot: stored ?? (context.isPreview ? .sample : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusStatusEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let stored = WidgetSnapshot.stored()
        // O pulnoci se vynuluji dnesni minuty (a pripadne serie); appka widget obnovi po kazde bitve.
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(3_600)
        let entries = [FocusStatusEntry(date: now, snapshot: stored), FocusStatusEntry(date: midnight, snapshot: stored)]
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
    }
}

struct FocusStatusWidget: Widget {
    static let kind = "FocusQuestStatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: FocusStatusProvider()) { entry in
            FocusStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("FocusQuest")
        .description("Your streak, the next boss and today's focus.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct FocusStatusWidgetView: View {
    let entry: FocusStatusEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        FocusWidgetContent(snapshot: entry.snapshot, family: family, date: entry.date)
            .containerBackground(for: .widget) { FocusWidgetBackground() }
            .widgetURL(URL(string: "focusquest://fight"))
    }
}
