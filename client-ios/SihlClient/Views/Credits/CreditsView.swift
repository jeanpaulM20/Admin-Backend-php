import SwiftUI

// MARK: - CreditsView

/// Lektionen & Guthaben für Personal Training vor Ort.
/// Pendant zu `CreditsScreen` in Flutter `credits_screen.dart`.
/// Online-Coaching-Abos werden hier bewusst nicht angeboten (App-Store 3.1.1);
/// Lektionen vor Ort sind physische Leistungen (3.1.3(e)).
struct CreditsView: View {
    @Environment(AuthViewModel.self)    private var auth
    @Environment(CreditsViewModel.self) private var credits

    // Kauf-Ablauf
    @State private var selectedId:   String?               // gewähltes Paket
    @State private var purchasing    = false               // Doppeltipp-Schutz
    @State private var agbTarget:    CreditPackage?        // welches Paket → AGB-Sheet
    @State private var methodTarget: CreditPackage?        // welches Paket → Zahlungsart-Sheet
    @State private var confirmTarget: CreditPackage?       // welches Paket → Bestätigungsdialog (Bank)
    @State private var pendingPayment: PendingPayment?     // für Polling-Sheet
    @State private var nextAfterAgb: CreditPackage?        // AGB akzeptiert → nach Dismiss Zahlungsart öffnen
    @State private var nextConfirm: CreditPackage?         // Bank gewählt → nach Dismiss Bestätigung öffnen
    @State private var toast: AppToast? = nil

