import SwiftUI

/// "Training"-Tab — Liste der Trainingspläne mit Abo-Banner.
/// Pendant zu `screens/training_plan_list_screen.dart`.
struct TrainingView: View {
    @Environment(AuthViewModel.self)      private var auth
    @Environment(TrainingViewModel.self)  private var vm

    @State private var showTrialSheet  = false
    @State private var showExpiryAlert = false
    @State private var expiryGuard     = false

    var body: some View {
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
                        vm.toast = (err, false)
                    } else {
                        vm.toast = ("Test-Abo aktiviert — viel Erfolg!", true)
                        await vm.fetch(clientId: id)
                    }
                }
            } onCancel: { showTrialSheet = false }
        }
        // Ablauf-Warnung
        .alert("Abo läuft bald ab", isPresented: $showExpiryAlert) {
            Button("Später", role: .cancel) {}
        } message: {
            let d = vm.subscription.daysLeft ?? 0
            let when = d <= 0 ? "heute" : "in \(d) \(d == 1 ? "Tag" : "Tagen")"
            return Text("Dein Abo läuft \(when) ab. Verlängere jetzt, um nahtlos weiterzutrainieren.")
        }
        // Toast
        .overlay(alignment: .bottom) {
            if let t = vm.toast {
                ToastView(message: t.message)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { vm.toast = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                subscriptionBanner

                if let err = vm.error {
                    TrainingErrorBanner(message: err)
                        .padding(.horizontal, 16).padding(.top, 8)
                }

                if vm.plans.isEmpty && !vm.isLoading {
                    emptyState
                } else {
                    ForEach(vm.plans) { plan in
                        NavigationLink(value: plan) {
                            PlanCard(plan: plan, exerciseIdMap: vm.exerciseIdMap)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationDestination(for: ClientTrainingPlan.self) { plan in
            if let id = plan.id {
                TrainingPlanDetailView(
                    planId: id,
                    planName: plan.name,
                    exerciseIdMap: vm.exerciseIdMap
                )
            }
        }
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
                    onTap: {}  // TODO: Coaching-Paywall
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48)).foregroundStyle(AppColor.muted)
            Text("Noch keine Trainingspläne")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(AppColor.text)
            Text("Du erhältst nach dem Onboarding deinen personalisierten Trainingsplan.")
                .font(.system(size: 13)).foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
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
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(AppColor.text)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(AppColor.orange)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColor.orange.opacity(0.8))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.border, lineWidth: 1))
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
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
                    size:          72
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name ?? "Trainingsplan")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColor.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if !phaseText.isEmpty {
                        Text(phaseText)
                            .font(.system(size: 11))
                            .foregroundStyle(AppColor.muted)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if plan.locked {
                    Text("Abo")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(AppColor.orange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppColor.orange.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14)).foregroundStyle(AppColor.muted)
                }
            }
            .padding(16)
        }
        .frame(minHeight: 88)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Error Banner

private struct TrainingErrorBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16)).foregroundStyle(AppColor.red)
            Text(message).font(.system(size: 13)).foregroundStyle(AppColor.red)
        }
        .padding(12)
        .background(AppColor.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Trial Sheet

struct TrialSheet: View {
    let onConfirm: () -> Void
    let onCancel:  () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("1 Monat gratis testen")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(AppColor.text)
                .padding(.bottom, 8)
            Text("Voller Zugriff: alle Trainingspläne · HR-Analyse · Chat-Feedback.\nKeine Zahlung. Endet automatisch nach 30 Tagen.")
                .font(.system(size: 13)).foregroundStyle(AppColor.muted).lineSpacing(4)
                .padding(.bottom, 20)
            Button("Test-Abo aktivieren") { onConfirm() }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColor.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button("Später") { onCancel() }
                .font(.system(size: 14)).foregroundStyle(AppColor.muted)
                .frame(maxWidth: .infinity).padding(.top, 8)
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 28)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .background(AppColor.surface.ignoresSafeArea())
    }
}
