import SwiftUI

/// Erste Ausbaustufe des Kundendetails: Stammdaten und Termine dieses Kunden.
/// Die weiteren Bereiche aus `client_detail_screen.dart` (Anamnese, Dateien,
/// Leistungstests, Pläne) folgen in den nächsten Etappen.
struct ClientDetailView: View {
    let client: Client
    @EnvironmentObject private var store: TrainerStore
    @EnvironmentObject private var auth: AuthViewModel

    private var appointments: [Training] {
        store.upcoming.filter { $0.clientId == client.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                header
                planLink
                contactCard
                appointmentsCard
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
        .background(AppColor.background)
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        Card(padding: AppSpacing.hero) {
            HStack(spacing: 14) {
                Avatar(initials: client.initials, photo: client.photo, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(client.name)
                        .font(.app(19, weight: .bold))
                        .foregroundStyle(AppColor.text)
                    if let type = client.trainingType {
                        Text(type)
                            .font(.app(13, weight: .semibold))
                            .foregroundStyle(AppColor.primary)
                    }
                    if let location = client.locationName {
                        Text(location)
                            .font(.app(13))
                            .foregroundStyle(AppColor.muted)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Einstieg in die Trainingspläne dieses Kunden.
    private var planLink: some View {
        NavigationLink {
            TrainingPlanListView(client: client, isPreview: auth.previewFlag)
        } label: {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.app(15))
                        .foregroundStyle(AppColor.primary)
                        .frame(width: 22)
                    Text("Trainingspläne")
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(AppColor.text)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.app(13))
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var contactCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Kontakt")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
                DetailRow(icon: "envelope", value: client.email)
                DetailRow(icon: "phone", value: client.phone)
                DetailRow(icon: "mappin.and.ellipse", value: client.address)
                DetailRow(icon: "calendar", value: client.dateOfBirth)
                DetailRow(icon: "heart", value: heartRateRange)
            }
        }
    }

    private var heartRateRange: String? {
        guard let min = client.minHeartRate, let max = client.maxHeartRate else { return nil }
        return "\(min)–\(max) bpm"
    }

    private var appointmentsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                Text("Nächste Termine")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
                if appointments.isEmpty {
                    Text("Keine anstehenden Termine")
                        .font(.app(14))
                        .foregroundStyle(AppColor.muted)
                } else {
                    ForEach(appointments.prefix(5)) { training in
                        TrainingRow(training: training, showsClient: false)
                    }
                }
            }
        }
    }
}

private struct DetailRow: View {
    let icon: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.app(13))
                    .foregroundStyle(AppColor.muted)
                    .frame(width: 18)
                Text(value)
                    .font(.app(14))
                    .foregroundStyle(AppColor.text)
                Spacer(minLength: 0)
            }
        }
    }
}
