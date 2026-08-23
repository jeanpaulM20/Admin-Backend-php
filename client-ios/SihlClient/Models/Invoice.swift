import Foundation

/// Pendant zu `models/invoice.dart`.
struct Invoice: Identifiable {
    let id: UUID               // synthetisch
    let invoiceNumber: String
    let status: String
    let transactionDate: Date?
    let dueDate: Date?
    let currency: String
    let amount: Double
    let packageName: String?
    let credits: Int?
    let durationMonths: Int?

    var isPaid: Bool { status.lowercased() == "paid" }

    init(json: [String: Any]) {
        self.id            = UUID()
        self.invoiceNumber = (json["invoiceNumber"] as? String)
                          ?? (json["invoice_number"] as? String)
                          ?? (json["number"] as? String) ?? ""
        self.status        = (json["status"] as? String) ?? ""
        self.currency      = (json["currency"] as? String) ?? "CHF"
        self.amount        = Double("\(json["amount"] ?? 0)") ?? 0

        let rawDate = json["transactionDate"] ?? json["transaction_date"] ?? json["date"]
        self.transactionDate = Self.parseDate(rawDate)
        self.dueDate         = Self.parseDate(json["dueDate"] ?? json["due_date"])

        self.packageName    = (json["packageName"] as? String) ?? (json["package_name"] as? String)
        self.credits        = Int("\(json["credits"] ?? "")")
        self.durationMonths = Int("\(json["durationMonths"] ?? json["duration_months"] ?? "")")
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
