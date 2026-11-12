import SwiftUI

struct LegalDocumentSheetView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FQSpace.lg) {
                HStack(alignment: .center, spacing: FQSpace.md) {
                    Text(document.title).font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                    Spacer(minLength: FQSpace.sm)
                    Button("Done") { dismiss() }
                        .font(.fqLabel)
                        .glassButtonStyle()
                        .buttonBorderShape(.capsule)
                        .tint(FQColor.textPrimary)
                }
                Text(document.content)
                    .font(.fqBody)
                    .lineSpacing(6)
                    .foregroundStyle(FQColor.textSecondary)
                if document == .privacy {
                    Text("Effective date: November 12, 2026").font(.fqMeta).foregroundStyle(FQColor.textTertiary)
                }
            }
            .padding(FQSpace.xl)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // Samotny list je sklo: pres material prosvita obrazovka pod nim.
        .presentationBackground(.ultraThinMaterial)
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}
