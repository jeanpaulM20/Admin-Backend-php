import SwiftUI

// MARK: - CreditsView

/// Pendant zu `CreditsScreen` in Flutter `credits_screen.dart`.
/// Wird aus dem Profil-Screen heraus via NavigationLink geöffnet.
struct CreditsView: View {
    @Environment(AuthViewModel.self)    private var auth
    @Environment(CreditsViewModel.self) private var credits

    // Purchase-Flow State
    @State private var purchasing    = false               // double-tap Guard
    @State private var agbTarget:    CreditPackage?        // welches Paket → AGB-Sheet
    @State private var methodTarget: CreditPackage?        // welches Paket → Zahlungsart-Sheet
    @State private var pendingPayment: PendingPayment?     // für Polling-Sheet
    @State private var toast: (msg: String, ok: Bool)? = nil

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if credits.isLoading && credits.credits.isEmpty && credits.packages.isEmpty {
                ProgressView("Lade Credits…").tint(AppColor.primary)
            } else if let e = credits.error {
                errorView(e)
            } else {
                contentList
            }

            // Toast
            if let t = toast {
                VStack {
                    Spacer()
                    ToastView(message: t.msg)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: toast != nil)
            }
        }
        .navigationTitle("Credits & Abos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if credits.credits.isEmpty && credits.packages.isEmpty {
                await credits.fetch(clientId: auth.clientId ?? "")
            }
        }
        .refreshable { await credits.fetch(clientId: auth.clientId ?? "") }
        // AGB-Sheet → danach Zahlungsart-Sheet
        .sheet(item: $agbTarget) { pkg in
            AGBSheet(package: pkg) { accepted in
                agbTarget = nil
                if accepted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        methodTarget = pkg
                    }
                }
            }
        }
        // Zahlungsart wählen
        .sheet(item: $methodTarget) { pkg in
            PaymentMethodSheet(package: pkg) { method in
                methodTarget = nil
                guard let method else { return }
                if method == "online" {
                    Task { await startOnlinePayment(pkg) }
                } else {
                    Task { await startBankTransfer(pkg) }
                }
            }
        }
        // Online-Zahlung Polling
        .sheet(item: $pendingPayment) { pending in
            PaymentPendingSheet(invoiceNumber: pending.id) { paid in
                pendingPayment = nil
                if paid {
                    showToast("Zahlung erfolgreich! Abo aktiviert.", ok: true)
                    Task { await credits.fetch(clientId: auth.clientId ?? "") }
                }
            }
        }
    }

    // MARK: - Content

    private var contentList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                SummaryCard(
                    activeCredits: credits.activeCredits,
                    packCount:     credits.credits.count
                )

                // Online Coaching Abos
                let coaching = credits.packages.filter(\.isCoaching)
                if !coaching.isEmpty {
                    SectionHeader(title: "ONLINE COACHING")
                    ForEach(coaching) { pkg in
                        PackageCard(package: pkg, purchasing: purchasing) {
                            agbTarget = pkg
                        }
                    }
                }

                // Lektionen & Pakete
                let regular = credits.packages.filter { !$0.isCoaching }
                if !regular.isEmpty {
                    SectionHeader(title: "LEKTIONEN & PAKETE")
                    ForEach(regular) { pkg in
                        PackageCard(package: pkg, purchasing: purchasing) {
                            agbTarget = pkg
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.title).foregroundStyle(.orange)
            Text(msg).font(.caption).foregroundStyle(AppColor.muted).multilineTextAlignment(.center)
            Button("Erneut laden") { Task { await credits.fetch(clientId: auth.clientId ?? "") } }
                .buttonStyle(.bordered).tint(AppColor.primary)
        }.padding()
    }

    // MARK: - Purchase flows

    /// Banküberweisung: Bestätigung → API-Call
    private func startBankTransfer(_ pkg: CreditPackage) async {
        purchasing = true
        do {
            let r = try await CreditsService.shared.purchasePackage(
                clientId: auth.clientId ?? "", packageId: pkg.id)
            showToast(r.message, ok: r.success)
            if r.success { await credits.fetch(clientId: auth.clientId ?? "") }
        } catch {
            showToast("Fehler: \(error.localizedDescription)", ok: false)
        }
        purchasing = false
    }

    /// Online-Zahlung (Saferpay): URL in Safari öffnen, dann Polling-Sheet anzeigen.
    private func startOnlinePayment(_ pkg: CreditPackage) async {
        purchasing = true
        do {
            let result = try await CreditsService.shared.initializePayment(
                clientId: auth.clientId ?? "",
                packageId: Int(pkg.id) ?? 0
            )
            // Safari öffnen
            if let url = URL(string: result.redirectUrl) {
                await UIApplication.shared.open(url)
            }
            // Polling-Sheet anzeigen
            pendingPayment = PendingPayment(id: result.invoiceNumber)
        } catch {
            showToast("Fehler: \(error.localizedDescription)", ok: false)
        }
        purchasing = false
    }

    private func showToast(_ msg: String, ok: Bool) {
        withAnimation { toast = (msg, ok) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { toast = nil }
        }
    }
}

