import Foundation

/// Einzelne CGM-Messung vom FreeStyle Libre Sensor.
/// TrendArrow: 1=steigt stark … 4=stabil … 7=fällt stark.
struct GlucoseReading: Codable, Identifiable {
    let id: UUID
    let valueMmol: Double
    let valueMgDl: Int
    let timestamp: Date
    let trendArrow: Int   // 1–7
    let isHigh: Bool
    let isLow: Bool

    init(id: UUID = UUID(), valueMmol: Double, valueMgDl: Int,
         timestamp: Date, trendArrow: Int, isHigh: Bool, isLow: Bool) {
        self.id = id
        self.valueMmol = valueMmol
        self.valueMgDl = valueMgDl
        self.timestamp = timestamp
        self.trendArrow = trendArrow
        self.isHigh = isHigh
        self.isLow = isLow
    }

    // MARK: - Codable (LibreView JSON → Swift)

    private enum CodingKeys: String, CodingKey {
        case valueMmol = "Value"
        case valueMgDl = "ValueInMgPerDl"
        case timestamp = "Timestamp"
        case trendArrow = "TrendArrow"
        case isHigh, isLow
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        valueMmol = (try? c.decode(Double.self, forKey: .valueMmol)) ?? 0
        valueMgDl = (try? c.decode(Int.self, forKey: .valueMgDl)) ?? 0
        trendArrow = (try? c.decode(Int.self, forKey: .trendArrow)) ?? 4
        isHigh = (try? c.decode(Bool.self, forKey: .isHigh)) ?? false
        isLow  = (try? c.decode(Bool.self, forKey: .isLow))  ?? false

        // LibreView liefert "1/15/2025 10:30:00 AM" — DateFormatter nötig
        let raw = (try? c.decode(String.self, forKey: .timestamp)) ?? ""
        timestamp = GlucoseReading.parseLibreDate(raw) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(valueMmol, forKey: .valueMmol)
        try c.encode(valueMgDl, forKey: .valueMgDl)
        try c.encode(ISO8601DateFormatter().string(from: timestamp), forKey: .timestamp)
        try c.encode(trendArrow, forKey: .trendArrow)
        try c.encode(isHigh, forKey: .isHigh)
        try c.encode(isLow, forKey: .isLow)
    }

    // MARK: - Darstellung

    var trendIcon: String {
        let icons = ["", "↑↑", "↑", "↗", "→", "↘", "↓", "↓↓"]
        guard trendArrow >= 1, trendArrow <= 7 else { return "→" }
        return icons[trendArrow]
    }

    var displayValue: String { String(format: "%.1f mmol/L", valueMmol) }

    // MARK: - Datums-Parser

    private static let libreFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d/yyyy h:mm:ss a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func parseLibreDate(_ raw: String) -> Date? {
        libreFormatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
}
