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
            .filter { !$0.trainerId.isEmpty }   // ohne Trainer-ID nicht adressierbar
    }

    /// `GET /api/client/chat/{clientId}/messages/{trainerId}`
    func getMessages(clientId: String, trainerId: String) async throws -> [ChatMessage] {
        try await APIClient.shared
            .getJSONArray("/api/client/chat/\(clientId)/messages/\(trainerId)")
            .map { ChatMessage(json: $0) }
    }

    /// `POST /api/client/chat/{clientId}/messages/{trainerId}` — Body `{ text }`.
    @discardableResult
    func sendMessage(clientId: String, trainerId: String, text: String) async throws -> ChatMessage? {
        guard !trainerId.isEmpty else {
            throw APIError(statusCode: -1, message: "Nachricht konnte nicht gesendet werden")
        }
        guard let dict = try await APIClient.shared.postJSONObject(
            "/api/client/chat/\(clientId)/messages/\(trainerId)", body: ["text": text]) else { return nil }
        return ChatMessage(json: dict)
    }

    /// `POST /api/client/chat/{clientId}/messages/{trainerId}/read`
    func markAsRead(clientId: String, trainerId: String) async throws {
        guard !trainerId.isEmpty else { return }
        _ = try? await APIClient.shared.post(
            "/api/client/chat/\(clientId)/messages/\(trainerId)/read", body: [:])
    }

    /// `GET /api/client/reviews/{clientId}` — für ReviewDetailSheet
    func getReviews(clientId: String) async throws -> [[String: Any]] {
        try await APIClient.shared.getJSONArray("/api/client/reviews/\(clientId)")
    }

    /// `GET /api/client/tests/{clientId}` — liefert Sektionen
    /// (`[{section, data: [{key, unit, history: [{date, value}]}]}]`);
    /// hier pro Testdatum zu einzelnen Tests umgebaut (neuester zuerst).
    func getPerformanceTests(clientId: String) async throws -> [PerformanceTestEntry] {
        let sections = try await APIClient.shared.getJSONArray("/api/client/tests/\(clientId)")
        return PerformanceTestEntry.from(sections: sections)
    }
}

// MARK: - PerformanceTestEntry

/// Ein einzelner Leistungstest (alle Messwerte eines Datums).
struct PerformanceTestEntry: Identifiable {
    struct Value {
        let label: String   // z. B. "Liegestütze" (Label vom Backend)
        let value: String
        let unit:  String
    }

    let date:   String      // Rohdatum aus dem Backend
    let values: [Value]     // in Backend-Reihenfolge (Sektionen)

    var id: String { date }

    /// Messwert per Backend-Label (z. B. "Gesamtpunkte").
    func value(_ label: String) -> String? {
        values.first(where: { $0.label == label })?.value
    }

    /// Baut aus der Sektions-Antwort pro Datum einen Test.
    static func from(sections: [[String: Any]]) -> [PerformanceTestEntry] {
        var order: [String] = []
        var byDate: [String: [Value]] = [:]
        for section in sections {
            for metric in (section["data"] as? [[String: Any]]) ?? [] {
                let label = (metric["key"] as? String) ?? ""
                let unit  = (metric["unit"] as? String) ?? ""
                for point in (metric["history"] as? [[String: Any]]) ?? [] {
                    guard let date = point["date"] as? String, !date.isEmpty,
                          let raw = point["value"], !(raw is NSNull) else { continue }
                    if byDate[date] == nil { order.append(date); byDate[date] = [] }
                    byDate[date]?.append(Value(label: label, value: "\(raw)", unit: unit))
                }
            }
        }
        let entries = order.map { PerformanceTestEntry(date: $0, values: byDate[$0] ?? []) }
        // Neuester zuerst
        return entries.sorted {
            (ZurichTime.parseTimestamp($0.date) ?? .distantPast) > (ZurichTime.parseTimestamp($1.date) ?? .distantPast)
        }
    }
}
