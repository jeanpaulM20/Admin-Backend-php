import SwiftUI
import MapKit

// MARK: - RoutePlannerModel (T5: Routenplaner)

/// Ein gesetzter Punkt mit stabiler Identität — Pins und Menüs bleiben
/// beim Löschen oder Umkehren an „ihrem" Punkt.
struct PlannedPoint: Identifiable, Equatable {
    let id: UUID
    var coordinate: CLLocationCoordinate2D

    init(_ coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.coordinate = coordinate
    }

    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
}

/// Zustand des Routenplaners auf der Touren-Karte: gesetzte Punkte
/// (erster = Start, letzter = Ziel, dazwischen Zwischenpunkte), Aktivität
/// und die berechnete Route. Nach jeder Änderung wird nach 400 ms Ruhe
/// automatisch neu gerechnet; eine laufende Berechnung wird abgebrochen.
@Observable @MainActor
final class RoutePlannerModel {
    static let maxPoints = 25

    enum Role: Equatable { case start, via(Int), destination }

    private(set) var points: [PlannedPoint] = []
    private(set) var activity: RoundtripActivity = .wandern
    private(set) var result: TourDetail?
    private(set) var isCalculating = false
    private(set) var error: String?
    /// Fehler, bei dem ein erneuter Versuch mit denselben Punkten Sinn ergibt
    /// (Netz, Auslastung) — im Gegensatz zu „Keine Route gefunden".
    private(set) var canRetry = false

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored var clientId: String?
    @ObservationIgnored var isDemo = false

    var isFull: Bool { points.count >= Self.maxPoints }
    var coordinates: [CLLocationCoordinate2D] { points.map(\.coordinate) }

    func role(of point: PlannedPoint) -> Role {
        guard let index = points.firstIndex(of: point) else { return .via(0) }
        if index == 0 { return .start }
        if index == points.count - 1 { return .destination }
        return .via(index)
    }

    /// Bedienhinweis je Zustand (Kopfzeile im Planungsmodus).
    var hint: String {
        switch points.count {
        case 0:  return "Tippe auf die Karte, um den Start zu setzen"
        case 1:  return "Der nächste Tipp setzt das Ziel"
        default: return isFull ? "Maximal \(Self.maxPoints) Punkte" : "Jeder weitere Tipp wird zum neuen Ziel"
        }
    }

    // MARK: Punkte

    func add(_ c: CLLocationCoordinate2D) {
        guard !isFull else { return }
        points.append(PlannedPoint(c))
        scheduleCalculation()
    }

    /// „Mein Standort als Start“: ersetzt den Start bzw. setzt ihn.
    func setStart(_ c: CLLocationCoordinate2D) {
        if points.isEmpty { points = [PlannedPoint(c)] } else { points[0].coordinate = c }
        scheduleCalculation()
    }

    func removeLast() {
        guard !points.isEmpty else { return }
        points.removeLast()
        scheduleCalculation()
    }

    func remove(_ point: PlannedPoint) {
        guard let index = points.firstIndex(of: point) else { return }
        points.remove(at: index)
        scheduleCalculation()
    }

    /// Start und Ziel tauschen (Zwischenpunkte spiegeln sich mit).
    func reverse() {
        guard points.count >= 2 else { return }
        points.reverse()
        scheduleCalculation()
    }

    func clear() {
        task?.cancel()
        points = []
        result = nil
        error = nil
        canRetry = false
        isCalculating = false
    }

    func setActivity(_ a: RoundtripActivity) {
        guard a != activity else { return }
        activity = a
        scheduleCalculation()
    }

    /// Gleiche Punkte nochmals rechnen (nach Netz-/Auslastungsfehler).
    func retry() {
        scheduleCalculation()
    }

    /// Fehler von aussen anzeigen (z. B. Ortung fehlgeschlagen).
    func report(_ message: String) {
        error = message
        canRetry = false
    }

    /// Beim Verlassen des Bildschirms laufende Anfragen stoppen …
    func cancelPending() {
        task?.cancel()
        task = nil
        if isCalculating { isCalculating = false }
    }

    /// … und beim Zurückkommen eine fehlende Route nachholen.
    func resumeIfNeeded() {
        guard points.count >= 2, result == nil, error == nil, task == nil else { return }
        scheduleCalculation()
    }

