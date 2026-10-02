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
    /// Ab diesem Abstand zur Route gilt ein Punkt als „abseits der Wege".
    static let offRouteThresholdM = 150

    enum Role: Equatable { case start, via(Int), destination }

    private(set) var points: [PlannedPoint] = []
    private(set) var activity: RoundtripActivity = .wandern
    /// Rundkurs: vom letzten Punkt zurück zum Start.
    private(set) var roundtrip = false
    private(set) var result: TourDetail?
    private(set) var isCalculating = false
    private(set) var error: String?
    /// Fehler, bei dem ein erneuter Versuch mit denselben Punkten Sinn ergibt
    /// (Netz, Auslastung) — im Gegensatz zu „Keine Route gefunden".
    private(set) var canRetry = false
    /// Punkte, die weit neben dem nächsten Weg liegen (Abstand in Metern)
    /// oder gar nicht erreichbar sind (`unreachableID`) — rot markiert.
    private(set) var offRoute: [UUID: Int] = [:]
    private(set) var unreachableID: UUID?
    /// „Meine Routen": die gespeicherte Fassung dieser Planung (falls es
    /// eine gibt) und ob seither etwas geändert wurde.
    private(set) var savedRoute: SavedRoute?
    private(set) var hasUnsavedChanges = false
    private(set) var isSaving = false
    /// Name einer vom Assistenten übernommenen Route (Vorschlag beim Speichern)
    private(set) var proposedName: String?

    @ObservationIgnored private var task: Task<Void, Never>?
    /// Zählt Änderungen — so erkennt `save`, ob währenddessen weitergeplant wurde
    @ObservationIgnored private var revision = 0
    @ObservationIgnored var clientId: String?
    @ObservationIgnored var isDemo = false

    var isFull: Bool { points.count >= Self.maxPoints }
    /// Die Route ist gespeichert und seither unverändert.
    var isSaved: Bool { savedRoute != nil && !hasUnsavedChanges }
    /// Namensvorschlag für eine neue Route: „Wandern · 12.4 km"
    var suggestedName: String {
        if let proposedName { return proposedName }
        return [activity.label, result?.distanceKm.map { TourFormat.distance($0) }]
            .compactMap { $0 }.joined(separator: " · ")
    }
    private var repository: SavedRouteRepository {
        SavedRouteRepository(clientId: clientId, isDemo: isDemo)
    }
    var coordinates: [CLLocationCoordinate2D] { points.map(\.coordinate) }

    /// Luftlinie durch alle Punkte (im Rundkurs zurück zum Start) — wird
    /// gestrichelt gezeigt, solange keine berechnete Route da ist.
    var straightLine: [CLLocationCoordinate2D] {
        roundtrip && points.count >= 2 ? coordinates + coordinates.prefix(1) : coordinates
    }

    func role(of point: PlannedPoint) -> Role {
        guard let index = points.firstIndex(of: point) else { return .via(0) }
        if index == 0 { return .start }
        if index == points.count - 1 && !roundtrip { return .destination }
        return .via(index)
    }

    func isFlagged(_ point: PlannedPoint) -> Bool {
        offRoute[point.id] != nil || unreachableID == point.id
    }

    func label(of point: PlannedPoint) -> String {
        switch role(of: point) {
        case .start:       return roundtrip ? "Start/Ziel" : "Start"
        case .via(let i):  return "Zwischenpunkt \(i)"
        case .destination: return "Ziel"
        }
    }

    /// Bedienhinweis je Zustand (Kopfzeile im Planungsmodus).
    var hint: String {
        switch points.count {
        case 0:  return "Tippe auf die Karte, um den Start zu setzen"
        case 1:  return roundtrip ? "Der nächste Tipp setzt den Wendepunkt" : "Der nächste Tipp setzt das Ziel"
        default:
            if isFull { return "Maximal \(Self.maxPoints) Punkte" }
            return roundtrip ? "Tipp: weiterer Punkt · auf der Linie: einfügen"
                             : "Tipp: neues Ziel · auf der Linie: einfügen"
        }
    }

    /// Hinweis auf Punkte abseits der Wege (unter den Kennzahlen).
    var warning: String? {
        guard let first = points.first(where: { offRoute[$0.id] != nil }),
              let meters = offRoute[first.id] else { return nil }
        let more = offRoute.count - 1
        let distance = meters >= 1000 ? String(format: "%.1f km", Double(meters) / 1000) : "\(meters) m"
        return "\(label(of: first)) liegt \(distance) neben dem nächsten Weg — die Route führt daran vorbei."
            + (more > 0 ? " (+\(more) weitere)" : "")
    }

    // MARK: Punkte

    func add(_ c: CLLocationCoordinate2D) {
        guard !isFull else { return }
        points.append(PlannedPoint(c))
        scheduleCalculation()
    }

    /// Punkt an Position `index` einfügen (Tipp auf die Linie).
    func insert(_ c: CLLocationCoordinate2D, at index: Int) {
        guard !isFull else { return }
        points.insert(PlannedPoint(c), at: min(max(index, 1), points.count))
        scheduleCalculation()
    }

    /// Einfügeposition für einen Tipp auf die Linie beim Linien-Stützpunkt
    /// `vertex` (Index in der berechneten Route bzw. in `straightLine`):
    /// der neue Punkt kommt vor den ersten gesetzten Punkt, den die Route
    /// erst NACH dieser Stelle erreicht.
    func insertIndex(afterLineVertex vertex: Int) -> Int {
        guard let route = result?.segments.first, route.count >= 2 else {
            return min(vertex + 1, points.count)
        }
        var from = 0
        for k in points.indices {
            let c = points[k].coordinate
            var best = from, bestD = Double.infinity
            for r in from..<route.count {
                let dLat = route[r].latitude - c.latitude, dLon = route[r].longitude - c.longitude
                let d = dLat * dLat + dLon * dLon
                if d < bestD { bestD = d; best = r }
            }
            if k > 0 && best > vertex { return k }
            from = best
        }
        return points.count
    }

    /// Pin ziehen: Koordinate laufend nachführen (die Route verschwindet,
    /// Luftlinien zeigen den Zwischenstand); gerechnet wird beim Loslassen.
    func move(_ point: PlannedPoint, to c: CLLocationCoordinate2D) {
        guard let index = points.firstIndex(of: point) else { return }
        points[index].coordinate = c
        revision += 1
        hasUnsavedChanges = true
        task?.cancel()
        task = nil
        result = nil
        error = nil
        isCalculating = false
        offRoute[point.id] = nil
        if unreachableID == point.id { unreachableID = nil }
    }

    func finishMove() {
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

    /// Richtung umkehren (Start und Ziel tauschen, Zwischenpunkte spiegeln).
    func reverse() {
        guard points.count >= 2 else { return }
        points.reverse()
        scheduleCalculation()
    }

    func clear() {
        task?.cancel()
        task = nil
        points = []
        result = nil
        error = nil
        canRetry = false
        isCalculating = false
        offRoute = [:]
        unreachableID = nil
        savedRoute = nil
        hasUnsavedChanges = false
        proposedName = nil
        revision += 1
    }

    // MARK: Meine Routen

    /// Gespeicherte Route zum Weiterbearbeiten in den Planer laden.
    func load(_ saved: SavedRoute) {
        clear()
        points = saved.points.map { PlannedPoint($0) }
        activity = saved.activity
        roundtrip = saved.roundtrip
        scheduleCalculation()
        savedRoute = saved
        hasUnsavedChanges = false
    }

    /// Vorschlag des Assistenten übernehmen: gleiche Punkte, Aktivität und
    /// Rundkurs — als neue, noch ungespeicherte Planung.
    func load(_ plan: RoutePlan) {
        clear()
        points = plan.points.prefix(Self.maxPoints).map { PlannedPoint($0) }
        activity = plan.activity
        roundtrip = plan.roundtrip
        proposedName = plan.name
        scheduleCalculation()
    }

    /// Route speichern: ersetzt die geladene Fassung oder legt — mit
    /// `asNew` bzw. ohne geladene Fassung — eine neue an.
    /// Liefert nil bei Erfolg, sonst die Fehlermeldung.
    func save(name: String, asNew: Bool = false) async -> String? {
        guard points.count >= 2, !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }
        let savedRevision = revision
        do {
            guard let saved = try await repository.save(
                name: name, points: coordinates, activity: activity, roundtrip: roundtrip,
                replacing: asNew ? nil : savedRoute?.id) else {
                return "Route konnte nicht gespeichert werden."
            }
            savedRoute = saved
            // Nur „gespeichert" melden, wenn währenddessen nichts verändert wurde
            hasUnsavedChanges = revision != savedRevision
            return nil
        } catch {
            if let api = error as? APIError, [400, 409, 422].contains(api.statusCode), !api.message.isEmpty {
                return api.message
            }
            return Self.classify(error).0
        }
    }

    func setActivity(_ a: RoundtripActivity) {
        guard a != activity else { return }
        activity = a
        scheduleCalculation()
    }

    func setRoundtrip(_ on: Bool) {
        guard on != roundtrip else { return }
        roundtrip = on
        scheduleCalculation()
    }

    /// Gleiche Punkte nochmals rechnen (nach Netz-/Auslastungsfehler).
    func retry() {
        recalculateUnchanged()
    }

    /// Neu rechnen, ohne dass die Planung als verändert gilt.
    private func recalculateUnchanged() {
        let unsaved = hasUnsavedChanges
        scheduleCalculation()
        hasUnsavedChanges = unsaved
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
        recalculateUnchanged()
    }

    /// Region, die die berechnete Route im freien Kartenausschnitt zeigt:
    /// Kopfzeile oben und Panel unten decken rund 60 % der Karte ab, darum
    /// der grosse Breitengrad-Faktor; der Mittelpunkt wandert etwas nach
    /// Süden, damit die Route über dem Panel liegt.
    var fitRegion: MKCoordinateRegion? {
        let coords = result?.segments.flatMap({ $0 }) ?? coordinates
        guard coords.count >= 2 else { return nil }
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }
        // Rechts unten sitzt der Lokalisieren-Knopf über dem Panel — genug
        // Rand lassen, damit kein Pin darunter verschwindet
        let latDelta = max((maxLat - minLat) * 3.0, 0.012)
        let lonDelta = max((maxLon - minLon) * 1.7, 0.012)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 - latDelta * 0.13,
                                           longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }

    // MARK: Berechnung

    private func scheduleCalculation() {
        revision += 1
        hasUnsavedChanges = true
        task?.cancel()
        task = nil
        error = nil
        canRetry = false
        result = nil
        offRoute = [:]
        unreachableID = nil
        guard points.count >= 2 else { isCalculating = false; return }
        isCalculating = true
        let snapshot = points, act = activity, loop = roundtrip, demo = isDemo, cid = clientId
        let coords = snapshot.map(\.coordinate)
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            defer { if !Task.isCancelled { isCalculating = false; task = nil } }
            if demo {
                result = TourService.demoPlannedRoute(points: coords, activity: act, roundtrip: loop)
                return
            }
            guard let cid else {
                error = "Bitte zuerst anmelden."
                return
            }
            do {
                let planned = try await TourService.shared.plannedRoute(
                    clientId: cid, points: coords, activity: act, roundtrip: loop)
                guard !Task.isCancelled else { return }
                guard let planned else {
                    error = "Keine Route gefunden — Punkt verschieben oder löschen."
                    return
                }
                result = planned.detail
                for (i, meters) in planned.offRouteM.enumerated() where i < snapshot.count {
                    if let meters, meters > Self.offRouteThresholdM { offRoute[snapshot[i].id] = meters }
                }
            } catch {
                guard !Task.isCancelled else { return }
                // 422 mit pointIndex: genau dieser Punkt ist nicht erreichbar
                if let api = error as? APIError, api.statusCode == 422,
                   let body = api.body,
                   let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                   let index = json["pointIndex"] as? Int, snapshot.indices.contains(index) {
                    unreachableID = snapshot[index].id
                    self.error = "\(label(of: snapshot[index])) ist nicht erreichbar — verschieben oder löschen."
                    return
                }
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
/// Z = Ziel (CTA-Orange); rot = abseits der Wege bzw. nicht erreichbar.
/// 26 pt Optik, 44 pt Trefffläche; beim Ziehen leicht vergrössert.
struct RoutePinView: View {
    let role: RoutePlannerModel.Role
    var flagged = false
    var lifted = false
    var label = ""

    private var color: Color {
        if flagged { return AppColor.red }
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

    var body: some View {
        Text(text)
            .font(.app(11, weight: .bold))
            .foregroundStyle(AppColor.white)
            .frame(width: 26, height: 26)
            .background(color, in: Circle())
            .overlay(Circle().stroke(AppColor.white, lineWidth: 2))
            .shadow(color: .black.opacity(lifted ? 0.45 : 0.25), radius: lifted ? 6 : 2, y: lifted ? 3 : 1)
            .scaleEffect(lifted ? 1.35 : 1)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .accessibilityLabel(flagged ? "\(label), abseits der Wege" : label)
            .accessibilityHint("Tippen für Aktionen, ziehen zum Verschieben")
    }
}

// MARK: - RoutePlannerPanel

/// Panel unter der Karte im Planungsmodus: Aktivität, Live-Kennzahlen,
/// Mini-Höhenprofil und die Aktionen. „Tour starten“ ist der eine CTA.
struct RoutePlannerPanel: View {
    let model: RoutePlannerModel
    let onLocate: () -> Void
    let onFit: () -> Void
    /// Speichern; `true` = ausdrücklich als neue Route (Kopie)
    let onSave: (Bool) -> Void
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

            // Mini-Höhenprofil — Tipp öffnet die Details mit dem vollen Profil
            if let r = model.result, ElevationProfileView.hasProfile(r.elevations) {
                ElevationProfileView(segments: r.segments, elevations: r.elevations, compact: true)
                    .frame(height: 40)
                    .background(AppColor.surface2, in: RoundedRectangle(cornerRadius: AppRadius.control))
                    .contentShape(Rectangle())
                    .onTapGesture { onDetails(r) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Öffnet die Details mit dem Höhenprofil")
            }

            HStack(spacing: 8) {
                iconButton("arrow.uturn.backward", "Letzten Punkt entfernen",
                           disabled: model.points.isEmpty) { model.removeLast() }
                iconButton("arrow.triangle.2.circlepath",
                           model.roundtrip ? "Rundkurs ausschalten" : "Rundkurs: zurück zum Start",
                           active: model.roundtrip) { model.setRoundtrip(!model.roundtrip) }
                // Lesezeichen: gefüllt = gespeichert und unverändert
                iconButton(model.isSaved ? "bookmark.fill" : "bookmark",
                           model.isSaved ? "Route ist gespeichert" : "Route speichern",
                           disabled: model.result == nil || model.isSaving || model.isSaved,
                           active: model.isSaved) { onSave(false) }
                moreMenu

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
                if let warning = model.warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(AppColor.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onDetails(r) }
        } else {
            // Der Bedienhinweis steht in der Kopfzeile — hier nur das Prinzip
            Text("Start, Zwischenpunkte, Ziel — die Route wird automatisch berechnet. Pins lassen sich ziehen.")
                .font(.footnote)
                .foregroundStyle(AppColor.muted)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }

    /// Seltenere Aktionen: Richtung umkehren, Route einpassen, Details, alles löschen.
    private var moreMenu: some View {
        Menu {
            Button(action: onLocate) {
                Label("Mein Standort als Start", systemImage: "location")
            }
            Button { model.reverse() } label: {
                Label("Richtung umkehren", systemImage: "arrow.left.arrow.right")
            }
            .disabled(model.points.count < 2)
            Button(action: onFit) {
                Label("Ganze Route zeigen", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .disabled(model.points.count < 2)
            Button {
                if let r = model.result { onDetails(r) }
            } label: {
                Label("Details und Höhenprofil", systemImage: "chart.xyaxis.line")
            }
            .disabled(model.result == nil)
            if model.savedRoute != nil {
                Button { onSave(true) } label: {
                    Label("Als neue Route speichern", systemImage: "bookmark")
                }
                .disabled(model.result == nil || model.isSaving)
            }
            Divider()
            Button(role: .destructive) { model.clear() } label: {
                Label("Alle Punkte löschen", systemImage: "trash")
            }
            .disabled(model.points.isEmpty)
        } label: {
            Image(systemName: "ellipsis")
                .font(.app(14, weight: .semibold))
                .foregroundStyle(AppColor.text)
                .frame(width: 40, height: 40)
                .background(AppColor.surface2, in: RoundedRectangle(cornerRadius: AppRadius.control))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                    .stroke(AppColor.border, lineWidth: 1))
        }
        .accessibilityLabel("Weitere Aktionen")
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
                            active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.app(14, weight: .semibold))
                .foregroundStyle(active ? AppColor.white
                                 : disabled ? AppColor.muted.opacity(0.5) : AppColor.text)
                .frame(width: 40, height: 40)
                .background(active ? AppColor.primary : AppColor.surface2,
                            in: RoundedRectangle(cornerRadius: AppRadius.control))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                    .stroke(active ? AppColor.primary : AppColor.border, lineWidth: 1))
        }
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}
