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
    @State private var showAssistant = false
    @State private var searchModel = LocationSearchModel()
    @FocusState private var searchFocused: Bool

    // Routen-Vorschau: die Route der gerade gewählten Tour-Karte wird auf
    // der Karte gezeichnet (Details werden nachgeladen und gecacht)
    @State private var visibleTourId: String?
    @State private var previewCache: [String: TourDetail] = [:]
    @State private var loadingPreviews: Set<String> = []

    private var isDemo: Bool { auth.clientId == "demo" }

    var body: some View {
        // Kacheln schweben über der Karte — sie bleibt zwischen den
        // Bedienelementen sichtbar (moderner Look, User-Wunsch 2026-08-25)
        ZStack(alignment: .top) {
            map

            VStack(spacing: AppSpacing.stack) {
                header

                // Live-Ortsvorschläge direkt unter der Suche
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
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, AppSpacing.stack)

            // Tour-Karten unten
            VStack {
                Spacer()
                bottomCards
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Touren-Assistent (C1): Wunschtour beschreiben → Route
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAssistant = true } label: {
                    Image(systemName: "sparkles")
                        .font(.callout)
                        .foregroundStyle(AppColor.brass)
                }
                .accessibilityLabel("Touren-Assistent")
            }
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
        .sheet(isPresented: $showAssistant) {
            TourAssistantView()
        }
        .sheet(isPresented: $showPlanSheet) {
            PlanTourSheet(activity: activity.roundtrip, isDemo: isDemo,
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

    // MARK: Kopfzeile (Kacheln — Suche, Aktivität, Filter + Rundtour)

    private var header: some View {
        VStack(spacing: AppSpacing.stack) {
            // Suche vollbreit
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.callout)
                    .foregroundStyle(AppColor.muted)
                TextField("Ort oder Region suchen", text: $searchText)
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
            .padding(.vertical, 12)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColor.border, lineWidth: 1))

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

            // Filterzeile: Radius · Hier suchen · Rundtour (der eine CTA) —
            // bewusst kompakter als die Standard-Masse, damit alle drei
            // Kacheln auf 402-pt-Geräten einzeilig bleiben
            HStack(spacing: 8) {
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                        .stroke(AppColor.border, lineWidth: 1))
                    .fixedSize()
                }

                // Kartenmitte übernehmen — ruhiger Kontext-Chip, kein zweiter CTA
                Button {
                    if let c = cameraCenter { center = c }
                    reload()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise").font(.caption)
                        Text("Hier suchen").font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(AppColor.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                        .stroke(AppColor.border, lineWidth: 1))
                    .fixedSize()
                }

                Spacer(minLength: 0)

                Button {
                    showPlanSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").font(.callout)
                        Text("Rundtour").font(.footnote.bold())
                    }
                    .lineLimit(1)
                    .foregroundStyle(AppColor.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(AppColor.cta, in: RoundedRectangle(cornerRadius: AppRadius.control))
                    .fixedSize()
                }
            }
        }
    }

    // MARK: Karte

    private var previewDetail: TourDetail? {
        visibleTourId.flatMap { previewCache[$0] }
    }

    private var map: some View {
        Map(position: $camera) {
            // Routenverlauf der gewählten Tour (blau = betrachtete Route)
            if let preview = previewDetail {
                ForEach(preview.segments.indices, id: \.self) { i in
                    MapPolyline(coordinates: preview.segments[i])
                        .stroke(AppColor.blue.opacity(0.9), lineWidth: 3)
                }
            }
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
        .background(selected ? AppColor.primary : AppColor.surface,
                    in: RoundedRectangle(cornerRadius: AppRadius.control))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
            .stroke(selected ? AppColor.primary : AppColor.border, lineWidth: 1))
        .contentShape(Rectangle())
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
                            .id(tour.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, AppSpacing.screen)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visibleTourId)
            .padding(.bottom, 16)
            .onChange(of: visibleTourId) { _, id in
                loadPreview(for: id)
            }
            .onAppear {
                if visibleTourId == nil { visibleTourId = tours.first?.id }
                loadPreview(for: visibleTourId)
            }
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
                    Label(TourFormat.duration(min), systemImage: "clock")
                }
                if let km = tour.distanceKm {
                    Label(TourFormat.distance(km), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
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

    // MARK: Daten

    private func reload() {
        error = nil
        visibleTourId = nil
        previewCache = [:]
        if isDemo {
            tours = TourService.demoTours(activity: activity)
            visibleTourId = tours.first?.id
            loadPreview(for: visibleTourId)
            return
        }
        guard let clientId = auth.clientId else { return }
        isLoading = true
        Task {
            do {
                tours = try await TourService.shared.tours(
                    clientId: clientId, lat: center.latitude, lon: center.longitude,
                    radiusKm: radiusKm, activity: activity)
                visibleTourId = tours.first?.id
                loadPreview(for: visibleTourId)
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
    /// Detail der gewählten Tour laden und als Karten-Vorschau zeichnen.
    private func loadPreview(for id: String?) {
        guard let id, previewCache[id] == nil, !loadingPreviews.contains(id) else { return }
        if isDemo {
            previewCache[id] = TourService.demoDetail(id)
            return
        }
        guard let clientId = auth.clientId else { return }
        loadingPreviews.insert(id)
        Task {
            if let detail = try? await TourService.shared.detail(clientId: clientId, tourId: id) {
                previewCache[id] = detail
            }
            loadingPreviews.remove(id)
        }
    }

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
    let activity: RoundtripActivity
    let isDemo: Bool
    let center: CLLocationCoordinate2D
    let onDone: (TourDetail?) -> Void

    @State private var distanceKm: Double = 10
    @State private var chosenActivity: RoundtripActivity
    @State private var isGenerating = false
    @State private var error: String?

    init(activity: RoundtripActivity, isDemo: Bool,
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

                // Aktivität — gleiches Kachel-Schema wie Discovery/Aufzeichnung
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RoundtripActivity.allCases) { a in
                            choice(a)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screen)
                }
                .padding(.horizontal, -AppSpacing.screen)

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

    private func choice(_ a: RoundtripActivity) -> some View {
        let selected = chosenActivity == a
        return HStack(spacing: 6) {
            Image(systemName: a.icon).font(.app(13))
            Text(a.label).font(.footnote.weight(selected ? .bold : .medium))
        }
        .foregroundStyle(selected ? AppColor.white : AppColor.muted)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(selected ? AppColor.primary : AppColor.surface,
                    in: RoundedRectangle(cornerRadius: AppRadius.control))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
            .stroke(selected ? AppColor.primary : AppColor.border, lineWidth: 1))
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
