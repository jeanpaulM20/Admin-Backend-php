import Foundation
import CoreLocation

// MARK: - Modelle

/// Ein gefilterter GPS-Punkt der Aufzeichnung.
struct TrackPoint: Codable {
    let t:   Date
    let lat: Double
    let lon: Double
    let ele: Double?
    let acc: Double?
}

enum LocationSourceState: Equatable {
    case idle
    case requesting          // Berechtigung angefragt
    case active(accuracy: Double?)   // liefert Punkte (letzte Genauigkeit in m)
    case denied

    var label: String {
        switch self {
        case .idle:       return "GPS aus"
        case .requesting: return "Warte auf GPS-Freigabe…"
        case .active(let a):
            if let a { return "GPS aktiv (±\(Int(a)) m)" }
            return "GPS aktiv"
        case .denied:     return "Kein Standort-Zugriff (Einstellungen)"
        }
    }

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}

/// Quelle für Standortdaten — echtes GPS oder Simulation (Demo/Simulator).
@MainActor
protocol LocationSource: AnyObject {
    var onPoint: ((TrackPoint) -> Void)? { get set }
    var onStateChange: ((LocationSourceState) -> Void)? { get set }
    func start()
    func stop()
}

// MARK: - CoreLocation (echtes GPS)

/// Fitness-Tracking-Konfiguration: beste Genauigkeit, läuft im Hintergrund
/// weiter, pausiert nie automatisch. Punkte mit schlechter Genauigkeit
/// (> 30 m) werden verworfen (GPS-Drift).
final class CoreLocationSource: NSObject, LocationSource {
    var onPoint: ((TrackPoint) -> Void)?
    var onStateChange: ((LocationSourceState) -> Void)?

    private let manager = CLLocationManager()
    private var started = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        started = true
        switch manager.authorizationStatus {
        case .notDetermined:
            emit(.requesting)
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        default:
            emit(.denied)
        }
    }

    func stop() {
        started = false
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
        emit(.idle)
    }

    private func beginUpdates() {
        // Hintergrund-Updates erst nach erteilter Berechtigung aktivieren
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        emit(.active(accuracy: nil))
    }

    private func emit(_ state: LocationSourceState) {
        Task { @MainActor in self.onStateChange?(state) }
    }
}

extension CoreLocationSource: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard started else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: beginUpdates()
        case .denied, .restricted:                    emit(.denied)
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            // Drift-Filter: unbrauchbare Punkte verwerfen
            guard loc.horizontalAccuracy > 0, loc.horizontalAccuracy <= 30 else { continue }
            let point = TrackPoint(
                t:   loc.timestamp,
                lat: loc.coordinate.latitude,
                lon: loc.coordinate.longitude,
                ele: loc.verticalAccuracy > 0 ? loc.altitude : nil,
                acc: loc.horizontalAccuracy
            )
            Task { @MainActor in
                self.onStateChange?(.active(accuracy: point.acc))
                self.onPoint?(point)
            }
        }
    }
}

// MARK: - Simulation (Demo-Modus & Simulator)

/// Simuliert einen Lauf entlang einer Runde am Sihl-Ufer (~2,6 m/s)
/// mit leichtem Höhenprofil — für Demo-Modus und Simulator-Tests.
final class SimulatedLocationSource: LocationSource {
    var onPoint: ((TrackPoint) -> Void)?
    var onStateChange: ((LocationSourceState) -> Void)?

    private var timer: Timer?
    private var tick = 0
    // Start: Sihlwald-Gegend
    private let baseLat = 47.320
    private let baseLon = 8.517

    func start() {
        onStateChange?(.active(accuracy: 5))
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.tick += 1
                // Runde: Ellipse, ~2,6 m/s Bahngeschwindigkeit
                let angle = Double(self.tick) * 0.004
                let lat = self.baseLat + 0.004 * sin(angle)
                let lon = self.baseLon + 0.006 * cos(angle)
                let ele = 470.0 + 25.0 * sin(angle * 2)   // sanfte Hügel
                self.onPoint?(TrackPoint(t: Date(), lat: lat, lon: lon, ele: ele, acc: 5))
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onStateChange?(.idle)
    }
}
