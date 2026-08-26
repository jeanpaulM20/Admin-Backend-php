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
    @State private var showMapFullscreen = false

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
        .fullScreenCover(isPresented: $showMapFullscreen) {
            if let detail {
                TourMapFullscreenView(detail: detail)
            }
        }
    }

    private func content(_ d: TourDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {

                // Karte mit allen Routen-Segmenten — statisch (sonst
                // kollidieren Karten-Gesten mit dem Seiten-Scrollen);
                // Tap oder Button öffnet die interaktive Vollbild-Ansicht
                Map {
                    ForEach(d.segments.indices, id: \.self) { i in
                        MapPolyline(coordinates: d.segments[i])
                            .stroke(AppColor.track, lineWidth: 3)
                    }
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .allowsHitTesting(false)
                .overlay(alignment: .topTrailing) {
                    Button {
                        showMapFullscreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.app(14, weight: .semibold))
                            .foregroundStyle(AppColor.muted)
                            .frame(width: 40, height: 40)
                            .background(AppColor.surface, in: Circle())
                            .overlay(Circle().stroke(AppColor.border, lineWidth: 1))
                    }
                    .padding(10)
                    .accessibilityLabel("Karte im Vollbild ansehen")
                }
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .onTapGesture { showMapFullscreen = true }
                .padding(.top, AppSpacing.stack)

                // Kennzahlen
                HStack(spacing: AppSpacing.stack) {
                    if let km = d.distanceKm {
                        stat("Distanz",
                             km < 1 ? "\(Int((km * 1000).rounded()))" : String(format: "%.1f", km),
                             km < 1 ? "m" : "km")
                    }
                    if let min = d.durationMin {
                        stat("Dauer ca.", TourFormat.duration(min), "")
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

                // Fakten — offizielle Stadt-Zürich-Angaben haben Vorrang vor OSM
                if let belag = d.official?.belag {
                    factRow("road.lanes", "Belag: \(belag)")
                } else if let surface = Self.surfaceLabel(d.surface) {
                    factRow("road.lanes", "Belag: \(surface)")
                }
                if let licht = d.official?.beleuchtung {
                    factRow("lightbulb", "Beleuchtung: \(licht)")
                } else if d.lit == true {
                    // Ohne Schaltzeiten aus OSM kein Zeitversprechen (viele
                    // Anlagen schalten z. B. um 22 Uhr ab)
                    factRow("lightbulb", "Beleuchtet")
                }
                if let km = d.distanceKm, km > 0, km < 1 {
                    factRow("arrow.triangle.2.circlepath",
                            "1 km ≈ \(Self.roundsLabel(1.0 / km)) Runden")
                }
                if let info = d.official?.gelaendeinfo {
                    factRow("ruler", info)
                }
                if let garderobe = d.official?.garderobe {
                    factRow("tshirt", "Garderobe: \(garderobe)")
                }
                if let kontakt = d.official?.kontakt {
                    factRow("phone", kontakt)
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

                Text("\(d.durationMin != nil && d.elevationGain == nil ? "Die Dauer ist eine Schätzung ohne Höhenmeter. " : "")Routendaten: © OpenStreetMap-Mitwirkende (ODbL).\(d.official != nil ? " Anlagen-Infos: Stadt Zürich (Open Data)." : "")")
                    .font(.caption2)
                    .foregroundStyle(AppColor.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
    }

    private func factRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(AppColor.muted)
            Text(text)
                .font(.footnote)
                .foregroundStyle(AppColor.muted)
        }
    }

    /// Runden pro Kilometer: ganzzahlig, wenn es (fast) aufgeht, sonst eine
    /// Dezimalstelle (400-m-Bahn → "2.5", 330-m-Bahn → "3").
    static func roundsLabel(_ rounds: Double) -> String {
        abs(rounds - rounds.rounded()) < 0.15
            ? "\(Int(rounds.rounded()))"
            : String(format: "%.1f", rounds)
    }

    /// OSM-surface → deutsche Bezeichnung (nur bekannte Werte, sonst nichts).
    static func surfaceLabel(_ surface: String?) -> String? {
        switch surface {
        case "woodchips":            return "Holzschnitzel/Sägemehl (gelenkschonend)"
        case "wood":                 return "Holz"
        case "fine_gravel":          return "Feinkies"
        case "gravel":               return "Kies"
        case "asphalt":              return "Asphalt"
        case "ground", "dirt", "earth": return "Naturweg"
        case "grass":                return "Rasen"
        case "compacted":            return "befestigter Weg"
        default:                     return nil
        }
    }

    private func stat(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.app(16, weight: .black))
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

// MARK: - TourMapFullscreenView

/// Interaktive Vollbild-Karte der Route — zum Erkunden vor dem Start
/// (zoomen, verschieben), mit Start-/Ziel-Markern und Kennzahlen-Pille.
private struct TourMapFullscreenView: View {
    @Environment(\.dismiss) private var dismiss
    let detail: TourDetail

    /// Start und Ziel liegen (fast) aufeinander → Rundtour.
    private var routeEndsMeet: Bool {
        guard let a = detail.segments.first?.first,
              let b = detail.segments.last?.last else { return true }
        return CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) < 50
    }

    var body: some View {
        ZStack {
            Map {
                ForEach(detail.segments.indices, id: \.self) { i in
                    MapPolyline(coordinates: detail.segments[i])
                        .stroke(AppColor.track, lineWidth: 4)
                }
                if let start = detail.segments.first?.first {
                    Annotation(routeEndsMeet ? "Start/Ziel" : "Start", coordinate: start) { flag }
                }
                if !routeEndsMeet, let end = detail.segments.last?.last {
                    Annotation("Ziel", coordinate: end) { flag }
                }
            }
            .mapStyle(.standard)
            .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    // Kennzahlen-Pille
                    HStack(spacing: 8) {
                        Text(detail.name)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppColor.text)
                            .lineLimit(1)
                        if let km = detail.distanceKm {
                            Text("·").foregroundStyle(AppColor.muted)
                            Text(TourFormat.distance(km))
                                .font(.footnote)
                                .foregroundStyle(AppColor.muted)
                        }
                        if let gain = detail.elevationGain {
                            Text("·").foregroundStyle(AppColor.muted)
                            Text("\(gain) m")
                                .font(.footnote)
                                .foregroundStyle(AppColor.muted)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppColor.surface.opacity(0.95), in: Capsule())
                    .overlay(Capsule().stroke(AppColor.border, lineWidth: 1))

                    Spacer(minLength: 8)

                    Button { dismiss() } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.app(14, weight: .semibold))
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

    private var flag: some View {
        Image(systemName: "flag.fill")
            .font(.app(11, weight: .semibold))
            .foregroundStyle(AppColor.white)
            .frame(width: 24, height: 24)
            .background(AppColor.blue, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
    }
}
