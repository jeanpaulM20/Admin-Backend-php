import Foundation
import CoreLocation

// MARK: - Modelle

/// Aktivitäten der Touren-Discovery. Der Rohwert ist zugleich der
/// API-Parameter des Backend-Proxys (dort auf Overpass-Selektoren gemappt).
enum TourActivity: String, CaseIterable, Identifiable {
    case wandern, joggen, rennrad, mtb, vitaparcours, finnenbahn

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wandern:      return "Wandern"
        case .joggen:       return "Joggen"
        case .rennrad:      return "Rennrad"
        case .mtb:          return "MTB"
        case .vitaparcours: return "Vita Parcours"
        case .finnenbahn:   return "Finnenbahn"
        }
    }

    var icon: String {
        switch self {
        case .wandern:      return "figure.hiking"
        case .joggen:       return "figure.run"
        case .rennrad:      return "bicycle"
        case .mtb:          return "figure.outdoor.cycle"
        case .vitaparcours: return "figure.strengthtraining.functional"
        case .finnenbahn:   return "figure.track.and.field"
        }
    }

    /// Passende Aufnahme-Aktivität für den Workout-Recorder.
    var workoutActivity: WorkoutActivity {
        switch self {
        case .wandern, .vitaparcours: return .wandern
        case .joggen, .finnenbahn:    return .joggen
        case .rennrad, .mtb:          return .rad
        }
    }

    /// Vorauswahl im Rundtouren-Generator passend zur Discovery-Aktivität.
    var roundtrip: RoundtripActivity {
        switch self {
        case .wandern, .vitaparcours: return .wandern
        case .joggen, .finnenbahn:    return .joggen
        case .rennrad:                return .rennrad
        case .mtb:                    return .mtb
        }
    }

    /// Aktivität aus dem Backend-Wert (`activity` in Tour/TourDetail).
    init(backendValue: String) {
        switch backendValue {
        case "bicycle":       self = .rennrad
        case "mtb":           self = .mtb
        case "running":       self = .joggen
        case "fitness_trail": self = .vitaparcours
        case "finnenbahn":    self = .finnenbahn
        default:              self = .wandern
        }
    }
}

/// Aktivitäten des Rundtouren-Generators — alles, was BRouter sinnvoll
/// routen kann. Vita Parcours und Finnenbahnen sind feste Anlagen und
/// darum bewusst nicht generierbar. Rohwert = API-Parameter.
enum RoundtripActivity: String, CaseIterable, Identifiable {
    case wandern, joggen, rennrad, gravel, mtb

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wandern: return "Wandern"
        case .joggen:  return "Joggen"
        case .rennrad: return "Rennrad"
        case .gravel:  return "Gravel"
        case .mtb:     return "MTB"
        }
    }

    var icon: String {
        switch self {
        case .wandern: return "figure.hiking"
        case .joggen:  return "figure.run"
        case .rennrad: return "bicycle"
        case .gravel:  return "bicycle.circle"
        case .mtb:     return "figure.outdoor.cycle"
        }
    }

    /// Richtgeschwindigkeit für die Demo-Dauerberechnung (km/h).
    var kmh: Double {
        switch self {
        case .wandern: return 4.2
        case .joggen:  return 8
        case .rennrad: return 20
        case .gravel:  return 16
        case .mtb:     return 12
        }
    }

    /// Backend-Aktivitätswert der generierten Route (Icons/Recorder-Mapping).
    var osmValue: String {
        switch self {
        case .wandern: return "hiking"
        case .joggen:  return "running"
        case .rennrad, .gravel: return "bicycle"
        case .mtb:     return "mtb"
        }
    }
}

