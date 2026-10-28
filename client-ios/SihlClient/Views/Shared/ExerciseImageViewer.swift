import SwiftUI
import UIKit

// MARK: - ExerciseImagePreview

/// Grosses Übungsbild in der aufgeklappten Übungskarte. Ein Tipp öffnet das
/// Vollbild mit Zoom — damit sich Haltung und Ausführung genau betrachten
/// lassen. Das Bild lädt die Karte (`ExerciseTile`) und reicht es herein;
/// das Vollbild präsentiert die Plan-Ansicht (`onOpen`), damit es ein
/// Neuladen des Plans übersteht.
struct ExerciseImagePreview: View {
    let image: UIImage
    let exerciseName: String
    let accent: Color
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 280)
                .background(accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    Label("Vergrössern", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.app(11, weight: .semibold))
                        .foregroundStyle(AppColor.text)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(10)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Übungsbild \(exerciseName)")
        .accessibilityHint("Öffnet das Bild im Vollbild zum Vergrössern")
    }
}

/// Was das Vollbild zeigt — als Wert, damit ein Neuladen des Plans das
/// offene Bild nicht austauscht.
struct ExerciseImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let title: String
}

// MARK: - ExerciseImageViewer

/// Vollbild-Betrachter auf Basis der nativen Zoom-Ansicht (UIScrollView):
/// Pinch-Zoom 1–4× mit Federung an den Grenzen, Verschieben nur bis zum
/// Bildrand, Doppeltipp zoomt auf die getippte Stelle bzw. zurück.
/// Schliessen über das X, mit einem Wisch nach unten (in der Übersicht;
/// das Bild folgt dem Finger) oder der VoiceOver-Geste „Zurück".
struct ExerciseImageViewer: View {
    let image: UIImage
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var zoom = ZoomController()
    @State private var isZoomed = false
    /// 0…1 während des Wischens nach unten — blendet den Hintergrund aus
    @State private var dismissProgress: CGFloat = 0

    var body: some View {
        ZStack {
            AppColor.black
                .opacity(1 - dismissProgress * 0.7)
                .ignoresSafeArea()

            ZoomableImage(image: image, controller: zoom,
                          onZoomChange: { isZoomed = $0 },
                          onDismissProgress: { dismissProgress = min($0, 1) },
                          onDismiss: { dismiss() })
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel("Übungsbild \(title)")
                .accessibilityAddTraits(.isImage)
                .accessibilityZoomAction { action in
                    switch action.direction {
                    case .zoomIn:  zoom.step(by: 1.5)
                    case .zoomOut: zoom.step(by: 1 / 1.5)
                    @unknown default: break
                    }
                }

            VStack(spacing: 0) {
                header
                Spacer()
                Text("Zum Zoomen zwei Finger spreizen oder doppeltippen")
                    .font(.app(11))
                    .foregroundStyle(AppColor.white.opacity(0.75))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(AppColor.black.opacity(0.45), in: Capsule())
                    .padding(.bottom, 16)
                    .opacity(isZoomed ? 0 : 1)
                    .accessibilityHidden(true)
            }
            .opacity(1 - dismissProgress)
        }
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .accessibilityAction(.escape) { dismiss() }
    }

