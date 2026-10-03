import Foundation
import CoreLocation
import Observation

// MARK: - Aktivitäten

enum WorkoutActivity: String, CaseIterable, Identifiable, Codable {
    case kraft    = "Krafttraining"
    case joggen   = "Joggen"
    case rad      = "Radfahren"
    case mtb      = "Mountainbike"
    case wandern  = "Wandern"
    case bergtour = "Bergtour"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .kraft:    return "dumbbell.fill"
        case .joggen:   return "figure.run"
        case .rad:      return "bicycle"
        case .mtb:      return "figure.outdoor.cycle"
        case .wandern:  return "figure.hiking"
        case .bergtour: return "mountain.2.fill"
        }
    }

    /// Outdoor-Aktivitäten zeichnen eine GPS-Route auf.
    var usesGPS: Bool { self != .kraft }

    /// Plausibilitätsgrenze für Punkt-zu-Punkt-Geschwindigkeit (m/s).
    /// Auf dem Rad (auch bergab im Gelände) sind höhere Spitzen normal.
    var maxSpeed: Double { (self == .rad || self == .mtb) ? 25 : 12 }

    // MARK: Zuletzt genutzte Aktivität

    private static let lastUsedKey = "lastWorkoutActivity"

    /// Zuletzt tatsächlich gestartete Aktivität (überlebt App-Neustarts).
    static var lastUsed: WorkoutActivity? {
        UserDefaults.standard.string(forKey: lastUsedKey).flatMap(WorkoutActivity.init(rawValue:))
    }

    /// Beim Start einer Aufzeichnung merken — nicht schon beim Antippen,
    /// sonst würde blosses Durchblättern die Reihenfolge verändern.
    static func rememberUsed(_ activity: WorkoutActivity) {
        UserDefaults.standard.set(activity.rawValue, forKey: lastUsedKey)
    }

    /// Auswahlreihenfolge: die zuletzt genutzte Aktivität zuerst,
    /// danach die übrigen in ihrer festen Reihenfolge.
    static func orderedByRecency(preferring first: WorkoutActivity? = nil) -> [WorkoutActivity] {
        guard let first = first ?? lastUsed else { return allCases }
        return [first] + allCases.filter { $0 != first }
    }
}

// MARK: - WorkoutRecorder

/// Aufnahme-Engine: sammelt 1-Hz-Herzfrequenz-Samples vom `HeartRateSource`
/// und (bei Outdoor-Aktivitäten) gefilterte GPS-Punkte vom `LocationSource`,
/// führt Dauer/Distanz/Pace/Höhenmeter und sichert alle 30 s einen Snapshot
/// auf Platte (Crash-/Kill-Recovery).
@MainActor @Observable
final class WorkoutRecorder {
    enum Phase { case setup, recording, paused, finished }

    private(set) var activity: WorkoutActivity = .kraft
    private let source: HeartRateSource
    private let gpsSource: LocationSource

    private(set) var phase: Phase = .setup
    private(set) var hrState: HeartRateSourceState = .idle
    private(set) var gpsState: LocationSourceState = .idle
    private(set) var currentHR: Int?
    private(set) var samples: [HrSample] = []
    private(set) var track: [TrackPoint] = []
    private(set) var distanceMeters: Double = 0
    private(set) var elevationGain: Double = 0
    private(set) var startedAt: Date?
    private(set) var elapsed: TimeInterval = 0
    /// Eindeutige ID dieser Aufzeichnung (UUID beim Start). Backend dedupliziert
    /// darüber (kein doppeltes Training bei erneutem Upload), das Foto wird
    /// unter dieser ID gesichert (kann nie am falschen Training landen).
    private(set) var recordingId: String?
    /// Konto, unter dem die Aufzeichnung läuft — die Recovery reicht sie nur
    /// unter demselben Konto nach (kein Demo-Lauf auf ein echtes Konto).
    private(set) var ownerClientId: String?
    /// Nach einer Pause wird der erste Punkt ohne Distanz übernommen — sonst
    /// zählt die Luftlinie der Pause (z. B. Autofahrt) als gelaufene Strecke.
    private var skipDistanceOnce = false

