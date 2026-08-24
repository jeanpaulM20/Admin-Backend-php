import SwiftUI

// MARK: - CoachingPaywallView
// Pendant zu `coaching_paywall_screen.dart`.
// Wird angezeigt, wenn der Client auf einen `locked` Trainingsplan tippt.

struct CoachingPaywallView: View {
    let plan: ClientTrainingPlan

    // MARK: - State

    @State private var packages:   [CreditPackage] = []
    @State private var selectedId: String?          = nil
    @State private var isLoading  = false
    @State private var isPaying   = false
    @State private var errorMsg:  String?           = nil
    @State private var pendingInvoice: String?      = nil   // einfacher Alert (kein Polling)

    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed

    /// Sektions-Label-Mapping (wie Flutter)
    private static let sectionLabels: [String: String] = [
        "sonsomo":  "Aufwärmen",
        "main":     "Haupttraining",
        "core":     "Core",
        "mobility": "Mobilität"
    ]

    /// "5 Übungen · Aufwärmen 1 · Haupttraining 3 · Core 1"
    private var teaserMeta: String {
        let order = ["sonsomo", "main", "core", "mobility"]
        let sections = order
            .compactMap { key -> String? in
                guard let count = plan.sections[key], count > 0 else { return nil }
                let label = Self.sectionLabels[key] ?? key
                return "\(label) \(count)"
            }
            .joined(separator: " · ")
        let exercises = "\(plan.totalExercises) Übungen"
        return sections.isEmpty ? exercises : "\(exercises) · \(sections)"
    }

    /// Teuerster Einmonats-Plan → Referenzpreis für Ersparnis-Berechnung
    private var referenceMonthlyPrice: Double? {
        packages
            .filter { ($0.durationMonths ?? 1) == 1 }
            .max(by: { $0.price < $1.price })
            .map { $0.price }
    }

    private var selectedPackage: CreditPackage? {
        packages.first { $0.id == selectedId }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(AppColor.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        teaserCard
                            .padding(.bottom, 20)

                        Text("Trainingsplan · Chat-Feedback · Analysen")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColor.text)
                        Text("Wähle dein Abo und schalte alle Pläne frei.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColor.muted)
                            .padding(.top, 4)
                            .padding(.bottom, 14)

                        if let err = errorMsg {
                            InlineErrorBanner(message: err)
                                .padding(.bottom, 12)
                        }

                        ForEach(packages) { pkg in
                            TierCard(
                                package:          pkg,
                                isSelected:       selectedId == pkg.id,
                                referenceMonthly: referenceMonthlyPrice
                            ) {
                                selectedId = pkg.id
                            }
                            .padding(.bottom, 12)
                        }

                        unlockButton
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(AppColor.background)
        .navigationTitle("Online Coaching")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPackages() }
        .alert("Zahlung läuft", isPresented: Binding(
            get: { pendingInvoice != nil },
            set: { if !$0 { pendingInvoice = nil } }
        )) {
            Button("Schließen", role: .cancel) { pendingInvoice = nil }
            Button("Fertig")  { pendingInvoice = nil; dismiss() }
        } message: {
            if let inv = pendingInvoice {
                Text("Schließe die Zahlung im Browser ab (Rechnung \(inv)). Danach ist dein Online Coaching freigeschaltet.")
            }
        }
    }

    // MARK: - Teaser Card

    private var teaserCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.name ?? "Trainingsplan")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColor.text)
            Text(teaserMeta)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(AppColor.muted)
                .lineLimit(2)
        }
        .padding(AppSpacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }

    // MARK: - Unlock Button

    private var unlockButton: some View {
        Button {
            Task { await startPayment() }
        } label: {
            if isPaying {
                ProgressView().tint(.white)
            } else {
                Text("Jetzt freischalten")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(selectedId == nil || isPaying)
        .opacity((selectedId == nil || isPaying) ? 0.6 : 1)
    }

    // MARK: - Actions

    private func loadPackages() async {
        isLoading = true
        errorMsg  = nil
        do {
            packages = try await CreditsService.shared.listCoachingPackages()
            if selectedId == nil, let first = packages.first {
                selectedId = first.id
            }
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    private func startPayment() async {
        guard let pkg = selectedPackage, let clientId = auth.clientId else { return }
        isPaying = true
        errorMsg = nil
        do {
            let result = try await CreditsService.shared.initializePayment(
                clientId: clientId,
                packageId: Int(pkg.id) ?? 0
            )
            if let url = URL(string: result.redirectUrl) {
                await UIApplication.shared.open(url)
            }
            pendingInvoice = result.invoiceNumber
        } catch {
            errorMsg = error.localizedDescription
        }
        isPaying = false
    }
}

// MARK: - TierCard

private struct TierCard: View {
    let package:          CreditPackage
    let isSelected:       Bool
    let referenceMonthly: Double?
    let onTap:            () -> Void

    private var durationMonths: Int { package.durationMonths ?? 1 }

    /// Tier-Name aus der Laufzeit abgeleitet (wie Flutter): "Monat" / "Jahr"
    private var shortName: String { durationMonths >= 12 ? "Jahr" : "Monat" }

    /// Effektiver Monatspreis (bei Mehrmonatspaketen umgerechnet)
    private var perMonth: Double {
        durationMonths > 0 ? package.price / Double(durationMonths) : package.price
    }

    /// "= CHF X / Mt.  ·  −Y %  ·  N Credits" bzw. nur "N Credits"
    private var valueLine: String {
        if durationMonths > 1, let ref = referenceMonthly, perMonth < ref {
            let pct = Int(((1 - perMonth / ref) * 100).rounded())
            return "= CHF \(Int(perMonth.rounded())) / Mt.  ·  −\(pct) %  ·  \(package.credits) Credits"
        }
        return "\(package.credits) Credits"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Preis — fixe Spalte, damit alle Tier-Namen auf einer Achse starten.
                VStack(alignment: .leading, spacing: 0) {
                    Text("CHF \(Int(package.price.rounded()))")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(AppColor.text)
                        .lineLimit(1)
                    Text("/ \(shortName)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.muted)
                }
                .frame(width: 104, alignment: .leading)

                Spacer().frame(width: 16)

                // Name + Value
                VStack(alignment: .leading, spacing: 3) {
                    Text(shortName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColor.text)
                    Text(valueLine)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(width: 8)

                // Auswahl-Indikator — das einzige, ausreichende Zustandssignal.
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? AppColor.primary : AppColor.border)
            }
            .padding(AppSpacing.card)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(AppColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .stroke(isSelected ? AppColor.primary : AppColor.border,
                                    lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
