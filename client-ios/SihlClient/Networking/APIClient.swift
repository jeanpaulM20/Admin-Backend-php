import Foundation
import os

/// Fehler-Typ analog zur Flutter `ApiException`.
struct APIError: LocalizedError {
    let statusCode: Int
    let message: String
    /// Roh-Antwort des Servers — für Aufrufer, die Zusatzfelder der
    /// Fehlerantwort brauchen (z. B. `pointIndex` beim Routenplaner).
    var body: Data? = nil

    var errorDescription: String? { message }
}

/// HTTP-Client auf Basis von URLSession + async/await.
/// Pendant zur Flutter `ApiClient` (singleton `apiClient`).
///
/// Token wird im Arbeitsspeicher gehalten; persistente Speicherung
/// übernimmt der `AuthViewModel` via `KeychainStore`.
///
/// Ein 401 auf einen Request mit Token (ausser dem Login) heisst: Sitzung
/// ungültig. Dann ruft der Client den `unauthorizedHandler` auf, den die
/// Composition Root (`SihlClientApp`) setzt — dort wird abgemeldet.
actor APIClient {
    static let shared = APIClient()

    /// Login-Endpunkt: Ein 401 dort heisst „falsche Zugangsdaten“, nicht
    /// „Sitzung abgelaufen“.
    static let loginPath = "api/client/token"

    /// Token und Handler synchron les-/setzbar, damit der Kaltstart das
    /// Token schon vor dem ersten Request gesetzt hat.
    private nonisolated let state = OSAllocatedUnfairLock(initialState: SharedState())

    private struct SharedState {
        var token: String?
        var unauthorizedHandler: (@Sendable () async -> Void)?
    }

    nonisolated func setToken(_ token: String?) {
        state.withLock { $0.token = token }
    }

    /// Wird bei einem 401 mit gültigem Token (ausser Login) aufgerufen.
    nonisolated func setUnauthorizedHandler(_ handler: (@Sendable () async -> Void)?) {
        state.withLock { $0.unauthorizedHandler = handler }
    }

    private var token: String? { state.withLock { $0.token } }

    // MARK: - Öffentliche Verben

    func get(_ path: String, timeout: TimeInterval? = nil) async throws -> Data {
        try await send(path: path, method: "GET", body: nil, timeout: timeout)
    }

    func post(_ path: String, body: [String: Any]? = nil, timeout: TimeInterval? = nil) async throws -> Data {
        try await send(path: path, method: "POST", body: body, timeout: timeout)
    }

    func put(_ path: String, body: [String: Any]? = nil, timeout: TimeInterval? = nil) async throws -> Data {
        try await send(path: path, method: "PUT", body: body, timeout: timeout)
    }

    func delete(_ path: String) async throws -> Data {
        try await send(path: path, method: "DELETE", body: nil)
    }

    // MARK: - Typed-Convenience

    /// GET + JSON-Decoding in einem Schritt.
    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        let data = try await get(path)
        return try decode(data)
    }

    func post<T: Decodable>(_ path: String, body: [String: Any]? = nil, as type: T.Type) async throws -> T {
        let data = try await post(path, body: body)
        return try decode(data)
    }

    // MARK: - JSON-Dictionary-Convenience
    // Für Models mit `init(json: [String: Any])`-Muster — erspart den Services
    // das JSONSerialization-Boilerplate. Parse-Fehler → leeres Ergebnis (die
    // Services behandeln "keine Daten" und "unlesbare Daten" bewusst gleich).

    /// GET, dessen Antwort ein JSON-Array von Objekten ist.
    func getJSONArray(_ path: String, timeout: TimeInterval? = nil) async throws -> [[String: Any]] {
        let data = try await get(path, timeout: timeout)
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    /// GET, dessen Antwort ein einzelnes JSON-Objekt ist.
    func getJSONObject(_ path: String, timeout: TimeInterval? = nil) async throws -> [String: Any]? {
        let data = try await get(path, timeout: timeout)
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// POST, dessen Antwort ein einzelnes JSON-Objekt ist.
    func postJSONObject(_ path: String, body: [String: Any]? = nil, timeout: TimeInterval? = nil) async throws -> [String: Any]? {
        let data = try await post(path, body: body, timeout: timeout)
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // MARK: - Intern

    /// Datei laden (Header-Auth) — liefert zusätzlich MIME-Typ und
    /// vorgeschlagenen Dateinamen für die Vorschau.
    func download(_ path: String, timeout: TimeInterval = 60) async throws
        -> (data: Data, mimeType: String?, suggestedFilename: String?) {
        let (data, http) = try await perform(path: path, method: "GET", body: nil,
                                             timeout: timeout, accept: "*/*")
        return (data, http.mimeType, http.suggestedFilename)
    }

    private func send(path: String, method: String, body: [String: Any]?,
                      timeout: TimeInterval? = nil) async throws -> Data {
        try await perform(path: path, method: method, body: body, timeout: timeout).data
    }

    private func perform(path: String, method: String, body: [String: Any]?,
                         timeout: TimeInterval? = nil,
                         accept: String = "application/json") async throws -> (data: Data, http: HTTPURLResponse) {
        var request = URLRequest(url: buildURL(path))
        request.httpMethod = method
        request.timeoutInterval = timeout ?? APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        let sentToken = token
        if let sentToken, !sentToken.isEmpty {
            request.setValue(sentToken, forHTTPHeaderField: APIConfig.authHeader)
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(statusCode: -1, message: "Ungültige Serverantwort")
        }
        guard (200..<300).contains(http.statusCode) else {
            let isLogin = Self.isLoginPath(path)
            if http.statusCode == 401, !isLogin {
                handleUnauthorized(sentToken: sentToken)
            }
            throw decodeError(statusCode: http.statusCode, data: data, isLogin: isLogin)
        }
        return (data, http)
    }

    /// Sitzung ungültig → zentral abmelden. Nur, wenn der Request das noch
    /// aktuelle Token trug (nicht nach Logout oder Neuanmeldung).
    private func handleUnauthorized(sentToken: String?) {
        guard let sentToken, !sentToken.isEmpty else { return }
        let (current, handler) = state.withLock { ($0.token, $0.unauthorizedHandler) }
        guard current == sentToken, let handler else { return }
        Task { await handler() }
    }

    private static func isLoginPath(_ path: String) -> Bool {
        let clean = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return clean.split(separator: "?").first.map(String.init) == loginPath
    }

    private func buildURL(_ path: String) -> URL {
        let clean = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: clean, relativeTo: APIConfig.baseURL) ?? APIConfig.baseURL
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError(statusCode: -2, message: "Antwort konnte nicht gelesen werden")
        }
    }

    private func decodeError(statusCode: Int, data: Data, isLogin: Bool) -> APIError {
        var message: String
        switch statusCode {
        case 401:      message = isLogin ? "E-Mail oder Passwort falsch"
                                         : "Sitzung abgelaufen – bitte neu anmelden"
        case 403:      message = "Dafür fehlt die Berechtigung."
        case 404:      message = "Nicht gefunden."
        case 500...:   message = "Der Server ist gerade nicht erreichbar — bitte später erneut versuchen."
        default:       message = "Serverfehler (\(statusCode))"
        }
        // Server-Message nur übernehmen, wenn sie mehr sagt als die üblichen
        // englischen HTTP-Floskeln ("Unauthorized" etc.)
        let generic: Set<String> = ["unauthorized", "forbidden", "not found", "bad request",
                                    "internal server error", "unprocessable entity"]
        if statusCode != 401,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let serverMsg = obj["message"] as? String,
           !generic.contains(serverMsg.lowercased()) {
            message = serverMsg
        }
        return APIError(statusCode: statusCode, message: message, body: data)
    }
}
