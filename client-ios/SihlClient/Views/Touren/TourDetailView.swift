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
                            .stroke(AppColor.track, lineWidth: 3)
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

                // Fakten aus OSM + berechnet
                if let surface = Self.surfaceLabel(d.surface) {
                    factRow("road.lanes", "Belag: \(surface)")
                }
                if d.lit == true {
                    factRow("lightbulb", "Beleuchtet — auch früh und spät nutzbar")
                }
                if let km = d.distanceKm, km > 0, km < 1 {
                    factRow("arrow.triangle.2.circlepath",
                            "1 km ≈ \(Self.roundsLabel(1.0 / km)) Runden")
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

                // Wissenswertes zum Routentyp
                if let fact = Self.funFact(d.activity) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WISSENSWERTES")
                            .font(.caption2.weight(.bold))
                            .kerning(1)
                            .foregroundStyle(AppColor.brass)
                        Text(fact)
                            .font(.footnote)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(3)
                    }
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
        case "woodchips":            return "Holzschnitzel (gelenkschonend)"
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

    /// Kurzes Wissenswertes je Routentyp — allgemeine, belegbare Fakten.
    static func funFact(_ activity: String) -> String? {
        switch TourActivity(backendValue: activity) {
        case .finnenbahn:
            return "Finnenbahnen stammen — der Name verrät es — aus Finnland: Der weiche Holzschnitzel-Belag federt jeden Schritt und schont Gelenke und Sehnen. Ideal für Tempoläufe, Lauf-ABC und lockere regenerative Runden."
        case .vitaparcours:
            return "Vitaparcours sind ein Schweizer Original: Rundkurse mit Übungsposten für Kraft, Beweglichkeit und Ausdauer — kostenlos, ganzjährig offen und von der Stiftung Vitaparcours unterhalten."
        case .joggen:
            return "Markierte Laufstrecken wie die Helsana Trails sind ausgeschildert und meist in mehreren Längen angelegt — verlässliche Standardrunden, auch gut für Intervalle."
        case .wandern:
            return "Schweizer Wanderwege sind einheitlich gelb signalisiert. Die angegebene Dauer folgt der SAC-Formel aus Distanz und Höhenmetern — dein persönliches Tempo kann abweichen."
        case .rennrad:
            return "Nationale und regionale Velorouten (SchweizMobil) sind durchgehend signalisiert — die rot-weissen Tafeln tragen die Routennummer."
        case .mtb:
            return "Mountainbike-Routen von SchweizMobil sind signalisiert. Trails teilen sich den Weg oft mit Wandernden — Rücksicht und Bremsbereitschaft gehören dazu."
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
