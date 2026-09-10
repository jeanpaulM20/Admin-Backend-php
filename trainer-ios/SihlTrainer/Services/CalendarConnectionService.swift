import Foundation

// MARK: - Modelle

/// Zustand einer Kalender-Verbindung, wie ihn das Backend meldet.
struct CalendarLink {
    let available: Bool          // Anbieter auf dem Server eingerichtet
    let connected: Bool
    let accountEmail: String?
    let lastSyncAt: Date?
    let lastSyncError: String?

    init(json: [String: Any]) {
        available     = json["available"] as? Bool ?? false
        connected     = json["connected"] as? Bool ?? false
        accountEmail  = json["accountEmail"] as? String
        lastSyncError = json["lastSyncError"] as? String
        lastSyncAt    = (json["lastSyncAt"] as? String).flatMap {
            ISO8601DateFormatter().date(from: $0)
                ?? ISO8601DateFormatter.withFractional.date(from: $0)
        }
    }
}

struct CalendarStatus {
    let google: CalendarLink
    let microsoft: CalendarLink
}

private extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: - Dienst

/// Kalender-Zusammenführung, Phase 1: Outlook der Klinik wird gelesen,
/// die Termine landen als Sperrzeit im Google-Kalender — dadurch blendet
/// die Terminplanung auf der Website sie selbst aus.
struct CalendarConnectionService {

    func status(trainerId: Int) async throws -> CalendarStatus {
        let data = try await APIClient.shared.get("calendar/status/\(trainerId)")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError(statusCode: 500, message: "Unerwartete Antwort")
        }
        return CalendarStatus(
            google:    CalendarLink(json: json["google"] as? [String: Any] ?? [:]),
            microsoft: CalendarLink(json: json["microsoft"] as? [String: Any] ?? [:])
        )
    }

    /// Adresse der Anmeldeseite — wird im Browser geöffnet.
    func connectURL(provider: String, trainerId: Int) async throws -> URL {
        let data = try await APIClient.shared.get("calendar/connect/\(provider)/\(trainerId)")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = json["url"] as? String,
              let url = URL(string: urlString) else {
            throw APIError(statusCode: 500, message: "Keine Anmeldeadresse erhalten")
        }
        return url
    }

    func disconnect(provider: String, trainerId: Int) async throws {
        _ = try await APIClient.shared.delete("calendar/\(provider)/\(trainerId)")
    }

    /// Abgleich sofort auslösen. Gibt zurück, wie viele Sperrzeiten sich geändert haben.
    @discardableResult
    func syncNow(trainerId: Int) async throws -> Int {
        let data = try await APIClient.shared.post("calendar/sync/\(trainerId)")
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["changed"] as? Int ?? 0
    }
}

// MARK: - Phase 2: abonnierte Fremdkalender

/// Ein abonnierter Kalender. Die Adresse selbst gibt das Backend nie heraus —
/// sie ist ein Generalschlüssel zu diesem Kalender; `source` ist eine
/// maskierte Fassung nur zur Wiedererkennung.
struct CalendarFeed: Identifiable, Equatable {
    let id: Int
    let label: String
    let source: String
    let active: Bool
    let lastFetchAt: Date?
    let lastError: String?
    let eventCount: Int

    init(json: [String: Any]) {
        id = JSON.int(json, "id") ?? 0
        label = JSON.string(json, "label") ?? "Externer Kalender"
        source = JSON.string(json, "source") ?? ""
        active = JSON.bool(json, "active")
        lastError = JSON.string(json, "lastError")
        eventCount = JSON.int(json, "eventCount") ?? 0
        lastFetchAt = JSON.date(JSON.string(json, "lastFetchAt"))
    }
}

/// Eine belegte Zeit aus einem Fremdkalender — ohne Betreff, nur Zeitfenster.
struct ExternalBusy: Identifiable, Equatable {
    let id: Int
    let source: String
    let start: Date
    let end: Date
    let allDay: Bool

    init?(json: [String: Any]) {
        guard let start = JSON.date(JSON.string(json, "start")),
              let end = JSON.date(JSON.string(json, "end")) else { return nil }
        id = JSON.int(json, "id") ?? 0
        source = JSON.string(json, "source") ?? "Externer Kalender"
        self.start = start
        self.end = end
        allDay = JSON.bool(json, "allDay")
    }
}

struct CalendarFeedService {

    func feeds(trainerId: Int) async throws -> [CalendarFeed] {
        let data = try await APIClient.shared.get("calendar/feeds/\(trainerId)")
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return list.map(CalendarFeed.init(json:))
    }

    /// Legt das Abo an. Das Backend liest es sofort einmal ein — ein Tippfehler
    /// in der Adresse fällt damit direkt auf und nicht erst 15 Minuten später.
    @discardableResult
    func add(trainerId: Int, label: String, url: String) async throws -> CalendarFeed {
        let data = try await APIClient.shared.post("calendar/feeds/\(trainerId)", body: [
            "label": label,
            "url": url,
        ])
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError(statusCode: 500, message: "Unerwartete Antwort")
        }
        return CalendarFeed(json: json)
    }

    func remove(trainerId: Int, feedId: Int) async throws {
        _ = try await APIClient.shared.delete("calendar/feeds/\(trainerId)/\(feedId)")
    }

    /// Belegte Zeiten für die Kalenderanzeige.
    func busy(trainerId: Int, from: Date, to: Date) async throws -> [ExternalBusy] {
        let formatter = ISO8601DateFormatter()
        let path = "calendar/busy/\(trainerId)"
            + "?from=\(formatter.string(from: from))&to=\(formatter.string(from: to))"
        let data = try await APIClient.shared.get(path)
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return list.compactMap(ExternalBusy.init(json:))
    }
}
