import Foundation

/// Zentrale Zeitbasis für Termine und Kalender: Schweizer Ortszeit
/// (Europe/Zurich), gregorianischer Kalender, Woche ab Montag — unabhängig
/// von Zeitzone, Kalender und Region des Geräts.
///
/// Das Backend liefert Termine als lokale Zürcher Zeit ohne Zeitzone
/// ("2026-10-28" + "10:00"); Werte an das Backend gehen im selben Format.
enum ZurichTime {
    static let timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    static let locale   = Locale(identifier: "de_CH")

    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.locale = locale
        c.firstWeekday = 2              // Montag
        c.minimumDaysInFirstWeek = 4    // ISO-Wochen
        return c
    }()

    // MARK: - Formatter

    /// Formatter für API-Werte: POSIX-Locale (keine lokalisierten Ziffern),
    /// gregorianisch, Zürcher Zeitzone.
    static func apiFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = timeZone
        f.dateFormat = format
        return f
    }

    /// Formatter für die Anzeige (deutsch, Schweiz), Zürcher Zeitzone.
    static func displayFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendar
        f.timeZone = timeZone
        f.dateFormat = format
        return f
    }

    static let apiDay      = apiFormatter("yyyy-MM-dd")
    static let apiTime     = apiFormatter("HH:mm")
    static let apiDayTime  = apiFormatter("yyyy-MM-dd HH:mm")
    static let apiDayTimeSeconds = apiFormatter("yyyy-MM-dd HH:mm:ss")

    /// "10:00"
    static let time = displayFormatter("HH:mm")

    // MARK: - Helfer

    /// "yyyy-MM-dd" des Tages in Zürcher Zeit (für Backend und Vergleiche).
    static func dayString(_ date: Date) -> String { apiDay.string(from: date) }

    /// Parst Datum ("yyyy-MM-dd", ggf. mit Zeitanteil) + Uhrzeit ("HH:mm" oder
    /// "HH:mm:ss") als Zürcher Ortszeit.
    static func date(day: String, time: String?) -> Date? {
        let dayPart = String(day.prefix(10))
        guard let t = time, t.count >= 5 else { return apiDay.date(from: dayPart) }
        return apiDayTime.date(from: "\(dayPart) \(t.prefix(5))")
    }

    /// Minuten seit Mitternacht (Zürcher Zeit).
    static func minuteOfDay(_ date: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    // MARK: - Zeitstempel (ISO 8601)

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parst Backend-Zeitstempel robust: ISO 8601 mit oder ohne Millisekunden
    /// ("…T10:00:00.000Z" / "…T10:00:00Z"), sonst "yyyy-MM-dd HH:mm:ss",
    /// "yyyy-MM-dd'T'HH:mm[:ss]" oder "yyyy-MM-dd" als Zürcher Ortszeit.
    static func parseTimestamp(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        if let d = isoFractional.date(from: s) ?? isoPlain.date(from: s) { return d }
        // Ohne Zeitzone: als Zürcher Ortszeit lesen
        let normalized = s.replacingOccurrences(of: "T", with: " ")
        if normalized.count >= 19, let d = apiDayTimeSeconds.date(from: String(normalized.prefix(19))) { return d }
        if normalized.count >= 16, let d = apiDayTime.date(from: String(normalized.prefix(16))) { return d }
        return apiDay.date(from: String(normalized.prefix(10)))
    }
}

/// Liest eine ID aus JSON robust als String — das Backend liefert IDs als
/// Zahl, ältere Endpunkte teils als String. `nil` bei fehlend/null/leer.
func jsonID(_ value: Any?) -> String? {
    switch value {
    case let s as String:
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    case let n as NSNumber:
        // Bool (NSNumber) ausschliessen
        if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
        return n.stringValue
    case let i as Int:
        return String(i)
    default:
        return nil
    }
}
