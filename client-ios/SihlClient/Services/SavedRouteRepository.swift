import Foundation
import CoreLocation

// MARK: - SavedRoute („Meine Routen", Routenplaner Phase 3)

/// Eine gespeicherte Planung: die gesetzten Punkte (zum Weiterbearbeiten)
/// und die Kennzahlen der berechneten Route. Die Geometrie kommt erst mit
/// dem Detail (`SavedRouteRepository.detail`).
struct SavedRoute: Identifiable, Hashable {
    let id: Int
    let name: String
    let activity: RoundtripActivity
    let roundtrip: Bool
    let points: [CLLocationCoordinate2D]
    let distanceKm: Double?
    let elevationGain: Int?
    let elevationLoss: Int?
    let durationMin: Int?
    let difficulty: String?

    init(id: Int, name: String, activity: RoundtripActivity, roundtrip: Bool,
         points: [CLLocationCoordinate2D], distanceKm: Double?, elevationGain: Int?,
         elevationLoss: Int?, durationMin: Int?, difficulty: String?) {
        self.id = id
        self.name = name
        self.activity = activity
        self.roundtrip = roundtrip
        self.points = points
        self.distanceKm = distanceKm
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.durationMin = durationMin
        self.difficulty = difficulty
    }

    init?(json: [String: Any]) {
        guard let id = Int("\(json["id"] ?? "")"),
              let name = json["name"] as? String else { return nil }
        let points: [CLLocationCoordinate2D] = (json["points"] as? [[String: Any]] ?? []).compactMap {
            guard let lat = Double("\($0["lat"] ?? "")"),
                  let lon = Double("\($0["lon"] ?? "")") else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard points.count >= 2 else { return nil }
        self.init(
            id: id, name: name,
            activity: RoundtripActivity(rawValue: json["activity"] as? String ?? "") ?? .wandern,
            roundtrip: (json["roundtrip"] as? Bool) ?? ((json["roundtrip"] as? Int) == 1),
            points: points,
            distanceKm: Double("\(json["distanceKm"] ?? "")"),
            elevationGain: Int("\(json["elevationGain"] ?? "")"),
            elevationLoss: Int("\(json["elevationLoss"] ?? "")"),
            durationMin: Int("\(json["durationMin"] ?? "")"),
            difficulty: json["difficulty"] as? String)
    }

    static func == (l: Self, r: Self) -> Bool { l.id == r.id && l.name == r.name }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// „12.4 km · ↑430 ↓410 m · 3 Std 10 Min"
    var statsLine: String {
        var parts: [String] = []
        if let km = distanceKm { parts.append(TourFormat.distance(km)) }
        if let gain = elevationGain {
            parts.append(elevationLoss.map { "↑\(gain) ↓\($0) m" } ?? "↑\(gain) m")
        }
        if let min = durationMin { parts.append(TourFormat.duration(min)) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - SavedRouteRepository

/// Zugriff auf „Meine Routen" — gegen das Backend bzw. im Demo-Modus gegen
/// einen Speicher, der nur für die laufende Sitzung hält. Views und das
/// Planer-Modell kennen nur diese Schnittstelle, nicht die Quelle.
struct SavedRouteRepository {
    let clientId: String?
    let isDemo: Bool

    func list() async throws -> [SavedRoute] {
        if isDemo { return await DemoSavedRoutes.shared.all() }
        guard let clientId else { return [] }
        return try await APIClient.shared
            .getJSONArray("/api/client/tours/planned/\(clientId)")
            .compactMap { SavedRoute(json: $0) }
    }

    /// Volle Route (Karte, Höhenprofil, Starten).
    func detail(_ route: SavedRoute) async throws -> TourDetail? {
        if isDemo {
            let demo = TourService.demoPlannedRoute(points: route.points, activity: route.activity,
                                                    roundtrip: route.roundtrip)
            return TourDetail(id: "saved-\(route.id)", name: route.name, activity: demo.activity,
                              description: demo.description, distanceKm: demo.distanceKm,
                              durationMin: demo.durationMin, difficulty: demo.difficulty,
                              segments: demo.segments)
        }
        guard let clientId,
              let json = try await APIClient.shared
                .getJSONObject("/api/client/tours/planned/\(clientId)/\(route.id)", timeout: 30) else { return nil }
        return TourDetail(json: json)
    }

    /// Neue Route speichern oder — mit `replacing` — eine bestehende mit
    /// den neuen Punkten ersetzen. Die Geometrie berechnet der Server.
    func save(name: String, points: [CLLocationCoordinate2D], activity: RoundtripActivity,
              roundtrip: Bool, replacing id: Int? = nil) async throws -> SavedRoute? {
        if isDemo {
            return await DemoSavedRoutes.shared.save(name: name, points: points, activity: activity,
                                                     roundtrip: roundtrip, replacing: id)
        }
        guard let clientId else { return nil }
        let body: [String: Any] = [
            "name": name,
            "points": points.map { ["lat": $0.latitude, "lon": $0.longitude] },
            "activity": activity.rawValue,
            "roundtrip": roundtrip,
        ]
        let data: Data
        if let id {
            // Ersetzen rechnet die Route auf dem Server neu — gleiche Geduld wie beim Anlegen
            data = try await APIClient.shared.put("/api/client/tours/planned/\(clientId)/\(id)",
                                                  body: body, timeout: 45)
        } else {
            data = try await APIClient.shared.post("/api/client/tours/planned/\(clientId)", body: body, timeout: 45)
        }
        return Self.route(from: data)
    }

    func rename(_ route: SavedRoute, to name: String) async throws -> SavedRoute? {
        if isDemo { return await DemoSavedRoutes.shared.rename(route.id, to: name) }
        guard let clientId else { return nil }
        let data = try await APIClient.shared
            .put("/api/client/tours/planned/\(clientId)/\(route.id)", body: ["name": name])
        return Self.route(from: data)
    }

    func delete(_ route: SavedRoute) async throws {
        if isDemo { await DemoSavedRoutes.shared.delete(route.id); return }
        guard let clientId else { return }
        _ = try await APIClient.shared.delete("/api/client/tours/planned/\(clientId)/\(route.id)")
    }

    private static func route(from data: Data) -> SavedRoute? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]).flatMap { SavedRoute(json: $0) }
    }
}

// MARK: - Demo-Speicher (nur für die laufende Sitzung)

private actor DemoSavedRoutes {
    static let shared = DemoSavedRoutes()
    private var routes: [SavedRoute] = []
    private var nextID = 1

    func all() -> [SavedRoute] { routes }

    func save(name: String, points: [CLLocationCoordinate2D], activity: RoundtripActivity,
              roundtrip: Bool, replacing id: Int?) -> SavedRoute {
        let demo = TourService.demoPlannedRoute(points: points, activity: activity, roundtrip: roundtrip)
        let route = SavedRoute(
            id: id ?? nextID, name: name, activity: activity, roundtrip: roundtrip, points: points,
            distanceKm: demo.distanceKm, elevationGain: nil, elevationLoss: nil,
            durationMin: demo.durationMin, difficulty: demo.difficulty)
        if id == nil { nextID += 1 }
        routes.removeAll { $0.id == route.id }
        routes.insert(route, at: 0)
        return route
    }

    func rename(_ id: Int, to name: String) -> SavedRoute? {
        guard let i = routes.firstIndex(where: { $0.id == id }) else { return nil }
        let old = routes[i]
        routes[i] = SavedRoute(
            id: old.id, name: name, activity: old.activity, roundtrip: old.roundtrip, points: old.points,
            distanceKm: old.distanceKm, elevationGain: old.elevationGain, elevationLoss: old.elevationLoss,
            durationMin: old.durationMin, difficulty: old.difficulty)
        return routes[i]
    }

    func delete(_ id: Int) {
        routes.removeAll { $0.id == id }
    }
}
