import Foundation

/// Pendant zu `models/credit_pack.dart`.
struct CreditPack: Identifiable {
    let id: UUID               // synthetisch — kein Server-ID im Payload
    let title: String
    let prepaidCredits: Int
    let spentCredits: Int
    let expiryDate: Date?

    var remainingCredits: Int { max(0, prepaidCredits - spentCredits) }
    /// Abgelaufen erst nach dem letzten gültigen Tag (bis 24:00 Zürcher Zeit).
    var isExpired: Bool {
        guard let exp = expiryDate else { return false }
        return Date() >= SwissDay.endOfDay(exp)
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
        self.expiryDate     = SwissDay.parse(json["expiryDate"])
    }
}

// MARK: - SwissDay

/// Kalendertage in Zürcher Zeit — Gültigkeitsdaten („yyyy-MM-dd“) gelten
/// den ganzen Tag, nicht nur bis 00:00.
enum SwissDay {
    static let timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current

    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar   = calendar
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.timeZone   = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "de_CH")
        f.timeZone   = timeZone
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso = ISO8601DateFormatter()

    /// ISO-Zeitstempel (mit/ohne Millisekunden) oder reines Datum (00:00 Zürich).
    static func parse(_ val: Any?) -> Date? {
        guard let s = val.map({ "\($0)" }), !s.isEmpty, s != "null", s != "<null>" else { return nil }
        return isoFractional.date(from: s)
            ?? iso.date(from: s)
            ?? dayFormatter.date(from: String(s.prefix(10)))
    }

    /// Beginn des Zürcher Kalendertags von `date`.
    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Ende des Zürcher Kalendertags (= Beginn des Folgetags).
    static func endOfDay(_ date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }

    /// „dd.MM.yyyy“ in Zürcher Zeit.
    static func display(_ date: Date) -> String {
        displayFormatter.string(from: date)
    }
}

// MARK: - Comparable

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
