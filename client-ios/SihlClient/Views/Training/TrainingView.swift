import SwiftUI

/// "Training"-Tab — Liste der Trainingspläne mit Abo-Banner.
/// Pendant zu `screens/training_plan_list_screen.dart`.
struct TrainingView: View {
    @Environment(AuthViewModel.self)      private var auth
    @Environment(TrainingViewModel.self)  private var vm

    @State private var showTrialSheet   = false
    @State private var showExpiryAlert  = false
    @State private var expiryGuard      = false
    @State private var showCreditsSheet = false
    @State private var showRecord       = false
    @State private var showTours        = false

    var body: some View {
        @Bindable var vm = vm
        ZStack {
            AppColor.background.ignoresSafeArea()
            if vm.isLoading && vm.plans.isEmpty {
                LoadingView(message: "Lade Trainingspläne…")
            } else {
                content
            }
        }
        .task {
            if vm.plans.isEmpty, let id = auth.clientId {
                await vm.fetch(clientId: id)
                maybeShowExpiryAlert()
            }
        }
        .refreshable {
            if let id = auth.clientId {
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

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                recordCard

                toursCard

                subscriptionBanner

                if let err = vm.error {
                    InlineErrorBanner(message: err)
                        .padding(.horizontal, AppSpacing.screen).padding(.top, 8)
                }

                if vm.plans.isEmpty && !vm.isLoading {
                    emptyState
                } else {
                    ForEach(vm.plans) { plan in
                        NavigationLink(value: plan) {
                            PlanCard(plan: plan, exerciseIdMap: vm.exerciseIdMap)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, AppSpacing.screen)
                        .padding(.bottom, AppSpacing.stack)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, AppSpacing.bottomInset)
                }
            }
        }
        .navigationDestination(isPresented: $showRecord) {
            RecordWorkoutView()
        }
        .navigationDestination(isPresented: $showTours) {
            TourDiscoveryView()
        }
        .navigationDestination(for: ClientTrainingPlan.self) { plan in
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
    }

    // MARK: - Training aufzeichnen (Phase-1-Tracking, s. KONZEPT-TRAINING-TRACKING.md)

    private var recordCard: some View {
        HStack(spacing: 12) {
            // Dominanter CTA des Screens → exklusives Erdton-Orange
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .fill(AppColor.cta)
                    .frame(width: 40, height: 40)
                Image(systemName: "record.circle")
                    .font(.app(20))
                    .foregroundStyle(AppColor.text)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Training aufzeichnen")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColor.text)
                Text("Herzfrequenz live mit dem Brustgurt tracken")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColor.cta)
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.cta, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { showRecord = true }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, 12)
        .padding(.bottom, AppSpacing.stack)
    }

    // MARK: - Touren entdecken (T1, s. KONZEPT-TOUREN.md)

    private var toursCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .fill(AppColor.primary.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "map")
                    .font(.app(18))
                    .foregroundStyle(AppColor.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Touren entdecken")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColor.text)
                Text("Wander-, Lauf- und Velorouten, Vita Parcours und Finnenbahnen in deiner Nähe")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColor.muted)
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { showTours = true }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.bottom, AppSpacing.stack)
    }

    // MARK: - Subscription Banner

    @ViewBuilder
    private var subscriptionBanner: some View {
        if !vm.isLoading && !vm.subscription.active {
            if vm.subscription.canStartTrial {
                SubBanner(
                    title: "1 Monat gratis testen",
                    subtitle: "Trainingsplan · HR-Analyse · Chat-Feedback",
                    onTap: { showTrialSheet = true }
                )
            } else {
                SubBanner(
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
            .padding(.horizontal, AppSpacing.screen).padding(.top, 16).padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: ClientTrainingPlan
    let exerciseIdMap: [String: Int]

    private static let sectionOrder  = ["sonsomo", "main", "core", "mobility"]
    private static let sectionLabels: [String: String] = [
        "sonsomo":  "Aufwärmen",
        "main":     "Haupttraining",
        "core":     "Core",
        "mobility": "Mobilität",
    ]

    private var phaseText: String {
        Self.sectionOrder
            .filter { (plan.sections[$0] ?? 0) > 0 }
            .map    { "\(Self.sectionLabels[$0] ?? $0) \(plan.sections[$0]!)" }
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
                    fallbackIcon:  plan.locked ? "lock" : "dumbbell.fill"
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
