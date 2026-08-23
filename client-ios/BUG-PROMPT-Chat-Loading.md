# BUG-PROMPT — Chat lädt nicht (Diagnose & Fix)

Datei: `SihlClient/Views/ChatView.swift`
ViewModell: `SihlClient/ViewModels/ChatViewModel.swift`
Netzwerk: `SihlClient/Networking/APIClient.swift`
Auth: `SihlClient/Auth/AuthViewModel.swift`
Modelle: `SihlClient/Models/ChatMessage.swift`

---

## Bekannte Bugs (aus Code-Analyse — vor Gerät-Test identifiziert)

### Bug 1 — KRITISCH: Race Condition `auth.clientId` (Chat lädt nie beim App-Start)

**Datei:** `ChatView.swift` Zeile ~23 + `AuthViewModel.swift` Zeile 28

**Ursache:**
`AuthViewModel.init()` startet `loadSavedAuth()` als **nicht-awaitetes** `Task`:
```swift
// AuthViewModel.swift:
init() {
    Task { await loadSavedAuth() }   // ← async, läuft im Hintergrund
}
```

`ChatView.task` feuert sofort wenn die View erscheint. Zu diesem Zeitpunkt hat
`loadSavedAuth()` noch nicht fertig — `auth.clientId` ist `nil`:
```swift
// ChatView.swift:
.task {
    if let id = auth.clientId {      // ← clientId ist nil → guard schlägt fehl
        await vm.fetchConversations(clientId: id)   // wird NIE aufgerufen
    }
}
```

Konsequenz: Chat bleibt dauerhaft leer (zeigt `emptyConversations`), kein Fehler,
kein Spinner — weil `isLoadingConversations` nie `true` wird und `error` nil bleibt.

**Fix:** `onChange` als Fallback ergänzen, der feuert wenn `clientId` nachträglich gesetzt wird:
```swift
// ChatView.swift — body ergänzen:
.task {
    if let id = auth.clientId { await vm.fetchConversations(clientId: id) }
}
.onChange(of: auth.clientId) { _, newId in
    guard let id = newId, vm.conversations.isEmpty, !vm.isLoadingConversations else { return }
    Task { await vm.fetchConversations(clientId: id) }
}
```

Gleiche Korrektur in `ChatThreadView` für `fetchMessages`:
```swift
// ChatThreadView.swift — body ergänzen:
.task { await vm.fetchMessages(clientId: clientId, trainerId: conversation.trainerId) }
// (ChatThreadView bekommt clientId direkt übergeben, kein .onChange nötig — .task reicht)
// ABER: sicherstellen dass clientId nicht leer ist beim Aufruf
```

---

### Bug 2 — KRITISCH: `sendMessage` Return-Typ Mismatch (möglicher Compile-Fehler)

**Datei:** `ChatViewModel.swift` Zeile 50 vs. `ChatView.swift` Zeile ~303

**ViewModel:**
```swift
func sendMessage(clientId: String, trainerId: String, text: String) async {
    // → gibt Void zurück
}
```

**View:**
```swift
Task {
    let ok = await vm.sendMessage(...)   // ok: () (Void)
    if !ok { inputText = textToSend }    // ← COMPILE ERROR: '!' auf Void
}
```

`Void` (= `()`) unterstützt kein `!`-Operator → **Compile-Fehler**.

**Fix A** (einfacher): ViewModel gibt `Bool` zurück:
```swift
// ChatViewModel.swift:
@discardableResult
func sendMessage(clientId: String, trainerId: String, text: String) async -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return false }
    isSending = true
    defer { isSending = false }
    let optimistic = OptimisticMessage(id: UUID().uuidString, text: trimmed)
    messages.append(optimistic.asChatMessage)
    do {
        let sent = try await service.sendMessage(clientId: clientId, trainerId: trainerId, text: trimmed)
        if let idx = messages.firstIndex(where: { $0.id == optimistic.id }) {
            messages[idx] = sent
        }
        return true
    } catch {
        messages.removeAll { $0.id == optimistic.id }
        self.error = error.localizedDescription
        return false
    }
}
```

**Fix B** (alternativ, View-seitig): Void-Ergebnis ignorieren + Fehler über `vm.error` prüfen:
```swift
Task {
    await vm.sendMessage(clientId: clientId, trainerId: conversation.trainerId, text: textToSend)
    if vm.error != nil { inputText = textToSend }
}
```

→ **Fix A bevorzugen** (sauberer, keine Race Condition mit `vm.error`).

---

### Bug 3 — HOCH: ISO8601 mit Millisekunden nicht parsebar

**Datei:** `ChatMessage.swift` Zeile 3

**Problem:** NestJS/TypeORM sendet Timestamps mit Millisekunden:
```
"2024-03-15T14:30:00.000Z"   ← Standard NestJS-Format
```
`ISO8601DateFormatter()` ohne explizite `formatOptions` parst **kein** `.000` hinter den Sekunden.
Resultat: alle Datum-Felder fallen auf `Date()` (= jetzt) zurück — Nachrichten erscheinen
mit heutigem Datum, oder Array-Elemente werden als leer interpretiert.

**Fix:** `iso8601Fmt` auf Fractional Seconds erweitern (in `ChatMessage.swift`):
```swift
// ChatMessage.swift — Zeile 3, private let ersetzen:
private let iso8601Fmt: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
```

Dieser Fix gilt für **alle** Models in der Datei (ChatMessage, ChatConversation, TrainingReview,
PerformanceTest, BodyMetric), da alle `iso8601Fmt` aus demselben `private let` nutzen.

---

### Bug 4 — MITTEL: Fehler in Detail-Sheets unsichtbar (silent catch)

**Datei:** `ChatView.swift` — `ReviewDetailSheet`, `PerformanceDetailSheet`, `MetricsDetailSheet`

