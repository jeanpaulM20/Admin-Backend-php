import SwiftUI
import MapKit

// MARK: - TourDetailView (T1: Route, Stats, Einstieg in die Aufzeichnung)

struct TourDetailView: View {
    @Environment(AuthViewModel.self) private var auth
    let tour: Tour

    @State private var detail: TourDetail?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showRecord = false

    private var isDemo: Bool { auth.clientId == "demo" }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            if isLoading {
                LoadingView(message: "Lade Route…")
            } else if let error {
                ErrorStateView(message: error) { load() }
            } else if let detail {
                content(detail)
            }
        }
        .navigationTitle(tour.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .navigationDestination(isPresented: $showRecord) {
            // T3: Route in den Recorder übergeben (Overlay + Off-Route-Hinweis)
            RecordWorkoutView(tour: detail?.asRoute)
        }
    }

    private func content(_ d: TourDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {

                // Karte mit allen Routen-Segmenten
                Map {
                    ForEach(d.segments.indices, id: \.self) { i in
                        MapPolyline(coordinates: d.segments[i])
                            .stroke(AppColor.cta, lineWidth: 3)
                    }
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .allowsHitTesting(false)
                .padding(.top, 12)

                // Kennzahlen
                HStack(spacing: AppSpacing.stack) {
                    if let km = d.distanceKm {
                        stat("Distanz", String(format: "%.1f", km), "km")
                    }
                    if let min = d.durationMin {
                        stat("Dauer ca.", TourDiscoveryView.formatDuration(min), "")
                    }
                    if let diff = d.difficulty {
                        stat("Schwierigkeit", diff, "")
                    }
                }

                // Herkunft/Netzwerk
                if tour.networkLabel != nil || d.operatorName != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "signpost.right")
                            .font(.footnote)
                            .foregroundStyle(AppColor.brass)
                        Text([tour.networkLabel, d.operatorName]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(AppColor.muted)
                    }
                }

                if let desc = d.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.text)
                        .padding(AppSpacing.card)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
                }

                Button("Tour starten") { showRecord = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)

                Text("Die Dauer ist eine Schätzung ohne Höhenmeter. Routendaten: © OpenStreetMap-Mitwirkende (ODbL).")
                    .font(.caption2)
                    .foregroundStyle(AppColor.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
    }

    private func stat(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(AppColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !unit.isEmpty {
                Text(unit).font(.caption2).foregroundStyle(AppColor.muted)
            }
            Text(label).font(.caption2).foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private func load() {
        error = nil
        isLoading = true
        if isDemo {
            detail = TourService.demoDetail(tour.id)
            isLoading = false
            return
        }
        guard let clientId = auth.clientId else { return }
        Task {
            do {
                detail = try await TourService.shared.detail(clientId: clientId, tourId: tour.id)
                if detail == nil { error = "Route konnte nicht geladen werden." }
            } catch {
                self.error = "Route konnte nicht geladen werden."
            }
            isLoading = false
        }
    }
}
