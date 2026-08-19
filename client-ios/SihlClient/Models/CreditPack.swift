import Foundation

/// Pendant zu `models/credit_pack.dart`.
struct CreditPack: Identifiable {
    let id: UUID               // synthetisch — kein Server-ID im Payload
    let title: String
    let prepaidCredits: Int
    let spentCredits: Int
    let expiryDate: Date?

    var remainingCredits: Int { max(0, prepaidCredits - spentCredits) }
    var isExpired: Bool {
        guard let exp = expiryDate else { return false }
        return exp < Date()
    }
    /// Fortschritts-Fraktion für die Progress-Bar (0…1).
    var fraction: Double {
        guard prepaidCredits > 0 else { return 0 }
        return Double(remainingCredits.clamped(to: 0...prepaidCredits)) / Double(prepaidCredits)
    }

    init(json: [String: Any]) {
        self.id             = UUID()
        self.title          = "\(json["title"] ?? "")"
        self.prepaidCredits = Int("\(json["prepaidCredits"] ?? 0)") ?? 0
        self.spentCredits   = Int("\(json["spentCredits"]   ?? 0)") ?? 0
        self.expiryDate     = Self.parseDate(json["expiryDate"])
    }

    private static func parseDate(_ val: Any?) -> Date? {
        guard let s = val.map({ "\($0)" }), !s.isEmpty, s != "null" else { return nil }
        return ISO8601DateFormatter().date(from: s)
            ?? DateFormatter.yyyyMMdd.date(from: s)
    }
}

// MARK: - Comparable

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}
