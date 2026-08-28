import Foundation

/// Trainingspläne eines Kunden.
/// Pendant zu den Calls aus `training_plan_list_screen.dart` und
/// `training_plan_detail_screen.dart`.
struct TrainingPlanService {

    func plans(clientId: Int) async throws -> [TrainingPlan] {
        let data = try await APIClient.shared.get("\(APIConfig.trainingPlan)?client_id=\(clientId)")
        let json = try? JSONSerialization.jsonObject(with: data)
        var list: [[String: Any]] = []
        if let array = json as? [[String: Any]] {
            list = array
        } else if let object = json as? [String: Any], let array = object["data"] as? [[String: Any]] {
            list = array
        }
        return list.map(TrainingPlan.init(json:))
    }

    /// Neu anlegen (POST) oder aktualisieren (PUT) — wie in Flutter am
    /// Vorhandensein der ID entschieden.
    func save(_ plan: TrainingPlan) async throws {
        if let id = plan.id {
            _ = try await APIClient.shared.put("\(APIConfig.trainingPlan)/\(id)", body: plan.savePayload)
        } else {
            _ = try await APIClient.shared.post(APIConfig.trainingPlan, body: plan.savePayload)
        }
    }

    /// Freigeben bzw. zurückziehen. Der Kunde sieht nur freigegebene Pläne.
    func setPublished(_ published: Bool, planId: Int) async throws {
        let action = published ? "publish" : "unpublish"
        _ = try await APIClient.shared.post("\(APIConfig.trainingPlan)/\(planId)/\(action)")
    }

    func delete(planId: Int) async throws {
        _ = try await APIClient.shared.delete("\(APIConfig.trainingPlan)/\(planId)")
    }
}
