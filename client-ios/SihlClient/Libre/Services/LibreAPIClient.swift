import Foundation

/// HTTP-Client für die inoffizielle LibreLinkUp API (URLSession + async/await).
/// HINWEIS: Inoffizielle API — kein Support durch Abbott, kann sich ändern.
actor LibreAPIClient {
    private static let appProduct = "llu.ios"
    private static let appVersion = "4.12.0"
    private static let timeout: TimeInterval = 15

    let region: LibreRegion

    init(region: LibreRegion = .eu) {
        self.region = region
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws -> LibreAuthTicket {
        let data = try await post("llu/auth/login", body: [
            "email": email,
            "password": password,
        ])
        let root = try decode([String: AnyCodable].self, from: data)
        guard let dataObj = root["data"]?.value as? [String: Any],
              let ticketObj = dataObj["authTicket"] as? [String: Any] else {
            throw LibreError(code: 0, message: "Ungültige Login-Antwort")
        }
        let ticketData = try JSONSerialization.data(withJSONObject: ticketObj)
        return try JSONDecoder().decode(LibreAuthTicket.self, from: ticketData)
    }

    // MARK: - Connections

    func getConnections(token: String) async throws -> [LibreConnection] {
        let data = try await get("llu/connections", token: token)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let list = root?["data"] as? [[String: Any]] ?? []
        return try list.map { obj in
            let d = try JSONSerialization.data(withJSONObject: obj)
            return try JSONDecoder().decode(LibreConnection.self, from: d)
        }
    }

    // MARK: - Graph-Daten

    func getGraphData(token: String, patientId: String) async throws -> [GlucoseReading] {
        let data = try await get("llu/connections/\(patientId)/graph", token: token)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let inner = root?["data"] as? [String: Any]

        var readings: [GlucoseReading] = []

        // Verlauf
        if let graphData = inner?["graphData"] as? [[String: Any]] {
            readings = try graphData.compactMap { obj in
                let d = try JSONSerialization.data(withJSONObject: obj)
                return try? JSONDecoder().decode(GlucoseReading.self, from: d)
            }
        }

        // Aktuelle Messung aus Connection ergänzen
        if let connection = inner?["connection"] as? [String: Any],
           let current = connection["glucoseMeasurement"] as? [String: Any] {
            let d = try JSONSerialization.data(withJSONObject: current)
            if let currentReading = try? JSONDecoder().decode(GlucoseReading.self, from: d) {
                if readings.isEmpty || currentReading.timestamp > (readings.last?.timestamp ?? .distantPast) {
                    readings.append(currentReading)
                }
            }
        }

        return readings.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Intern

    private func get(_ path: String, token: String) async throws -> Data {
        try await send(path: path, method: "GET", body: nil, token: token)
    }

    private func post(_ path: String, body: [String: Any]) async throws -> Data {
        try await send(path: path, method: "POST", body: body, token: nil)
    }

    private func send(path: String, method: String, body: [String: Any]?, token: String?) async throws -> Data {
        let url = URL(string: "\(region.rawValue)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.appProduct, forHTTPHeaderField: "product")
        request.setValue(Self.appVersion, forHTTPHeaderField: "version")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LibreError(code: -1, message: "Ungültige Serverantwort")
        }
        if http.statusCode == 401 {
            throw LibreError(code: 401, message: "Nicht autorisiert — bitte erneut einloggen")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LibreError(code: http.statusCode, message: "Serverfehler (\(http.statusCode))")
        }
        // LibreView gibt status=0 bei Erfolg zurück
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? Int, status != 0 {
            throw LibreError(code: status, message: "API-Fehler (Status \(status))")
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

struct LibreError: LocalizedError {
    let code: Int
    let message: String
    var errorDescription: String? { message }
}

// Hilfsstruct um beliebige JSON-Werte zu wrappen
struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode([String: AnyCodable].self) { value = v.mapValues { $0.value }; return }
        if let v = try? c.decode([AnyCodable].self)         { value = v.map { $0.value }; return }
        if let v = try? c.decode(String.self)               { value = v; return }
        if let v = try? c.decode(Double.self)               { value = v; return }
        if let v = try? c.decode(Bool.self)                 { value = v; return }
        value = NSNull()
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as String: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as Bool:   try c.encode(v)
        default: try c.encodeNil()
        }
    }
}
