import SwiftUI

// MARK: - ExerciseImagePreview

/// Grosses Übungsbild in der aufgeklappten Übungskarte. Ein Tipp öffnet das
/// Vollbild mit Zoom — damit sich Haltung und Ausführung genau betrachten
/// lassen. Ohne geladenes Bild zeigt die Karte nichts (kein leerer Rahmen).
struct ExerciseImagePreview: View {
    let exerciseId: Int
    let exerciseName: String
    let accent: Color

    @Environment(AuthViewModel.self) private var auth
    @State private var image: UIImage?
    @State private var showViewer = false

    private var urlString: String { ExerciseBadge.imageURL(exerciseId: exerciseId) }

    var body: some View {
        Group {
            if let image {
                Button { showViewer = true } label: {
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
                .accessibilityLabel("Übungsbild \(exerciseName) vergrössern")
                .fullScreenCover(isPresented: $showViewer) {
                    ExerciseImageViewer(image: image, title: exerciseName)
                }
            }
        }
        .task(id: urlString) {
            image = await TokenImageStore.shared.image(for: urlString, token: auth.token)
        }
    }
}

// MARK: - ExerciseImageViewer

/// Vollbild-Betrachter: Pinch-Zoom (1–4×), Verschieben im gezoomten Zustand,
/// Doppeltipp wechselt zwischen Übersicht und 2,5×. Schliessen über das X
/// oder — in der Übersicht — mit einem Wisch nach unten.
struct ExerciseImageViewer: View {
    let image: UIImage
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    private var effectiveScale: CGFloat { min(max(scale * pinch, minScale * 0.7), maxScale * 1.3) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(effectiveScale)
                    .offset(x: offset.width + drag.width, y: offset.height + drag.height)
                    .gesture(zoomGesture.simultaneously(with: panGesture(in: geo.size)))
                    .onTapGesture(count: 2) { toggleZoom() }
                    .accessibilityLabel("Übungsbild \(title)")
                    .accessibilityAddTraits(.isImage)

                VStack {
                    HStack {
                        Text(title)
                            .font(.app(15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.app(15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(0.15), in: Circle())
                        }
                        .accessibilityLabel("Schliessen")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    Spacer()
                    Text("Zum Zoomen zwei Finger spreizen · Doppeltipp")
                        .font(.app(11))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 12)
                        .opacity(scale == 1 ? 1 : 0)
                }
            }
        }
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                withAnimation(.easeOut(duration: 0.2)) {
                    scale = min(max(scale * value.magnification, minScale), maxScale)
                    if scale == minScale { offset = .zero }
                }
            }
    }

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($drag) { value, state, _ in
                if scale > minScale { state = value.translation }
            }
            .onEnded { value in
                if scale > minScale {
                    // Im Zoom: verschieben, aber nicht aus dem Bild hinaus
                    let limitX = size.width  * (scale - 1) / 2
                    let limitY = size.height * (scale - 1) / 2
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = CGSize(
                            width:  min(max(offset.width  + value.translation.width,  -limitX), limitX),
                            height: min(max(offset.height + value.translation.height, -limitY), limitY))
                    }
                } else if value.translation.height > 90 {
                    // Übersicht: Wisch nach unten schliesst
                    dismiss()
                }
            }
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if scale > minScale { scale = minScale; offset = .zero } else { scale = 2.5 }
        }
    }
}
