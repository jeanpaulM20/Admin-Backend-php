import Foundation

// MARK: - CreditPackage

/// Lektionen-Paket für Personal Training vor Ort.
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

    /// Online-Coaching-Abo — wird in der App nicht angeboten (App-Store 3.1.1).
    var isCoaching: Bool { kind == "coaching" }

    /// Preis in CHF, ganze Franken ohne Rappen (z.B. "CHF 250", "CHF 32.50")
    var priceFormatted: String { Self.chf(price, minFraction: 0) }

    /// Preis immer mit Rappen (z.B. "CHF 250.00") — z.B. im Bestätigungsdialog
    var priceFormattedExact: String { Self.chf(price, minFraction: 2) }

    var perSessionFormatted: String? {
        guard let pps = pricePerSession else { return nil }
        return "\(Self.chf(pps, minFraction: 0)) / Lektion"
    }

    /// Einheitliche CHF-Formatierung (de_CH). `minFraction: 0` lässt die Rappen
    /// nur bei ganzen Franken weg — Beträge mit Rappen erscheinen immer zweistellig.
    static func chf(_ value: Double, minFraction: Int = 2) -> String {
        let whole = (value * 100).rounded().truncatingRemainder(dividingBy: 100) == 0
        let digits = (minFraction == 0 && whole) ? 0 : 2
        let f = NumberFormatter()
        f.numberStyle           = .decimal
        f.minimumFractionDigits = digits
        f.maximumFractionDigits = digits
        f.locale = Locale(identifier: "de_CH")
        return "CHF \(f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value))"
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

/// Gebuchtes Lektionen-Paket. Pendant zu `ClientCredit` in `models/buyable_credit.dart`.
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
        // Gehört der Eintrag zu einem Online-Coaching-Abo (Backend: kind),
        // klar so benennen — er bleibt im Guthaben, weil seine Lektionen
        // buchbar sind
        self.title     = (json["kind"] as? String) == "coaching"
            ? "Online Coaching"
            : json["title"] as? String ?? "Lektionen-Paket"
        self.paid      = paid
        self.attended  = attended
        self.remaining = Int("\(json["remaining"] ?? 0)") ?? (paid - attended)
        self.startdate = json["startdate"] as? String
        self.expires   = json["expires"]   as? String
    }

    /// Aktiv ab Beginn des Starttags bis Ende des Ablauftags (Zürcher Zeit).
    var isActive: Bool {
        let now = Date()
        if let d = SwissDay.parse(expires), now >= SwissDay.endOfDay(d) { return false }
        if let d = SwissDay.parse(startdate), now < SwissDay.startOfDay(d) { return false }
        return true
    }
}
