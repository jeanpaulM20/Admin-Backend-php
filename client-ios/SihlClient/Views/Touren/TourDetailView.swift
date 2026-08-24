import SwiftUI
import MapKit

// MARK: - TourDetailView (T1/T4: Route, Stats, GPX-Export, Tour starten)

/// Zeigt eine Route: aus OSM (per Tour-ID nachgeladen), aus dem
/// Rundtouren-Generator oder aus einer GPX-Datei (bereits geladen).
struct TourDetailView: View {
    @Environment(AuthViewModel.self) private var auth

    let title: String
    private let tourId: String?

    @State private var detail: TourDetail?
    @State private var isLoading: Bool
    @State private var error: String?
    @State private var showRecord = false
    @State private var gpxURL: URL?

    /// OSM-Tour aus der Discovery (Detail wird nachgeladen).
    init(tour: Tour) {
        self.title = tour.name
        self.tourId = tour.id
        _detail = State(initialValue: nil)
        _isLoading = State(initialValue: true)
    }

    /// Bereits geladene Route (Rundtouren-Generator, GPX-Import).
    init(detail: TourDetail) {
        self.title = detail.name
        self.tourId = nil
        _detail = State(initialValue: detail)
        _isLoading = State(initialValue: false)
    }

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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // GPX-Export (T4) — sobald die Geometrie da ist
            if let url = gpxURL {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.callout)
                            .foregroundStyle(AppColor.muted)
                    }
                }
            }
        }
        .task {
            load()
        }
        .onChange(of: detail?.id) { _, _ in prepareGPX() }
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
                .padding(.top, AppSpacing.stack)

                // Kennzahlen
                HStack(spacing: AppSpacing.stack) {
                    if let km = d.distanceKm {
                        stat("Distanz",
                             km < 1 ? "\(Int((km * 1000).rounded()))" : String(format: "%.1f", km),
                             km < 1 ? "m" : "km")
                    }
                    if let min = d.durationMin {
                        stat("Dauer ca.", TourDiscoveryView.formatDuration(min), "")
                    }
                    if let gain = d.elevationGain {
                        stat("Höhenmeter", "\(gain)", "m")
                    } else if let diff = d.difficulty {
                        stat("Schwierigkeit", diff, "")
                    }
                }
                if d.elevationGain != nil, let diff = d.difficulty {
                    HStack(spacing: 8) {
                        Image(systemName: tourActivityIcon(d.activity))
                            .font(.footnote).foregroundStyle(AppColor.muted)
                        Text("Schwierigkeit: \(diff)")
                            .font(.footnote).foregroundStyle(AppColor.muted)
                    }
                }

                // Herkunft/Netzwerk
                if d.networkLabel != nil || d.operatorName != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "signpost.right")
                            .font(.footnote)
                            .foregroundStyle(AppColor.brass)
                        Text([d.networkLabel, d.operatorName]
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

                Text("\(d.durationMin != nil && d.elevationGain == nil ? "Die Dauer ist eine Schätzung ohne Höhenmeter. " : "")Routendaten: © OpenStreetMap-Mitwirkende (ODbL).")
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
        .padding(.vertical, AppSpacing.card)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private func load() {
        // Bereits geladen (Generator/GPX) → nur GPX-Export vorbereiten
        guard detail == nil else { prepareGPX(); return }
        guard let tourId else { return }
        error = nil
        isLoading = true
        if isDemo {
            detail = TourService.demoDetail(tourId)
            isLoading = false
            prepareGPX()
            return
        }
        guard let clientId = auth.clientId else { return }
        Task {
            do {
                detail = try await TourService.shared.detail(clientId: clientId, tourId: tourId)
                if detail == nil { error = "Route konnte nicht geladen werden." }
            } catch {
                self.error = "Route konnte nicht geladen werden."
            }
            isLoading = false
            prepareGPX()
        }
    }

    private func prepareGPX() {
        guard let d = detail, !d.segments.isEmpty else { return }
        gpxURL = GPXFile.write(name: d.name, segments: d.segments, elevations: d.elevations)
    }
}