/// Icon je Backend-Aktivitätswert (`activity` in Tour/TourDetail).
func tourActivityIcon(_ activity: String) -> String {
    TourActivity(backendValue: activity).icon
}

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
    var workoutActivity: WorkoutActivity {
        TourActivity(backendValue: activity).workoutActivity
    }
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
               radiusKm: Double, activity: TourActivity) async throws -> [Tour] {
        try await APIClient.shared
            .getJSONArray("/api/client/tours/\(clientId)?lat=\(lat)&lon=\(lon)&radiusKm=\(radiusKm)&activity=\(activity.rawValue)",
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
                   distanceKm: Double, activity: RoundtripActivity) async throws -> TourDetail? {
        let body: [String: Any] = [
            "lat": lat, "lon": lon, "distanceKm": distanceKm,
            "activity": activity.rawValue,
        ]
        guard let json = try await APIClient.shared
            .postJSONObject("/api/client/tours/roundtrip/\(clientId)", body: body, timeout: 60) else { return nil }
        return TourDetail(json: json)
    }

    // MARK: - Demo-Daten (Demo-Modus: kein Backend-Zugriff)

    private static func demoCatalog(_ activity: TourActivity) -> [[String: Any]] {
        switch activity {
        case .wandern: return [
            ["id": "demo-t1", "name": "Sihluferweg Adliswil–Langnau", "activity": "hiking",
             "network": "lwn", "distanceKm": 6.8, "durationMin": 97, "difficulty": "Leicht",
             "lat": 47.309, "lon": 8.53],
            ["id": "demo-t2", "name": "Uetliberg Panoramaweg", "activity": "hiking",
             "network": "rwn", "distanceKm": 12.4, "durationMin": 177, "difficulty": "Mittel",
             "lat": 47.35, "lon": 8.49]]
        case .joggen: return [
            ["id": "demo-j1", "name": "Helsana Trail Adliswil blau", "activity": "running",
             "distanceKm": 5.4, "durationMin": 41, "difficulty": "Leicht",
             "lat": 47.312, "lon": 8.524],
            ["id": "demo-j2", "name": "Sihlrunde", "activity": "running",
             "distanceKm": 8.2, "durationMin": 62, "difficulty": "Mittel",
             "lat": 47.33, "lon": 8.52]]
        case .rennrad: return [
            ["id": "demo-r1", "name": "Zürichsee-Runde Süd", "activity": "bicycle",
             "network": "rcn", "distanceKm": 42.0, "durationMin": 168, "difficulty": "Schwer",
             "lat": 47.28, "lon": 8.56]]
        case .mtb: return [
            ["id": "demo-m1", "name": "Triemlitrail", "activity": "mtb",
             "distanceKm": 4.8, "durationMin": 24, "difficulty": "Leicht",
             "lat": 47.36, "lon": 8.49],
            ["id": "demo-m2", "name": "Adlisberg Trail", "activity": "mtb",
             "distanceKm": 6.5, "durationMin": 33, "difficulty": "Leicht",
             "lat": 47.37, "lon": 8.58]]
        case .vitaparcours: return [
            ["id": "demo-v1", "name": "Vitaparcours Entlisberg", "activity": "fitness_trail",
             "distanceKm": 2.3, "durationMin": 33, "difficulty": "Leicht",
             "lat": 47.34, "lon": 8.53]]
        case .finnenbahn: return [
            ["id": "demo-f1", "name": "Finnenbahn Allmend Brunau", "activity": "finnenbahn",
             "distanceKm": 0.4, "lat": 47.353, "lon": 8.525]]
        }
    }

    static func demoTours(activity: TourActivity) -> [Tour] {
        demoCatalog(activity).compactMap { Tour(json: $0) }
    }

    static func demoDetail(_ id: String) -> TourDetail? {
        let all = TourActivity.allCases.flatMap { demoCatalog($0) }
        guard let t = all.first(where: { ($0["id"] as? String) == id }),
              let lat = t["lat"] as? Double, let lon = t["lon"] as? Double else { return nil }
        // Kreisförmige Demo-Geometrie mit passendem Umfang um den Tour-Mittelpunkt
        let km = t["distanceKm"] as? Double ?? 5
        let rKm = km / (2 * .pi)
        let latKm = 110.574, lonKm = 111.32 * cos(lat * .pi / 180)
        var seg: [[String: Any]] = []
        for i in 0...60 {
            let phi = Double(i) / 60 * 2 * .pi
            seg.append(["lat": lat + (rKm / latKm) * cos(phi),
                        "lon": lon + (rKm / lonKm) * sin(phi)])
        }
        var json = t
        json["description"] = "Demo-Route."
        json["segments"] = [seg]
        return TourDetail(json: json)
    }

    /// Demo-Rundtour: Kreis um den Startpunkt mit synthetischem Höhenprofil.
    static func demoRoundtrip(lat: Double, lon: Double, distanceKm: Double,
                              activity: RoundtripActivity) -> TourDetail {
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
            "activity": activity.osmValue,
            "distanceKm": distanceKm,
            "durationMin": Int(distanceKm / activity.kmh * 60),
            "difficulty": distanceKm < 8 ? "Leicht" : (distanceKm < 16 ? "Mittel" : "Schwer"),
            "elevationGain": 120,
            "segments": [seg],
        ])!
    }
}
