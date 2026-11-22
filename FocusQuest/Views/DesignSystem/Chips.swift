import SwiftUI

/// Cipy (predmety, zvuk, styl vlasu ...) maji v cele appce stejny vzhled.
/// Vybrany cip: tmave pozadi .55, bily tucny text, zluty vnitrni okraj 1,5 pt. Zadna zluta ani matova vypln.
enum FQChipMetrics {
    static let height: CGFloat = 40
    static let compactHeight: CGFloat = 34
    static let padding: CGFloat = 16
    static let compactPadding: CGFloat = 12
    static let fill = Color.white.opacity(0.14)
    static let selectedFill = Color.black.opacity(0.55)
    static let selectedBorder = FQColor.cta.opacity(0.6)
    static let selectedBorderWidth: CGFloat = 1.5
}

extension View {
    /// Vzhled cipu pro libovolny popisek (text, ikona s textem). Sirka podle obsahu.
    func fqChip(selected: Bool, compact: Bool = false) -> some View {
        // Sirka je vzdy podle tucneho popisku: vyber cip nerozsiri, takze se v ChipFlow nic nezalomi
        // jinak a poradi polozek zustava pevne (vyber jen zvyrazni).
        ZStack {
            self.fqFont(size: compact ? 14 : 15, weight: .bold, design: .rounded).hidden()
            self.fqFont(size: compact ? 14 : 15, weight: selected ? .bold : .medium, design: .rounded)
        }
            .foregroundStyle(selected ? Color.white : FQColor.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, compact ? FQChipMetrics.compactPadding : FQChipMetrics.padding)
            .frame(height: compact ? FQChipMetrics.compactHeight : FQChipMetrics.height)
            .background(selected ? FQChipMetrics.selectedFill : FQChipMetrics.fill, in: Capsule())
            .overlay {
                if selected {
                    Capsule().strokeBorder(FQChipMetrics.selectedBorder, lineWidth: FQChipMetrics.selectedBorderWidth)
                }
            }
            .contentShape(Capsule())
    }
}

/// Vyberovy cip s textem.
struct FQChip: View {
    let title: String
    let isSelected: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).fqChip(selected: isSelected, compact: compact)
        }
        .buttonStyle(.fqPress)
        // Cil dotyku aspon 44 pt i u nizsiho cipu.
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Jednoduche zalamovani cipu do radku (zleva doprava, dalsi radek pri nedostatku mista).
struct ChipFlow: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + rowSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
                x += min(size.width, bounds.width) + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let itemWidth = min(size.width, width)
            let needed = current.indices.isEmpty ? itemWidth : current.width + spacing + itemWidth
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? itemWidth : current.width + spacing + itemWidth
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
