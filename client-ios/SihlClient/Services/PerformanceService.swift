import Foundation

/// Pendant zu `services/performance_service.dart`.
struct PerformanceService {
    static let shared = PerformanceService()
    private init() {}

    /// `GET /api/client/tests/{clientId}` — Leistungstests
    func getPerformanceData(clientId: String) async throws -> [PerformanceSection] {
        let json = try await APIClient.shared.get("/api/client/tests/\(clientId)")
        return (json as? [[String: Any]] ?? []).map { PerformanceSection(json: $0) }
    }

    /// `GET /api/client/metrics/{clientId}` — Körpermesswerte
    func getMetrics(clientId: String) async throws -> [PerformanceSection] {
        let json = try await APIClient.shared.get("/api/client/metrics/\(clientId)")
        return (json as? [[String: Any]] ?? []).map { PerformanceSection(json: $0) }
    }

    /// `GET /api/client/reviews/{clientId}` — Trainingsaufzeichnungen
    func getReviews(clientId: String) async throws -> [TrainingReview] {
        let json = try await APIClient.shared.get("/api/client/reviews/\(clientId)")
        return (json as? [[String: Any]] ?? []).map { TrainingReview(json: $0) }
    }
}
