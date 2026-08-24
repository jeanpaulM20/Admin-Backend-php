import Foundation
import CoreLocation

// MARK: - Modelle

/// Eine markierte Route aus OSM (Listen-Eintrag der Touren-Discovery).
struct Tour: Identifiable, Hashable {
    let id: String
    let name: String
    let ref: String?
    let activity: String        // "hiking" | "bicycle"
    let network: String?        // lwn/rwn/nwn = lokal/regional/national
    let distanceKm: Double?
    let durationMin: Int?
    let difficulty: String?
    let lat: Double
    let lon: Double

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String ?? (json["id"]).map({ "\($0)" }),
              let name = json["name"] as? String,
              let lat = Double("\(json["lat"] ?? "")"),
              let lon = Double("\(json["lon"] ?? "")") else { return nil }
        self.id = id
        self.name = name
        self.ref = json["ref"] as? String
        self.activity = json["activity"] as? String ?? "hiking"
        self.network = json["network"] as? String
        self.distanceKm = Double("\(json["distanceKm"] ?? "")")
        self.durationMin = Int("\(json["durationMin"] ?? "")")
        self.difficulty = json["difficulty"] as? String
        self.lat = lat
        self.lon = lon
    }

    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var networkLabel: String? {
        switch network {
        case "lwn", "lcn": return "Lokale Route"
        case "rwn", "rcn": return "Regionale Route"
        case "nwn", "ncn": return "Nationale Route"
        default:           return nil
        }
    }
}

/// Detail einer Route: Geometrie als Segmente (OSM-Reihenfolge nicht
/// garantiert — Segmente einzeln zeichnen, Länge ist die Summe).
struct TourDetail {
    let id: String
    let name: String
    let activity: String
    let network: String?
    let operatorName: String?
    let description: String?
    let distanceKm: Double?
    let durationMin: Int?
    let difficulty: String?
    let segments: [[CLLocationCoordinate2D]]

    init?(json: [String: Any]) {
        guard let name = json["name"] as? String else { return nil }
        self.id = "\(json["id"] ?? "")"
        self.name = name
        self.activity = json["activity"] as? String ?? "hiking"
        self.network = json["network"] as? String
        self.operatorName = json["operator"] as? String
        self.description = json["description"] as? String
        self.distanceKm = Double("\(json["distanceKm"] ?? "")")
        self.durationMin = Int("\(json["durationMin"] ?? "")")
        self.difficulty = json["difficulty"] as? String
        self.segments = (json["segments"] as? [[[String: Any]]] ?? []).map { seg in
            seg.compactMap { p in
                guard let lat = Double("\(p["lat"] ?? "")"),
                      let lon = Double("\(p["lon"] ?? "")") else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }.filter { $0.count >= 2 }
    }
}

// MARK: - TourService

/// Touren-Discovery (T1, s. KONZEPT-TOUREN.md): markierte OSM-Routen über
/// den Backend-Proxy (Overpass + Cache). Datenquelle: OpenStreetMap (ODbL).
struct TourService {
    static let shared = TourService()
    private init() {}

    func tours(clientId: String, lat: Double, lon: Double,
               radiusKm: Double, activity: WorkoutActivity) async throws -> [Tour] {
        let act = activity == .rad ? "rad" : "wandern"
        return try await APIClient.shared
            .getJSONArray("/api/client/tours/\(clientId)?lat=\(lat)&lon=\(lon)&radiusKm=\(radiusKm)&activity=\(act)")
            .compactMap { Tour(json: $0) }
    }

    func detail(clientId: String, tourId: String) async throws -> TourDetail? {
        guard let json = try await APIClient.shared
            .getJSONObject("/api/client/tours/\(clientId)/\(tourId)") else { return nil }
        return TourDetail(json: json)
    }

    // MARK: - Demo-Daten (Demo-Modus: kein Backend-Zugriff)

    static func demoTours() -> [Tour] {
        [
            Tour(json: ["id": "demo-t1", "name": "Sihluferweg Adliswil–Langnau",
                        "activity": "hiking", "network": "lwn", "distanceKm": 6.8,
                        "durationMin": 97, "difficulty": "Leicht",
                        "lat": 47.309, "lon": 8.53]),
            Tour(json: ["id": "demo-t2", "name": "Uetliberg Panoramaweg",
                        "activity": "hiking", "network": "rwn", "distanceKm": 12.4,
                        "durationMin": 177, "difficulty": "Mittel",
                        "lat": 47.35, "lon": 8.49]),
        ].compactMap { $0 }
    }

    static func demoDetail(_ id: String) -> TourDetail? {
        // Einfacher Streckenzug entlang der Sihl
        let base: [(Double, Double)] = [
            (47.320, 8.525), (47.316, 8.527), (47.311, 8.528),
            (47.306, 8.531), (47.300, 8.534), (47.294, 8.538),
        ]
        return TourDetail(json: [
            "id": id,
            "name": id == "demo-t2" ? "Uetliberg Panoramaweg" : "Sihluferweg Adliswil–Langnau",
            "activity": "hiking", "network": "lwn",
            "distanceKm": id == "demo-t2" ? 12.4 : 6.8,
            "durationMin": id == "demo-t2" ? 177 : 97,
            "difficulty": id == "demo-t2" ? "Mittel" : "Leicht",
            "description": "Demo-Route entlang der Sihl.",
            "segments": [base.map { ["lat": $0.0, "lon": $0.1] }],
        ])
    }
}
