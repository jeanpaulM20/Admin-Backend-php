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

    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed

    /// Sektions-Label-Mapping (wie Flutter)
    private static let sectionLabels: [String: String] = [
        "sonsomo":  "Aufwärmen",
        "main":     "Haupttraining",
        "core":     "Core",
        "mobility": "Mobilität"
    ]

    private var sectionSummary: String {
        let order = ["sonsomo", "main", "core", "mobility"]
        return order
            .compactMap { key -> String? in
                guard let count = plan.sections[key], count > 0 else { return nil }
                let label = Self.sectionLabels[key] ?? key
                return "\(label) \(count)"
            }
            .joined(separator: " · ")
    }

    /// Teuerster Einmonats-Plan → Referenzpreis für Ersparnis-Berechnung
    private var referenceMonthlyPrice: Double? {
        packages
            .filter { $0.durationMonths == 1 }
            .max(by: { $0.price < $1.price })
            .map { $0.price }
    }

    private var selectedPackage: CreditPackage? {
        packages.first { $0.id == selectedId }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                if isLoading {
                    ProgressView()
                        .tint(AppColor.primary)
                        .padding(.top, 40)
                } else if let err = errorMsg {
                    Text(err)
                        .foregroundStyle(AppColor.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    tierCards
                    unlockButton
                }
            }
            .padding(.vertical, 20)
            .padding(.bottom, 80)
        }
        .background(AppColor.background)
        .navigationTitle("Coaching freischalten")
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
                Text("Schließe die Zahlung im Browser ab.\nRechnung: \(inv)")
            }
        }
    }

    // MARK: - Teaser Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(AppColor.primary)
                Text("Gesperrter Plan")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColor.surface)
                    .clipShape(Capsule())
            }

            Text(plan.name ?? "Trainingsplan")
                .font(.title2.bold())
                .foregroundStyle(AppColor.text)

            Text("\(plan.totalExercises) Übungen · \(sectionSummary)")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)

            Divider().overlay(AppColor.border)

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(AppColor.primary)
                    .font(.footnote)
                Text("Dieser Plan ist nur für Coaching-Mitglieder verfügbar. Wähle ein Abo, um sofort Zugang zu erhalten.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Tier Cards

    @ViewBuilder
    private var tierCards: some View {
        VStack(spacing: 12) {
            Text("Coaching-Abo wählen")
                .font(.headline)
                .foregroundStyle(AppColor.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            ForEach(packages) { pkg in
                TierCard(
                    package:           pkg,
                    isSelected:        selectedId == pkg.id,
                    referenceMonthly:  referenceMonthlyPrice
                ) {
                    selectedId = pkg.id
                }
            }
        }
    }

    // MARK: - Unlock Button

    private var unlockButton: some View {
        Button {
            Task { await startPayment() }
        } label: {
            Group {
                if isPaying {
                    ProgressView().tint(.white)
                } else {
                    Label("Jetzt freischalten", systemImage: "lock.open.fill")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(selectedId != nil ? AppColor.primary : AppColor.border)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(selectedId == nil || isPaying)
        .padding(.horizontal, 16)
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
            errorMsg = "Pakete konnten nicht geladen werden: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func startPayment() async {
        guard let pkg = selectedPackage else { return }
        // clientId aus Auth-Daten – analog CreditsView via Environment AuthViewModel.
        // Hier aus dem TrainingPlan-Objekt ablesen (clientId ist dort gesetzt).
        guard let clientId = plan.clientId.map({ "\($0)" }) else {
            errorMsg = "Client-ID nicht verfügbar."
            return
        }
        isPaying = true
        errorMsg = nil
        do {
            let result = try await CreditsService.shared.initializePayment(
                clientId: clientId,
                packageId: pkg.id
            )
            if let url = URL(string: result.redirectUrl) {
                await UIApplication.shared.open(url)
            }
            pendingInvoice = result.invoiceNumber
        } catch {
            errorMsg = "Zahlung konnte nicht gestartet werden: \(error.localizedDescription)"
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

    /// Effektiver Monatspreis (bei Mehrmonatspaketen umgerechnet)
    private var effectiveMonthly: Double {
        guard let months = package.durationMonths, months > 1 else { return package.price }
        return package.price / Double(months)
    }

    /// Ersparnis-Prozent gegenüber Referenz-Monatsabo
    private var savingsPercent: Int? {
        guard let ref = referenceMonthly,
              let months = package.durationMonths,
              months > 1,
              ref > 0
        else { return nil }
        let pct = (ref - effectiveMonthly) / ref * 100
        return pct > 0 ? Int(pct.rounded()) : nil
    }

    /// Preiszeile: "CHF 89 / Monat" oder "CHF 890 / Jahr"
    private var priceLabel: String {
        let f = NumberFormatter()
        f.numberStyle          = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "de_CH")
        let priceStr = f.string(from: NSNumber(value: package.price)) ?? "\(Int(package.price))"
        if let months = package.durationMonths, months == 12 {
            return "CHF \(priceStr) / Jahr"
        }
        return "CHF \(priceStr) / Monat"
    }

    /// Zusatzbeschriftung für Mehrmonats-Pakete: "= CHF X / Mt. · -Y%"
    private var savingsLine: String? {
        guard let months = package.durationMonths, months > 1 else { return nil }
        let f = NumberFormatter()
        f.numberStyle          = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "de_CH")
        let mStr = f.string(from: NSNumber(value: effectiveMonthly)) ?? "\(Int(effectiveMonthly))"
        var line = "= CHF \(mStr) / Mt."
        if let pct = savingsPercent { line += " · -\(pct)%" }
        if package.credits > 0      { line += " · \(package.credits) Credits" }
        return line
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                // Radio
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppColor.primary : AppColor.muted)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(package.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(AppColor.text)
                        if let pct = savingsPercent {
                            Text("-\(pct)%")
                                .font(.caption2.bold())
                                .foregroundStyle(AppColor.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(AppColor.primary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Text(priceLabel)
                        .font(.title3.bold())
                        .foregroundStyle(AppColor.text)

                    if let line = savingsLine {
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(AppColor.primary)
                    }

                    if let desc = package.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                            .padding(.top, 2)
                    }

                    if let inc = package.includes, !inc.isEmpty {
                        Text(inc)
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? AppColor.primary : AppColor.border,
                                    lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}
