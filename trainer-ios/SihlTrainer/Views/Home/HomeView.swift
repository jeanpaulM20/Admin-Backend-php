import SwiftUI

/// Pendant zu `screens/home_screen.dart`: Trainerkarte, nächster Termin,
/// Kennzahlen.
struct HomeView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var store: TrainerStore

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                if let trainer = auth.trainer {
                    trainerCard(trainer)
                }
                statsRow
                nextAppointment
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
        .background(AppColor.background)
        .refreshable {
            guard let id = auth.trainer?.id else { return }
            await store.load(trainerId: id)
        }
        .sectionChrome("Übersicht")
    }

    private func trainerCard(_ trainer: Trainer) -> some View {
        Card(padding: AppSpacing.hero) {
            HStack(spacing: 14) {
                Avatar(initials: trainer.initials, photo: trainer.photo, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(trainer.name)
                        .font(.app(18, weight: .bold))
                        .foregroundStyle(AppColor.text)
                    if let email = trainer.email {
                        Text(email)
                            .font(.app(13))
                            .foregroundStyle(AppColor.muted)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: AppSpacing.stack) {
            StatTile(value: "\(store.todayCount)", label: "Heute")
            StatTile(value: "\(store.thisWeekCount)", label: "Diese Woche")
            StatTile(value: "\(store.clients.count)", label: "Kunden", accent: AppColor.brass)
        }
    }

    @ViewBuilder private var nextAppointment: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                Text("Nächster Termin")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
                if store.trainingsLoading && store.trainings.isEmpty {
                    ProgressView().tint(AppColor.primary)
                } else if let error = store.trainingsError {
                    Text(error)
                        .font(.app(13))
                        .foregroundStyle(AppColor.red)
                } else if let next = store.nextTraining {
                    TrainingRow(training: next)
                } else {
                    Text("Keine anstehenden Termine")
                        .font(.app(14))
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
    }
}
