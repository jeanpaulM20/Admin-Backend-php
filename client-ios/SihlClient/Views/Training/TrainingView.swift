import SwiftUI

/// Liste der Trainingspläne mit Abo-Banner.
/// Pendant zu `screens/training_plan_list_screen.dart`.
///
/// `embedded`: Inhalt der Startseite (Chip „Trainingspläne") — ohne eigenen
/// Scroll-Bereich, eigenen Hintergrund und seitliche Ränder; die Startseite
/// scrollt, randet ein und lädt per Ziehen neu (`TrainingViewModel`).
struct TrainingView: View {
    var embedded = false

    @Environment(AuthViewModel.self)      private var auth
    @Environment(TrainingViewModel.self)  private var vm

    @State private var showTrialSheet   = false
    @State private var showExpiryAlert  = false
    @State private var expiryGuard      = false
    @State private var showCreditsSheet = false

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
        @Bindable var vm = vm
        return ZStack {
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
                maybeShowExpiryAlert()
            }
        }
        // Trial-Sheet
        .sheet(isPresented: $showTrialSheet) {
            TrialSheet {
                showTrialSheet = false
                Task {
                    guard let id = auth.clientId else { return }
                    if let err = await vm.activateTrial(clientId: id) {
                        vm.toast = AppToast(message: err, style: .error)
                    } else {
                        vm.toast = AppToast(message: "Test-Abo aktiviert — viel Erfolg!", style: .success)
                        await vm.fetch(clientId: id)
                    }
                }
            } onCancel: { showTrialSheet = false }
        }
        // Credits & Abos (Coaching-Sektion) — wie Flutter `_openCoachingCredits()`
        .sheet(isPresented: $showCreditsSheet, onDismiss: { reload() }) {
            NavigationStack { CreditsView() }
        }
        // Ablauf-Warnung
        .alert("Abo läuft bald ab", isPresented: $showExpiryAlert) {
            Button("Später", role: .cancel) {}
            Button("Verlängern") { showCreditsSheet = true }
        } message: {
            let d = vm.subscription.daysLeft ?? 0
            let when = d <= 0 ? "heute" : "in \(d) \(d == 1 ? "Tag" : "Tagen")"
            return Text("Dein Abo läuft \(when) ab. Verlängere jetzt, um nahtlos weiterzutrainieren.")
        }
        // Toast
        .appToast($vm.toast)
    }

    private func refresh() async {
        guard !isDemo, let id = auth.clientId else { return }
        await vm.fetch(clientId: id)
        maybeShowExpiryAlert()
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
            subscriptionBanner
                .padding(.top, embedded ? 0 : 12)

            if let err = vm.error {
                InlineErrorBanner(message: err)
                    .padding(.horizontal, hPad).padding(.top, 8)
            }

            if vm.plans.isEmpty && !vm.isLoading {
                emptyState
            } else {
                ForEach(vm.plans) { plan in
                    NavigationLink(destination: planDestination(plan)) {
                        PlanCard(plan: plan, exerciseIdMap: vm.exerciseIdMap)
                    }
                    .buttonStyle(.plain)
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
    private func planDestination(_ plan: ClientTrainingPlan) -> some View {
        if plan.locked {
            // Gesperrter Plan → Coaching-Paywall (wie Flutter CoachingPaywallScreen)
            CoachingPaywallView(plan: plan)
                .onDisappear { reload() }
        } else if let id = plan.id {
            TrainingPlanDetailView(
                planId: id,
                planName: plan.name,
                exerciseIdMap: vm.exerciseIdMap
            )
        }
    }

    // MARK: - Subscription Banner

    @ViewBuilder
    private var subscriptionBanner: some View {
        if !vm.isLoading && !vm.subscription.active {
            if vm.subscription.canStartTrial {
                SubBanner(
                    hPad:     hPad,
                    title: "1 Monat gratis testen",
                    subtitle: "Trainingsplan · HR-Analyse · Chat-Feedback",
                    onTap: { showTrialSheet = true }
                )
            } else {
                SubBanner(
                    hPad:     hPad,
                    title: "Trainingsplan · HR-Analyse · Chat-Feedback",
                    subtitle: "Online Coaching starten",
                    onTap: { showCreditsSheet = true }
                )
            }
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

    // MARK: - Reload

    /// Pendant zu Flutter `.then((_) => _load())` nach Paywall/Credits-Rückkehr.
    private func reload() {
        Task {
            guard let id = auth.clientId else { return }
            await vm.fetch(clientId: id)
            maybeShowExpiryAlert()
        }
    }

    // MARK: - Expiry Popup

    private func maybeShowExpiryAlert() {
        guard !expiryGuard else { return }
        let sub = vm.subscription
        guard sub.active, sub.expiringSoon, let vTo = sub.validTo else { return }
        let key   = "expiry_popup_\(vTo)"
        let today = String(Date().ISO8601Format().prefix(10))
        if UserDefaults.standard.string(forKey: key) == today { return }
        UserDefaults.standard.set(today, forKey: key)
        expiryGuard      = true
        showExpiryAlert  = true
    }
}

// MARK: - Subscription Banner

private struct SubBanner: View {
    var hPad: CGFloat = AppSpacing.screen
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.app(14, weight: .bold)).foregroundStyle(AppColor.text)
                    // Sekundäre Aktion — optisch zurückgenommen (CTA-Farbe ist
                    // exklusiv für die dominante Aktion des Screens reserviert)
                    Text(subtitle).font(.app(12)).foregroundStyle(AppColor.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.app(14))
                    .foregroundStyle(AppColor.muted)
            }
            .padding(.horizontal, AppSpacing.card).padding(.vertical, 14)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.control).stroke(AppColor.border, lineWidth: 1))
            .padding(.horizontal, hPad).padding(.top, 16).padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }
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
                    // Messing = Wertigkeits-/Beleg-Farbe der Marken-Palette
                    Text("Abo")
                        .font(.app(10, weight: .bold)).foregroundStyle(AppColor.brass)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppColor.brass.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
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

// MARK: - Trial Sheet

struct TrialSheet: View {
    let onConfirm: () -> Void
    let onCancel:  () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("1 Monat gratis testen")
                .font(.app(18, weight: .heavy))
                .foregroundStyle(AppColor.text)
                .padding(.bottom, 8)
            Text("Voller Zugriff: alle Trainingspläne · HR-Analyse · Chat-Feedback.\nKeine Zahlung. Endet automatisch nach 30 Tagen.")
                .font(.app(13)).foregroundStyle(AppColor.muted).lineSpacing(4)
                .padding(.bottom, 20)
            Button("Test-Abo aktivieren") { onConfirm() }
                .buttonStyle(PrimaryButtonStyle())
            Button("Später") { onCancel() }
                .font(.app(14)).foregroundStyle(AppColor.muted)
                .frame(maxWidth: .infinity).padding(.top, 8)
        }
        .padding(.horizontal, AppSpacing.screen).padding(.top, 20).padding(.bottom, 28)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .background(AppColor.surface.ignoresSafeArea())
    }
}
