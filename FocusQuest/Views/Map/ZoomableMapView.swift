import SwiftUI
import UIKit

/// Pozadavek na kameru mapy: kam najet a s jakym zoomem. Novy `token` ho provede.
struct MapCameraRequest: Equatable {
    var point: CGPoint
    var zoom: CGFloat
    /// Odkud kamera startuje (oddaleni pred najezdem); nil = z aktualni pozice.
    var startZoom: CGFloat? = nil
    var animated = true
    var token: Int
}

/// Mapa v nativnim UIScrollView: posun tazenim se setrvacnosti, pinch-zoom a pruzne okraje
/// v plnych 60 fps. Obsah je SwiftUI v UIHostingController (zastavky jsou normalni tlacitka
/// s VoiceOver popisky). Zoom zvetsuje vrstvy transformaci, pixelovy teren zustava ostry
/// (bez vyhlazovani).
struct ZoomableMapView<Content: View>: UIViewRepresentable {
    let contentSize: CGSize
    var minZoom: CGFloat = 0.5
    var maxZoom: CGFloat = 1.6
    var camera: MapCameraRequest?
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(hosting: UIHostingController(rootView: content()), contentSize: contentSize)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = minZoom
        scroll.maximumZoomScale = maxZoom
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.decelerationRate = .normal
        scroll.backgroundColor = .clear
        let hostView = context.coordinator.hosting.view!
        hostView.backgroundColor = .clear
        // Mapa je vzdy nocni pixel-art: tokeny barev musi byt v tmavem rezimu i uvnitr UIKitu.
        context.coordinator.hosting.overrideUserInterfaceStyle = .dark
        if #available(iOS 16.4, *) { context.coordinator.hosting.safeAreaRegions = [] }
        hostView.frame = CGRect(origin: .zero, size: contentSize)
        scroll.addSubview(hostView)
        scroll.contentSize = contentSize
        scroll.zoomScale = 1
        context.coordinator.scrollView = scroll
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.hosting.rootView = content()
        guard let camera, camera.token != coordinator.lastToken else { return }
        coordinator.lastToken = camera.token
        Task { @MainActor in coordinator.move(to: camera) }
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hosting: UIHostingController<Content>
        let contentSize: CGSize
        weak var scrollView: UIScrollView?
        var lastToken = -1

        init(hosting: UIHostingController<Content>, contentSize: CGSize) {
            self.hosting = hosting
            self.contentSize = contentSize
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { hosting.view }

        /// Bod mapy doprostred obrazovky (o kousek vys, aby ho nezakryla karta bosse).
        private func offset(centering point: CGPoint, zoom: CGFloat, in size: CGSize) -> CGPoint {
            let maxX = max(0, contentSize.width * zoom - size.width)
            let maxY = max(0, contentSize.height * zoom - size.height)
            return CGPoint(
                x: min(maxX, max(0, point.x * zoom - size.width / 2)),
                y: min(maxY, max(0, point.y * zoom - size.height * 0.45))
            )
        }

        func move(to request: MapCameraRequest) {
            guard let scroll = scrollView else { return }
            // Pri prvnim zobrazeni jeste nemusi mit rozmer: zkusi to znovu po rozlozeni.
            guard scroll.bounds.width > 0 else {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(60))
                    self.move(to: request)
                }
                return
            }
            let clamp = { (zoom: CGFloat) in min(scroll.maximumZoomScale, max(scroll.minimumZoomScale, zoom)) }
            let target = clamp(request.zoom)
            let size = scroll.bounds.size
            if let start = request.startZoom, request.animated {
                let from = clamp(start)
                scroll.setZoomScale(from, animated: false)
                scroll.setContentOffset(offset(centering: request.point, zoom: from, in: size), animated: false)
            }
            let destination = offset(centering: request.point, zoom: target, in: size)
            guard request.animated else {
                scroll.setZoomScale(target, animated: false)
                scroll.setContentOffset(destination, animated: false)
                return
            }
            UIView.animate(withDuration: 0.9, delay: 0.05, options: [.curveEaseInOut, .allowUserInteraction]) {
                scroll.zoomScale = target
                scroll.contentOffset = destination
            }
        }
    }
}
