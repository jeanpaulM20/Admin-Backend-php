import SwiftUI

/// Termindetail mit Absage. Pendant zu `screens/training_detail_screen.dart`.
struct TrainingDetailView: View {
    let training: Training
    let isPreview: Bool
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isCancelled: Bool
    @State private var isCancelling = false
    @State private var showConfirm = false
    @State private var error: String?

    init(training: Training, isPreview: Bool, onChanged: @escaping () -> Void) {
        self.training = training
        self.isPreview = isPreview
        self.onChanged = onChanged
        _isCancelled = State(initialValue: training.isCancelled)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                statusBanner
                detailCard
                if !isCancelled {
                    cancelButton
                }
                if let error {
                    Text(error)
                        .font(.app(13))
                        .foregroundStyle(AppColor.red)
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
        .background(AppColor.background)
        .navigationTitle("Termin")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Termin absagen?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Absagen", role: .destructive) {
                Task { await cancel() }
            }
            Button("Zurück", role: .cancel) {}
        } message: {
            Text("Der Termin bleibt im Kalender sichtbar und wird als abgesagt geführt.")
        }
    }

    private var statusBanner: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: isCancelled ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.app(20))
                    .foregroundStyle(isCancelled ? AppColor.red : AppColor.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isCancelled ? "Abgesagt" : "Gebucht")
                        .font(.app(16, weight: .bold))
                        .foregroundStyle(AppColor.text)
                    if isCancelled, training.isLateCancellation {
                        // Kurzfristige Absagen werden weiterhin verrechnet —
                        // das muss der Trainer sehen.
                        Text("Kurzfristig — wird verrechnet")
                            .font(.app(12))
                            .foregroundStyle(AppColor.orange)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var detailCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                detailRow("Kunde", training.clientName)
                detailRow("Art", training.trainingType)
                detailRow("Datum", training.startTime.map { ReviewFormatters.date.string(from: $0) })
                detailRow("Zeit", training.startTime.map { ReviewFormatters.time.string(from: $0) })
                detailRow("Standort", training.locationName)
                detailRow("Trainingsplan", training.trainingPlanName)
                detailRow("Notiz", training.notes)
            }
        }
    }

    @ViewBuilder private func detailRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(label)
                    .font(.app(13))
                    .foregroundStyle(AppColor.muted)
                    .frame(width: 110, alignment: .leading)
                Text(value)
                    .font(.app(14))
                    .foregroundStyle(AppColor.text)
                Spacer(minLength: 0)
            }
        }
    }

    /// Die dominante Aktion dieses Screens ist eine destruktive — darum Rot
    /// statt der CTA-Farbe.
    private var cancelButton: some View {
        Button {
            showConfirm = true
        } label: {
            HStack {
                if isCancelling {
                    ProgressView().tint(AppColor.white)
                } else {
                    Label("Termin absagen", systemImage: "xmark.circle")
                        .font(.app(15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(AppColor.red.opacity(0.15))
            .foregroundStyle(AppColor.red)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        }
        .disabled(isCancelling)
    }

    private func cancel() async {
        isCancelling = true
        defer { isCancelling = false }
        #if DEBUG
        if isPreview {
            isCancelled = true
            onChanged()
            return
        }
        #endif
        do {
            try await SchedulingService().cancelTraining(id: training.id)
            isCancelled = true
            onChanged()
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Termin konnte nicht abgesagt werden"
        }
    }
}