// MARK: - SummaryCard

private struct SummaryCard: View {
    let activeCredits: Int
    let packCount:     Int

    var body: some View {
        let has = activeCredits > 0
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill((has ? AppColor.primary : Color.orange).opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: has ? "checkmark.circle.fill" : "info.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(has ? AppColor.primary : .orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(has
                     ? "\(activeCredits) Credit\(activeCredits == 1 ? "" : "s") verfügbar"
                     : "Keine aktiven Credits")
                    .font(.headline)
                    .foregroundStyle(has ? AppColor.primary : .orange)
                Text(has
                     ? "Aus \(packCount) Abo\(packCount == 1 ? "" : "s")"
                     : "Wähle ein Abo und bestelle direkt")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }
            Spacer()
        }
        .padding(16)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - SectionHeader

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(AppColor.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

// MARK: - PackageCard

private struct PackageCard: View {
    let package:    CreditPackage
    let purchasing: Bool
    let onBuy:      () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Name + Preis
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.name)
                        .font(.title3.bold())
                        .foregroundStyle(AppColor.text)
                    if let desc = package.description {
                        Text(desc)
                            .font(.callout)
                            .foregroundStyle(AppColor.muted)
                    }
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.priceFormatted)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColor.primary)
                    if let pps = package.perSessionFormatted {
                        Text(pps)
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }
                }
            }

            // Details
            HStack(spacing: 16) {
                Label(
                    "\(package.credits) \(package.credits == 1 ? "Lektion" : "Lektionen")",
                    systemImage: "dumbbell.fill"
                )
                .font(.caption)
                .foregroundStyle(AppColor.muted)

                if let months = package.durationMonths {
                    Label(
                        "\(months) \(months == 1 ? "Monat" : "Monate") gültig",
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                }
            }

            // Includes
            if let inc = package.includes, !inc.isEmpty {
                Divider().background(AppColor.muted.opacity(0.2))
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(inc.components(separatedBy: ", "), id: \.self) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption).foregroundStyle(.green)
                            Text(item)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(AppColor.text)
                        }
                    }
                }
            }

            // Kaufen-Button
            Button(action: onBuy) {
                if purchasing {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white).scaleEffect(0.8)
                        Text("Wird verarbeitet…")
                            .font(.callout.bold()).foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label("Abo kaufen", systemImage: "cart.fill")
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(purchasing)
            .padding(.vertical, 13)
            .background(purchasing ? AppColor.muted.opacity(0.3) : AppColor.primary,
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - AGBSheet

/// Pendant zu Flutter's `_showAgbSheet` — AGB mit Akzeptanz-Checkbox.
private struct AGBSheet: View {
    let package:    CreditPackage
    let onDismiss:  (Bool) -> Void
    @State private var accepted = false
    @Environment(\.dismiss) private var dismiss

    private let agbItems: [(num: String, title: String, text: String)] = [
        ("1", "Terminvereinbarung", "Für den Bezug sämtlicher Leistungen ist eine Terminvereinbarung (online oder telefonisch) erforderlich."),
        ("2", "Absagefrist", "Verhindert der Klient die Wahrnehmung eines Termins, ist die SIHLHEALTH GmbH spätestens 24 Stunden im Voraus zu informieren. Bei verspäteter Absage oder Nichterscheinen gilt die Leistung als erbracht und ist vollumfänglich geschuldet – auch bei unverschuldeter Verhinderung (ausgenommen ärztlich belegte Krankheit oder Unfall). Verspätungen führen nicht zu einer Verlängerung der Trainingszeit."),
        ("3", "Zahlungskonditionen", "Der Preis ist vor Leistungsbezug fällig. Abos sind innert 7 Tagen ab Unterzeichnung zahlbar. Die SIHLHEALTH GmbH behält sich vor, Leistungen bei Zahlungsverzug auszusetzen."),
        ("4", "Gültigkeit", "Nicht genutzte Leistungen verfallen nach Ablauf der Abo-Gültigkeit ohne Anspruch auf Rückerstattung."),
        ("5", "Depot", "Für den Herzfrequenzsensor wird ein Depot von CHF 20.00 erhoben, welches bei unbeschädigter Rückgabe nach Vertragsende erstattet wird."),
        ("6", "Gesundheitszustand", "Der Klient bestätigt seine Sporttauglichkeit. Er verpflichtet sich, die SIHLHEALTH GmbH über körperliche Einschränkungen oder gesundheitliche Risiken proaktiv zu informieren. Das Training erfolgt auf eigenes Risiko."),
        ("7", "Versicherung & Haftung", "Versicherung ist Sache des Klienten. Soweit gesetzlich zulässig, wird jegliche Haftung der SIHLHEALTH GmbH für Personen- oder Sachschäden ausgeschlossen."),
        ("8", "Wertsachen", "Für Verlust oder Beschädigung von persönlichen Gegenständen wird keine Haftung übernommen."),
        ("9", "Übertragbarkeit", "Leistungsansprüche sind persönlich und nicht auf Dritte übertragbar."),
        ("10", "Datenschutz", "Personenbezogene Daten werden nur im Rahmen der Leistungserbringung erhoben und verarbeitet."),
        ("11", "Schlussbestimmungen", "Änderungen bedürfen der Schriftform. Sollten einzelne Bestimmungen unwirksam sein, bleibt der Rest des Vertrages gültig."),
        ("12", "Gerichtsstand", "Gerichtsstand für alle Streitigkeiten ist Zürich."),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // AGB-Text scrollbar
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(agbItems, id: \.num) { item in
                            AGBItemView(num: item.num, title: item.title, text: item.text)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }

                // Footer: Checkbox + Button
                VStack(spacing: 14) {
                    Divider().background(AppColor.muted.opacity(0.2))
                    HStack(spacing: 10) {
                        Button {
                            withAnimation { accepted.toggle() }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(accepted ? AppColor.primary : AppColor.muted, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                                if accepted {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AppColor.primary).frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold()).foregroundStyle(.white)
                                }
                            }
                        }
                        Text("Ich habe die AGB gelesen und akzeptiere diese.")
                            .font(.callout).foregroundStyle(AppColor.text)
                    }

                    Button {
                        dismiss()
                        onDismiss(true)
                    } label: {
                        Text("AGB akzeptieren")
                            .font(.callout.bold()).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .background(accepted ? AppColor.primary : AppColor.muted.opacity(0.3),
                                in: RoundedRectangle(cornerRadius: 10))
                    .disabled(!accepted)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .padding(.top, 12)
                .background(AppColor.surface)
            }
            .background(AppColor.background)
            .navigationTitle("Allgemeine Geschäftsbedingungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                        onDismiss(false)
                    }
                    .foregroundStyle(AppColor.muted)
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct AGBItemView: View {
    let num:   String
    let title: String
    let text:  String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColor.primary.opacity(0.12))
                    .frame(width: 24, height: 24)
                Text(num)
                    .font(.caption.bold())
                    .foregroundStyle(AppColor.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.bold())
                    .foregroundStyle(AppColor.text)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                    .lineSpacing(4)
            }
        }
        .padding(.bottom, 14)
    }
}

