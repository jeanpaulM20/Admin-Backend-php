import Foundation

/// Pendant zu `services/chat_service.dart`.
/// Alle API-Calls laufen über `APIClient.shared` (actor, async/await).
struct ChatService {
    static let shared = ChatService()
    private init() {}

    /// `GET /api/client/chat/{clientId}/conversations`
    func getConversations(clientId: String) async throws -> [ChatConversation] {
        let data = try await APIClient.shared.get("/api/client/chat/\(clientId)/conversations")
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map { ChatConversation(json: $0) }
    }

    /// `GET /api/client/chat/{clientId}/messages/{trainerId}`
    func getMessages(clientId: String, trainerId: String) async throws -> [ChatMessage] {
        let data = try await APIClient.shared.get(
            "/api/client/chat/\(clientId)/messages/\(trainerId)")
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map { ChatMessage(json: $0) }
    }

    /// `POST /api/client/chat/{clientId}/messages`
    @discardableResult
    func sendMessage(clientId: String, trainerId: String, text: String) async throws -> ChatMessage? {
        let body: [String: Any] = ["text": text, "trainer_id": trainerId]
        let data = try await APIClient.shared.post(
            "/api/client/chat/\(clientId)/messages", body: body)
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return ChatMessage(json: dict)
    }

    /// `POST /api/client/chat/{clientId}/messages/{trainerId}/read`
    func markAsRead(clientId: String, trainerId: String) async throws {
        _ = try? await APIClient.shared.post(
            "/api/client/chat/\(clientId)/messages/\(trainerId)/read", body: [:])
    }

    /// `GET /api/client/reviews/{clientId}` — für ReviewDetailSheet
    func getReviews(clientId: String) async throws -> [[String: Any]] {
        let data = try await APIClient.shared.get("/api/client/reviews/\(clientId)")
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    /// `GET /api/client/tests/{clientId}` — für PerformanceDetailSheet
    func getPerformanceTests(clientId: String) async throws -> [[String: Any]] {
        let data = try await APIClient.shared.get("/api/client/tests/\(clientId)")
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }
}
