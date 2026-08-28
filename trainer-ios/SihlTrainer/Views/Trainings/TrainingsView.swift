import SwiftUI

/// Pendant zu `screens/trainings_screen.dart` — Termine des Trainers,
/// gruppiert nach Tag. Filter und Detailansicht folgen in der nächsten Etappe.
struct TrainingsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var store: TrainerStore

    private var grouped: [(day: Date, trainings: [Training])] {
        let calendar = Calendar.current
        let withDate = store.upcoming.filter { $0.startTime != nil }
        let groups = Dictionary(grouping: withDate) { training in
            calendar.startOfDay(for: training.startTime!)
        }
        return groups
            .map { (day: $0.key, trainings: $0.value.sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        Group {
            if store.trainingsLoading && store.trainings.isEmpty {
                LoadingState()
            } else if let error = store.trainingsError {
                MessageState(icon: "exclamationmark.triangle",
                             title: "Termine konnten nicht geladen werden",
                             message: error,
                             actionTitle: "Erneut versuchen") {
                    Task { await reload() }
                }
            } else if grouped.isEmpty {
                MessageState(icon: "figure.strengthtraining.traditional",
                             title: "Keine anstehenden Trainings",
                             message: "Gebuchte Termine erscheinen hier automatisch.")
            } else {
                list
            }
        }
        .background(AppColor.background)
        .sectionChrome("Trainings")
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                ForEach(grouped, id: \.day) { group in
                    Text(Self.headerFormatter.string(from: group.day))
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(AppColor.muted)
                        .padding(.top, 6)
                    Card {
                        VStack(spacing: 14) {
                            ForEach(group.trainings) { training in
                                TrainingRow(training: training)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
        .refreshable { await reload() }
    }

    private func reload() async {
        guard let id = auth.trainer?.id else { return }
        await store.loadTrainings(trainerId: id)
    }

    static let headerFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "EEEE, d. MMMM"
        return f
    }()
}
