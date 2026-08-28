import Foundation

/// Planliste eines Kunden.
@MainActor
final class TrainingPlanListViewModel: ObservableObject {
    @Published private(set) var plans: [TrainingPlan] = []
    @Published private(set) var isLoading = false
    @Published var error: String?

    private let service = TrainingPlanService()
    private let clientId: Int
    private let isPreview: Bool

    init(clientId: Int, isPreview: Bool) {
        self.clientId = clientId
        self.isPreview = isPreview
    }

    func load() async {
        #if DEBUG
        if isPreview {
            plans = PreviewData.plans
            return
        }
        #endif
        isLoading = true
        defer { isLoading = false }
        do {
            plans = try await service.plans(clientId: clientId)
            error = nil
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Trainingspläne konnten nicht geladen werden"
        }
    }

    /// Freigabe umschalten. Der neue Zustand wird sofort gezeigt und bei einem
    /// Fehler zurückgenommen — sonst steht die Liste im Widerspruch zum Server.
    func togglePublished(_ plan: TrainingPlan) async {
        guard let id = plan.id, let index = plans.firstIndex(where: { $0.id == id }) else { return }
        let target = !plan.isPublished
        plans[index].status = target ? "published" : "draft"
        #if DEBUG
        if isPreview { return }
        #endif
        do {
            try await service.setPublished(target, planId: id)
        } catch let apiError as APIError {
            plans[index].status = target ? "draft" : "published"
            error = apiError.message
        } catch {
            plans[index].status = target ? "draft" : "published"
            self.error = "Freigabe konnte nicht geändert werden"
        }
    }

    func delete(_ plan: TrainingPlan) async {
        guard let id = plan.id else { return }
        let backup = plans
        plans.removeAll { $0.id == id }
        #if DEBUG
        if isPreview { return }
        #endif
        do {
            try await service.delete(planId: id)
        } catch {
            plans = backup
            self.error = "Plan konnte nicht gelöscht werden"
        }
    }

    func replace(_ plan: TrainingPlan) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        plans[index] = plan
    }
}

/// Ein Plan im Detail — Anzeigen und Bearbeiten.
@MainActor
final class TrainingPlanEditorViewModel: ObservableObject {
    @Published var plan: TrainingPlan
    @Published var isEditing = false
    @Published private(set) var isSaving = false
    @Published var error: String?

    private let service = TrainingPlanService()
    private let isPreview: Bool
    private var saved: TrainingPlan

    init(plan: TrainingPlan, isPreview: Bool) {
        self.plan = plan
        self.saved = plan
        self.isPreview = isPreview
    }

    var hasChanges: Bool {
        plan.name != saved.name || plan.values != saved.values
    }

    func addRow(to section: PlanSection) {
        plan.values[section].append(TrainingPlanRow())
    }

    func removeRows(at offsets: IndexSet, in section: PlanSection) {
        plan.values[section].remove(atOffsets: offsets)
    }

    /// Leere Zeilen fliegen beim Speichern raus — sie entstehen beim
    /// Hinzufügen und würden sonst als Geisterübungen beim Kunden landen.
    func save() async {
        isSaving = true
        defer { isSaving = false }
        for section in PlanSection.allCases {
            plan.values[section].removeAll { $0.isEmpty }
        }
        #if DEBUG
        if isPreview {
            saved = plan
            isEditing = false
            return
        }
        #endif
        do {
            try await service.save(plan)
            saved = plan
            isEditing = false
            error = nil
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Plan konnte nicht gespeichert werden"
        }
    }

    func discard() {
        plan = saved
        isEditing = false
    }

    func togglePublished() async {
        guard let id = plan.id else { return }
        let target = !plan.isPublished
        plan.status = target ? "published" : "draft"
        saved.status = plan.status
        #if DEBUG
        if isPreview { return }
        #endif
        do {
            try await service.setPublished(target, planId: id)
        } catch {
            plan.status = target ? "draft" : "published"
            saved.status = plan.status
            self.error = "Freigabe konnte nicht geändert werden"
        }
    }
}
