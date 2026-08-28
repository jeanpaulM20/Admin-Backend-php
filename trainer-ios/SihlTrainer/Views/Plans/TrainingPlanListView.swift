import SwiftUI

/// Pendant zu `screens/training_plan_list_screen.dart`: die Pläne eines
/// Kunden mit Freigabe-Zustand. Die KI-Empfehlung folgt später.
struct TrainingPlanListView: View {
    let client: Client

    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var model: TrainingPlanListViewModel

    init(client: Client, isPreview: Bool) {
        self.client = client
        _model = StateObject(wrappedValue: TrainingPlanListViewModel(
            clientId: client.id,
            isPreview: isPreview
        ))
    }

    var body: some View {
        Group {
            if model.isLoading && model.plans.isEmpty {
                LoadingState()
            } else if model.plans.isEmpty {
                MessageState(icon: "list.bullet.rectangle",
                             title: "Noch kein Plan",
                             message: "Für \(client.name) ist bisher kein Trainingsplan angelegt.")
            } else {
                list
            }
        }
        .background(AppColor.background)
        .navigationTitle("Trainingspläne")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .alert("Fehler", isPresented: .constant(model.error != nil)) {
            Button("OK") { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
    }

    private var list: some View {
        List {
            ForEach(model.plans) { plan in
                // Ziel direkt am Link statt wertbasiert: in dieser
                // gepushten Liste hat navigationDestination(for:) nicht
                // ausgelöst — dieselbe Unzuverlässigkeit wie in client-ios.
                NavigationLink {
                    TrainingPlanDetailView(plan: plan, isPreview: auth.previewFlag) { updated in
                        model.replace(updated)
                    }
                } label: {
                    PlanRow(plan: plan)
                }
                .listRowBackground(AppColor.background)
                .listRowSeparatorTint(AppColor.border)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await model.delete(plan) }
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                    Button {
                        Task { await model.togglePublished(plan) }
                    } label: {
                        Label(plan.isPublished ? "Zurückziehen" : "Freigeben",
                              systemImage: plan.isPublished ? "eye.slash" : "paperplane")
                    }
                    .tint(AppColor.primary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await model.load() }
    }
}

private struct PlanRow: View {
    let plan: TrainingPlan

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name?.isEmpty == false ? plan.name! : "Ohne Titel")
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(plan.values.totalRows) Übungen")
                    if let created = plan.createdAt, let date = JSON.date(created) {
                        Text("·")
                        Text(Self.dateFormatter.string(from: date))
                    }
                }
                .font(.app(13))
                .foregroundStyle(AppColor.muted)
            }
            Spacer(minLength: 0)
            StatusPill(isPublished: plan.isPublished)
        }
        .padding(.vertical, 4)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "d. MMM yyyy"
        return f
    }()
}

/// Freigabe-Zustand. Grün heisst: der Kunde sieht den Plan.
struct StatusPill: View {
    let isPublished: Bool

    var body: some View {
        Text(isPublished ? "Freigegeben" : "Entwurf")
            .font(.app(11, weight: .semibold))
            .foregroundStyle(isPublished ? AppColor.green : AppColor.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((isPublished ? AppColor.green : AppColor.muted).opacity(0.12))
            .clipShape(Capsule())
    }
}

extension TrainingPlan: Hashable {
    static func == (lhs: TrainingPlan, rhs: TrainingPlan) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.name == rhs.name && lhs.values == rhs.values
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
