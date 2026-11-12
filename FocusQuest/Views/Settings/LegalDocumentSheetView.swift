import SwiftUI

struct LegalDocumentSheetView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            FocusQuestBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack { Text(document.title).font(.system(size: 24, weight: .bold, design: .rounded)); Spacer(); Button("Done") { dismiss() }.font(.system(size: 13, weight: .semibold)) }
                    Text(document.content).font(.system(size: 15, design: .rounded)).lineSpacing(6).foregroundStyle(.white.opacity(0.85))
                    if document == .privacy { Text("Effective date: November 12, 2026").font(.caption).foregroundStyle(.white.opacity(0.5)) }
                }.padding(22).frame(maxWidth: .infinity, alignment: .leading).glassmorphic()
            }.padding(18)
        }.preferredColorScheme(.dark)
    }
}