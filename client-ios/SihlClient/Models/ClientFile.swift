import Foundation

/// Pendant zu `models/client_file.dart`.
struct ClientFile: Identifiable {
    let id: String
    let name: String
    let url: String?
    let date: Date?

    var hasUrl: Bool { !(url?.isEmpty ?? true) }

    init(json: [String: Any]) {
        self.id   = "\(json["id"] ?? UUID().uuidString)"
        self.name = (json["filename"] as? String) ?? (json["name"] as? String) ?? ""
        self.url  = (json["url"] as? String)
                 ?? (json["file"] as? String)
                 ?? (json["path"] as? String)

        let raw = json["created_at"] ?? json["createdAt"] ?? json["date"]
        self.date = Self.parseDate(raw)
    }

    private static func parseDate(_ val: Any?) -> Date? {
        guard let s = val.map({ "\($0)" }), !s.isEmpty, s != "null" else { return nil }
        return ISO8601DateFormatter().date(from: s)
            ?? DateFormatter.yyyyMMdd.date(from: String(s.prefix(10)))
    }
}

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}
