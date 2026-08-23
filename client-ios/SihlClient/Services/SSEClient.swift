import Foundation

/// iOS-Ersatz für Flutter's `dart:html EventSource` aus `realtime_service.dart`.
///
/// Flutter (Web) nutzt `dart:html EventSource` — das ist web-only.
/// Auf iOS öffnen wir stattdessen einen `URLSession`-Streaming-Request und iterieren
/// per `AsyncBytes.lines` über die SSE-Zeilen (verfügbar ab iOS 15).
///
/// Verbindung:  `GET /api/events/stream?channel=client_{clientId}&token=...`
/// Wiederverbindung: automatisch nach 5 s (wie im Flutter-Original).
actor SSEClient {

    private var streamTask: Task<Void, Never>?

    // MARK: - Public API

    /// Öffnet die SSE-Verbindung für den angegebenen Channel.
    /// `onEvent` wird auf dem **MainActor** aufgerufen.
    func connect(channel: String, token: String, onEvent: @escaping @Sendable (String) -> Void) {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            await self.stream(channel: channel, token: token, onEvent: onEvent)
        }
    }

    /// Trennt die Verbindung (kein Auto-Reconnect mehr).
    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
    }

    // MARK: - Private streaming loop

    private func stream(
        channel: String,
        token: String,
        onEvent: @escaping @Sendable (String) -> Void
    ) async {
        while !Task.isCancelled {
            do {
                guard
                    let encodedChannel = channel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                    let encodedToken   = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                else { return }

                let base = APIConfig.baseURL.absoluteString
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard let url = URL(string: "\(base)/api/events/stream?channel=\(encodedChannel)&token=\(encodedToken)") else { return }

                var request = URLRequest(url: url)
                request.timeoutInterval = 300          // 5 min — SSE-Verbindung bleibt offen
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                let (asyncBytes, _) = try await URLSession.shared.bytes(for: request)
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
                    // Auf den MainActor wechseln, dann Callback auslösen
                    await MainActor.run { onEvent(type) }
                }
                // Stream sauber beendet (z.B. 401/Fehlerantwort ohne Exception):
                // ohne Delay würde die while-Schleife den Server im Tight-Loop hämmern.
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                if Task.isCancelled { return }
                // 5 s warten, dann neu verbinden (wie Flutter: `Future.delayed(5s)`)
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
}
