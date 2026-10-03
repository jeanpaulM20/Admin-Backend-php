import Foundation
import Observation

// MARK: - RecordingLauncher (Routenplaner Phase 5.1)

/// App-weiter Startbefehl für „Tour starten": Die Aufzeichnung hat in der
/// App genau einen Ort — den Tab „Start" mit seinem Recorder. Planer,
/// Tour-Detail und Assistent legen hier die Route ab; der Tab-Container
/// wechselt auf „Start", und die Startseite übernimmt die Route und
/// startet die Aufzeichnung (Countdown). So gibt es nie eine zweite Kopie
/// der Aufzeichnung in einem anderen Tab.
@MainActor @Observable
final class RecordingLauncher {
    /// Route, die auf der Startseite übernommen werden soll.
    private(set) var pendingRoute: TourRoute?
    /// Zählt Startbefehle — Views reagieren auf die Änderung (Tab-Wechsel,
    /// Sheets schliessen), auch wenn dieselbe Route zweimal gestartet wird.
    private(set) var requestCount = 0

    func start(_ route: TourRoute) {
        pendingRoute = route
        requestCount += 1
    }

    /// Die Startseite holt die Route genau einmal ab.
    func takePendingRoute() -> TourRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }
}
