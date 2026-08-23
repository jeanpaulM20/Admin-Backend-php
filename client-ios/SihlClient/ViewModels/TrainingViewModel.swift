import Foundation

/// List-Screen ViewModel — Pendant zu `providers/training_plan_provider.dart`.
@MainActor @Observable
final class TrainingViewModel {
    var isLoading      = false
    var error: String?
    var plans: [ClientTrainingPlan] = []
    var subscription   = SubscriptionStatus()
    var exerciseIdMap: [String: Int] = [:]
    var isActivatingTrial = false
    var toast: AppToast?

    private let service = TrainingPlanService()

    func fetch(clientId: String) async {
        guard !isLoading else { return }
        isLoading = true; error = nil

        async let plansTask = service.listPlans()
        async let subTask   = service.getSubscription(clientId: clientId)
        async let exTask    = service.listExercises()

        do {
            plans = try await plansTask
        } catch {
            self.error = error.localizedDescription
        }
        do {
            subscription = try await subTask
        } catch let err as APIError {
            self.error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        if let ex = try? await exTask { exerciseIdMap = ex }
        isLoading = false
    }

    /// Gibt nil bei Erfolg zurück, user-facing Fehlermeldung bei Fehler.
    func activateTrial(clientId: String) async -> String? {
        isActivatingTrial = true
        defer { isActivatingTrial = false }
        do {
            subscription = try await service.activateTrial(clientId: clientId)
            return nil
        } catch let err as APIError {
            return err.message
        } catch {
            return error.localizedDescription
        }
    }
}
