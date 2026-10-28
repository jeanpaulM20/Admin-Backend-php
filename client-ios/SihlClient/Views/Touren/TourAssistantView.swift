import SwiftUI
import MapKit

// MARK: - TourAssistantView

/// Chat-Sheet des Touren-Assistenten: Wunsch beschreiben → berechnete
/// Route als Karte in der Antwort → TourDetail → „Tour starten".
struct TourAssistantView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    /// Empfohlene Route im Routenplaner öffnen (Start, Zwischenpunkte, Ziel
    /// anpassen). Ohne Callback wird der Knopf nicht gezeigt.
    var onPlan: ((RoutePlan) -> Void)? = nil

    @State private var messages: [AssistantMessage] = []
    @State private var input = ""
    @State private var isThinking = false
    @State private var detailRoute: TourDetail?
    @Environment(RecordingLauncher.self) private var launcher
    @FocusState private var inputFocused: Bool

    /// Einwilligung zur KI-Übermittlung (App-Store-Guideline 5.1.2(i))
    @AppStorage(TourAssistantConsent.storageKey) private var aiConsent = false

    private var isDemo: Bool { auth.clientId == "demo" }
    /// Ohne Einwilligung wird nichts ans Backend gesendet (Demo braucht keine)
    private var mayUseAI: Bool { isDemo || aiConsent }

    private static let examples = [
        "Panorama-Wanderung ab Zug, ca. 2 Stunden",
        "Gravel-Runde, 40 km, Start Adliswil",
        "Zum Rigi Kulm wandern, Start Vitznau, runter mit der Bahn",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                if mayUseAI {
                    VStack(spacing: 0) {
                        conversation
                        aiNotice
                        inputBar
                    }
                } else {
                    // Erstes Öffnen: Einwilligung statt Chat (als Inhalt dieses
                    // Sheets — ein zweites Sheet darüber käme beim Öffnen nicht
                    // zuverlässig an). „Nicht jetzt" schliesst den Assistenten.
                    TourAssistantConsentView(
                        onAccept: { aiConsent = true },
                        onDecline: { dismiss() })
                }
            }
            .navigationTitle("Touren-Assistent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.muted)
                }
            }
            .navigationDestination(item: $detailRoute) { detail in
                TourDetailView(detail: detail)
            }
            // „Tour starten" (hier oder im Tour-Detail darunter): Sheet schliessen,
            // die Aufzeichnung übernimmt im Start-Tab (Phase 5.1)
            .onChange(of: launcher.requestCount) { _, _ in dismiss() }
        }
    }

    /// Dauerhafter Hinweis über dem Eingabefeld
    private var aiNotice: some View {
        Text("KI-Antworten können Fehler enthalten – Wege und Verhältnisse selbst prüfen.")
            .font(.app(11))
            .foregroundStyle(AppColor.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, 6)
            .background(AppColor.background)
    }

    // MARK: Verlauf

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.stack) {
                    if messages.isEmpty { emptyState }
                    ForEach(messages) { message in
                        bubble(message)
                    }
                    if isThinking {
                        HStack(spacing: 8) {
                            ProgressView().tint(AppColor.primary)
                            Text("Ich rechne die Route — das kann eine halbe Minute dauern…")
                                .font(.caption)
                                .foregroundStyle(AppColor.muted)
                        }
                        .padding(AppSpacing.card)
                        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
                        .id("thinking")
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.vertical, AppSpacing.card)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: isThinking) { _, thinking in
                if thinking { withAnimation { proxy.scrollTo("thinking", anchor: .bottom) } }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.stack) {
            Text("Beschreib deine Wunschtour — ich finde und berechne die Route.")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
                .padding(.top, 8)
            ForEach(Self.examples, id: \.self) { example in
                Button {
                    input = example
                    submit()
                } label: {
                    Text(example)
                        .font(.footnote)
                        .foregroundStyle(AppColor.text)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                            .stroke(AppColor.border, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: AssistantMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            Text(Self.formatted(message))
                .font(.subheadline)
                .foregroundStyle(message.role == .user ? AppColor.white : AppColor.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == .user ? AppColor.primary : AppColor.surface,
                            in: RoundedRectangle(cornerRadius: AppRadius.card))
            if let route = message.route {
                routeCard(route, plan: message.plan)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .id(message.id)
    }

    /// Antworten des Assistenten enthalten Hervorhebungen (**fett**) —
    /// als Auszeichnung darstellen statt als Sternchen. Zeilenumbrüche
    /// bleiben erhalten; eigene Eingaben werden nie interpretiert.
    private static func formatted(_ message: AssistantMessage) -> AttributedString {
        guard message.role == .assistant,
              var rich = try? AttributedString(
                markdown: message.text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else {
            return AttributedString(message.text)
        }
        // Nur Hervorhebungen übernehmen: Links aus dem Modelltext werden
        // nicht antippbar (der Text kann Inhalte fremder Quellen wie
        // Ortsnamen aus der Geocodierung enthalten)
        for run in rich.runs where run.link != nil {
            rich[run.range].link = nil
        }
        return rich
    }

    /// Kompakte Routen-Karte: Tap → Detail; „Im Planer anpassen" übergibt
    /// die Punkte an den Routenplaner; „Tour starten" startet direkt.
    private func routeCard(_ route: TourDetail, plan: RoutePlan?) -> some View {
        VStack(spacing: 0) {
        Button {
            detailRoute = route
        } label: {
            HStack(spacing: AppSpacing.stack) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.control)
                        .fill(AppColor.primary.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: tourActivityIcon(route.activity))
                        .font(.app(18))
                        .foregroundStyle(AppColor.primary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(route.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 10) {
                        if let km = route.distanceKm {
                            Label(TourFormat.distance(km),
                                  systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        }
                        if let min = route.durationMin {
                            Label(TourFormat.duration(min), systemImage: "clock")
                        }
                        if let gain = route.elevationGain {
                            Label("\(gain) m", systemImage: "arrow.up.right")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }
            .padding(AppSpacing.card)
        }
        .buttonStyle(.plain)

        // Ruhige Zweitaktion — der eine CTA der Karte bleibt „Tour starten"
        if let plan, let onPlan {
            Divider().overlay(AppColor.border)
            Button {
                onPlan(plan)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "point.3.connected.trianglepath.dotted").font(.footnote)
                    Text("Im Planer anpassen").font(.footnote.weight(.medium))
                }
                .foregroundStyle(AppColor.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öffnet die Route im Routenplaner mit Start, Zwischenpunkten und Ziel")
        }

        Button {
            var started = route.asRoute
            started.waypoints = plan?.points ?? []
            launcher.start(started)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "record.circle").font(.callout)
                Text("Tour starten").font(.subheadline.bold())
            }
            .foregroundStyle(AppColor.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(AppColor.cta)
        }
        .buttonStyle(.plain)
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card)
            .stroke(AppColor.border, lineWidth: 1))
    }

    // MARK: Eingabe

    private var inputBar: some View {
        HStack(spacing: AppSpacing.stack) {
            TextField("Deine Wunschtour…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .font(.subheadline)
                .foregroundStyle(AppColor.text)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                    .stroke(AppColor.border, lineWidth: 1))

            Button {
                submit()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(AppColor.white)
                    .frame(width: 40, height: 40)
                    .background(canSend ? AppColor.cta : AppColor.surface2, in: Circle())
            }
            .accessibilityLabel("Frage senden")
            .disabled(!canSend)
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.vertical, AppSpacing.stack)
        .background(AppColor.background)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    private func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        guard mayUseAI else { return }   // ohne Einwilligung nichts senden
        input = ""
        inputFocused = false
        messages.append(AssistantMessage(role: .user, text: text))

        if isDemo {
            isThinking = true
            Task {
                try? await Task.sleep(for: .seconds(1))
                messages.append(TourAssistantService.demoReply(for: text))
                isThinking = false
            }
            return
        }
        guard let clientId = auth.clientId else { return }
        isThinking = true
        Task {
            do {
                let reply = try await TourAssistantService.send(clientId: clientId, history: messages)
                messages.append(reply)
            } catch {
                messages.append(AssistantMessage(
                    role: .assistant,
                    text: "Das hat gerade nicht geklappt — bitte versuch es nochmal.",
                    isLocalError: true))
            }
            isThinking = false
        }
    }
}

// MARK: - Einwilligung

/// Speicherort der Einwilligung zur KI-Übermittlung.
enum TourAssistantConsent {
    static let storageKey = "tourAssistant.aiConsent.v1"
    static let privacyURL = AppLinks.privacy
}

/// Hinweis und Einwilligung vor der ersten Nutzung des Assistenten.
struct TourAssistantConsentView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        // Scrollbar, damit grosse Schrift (Dynamic Type) nicht abschneidet
        ScrollView {
        VStack(alignment: .leading, spacing: AppSpacing.card) {
            HStack(spacing: AppSpacing.stack) {
                Image(systemName: "sparkles")
                    .font(.app(20, weight: .semibold))
                    .foregroundStyle(AppColor.primaryLight)
                Text("Touren-Assistent")
                    .font(.app(20, weight: .bold))
                    .foregroundStyle(AppColor.text)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Text("Der Touren-Assistent nutzt KI. Deine Nachrichten und der gewählte Startpunkt werden zur Beantwortung über unseren Server an Anthropic (USA) übermittelt und dort nicht zum Training verwendet. Gib keine Gesundheits- oder Personendaten ein.")
                .font(.app(15))
                .foregroundStyle(AppColor.text)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: TourAssistantConsent.privacyURL) {
                HStack(spacing: 4) {
                    Text("Datenschutz")
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.app(14, weight: .medium))
                .foregroundStyle(AppColor.primaryLight)
            }

            Button(action: onAccept) {
                Text("Zustimmen")
                    .font(.app(16, weight: .bold))
                    .foregroundStyle(AppColor.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColor.cta, in: RoundedRectangle(cornerRadius: AppRadius.control))
            }
            .buttonStyle(.plain)

            Button(action: onDecline) {
                Text("Nicht jetzt")
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(AppColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.hero)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