    // Tour folgen (T3): Route-Overlay + Off-Route-Erkennung
    private(set) var routeName: String?

    /// Letzte empfangene Position (auch ungenaue) — fürs Karten-Zentrieren.
    private(set) var lastKnownCoordinate: CLLocationCoordinate2D?
    /// Zähler je Positions-Update; die View beobachtet ihn für den Follow-Modus.
    private(set) var locationTick = 0
    /// Blickrichtung in Grad (0 = Nord), vom Kompass bzw. simuliert.
    private(set) var headingDegrees: Double?
    private(set) var routeSegments: [[CLLocationCoordinate2D]] = []
    private(set) var routeElevations: [[Double?]] = []
    private(set) var isOffRoute = false
    private(set) var offRouteDistance: Double = 0

    // Routenführung (Phase 5.2): Fortschritt entlang der Route
    struct RouteProgress: Equatable {
        /// Stützpunkt der Linie, bis zu dem die Route abgeschritten ist
        var index: Int
        var doneM: Double
        var leftM: Double
        var ascentLeftM: Double
        var descentLeftM: Double
        /// Restzeit in Minuten (SAC-Formel, ab 500 m mit dem eigenen Tempo gemischt)
        var etaMinutes: Int?
        /// Distanz entlang der Route bis zum nächsten Zwischenpunkt
        var nextWaypointM: Double?
        var fraction: Double
    }
    private(set) var routeProgress: RouteProgress?
    /// Ziel erreicht: innerhalb 30 m vom Ende und mindestens 90 % abgeschritten
    private(set) var arrived = false
    /// Nächste Stelle auf der Route — Richtung für den Rückweg-Pfeil
    private(set) var nearestRoutePoint: CLLocationCoordinate2D?
    /// Die Route als eine Linie (Segmente aneinandergehängt)
    private(set) var routeLine: [CLLocationCoordinate2D] = []
    private var routeCum: [Double] = []          // Meter ab Start je Stützpunkt
    /// Stützpunkt-Indizes, an denen ein neues Segment beginnt — bei
    /// ungeordneten Routen (OSM-Relation) gibt es dort keine Verbindung
    private var routeBreaks: Set<Int> = []
    /// Fortschritt nur für geordnete Routen (Planer, Rundtour, GPX)
    private var routeOrdered = true
    private var routeAscentToEnd: [Double] = []  // Resthöhenmeter ↑ ab Stützpunkt
    private var routeDescentToEnd: [Double] = []
    private var routeWaypointCum: [Double] = []  // Zwischenpunkte (ohne Start) als Meter ab Start
    private var routeKmh = 4.2
    private var routeClimbPerH = 400.0

    // Abbiegehinweise (Phase 5.3)
    private var routeHints: [TurnHint] = []
    /// Die Route hat Abbiegehinweise (Sprachschalter zeigen)
    var hasHints: Bool { !routeHints.isEmpty }
    /// Nächster Hinweis voraus und die Distanz dorthin entlang der Route
    private(set) var nextHint: TurnHint?
    private(set) var nextHintDistance: Double = 0
    /// Ansage-Ereignis: wird bei 150 m, 30 m und am Abbiegepunkt ausgelöst
    struct HintCue: Equatable { let hint: TurnHint; let stage: Stage; let serial: Int
        enum Stage { case far, near, now } }
    private(set) var hintCue: HintCue?
    private var cueSerial = 0
    private var announced: [Int: Set<Int>] = [:]   // Index in routeHints → Stufen (0 far, 1 near, 2 now)

    // Pausen-Buchhaltung: elapsed = jetzt - start - Pausensumme
    private var pausedTotal: TimeInterval = 0
    private var pauseBegan: Date?
    private var ticker: Timer?
    private var lastSnapshot = Date.distantPast
    private var lastSmoothedEle: Double?

