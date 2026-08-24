import SwiftUI
import MapKit
import UniformTypeIdentifiers

// MARK: - TourDiscoveryView (T1: markierte OSM-Routen entdecken)

/// Komoot-inspirierte Touren-Suche: Karte + Orts-Suche + Aktivität/Radius,
/// Tour-Karten unten. Datenquelle: OpenStreetMap via Backend-Proxy.
struct TourDiscoveryView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var activity: TourActivity = .wandern
    @State private var radiusKm: Double = 10
    @State private var searchText = ""
    @State private var center = CLLocationCoordinate2D(latitude: 47.37, longitude: 8.54) // Zürich
    @State private var cameraCenter: CLLocationCoordinate2D?
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 47.37, longitude: 8.54),
                           span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)))

    @State private var tours: [Tour] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var detailTour: Tour?
    @State private var showPlanSheet = false
    @State private var generatedDetail: TourDetail?
    @State private var showImporter = false
    @State private var searchModel = LocationSearchModel()
    @FocusState private var searchFocused: Bool

    private var isDemo: Bool { auth.clientId == "demo" }

    var body: some View {
        ZStack(alignment: .top) {
            map

            // Kopfzeile: Suche + Filter
            VStack(spacing: AppSpacing.stack) {
                HStack(spacing: AppSpacing.stack) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.callout)
                            .foregroundStyle(AppColor.muted)
                        TextField("Ort suchen…", text: $searchText)
                            .font(.subheadline)
                            .foregroundStyle(AppColor.text)
                            .submitLabel(.search)
                            .focused($searchFocused)
                            .onSubmit { searchLocation() }
                            .onChange(of: searchText) { _, text in
                                searchModel.update(query: text, near: cameraCenter ?? center)
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColor.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColor.border, lineWidth: 1))

                    // Rundtouren-Generator (T4) — der eine CTA dieses Screens
                    Button {
                        showPlanSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill").font(.callout)
                            Text("Rundtour").font(.subheadline.bold())
                        }
                        .foregroundStyle(AppColor.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppColor.cta)
                        .clipShape(Capsule())
                    }
                }

                // Live-Ortsvorschläge während des Tippens
                if searchFocused && !searchModel.suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(searchModel.suggestions) { s in
                            suggestionRow(s)
                            if s.id != searchModel.suggestions.last?.id {
                                Divider().overlay(AppColor.border)
                            }
                        }
                    }
                    .background(AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                        .stroke(AppColor.border, lineWidth: 1))
                }

                // Aktivität (scrollbar — sechs Routentypen)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TourActivity.allCases) { a in
                            activityChip(a)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screen)
                }
                .padding(.horizontal, -AppSpacing.screen)

                HStack(spacing: AppSpacing.stack) {
                    // Radius (Chevron zeigt das Menü-Angebot an)
                    Menu {
                        ForEach([5.0, 10, 25], id: \.self) { r in
                            Button("in \(Int(r)) km Umkreis") { radiusKm = r; reload() }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "scope").font(.caption)
                            Text("\(Int(radiusKm)) km").font(.footnote.weight(.medium))
                            Image(systemName: "chevron.down").font(.app(9, weight: .semibold))
                        }
                        .foregroundStyle(AppColor.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColor.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColor.border, lineWidth: 1))
                    }

                    Spacer()

                    // In diesem Gebiet suchen (Kartenmitte übernehmen) — ruhiger
                    // Kontext-Chip, kein zweiter CTA (Ein-CTA-Prinzip)
                    Button {
                        if let c = cameraCenter { center = c }
                        reload()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise").font(.caption)
                            Text("Hier suchen").font(.footnote.weight(.medium))
                        }
                        .foregroundStyle(AppColor.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColor.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColor.border, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, AppSpacing.stack)

            // Tour-Karten unten
            VStack {
                Spacer()
                bottomCards
            }
        }
        .navigationTitle("Touren")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // GPX-Import (T4) — z.B. aus Komoot exportierte Touren
            ToolbarItem(placement: .topBarTrailing) {
                Button { showImporter = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down").font(.callout)
                        Text("GPX").font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(AppColor.muted)
                }
                .accessibilityLabel("GPX importieren")
            }
        }
        .task { if tours.isEmpty { reload() } }
        .navigationDestination(item: $detailTour) { tour in
            TourDetailView(tour: tour)
        }
        .navigationDestination(item: $generatedDetail) { detail in
            TourDetailView(detail: detail)
        }
        .sheet(isPresented: $showPlanSheet) {
            PlanTourSheet(activity: activity.roundtripActivity, isDemo: isDemo,
                          center: cameraCenter ?? center) { detail in
                showPlanSheet = false
                if let detail { generatedDetail = detail }
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml]) { result in
            if case .success(let url) = result, let detail = GPXFile.parse(url: url) {
                generatedDetail = detail
            } else {
                error = "GPX-Datei konnte nicht gelesen werden."
            }
        }
    }

    // MARK: Karte

    private var map: some View {
        Map(position: $camera) {
            ForEach(tours) { tour in
                Annotation(tour.name, coordinate:
                            CLLocationCoordinate2D(latitude: tour.lat, longitude: tour.lon)) {
                    ZStack {
                        Circle().fill(AppColor.surface).frame(width: 34, height: 34)
                            .overlay(Circle().stroke(AppColor.primary, lineWidth: 2))
                        Image(systemName: tourActivityIcon(tour.activity))
                            .font(.app(15))
                            .foregroundStyle(AppColor.primary)
                    }
                    // 44-pt-Tap-Ziel (Apple-Minimum) bei 34-pt-Optik
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .onTapGesture { detailTour = tour }
                }
            }
        }
        .onMapCameraChange { context in
            cameraCenter = context.region.center
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func activityChip(_ a: TourActivity) -> some View {
        let selected = activity == a
        return HStack(spacing: 6) {
            Image(systemName: a.icon).font(.app(13))
            Text(a.label).font(.footnote.weight(selected ? .bold : .medium))
        }
        .foregroundStyle(selected ? AppColor.white : AppColor.muted)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(selected ? AppColor.primary : AppColor.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(selected ? AppColor.primary : AppColor.border, lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture {
            guard activity != a else { return }
            activity = a
            reload()
        }
    }

    // MARK: Karten unten

    @ViewBuilder
    private var bottomCards: some View {
        if isLoading {
            HStack(spacing: 10) {
                ProgressView().tint(AppColor.primary)
                Text("Lade Touren — die erste Suche in einem Gebiet kann bis zu einer halben Minute dauern…")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }
            .padding(12)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, 16)
        } else if let error {
            InlineErrorBanner(message: error)
                .padding(.horizontal, AppSpacing.screen)
                .padding(.bottom, 16)
        } else if tours.isEmpty {
            Text("In diesem Gebiet wurde nichts gefunden.")
                .font(.footnote)
                .foregroundStyle(AppColor.muted)
                .padding(12)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
                .padding(.horizontal, AppSpacing.screen)
                .padding(.bottom, 16)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.stack) {
                    ForEach(tours.prefix(25)) { tour in
                        tourCard(tour)
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
            }
            .padding(.bottom, 16)
        }
    }

    private func tourCard(_ tour: Tour) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let diff = tour.difficulty {
                    Text(diff)
                        .font(.app(10, weight: .bold))
                        .foregroundStyle(AppColor.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(AppColor.primaryDark)
                        .clipShape(Capsule())
                }
                if let net = tour.networkLabel {
                    Text(net)
                        .font(.app(10, weight: .medium))
                        .foregroundStyle(AppColor.brass)
                }
                Spacer()
            }
            Text(tour.name)
                .font(.subheadline.bold())
                .foregroundStyle(AppColor.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 8) {
                if let min = tour.durationMin {
                    Label(Self.formatDuration(min), systemImage: "clock")
                }
                if let km = tour.distanceKm {
                    Label(Self.formatDistance(km), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
            }
            .font(.caption)
            .foregroundStyle(AppColor.muted)
        }
        .padding(AppSpacing.card)
        .frame(width: 260, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { detailTour = tour }
    }

    static func formatDuration(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60) Std \(minutes % 60) Min" : "\(minutes) Min"
    }

    /// Kurze Bahnen metergenau, Routen in Kilometern.
    static func formatDistance(_ km: Double) -> String {
        km < 1 ? "\(Int((km * 1000).rounded())) m" : String(format: "%.1f km", km)
    }

    // MARK: Daten

    private func reload() {
        error = nil
        if isDemo {
            tours = TourService.demoTours(activity: activity)
            return
        }
        guard let clientId = auth.clientId else { return }
        isLoading = true
        Task {
            do {
                tours = try await TourService.shared.tours(
                    clientId: clientId, lat: center.latitude, lon: center.longitude,
                    radiusKm: radiusKm, activity: activity)
            } catch {
                self.error = "Touren konnten nicht geladen werden."
            }
            isLoading = false
        }
    }

    private func suggestionRow(_ s: LocationSearchModel.Suggestion) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.callout)
                .foregroundStyle(AppColor.muted)
            VStack(alignment: .leading, spacing: 1) {
                Text(s.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.text)
                    .lineLimit(1)
                if !s.subtitle.isEmpty {
                    Text(s.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { select(s) }
    }

    /// Vorschlag übernehmen: auflösen, Karte zentrieren, Touren laden.
    private func select(_ s: LocationSearchModel.Suggestion) {
        searchFocused = false
        searchText = s.title
        searchModel.clear()
        Task {
            guard let c = await searchModel.resolve(s) else {
                error = "Ort konnte nicht geladen werden."
                return
            }
            moveTo(c)
        }
    }

    /// Fallback für die „Suchen“-Taste ohne gewählten Vorschlag.
    private func searchLocation() {
        searchFocused = false
        searchModel.clear()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
        MKLocalSearch(request: request).start { response, _ in
            Task { @MainActor in
                guard let item = response?.mapItems.first else {
                    error = "„\(searchText)“ wurde nicht gefunden."
                    return
                }
                moveTo(item.placemark.coordinate)
            }
        }
    }

    private func moveTo(_ c: CLLocationCoordinate2D) {
        center = c
        camera = .region(MKCoordinateRegion(
            center: c,
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)))
        reload()
    }
}


// MARK: - PlanTourSheet (T4: Rundtouren-Generator)

private struct PlanTourSheet: View {
    @Environment(AuthViewModel.self) private var auth
    let activity: WorkoutActivity
    let isDemo: Bool
    let center: CLLocationCoordinate2D
    let onDone: (TourDetail?) -> Void

    @State private var distanceKm: Double = 10
    @State private var chosenActivity: WorkoutActivity
    @State private var isGenerating = false
    @State private var error: String?

    init(activity: WorkoutActivity, isDemo: Bool,
         center: CLLocationCoordinate2D, onDone: @escaping (TourDetail?) -> Void) {
        self.activity = activity
        self.isDemo = isDemo
        self.center = center
        self.onDone = onDone
        _chosenActivity = State(initialValue: activity)
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                Text("Rundtour planen")
                    .font(.headline)
                    .foregroundStyle(AppColor.text)
                    .padding(.top, 20)

                Text("Startpunkt ist die aktuelle Kartenmitte. Die Route führt als Runde dorthin zurück.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.muted)

                // Aktivität
                HStack(spacing: AppSpacing.stack) {
                    choice(.wandern, "figure.hiking", "Wandern")
                    choice(.rad, "figure.outdoor.cycle", "Radfahren")
                }

                // Distanz
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gewünschte Distanz: \(Int(distanceKm)) km")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.text)
                    Slider(value: $distanceKm, in: 3...40, step: 1)
                        .tint(AppColor.primary)
                }
                .padding(AppSpacing.card)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))

                if let error {
                    InlineErrorBanner(message: error)
                }

                Button(isGenerating ? "Route wird berechnet…" : "Rundtour erstellen") { generate() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isGenerating)

                Text("Routing: BRouter auf OpenStreetMap-Daten — inklusive Höhenmeter.")
                    .font(.caption2)
                    .foregroundStyle(AppColor.muted)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.screen)
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }

    private func choice(_ a: WorkoutActivity, _ icon: String, _ label: String) -> some View {
        let selected = chosenActivity == a
        return VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.app(22))
                .foregroundStyle(selected ? AppColor.primary : AppColor.muted)
            Text(label)
                .font(.footnote.weight(selected ? .bold : .regular))
                .foregroundStyle(selected ? AppColor.text : AppColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card)
            .stroke(selected ? AppColor.primary : AppColor.border, lineWidth: selected ? 1.5 : 1))
        .contentShape(Rectangle())
        .onTapGesture { chosenActivity = a }
    }

    private func generate() {
        error = nil
        if isDemo {
            onDone(TourService.demoRoundtrip(lat: center.latitude, lon: center.longitude,
                                             distanceKm: distanceKm, activity: chosenActivity))
            return
        }
        guard let clientId = auth.clientId else { return }
        isGenerating = true
        Task {
            do {
                let detail = try await TourService.shared.roundtrip(
                    clientId: clientId, lat: center.latitude, lon: center.longitude,
                    distanceKm: distanceKm, activity: chosenActivity)
                isGenerating = false
                if let detail {
                    onDone(detail)
                } else {
                    error = "Keine Route gefunden — anderen Startpunkt versuchen."
                }
            } catch {
                isGenerating = false
                self.error = "Route konnte nicht berechnet werden."
            }
        }
    }
}
