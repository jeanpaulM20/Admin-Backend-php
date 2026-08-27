import SwiftUI

// MARK: - ChatThreadView

/// Pendant zu `_ChatThread` in Flutter `chat_screen.dart`.
/// Zeigt Nachrichten mit Datum-Separatoren, Bubbles, Datenkarten und Kreis-Gruppen.
/// Realtime-Updates via SSE (`SSEClient`).
struct ChatThreadView: View {
    let trainerId:      String
    let trainerName:    String
    let trainerPicture: String?

    @Environment(AuthViewModel.self) private var auth
    @Environment(ChatViewModel.self) private var chat

    // Thread-lokaler State
    @State private var messages:     [ChatMessage] = []
    @State private var isLoading     = true
    @State private var messageText   = ""
    @State private var isSending     = false
    @State private var showAttach    = false
    @State private var dataDetail:   DataDetailItem? = nil
    @State private var toast:        AppToast? = nil
    @State private var sse           = SSEClient()

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView().tint(AppColor.primary)
                    Spacer()
                } else {
                    messageScrollView
                }
                inputBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Titel + Untertitel "N Nachrichten · M Workouts" (Flutter `_getStatusText`)
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(trainerName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                        .lineLimit(1)
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(AppColor.muted)
                }
            }
            // Refresh-Button (Flutter: Icons.refresh, Tooltip "Aktualisieren")
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.callout)
                        .foregroundStyle(AppColor.muted)
                }
                .accessibilityLabel("Aktualisieren")
            }
        }
        .appToast($toast, bottomPadding: 72)
        .sheet(item: $dataDetail) { item in
            DataDetailRouterView(item: item)
        }
        .sheet(isPresented: $showAttach) {
            AttachMenuSheet(clientId: auth.clientId ?? "") { text in
                // Wie Flutter: Auswahl landet im Eingabefeld (editierbar), wird NICHT sofort gesendet
                messageText = text
                showAttach  = false
            }
        }
        .task {
            await loadAndSubscribe()
        }
        .onDisappear {
            Task { await sse.disconnect() }
        }
    }

    /// Pendant zu Flutter `_getStatusText`: "N Nachrichten · M Workouts".
    private var statusText: String {
        var msgCount = 0, circleCount = 0
        for m in messages { if m.isCircle { circleCount += 1 } else { msgCount += 1 } }
        var parts: [String] = []
        if msgCount    > 0 { parts.append("\(msgCount) Nachrichten") }
        if circleCount > 0 { parts.append("\(circleCount) Workouts") }
        return parts.isEmpty ? "Chat" : parts.joined(separator: " · ")
    }

    // MARK: - Message scroll

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(groupedItems, id: \.id) { item in
                        switch item.content {
                        case .dateSeparator(let label):
                            DateSeparatorView(label: label)
                        case .message(let msg):
                            BubbleView(
                                message:     msg,
                                trainerName: trainerName,
                                onDataTap: { dataDetail = DataDetailItem(message: msg, clientId: auth.clientId ?? "") }
                            )
                        case .circleGroup(let msgs):
                            CircleGroupView(messages: msgs)
                        }
                    }
                }
                .padding(.vertical, 12)
                .id("bottom-anchor")
            }
            .onChange(of: messages.count) {
                withAnimation { proxy.scrollTo("bottom-anchor", anchor: .bottom) }
            }
            .onAppear {
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button { showAttach = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppColor.primary)
            }
            .accessibilityLabel("Datei anhängen")
            TextField("Nachricht ...", text: $messageText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.hero))
                .foregroundStyle(AppColor.text)
            Button {
                Task { await sendMessage() }
            } label: {
                if isSending {
                    ProgressView().tint(AppColor.primary)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? AppColor.muted : AppColor.primary)
                }
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.vertical, 10)
        .background(AppColor.surface.opacity(0.95))
    }

    // MARK: - Load + SSE

    private func loadAndSubscribe() async {
        isLoading = true
        do {
            messages  = try await ChatService.shared.getMessages(clientId: auth.clientId ?? "", trainerId: trainerId)
        } catch {}
        isLoading = false

        // Als gelesen markieren
        await chat.markRead(clientId: auth.clientId ?? "", trainerId: trainerId)

        // SSE abonnieren (Kanal: client_{clientId}) — nur mit gültiger Session,
        // sonst würde der Reconnect-Loop endlos einen leeren Kanal abonnieren.
        guard let clientId = auth.clientId, !clientId.isEmpty,
              let token = auth.token, !token.isEmpty else { return }
        await sse.connect(channel: "client_\(clientId)", token: token) {
            [self] eventType in
            guard eventType == "chat" else { return }
            Task { @MainActor in
                // Wie Flutter `_refresh`: neu laden UND als gelesen markieren,
                // sonst bleibt die Nachricht serverseitig ungelesen.
                if let fresh = try? await ChatService.shared.getMessages(
                    clientId: clientId, trainerId: self.trainerId) {
                    self.messages = fresh
                }
                await self.chat.markRead(clientId: clientId, trainerId: self.trainerId)
            }
        }
    }

    /// Pendant zu Flutter `_refresh`: Nachrichten neu laden + als gelesen markieren.
    private func refresh() async {
        if let fresh = try? await ChatService.shared.getMessages(
            clientId: auth.clientId ?? "", trainerId: trainerId) {
            messages = fresh
        }
        await chat.markRead(clientId: auth.clientId ?? "", trainerId: trainerId)
    }

    // MARK: - Send

    /// Pendant zu Flutter `_send`: bei Fehlschlag Text zurücklegen + Fehlermeldung.
    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        isSending = true
        let savedText = messageText
        messageText = ""
        do {
            if let msg = try await ChatService.shared.sendMessage(
                clientId: auth.clientId ?? "", trainerId: trainerId, text: text) {
                messages.append(msg)
            }
        } catch {
            // Text wiederherstellen, damit erneut gesendet werden kann
            messageText = savedText
            withAnimation { toast = AppToast(message: "Nachricht konnte nicht gesendet werden", style: .error) }
        }
        isSending = false
    }

    // MARK: - Grouped items (Datum-Separatoren + Kreis-Gruppen)

    private var groupedItems: [GroupedItem] {
        var result: [GroupedItem] = []
        var i = 0
        var lastDate: String? = nil
        let cal = Calendar.current

        while i < messages.count {
            let msg = messages[i]

            // Datum-Separator
            if let date = msg.createdAt {
                let label = dateLabel(date, cal: cal)
                if label != lastDate {
                    result.append(GroupedItem(content: .dateSeparator(label)))
                    lastDate = label
                }
            }

            // Kreis-Gruppe: ALLE aufeinanderfolgenden isCircle-Nachrichten gruppieren
            // (wie Flutter `_buildGroupedWidgets`, ohne Sender-Einschränkung)
            if msg.isCircle {
                var group: [ChatMessage] = [msg]
                i += 1
                while i < messages.count && messages[i].isCircle {
                    group.append(messages[i])
                    i += 1
                }
                result.append(GroupedItem(content: .circleGroup(group)))
                continue
            }

            result.append(GroupedItem(content: .message(msg)))
            i += 1
        }
        return result
    }

    private func dateLabel(_ date: Date, cal: Calendar) -> String {
        if cal.isDateInToday(date)     { return "Heute" }
        if cal.isDateInYesterday(date) { return "Gestern" }
        return DateFormatter.chatDDMMYYYY.string(from: date)
    }
}