    init(source: HeartRateSource, gpsSource: LocationSource) {
        self.source = source
        self.gpsSource = gpsSource
        source.onStateChange = { [weak self] state in self?.hrState = state }
        source.onSample = { [weak self] bpm in self?.ingest(bpm) }
        gpsSource.onStateChange = { [weak self] state in self?.gpsState = state }
        gpsSource.onPoint = { [weak self] point in self?.ingest(point) }
        gpsSource.onHeading = { [weak self] deg in self?.headingDegrees = deg }
    }

    // MARK: Statistiken

    var avgHR: Int? {
        guard !samples.isEmpty else { return nil }
        return samples.map(\.bpm).reduce(0, +) / samples.count
    }
    var maxHR: Int? { samples.map(\.bpm).max() }

    var durationString: String {
        let s = Int(elapsed)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    var distanceString: String {
        distanceMeters >= 1000
            ? String(format: "%.2f km", distanceMeters / 1000)
            : "\(Int(distanceMeters)) m"
    }

    /// Ø-Pace (min/km) bzw. Ø-Tempo (km/h beim Rad) über die gesamte Aufnahme.
    var paceString: String {
        guard distanceMeters > 50, elapsed > 10 else { return "–" }
        if activity == .rad {
            let kmh = distanceMeters / elapsed * 3.6
            return String(format: "%.1f km/h", kmh)
        }
        let secPerKm = elapsed / (distanceMeters / 1000)
        let m = Int(secPerKm) / 60, s = Int(secPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }

    /// HF-Kurve für das bestehende `HrLineChart` in der Zusammenfassung.
    /// Auf ≤ 720 Punkte ausgedünnt: Bei Langzeit-Trainings (10 h ≈ 36'000
    /// Samples) würde sonst jede Sekunde die komplette Serie neu formatiert
    /// und gezeichnet — mehr Punkte als Pixel zeigt das Chart ohnehin nicht.
    var hrPoints: [HrPoint] {
        let fmt = ISO8601DateFormatter()
        let stride = max(1, samples.count / 720)
        return samples.enumerated()
            .filter { $0.offset % stride == 0 }
            .map { HrPoint(time: fmt.string(from: $0.element.t), value: Double($0.element.bpm)) }
    }

    var trackCoordinates: [CLLocationCoordinate2D] {
        track.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    // MARK: Steuerung


    func startRecording(_ activity: WorkoutActivity, clientId: String? = nil) {
        guard phase == .setup else { return }
        self.activity = activity
        recordingId = UUID().uuidString
        ownerClientId = clientId
        WorkoutPhotoService.clearActivePhoto(recordingId: nil)   // keine Altlast anhängen
        // Gurt-Empfang gehört zum Start wie das GPS: Die Sensor-Einrichtung
        // im Profil nutzt eine eigene, beim Verlassen freigegebene Instanz —
        // ohne diesen Aufruf käme hier nie ein Puls an (0 Messwerte).
        source.start()
        if activity.usesGPS { gpsSource.start() }
        startedAt = Date()
        phase = .recording
        startTicker()
    }

    /// Route hinterlegen, der gefolgt wird (T3): Overlay + Off-Route-Hinweis.
    /// Für den Distanz-Check wird die Route auf ~800 Punkte ausgedünnt.
    func setRoute(_ route: TourRoute) {
        routeName = route.name
        routeSegments = route.segments
        routeElevations = route.elevations
        routeLine = route.segments.flatMap { $0 }
        routeOrdered = route.ordered
        routeBreaks = []
        var offset = 0
        for seg in route.segments.dropLast() { offset += seg.count; routeBreaks.insert(offset) }

        // Kumulierte Distanz je Stützpunkt
        routeCum = routeLine.isEmpty ? [] : [0]
        for i in routeLine.indices.dropFirst() {
            routeCum.append(routeCum[i - 1] + Self.meters(routeLine[i - 1], routeLine[i]))
        }

        // Resthöhenmeter ab jedem Stützpunkt (Suffixsummen, 2-m-Glättung wie
        // beim Aufzeichnen, damit Rest und Gesamt zusammenpassen)
        let eles = route.elevations.flatMap { $0 }
        var up = [Double](repeating: 0, count: routeLine.count)
        var down = [Double](repeating: 0, count: routeLine.count)
        if eles.count == routeLine.count {
            var smoothed: Double?
            for i in eles.indices {
                guard let e = eles[i] else { continue }
                if let sm = smoothed {
                    let delta = e - sm
                    if delta >= 2 { up[i] = delta; smoothed = e }
                    else if delta <= -2 { down[i] = -delta; smoothed = e }
                } else {
                    smoothed = e
                }
            }
        }
        routeAscentToEnd = [Double](repeating: 0, count: routeLine.count)
        routeDescentToEnd = [Double](repeating: 0, count: routeLine.count)
        var accUp = 0.0, accDown = 0.0
        for i in routeLine.indices.reversed() {
            routeAscentToEnd[i] = accUp
            routeDescentToEnd[i] = accDown
            accUp += up[i]
            accDown += down[i]
        }

        // Zwischenpunkte (ohne Start und Ziel) auf die Linie legen — das Ziel
        // steht schon unter „Noch", beim Rundkurs ist der letzte Punkt echt
        let total = routeCum.last ?? 0
        routeWaypointCum = route.waypoints.dropFirst().compactMap { wp in
            Self.nearestIndex(to: wp, in: routeLine, from: 0, to: routeLine.count - 1).map { routeCum[$0.index] }
        }.filter { $0 < total - 30 }

        // Richttempo je Aktivität (wie im Backend: SAC-Formel)
        switch route.activity {
        case "alpine_hiking": routeKmh = 3;   routeClimbPerH = 350
        case "running":       routeKmh = 8;   routeClimbPerH = 500
        case "bicycle":       routeKmh = 18;  routeClimbPerH = 600
        case "mtb":           routeKmh = 12;  routeClimbPerH = 500
        default:              routeKmh = 4.2; routeClimbPerH = 400
        }

        // Hinweise auf die eigene Linie legen: Das Backend misst „Meter ab
        // Start" entlang der vollen Geometrie, die App entlang der
        // ausgedünnten — auf langen Routen weichen beide um Dutzende Meter
        // ab. Der Lotpunkt der Hinweis-Koordinate ist die verlässliche Stelle.
        routeHints = route.hints.map { hint in
            guard routeLine.count >= 2,
                  let near = nearestOnRoute(to: hint.coordinate, from: 0, to: routeLine.count - 1),
                  near.distance <= 50 else { return hint }
            return TurnHint(at: near.doneM, coordinate: hint.coordinate, turn: hint.turn, exit: hint.exit)
        }.sorted { $0.at < $1.at }
        announced = [:]
        hintCue = nil
        arrived = false
        nearestRoutePoint = nil
        routeProgress = routeLine.count >= 2 && routeOrdered ? progress(doneM: 0) : nil
        updateNextHint()
    }

    /// Nächsten Hinweis bestimmen: der erste, dessen Stelle noch vor uns
    /// liegt (15 m Toleranz); Ansage-Stufen bei 150 m, 30 m und ≤ 15 m.
    private func updateNextHint() {
        guard let p = routeProgress else { nextHint = nil; return }
        guard let index = routeHints.firstIndex(where: { $0.at > p.doneM - 15 }) else {
            nextHint = nil; nextHintDistance = 0; return
        }
        let hint = routeHints[index]
        nextHint = hint
        nextHintDistance = max(0, hint.at - p.doneM)
        guard phase == .recording, !isOffRoute else { return }
        // Höchste fällige Stufe; alle darunter gelten als erledigt — sonst
        // käme nach „Jetzt links" noch „In 20 Metern links"
        var stages = announced[index] ?? []
        let due: (Int, HintCue.Stage)? =
            nextHintDistance <= 15 ? (2, .now) : nextHintDistance <= 30 ? (1, .near)
            : nextHintDistance <= 150 ? (0, .far) : nil
        if let (level, stage) = due, !stages.contains(where: { $0 >= level }) {
            stages.formUnion(0...level)
            announced[index] = stages
            cueSerial += 1
            hintCue = HintCue(hint: hint, stage: stage, serial: cueSerial)
        }
    }

    /// Route wieder entfernen — nach einer Routen-Aufzeichnung auf dem
    /// Start-Tab, damit das nächste Training ohne Leitlinie beginnt.
    func clearRoute() {
        routeName = nil
        routeSegments = []
        routeElevations = []
        routeLine = []
        routeCum = []
        routeAscentToEnd = []
        routeDescentToEnd = []
        routeWaypointCum = []
        routeProgress = nil
        routeHints = []
        nextHint = nil
        hintCue = nil
        announced = [:]
        arrived = false
        nearestRoutePoint = nil
        isOffRoute = false
        offRouteDistance = 0
    }

    // GPS läuft bewusst NICHT im Setup „warm": Der Start-Tab ist die
    // Landeseite der App — ein Warmlauf dort hiesse Dauer-GPS ab App-Start.
    // startRecording() schaltet es ein, stop()/teardown() wieder aus; die
    // ersten Sekunden bis zum Fix fängt der Genauigkeitsfilter (≤30 m) ab.

    func pause() {
        guard phase == .recording else { return }
        phase = .paused
        pauseBegan = Date()
    }

    func resume() {
        guard phase == .paused, let began = pauseBegan else { return }
        pausedTotal += Date().timeIntervalSince(began)
        skipDistanceOnce = true
        pauseBegan = nil
        phase = .recording
    }

    func finish() {
        guard phase == .recording || phase == .paused else { return }
        if let began = pauseBegan { pausedTotal += Date().timeIntervalSince(began); pauseBegan = nil }
        refreshElapsed()
        phase = .finished
        ticker?.invalidate()
        source.stop()
        gpsSource.stop()
        persistSnapshot()   // bleibt bis zum erfolgreichen Upload liegen
    }

    func teardown() {
        ticker?.invalidate()
        source.stop()
        gpsSource.stop()
    }

    /// Nach Speichern/Verwerfen in den Ausgangszustand — die Instanz lebt im
    /// Start-Tab weiter (Tab-Wurzel, `dismiss()` wirkt dort nicht). Ohne Reset
    /// blieb `phase == .finished`, `startRecording()` lief ins Leere und der
    /// nächste Start zeigte erneut die alte Zusammenfassung.
    func reset() {
        teardown()
        Self.clearSnapshot()
        phase = .setup
        hrState = .idle
        gpsState = .idle
        currentHR = nil
        samples = []
        track = []
        distanceMeters = 0
        elevationGain = 0
        startedAt = nil
        elapsed = 0
        recordingId = nil
        ownerClientId = nil
        skipDistanceOnce = false
        pausedTotal = 0
        pauseBegan = nil
        lastSnapshot = .distantPast
        lastSmoothedEle = nil
        lastKnownCoordinate = nil
        headingDegrees = nil
        // Route bewusst NICHT löschen: Sie gehört zur Tour-Ansicht und wird nur
        // beim ersten Erscheinen gesetzt — ein erneuter Start derselben Tour
        // braucht sie noch. Nur der Off-Route-Zustand wird zurückgesetzt.
        isOffRoute = false
        offRouteDistance = 0
        arrived = false
        nearestRoutePoint = nil
        announced = [:]
        hintCue = nil
        routeProgress = routeLine.count >= 2 && routeOrdered ? progress(doneM: 0) : nil
        updateNextHint()
    }

    // MARK: Intern — Herzfrequenz

    private func ingest(_ bpm: Int) {
        currentHR = bpm
        guard phase == .recording else { return }
        samples.append(HrSample(t: Date(), bpm: bpm))
    }

    // MARK: Intern — GPS

    private func ingest(_ point: TrackPoint) {
        // Beste bekannte Position — unabhängig von Phase und Track-Filter,
        // damit die Live-Karte sofort und immer zentrieren kann
        lastKnownCoordinate = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
        locationTick += 1

        guard phase == .recording, activity.usesGPS else { return }
        // Qualitäts-Schwelle für die Aufzeichnung (vorher in der Quelle)
        guard (point.acc ?? .infinity) <= 30 else { return }

        if let last = track.last, !skipDistanceOnce {
            let from = CLLocation(latitude: last.lat, longitude: last.lon)
            let to   = CLLocation(latitude: point.lat, longitude: point.lon)
            let d    = to.distance(from: from)
            let dt   = point.t.timeIntervalSince(last.t)

            // Jitter (< 2 m) und unplausible Sprünge verwerfen
            guard d >= 2 else { return }
            if dt > 0, d / dt > activity.maxSpeed { return }

            distanceMeters += d
        }
        skipDistanceOnce = false

        // Höhenmeter mit 2-m-Glättung gegen Barometer-/GPS-Rauschen
        if let ele = point.ele {
            if let smoothed = lastSmoothedEle {
                let delta = ele - smoothed
                if delta >= 2 {
                    elevationGain += delta
                    lastSmoothedEle = ele
                } else if delta <= -2 {
                    lastSmoothedEle = ele
                }
            } else {
                lastSmoothedEle = ele
            }
        }

        track.append(point)
        updateRouteProgress(point)
    }

    /// Routenführung (Phase 5.2): Position auf die Route projizieren — auf
    /// die Linienabschnitte (nicht nur Stützpunkte, sonst gälte man
    /// zwischen zwei weit entfernten Punkten als „neben der Route"),
    /// monoton (nie zurück), mit Fenster bis 300 m voraus; Abkürzungen
    /// springen vor, wenn man wieder nahe (< 60 m) an der Linie ist.
    /// Daraus Off-Route (Hysterese 100 m hinaus / 60 m zurück), Rest,
    /// Ankunft und Zielerkennung.
    private func updateRouteProgress(_ point: TrackPoint) {
        guard routeLine.count >= 2 else { return }
        let here = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)

        // Ungeordnete Route (OSM-Relation): nur Abstand zum nächsten Weg
        guard let current = routeProgress else {
            if let h = nearestOnRoute(to: here, from: 0, to: routeLine.count - 1) {
                nearestRoutePoint = h.point
                offRouteDistance = h.distance
                if isOffRoute { if h.distance < 60 { isOffRoute = false } }
                else if h.distance > 100 { isOffRoute = true }
            }
            return
        }

        // Fenster: 20 Stützpunkte zurück bis 300 m voraus
        let from = max(0, current.index - 20)
        var to = current.index
        while to + 1 < routeLine.count, routeCum[to + 1] - routeCum[current.index] <= 300 { to += 1 }
        // Bei fast gleichem Abstand (Hin- und Rückweg nebeneinander) gewinnt
        // die Stelle, die dem bisherigen Fortschritt am nächsten liegt
        var hit = nearestOnRoute(to: here, from: from, to: to, near: current.doneM)

        var newDone = current.doneM
        if let h = hit, h.distance <= 100 {
            newDone = max(current.doneM, h.doneM)
        } else {
            // Nicht im Fenster: ganze Route — eine Abkürzung nach vorn wird
            // übernommen, zurück nie; und nie in die letzten 15 %, solange die
            // erste Hälfte nicht gelaufen ist (Rundkurs: man kommt am Anfang
            // oft über den Schlussabschnitt zum Start)
            let total = routeCum.last ?? 0
            let global = nearestOnRoute(to: here, from: 0, to: routeLine.count - 1, near: current.doneM)
            hit = global
            if let g = global, g.distance <= 60, g.doneM > current.doneM,
               g.doneM < total * 0.85 || current.fraction > 0.5 {
                newDone = g.doneM
            }
        }

        if let h = hit {
            nearestRoutePoint = h.point
            offRouteDistance = h.distance
            if isOffRoute {
                if h.distance < 60 { isOffRoute = false }
            } else if h.distance > 100 {
                isOffRoute = true
            }
        }

        // Jeder Punkt: Rest und Ankunft hängen auch am eigenen Tempo
        routeProgress = progress(doneM: newDone)
        updateNextHint()

        // Angekommen: der letzte Routenpunkt ist erreicht (die Projektion
        // lässt das nur innerhalb von 100 m zu) oder — nahe am Ende — man
        // steht keine 30 m vom Ziel entfernt
        // … und nur, wenn tatsächlich mindestens die halbe Strecke gelaufen
        // wurde (sonst „Ziel erreicht" beim Start eines Rundkurses)
        if !arrived, let end = routeLine.last, let p = routeProgress,
           distanceMeters >= (routeCum.last ?? 0) * 0.5,
           p.leftM <= 0 || (p.fraction >= 0.9 && Self.meters(here, end) <= 30) {
            arrived = true
        }
    }

    /// Nächste Stelle auf der Route im Abschnittsbereich [from, to]:
    /// Lotpunkt auf den Abschnitt, Meter ab Start, Abstand.
    private func nearestOnRoute(to c: CLLocationCoordinate2D, from: Int, to: Int, near preferDoneM: Double? = nil)
        -> (doneM: Double, point: CLLocationCoordinate2D, distance: Double)? {
        guard routeLine.count >= 2, from <= to else { return nil }
        let kLat = 111_320.0, kLon = 111_320.0 * cos(c.latitude * .pi / 180)
        var best: (doneM: Double, point: CLLocationCoordinate2D, distance: Double)?
        var i = from
        while i <= min(to, routeLine.count - 2) {
            // Ungeordnete Segmente: die Verbindung zwischen zwei Wegen ist kein Weg
            if routeBreaks.contains(i + 1) { i += 1; continue }
            let a = routeLine[i], b = routeLine[i + 1]
            let ax = (a.longitude - c.longitude) * kLon, ay = (a.latitude - c.latitude) * kLat
            let bx = (b.longitude - c.longitude) * kLon, by = (b.latitude - c.latitude) * kLat
            let dx = bx - ax, dy = by - ay
            let len2 = dx * dx + dy * dy
            let t = len2 == 0 ? 0 : min(max(-(ax * dx + ay * dy) / len2, 0), 1)
            let px = ax + t * dx, py = ay + t * dy
            let d = (px * px + py * py).squareRoot()
            let doneM = routeCum[i] + t * (routeCum[i + 1] - routeCum[i])
            var better = d < (best?.distance ?? .infinity)
            if let b0 = best, let prefer = preferDoneM, abs(d - b0.distance) <= 5 {
                better = abs(doneM - prefer) < abs(b0.doneM - prefer)
            }
            if better {
                let point = CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                                   longitude: a.longitude + (b.longitude - a.longitude) * t)
                best = (doneM, point, d)
            }
            i += 1
        }
        // Letzter Stützpunkt (Ziel) als eigener Kandidat
        if to >= routeLine.count - 1 {
            let d = Self.meters(c, routeLine[routeLine.count - 1])
            if d < (best?.distance ?? .infinity) {
                best = (routeCum[routeLine.count - 1], routeLine[routeLine.count - 1], d)
            }
        }
        return best
    }

    /// Kennzahlen an der Stelle `doneM` (Meter ab Start).
    private func progress(doneM: Double) -> RouteProgress {
        let total = routeCum.last ?? 0
        let done = min(max(doneM, 0), total)
        // Stützpunkt, bis zu dem die Route abgeschritten ist (Zeichnen, Höhen)
        var index = 0
        while index + 1 < routeCum.count, routeCum[index + 1] <= done { index += 1 }
        let left = max(0, total - done)
        let ascentLeft = routeAscentToEnd[index]
        let descentLeft = routeDescentToEnd[index]

        // SAC: t = max(horizontal, vertikal) + min(...)/2
        let horiz = left / 1000 / routeKmh
        let climb = ascentLeft / routeClimbPerH
        var hours = max(horiz, climb) + min(horiz, climb) / 2
        // Ab 500 m mit dem eigenen Schnitt mischen
        if distanceMeters > 500, elapsed > 60 {
            let ownSpeed = distanceMeters / elapsed   // m/s
            if ownSpeed > 0.3 {
                hours = (hours + left / ownSpeed / 3600) / 2
            }
        }
        let eta = left > 0 ? Int((hours * 60).rounded()) : 0

        let next = routeWaypointCum.first { $0 > done + 30 }.map { $0 - done }
        return RouteProgress(index: index, doneM: done, leftM: left,
                             ascentLeftM: ascentLeft, descentLeftM: descentLeft,
                             etaMinutes: eta, nextWaypointM: next,
                             fraction: total > 0 ? done / total : 0)
    }

    /// Nächster Stützpunkt im Bereich [from, to] (optional ausgedünnt).
    private static func nearestIndex(to c: CLLocationCoordinate2D, in line: [CLLocationCoordinate2D],
                                     from: Int, to: Int, stride: Int = 1) -> (index: Int, distance: Double)? {
        guard !line.isEmpty, from <= to else { return nil }
        var best = from, bestD = Double.infinity
        var i = from
        while i <= to {
            let d = meters(c, line[i])
            if d < bestD { bestD = d; best = i }
            i += stride
        }
        return (best, bestD)
    }

    /// Abstand zweier Koordinaten (äquirektangular — für Nachbarpunkte metergenau).
    private static func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dLat = (b.latitude - a.latitude) * 111_320
        let dLon = (b.longitude - a.longitude) * 111_320 * cos(a.latitude * .pi / 180)
        return (dLat * dLat + dLon * dLon).squareRoot()
    }