    /// Titel und Schliessen auf einem Verlauf — lesbar auch auf hellen Bildern
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.app(15, weight: .semibold))
                .foregroundStyle(AppColor.white)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.white)
                    .frame(width: 40, height: 40)
                    .background(AppColor.white.opacity(0.18), in: Circle())
            }
            .accessibilityLabel("Schliessen")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .background(
            LinearGradient(colors: [AppColor.black.opacity(0.75), AppColor.black.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - ZoomController

/// Brücke für Zoom-Befehle aus SwiftUI (VoiceOver) in die UIKit-Ansicht.
@MainActor
final class ZoomController {
    fileprivate weak var scrollView: ZoomingScrollView?

    func step(by factor: CGFloat) {
        guard let sv = scrollView else { return }
        let target = min(max(sv.zoomScale * factor, sv.minimumZoomScale), sv.maximumZoomScale)
        sv.setZoomScale(target, animated: true)
    }
}

// MARK: - ZoomableImage

private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    let controller: ZoomController
    let onZoomChange: (Bool) -> Void
    let onDismissProgress: (CGFloat) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> ZoomingScrollView {
        let sv = ZoomingScrollView(image: image)
        sv.delegate = context.coordinator
        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        sv.addGestureRecognizer(doubleTap)
        controller.scrollView = sv
        return sv
    }

    func updateUIView(_ sv: ZoomingScrollView, context: Context) {
        context.coordinator.parent = self
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableImage
        /// Pinch in der laufenden Geste — dann nie schliessen, auch wenn
        /// die Finger dabei nach unten wandern
        private var pinchedDuringGesture = false
        private var reportedZoomed = false
        private let dismissDistance: CGFloat = 110

        init(_ parent: ZoomableImage) { self.parent = parent }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomingScrollView)?.imageView
        }

        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            pinchedDuringGesture = true
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? ZoomingScrollView)?.centerContent()
            let zoomed = scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
            if zoomed != reportedZoomed {
                reportedZoomed = zoomed
                parent.onZoomChange(zoomed)
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let atOverview = scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01
            parent.onDismissProgress(atOverview ? pullDown(scrollView) / (dismissDistance * 2) : 0)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            if !scrollView.isZooming { pinchedDuringGesture = false }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            defer { pinchedDuringGesture = false }
            let atOverview = scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01
            let pinchState = scrollView.pinchGestureRecognizer?.state
            let pinching = scrollView.isZooming || pinchState == .began || pinchState == .changed
            if atOverview, !pinchedDuringGesture, !pinching, pullDown(scrollView) > dismissDistance {
                parent.onDismiss()
            }
        }

        /// Wie weit das Bild über den oberen Rand hinaus nach unten gezogen ist
        private func pullDown(_ scrollView: UIScrollView) -> CGFloat {
            max(0, -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top))
        }

        @objc func doubleTapped(_ g: UITapGestureRecognizer) {
            guard let sv = g.view as? ZoomingScrollView else { return }
            if sv.zoomScale > sv.minimumZoomScale + 0.01 {
                sv.setZoomScale(sv.minimumZoomScale, animated: true)
            } else {
                // Auf die getippte Stelle zoomen
                let target: CGFloat = 2.5
                let p = g.location(in: sv.imageView)
                let w = sv.bounds.width / target, h = sv.bounds.height / target
                sv.zoom(to: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h), animated: true)
            }
        }
    }
}

// MARK: - ZoomingScrollView

/// Scroll-Ansicht mit eingepasstem Bild: Inhaltsgrösse = eingepasste
/// Bildgrösse, darum enden Verschieben und Zoomen genau am Bildrand —
/// auch nach dem Herauszoomen. Kleiner als der Rahmen wird zentriert.
final class ZoomingScrollView: UIScrollView {
    let imageView: UIImageView
    private var laidOutSize: CGSize = .zero

    init(image: UIImage) {
        imageView = UIImageView(image: image)
        super.init(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        minimumZoomScale = 1
        maximumZoomScale = 4
        bouncesZoom = true
        alwaysBounceVertical = true          // Wisch nach unten zum Schliessen
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht verwendet") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize, bounds.width > 0, bounds.height > 0 else { return }
        laidOutSize = bounds.size
        // Neu einpassen (erstes Layout, Drehung) — in der Übersicht
        zoomScale = 1
        let size = imageView.image?.size ?? bounds.size
        let fit = min(bounds.width / max(size.width, 1), bounds.height / max(size.height, 1))
        let fitted = CGSize(width: size.width * fit, height: size.height * fit)
        imageView.frame = CGRect(origin: .zero, size: fitted)
        contentSize = fitted
        centerContent()
        // Ruhelage zum zentrierenden Rand — sonst sässe das Bild oben
        contentOffset = CGPoint(x: -contentInset.left, y: -contentInset.top)
    }

    /// Bild mittig halten, solange es kleiner als der Rahmen ist
    func centerContent() {
        let dx = max(0, (bounds.width  - contentSize.width)  / 2)
        let dy = max(0, (bounds.height - contentSize.height) / 2)
        contentInset = UIEdgeInsets(top: dy, left: dx, bottom: dy, right: dx)
    }
}