    /// Region, die die berechnete Route im freien Kartenausschnitt zeigt:
    /// Kopfzeile oben und Panel unten decken rund 60 % der Karte ab, darum
    /// der grosse Breitengrad-Faktor; der Mittelpunkt wandert etwas nach
    /// Süden, damit die Route über dem Panel liegt.
    var fitRegion: MKCoordinateRegion? {
        guard let coords = result?.segments.flatMap({ $0 }), coords.count >= 2 else { return nil }
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }
        let latDelta = max((maxLat - minLat) * 2.6, 0.012)
        let lonDelta = max((maxLon - minLon) * 1.4, 0.012)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 - latDelta * 0.12,
                                           longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }

    // MARK: Berechnung

    private func scheduleCalculation() {
        task?.cancel()
        task = nil
        error = nil
        canRetry = false
        result = nil
        guard points.count >= 2 else { isCalculating = false; return }
        isCalculating = true
        let coords = coordinates, act = activity, demo = isDemo, cid = clientId
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            defer { if !Task.isCancelled { isCalculating = false; task = nil } }
            if demo {
                result = TourService.demoPlannedRoute(points: coords, activity: act)
                return
            }
            guard let cid else {
                error = "Bitte zuerst anmelden."
                return
            }
            do {
                let detail = try await TourService.shared.plannedRoute(clientId: cid, points: coords, activity: act)
                guard !Task.isCancelled else { return }
                if let detail {
                    result = detail
                } else {
                    error = "Keine Route gefunden — Punkt verschieben oder löschen."
                }
            } catch {
                guard !Task.isCancelled else { return }
                let (message, retryable) = Self.classify(error)
                self.error = message
                canRetry = retryable
            }
        }
    }

    /// Fehler → Meldung und ob ein erneuter Versuch sinnvoll ist.
    private static func classify(_ error: Error) -> (String, Bool) {
        if let url = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed].contains(url.code) {
            return ("Kein Netz — die Route kann gerade nicht berechnet werden.", true)
        }
        if let api = error as? APIError {
            // 400/422: fachliche Antwort des Servers (Punkte, keine Route) — kein Retry
            if [400, 422].contains(api.statusCode), !api.message.isEmpty { return (api.message, false) }
            if api.statusCode == 503 { return ("Routing gerade ausgelastet — bitte gleich nochmals versuchen.", true) }
        }
        return ("Routing vorübergehend nicht erreichbar — bitte gleich nochmals versuchen.", true)
    }
}

// MARK: - RoutePinView

/// Pin auf der Karte: S = Start (Olive), Ziffer = Zwischenpunkt (Messing),
/// Z = Ziel (CTA-Orange). 26 pt Optik, 44 pt Trefffläche.
struct RoutePinView: View {
    let role: RoutePlannerModel.Role

    private var color: Color {
        switch role {
        case .start:       return AppColor.primary
        case .via:         return AppColor.brass
        case .destination: return AppColor.cta
        }
    }

    private var text: String {
        switch role {
        case .start:        return "S"
        case .via(let i):   return "\(i)"
        case .destination:  return "Z"
        }
    }

    var accessibilityText: String {
        switch role {
        case .start:        return "Startpunkt"
        case .via(let i):   return "Zwischenpunkt \(i)"
        case .destination:  return "Ziel"
        }
    }

