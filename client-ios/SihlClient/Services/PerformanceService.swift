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
}
