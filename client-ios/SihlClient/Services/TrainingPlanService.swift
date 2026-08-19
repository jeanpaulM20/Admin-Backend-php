import Foundation

/// Pendant zu `services/training_plan_service.dart`.
struct TrainingPlanService {

    /// Veröffentlichte Pläne des eingeloggten Clients (teaser + lock-Flag).
    func listPlans() async throws -> [ClientTrainingPlan] {
        let data = try await APIClient.shared.get("api/training-plan")
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map { ClientTrainingPlan(json: $0) }
    }

    /// Einzelner Plan: voller Inhalt wenn berechtigt, sonst gesperrter Teaser.
    func getPlan(_ id: Int) async throws -> ClientTrainingPlan {
        let data = try await APIClient.shared.get("api/training-plan/\(id)")
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError(statusCode: 500, message: "Ungültige Antwort vom Server")
        }
        return ClientTrainingPlan(json: dict)
    }

    /// Aktueller Abo-Status des Clients.
    func getSubscription(clientId: String) async throws -> SubscriptionStatus {
        let data = try await APIClient.shared.get("api/client/subscription/\(clientId)")
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return SubscriptionStatus()
        }
        return SubscriptionStatus(json: dict)
    }

    /// Einmaligen Gratis-Test-Monat aktivieren.
    func activateTrial(clientId: String) async throws -> SubscriptionStatus {
        let data = try await APIClient.shared.post("api/client/coaching/trial/\(clientId)")
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return SubscriptionStatus()
        }
        return SubscriptionStatus(json: dict)
    }

    /// Alle Übungen → Name-zu-ID-Map (für Cover-Bilder).
    func listExercises() async throws -> [String: Int] {
        let data = try await APIClient.shared.get("api/exercise")
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [:] }
        var map: [String: Int] = [:]
        for ex in arr {
            if let name = ex["name"] as? String, let id = ex["id"] as? Int {
                map[name] = id
            }
        }
        return map
    }

    /// Like / Dislike für eine Übung. Gibt aktuellen Likes-State zurück.
    func toggleLike(planId: Int, exerciseKey: String, type: String) async throws -> [String: String] {
        let data = try await APIClient.shared.post(
            "api/training-plan/\(planId)/like",
            body: ["exerciseKey": exerciseKey, "type": type]
        )
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return dict.mapValues { "\($0)" }
    }

    /// Kommentare für eine Übung (oder den ganzen Plan wenn exerciseKey nil).
    func getComments(planId: Int, exerciseKey: String?) async throws -> [[String: Any]] {
        var path = "api/training-plan/\(planId)/comments"
        if let key = exerciseKey { path += "?exerciseKey=\(key)" }
        let data = try await APIClient.shared.get(path)
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    /// Kommentar-Anzahlen pro exerciseKey.
    func getCommentCounts(planId: Int) async throws -> [String: Int] {
        let data = try await APIClient.shared.get("api/training-plan/\(planId)/comment-counts")
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return dict.compactMapValues { ($0 as? Int) ?? Int("\($0)") }
    }

    /// Kommentar senden.
    func sendComment(planId: Int, text: String, exerciseKey: String?) async throws {
        var body: [String: Any] = ["text": text]
        if let key = exerciseKey { body["exerciseKey"] = key }
        _ = try await APIClient.shared.post("api/training-plan/\(planId)/comments", body: body)
    }

    /// Eigenen Kommentar löschen.
    func deleteComment(commentId: Int) async throws {
        _ = try await APIClient.shared.delete("api/training-plan/comments/\(commentId)")
    }
}
