import SwiftUI

/// Liste der Trainingspläne. Pendant zu `screens/training_plan_list_screen.dart`.
/// Online Coaching wird in der App nicht verkauft (App-Store 3.1.1): gesperrte
/// Pläne erscheinen mit Schloss, ein Tipp zeigt nur einen neutralen Hinweis.
///
/// `embedded`: Inhalt der Startseite (Chip „Trainingspläne") — ohne eigenen
/// Scroll-Bereich, eigenen Hintergrund und seitliche Ränder; die Startseite
/// scrollt, randet ein und lädt per Ziehen neu (`TrainingViewModel`).
struct TrainingView: View {
    var embedded = false

    @Environment(AuthViewModel.self)      private var auth
    @Environment(TrainingViewModel.self)  private var vm

    @State private var showLockedInfo = false

    private var isDemo: Bool { auth.clientId == "demo" }
    /// Seitlicher Rand der Elemente — eingebettet randet die Startseite ein
    private var hPad: CGFloat { embedded ? 0 : AppSpacing.screen }

    var body: some View {
        if embedded {
            main
        } else {
            main.refreshable { await refresh() }
        }
    }

    private var main: some View {
        ZStack {
            if !embedded { AppColor.background.ignoresSafeArea() }
            if isDemo {
                // Wie Kalender/Chat: Pläne kommen vom Trainer, ohne Konto gibt
                // es keine — statt „E-Mail oder Passwort falsch" ein Hinweis
                DemoUnavailableView(message: "Hier erscheinen die Trainingspläne deines Trainers.")
                    .frame(minHeight: embedded ? 320 : nil)
            } else if vm.isLoading && vm.plans.isEmpty {
                LoadingView(message: "Lade Trainingspläne…")
                    .frame(minHeight: embedded ? 320 : nil)
            } else {
                content
            }
        }
        .task {
            if !isDemo, vm.plans.isEmpty, let id = auth.clientId {
                await vm.fetch(clientId: id)
            }
        }
        // Gesperrter Plan: neutraler Hinweis — kein Preis, kein Kaufknopf, kein Link
        .alert("Plan gesperrt", isPresented: $showLockedInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(LockedPlanInfo.message)
        }
    }

    private func refresh() async {
        guard !isDemo, let id = auth.clientId else { return }
        await vm.fetch(clientId: id)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if embedded {
            planStack
        } else {
            ScrollView { planStack.padding(.bottom, AppSpacing.bottomInset) }
        }
    }

    private var planStack: some View {
        LazyVStack(spacing: 0, pinnedViews: []) {
            expiryInfo
                .padding(.top, embedded ? 0 : 12)

            if let err = vm.error {
                // Fehler ODER Leerzustand — nie beides
                InlineErrorBanner(message: err)
                    .padding(.horizontal, hPad).padding(.top, 8).padding(.bottom, 8)
            }

            if vm.plans.isEmpty {
                if vm.error == nil && !vm.isLoading { emptyState }
            } else {
                ForEach(vm.plans) { plan in
                    planRow(plan)
                        .padding(.horizontal, hPad)
                        .padding(.bottom, AppSpacing.stack)
                }
                .padding(.top, 4)
            }
        }
    }

    /// Ziel je Plan — direkte Destination statt wertbasierter Navigation:
    /// Die Liste steckt in der Startseite (Chip „Trainingspläne"), nicht an
    /// der Wurzel eines eigenen NavigationStack; ein hier registriertes
    /// `navigationDestination(for:)` fand SwiftUI in dieser Lage nicht
    /// zuverlässig — der Tipp auf einen Plan verpuffte dann kommentarlos.
    /// Direkte NavigationLink-Ziele haben das Problem nicht.
    @ViewBuilder
    private func planRow(_ plan: ClientTrainingPlan) -> some View {
        if plan.locked {
            Button { showLockedInfo = true } label: {
                PlanCard(plan: plan, exerciseIdMap: vm.exerciseIdMap)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Gesperrt. Zeigt einen Hinweis.")
        } else if let id = plan.id {
            NavigationLink {
                TrainingPlanDetailView(
                    planId: id,
                    planName: plan.name,
                    exerciseIdMap: vm.exerciseIdMap
                )
            } label: {
                PlanCard(plan: plan, exerciseIdMap: vm.exerciseIdMap)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Ablauf-Info

    /// Reine Information ohne Kaufaufforderung (App-Store 3.1.3(b)).
    @ViewBuilder
    private var expiryInfo: some View {
        let sub = vm.subscription
        if !vm.isLoading, sub.active, sub.expiringSoon,
           let raw = sub.validTo, let date = SwissDay.parse(raw) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.app(13))
                    .foregroundStyle(AppColor.muted)
                    .accessibilityHidden(true)
                Text("Dein Online Coaching läuft am \(SwissDay.display(date)) ab.")
                    .font(.app(12))
                    .foregroundStyle(AppColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, hPad).padding(.top, 8).padding(.bottom, 8)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Empty State

    /// Gute-Form-Kanon: schlichtes Icon, EINE Muted-Zeile — keine Überschrift.
    private var emptyState: some View {
        EmptyStateView(
            icon: "doc.text",
            message: "Du erhältst nach dem Onboarding deinen personalisierten Trainingsplan."
        )
    }
}

// MARK: - Locked Plan Info

/// Neutraler Hinweis für gesperrte Pläne (Liste + Detail) — ohne Preis,
/// Knopf oder Link (App-Store 3.1.1/3.1.3(b)).
enum LockedPlanInfo {
    static let message = "Online Coaching ist für dein Konto nicht aktiv. Sprich dafür deinen Trainer an."
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: ClientTrainingPlan
    let exerciseIdMap: [String: Int]

    private var phaseText: String {
        let labels = PlanSectionLabels.labels(for: plan.modality)
        return PlanSectionLabels.order
            .filter { (plan.sections[$0] ?? 0) > 0 }
            .map    { "\(labels[$0] ?? $0) \(plan.sections[$0]!)" }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 0) {
            // Linker Akzentstreifen
            Rectangle()
                .fill(plan.locked ? AppColor.muted : AppColor.primary)
                .frame(width: 3)

            HStack(spacing: 12) {
                ExerciseBadge(
                    exerciseName:  plan.coverExerciseName,
                    exerciseIdMap: exerciseIdMap,
                    color:         plan.locked ? AppColor.muted : AppColor.primary,
                    index:         nil,
                    liked:         false,
                    disliked:      false,
                    size:          72,
                    fallbackIcon:  plan.locked ? "lock"
                                   : PlanSectionLabels.usesSprings(plan.modality) ? "figure.pilates" : "dumbbell.fill"
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name ?? "Trainingsplan")
                        .font(.app(15, weight: .bold))
                        .foregroundStyle(AppColor.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if !phaseText.isEmpty {
                        Text(phaseText)
                            .font(.app(11))
                            .foregroundStyle(AppColor.muted)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if plan.locked {
                    // Gesperrt — neutral, ohne Abo-/Kauf-Hinweis
                    Image(systemName: "lock.fill")
                        .font(.app(14)).foregroundStyle(AppColor.muted)
                        .accessibilityLabel("Gesperrt")
                } else {
                    Image(systemName: "chevron.right")
                        .font(.app(14)).foregroundStyle(AppColor.muted)
                }
            }
            .padding(AppSpacing.card)
        }
        .frame(minHeight: 88)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }
}

// `InlineErrorBanner` lebt in `Views/Shared/SharedComponents.swift`.
