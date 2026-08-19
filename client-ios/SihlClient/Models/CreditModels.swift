import Foundation

// MARK: - CreditPackage

/// Pendant zu `CreditPackage` in `models/buyable_credit.dart`.
struct CreditPackage: Identifiable {
    let id:              String
    let name:            String
    let credits:         Int
    let price:           Double
    let pricePerSession: Double?
    let durationMonths:  Int?
    let description:     String?
    let includes:        String?
    let kind:            String   // 'credits' | 'coaching'

    var isCoaching: Bool { kind == "coaching" }

    /// Preis formatiert in CHF (z.B. "CHF 250")
    var priceFormatted: String {
        let f = NumberFormatter()
        f.numberStyle        = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "de_CH")
        return "CHF \(f.string(from: NSNumber(value: price)) ?? "\(Int(price))")"
    }

    var perSessionFormatted: String? {
        guard let pps = pricePerSession else { return nil }
        return "CHF \(Int(pps)) / Lektion"
    }

    init(json: [String: Any]) {
        self.id             = "\(json["id"]   ?? "")"
        self.name           = "\(json["name"] ?? "")"
        self.credits        = Int("\(json["credits"] ?? 0)") ?? 0
        self.price          = Double("\(json["price"] ?? 0)") ?? 0
        self.pricePerSession = json["pricePerSession"].flatMap { Double("\($0)") }
        self.durationMonths  = json["durationMonths"].flatMap { Int("\($0)") }
        self.description    = json["description"] as? String
        self.includes       = json["includes"] as? String
        self.kind           = json["kind"] as? String ?? "credits"
    }
}

// MARK: - ClientCredit

/// Pendant zu `ClientCredit` in `models/buyable_credit.dart` — ein gebuchtes Abo.
struct ClientCredit: Identifiable {
    let id:        String
    let title:     String
    let paid:      Int
    let attended:  Int
    let remaining: Int
    let startdate: String?
    let expires:   String?

    init(json: [String: Any]) {
        let paid     = Int("\(json["paid"]     ?? 0)") ?? 0
        let attended = Int("\(json["attended"] ?? 0)") ?? 0
        self.id        = "\(json["id"] ?? UUID().uuidString)"
        self.title     = json["title"] as? String ?? "Credit-Paket"
        self.paid      = paid
        self.attended  = attended
        self.remaining = Int("\(json["remaining"] ?? 0)") ?? (paid - attended)
        self.startdate = json["startdate"] as? String
        self.expires   = json["expires"]   as? String
    }

    /// Ist dieses Abo zum aktuellen Zeitpunkt aktiv?
    var isActive: Bool {
        let now = Date()
        if let exp = expires, let d = Self.parseDate(exp), d < now { return false }
        if let start = startdate, let d = Self.parseDate(start), d > now { return false }
        return true
    }

    private static func parseDate(_ s: String) -> Date? {
        ISO8601DateFormatter().date(from: s)
        ?? DateFormatter.yyyyMMdd.date(from: s)
    }
}

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}

// MARK: - PaymentInitResult

struct PaymentInitResult {
    let redirectUrl:   String
    let invoiceNumber: String
}
