import Foundation

/// Pendant zu `services/performance_service.dart`.
struct PerformanceService {
    static let shared = PerformanceService()
    private init() {}

    /// `GET /api/client/tests/{clientId}` — Leistungstests
    func getPerformanceData(clientId: String) async throws -> [PerformanceSection] {
        let data = try await APIClient.shared.get("/api/client/tests/\(clientId)")
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map { PerformanceSection(json: $0) }
    }

    /// `GET /api/client/metrics/{clientId}` — Körpermesswerte
    func getMetrics(clientId: String) async throws -> [PerformanceSection] {
        let data = try await APIClient.shared.get("/api/client/metrics/\(clientId)")
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map { PerformanceSection(json: $0) }
    }

    /// `GET /api/client/reviews/{clientId}` — Trainingsaufzeichnungen
    func getReviews(clientId: String) async throws -> [TrainingReview] {
        let data = try await APIClient.shared.get("/api/client/reviews/\(clientId)")
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map { TrainingReview(json: $0) }
    }
}
