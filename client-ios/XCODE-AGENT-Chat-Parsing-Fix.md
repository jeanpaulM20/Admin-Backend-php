# Xcode-Agent-Prompt — Chat defensiv parsen wie die Flutter-App

> Kopiere den Text zwischen den Linien 1:1 in den Xcode Coding-Agent.

---------------------------------------------------------------------------

**Kontext:** Die Chat-Funktion läuft in der Flutter-App einwandfrei, in der SwiftUI-App lädt/zeigt sie nicht korrekt. Beide reden mit demselben Backend (identisches JSON). Ursache ist NICHT das Backend, sondern dass das SwiftUI-Decoding strikt und „alles-oder-nichts" ist, während Flutter defensiv parst. Mache das SwiftUI-Parsing genauso robust wie Flutter.

**Betroffene Dateien:**
- `SihlClient/Services/ChatService.swift`
- `SihlClient/Models/ChatMessage.swift`
- `SihlClient/Networking/APIClient.swift`

**Verifizierte Fakten (NICHT ändern):** Endpoint-Pfade, Feldnamen (snake_case), Auth-Header `X-Auth-Token`, Login-Antwort `{ token, client:{ id } }` sind alle korrekt. Der Code kompiliert bereits. Es geht NUR um robusteres Verarbeiten der Antwort.

---

### Fix 1 — `ChatService`: Antwort defensiv Element-für-Element dekodieren

In Flutter macht der Service:
```dart
if (data is List) {
  return data.whereType<Map>().map(ChatConversation.fromJson).toList();
}
return [];
```
Das SwiftUI-Pendant nutzt aktuell `get(path, as: [ChatConversation].self)` — das ist alles-oder-nichts: ein einziges fehlerhaftes Array-Element ODER eine Nicht-Array-Antwort lässt den GESAMTEN Decode scheitern → 0 Gespräche.

Ändere `ChatService.swift` so, dass die Antwort als rohe `Data` geholt und dann Element für Element dekodiert wird; fehlerhafte Elemente werden übersprungen, eine Nicht-Array-Antwort ergibt eine leere Liste (kein Throw):

```swift
import Foundation

struct ChatService {
    static let shared = ChatService()

    func getConversations(clientId: String) async throws -> [ChatConversation] {
        let data = try await APIClient.shared.get("api/client/chat/\(clientId)/conversations")
        return Self.decodeArraySkippingBad(data, as: ChatConversation.self)
    }

    func getMessages(clientId: String, trainerId: String) async throws -> [ChatMessage] {
        let data = try await APIClient.shared.get("api/client/chat/\(clientId)/messages/\(trainerId)")
        return Self.decodeArraySkippingBad(data, as: ChatMessage.self)
    }

    func sendMessage(clientId: String, trainerId: String, text: String) async throws -> ChatMessage {
        try await APIClient.shared.post(
            "api/client/chat/\(clientId)/messages/\(trainerId)",
            body: ["text": text], as: ChatMessage.self)
    }

    func markAsRead(clientId: String, trainerId: String) async throws {
        _ = try await APIClient.shared.post("api/client/chat/\(clientId)/messages/\(trainerId)/read")
    }

    func getReviews(clientId: String) async throws -> [TrainingReview] {
        let data = try await APIClient.shared.get("api/client/reviews/\(clientId)")
        return Self.decodeArraySkippingBad(data, as: TrainingReview.self)
    }

    func getPerformanceTests(clientId: String) async throws -> [PerformanceTest] {
        let data = try await APIClient.shared.get("api/client/tests/\(clientId)")
        return Self.decodeArraySkippingBad(data, as: PerformanceTest.self)
    }

    func getBodyMetrics(clientId: String) async throws -> [BodyMetric] {
        let data = try await APIClient.shared.get("api/client/profile/\(clientId)")
        return Self.decodeArraySkippingBad(data, as: BodyMetric.self)
    }

    /// Dekodiert ein JSON-Array Element für Element. Nicht-Array-Antworten ergeben [].
    /// Einzelne fehlerhafte Elemente werden übersprungen (wie Flutters whereType().map()).
    private static func decodeArraySkippingBad<T: Decodable>(_ data: Data, as type: T.Type) -> [T] {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        let decoder = JSONDecoder()
        var result: [T] = []
        for element in raw {
            guard JSONSerialization.isValidJSONObject([element]),
                  let elemData = try? JSONSerialization.data(withJSONObject: element),
                  let decoded = try? decoder.decode(T.self, from: elemData)
            else { continue }
            result.append(decoded)
        }
        return result
    }
}
```

