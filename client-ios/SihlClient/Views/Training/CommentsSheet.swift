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
                .font(.system(size: 15, weight: .bold))
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
            } else if comments.isEmpty {
                Spacer()
                Text("Noch keine Kommentare")
                    .font(.system(size: 14)).foregroundStyle(AppColor.muted)
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
            inputRow
        }
        .background(AppColor.surface.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .alert("Kommentar löschen?", isPresented: $showDeleteAlert, presenting: pendingDeleteId) { id in
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                Task { try? await service.deleteComment(commentId: id); await load() }
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
                .font(.system(size: 14)).foregroundStyle(AppColor.text)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(AppColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 22))

            Button {
                Task { await send() }
            } label: {
                ZStack {
                    Circle().fill(AppColor.primary).frame(width: 44, height: 44)
                    if isSending {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16)).foregroundStyle(.white)
                    }
                }
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
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
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(bubbleColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                // Author row
                HStack(spacing: 6) {
                    Text(author)
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(AppColor.text)
                    if isClient {
                        Text("Du")
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(AppColor.primary)
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
                            Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(AppColor.muted)
                        }
                    }
                }

                // Bubble
                Text(txt)
                    .font(.system(size: 13)).foregroundStyle(AppColor.text)
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

    private func load() async {
        isLoading = true
        comments = (try? await service.getComments(planId: planId, exerciseKey: exerciseKey)) ?? []
        isLoading = false
    }

    private func send() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        isSending = true
        text = ""
        try? await service.sendComment(planId: planId, text: trimmed, exerciseKey: exerciseKey)
        await load()
        isSending = false
    }
}

// MARK: - CommentsSheetItem (für .sheet(item:))

struct CommentsSheetItem: Identifiable {
    let id = UUID()
    let planId: Int
    let exerciseKey: String
    let exerciseName: String
}
