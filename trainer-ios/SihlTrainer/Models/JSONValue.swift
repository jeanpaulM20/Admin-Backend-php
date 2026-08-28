import Foundation

/// Kleine Lesehilfen für die lose typisierten Backend-Antworten.
///
/// Das Backend mischt Legacy-PHP und NestJS: dieselbe Zahl kommt mal als Int,
/// mal als String, Schlüssel heissen mal snake_case, mal camelCase. Die
/// Flutter-Models fangen das mit `_parseInt`/`??`-Ketten ab; hier steht das
/// Pendant an einer Stelle, statt in jedem Model neu.
enum JSON {

    /// Erster nicht-leerer String unter den angegebenen Schlüsseln.
    static func string(_ json: [String: Any], _ keys: String...) -> String? {
        for key in keys {
            guard let value = json[key], !(value is NSNull) else { continue }
            let text = String(describing: value).trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { return text }
        }
        return nil
    }

    /// Int unter den angegebenen Schlüsseln; akzeptiert auch numerische Strings.
    static func int(_ json: [String: Any], _ keys: String...) -> Int? {
        for key in keys {
            guard let value = json[key], !(value is NSNull) else { continue }
            if let number = value as? Int { return number }
            if let number = value as? Double { return Int(number) }
            if let text = value as? String, let number = Int(text) { return number }
        }
        return nil
    }

    /// Wie `int`, aber 0 gilt als "nicht gesetzt" — das Legacy-Schema schreibt
    /// 0 statt NULL in Fremdschlüssel und Messwerte.
    static func intNonZero(_ json: [String: Any], _ keys: String...) -> Int? {
        for key in keys {
            guard let value = json[key], !(value is NSNull) else { continue }
            if let number = value as? Int { return number == 0 ? nil : number }
            if let number = value as? Double { return number == 0 ? nil : Int(number) }
            if let text = value as? String, let number = Int(text) { return number == 0 ? nil : number }
        }
        return nil
    }

    /// Double unter den angegebenen Schlüsseln; akzeptiert auch Strings.
    static func double(_ json: [String: Any], _ keys: String...) -> Double? {
        for key in keys {
            guard let value = json[key], !(value is NSNull) else { continue }
            if let number = value as? Double { return number }
            if let number = value as? Int { return Double(number) }
            if let text = value as? String, let number = Double(text) { return number }
        }
        return nil
    }

    /// Bool unter den angegebenen Schlüsseln; akzeptiert true/1/"1".
    static func bool(_ json: [String: Any], _ keys: String...) -> Bool {
        for key in keys {
            guard let value = json[key], !(value is NSNull) else { continue }
            if let flag = value as? Bool { return flag }
            if let number = value as? Int { return number == 1 }
            if let text = value as? String { return text == "1" || text.lowercased() == "true" }
        }
        return false
    }

    /// Datum aus den gemischten Formaten des Backends.
    /// ISO-8601 mit und ohne Zeitzone sowie "yyyy-MM-dd HH:mm:ss".
    static func date(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        if let date = isoWithFraction.date(from: text) { return date }
        if let date = iso.date(from: text) { return date }
        for format in fallbackFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// Datum aus getrennten Feldern (Legacy: `date` + `starttime`).
    static func date(day: String?, time: String?) -> Date? {
        guard let day, !day.isEmpty else { return nil }
        guard let time, !time.isEmpty else { return date(day) }
        return date("\(day) \(time)")
    }

    private static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso = ISO8601DateFormatter()

    private static let fallbackFormats = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd",
    ]

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()
}

extension String {
    /// Initialen für Avatare: "Anna Beispiel" → "AB", "Anna" → "A".
    var initials: String {
        let parts = split(separator: " ").filter { !$0.isEmpty }
        guard let first = parts.first?.first else { return "?" }
        if parts.count == 1 { return String(first).uppercased() }
        let last = parts[parts.count - 1].first.map(String.init) ?? ""
        return (String(first) + last).uppercased()
    }
}
