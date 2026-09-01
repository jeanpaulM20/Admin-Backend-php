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
