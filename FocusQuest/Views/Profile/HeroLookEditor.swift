import SwiftUI

/// Volba, ktera se v editoru ukazuje jako barevne kolecko.
protocol SwatchOption: Identifiable, Equatable {
    var rgb: RGB { get }
    var displayName: String { get }
}

extension SkinTone: SwatchOption { }
extension HairColor: SwatchOption { }
extension GearColor: SwatchOption { }

/// Editor vzhledu hrdiny: kuze, uces, barva vlasu, obleceni a boty.
/// Pouziva ho list Edit appearance na zalozce Hero.
struct HeroLookEditor: View {
    let appearance: AvatarAppearance
    let onChange: (AvatarAppearance) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FQSpace.md) {
            swatchRow("Skin", options: SkinTone.allCases, selected: appearance.skin) { value in change { $0.skin = value } }
            HairlineDivider()
            hairStyleRow
            swatchRow("Hair color", options: HairColor.allCases, selected: appearance.hairColor) { value in change { $0.hairColor = value } }
                .disabled(appearance.hairStyle == .bald)
                .opacity(appearance.hairStyle == .bald ? 0.4 : 1)
            HairlineDivider()
            swatchRow("Outfit", options: GearColor.allCases, selected: appearance.outfitColor) { value in change { $0.outfitColor = value } }
            swatchRow("Boots", options: GearColor.allCases, selected: appearance.bootsColor) { value in change { $0.bootsColor = value } }
        }
    }

    private func change(_ edit: (inout AvatarAppearance) -> Void) {
        var copy = appearance
        edit(&copy)
        onChange(copy)
    }

    private var hairStyleRow: some View {
        VStack(alignment: .leading, spacing: FQSpace.xs) {
            Text("Hair style").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            FadingHorizontalScroll {
                HStack(spacing: FQSpace.sm) {
                    ForEach(HairStyle.allCases) { style in
                        FQChip(title: style.displayName, isSelected: style == appearance.hairStyle, compact: true) {
                            change { $0.hairStyle = style }
                        }
                        .accessibilityLabel("Hair style \(style.displayName)")
                    }
                }
            }
        }
    }

    private func swatchRow<Option: SwatchOption>(_ title: String, options: [Option], selected: Option, select: @escaping (Option) -> Void) -> some View {
        VStack(alignment: .leading, spacing: FQSpace.xs) {
            Text(title).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            FadingHorizontalScroll {
                HStack(spacing: 0) {
                    ForEach(options) { option in
                        let isSelected = option == selected
                        Button { select(option) } label: {
                            Circle()
                                .fill(Color(rgb: option.rgb))
                                .frame(width: 28, height: 28)
                                .overlay { Circle().strokeBorder(FQColor.hairline, lineWidth: 1) }
                                .padding(FQSpace.xs)
                                .overlay { Circle().strokeBorder(isSelected ? FQColor.accent : Color.clear, lineWidth: 2) }
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.fqPress)
                        .accessibilityLabel("\(title) \(option.displayName)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
    }
}
