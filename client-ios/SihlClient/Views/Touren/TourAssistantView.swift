import SwiftUI
import MapKit

// MARK: - TourAssistantView

/// Chat-Sheet des Touren-Assistenten: Wunsch beschreiben → berechnete
/// Route als Karte in der Antwort → TourDetail → „Tour starten".
struct TourAssistantView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [AssistantMessage] = []
    @State private var input = ""
    @State private var isThinking = false
    @State private var detailRoute: TourDetail?
    @State private var startTour: TourRoute?
    @State private var showRecord = false
    @FocusState private var inputFocused: Bool

    private var isDemo: Bool { auth.clientId == "demo" }

    private static let examples = [
        "Panorama-Wanderung ab Zug, ca. 2 Stunden",
        "Gravel-Runde, 40 km, Start Adliswil",
        "Zum Rigi Kulm wandern, Start Vitznau, runter mit der Bahn",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    conversation
                    inputBar
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
            // Direktstart aus dem Chat: Route in den Recorder übergeben (T3)
            .navigationDestination(isPresented: $showRecord) {
                RecordWorkoutView(tour: startTour)
            }
        }
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
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(message.role == .user ? AppColor.white : AppColor.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == .user ? AppColor.primary : AppColor.surface,
                            in: RoundedRectangle(cornerRadius: AppRadius.card))
            if let route = message.route {
                routeCard(route)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .id(message.id)
    }

    /// Kompakte Routen-Karte: Tap → Detail; „Tour starten" startet direkt.
    private func routeCard(_ route: TourDetail) -> some View {
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

        Button {
            startTour = route.asRoute
            showRecord = true
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
                    text: "Das hat gerade nicht geklappt — bitte versuch es nochmal."))
            }
            isThinking = false
        }
    }
}
