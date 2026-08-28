import Foundation

/// Chat zwischen Trainer und Kunde.
/// Pendant zu den Feedback-Calls aus `nachrichten_screen.dart` und
/// `workout_feedback_screen.dart`.
struct ChatService {

    /// Vom Backend aggregierte Gesprächsliste (eine SQL-Abfrage statt N+1).
    func conversations(trainerId: Int) async throws -> [Conversation] {
        let data = try await APIClient.shared.get("\(APIConfig.feedback)/conversations?trainer_id=\(trainerId)")
        return Self.list(from: data).map(Conversation.init(json:))
    }

    func messages(clientId: Int) async throws -> [ChatMessage] {
        let data = try await APIClient.shared.get("\(APIConfig.feedback)?client_id=\(clientId)")
        return Self.list(from: data).map(ChatMessage.init(json:))
    }

    /// Trainer → Kunde. `readTrainer: 1` + `readClient: 0` markiert den Absender.
    func send(clientId: Int, trainerId: Int, text: String) async throws {
        _ = try await APIClient.shared.post(APIConfig.feedback, body: [
            "clientId": clientId,
            "trainerId": trainerId,
            "message": text,
            "readTrainer": 1,
            "readClient": 0,
        ])
    }

    /// Alle Nachrichten eines Kunden als gelesen markieren — ein Request
    /// statt einer pro Nachricht.
    func markAllRead(clientId: Int) async throws {
        _ = try await APIClient.shared.post("\(APIConfig.feedback)/read-all?client_id=\(clientId)")
    }

    private static func list(from data: Data) -> [[String: Any]] {
        let json = try? JSONSerialization.jsonObject(with: data)
        if let array = json as? [[String: Any]] { return array }
        if let object = json as? [String: Any], let array = object["data"] as? [[String: Any]] {
            return array
        }
        return []
    }
}

/// Sternebewertungen liegen auf derselben feedback-Ressource wie der Chat,
/// tragen aber ein rating — darum ein eigener kleiner Service.
struct FeedbackRatingService {

    func ratings() async throws -> [FeedbackItem] {
        let data = try await APIClient.shared.get(APIConfig.feedback)
        let json = try? JSONSerialization.jsonObject(with: data)
        var list: [[String: Any]] = []
        if let array = json as? [[String: Any]] {
            list = array
        } else if let object = json as? [String: Any], let array = object["data"] as? [[String: Any]] {
            list = array
        }
        // Nur Einträge mit Sternen — der Rest sind Chatnachrichten.
        return list.map(FeedbackItem.init(json:)).filter { $0.rating > 0 }
    }

    func markRead(id: Int) async throws {
        _ = try await APIClient.shared.post("\(APIConfig.feedback)/\(id)/read")
    }
}
