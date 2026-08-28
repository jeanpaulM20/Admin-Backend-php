import SwiftUI

/// Einen Trainingsplan in den Kalender des Kunden legen.
/// Pendant zu `screens/schedule_plan_dialog.dart`.
struct SchedulePlanSheet: View {
    let plan: TrainingPlan
    let isPreview: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.sihl.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var error: String?
    @State private var done = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Termin") {
                    DatePicker("Datum und Zeit", selection: $date)
                        .listRowBackground(AppColor.surface)
                }
                Section {
                    Text("Der Plan wird als Online-Coaching eingeplant — ohne Standort und ohne Trainerkonflikt.")
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                        .listRowBackground(AppColor.surface)
                }
                if let error {
                    Section {
                        Text(error).font(.app(13)).foregroundStyle(AppColor.red)
                    }
                }
                if done {
                    Section {
                        Label("Eingeplant", systemImage: "checkmark.circle.fill")
                            .font(.app(14, weight: .semibold))
                            .foregroundStyle(AppColor.green)
                            .listRowBackground(AppColor.surface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
            .navigationTitle("Plan einplanen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }.foregroundStyle(AppColor.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await schedule() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(AppColor.primary)
                        } else {
                            Text("Einplanen").font(.app(15, weight: .semibold))
                        }
                    }
                    .disabled(isSaving || plan.id == nil || plan.clientId == nil)
                }
            }
        }
    }

    private func schedule() async {
        guard let planId = plan.id, let clientId = plan.clientId else { return }
        isSaving = true
        defer { isSaving = false }
        #if DEBUG
        if isPreview {
            done = true
            return
        }
        #endif
        do {
            try await SchedulingService().schedulePlan(planId: planId, clientId: clientId, date: date)
            done = true
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Plan konnte nicht eingeplant werden"
        }
    }
}
