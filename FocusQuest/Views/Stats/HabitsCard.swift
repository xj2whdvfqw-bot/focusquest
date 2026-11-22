import SwiftUI

/// Habits ve Stats: mrizka dni na sirku (sloupec = 7 dni, radek = den v tydnu), barva podle minut soustredeni.
/// Poradi je od nejnovejsiho: dnesek je prvni ctverecek vlevo nahore, dolu a doprava jdou starsi dny
/// (sloupec 1 = poslednich 7 dni). Pismena dni vlevo sedi na kazdy sloupec, protoze sloupce maji po 7 dnech.
/// Cisla tydnu 1, 3, 5 … stoji kazde vycentrovane nad svym sloupcem (stejna sirka jako bunka).
/// Klepnuti na den ukaze malou bublinu s datem a minutami; dalsi klepnuti ji schova.
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
                VStack(alignment: .leading, spacing: Layout.weekRowGap) {
                    weekNumbers
                    cells
                }
            }
            .frame(maxWidth: .infinity)
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

    /// Cislo nad kazdym lichym tydnem; prvni (aktualni, vlevo) je zvyrazneny.
    private var weekNumbers: some View {
        HStack(spacing: Layout.gap) {
            ForEach(0..<weekCount, id: \.self) { index in
                let isCurrent = index == 0
                Text(index % 2 == 0 ? "\(index + 1)" : "")
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
            }
        }
        .overlay(alignment: .topLeading) { bubbleOverlay }
    }

    @ViewBuilder private func cell(_ day: HabitDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: Layout.cell * 0.25, style: .continuous)
        if day.isFuture {
            shape
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: Layout.cell, height: Layout.cell)
                .accessibilityHidden(true)
        } else {
            shape
                .fill(Self.color(level: day.level))
                .frame(width: Layout.cell, height: Layout.cell)
                .shadow(color: day.level == 4 ? Self.glow : .clear, radius: 3)
                .overlay {
                    if day.isToday || selected == day {
                        shape.strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selected = selected == day ? nil : day }
                .accessibilityElement()
                .accessibilityLabel("\(Self.dateText(day)): \(Self.minutesText(day.minutes, spoken: true))")
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
            HabitBubble(text: "\(Self.dateText(day)) · \(Self.minutesText(day.minutes, spoken: false))")
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
        Text("Today is top left, older days go down and to the right · filled by your focus time")
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
