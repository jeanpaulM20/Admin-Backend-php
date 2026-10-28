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
    /// Paket-Art laut Backend ('credits' | 'coaching') — nur falls geliefert
    let kind: String?

    var isPaid: Bool { status.lowercased() == "paid" }

    /// Rechnung für ein Online-Coaching-Abo: in der App nur als Beleg,
    /// ohne Zahlungsweg (App-Store 3.1.1/3.1.3(b)). Das Backend kennzeichnet
    /// verknüpfte Abos (kind); ältere Coaching-Rechnungen ohne Verknüpfung
    /// erkennt zusätzlich der Paketname — im Zweifel lieber nur Beleg.
    var isCoaching: Bool {
        kind?.lowercased() == "coaching"
            || (packageName?.localizedCaseInsensitiveContains("coaching") ?? false)
    }

    /// Betrag mit Rappen, de_CH (z.B. "CHF 1’680.00")
    var amountFormatted: String {
        currency.uppercased() == "CHF"
            ? CreditPackage.chf(amount, minFraction: 2)
            : "\(currency) \(String(format: "%.2f", amount))"
    }

    init(json: [String: Any]) {
        self.id            = UUID()
        self.invoiceNumber = (json["invoiceNumber"] as? String)
                          ?? (json["invoice_number"] as? String)
                          ?? (json["number"] as? String) ?? ""
        self.status        = (json["status"] as? String) ?? ""
        self.currency      = (json["currency"] as? String) ?? "CHF"
        self.amount        = Double("\(json["amount"] ?? 0)") ?? 0

        let rawDate = json["transactionDate"] ?? json["transaction_date"] ?? json["date"]
        self.transactionDate = SwissDay.parse(rawDate)
        self.dueDate         = SwissDay.parse(json["dueDate"] ?? json["due_date"])

        self.packageName    = (json["packageName"] as? String) ?? (json["package_name"] as? String)
        self.credits        = Int("\(json["credits"] ?? "")")
        self.durationMonths = Int("\(json["durationMonths"] ?? json["duration_months"] ?? "")")
        self.kind           = (json["kind"] as? String)
                           ?? (json["packageKind"] as? String)
                           ?? (json["package_kind"] as? String)
    }
}
