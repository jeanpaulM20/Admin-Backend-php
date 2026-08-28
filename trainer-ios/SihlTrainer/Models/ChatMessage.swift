import Foundation

/// Eine Nachricht im Trainer-Kunden-Chat.
/// Pendant zu `_FeedbackMessage` aus `workout_feedback_screen.dart`.
struct ChatMessage: Identifiable, Equatable {
    let id: Int
    let text: String
    let author: String?
    let isTrainer: Bool
    let isCircle: Bool
    let readTrainer: Bool

    init(json: [String: Any]) {
        id = JSON.int(json, "id") ?? 0
        text = JSON.string(json, "text", "message", "comment") ?? ""
        author = JSON.string(json, "author")
        readTrainer = JSON.bool(json, "read_trainer")
        isCircle = JSON.bool(json, "is_circle")

        // `align` kommt nur aus dem Legacy-PHP. Fehlt es, leitet sich die Seite
        // aus den Lesemarken ab: vom Trainer gesendet heisst read_trainer=1
        // und read_client=0.
        if let align = JSON.string(json, "align") {
            isTrainer = align == "right"
        } else {
            isTrainer = JSON.bool(json, "read_trainer") && !JSON.bool(json, "read_client")
        }
    }
}

/// Ein Gesprächsfaden in der Übersicht — vom Backend aggregiert
/// (`GET feedback/conversations`).
struct Conversation: Identifiable, Equatable {
    let clientId: Int
    let clientName: String
    let lastMessage: String
    let unreadCount: Int

    var id: Int { clientId }

    init(json: [String: Any]) {
        clientId = JSON.int(json, "client_id", "clientId") ?? 0
        clientName = JSON.string(json, "client_name", "clientName") ?? "Unbekannt"
        lastMessage = JSON.string(json, "last_message", "lastMessage") ?? ""
        unreadCount = JSON.int(json, "unread_count", "unreadCount") ?? 0
    }
}
