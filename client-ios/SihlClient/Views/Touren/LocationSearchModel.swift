import MapKit
import Observation

// MARK: - LocationSearchModel (Live-Ortsvorschläge für die Touren-Suche)

/// Kapselt MKLocalSearchCompleter: liefert während des Tippens Ortsvorschläge
/// (Adressen + Orte, bevorzugt nahe der aktuellen Kartenregion) und löst eine
/// gewählte Vervollständigung in Koordinaten auf.
@Observable
final class LocationSearchModel: NSObject, MKLocalSearchCompleterDelegate {

    struct Suggestion: Identifiable {
        let id: Int
        let title: String
        let subtitle: String
        let completion: MKLocalSearchCompletion
    }

    private(set) var suggestions: [Suggestion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Bei jeder Eingabe aufrufen; leerer Text räumt die Vorschläge weg.
    func update(query: String, near center: CLLocationCoordinate2D) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            suggestions = []
            return
        }
        completer.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
        completer.queryFragment = query
    }

    func clear() {
        suggestions = []
    }

    /// Aufgelöster Suchtreffer: exakte Koordinate, Anzeigename und ein zur
    /// Grösse des Treffers passender Kartenausschnitt (Adresse/POI ≈ 1 km,
    /// Ortschaft so weit, dass sie ganz sichtbar ist).
    struct Place {
        let coordinate: CLLocationCoordinate2D
        let name: String
        /// Kartenausschnitt in Grad (Breite = Länge).
        let span: Double

        init(item: MKMapItem, fallbackName: String) {
            coordinate = item.placemark.coordinate
            // Ortschaft anhängen („Bahnhofstrasse 1, Kilchberg“) — so ist
            // sofort sichtbar, in welchem Ort der Treffer liegt
            let base = item.name ?? fallbackName
            if let town = item.placemark.locality, !base.localizedCaseInsensitiveContains(town) {
                name = "\(base), \(town)"
            } else {
                name = base
            }
            // MapKit liefert zu jedem Treffer dessen Ausdehnung als Kreis:
            // Hausnummer ≈ 50 m, Ortschaft einige Kilometer
            let radius = (item.placemark.region as? CLCircularRegion)?.radius ?? 300
            span = min(max(radius * 2.8 / 111_000, 0.008), 0.15)
        }
    }

    /// Vervollständigung in einen Treffer auflösen (nil = nicht auffindbar).
    func resolve(_ suggestion: Suggestion) async -> Place? {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let response = try? await MKLocalSearch(request: request).start()
        return response?.mapItems.first.map { Place(item: $0, fallbackName: suggestion.title) }
    }

    /// Freitext-Suche („Suchen“-Taste ohne gewählten Vorschlag).
    func search(_ query: String, near center: CLLocationCoordinate2D) async -> Place? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
        let response = try? await MKLocalSearch(request: request).start()
        return response?.mapItems.first.map { Place(item: $0, fallbackName: query) }
    }

    // MARK: MKLocalSearchCompleterDelegate (Callbacks auf dem Main Thread)

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.prefix(5).enumerated().map { i, c in
            Suggestion(id: i, title: c.title, subtitle: c.subtitle, completion: c)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
