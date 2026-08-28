import Foundation

/// Gesprächsübersicht. Pendant zum Zustand in `nachrichten_screen.dart`.
@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let service = ChatService()

    var unreadTotal: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    func load(trainerId: Int) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            conversations = try await service.conversations(trainerId: trainerId)
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Nachrichten konnten nicht geladen werden"
        }
    }

    #if DEBUG
    func loadPreviewData() {
        conversations = PreviewData.conversations
        error = nil
    }
    #endif
}

/// Ein einzelner Gesprächsfaden.
@MainActor
final class ChatThreadViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published var error: String?
    @Published var draft = ""

    private let service = ChatService()
    private let sse = SSEClient()
    private let clientId: Int
    private var trainerId: Int
    private var isPreview: Bool

    init(clientId: Int, trainerId: Int, isPreview: Bool = false) {
        self.clientId = clientId
        self.trainerId = trainerId
        self.isPreview = isPreview
    }

    /// Die View erzeugt das Modell, bevor sie die Sitzung sieht — Trainer-ID
    /// und Vorschaumodus werden darum beim Erscheinen nachgereicht.
    func adopt(trainerId: Int, isPreview: Bool) {
        self.trainerId = trainerId
        self.isPreview = isPreview
    }

    func load() async {
        #if DEBUG
        if isPreview {
            messages = PreviewData.messages
            return
        }
        #endif
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await service.messages(clientId: clientId)
            error = nil
            await markRead()
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Nachrichten konnten nicht geladen werden"
        }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        isSending = true
        defer { isSending = false }
        #if DEBUG
        if isPreview {
            draft = ""
            return
        }
        #endif
        do {
            try await service.send(clientId: clientId, trainerId: trainerId, text: text)
            draft = ""
            await load()
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Nachricht konnte nicht gesendet werden"
        }
    }

    /// Live-Aktualisierung über denselben SSE-Kanal wie die Flutter-App
    /// (`client_<id>`), damit eingehende Nachrichten ohne Nachladen erscheinen.
    func startLiveUpdates() {
        guard !isPreview, let token = KeychainStore.get(AuthService.tokenKey) else { return }
        Task {
            await sse.connect(channel: "client_\(clientId)", token: token) { [weak self] type in
                guard type == "chat" else { return }
                Task { @MainActor in await self?.load() }
            }
        }
    }

    func stopLiveUpdates() {
        Task { await sse.disconnect() }
    }

    private func markRead() async {
        guard messages.contains(where: { $0.id > 0 && !$0.readTrainer }) else { return }
        try? await service.markAllRead(clientId: clientId)
    }
}
