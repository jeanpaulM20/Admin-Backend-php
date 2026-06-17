# Xcode-Agent-Prompt — Chat-Tab lädt keine Daten

> Kopiere den Text zwischen den Linien unten 1:1 in den Xcode Coding-Agent.

---------------------------------------------------------------------------

**Aufgabe:** Der Chat-Tab (`ChatView`) lädt keine Gespräche/Nachrichten. Finde und behebe die Ursache. Ändere NICHTS, was laut „Bereits verifiziert" korrekt ist — sonst machst du Funktionierendes kaputt.

**Relevante Dateien:**
- `SihlClient/Views/ChatView.swift` — UI (Liste, Thread, Detail-Sheets)
- `SihlClient/ViewModels/ChatViewModel.swift` — `fetchConversations`, `fetchMessages`, `sendMessage`
- `SihlClient/Services/ChatService.swift` — API-Aufrufe
- `SihlClient/Models/ChatMessage.swift` — `ChatMessage`, `ChatConversation`, `TrainingReview`
- `SihlClient/Networking/APIClient.swift` — HTTP + Decoding
- `SihlClient/Auth/AuthViewModel.swift` / `AuthToken.swift` — `clientId`-Quelle

**Bereits verifiziert (NICHT ändern, ist korrekt):**
- Endpoint-Pfade stimmen mit dem Backend überein:
  `GET api/client/chat/{clientId}/conversations`, `.../messages/{trainerId}`, `POST .../messages/{trainerId}`, `.../read`
- JSON-Feldnamen (snake_case) im Decoder sind korrekt: `trainer_id`, `trainer_name`, `last_message`, `last_message_at`, `unread_count`, `sender_type`, `is_circle`, `created_at`
- Login-Antwort ist `{ "token": "...", "client": { "id": <Int> } }` → `AuthToken.clientId` wird korrekt als numerischer String geparst
- `sendMessage` gibt `Bool` zurück, `ChatView` hat bereits `.onChange(of: auth.clientId)` als Fallback
- Das Backend verlangt `clientId` als **Integer** (`ParseIntPipe`) → ein leerer oder nicht-numerischer `clientId` ergibt HTTP 400

**Vorgehen (in dieser Reihenfolge):**

1. Baue eine Diagnose ein: Füge in `ChatViewModel.fetchConversations` temporäre `print()`-Logs hinzu, die `clientId`, den HTTP-Status und die Anzahl/den Fehler ausgeben. Beispiel:
   ```swift
   print("CHAT fetchConversations clientId='\(clientId)'")
   // im do: print("CHAT loaded \(conversations.count) conversations")
   // im catch: print("CHAT error: \(error)")
   ```
   Mache dasselbe in `APIClient.send` (logge die finale URL und den `http.statusCode`).

2. Starte die App im Simulator, logge dich ein, öffne den Chat-Tab und lies die Konsole. Bestimme welcher Fall vorliegt:
   - **Kein `fetchConversations`-Log** → `clientId` ist `nil`/leer, der `.task`/`.onChange` greift nicht. Prüfe ob `AuthViewModel.clientId` nach dem Login gesetzt und vor dem Tab-Wechsel verfügbar ist.
   - **Log mit leerem `clientId=''`** → `AuthToken`-Decoding liefert keinen `client.id`. Prüfe die echte Login-Antwort und passe `AuthToken.init` an.
   - **HTTP 400/404** → falscher/leerer `clientId` in der URL (z.B. doppelter Slash `chat//conversations`).
   - **HTTP 401** → Token fehlt/abgelaufen; prüfe ob `APIClient.setToken` vor dem Request aufgerufen wurde.
   - **HTTP 200 aber 0 Conversations** → Backend liefert leeres Array für diesen Client; KEIN App-Bug. Prüfe mit einem Account, der Trainer-Nachrichten hat.
   - **Decode-Fehler** (`statusCode -2`, „Antwort konnte nicht gelesen werden") → die JSON-Struktur weicht ab (z.B. in ein Objekt gewrappt statt bares Array). Logge den rohen Response-Body als String und passe den Decoder an.

3. Behebe NUR die unter Schritt 2 bestätigte Ursache. Rate nicht — richte dich nach dem tatsächlichen Konsolen-Output.

4. Entferne danach die temporären `print()`-Logs wieder.

5. Verifiziere: Chat-Tab öffnen → Gespräche erscheinen; Gespräch antippen → Nachrichten laden; Nachricht senden → erscheint. Baue mit dem `SihlCient`-Scheme für den Simulator und stelle sicher, dass es ohne Fehler kompiliert.

**Wichtig:** Der Code baut bereits fehlerfrei (`** BUILD SUCCEEDED **`). Es ist also kein Compile-Fehler, sondern ein Laufzeit-/Daten-Problem. Konzentriere dich auf den tatsächlichen Request und seinen Response, nicht auf Refactoring.

---------------------------------------------------------------------------
