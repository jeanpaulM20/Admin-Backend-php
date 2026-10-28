import Foundation

/// List-Screen ViewModel — Pendant zu `providers/training_plan_provider.dart`.
@MainActor @Observable
final class TrainingViewModel {
    var isLoading      = false
    var error: String?
    var plans: [ClientTrainingPlan] = []
    var subscription   = SubscriptionStatus()
    var exerciseIdMap: [String: Int] = [:]

    private let service = TrainingPlanService()

    func fetch(clientId: String) async {
        guard !isLoading else { return }
        isLoading = true; error = nil

        async let plansTask = service.listPlans()
        async let subTask   = service.getSubscription(clientId: clientId)
        async let exTask    = service.listExercises()

        do {
            plans = try await plansTask
        } catch let err as APIError {
            self.error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        // Coaching-Status ist reine Info (Ablaufhinweis) — ein Fehler hier
        // soll die Planliste nicht mit einem Fehlerbanner überlagern
        if let sub = try? await subTask { subscription = sub }
        if let ex = try? await exTask { exerciseIdMap = ex }
        isLoading = false
    }
}
