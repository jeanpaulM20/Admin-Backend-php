import Foundation

/// Fehler-Typ analog zur Flutter `ApiException`.
struct APIError: LocalizedError {
    let statusCode: Int
    let message: String

    var errorDescription: String? { message }
}

/// HTTP-Client auf Basis von URLSession + async/await.
/// Pendant zur Flutter `ApiClient` (singleton `apiClient`).
///
/// Token wird im Arbeitsspeicher gehalten; persistente Speicherung
/// übernimmt der `AuthViewModel` via `KeychainStore`.
actor APIClient {
    static let shared = APIClient()

    private var token: String?

    func setToken(_ token: String?) {
        self.token = token
    }

    // MARK: - Öffentliche Verben

    func get(_ path: String, timeout: TimeInterval? = nil) async throws -> Data {
        try await send(path: path, method: "GET", body: nil, timeout: timeout)
    }

    func post(_ path: String, body: [String: Any]? = nil, timeout: TimeInterval? = nil) async throws -> Data {
        try await send(path: path, method: "POST", body: body, timeout: timeout)
    }

    func put(_ path: String, body: [String: Any]? = nil) async throws -> Data {
        try await send(path: path, method: "PUT", body: body)
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

    #if DEBUG
    /// Roher Aufruf für den Verbindungstest: liefert Status, Grösse und einen
    /// Ausschnitt der Antwort, statt Fehler in Meldungen zu übersetzen.
    /// Nur in Debug-Builds vorhanden.
    func probe(_ path: String) async -> (status: Int, bytes: Int, snippet: String) {
        var request = URLRequest(url: buildURL(path))
        request.httpMethod = "GET"
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: APIConfig.authHeader)
        } else {
            return (-1, 0, "kein Token gesetzt")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            var snippet = String(data: data.prefix(200), encoding: .utf8) ?? "nicht lesbar"
            if let array = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                snippet = "Array mit \(array.count) Einträgen"
            }
            return (status, data.count, snippet)
        } catch let error as URLError {
            return (-2, 0, Self.describe(error))
        } catch {
            return (-2, 0, error.localizedDescription)
        }
    }
    #endif

    // MARK: - Intern

    private func send(path: String, method: String, body: [String: Any]?,
                      timeout: TimeInterval? = nil) async throws -> Data {
        var request = URLRequest(url: buildURL(path))
        request.httpMethod = method
        request.timeoutInterval = timeout ?? APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: APIConfig.authHeader)
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            // Ohne diese Übersetzung landet jeder Netzwerkfehler im generischen
            // "konnte nicht geladen werden" der Views — dann ist nicht mehr
            // erkennbar, ob es am Netz, am Zeitlimit oder am Server lag.
            throw APIError(statusCode: -3, message: Self.describe(error))
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError(statusCode: -1, message: "Ungültige Serverantwort")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw decodeError(statusCode: http.statusCode, data: data)
        }
        return data
    }

    /// Klartext für die häufigen Netzwerkfehler.
    private static func describe(_ error: URLError) -> String {
        switch error.code {
        case .timedOut:
            return "Zeitüberschreitung — der Server hat nicht rechtzeitig geantwortet."
        case .notConnectedToInternet:
            return "Keine Internetverbindung."
        case .networkConnectionLost:
            return "Verbindung unterbrochen."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Server nicht erreichbar."
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return "Gesicherte Verbindung fehlgeschlagen."
        case .cancelled:
            return "Anfrage abgebrochen."
        default:
            return "Netzwerkfehler (\(error.code.rawValue))."
        }
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

    private func decodeError(statusCode: Int, data: Data) -> APIError {
        var message: String
        switch statusCode {
        case 401:      message = "Passcode ungültig"
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
        return APIError(statusCode: statusCode, message: message)
    }
}
