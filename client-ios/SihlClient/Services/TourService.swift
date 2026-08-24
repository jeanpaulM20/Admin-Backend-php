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

    var networkLabel: String? { TourDetail.networkLabel(network) }
}

/// Detail einer Route: Geometrie als Segmente. OSM-Relationen liefern die
/// Segmente ungeordnet; generierte Rundtouren (T4) und GPX-Importe sind
/// geordnet (ein Segment bzw. Segmentfolge).
struct TourDetail: Identifiable, Hashable {
    let id: String
    let name: String
    let activity: String
    let network: String?
    let operatorName: String?
    let description: String?
    let distanceKm: Double?
    let durationMin: Int?
    let difficulty: String?
    let elevationGain: Int?
    let segments: [[CLLocationCoordinate2D]]
    /// Höhen je Segmentpunkt (parallel zu `segments`), falls die Quelle sie liefert.
    let elevations: [[Double?]]

    init(id: String, name: String, activity: String, network: String? = nil,
         operatorName: String? = nil, description: String? = nil,
         distanceKm: Double? = nil, durationMin: Int? = nil,
         difficulty: String? = nil, elevationGain: Int? = nil,
         segments: [[CLLocationCoordinate2D]], elevations: [[Double?]] = []) {
        self.id = id
        self.name = name
        self.activity = activity
        self.network = network
        self.operatorName = operatorName
        self.description = description
        self.distanceKm = distanceKm
        self.durationMin = durationMin
        self.difficulty = difficulty
        self.elevationGain = elevationGain
        self.segments = segments
        self.elevations = elevations
    }

    init?(json: [String: Any]) {
        guard let name = json["name"] as? String else { return nil }
        var segs: [[CLLocationCoordinate2D]] = []
        var eles: [[Double?]] = []
        for seg in (json["segments"] as? [[[String: Any]]] ?? []) {
            var coords: [CLLocationCoordinate2D] = []
            var segEles: [Double?] = []
            for p in seg {
                guard let lat = Double("\(p["lat"] ?? "")"),
                      let lon = Double("\(p["lon"] ?? "")") else { continue }
                coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                segEles.append(Double("\(p["ele"] ?? "")"))
            }
            if coords.count >= 2 { segs.append(coords); eles.append(segEles) }
        }
        self.init(
            id: "\(json["id"] ?? UUID().uuidString)",
            name: name,
            activity: json["activity"] as? String ?? "hiking",
            network: json["network"] as? String,
            operatorName: json["operator"] as? String,
            description: json["description"] as? String,
            distanceKm: Double("\(json["distanceKm"] ?? "")"),
            durationMin: Int("\(json["durationMin"] ?? "")"),
            difficulty: json["difficulty"] as? String,
            elevationGain: Int("\(json["elevationGain"] ?? "")"),
            segments: segs, elevations: eles
        )
    }

    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var networkLabel: String? { Self.networkLabel(network) }

    static func networkLabel(_ network: String?) -> String? {
        switch network {
        case "lwn", "lcn": return "Lokale Route"
        case "rwn", "rcn": return "Regionale Route"
        case "nwn", "ncn": return "Nationale Route"
        default:           return nil
        }
    }
}

// MARK: - TourRoute (Übergabe an den Workout-Recorder, T3)

/// Eine Route, der beim Aufzeichnen gefolgt wird (graue Linie + Off-Route-Hinweis).
struct TourRoute {
    let name: String
    let segments: [[CLLocationCoordinate2D]]
    let distanceKm: Double?
    let activity: String        // "hiking" | "bicycle"

    /// Vorausgewählte Aufnahme-Aktivität.
    var workoutActivity: WorkoutActivity { activity == "bicycle" ? .rad : .wandern }
}

extension TourDetail {
    var asRoute: TourRoute {
        TourRoute(name: name, segments: segments, distanceKm: distanceKm, activity: activity)
    }
}

// MARK: - TourService

/// Touren-Discovery (T1) + Rundtouren-Generator (T4, BRouter/OSM).
/// Datenquelle: OpenStreetMap (ODbL) über den Backend-Proxy.
struct TourService {
    static let shared = TourService()
    private init() {}

    func tours(clientId: String, lat: Double, lon: Double,
               radiusKm: Double, activity: WorkoutActivity) async throws -> [Tour] {
        let act = activity == .rad ? "rad" : "wandern"
        return try await APIClient.shared
            .getJSONArray("/api/client/tours/\(clientId)?lat=\(lat)&lon=\(lon)&radiusKm=\(radiusKm)&activity=\(act)",
                          timeout: 45)
            .compactMap { Tour(json: $0) }
    }

    func detail(clientId: String, tourId: String) async throws -> TourDetail? {
        guard let json = try await APIClient.shared
            .getJSONObject("/api/client/tours/\(clientId)/\(tourId)", timeout: 60) else { return nil }
        return TourDetail(json: json)
    }

    /// Rundtour ab Startpunkt generieren (T4, geordnete Route inkl. Höhen).
    func roundtrip(clientId: String, lat: Double, lon: Double,
                   distanceKm: Double, activity: WorkoutActivity) async throws -> TourDetail? {
        let body: [String: Any] = [
            "lat": lat, "lon": lon, "distanceKm": distanceKm,
            "activity": activity == .rad ? "rad" : "wandern",
        ]
        guard let json = try await APIClient.shared
            .postJSONObject("/api/client/tours/roundtrip/\(clientId)", body: body, timeout: 60) else { return nil }
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

    /// Demo-Rundtour: Kreis um den Startpunkt mit synthetischem Höhenprofil.
    static func demoRoundtrip(lat: Double, lon: Double, distanceKm: Double,
                              activity: WorkoutActivity) -> TourDetail {
        let rKm = distanceKm / (2 * .pi)
        let latKm = 110.574, lonKm = 111.32 * cos(lat * .pi / 180)
        let cLat = lat + rKm / latKm
        var seg: [[String: Any]] = []
        for i in 0...72 {
            let phi = Double(i) / 72 * 2 * .pi + .pi
            seg.append([
                "lat": cLat + (rKm / latKm) * cos(phi),
                "lon": lon + (rKm / lonKm) * sin(phi),
                "ele": 460 + 40 * sin(phi * 2),
            ])
        }
        return TourDetail(json: [
            "id": "rt-demo", "name": String(format: "Rundtour · %.1f km", distanceKm),
            "activity": activity == .rad ? "bicycle" : "hiking",
            "distanceKm": distanceKm,
            "durationMin": Int(distanceKm / (activity == .rad ? 15 : 4.2) * 60),
            "difficulty": distanceKm < 8 ? "Leicht" : (distanceKm < 16 ? "Mittel" : "Schwer"),
            "elevationGain": 120,
            "segments": [seg],
        ])!
    }
}