    // MARK: Intern — Zeit & Snapshot

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard phase == .recording else { return }
        refreshElapsed()
        if Date().timeIntervalSince(lastSnapshot) >= 30 {
            persistSnapshot()
        }
    }

    private func refreshElapsed() {
        guard let start = startedAt else { return }
        elapsed = Date().timeIntervalSince(start) - pausedTotal
    }

    // MARK: Snapshot (Crash-Recovery)

    struct Snapshot: Codable {
        let activity: WorkoutActivity
        let startedAt: Date
        let elapsed: TimeInterval
        let samples: [HrSample]
        var track: [TrackPoint]? = nil
        var distanceMeters: Double? = nil
        var elevationGain: Double? = nil
        var recordingId: String? = nil
        var ownerClientId: String? = nil
    }

    private static var snapshotURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("active-workout.json")
    }

    private func persistSnapshot() {
        guard let start = startedAt else { return }
        lastSnapshot = Date()
        let snap = Snapshot(activity: activity, startedAt: start,
                            elapsed: elapsed, samples: samples,
                            track: track.isEmpty ? nil : track,
                            distanceMeters: distanceMeters > 0 ? distanceMeters : nil,
                            elevationGain: elevationGain > 0 ? elevationGain : nil,
                            recordingId: recordingId, ownerClientId: ownerClientId)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: Self.snapshotURL, options: .atomic)
        }
    }

    static func clearSnapshot() {
        try? FileManager.default.removeItem(at: snapshotURL)
    }

    /// Liegt ein unterbrochenes (nicht hochgeladenes) Training vor?
    static func pendingSnapshot() -> Snapshot? {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data),
              snap.samples.count >= 10 || (snap.track?.count ?? 0) >= 10 else { return nil }
        return snap
    }
}
