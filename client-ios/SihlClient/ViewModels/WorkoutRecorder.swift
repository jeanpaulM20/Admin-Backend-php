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

    // Tour folgen (T3): Route-Overlay + Off-Route-Erkennung
    private(set) var routeName: String?

    /// Letzte empfangene Position (auch ungenaue) — fürs Karten-Zentrieren.
    private(set) var lastKnownCoordinate: CLLocationCoordinate2D?
    /// Zähler je Positions-Update; die View beobachtet ihn für den Follow-Modus.
    private(set) var locationTick = 0
    /// Blickrichtung in Grad (0 = Nord), vom Kompass bzw. simuliert.
    private(set) var headingDegrees: Double?
    private(set) var routeSegments: [[CLLocationCoordinate2D]] = []
    private(set) var isOffRoute = false
    private(set) var offRouteDistance: Double = 0
    private var routeCheckPoints: [CLLocationCoordinate2D] = []
    private var pointsSinceRouteCheck = 0

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
    var hrPoints: [HrPoint] {
        let fmt = ISO8601DateFormatter()
        return samples.map { HrPoint(time: fmt.string(from: $0.t), value: Double($0.bpm)) }
    }

    var trackCoordinates: [CLLocationCoordinate2D] {
        track.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    // MARK: Steuerung

    func connectSensor() { source.start() }

    func startRecording(_ activity: WorkoutActivity) {
        guard phase == .setup else { return }
        self.activity = activity
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
        let all = route.segments.flatMap { $0 }
        let stride = max(1, all.count / 800)
        routeCheckPoints = all.enumerated().compactMap { $0.offset % stride == 0 ? $0.element : nil }
    }

    /// GPS-Berechtigung/Fix schon im Setup anstoßen (Outdoor-Aktivität gewählt).
    func prepareGPS() { gpsSource.start() }
    func stopGPSPreparation() { if phase == .setup { gpsSource.stop() } }

    func pause() {
        guard phase == .recording else { return }
        phase = .paused
        pauseBegan = Date()
    }

    func resume() {
        guard phase == .paused, let began = pauseBegan else { return }
        pausedTotal += Date().timeIntervalSince(began)
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

        if let last = track.last {
            let from = CLLocation(latitude: last.lat, longitude: last.lon)
            let to   = CLLocation(latitude: point.lat, longitude: point.lon)
            let d    = to.distance(from: from)
            let dt   = point.t.timeIntervalSince(last.t)

            // Jitter (< 2 m) und unplausible Sprünge verwerfen
            guard d >= 2 else { return }
            if dt > 0, d / dt > activity.maxSpeed { return }

            distanceMeters += d
        }

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
        updateOffRoute(point)
    }

    /// Off-Route-Check (gedrosselt, alle 5 Punkte): nächster Routenpunkt.
    /// Hysterese 100 m raus / 60 m zurück, damit der Hinweis nicht flattert.
    private func updateOffRoute(_ point: TrackPoint) {
        guard !routeCheckPoints.isEmpty else { return }
        pointsSinceRouteCheck += 1
        guard pointsSinceRouteCheck >= 5 || track.count <= 1 else { return }
        pointsSinceRouteCheck = 0

        let here = CLLocation(latitude: point.lat, longitude: point.lon)
        var minDist = Double.greatestFiniteMagnitude
        for rp in routeCheckPoints {
            let d = here.distance(from: CLLocation(latitude: rp.latitude, longitude: rp.longitude))
            if d < minDist { minDist = d }
        }
        offRouteDistance = minDist
        if isOffRoute {
            if minDist < 60 { isOffRoute = false }
        } else if minDist > 100 {
            isOffRoute = true
        }
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
                            elevationGain: elevationGain > 0 ? elevationGain : nil)
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