> Hinweis: Die bestehenden Detail-Sheets erwarten weiterhin `[TrainingReview]` / `[PerformanceTest]` / `[BodyMetric]` — Signaturen bleiben gleich, nur die Implementierung wird robust.

---

### Fix 2 — `ChatMessage.swift`: toleranter Datums-Parser (wie Flutters `DateTime.tryParse`)

Aktuell parst SwiftUI nur striktes ISO8601. Flutter akzeptiert auch das MySQL-Format `"2024-03-15 14:30:00"` (Leerzeichen statt `T`, ohne `Z`). Wenn das Backend dieses Format liefert (z. B. aus Raw-SQL `MAX(created_at)`), schlägt SwiftUI fehl → Nachrichten zeigen die aktuelle Uhrzeit und gruppieren alle unter „Heute".

Erweitere die Datums-Hilfsfunktion in `ChatMessage.swift` um einen MySQL-Fallback:

```swift
private let _iso8601Ms: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
}()
private let _iso8601Plain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
}()
private let _mysqlFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()
private func iso8601Fmt(from s: String) -> Date? {
    _iso8601Ms.date(from: s)
        ?? _iso8601Plain.date(from: s)
        ?? _mysqlFmt.date(from: s)                     // MySQL "yyyy-MM-dd HH:mm:ss"
        ?? _mysqlFmt.date(from: String(s.prefix(19)))  // ISO mit Offset zur Not abschneiden
}
```
Alle bestehenden Aufrufe `iso8601Fmt(from:)` bleiben unverändert.

---

### Fix 3 — `ChatMessage.swift`: Feld-Defaults an Flutter angleichen

In `ChatMessage.init`:
- `sender_type`-Default von `"trainer"` auf **`"client"`** ändern (Flutter-Verhalten — sonst landet eine Nachricht ohne Typ auf der falschen Seite).
- `text` mit Fallback lesen wie Flutter (`text ?? message ?? comment`):
  ```swift
  text = (try? c.decode(String.self, forKey: .text))
      ?? (try? c.decode(String.self, forKey: .message))
      ?? (try? c.decode(String.self, forKey: .comment))
      ?? ""
  ```
  Dafür die `CodingKeys` um `case message` und `case comment` ergänzen.

In `ChatConversation.init`:
- `unread_count` auch als String tolerieren:
  ```swift
  if let i = try? c.decode(Int.self, forKey: .unreadCount) { unreadCount = i }
  else if let s = try? c.decode(String.self, forKey: .unreadCount), let i = Int(s) { unreadCount = i }
  else { unreadCount = 0 }
  ```

---

### Verifikation

1. Baue mit dem Scheme `SihlCient` für den iOS-Simulator — muss fehlerfrei kompilieren.
2. Logge dich in der App ein, öffne den Chat-Tab:
   - Gespräche erscheinen (auch wenn einzelne Datensätze unvollständig sind).
   - Gespräch öffnen → Nachrichten mit korrekten Zeitstempeln und korrekter Tages-Gruppierung.
   - Eigene Nachrichten rechts, Trainer-Nachrichten links.
3. Falls weiterhin leer: Füge temporär in `APIClient.send` ein `print(String(data: data, encoding: .utf8) ?? "")` direkt vor dem Return ein, öffne den Chat, und prüfe in der Konsole die ROHE Antwort des `conversations`-Endpoints — passe den Decoder an die tatsächliche Struktur an. Entferne das Log danach.

**Ziel:** Das SwiftUI-Parsing soll genauso fehlertolerant sein wie Flutters `whereType().map(fromJson)` + `DateTime.tryParse`. Keine UI-/Layout-Änderungen in diesem Schritt — nur robustes Laden und korrekte Daten.

---------------------------------------------------------------------------