// MARK: - PaymentMethodSheet

private struct PaymentMethodSheet: View {
    let package:   CreditPackage
    let onSelect:  (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(AppColor.muted.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            VStack(spacing: 6) {
                Text("Zahlungsmethode wählen")
                    .font(.title3.bold()).foregroundStyle(AppColor.text)
                Text("\(package.name) – \(package.priceFormatted)")
                    .font(.callout).foregroundStyle(AppColor.muted)
            }
            .padding(.vertical, 20)

            // Online
            PaymentMethodTile(
                icon: "creditcard.fill",
                title: "Online bezahlen",
                subtitle: "Kreditkarte, TWINT, PostFinance, Apple Pay"
            ) {
                dismiss(); onSelect("online")
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 12)

            // Bank
            PaymentMethodTile(
                icon: "building.columns.fill",
                title: "Banküberweisung",
                subtitle: "Rechnung per E-Mail mit QR-Einzahlungsschein"
            ) {
                dismiss(); onSelect("bank")
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 32)
        }
        .background(AppColor.surface)
        .presentationDetents([.height(340)])
        .onDisappear { onSelect(nil) }
    }
}

private struct PaymentMethodTile: View {
    let icon:     String
    let title:    String
    let subtitle: String
    let onTap:    () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColor.primary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(AppColor.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.bold()).foregroundStyle(AppColor.text)
                    Text(subtitle)
                        .font(.caption).foregroundStyle(AppColor.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(AppColor.muted)
            }
            .padding(16)
            .background(AppColor.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColor.muted.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PaymentPendingSheet

/// Pendant zu `_PaymentPendingDialog` — polling während der User in Safari bezahlt.
private struct PaymentPendingSheet: View {
    let invoiceNumber: String
    let onResult:      (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pollTask: Task<Void, Never>? = nil
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(AppColor.primary)
                    VStack(spacing: 8) {
                        Text("Zahlung läuft…")
                            .font(.headline).foregroundStyle(AppColor.text)
                        Text("Bitte schliesse die Zahlung in Safari ab.\nDieses Fenster schliesst automatisch nach erfolgreicher Zahlung.")
                            .font(.callout).foregroundStyle(AppColor.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button("Abbrechen") {
                            pollTask?.cancel()
                            dismiss()
                            onResult(false)
                        }
                        .buttonStyle(.bordered).tint(AppColor.muted)

                        Button {
                            Task { await checkManually() }
                        } label: {
                            if isChecking {
                                ProgressView().tint(.white).scaleEffect(0.8)
                                    .frame(width: 80)
                            } else {
                                Text("Status prüfen")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColor.primary)
                        .disabled(isChecking)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Zahlung ausstehend")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            var attempts = 0
            while !Task.isCancelled && attempts < 120 {   // max 6 min
                try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3s
                if Task.isCancelled { break }
                attempts += 1
                guard let status = try? await CreditsService.shared.checkPaymentStatus(
                    invoiceNumber: invoiceNumber) else { continue }
                if status == "paid" {
                    await MainActor.run {
                        pollTask?.cancel()
                        dismiss()
                        onResult(true)
                    }
                    return
                }
            }
        }
    }

    private func checkManually() async {
        isChecking = true
        if let status = try? await CreditsService.shared.checkPaymentStatus(
            invoiceNumber: invoiceNumber), status == "paid" {
            pollTask?.cancel()
            dismiss()
            onResult(true)
        }
        isChecking = false
    }
}

// MARK: - PendingPayment (sheet item)

/// Kapselt die Invoice-Nummer für das `.sheet(item:)` Binding.
struct PendingPayment: Identifiable {
    let id: String   // = invoiceNumber
}
