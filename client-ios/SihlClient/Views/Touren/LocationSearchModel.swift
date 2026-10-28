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
    /// Suchtext, zu dem `suggestions` gehören (leer = keine gültigen)
    private var suggestionsQuery = ""
    /// Zuletzt angefragter Suchtext — spätere Antworten älterer Anfragen verwerfen
    private var currentQuery = ""
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Bei jeder Eingabe aufrufen; leerer Text räumt die Vorschläge weg.
    func update(query: String, near center: CLLocationCoordinate2D) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            // Laufende Anfrage stoppen, sonst tauchen alte Vorschläge wieder auf
            clear()
            return
        }
        currentQuery = trimmed
        completer.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
        completer.queryFragment = query
    }

    func clear() {
        currentQuery = ""
        suggestionsQuery = ""
        suggestions = []
        completer.cancel()
        completer.queryFragment = ""
    }

    /// Oberster Vorschlag — nur wenn er zum aktuellen Suchtext gehört
    /// (die „Suchen"-Taste springt sonst zu einem veralteten Ort).
    func topSuggestion(for query: String) -> Suggestion? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed == suggestionsQuery else { return nil }
        return suggestions.first
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
            // Obergrenze 0.8° (≈ 90 km): Täler und Kantone bleiben ganz
            // sichtbar, ein Land zoomt nicht ins Leere
            let radius = (item.placemark.region as? CLCircularRegion)?.radius ?? 300
            span = min(max(radius * 2.8 / 111_000, 0.008), 0.8)
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
        let query = completer.queryFragment.trimmingCharacters(in: .whitespaces)
        // Feld inzwischen geleert oder Text geändert → Antwort verwerfen
        guard !currentQuery.isEmpty, query == currentQuery else { return }
        suggestionsQuery = query
        suggestions = completer.results.prefix(5).enumerated().map { i, c in
            Suggestion(id: i, title: c.title, subtitle: c.subtitle, completion: c)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestionsQuery = ""
        suggestions = []
    }
}
