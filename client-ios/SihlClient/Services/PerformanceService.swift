import Foundation

/// Pendant zu `services/performance_service.dart`.
struct PerformanceService {
    static let shared = PerformanceService()
    private init() {}

    /// `GET /api/client/tests/{clientId}` — Leistungstests
    func getPerformanceData(clientId: String) async throws -> [PerformanceSection] {
        try await APIClient.shared
            .getJSONArray("/api/client/tests/\(clientId)")
            .map { PerformanceSection(json: $0) }
    }

    /// `GET /api/client/metrics/{clientId}` — Körpermesswerte
    func getMetrics(clientId: String) async throws -> [PerformanceSection] {
        try await APIClient.shared
            .getJSONArray("/api/client/metrics/\(clientId)")
            .map { PerformanceSection(json: $0) }
    }

    /// `GET /api/client/reviews/{clientId}` — Trainingsaufzeichnungen
    func getReviews(clientId: String) async throws -> [TrainingReview] {
        try await APIClient.shared
            .getJSONArray("/api/client/reviews/\(clientId)")
            .map { TrainingReview(json: $0) }
    }

    /// `GET /api/client/workouts/{clientId}/{reviewId}/track` — GPS-Route
    /// einer App-Aufzeichnung (leer bei Trainings ohne GPS).
    func getTrack(clientId: String, reviewId: String) async throws -> [GeoPoint] {
        try await APIClient.shared
            .getJSONArray("/api/client/workouts/\(clientId)/\(reviewId)/track")
            .compactMap { GeoPoint(json: $0) }
    }
}

/// Ein Punkt der GPS-Route (Detail-Ansicht: Karte + Höhenprofil).
struct GeoPoint {
    let lat: Double
    let lon: Double
    let ele: Double?

    init?(json: [String: Any]) {
        guard let lat = Double("\(json["lat"] ?? "")"),
              let lon = Double("\(json["lon"] ?? "")") else { return nil }
        self.lat = lat
        self.lon = lon
        self.ele = Double("\(json["ele"] ?? "")")
    }
}
