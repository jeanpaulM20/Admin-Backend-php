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

    /// Vervollständigung in Koordinaten auflösen (nil = nicht auffindbar).
    func resolve(_ suggestion: Suggestion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let response = try? await MKLocalSearch(request: request).start()
        return response?.mapItems.first?.placemark.coordinate
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
