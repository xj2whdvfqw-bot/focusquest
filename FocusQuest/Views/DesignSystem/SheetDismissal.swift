import SwiftUI
import UIKit

// Zavirani vyjizdejicich oken (sheetu) tahem dolu.
//
// Samotny tah obstarava system: okno sleduje prst, po pusteni se podle vzdalenosti a rychlosti
// zavre nebo zajede zpet, a kdyz obsah roluje, zavira se az od horniho okraje. Tady se jen:
// - tah zablokuje tam, kde okno zavrit nesmi (potvrzeni smazani, reset, rozepsany predmet),
// - zachyti pokus o zavreni zablokovaneho okna (napr. dotaz "Discard the new focus?"),
// - prida zavreni pro VoiceOver misto krizku (escape gesto a akce "Close").

extension View {
    /// Zavreni okna tahem dolu a pres VoiceOver.
    /// - `blocked`: tah okno nezavre, jen zajede zpet.
    /// - `onBlockedAttempt`: co udelat, kdyz se hrac pokusi zablokovane okno zavrit (tahem nebo VoiceOverem).
    /// - `close`: zavreni okna (VoiceOver escape).
    func fqSheetDismissal(blocked: Bool, onBlockedAttempt: (() -> Void)? = nil, close: @escaping () -> Void) -> some View {
        interactiveDismissDisabled(blocked)
            .background(DismissAttemptObserver(onAttempt: blocked ? onBlockedAttempt : nil))
            // Okno je kontejner: prvky uvnitr zustanou samostatne, escape gesto patri celemu oknu.
            .accessibilityElement(children: .contain)
            .accessibilityAction(.escape) {
                if blocked { onBlockedAttempt?() } else { close() }
            }
    }

    /// Akce "Close" pro VoiceOver na nadpisu okna (nahrazuje krizek).
    func fqSheetCloseAction(_ close: @escaping () -> Void) -> some View {
        accessibilityAction(named: "Close", close)
    }
}

/// Zachyti pokus o zavreni okna, ktere ma zavreni tahem zablokovane (UIKit
/// `presentationControllerDidAttemptToDismiss`). SwiftUI tuto udalost na iOS 17 nema.
private struct DismissAttemptObserver: UIViewControllerRepresentable {
    let onAttempt: (() -> Void)?

    func makeUIViewController(context: Context) -> ObserverController { ObserverController() }

    func updateUIViewController(_ controller: ObserverController, context: Context) {
        controller.proxy.onAttempt = onAttempt
        controller.install()
    }

    final class ObserverController: UIViewController {
        let proxy = DismissAttemptProxy()

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            install()
        }

        /// Zaradi proxy pred delegata, ktereho okno uz ma (SwiftUI); vsechno ostatni mu dal preposila.
        func install() {
            var top: UIViewController = self
            while let parent = top.parent { top = parent }
            guard let presentation = top.presentationController,
                  presentation.delegate !== proxy else { return }
            proxy.original = presentation.delegate
            presentation.delegate = proxy
        }
    }
}

/// Delegat okna, ktery hlasi pokus o zavreni a vse ostatni preposila puvodnimu delegatovi (SwiftUI).
@MainActor
private final class DismissAttemptProxy: NSObject, UIAdaptivePresentationControllerDelegate {
    nonisolated(unsafe) weak var original: (any UIAdaptivePresentationControllerDelegate)?
    var onAttempt: (() -> Void)?

    override nonisolated func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (original?.responds(to: aSelector) ?? false)
    }

    override nonisolated func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original, original.responds(to: aSelector) { return original }
        return super.forwardingTarget(for: aSelector)
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        original?.presentationControllerDidAttemptToDismiss?(presentationController)
        onAttempt?()
    }
}
