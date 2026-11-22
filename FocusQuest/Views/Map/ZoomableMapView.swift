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

/// Kam se mapa prave diva (posun a zoom scroll view). Ctou ho jen popisky svetu nad mapou,
/// takze posun mapy neprekresluje celou zalozku.
@MainActor
@Observable
final class MapViewport {
    var offset: CGPoint = .zero
    var zoom: CGFloat = 1
    var size: CGSize = .zero

    /// Bod mapy -> bod obrazovky.
    func screenPoint(of point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * zoom - offset.x, y: point.y * zoom - offset.y)
    }
}

/// Mapa v nativnim UIScrollView: posun tazenim se setrvacnosti, pinch-zoom a pruzne okraje
/// v plnych 60 fps. Obsah je SwiftUI v UIHostingController (zastavky jsou normalni tlacitka
/// s VoiceOver popisky), ktery je radnym potomkem kontroleru mapy, aby se gesta mapy
/// nepletla s tlacitky nad ni. Zoom zvetsuje vrstvy transformaci, pixelovy teren zustava ostry.
///
/// `insets` = hlavicka nahore a tab bar dole: mapa pod nimi pokracuje (je videt pod sklem),
/// ale jde odrolovat tak, aby nic dulezite pod nimi nezustalo, a kamera centruje do viditelne casti.
struct ZoomableMapView<Content: View>: UIViewControllerRepresentable {
    let contentSize: CGSize
    var minZoom: CGFloat = 0.5
    var maxZoom: CGFloat = 1.6
    var insets: UIEdgeInsets = .zero
    var camera: MapCameraRequest?
    var viewport: MapViewport?
    @ViewBuilder var content: () -> Content

    func makeUIViewController(context: Context) -> MapScrollController<Content> {
        let controller = MapScrollController(rootView: content(), contentSize: contentSize)
        controller.scroll.minimumZoomScale = minZoom
        controller.scroll.maximumZoomScale = maxZoom
        controller.viewport = viewport
        controller.apply(insets: insets)
        return controller
    }

    func updateUIViewController(_ controller: MapScrollController<Content>, context: Context) {
        controller.hosting.rootView = content()
        controller.viewport = viewport
        controller.apply(insets: insets)
        guard let camera, camera.token != controller.lastToken else { return }
        controller.lastToken = camera.token
        Task { @MainActor in controller.move(to: camera) }
    }
}

/// Kontroler mapy: UIScrollView a v nem hosting controller s obsahem mapy jako potomek.
@MainActor
final class MapScrollController<Content: View>: UIViewController, UIScrollViewDelegate {
    let scroll = UIScrollView()
    let hosting: UIHostingController<Content>
    let contentSize: CGSize
    weak var viewport: MapViewport?
    var lastToken = -1

    init(rootView: Content, contentSize: CGSize) {
        hosting = UIHostingController(rootView: rootView)
        self.contentSize = contentSize
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        scroll.delegate = self
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.decelerationRate = .normal
        scroll.backgroundColor = .clear
        view = scroll

        addChild(hosting)
        let hostView = hosting.view!
        hostView.backgroundColor = .clear
        // Mapa je vzdy nocni pixel-art: tokeny barev musi byt v tmavem rezimu i uvnitr UIKitu.
        hosting.overrideUserInterfaceStyle = .dark
        if #available(iOS 16.4, *) { hosting.safeAreaRegions = [] }
        hostView.frame = CGRect(origin: .zero, size: contentSize)
        scroll.addSubview(hostView)
        hosting.didMove(toParent: self)
        scroll.contentSize = contentSize
        scroll.zoomScale = 1
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        publishViewport()
    }

    func apply(insets: UIEdgeInsets) {
        guard scroll.contentInset != insets else { return }
        scroll.contentInset = insets
        publishViewport()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { hosting.view }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { publishViewport() }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { publishViewport() }

    private func publishViewport() {
        guard let viewport else { return }
        let offset = scroll.contentOffset, zoom = scroll.zoomScale, size = scroll.bounds.size
        if viewport.offset != offset { viewport.offset = offset }
        if viewport.zoom != zoom { viewport.zoom = zoom }
        if viewport.size != size { viewport.size = size }
    }

    /// Bod mapy doprostred viditelne casti (mezi hlavickou a tab barem), v mezich, kam mapa jde odrolovat.
    private func offset(centering point: CGPoint, zoom: CGFloat) -> CGPoint {
        let size = scroll.bounds.size
        let inset = scroll.contentInset
        let visibleHeight = max(1, size.height - inset.top - inset.bottom)
        let minX = -inset.left, maxX = max(minX, contentSize.width * zoom - size.width + inset.right)
        let minY = -inset.top, maxY = max(minY, contentSize.height * zoom - size.height + inset.bottom)
        return CGPoint(
            x: min(maxX, max(minX, point.x * zoom - size.width / 2)),
            y: min(maxY, max(minY, point.y * zoom - inset.top - visibleHeight * 0.5))
        )
    }

    func move(to request: MapCameraRequest) {
        // Pri prvnim zobrazeni jeste nemusi mit rozmer: zkusi to znovu po rozlozeni.
        guard scroll.bounds.width > 0 else {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                self.move(to: request)
            }
            return
        }
        let clamp = { (zoom: CGFloat) in min(self.scroll.maximumZoomScale, max(self.scroll.minimumZoomScale, zoom)) }
        let target = clamp(request.zoom)
        if let start = request.startZoom, request.animated {
            let from = clamp(start)
            scroll.setZoomScale(from, animated: false)
            scroll.setContentOffset(offset(centering: request.point, zoom: from), animated: false)
        }
        let destination = offset(centering: request.point, zoom: target)
        guard request.animated else {
            scroll.setZoomScale(target, animated: false)
            scroll.setContentOffset(destination, animated: false)
            return
        }
        UIView.animate(withDuration: 0.9, delay: 0.05, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.scroll.zoomScale = target
            self.scroll.contentOffset = destination
        }
    }
}