    var body: some View {
        Text(text)
            .font(.app(11, weight: .bold))
            .foregroundStyle(AppColor.white)
            .frame(width: 26, height: 26)
            .background(color, in: Circle())
            .overlay(Circle().stroke(AppColor.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .accessibilityLabel(accessibilityText)
    }
}

// MARK: - RoutePlannerPanel

/// Panel unter der Karte im Planungsmodus: Aktivität, Live-Kennzahlen,
/// Mini-Höhenprofil und die Aktionen. „Tour starten“ ist der eine CTA.
struct RoutePlannerPanel: View {
    let model: RoutePlannerModel
    let onLocate: () -> Void
    let onDetails: (TourDetail) -> Void
    let onStart: (TourDetail) -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Aktivität — gleiches Chip-Schema wie Rundtour/Discovery
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RoundtripActivity.allCases) { a in
                        chip(a)
                    }
                }
                .padding(.horizontal, AppSpacing.card)
            }
            .padding(.horizontal, -AppSpacing.card)

            status

            if let r = model.result, ElevationProfileView.hasProfile(r.elevations) {
                ElevationProfileView(segments: r.segments, elevations: r.elevations, compact: true)
                    .frame(height: 40)
                    .background(AppColor.surface2, in: RoundedRectangle(cornerRadius: AppRadius.control))
            }

            HStack(spacing: 8) {
                iconButton("location", "Mein Standort als Start", action: onLocate)
                iconButton("arrow.uturn.backward", "Letzten Punkt entfernen",
                           disabled: model.points.isEmpty) { model.removeLast() }
                iconButton("trash", "Alle Punkte löschen",
                           disabled: model.points.isEmpty) { model.clear() }
                iconButton("chart.xyaxis.line", "Details und Höhenprofil",
                           disabled: model.result == nil) {
                    if let r = model.result { onDetails(r) }
                }

                Spacer(minLength: 0)

                Button {
                    if let r = model.result { onStart(r) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill").font(.app(12, weight: .bold))
                        Text("Tour starten").font(.footnote.bold())
                    }
                    .lineLimit(1)
                    .foregroundStyle(AppColor.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(AppColor.cta, in: RoundedRectangle(cornerRadius: AppRadius.control))
                    .fixedSize()
                }
                .disabled(model.result == nil)
                .opacity(model.result == nil ? 0.45 : 1)
            }
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
        .padding(.horizontal, AppSpacing.screen)
        .padding(.bottom, 16)
    }

    // MARK: Status / Kennzahlen

    @ViewBuilder
    private var status: some View {
        if model.isCalculating {
            HStack(spacing: 10) {
                ProgressView().tint(AppColor.primary)
                Text("Route wird berechnet…")
                    .font(.footnote)
                    .foregroundStyle(AppColor.muted)
                Spacer()
            }
            .frame(minHeight: 44)
        } else if let error = model.error {
            VStack(spacing: 8) {
                InlineErrorBanner(message: error)
                if model.canRetry {
                    Button("Nochmals versuchen") { model.retry() }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else if let r = model.result {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    stat("Distanz", r.distanceKm.map { TourFormat.distance($0) } ?? "–")
                    if let gain = r.elevationGain {
                        stat("Höhenmeter", r.elevationLoss.map { "↑\(gain) ↓\($0) m" } ?? "↑\(gain) m")
                    } else {
                        stat("Höhenmeter", "–")
                    }
                    stat("Dauer ca.", r.durationMin.map { TourFormat.duration($0) } ?? "–")
                    stat("Schwierigkeit", r.difficulty ?? "–")
                }
                if let note = r.description, r.elevationGain == nil {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            // Der Bedienhinweis steht in der Kopfzeile — hier nur das Prinzip
            Text("Start, Zwischenpunkte, Ziel — die Route wird automatisch berechnet.")
                .font(.footnote)
                .foregroundStyle(AppColor.muted)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.app(13, weight: .bold))
                .foregroundStyle(AppColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.app(10))
                .foregroundStyle(AppColor.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppColor.surface2, in: RoundedRectangle(cornerRadius: AppRadius.control))
    }

    private func chip(_ a: RoundtripActivity) -> some View {
        let selected = model.activity == a
        return HStack(spacing: 6) {
            Image(systemName: a.icon).font(.app(13))
            Text(a.label).font(.footnote.weight(selected ? .bold : .medium))
        }
        .foregroundStyle(selected ? AppColor.white : AppColor.muted)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selected ? AppColor.primary : AppColor.surface2,
                    in: RoundedRectangle(cornerRadius: AppRadius.control))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
            .stroke(selected ? AppColor.primary : AppColor.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { model.setActivity(a) }
    }

    private func iconButton(_ symbol: String, _ label: String, disabled: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.app(14, weight: .semibold))
                .foregroundStyle(disabled ? AppColor.muted.opacity(0.5) : AppColor.text)
                .frame(width: 40, height: 40)
                .background(AppColor.surface2, in: RoundedRectangle(cornerRadius: AppRadius.control))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                    .stroke(AppColor.border, lineWidth: 1))
        }
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}
