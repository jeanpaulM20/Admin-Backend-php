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
    @State private var confirmTarget: CreditPackage?       // welches Paket → Bestätigungsdialog
    @State private var nextAfterAgb: CreditPackage?        // AGB akzeptiert → nach Dismiss Bestätigung öffnen
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
        // AGB-Sheet → danach Bestätigung. Bezahlt wird nicht in der App,
        // sondern per Rechnung mit QR-Einzahlungsschein. Verkettung über
        // onDismiss: läuft erst NACH der Dismiss-Animation, die Bestätigung
        // kann also nicht verschluckt werden.
        .sheet(item: $agbTarget, onDismiss: {
            if let pkg = nextAfterAgb {
                nextAfterAgb = nil
                confirmTarget = pkg
            }
        }) { pkg in
            AGBSheet(package: pkg) { accepted in
                if accepted { nextAfterAgb = pkg }
                agbTarget = nil
            }
        }
        // Bestätigung der Bestellung auf Rechnung (wie Flutter `_showConfirmDialog`)
        .alert("Kauf bestätigen", isPresented: Binding(
            get: { confirmTarget != nil },
            set: { if !$0 { confirmTarget = nil } }
        ), presenting: confirmTarget) { pkg in
            Button("Abbrechen", role: .cancel) { confirmTarget = nil }
            Button("Auf Rechnung bestellen") {
                confirmTarget = nil
                Task { await orderOnInvoice(pkg) }
            }
        } message: { pkg in
            Text(confirmMessage(for: pkg))
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
                        Text("Gilt für deine Personal-Training-Lektionen.")
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
        lines.append("Du erhältst eine Rechnung mit QR-Einzahlungsschein per E-Mail, zahlbar innert 7 Tagen. Die Rechnung findest du auch im Profil unter Rechnungen.")
        return lines.joined(separator: "\n")
    }

    /// Bestellung auf Rechnung (QR-Einzahlungsschein): Bestätigung → API-Call
    private func orderOnInvoice(_ pkg: CreditPackage) async {
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
                     ? "Aus \(packCount) \(packCount == 1 ? "Paket" : "Paketen") · Personal Training"
                     : "Wähle ein Paket für dein Personal Training")
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
        ("2", "Absagefrist", "Verhindert der Klient die Wahrnehmung eines Termins, ist Jean Paul Mvongo, Personal Training, spätestens 24 Stunden im Voraus zu informieren. Bei verspäteter Absage oder Nichterscheinen gilt die Leistung als erbracht und ist vollumfänglich geschuldet – auch bei unverschuldeter Verhinderung (ausgenommen ärztlich belegte Krankheit oder Unfall). Verspätungen führen nicht zu einer Verlängerung der Trainingszeit."),
        ("3", "Zahlungskonditionen", "Der Preis ist vor Leistungsbezug fällig. Abos sind innert 7 Tagen ab Unterzeichnung zahlbar. Jean Paul Mvongo, Personal Training, behält sich vor, Leistungen bei Zahlungsverzug auszusetzen."),
        ("4", "Gültigkeit", "Nicht genutzte Leistungen verfallen nach Ablauf der Abo-Gültigkeit ohne Anspruch auf Rückerstattung."),
        ("5", "Depot", "Für den Herzfrequenzsensor wird ein Depot von CHF 20.00 erhoben, welches bei unbeschädigter Rückgabe nach Vertragsende erstattet wird."),
        ("6", "Gesundheitszustand", "Der Klient bestätigt seine Sporttauglichkeit. Er verpflichtet sich, Jean Paul Mvongo, Personal Training, über körperliche Einschränkungen oder gesundheitliche Risiken proaktiv zu informieren. Das Training erfolgt auf eigenes Risiko."),
        ("7", "Versicherung & Haftung", "Versicherung ist Sache des Klienten. Soweit gesetzlich zulässig, wird jegliche Haftung von Jean Paul Mvongo, Personal Training, für Personen- oder Sachschäden ausgeschlossen."),
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