    private var selectedPackage: CreditPackage? {
        credits.packages.first { $0.id == selectedId } ?? credits.packages.first
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if credits.isLoading && credits.credits.isEmpty && credits.packages.isEmpty {
                ProgressView("Lade Guthaben…").tint(AppColor.primary)
            } else if let e = credits.error {
                ErrorStateView(message: e) {
                    Task { await credits.fetch(clientId: auth.clientId ?? "") }
                }
            } else {
                contentList
            }
        }
        .appToast($toast)
        .navigationTitle("Lektionen & Guthaben")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if credits.credits.isEmpty && credits.packages.isEmpty {
                await credits.fetch(clientId: auth.clientId ?? "")
            }
        }
        .refreshable { await credits.fetch(clientId: auth.clientId ?? "") }
        // AGB-Sheet → danach Zahlungsart-Sheet. Verkettung über onDismiss statt
        // eines 0.3s-Timers: onDismiss läuft erst NACH der Dismiss-Animation,
        // die Folge-Präsentation kann also nicht verschluckt werden.
        .sheet(item: $agbTarget, onDismiss: {
            if let pkg = nextAfterAgb {
                nextAfterAgb = nil
                methodTarget = pkg
            }
        }) { pkg in
            AGBSheet(package: pkg) { accepted in
                if accepted { nextAfterAgb = pkg }
                agbTarget = nil
            }
        }
        // Zahlungsart wählen
        .sheet(item: $methodTarget, onDismiss: {
            if let pkg = nextConfirm {
                nextConfirm = nil
                confirmTarget = pkg
            }
        }) { pkg in
            PaymentMethodSheet(package: pkg) { method in
                methodTarget = nil
                guard let method else { return }
                if method == "online" {
                    Task { await startOnlinePayment(pkg) }
                } else {
                    nextConfirm = pkg
                }
            }
        }
        // Bestätigungsdialog vor Banküberweisung (wie Flutter `_showConfirmDialog`)
        .alert("Kauf bestätigen", isPresented: Binding(
            get: { confirmTarget != nil },
            set: { if !$0 { confirmTarget = nil } }
        ), presenting: confirmTarget) { pkg in
            Button("Abbrechen", role: .cancel) { confirmTarget = nil }
            Button("Kauf bestätigen") {
                confirmTarget = nil
                Task { await startBankTransfer(pkg) }
            }
        } message: { pkg in
            Text(confirmMessage(for: pkg))
        }
        // Online-Zahlung: Polling mit sauberem Abschluss
        .sheet(item: $pendingPayment) { pending in
            PaymentPendingSheet(invoiceNumber: pending.id) { outcome in
                pendingPayment = nil
                switch outcome {
                case .paid:
                    showToast("Zahlung erfolgreich. Deine Lektionen sind gutgeschrieben.", ok: true)
                case .open:
                    showToast("Rechnung \(pending.id) bleibt offen. Du findest sie im Profil unter Rechnungen.", ok: false)
                }
                Task { await credits.fetch(clientId: auth.clientId ?? "") }
            }
        }
    }

    // MARK: - Content

    private var contentList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SummaryCard(
                    activeCredits: credits.activeCredits,
                    packCount:     credits.activePackCount
                )

                if credits.packages.isEmpty {
                    EmptyStateView(
                        icon: "tag",
                        message: "Zurzeit sind keine Lektionen-Pakete verfügbar."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        OverlineHeader(title: "LEKTIONEN-PAKETE")
                        Text("Gilt für Personal-Training-Lektionen im Studio.")
                            .font(.app(13))
                            .foregroundStyle(AppColor.muted)
                    }
                    .padding(.top, 8)

                    ForEach(credits.packages) { pkg in
                        PackageCard(
                            package:    pkg,
                            isSelected: pkg.id == selectedPackage?.id
                        ) {
                            selectedId = pkg.id
                        }
                    }

                    buyButton
                        .padding(.top, 4)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, 16)
        }
    }

    /// Die eine Hauptaktion des Screens (Ein-CTA-Prinzip)
    private var buyButton: some View {
        Button {
            if let pkg = selectedPackage { agbTarget = pkg }
        } label: {
            if purchasing {
                HStack(spacing: 8) {
                    ProgressView().tint(AppColor.white).scaleEffect(0.8)
                    Text("Wird verarbeitet…")
                }
            } else {
                Text("Paket kaufen")
            }
        }
        .buttonStyle(PrimaryButtonStyle(fill: purchasing ? AppColor.muted.opacity(0.3) : AppColor.cta))
        .disabled(purchasing || selectedPackage == nil)
    }

    // MARK: - Purchase flows

    /// Text des Bestätigungsdialogs: Lektionen / Gültigkeit / Preis + Zahlungsfrist-Hinweis.
    private func confirmMessage(for pkg: CreditPackage) -> String {
        var lines = [pkg.name, "", "Lektionen: \(pkg.credits)"]
        if let months = pkg.durationMonths {
            lines.append("Gültigkeit: \(months) \(months == 1 ? "Monat" : "Monate")")
        }
        lines.append("Preis: \(pkg.priceFormattedExact)")
        lines.append("")
        lines.append("Die Rechnung wird per E-Mail zugestellt und ist innert 7 Tagen zahlbar.")
        return lines.joined(separator: "\n")
    }

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

    /// Online-Zahlung (Saferpay): URL im Browser öffnen, dann Polling-Sheet anzeigen.
    private func startOnlinePayment(_ pkg: CreditPackage) async {
        purchasing = true
        showToast("Zahlung wird vorbereitet…", ok: true)
        do {
            let result = try await CreditsService.shared.initializePayment(
                clientId: auth.clientId ?? "",
                packageId: Int(pkg.id) ?? 0
            )
            withAnimation { toast = nil }
            guard let url = URL(string: result.redirectUrl),
                  await UIApplication.shared.open(url) else {
                showToast("Die Zahlungsseite konnte nicht geöffnet werden. Rechnung \(result.invoiceNumber) bleibt offen.", ok: false)
                await credits.fetch(clientId: auth.clientId ?? "")
                purchasing = false
                return
            }
            pendingPayment = PendingPayment(id: result.invoiceNumber)
        } catch {
            withAnimation { toast = nil }
            showToast("Fehler: \(error.localizedDescription)", ok: false)
        }
        purchasing = false
    }

    private func showToast(_ msg: String, ok: Bool) {
        // Präsentation + Auto-Dismiss übernimmt der `.appToast`-Modifier.
        withAnimation { toast = AppToast(message: msg, style: ok ? .success : .error) }
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
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .fill((has ? AppColor.primary : AppColor.orange).opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: has ? "checkmark.circle.fill" : "info.circle")
                    .font(.app(22))
                    .foregroundStyle(has ? AppColor.primary : AppColor.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(has
                     ? "\(activeCredits) \(activeCredits == 1 ? "Lektion" : "Lektionen") verfügbar"
                     : "Kein Guthaben für Lektionen")
                    .font(.headline)
                    .foregroundStyle(has ? AppColor.primary : AppColor.orange)
                Text(has
                     ? "Aus \(packCount) \(packCount == 1 ? "Paket" : "Paketen") · Personal Training im Studio"
                     : "Wähle ein Paket für dein Personal Training im Studio")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }
            Spacer()
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PackageCard

/// Auswählbare Paket-Karte: fixe Preisspalte links, EINE punktgetrennte
/// Muted-Wertzeile, Auswahl-Indikator rechts. Gekauft wird über den einen CTA.
private struct PackageCard: View {
    let package:    CreditPackage
    let isSelected: Bool
    let onSelect:   () -> Void

    /// "N Lektionen · M Monate gültig"
    private var valueLine: String {
        var parts = ["\(package.credits) \(package.credits == 1 ? "Lektion" : "Lektionen")"]
        if let months = package.durationMonths {
            parts.append("\(months) \(months == 1 ? "Monat" : "Monate") gültig")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 0) {
                // Preis — fixe Spalte, damit alle Paketnamen auf einer Achse starten.
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.priceFormatted)
                        .font(.app(19, weight: .heavy))
                        .foregroundStyle(AppColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let pps = package.perSessionFormatted {
                        Text(pps)
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }
                }
                .frame(width: 104, alignment: .leading)

                Spacer().frame(width: 16)

                // Name + Wertzeile
                VStack(alignment: .leading, spacing: 3) {
                    Text(package.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.text)
                    if let desc = package.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }
                    Text(valueLine)
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(width: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.app(20))
                    .foregroundStyle(isSelected ? AppColor.primary : AppColor.border)
                    .accessibilityHidden(true)
            }
            .padding(AppSpacing.card)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(isSelected ? AppColor.primary : AppColor.muted.opacity(0.15),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    // Checkbox samt Text als EIN Bedienelement (grössere Trefferfläche, VoiceOver)
                    Button {
                        withAnimation { accepted.toggle() }
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(accepted ? AppColor.primary : AppColor.muted, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                                if accepted {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AppColor.primary).frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold()).foregroundStyle(AppColor.white)
                                }
                            }
                            .accessibilityHidden(true)
                            Text("Ich habe die AGB gelesen und akzeptiere diese.")
                                .font(.callout).foregroundStyle(AppColor.text)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Ich habe die AGB gelesen und akzeptiere diese.")
                    .accessibilityValue(accepted ? "Ausgewählt" : "Nicht ausgewählt")
                    .accessibilityAddTraits(accepted ? [.isButton, .isSelected] : .isButton)

                    Button {
                        dismiss()
                        onDismiss(true)
                    } label: {
                        Text("AGB akzeptieren")
                            .font(.callout.bold()).foregroundStyle(AppColor.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .background(accepted ? AppColor.primary : AppColor.muted.opacity(0.3),
                                in: RoundedRectangle(cornerRadius: AppRadius.control))
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
    @State private var didSelect = false

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
                Text("\(package.name) – \(package.priceFormattedExact)")
                    .font(.callout).foregroundStyle(AppColor.muted)
                Text("Personal-Training-Lektionen im Studio")
                    .font(.caption).foregroundStyle(AppColor.muted)
            }
            .multilineTextAlignment(.center)
            .padding(.vertical, 20)

            // Online
            PaymentMethodTile(
                icon: "creditcard.fill",
                title: "Online bezahlen",
                subtitle: "Kreditkarte, TWINT, PostFinance, Apple Pay"
            ) {
                didSelect = true
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
                didSelect = true
                dismiss(); onSelect("bank")
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 32)
        }
        .background(AppColor.surface)
        .presentationDetents([.height(360)])
        .onDisappear { if !didSelect { onSelect(nil) } }
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
                    RoundedRectangle(cornerRadius: AppRadius.control)
                        .fill(AppColor.primary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.app(20))
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
            .padding(AppSpacing.card)
            .background(AppColor.background, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PaymentPendingSheet

/// Pendant zu `_PaymentPendingDialog` — fragt den Status ab, während im Browser
/// bezahlt wird. Meldet Erfolg, Fehlschlag und Zeitüberschreitung mit Ausweg.
private struct PaymentPendingSheet: View {
    enum Outcome { case paid, open }

    private enum Phase: Equatable {
        case waiting
        case timedOut
        case failed(String)
    }

    let invoiceNumber: String
    let onResult:      (Outcome) -> Void

    @Environment(\.dismiss)    private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var pollTask: Task<Void, Never>? = nil
    @State private var phase: Phase = .waiting
    @State private var isChecking = false
    @State private var hint: String?
    @State private var reported = false

    private static let interval: UInt64   = 3_000_000_000  // 3 s
    private static let maxAttempts        = 120             // ~6 min
    private static let maxNetworkErrors   = 10              // ~30 s ohne Verbindung

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    statusIcon
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.headline).foregroundStyle(AppColor.text)
                        Text(message)
                            .font(.callout).foregroundStyle(AppColor.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        if let hint {
                            Text(hint)
                                .font(.footnote).foregroundStyle(AppColor.muted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button(phase == .waiting ? "Abbrechen" : "Schliessen") {
                            finish(.open)
                        }
                        .buttonStyle(.bordered).tint(AppColor.muted)

                        Button {
                            if phase == .waiting {
                                Task { await checkManually() }
                            } else {
                                startPolling()
                            }
                        } label: {
                            if isChecking {
                                ProgressView().tint(AppColor.white).scaleEffect(0.8)
                                    .frame(width: 80)
                            } else {
                                Text(phase == .waiting ? "Status prüfen" : "Erneut prüfen")
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
        // Rückkehr aus dem Browser → sofort prüfen statt bis zum nächsten Takt zu warten
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, phase == .waiting { Task { await checkOnce(manual: false) } }
        }
        .onDisappear {
            pollTask?.cancel()
            // Wegwischen zählt wie Schliessen — Ergebnis immer melden
            if !reported { reported = true; onResult(.open) }
        }
    }

    // MARK: - Darstellung

    @ViewBuilder
    private var statusIcon: some View {
        switch phase {
        case .waiting:
            ProgressView().scaleEffect(1.5).tint(AppColor.primary)
        case .timedOut:
            Image(systemName: "clock.badge.questionmark")
                .font(.app(40)).foregroundStyle(AppColor.muted)
                .accessibilityHidden(true)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.app(40)).foregroundStyle(AppColor.orange)
                .accessibilityHidden(true)
        }
    }

    private var title: String {
        switch phase {
        case .waiting:  return "Zahlung läuft…"
        case .timedOut: return "Zahlung noch nicht bestätigt"
        case .failed:   return "Zahlung nicht abgeschlossen"
        }
    }

    private var openInvoiceHint: String {
        "Ohne Zahlungseingang bleibt die Rechnung \(invoiceNumber) offen. Du findest sie im Profil unter Rechnungen und kannst sie dort per QR-Rechnung bezahlen."
    }

    private var message: String {
        switch phase {
        case .waiting:
            return "Bitte schliesse die Zahlung im Browser ab.\nDieses Fenster schliesst automatisch, sobald die Zahlung eingegangen ist."
        case .timedOut:
            return "Wir haben noch keinen Zahlungseingang erhalten. Falls du bezahlt hast, prüfe den Status erneut.\n\n\(openInvoiceHint)"
        case .failed(let reason):
            return "\(reason)\n\n\(openInvoiceHint)"
        }
    }

    // MARK: - Ablauf

    private func startPolling() {
        pollTask?.cancel()
        phase = .waiting
        hint  = nil
        pollTask = Task { @MainActor in
            var networkErrors = 0
            for _ in 0..<Self.maxAttempts {
                try? await Task.sleep(nanoseconds: Self.interval)
                if Task.isCancelled { return }
                do {
                    let status = try await CreditsService.shared.checkPaymentStatus(invoiceNumber: invoiceNumber)
                    networkErrors = 0
                    if Task.isCancelled { return }
                    if handle(status) { return }
                } catch {
                    if Task.isCancelled { return }
                    networkErrors += 1
                    if networkErrors >= Self.maxNetworkErrors {
                        phase = .failed("Der Zahlungsstatus konnte nicht abgefragt werden. Bitte prüfe deine Internetverbindung.")
                        return
                    }
                }
            }
            if !Task.isCancelled { phase = .timedOut }
        }
    }

    /// true = Ablauf beendet (bezahlt oder fehlgeschlagen)
    @discardableResult
    private func handle(_ status: PaymentStatus) -> Bool {
        switch status {
        case .paid:
            finish(.paid)
            return true
        case .failed(let reason):
            pollTask?.cancel()
            phase = .failed(reason)
            return true
        case .pending:
            return false
        }
    }

    private func checkManually() async {
        isChecking = true
        await checkOnce(manual: true)
        isChecking = false
    }

    private func checkOnce(manual: Bool) async {
        do {
            let status = try await CreditsService.shared.checkPaymentStatus(invoiceNumber: invoiceNumber)
            if !handle(status), manual { hint = "Noch kein Zahlungseingang." }
        } catch {
            if manual { hint = "Status konnte nicht abgefragt werden. Bitte prüfe deine Internetverbindung." }
        }
    }

    private func finish(_ outcome: Outcome) {
        pollTask?.cancel()
        guard !reported else { return }
        reported = true
        dismiss()
        onResult(outcome)
    }
}

// MARK: - PendingPayment (sheet item)

/// Kapselt die Invoice-Nummer für das `.sheet(item:)` Binding.
struct PendingPayment: Identifiable {
    let id: String   // = invoiceNumber
}
