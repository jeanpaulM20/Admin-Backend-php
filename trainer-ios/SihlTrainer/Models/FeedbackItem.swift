import Foundation

/// Bewertung eines Kunden. Pendant zu `FeedbackItem` aus
/// `screens/feedback_screen.dart`.
struct FeedbackItem: Identifiable, Equatable {
    let id: Int
    let clientName: String
    let date: String?
    let rating: Int
    let comment: String
    var isRead: Bool

    init(json: [String: Any]) {
        id = JSON.int(json, "id", "feedback_id") ?? 0
        if let name = JSON.string(json, "client_name") {
            clientName = name
        } else if let client = json["client"] as? [String: Any] {
            let first = JSON.string(client, "firstname", "name") ?? ""
            let last = JSON.string(client, "lastname", "surname") ?? ""
            let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
            clientName = full.isEmpty ? "Unbekannt" : full
        } else {
            clientName = "Unbekannt"
        }
        date = JSON.string(json, "date", "created_at", "feedback_date")
        rating = JSON.int(json, "rating", "stars") ?? 0
        comment = JSON.string(json, "message", "comment", "text") ?? ""
        isRead = JSON.bool(json, "read", "read_trainer")
    }
}
