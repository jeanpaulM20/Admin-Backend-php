import SwiftUI
import MapKit

// MARK: - RouteFullscreenView

/// Vollbild-Karte einer aufgezeichneten Route — frei zoom- und
/// verschiebbar. Genutzt von der Trainings-Zusammenfassung und dem
/// Analytics-Detail (die Inline-Karten bleiben statisch, damit die
/// Kartengesten nicht mit dem Seiten-Scrollen kollidieren).
struct RouteFullscreenView: View {
    @Environment(\.dismiss) private var dismiss

    /// Geplante Tour-Route (gestrichelt hinter der gelaufenen Linie).
    var plannedSegments: [[CLLocationCoordinate2D]] = []
    /// Aufgezeichnete Route.
    let coordinates: [CLLocationCoordinate2D]

    /// Start und Ziel liegen (fast) aufeinander → Rundkurs.
    private var routeEndsMeet: Bool {
        guard let a = coordinates.first, let b = coordinates.last else { return true }
        return CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) < 50
    }

    var body: some View {
        ZStack {
            Map {
                ForEach(plannedSegments.indices, id: \.self) { i in
                    MapPolyline(coordinates: plannedSegments[i])
                        .stroke(AppColor.blue.opacity(0.85),
                                style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                }
                MapPolyline(coordinates: coordinates)
                    .stroke(AppColor.track, lineWidth: 4)
                if let start = coordinates.first {
                    Annotation(routeEndsMeet ? "Start/Ziel" : "Start", coordinate: start) { marker }
                }
                if !routeEndsMeet, let end = coordinates.last {
                    Annotation("Ziel", coordinate: end) { marker }
                }
            }
            .mapStyle(.standard)
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.app(15, weight: .semibold))
                            .foregroundStyle(AppColor.muted)
                            .frame(width: 40, height: 40)
                            .background(AppColor.surface, in: Circle())
                            .overlay(Circle().stroke(AppColor.border, lineWidth: 1))
                    }
                    .accessibilityLabel("Vollbild schliessen")
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, AppSpacing.stack)
                Spacer()
            }
        }
    }

    private var marker: some View {
        Circle()
            .fill(AppColor.track)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(AppColor.white, lineWidth: 2))
    }
}