**Problem:** `.task {}` in den Detail-Sheets hat `catch {}` ohne Fehlerbehandlung:
```swift
.task {
    do {
        reviews = try await ChatService.shared.getReviews(clientId: clientId)
    } catch {
        // NICHTS — User sieht leeres Sheet, kein Fehlerhinweis
    }
    isLoading = false
}
```

**Fix:** `error`-State nutzen (der ist bereits als `@State var error: String?` deklariert,
wird aber nicht gesetzt):
```swift
.task {
    do {
        reviews = try await ChatService.shared.getReviews(clientId: clientId)
    } catch {
        self.error = error.localizedDescription   // ← ergänzen
    }
    isLoading = false
}
```

Gleiches für `PerformanceDetailSheet` und `MetricsDetailSheet`.

---

## Diagnose-Schritte (Agent führt aus)

### Schritt 1 — Compile-Check

```bash
cd /Users/piaclodimac.com/Admin-Backend-php/client-ios/SihlCient

xcodebuild -project SihlCient.xcodeproj -scheme SihlCient \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath /tmp/sihl-chat-debug \
  -configuration Debug build 2>&1 | grep -E "error:|warning:|BUILD"
```

**Erwartet:** Fehler bei `if !ok` (Bug 2) → bestätigt Compile-Fehler.

### Schritt 2 — API direkt testen (mit echtem Token)

Token aus der App holen (Keychain-Key: `auth_token`). Dann:

```bash
TOKEN="<token-hier-einsetzen>"
BASE="https://admin-backend-php-production.up.railway.app"

# Conversations
curl -s -H "X-Auth-Token: $TOKEN" \
  "$BASE/api/client/chat/<clientId>/conversations" | python3 -m json.tool | head -40

# Messages
curl -s -H "X-Auth-Token: $TOKEN" \
  "$BASE/api/client/chat/<clientId>/messages/<trainerId>" | python3 -m json.tool | head -40
```

**Was prüfen:**
- [ ] HTTP 200 oder Fehler? Falls 401 → Token falsch/abgelaufen
- [ ] Response-Format: `[{ "trainer_id": ..., "trainer_name": ..., "unread_count": ..., "last_message_at": "YYYY-MM-DDTHH:MM:SS.mmmZ" }]`
- [ ] Datum-Format: Hat es Millisekunden (`.000Z`)? → bestätigt Bug 3
- [ ] `trainer_id` als Int oder String?

### Schritt 3 — Temporäres Debug-Logging einfügen

In `ChatViewModel.fetchConversations` temporär `print()` ergänzen:
```swift
func fetchConversations(clientId: String) async {
    print("🔵 fetchConversations called with clientId='\(clientId)'")  // ← hinzufügen
    isLoadingConversations = true
    error = nil
    defer { isLoadingConversations = false }
    do {
        conversations = try await service.getConversations(clientId: clientId)
        print("✅ conversations loaded: \(conversations.count)")         // ← hinzufügen
    } catch {
        print("❌ fetchConversations error: \(error)")                   // ← hinzufügen
        self.error = error.localizedDescription
    }
}
```

App neu bauen + Gerät/Simulator-Konsole beobachten:
- Kein `🔵` → Bug 1 (Race Condition), `clientId` war nil beim task-Start
- `🔵` aber kein `✅` → Netzwerkfehler oder Decode-Fehler
- `❌` → Fehlertext zeigt die Ursache

### Schritt 4 — Fix-Reihenfolge

1. **Bug 2 zuerst** — Compile-Fehler beheben (ViewModel `sendMessage` → `Bool`)
2. **Bug 3** — `iso8601Fmt` mit `.withFractionalSeconds` in `ChatMessage.swift`
3. **Bug 1** — `.onChange(of: auth.clientId)` in `ChatView.body`
4. **Bug 4** — `catch { self.error = ... }` in den 3 Detail-Sheets
5. Neu bauen und testen

### Schritt 5 — Abschluss-Check nach Fixes

```bash
# Build nach Fixes:
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient \
  -destination 'platform=iOS,id=00008120-001A6CE83C81A01E' \
  -derivedDataPath /tmp/sihl-chat-fixed -allowProvisioningUpdates \
  build 2>&1 | grep -E "error:|BUILD"

# Installieren:
xcrun devicectl device install app \
  --device E2C5D08C-9F15-565A-92D7-842157B75723 \
  /tmp/sihl-chat-fixed/Build/Products/Debug-iphoneos/SihlCient.app

# Starten:
xcrun devicectl device process launch \
  --device E2C5D08C-9F15-565A-92D7-842157B75723 ch.sihltraining.SihlCient
```

**Abnahme-Kriterien:**
- [ ] Build ohne Fehler
- [ ] Chat-Tab öffnen → Gespräche laden (auch nach App-Neustart)
- [ ] Thread antippen → Nachrichten erscheinen mit korrekten Zeitstempeln
- [ ] Nachricht senden → erscheint, Text-Restore funktioniert bei Fehler
- [ ] Detail-Sheet-Fehler sind sichtbar (kein leeres Sheet ohne Hinweis)

---

## Zusammenfassung

| Bug | Schwere | Datei | Zeile | Fix |
|---|---|---|---|---|
| 1 — Race Condition `clientId` | Kritisch | `ChatView.swift` | ~23 | `.onChange` ergänzen |
| 2 — `sendMessage` Void vs Bool | Kritisch | `ChatViewModel.swift` | 50 | `async -> Bool` |
| 3 — ISO8601 ohne Millisekunden | Hoch | `ChatMessage.swift` | 3 | `formatOptions` setzen |
| 4 — Silent catch in Sheets | Mittel | `ChatView.swift` | ~651/792/840 | `self.error =` ergänzen |
