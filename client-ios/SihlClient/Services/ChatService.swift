import Foundation

/// Pendant zu `services/chat_service.dart`.
/// Alle API-Calls laufen über `APIClient.shared` (actor, async/await).
struct ChatService {
    static let shared = ChatService()
    private init() {}

    /// `GET /api/client/chat/{clientId}/conversations`
    func getConversations(clientId: String) async throws -> [ChatConversation] {
        try await APIClient.shared
            .getJSONArray("/api/client/chat/\(clientId)/conversations")
            .map { ChatConversation(json: $0) }
    }

    /// `GET /api/client/chat/{clientId}/messages/{trainerId}`
    func getMessages(clientId: String, trainerId: String) async throws -> [ChatMessage] {
        try await APIClient.shared
            .getJSONArray("/api/client/chat/\(clientId)/messages/\(trainerId)")
            .map { ChatMessage(json: $0) }
    }

    /// `POST /api/client/chat/{clientId}/messages`
    @discardableResult
    func sendMessage(clientId: String, trainerId: String, text: String) async throws -> ChatMessage? {
        let body: [String: Any] = ["text": text, "trainer_id": trainerId]
        guard let dict = try await APIClient.shared.postJSONObject(
            "/api/client/chat/\(clientId)/messages", body: body) else { return nil }
        return ChatMessage(json: dict)
    }

    /// `POST /api/client/chat/{clientId}/messages/{trainerId}/read`
    func markAsRead(clientId: String, trainerId: String) async throws {
        _ = try? await APIClient.shared.post(
            "/api/client/chat/\(clientId)/messages/\(trainerId)/read", body: [:])
    }

    /// `GET /api/client/reviews/{clientId}` — für ReviewDetailSheet
    func getReviews(clientId: String) async throws -> [[String: Any]] {
        try await APIClient.shared.getJSONArray("/api/client/reviews/\(clientId)")
    }

    /// `GET /api/client/tests/{clientId}` — für PerformanceDetailSheet
    func getPerformanceTests(clientId: String) async throws -> [[String: Any]] {
        try await APIClient.shared.getJSONArray("/api/client/tests/\(clientId)")
    }
}
