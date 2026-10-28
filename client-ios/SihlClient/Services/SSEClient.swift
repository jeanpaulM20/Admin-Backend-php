import Foundation

/// iOS-Ersatz für Flutter's `dart:html EventSource` aus `realtime_service.dart`.
///
/// Öffnet einen `URLSession`-Streaming-Request und iteriert per
/// `AsyncBytes.lines` über die SSE-Zeilen.
///
/// Verbindung:  `GET /api/events/stream?channel=client_{clientId}`,
/// Token im Header `X-Auth-Token` (nicht in der URL — landet sonst in Logs).
/// Wiederverbindung: nach 5 s; bei 401/403 wird endgültig aufgehört.
actor SSEClient {

    private var streamTask: Task<Void, Never>?

    // MARK: - Strukturierte API (bevorzugt)

    /// Liefert die Event-Typen eines Kanals als `AsyncStream`. Der Stream endet,
    /// sobald der konsumierende Task abgebrochen wird (z. B. `.task` beim
    /// Verlassen der View) — keine verwaiste Verbindung, kein Reconnect-Loop.
    /// Endet ebenfalls bei 401/403.
    static func events(channel: String, token: String) -> AsyncStream<String> {
        AsyncStream(bufferingPolicy: .bufferingNewest(8)) { continuation in
            let task = Task {
                await run(channel: channel, token: token) { type in
                    continuation.yield(type)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Callback-API

    /// Öffnet die SSE-Verbindung für den angegebenen Channel.
    /// `onEvent` wird auf dem **MainActor** aufgerufen.
    /// Ist der aufrufende Task bereits abgebrochen, wird nicht verbunden.
    func connect(channel: String, token: String, onEvent: @escaping @Sendable (String) -> Void) {
        streamTask?.cancel()
        streamTask = nil
        guard !Task.isCancelled else { return }
        streamTask = Task {
            await Self.run(channel: channel, token: token) { type in
                guard !Task.isCancelled else { return }
                await MainActor.run { onEvent(type) }
            }
        }
    }

    /// Trennt die Verbindung (kein Auto-Reconnect mehr).
    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
    }

    // MARK: - Streaming-Schleife

    /// Liest den Stream bis Abbruch oder Auth-Fehler; reconnectet nach 5 s.
    private static func run(
        channel: String,
        token: String,
        onEvent: @Sendable (String) async -> Void
    ) async {
        guard !channel.isEmpty, !token.isEmpty,
              let encodedChannel = channel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return }
        let base = APIConfig.baseURL.absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/events/stream?channel=\(encodedChannel)") else { return }

        while !Task.isCancelled {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 300          // 5 min — SSE-Verbindung bleibt offen
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.setValue(token, forHTTPHeaderField: APIConfig.authHeader)

                let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                if let http = response as? HTTPURLResponse {
                    // Token ungültig/abgelaufen: Neuverbinden bringt nichts
                    if http.statusCode == 401 || http.statusCode == 403 { return }
                    guard (200..<300).contains(http.statusCode) else {
                        throw URLError(.badServerResponse)
                    }
                }
                for try await line in asyncBytes.lines {
                    if Task.isCancelled { return }
                    guard line.hasPrefix("data:") else { continue }
                    let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    guard
                        let data  = payload.data(using: .utf8),
                        let obj   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let type  = obj["type"] as? String,
                        type != "ping"
                    else { continue }
                    await onEvent(type)
                }
                // Stream vom Server beendet: verzögert neu verbinden (kein Tight-Loop)
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
}
