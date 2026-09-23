import Foundation
import CoreLocation
import Observation

/// Einmalige Standortabfrage für die Touren-Karte („Wo bin ich?").
/// Bewusst getrennt von den kontinuierlichen Quellen der Aufzeichnung:
/// Hier wird nur ein einziger Fix geholt und die Ortung sofort wieder
/// beendet — kein Dauer-GPS beim Betrachten der Karte.
@MainActor @Observable
final class OneShotLocator: NSObject, CLLocationManagerDelegate {
    enum Outcome { case located(CLLocationCoordinate2D), denied, failed }

    private let manager = CLLocationManager()
    private var pending: ((Outcome) -> Void)?
    private(set) var isLocating = false

    var isAuthorized: Bool {
        manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways
    }
    var isDenied: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Fragt bei Bedarf die Berechtigung an und liefert genau einen Fix.
    func locate(_ completion: @escaping (Outcome) -> Void) {
        guard !isLocating else { return }
        pending = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()   // Antwort kommt über den Delegate
        case .denied, .restricted:
            finish(.denied)
        default:
            isLocating = true
            manager.requestLocation()
        }
    }

    private func finish(_ outcome: Outcome) {
        isLocating = false
        let cb = pending
        pending = nil
        cb?(outcome)
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.pending != nil else { return }
            if self.isAuthorized { manager.requestLocation() }
            else if self.isDenied { self.finish(.denied) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.last?.coordinate
        Task { @MainActor in
            if let coord { self.finish(.located(coord)) } else { self.finish(.failed) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(.failed) }
    }
}
