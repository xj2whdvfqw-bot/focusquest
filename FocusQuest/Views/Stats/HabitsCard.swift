import SwiftUI

/// Habits ve Stats (C0): pevna mrizka od prvniho dne pouzivani. Radky jsou dny v tydnu (M … S),
/// sloupce tydny (tyden 1 vlevo). Dny se nikdy neposouvaji; dnesek ma bily ramecek a kazdy den je o ctverecek dal.
/// Budouci dny jsou prazdne a tlumene, zamrzle dny (Streak freeze) maji led. Kdyz se tydny nevejdou, mrizka jde
/// posunout vodorovne a pri otevreni se sama posune k dnesku. Klepnuti na den ukaze bublinu s datem a minutami.
struct HabitsCard: View {
    let grid: HabitGrid
    @State private var selected: HabitDay?
    @State private var bubbleSize: CGSize = .zero

    private enum Layout {
        static let cell: CGFloat = 16
        static let gap: CGFloat = 4
        static let dayColumnGap: CGFloat = 6
        static let weekRowHeight: CGFloat = 14
        static let weekRowGap: CGFloat = 4
        static let padding: CGFloat = 16
        static let labelFont = Font.system(size: 10, weight: .regular, design: .rounded)
    }

    private var weekCount: Int { grid.weeks.count }
    private var gridWidth: CGFloat { CGFloat(weekCount) * Layout.cell + CGFloat(max(0, weekCount - 1)) * Layout.gap }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: Layout.dayColumnGap) {
                dayLabels
                    .padding(.top, Layout.weekRowHeight + Layout.weekRowGap)
                ScrollViewReader { reader in
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: Layout.weekRowGap) {
                            weekNumbers
                            cells
                        }
                        // Misto pro bublinu nad hornim radkem a pro ramecek dneska.
                        .padding(.vertical, 2)
                        .padding(.trailing, 2)
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    // Pri otevreni je dnesek videt (az se tydny nevejdou na sirku).
                    .onAppear { reader.scrollTo(grid.todayWeek, anchor: .center) }
                    .onChange(of: grid.todayWeek) { _, week in reader.scrollTo(week, anchor: .center) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            legend
        }
        .padding(Layout.padding)
        .fqCard()
        .contentShape(Rectangle())
        .onTapGesture { selected = nil }
        .animation(.easeOut(duration: 0.15), value: selected)
    }

    // MARK: - Popisky

    private var dayLabels: some View {
        VStack(spacing: Layout.gap) {
            ForEach(grid.rowLetters.indices, id: \.self) { index in
                Text(grid.rowLetters[index])
                    .font(Layout.labelFont)
                    .foregroundStyle(FQColor.textTertiary)
                    .frame(height: Layout.cell)
            }
        }
        .accessibilityHidden(true)
    }

    /// Cislo nad kazdym lichym tydnem (tyden 1 = prvni tyden pouzivani); aktualni tyden je zvyrazneny vzdy.
    private var weekNumbers: some View {
        HStack(spacing: Layout.gap) {
            ForEach(0..<weekCount, id: \.self) { index in
                let isCurrent = index == grid.todayWeek
                Text(index % 2 == 0 || isCurrent ? "\(index + 1)" : "")
                    .font(Layout.labelFont.weight(isCurrent ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isCurrent ? FQColor.accent : FQColor.textTertiary)
                    .fixedSize()
                    .frame(width: Layout.cell, height: Layout.weekRowHeight)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Mrizka

    private var cells: some View {
        HStack(alignment: .top, spacing: Layout.gap) {
            ForEach(grid.weeks.indices, id: \.self) { week in
                VStack(spacing: Layout.gap) {
                    ForEach(grid.weeks[week]) { day in cell(day) }
                }
                .id(week)
            }
        }
        .overlay(alignment: .topLeading) { bubbleOverlay }
    }

    @ViewBuilder private func cell(_ day: HabitDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: Layout.cell * 0.25, style: .continuous)
        if day.isBeforeStart {
            // Pred prvnim dnem pouzivani: prazdne misto, aby prvni den sedel ve svem radku.
            Color.clear
                .frame(width: Layout.cell, height: Layout.cell)
                .accessibilityHidden(true)
        } else if day.isFuture {
            // Budouci dny: prazdne a tlumenejsi nez dny bez soustredeni.
            shape
                .strokeBorder(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: Layout.cell, height: Layout.cell)
                .accessibilityHidden(true)
        } else {
            shape
                .fill(day.isFrozen && day.minutes == 0 ? Self.ice : Self.color(level: day.level))
                .overlay {
                    if day.isFrozen {
                        Image(systemName: "snowflake")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: Layout.cell, height: Layout.cell)
                .shadow(color: day.level == 4 ? Self.glow : .clear, radius: 3)
                .overlay {
                    if day.isToday || selected == day {
                        shape.strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    FQFeedback.shared.tap()
                    selected = selected == day ? nil : day
                }
                .accessibilityElement()
                .accessibilityLabel("\(Self.dateText(day)): \(day.isFrozen ? "streak freeze, streak kept" : Self.minutesText(day.minutes, spoken: true))")
                .accessibilityAddTraits(.isButton)
        }
    }

    /// Bublina nad vybranym dnem; vodorovne se drzi u mrizky, aby nevyjela z karty.
    @ViewBuilder private var bubbleOverlay: some View {
        if let day = selected, let position = position(of: day) {
            let step = Layout.cell + Layout.gap
            let half = bubbleSize.width / 2
            let anchorX = CGFloat(position.week) * step + Layout.cell / 2
            let minX = half - Layout.dayColumnGap - 10
            let maxX = gridWidth - half + Layout.padding / 2
            let centerX = maxX >= minX ? min(max(anchorX, minX), maxX) : gridWidth / 2
            HabitBubble(text: "\(Self.dateText(day)) · \(day.isFrozen ? "❄︎ streak freeze" : Self.minutesText(day.minutes, spoken: false))")
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { bubbleSize = $0 }
                .offset(x: centerX - half, y: CGFloat(position.day) * step - bubbleSize.height - 4)
                .transition(.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func position(of day: HabitDay) -> (week: Int, day: Int)? {
        for (week, days) in grid.weeks.enumerated() {
            if let index = days.firstIndex(of: day) { return (week, index) }
        }
        return nil
    }

    // MARK: - Legenda

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                legendText
                Spacer(minLength: 0)
                scale
            }
            VStack(alignment: .leading, spacing: 4) {
                legendText
                scale
            }
        }
        .font(.system(size: 13, design: .rounded))
        .foregroundStyle(FQColor.textSecondary)
    }

    private var legendText: some View {
        Text("Each square is one day, starting from your first day · filled by your focus time")
            .fixedSize(horizontal: false, vertical: true)
    }

    private var scale: some View {
        HStack(spacing: 3) {
            Text("0 min").padding(.trailing, 3)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Self.color(level: level))
                    .frame(width: 10, height: 10)
            }
            Text("90+ min").padding(.leading, 3)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Darker green means less focus, lighter green means 90 minutes or more")
    }

    // MARK: - Barvy a texty

    /// Odstiny zelene od tmave (malo) po svetlou (hodne), bez tyrkysove.
    static func color(level: Int) -> Color {
        switch level {
        case 1: Color(red: 0x22 / 255, green: 0x4A / 255, blue: 0x2C / 255)
        case 2: Color(red: 0x2F / 255, green: 0x7A / 255, blue: 0x3E / 255)
        case 3: Color(red: 0x4E / 255, green: 0xAE / 255, blue: 0x55 / 255)
        case 4: Color(red: 0x8E / 255, green: 0xE0 / 255, blue: 0x7C / 255)
        default: Color.white.opacity(0.08)
        }
    }

    /// C2: zamrzly den (Streak freeze) bez soustredeni: ledove modra.
    static let ice = Color(red: 0x5B / 255, green: 0xB8 / 255, blue: 0xF0 / 255).opacity(0.55)

    private static let glow = Color(red: 0x8E / 255, green: 0xE0 / 255, blue: 0x7C / 255).opacity(0.45)

    static func dateText(_ day: HabitDay) -> String {
        if day.isToday { return "Today" }
        return day.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    static func minutesText(_ minutes: Int, spoken: Bool) -> String {
        guard minutes > 0 else { return "no focus" }
        return ArenaView.durationText(minutes: minutes) + (spoken ? " of focus" : "")
    }
}

/// Mala kremova pixelova bublina s datem a minutami (stejny tvar jako toasty).
private struct HabitBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(PixelToast.ink)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    PixelBubbleShape(step: 3).fill(PixelToast.ink)
                    PixelBubbleShape(step: 3).fill(PixelToast.paper).padding(2)
                }
                .compositingGroup()
                .shadow(color: Color(red: 10 / 255, green: 8 / 255, blue: 24 / 255).opacity(0.45), radius: 0, y: 3)
            }
    }
}
