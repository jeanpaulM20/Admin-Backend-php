import Foundation

/// Pendant zu Flutter's `ChatProvider` — hält die Konversationsliste und
/// das ungelesene Badge für den Chat-Tab.
/// Nachrichten eines einzelnen Threads werden direkt im `ChatThreadView` geladen.
@MainActor @Observable final class ChatViewModel {
    var conversations: [ChatConversation] = []
    var isLoading    = false
    var error: String?

    /// Summe aller ungelesenen Nachrichten (für Tab-Badge).
    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    // MARK: - Fetch

    func fetchConversations(clientId: String) async {
        isLoading = true
        error     = nil
        do {
            conversations = try await ChatService.shared.getConversations(clientId: clientId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Mark read (optimistisch lokal, dann API)

    func markRead(clientId: String, trainerId: String) async {
        if let i = conversations.firstIndex(where: { $0.trainerId == trainerId }) {
            conversations[i].unreadCount = 0
        }
        try? await ChatService.shared.markAsRead(clientId: clientId, trainerId: trainerId)
    }
}
