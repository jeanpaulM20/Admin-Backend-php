import Foundation

// MARK: - ChatMessage

/// Pendant zu `ChatMessage` in `models/chat_message.dart`.
struct ChatMessage: Identifiable {
    let id:         String
    let text:       String
    let senderType: String   // 'client' | 'trainer'
    let author:     String?
    let isCircle:   Bool     // Trainingsintensitäts-Eintrag
    let createdAt:  Date?

    var isFromClient:  Bool { senderType == "client"  }
    var isFromTrainer: Bool { senderType == "trainer" }

    init(json: [String: Any]) {
        self.id         = "\(json["id"] ?? "")"
        self.text       = (json["text"] ?? json["message"] ?? json["comment"])
                            .map { "\($0)" } ?? ""
        self.senderType = json["sender_type"] as? String ?? "client"
        self.author     = json["author"] as? String
        self.isCircle   = Self.parseBool(json["is_circle"])
        if let raw = json["created_at"] as? String {
            self.createdAt = ISO8601DateFormatter().date(from: raw)
                ?? DateFormatter.yyyyMMddHHmm.date(from: raw)
        } else {
            self.createdAt = nil
        }
    }

    private static func parseBool(_ v: Any?) -> Bool {
        if let b = v as? Bool { return b }
        if let i = v as? Int  { return i == 1 }
        if let s = v as? String { return s == "1" || s == "true" }
        return false
    }
}

// MARK: - ChatConversation

/// Pendant zu `ChatConversation` in `models/chat_message.dart`.
struct ChatConversation: Identifiable, Hashable {
    let id:            String  // = trainerId (für Identifiable)
    let trainerId:     String
    let trainerName:   String
    let trainerPicture: String?
    let lastMessage:   String?
    let lastMessageAt: Date?
    var unreadCount:   Int

    init(json: [String: Any]) {
        self.trainerId     = json["trainer_id"]   as? String ?? ""
        self.trainerName   = json["trainer_name"] as? String ?? "Trainer"
        self.trainerPicture = json["trainer_picture"] as? String
        self.lastMessage   = json["last_message"] as? String
        self.unreadCount   = Int("\(json["unread_count"] ?? 0)") ?? 0
        self.id            = self.trainerId
        if let raw = json["last_message_at"] as? String {
            self.lastMessageAt = ISO8601DateFormatter().date(from: raw)
                ?? DateFormatter.yyyyMMddHHmm.date(from: raw)
        } else {
            self.lastMessageAt = nil
        }
    }

    var initials: String {
        let parts = trainerName.trimmingCharacters(in: .whitespaces).split(separator: " ")
        guard !parts.isEmpty else { return "?" }
        if parts.count == 1 { return String(parts[0].prefix(1)).uppercased() }
        return (String(parts.first!.prefix(1)) + String(parts.last!.prefix(1))).uppercased()
    }
}

// MARK: - DateFormatter helper

private extension DateFormatter {
    static let yyyyMMddHHmm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}
