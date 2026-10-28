import SwiftUI

/// Kommentar-Sheet pro Übung — Pendant zu `_CommentsSheet` in
/// `screens/training_plan_detail_screen.dart`.
struct CommentsSheet: View {
    let planId: Int
    let exerciseKey: String?
    let exerciseName: String?
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comments: [[String: Any]] = []
    @State private var isLoading = true
    @State private var isSending = false
    @State private var text = ""
    @State private var showDeleteAlert = false
    @State private var pendingDeleteId: Int?
    /// Laden fehlgeschlagen und noch nichts angezeigt → Fehlerzustand statt „Noch keine Kommentare“
    @State private var loadError: String?
    /// Senden/Löschen fehlgeschlagen — Banner über der Eingabe
    @State private var actionError: String?

    private let service = TrainingPlanService()

    var body: some View {
        VStack(spacing: 0) {
            // Drag-Indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColor.border)
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            // Titel
            Text(exerciseName.map { "Kommentare · \($0)" } ?? "Plan-Kommentare")
                .font(.app(15, weight: .bold))
                .foregroundStyle(AppColor.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12).padding(.bottom, 8)

            Divider().background(AppColor.border)

            // Liste
            if isLoading {
                Spacer()
                ProgressView().tint(AppColor.primary)
                Spacer()
            } else if comments.isEmpty, let err = loadError {
                ErrorStateView(message: err) { Task { await load() } }
            } else if comments.isEmpty {
                Spacer()
                EmptyStateView(icon: "bubble.left", message: "Noch keine Kommentare")
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(comments.enumerated()), id: \.offset) { _, c in
                                commentBubble(c).id(c["id"].map { "\($0)" } ?? UUID().uuidString)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                    .onChange(of: comments.count) {
                        if let last = comments.last, let id = last["id"] {
                            withAnimation { proxy.scrollTo("\(id)", anchor: .bottom) }
                        }
                    }
                }
            }

            // Eingabe
            Divider().background(AppColor.border)
            if let err = actionError {
                InlineErrorBanner(message: err)
                    .padding(.horizontal, 16).padding(.top, 10)
            }
            inputRow
        }
        .background(AppColor.surface.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .alert("Kommentar löschen?", isPresented: $showDeleteAlert, presenting: pendingDeleteId) { id in
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                Task { await delete(id) }
            }
        } message: { _ in Text("Dieser Kommentar wird unwiderruflich gelöscht.") }
        .task { await load() }
        .onDisappear { onClose() }
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Kommentar schreiben…", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .font(.app(14)).foregroundStyle(AppColor.text)
                .padding(.horizontal, AppSpacing.card).padding(.vertical, 8)
                .background(AppColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero))
                .disabled(isSending)

            Button {
                Task { await send() }
            } label: {
                ZStack {
                    Circle().fill(AppColor.primary).frame(width: 44, height: 44)
                    if isSending {
                        ProgressView().tint(AppColor.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.app(16)).foregroundStyle(AppColor.white)
                    }
                }
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .accessibilityLabel(isSending ? "Kommentar wird gesendet" : "Kommentar senden")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - Comment Bubble

    @ViewBuilder
    private func commentBubble(_ c: [String: Any]) -> some View {
        let author: String   = (c["authorName"] ?? c["author_name"]).map { "\($0)" } ?? "?"
        let txt: String      = (c["text"] as? String) ?? ""
        let id               = c["id"]
        let isClient: Bool   = (c["senderType"] as? String ?? c["sender_type"] as? String ?? "") == "client"
        let bubbleColor: Color = isClient ? AppColor.primary : AppColor.blue

        HStack(alignment: .top, spacing: 10) {
            // Avatar
            Circle()
                .fill(bubbleColor.opacity(0.18))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(author.prefix(1).uppercased())
                        .font(.app(13, weight: .bold)).foregroundStyle(bubbleColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                // Author row
                HStack(spacing: 6) {
                    Text(author)
                        .font(.app(12, weight: .bold)).foregroundStyle(AppColor.text)
                    if isClient {
                        Text("Du")
                            .font(.app(9, weight: .bold)).foregroundStyle(AppColor.primary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(AppColor.primary.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer()
                    if isClient, let idVal = id {
                        Button {
                            pendingDeleteId = (idVal as? Int) ?? Int("\(idVal)")
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "xmark").font(.app(11)).foregroundStyle(AppColor.muted)
                        }
                        .accessibilityLabel("Kommentar löschen")
                    }
                }

                // Bubble
                Text(txt)
                    .font(.app(13)).foregroundStyle(AppColor.text)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(AppColor.surface2)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0, bottomLeadingRadius: 12,
                            bottomTrailingRadius: 12, topTrailingRadius: 12
                        )
                    )
            }
        }
    }

    // MARK: - Load / Send

    /// Lädt die Kommentare. Bei Fehler bleiben bereits angezeigte erhalten.
    private func load() async {
        isLoading = comments.isEmpty
        do {
            comments  = try await service.getComments(planId: planId, exerciseKey: exerciseKey)
            loadError = nil
        } catch {
            if comments.isEmpty {
                loadError = "Kommentare konnten nicht geladen werden."
            } else {
                actionError = "Kommentare konnten nicht aktualisiert werden."
            }
        }
        isLoading = false
    }

    /// Text bleibt im Feld, bis der Server den Kommentar angenommen hat —
    /// offline geht nichts verloren.
    private func send() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        isSending   = true
        actionError = nil
        do {
            try await service.sendComment(planId: planId, text: trimmed, exerciseKey: exerciseKey)
            text = ""
            await load()
        } catch {
            actionError = "Kommentar konnte nicht gesendet werden. Bitte prüfe deine Verbindung und versuche es erneut."
        }
        isSending = false
    }

    private func delete(_ id: Int) async {
        actionError = nil
        do {
            try await service.deleteComment(commentId: id)
            await load()
        } catch {
            actionError = "Kommentar konnte nicht gelöscht werden. Bitte versuche es erneut."
        }
    }
}

// MARK: - CommentsSheetItem (für .sheet(item:))

struct CommentsSheetItem: Identifiable {
    let id = UUID()
    let planId: Int
    let exerciseKey: String
    let exerciseName: String
}
