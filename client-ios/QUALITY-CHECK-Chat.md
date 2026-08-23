# QUALITY-CHECK — Chat-Funktion (Analyse & Test)

Analysiere und teste die komplette Chat-Funktion der SihlCient SwiftUI-App.
Ziel: Bugs finden, Code-Qualität bewerten, alle User-Flows manuell testen.

---

## Betroffene Dateien

| Datei | Zweck |
|---|---|
| `SihlClient/Views/ChatView.swift` | UI (848 Zeilen) — alle Komponenten |
| `SihlClient/ViewModels/ChatViewModel.swift` | State + Logik |
| `SihlClient/Services/ChatService.swift` | API-Aufrufe |

---

## Schritt 1 — Code-Analyse

### 1a) ChatViewModel.swift lesen und prüfen:

**Bekannte Risiken überprüfen:**

1. **Optimistic Send + Input-Clearing (kritischer Bug):**
   Im `inputBar` der `ChatThreadView` wird `inputText` **vor** dem `Task { await vm.sendMessage(...) }` geleert.
   Im ViewModel löscht `sendMessage` bei einem Fehler die optimistische Nachricht und setzt `self.error`.
   **Problem:** Der Originaltext ist bereits weg — der User kann die Nachricht nicht erneut senden.
   → Prüfen ob `inputText` erst nach erfolgreichem Send geleert wird.

2. **Unread-Count nur lokal gelöscht:**
   In `fetchMessages` wird `conversations[idx].unreadCount = 0` lokal gesetzt, aber nicht neu vom Server geholt.
   → Sicherstellen, dass ein Pull-to-refresh die echten Zahlen zurückholt.

3. **`markAsRead` mit `try?`:**
   Silent failure ist OK (non-critical). Trotzdem notieren.

4. **Kein Retry-Mechanismus:**
   `error` wird als String gesetzt, aber es gibt keine UI-Retry-Schaltfläche.
   → Prüfen wie `vm.error` in `ChatView` und `ChatThreadView` angezeigt wird.

### 1b) ChatView.swift lesen und prüfen:

5. **Silent `catch {}` in Detail-Sheets:**
   `ReviewDetailSheet`, `PerformanceDetailSheet`, `MetricsDetailSheet` fangen Fehler ohne Anzeige.
   → Leere Listen ohne Fehlermeldung sind für den User verwirrend.
   → Entweder `self.error = error.localizedDescription` oder minimaler Fehlerhinweis.

6. **Data-Card-Prefix-Routing:**
   `MessageBubble.dataCardAction()` routet anhand exakter String-Präfixe:
   - `[Aufzeichnung]` → `ReviewDetailSheet`
   - `[Performance]` → `PerformanceDetailSheet`
   - `[Messwerte]` → `MetricsDetailSheet`
   - `[TRAINING_REPORT]` → (prüfen welches Sheet)
   → Prüfen: Was passiert wenn der Backend-String leicht abweicht? (z.B. Leerzeichen, Großschreibung)

7. **`CircleGroupBubble` Expand-State:**
   `@State private var expanded = false` ist lokal je Bubble.
   → Bei `fetchMessages` wird die Liste neu ersetzt — alle Bubble-States werden zurückgesetzt.
   → Verhalten prüfen: Ist das erwünscht?

8. **Auto-Scroll bei neuer Nachricht:**
   `ScrollViewReader` + `.onChange(of: vm.messages)` muss auf die letzte Message-ID scrollen.
   → Sicherstellen dass die ID auf dem letzten Element gesetzt ist und nicht auf einem Platzhalter.

9. **`AttachPickerSheet` — kein Loading/Error-State:**
   Sheet öffnet sich sofort, aber die Daten werden erst im Detail-Sheet geladen.
   → Das ist UX-üblich, aber sicherstellen dass leere Detail-Sheets nicht leer+stumm bleiben.

10. **`ConversationTile` Unread-Badge:**
    Badge zeigt `conversation.unreadCount`. Prüfen: Was wenn count > 99?

---

## Schritt 2 — API-Endpoints verifizieren

Basis-URL: `https://admin-backend-php-production.up.railway.app/`
Auth-Header: `X-Auth-Token: <token>`
Client-ID aus `AuthViewModel.clientId`

Folgende Endpunkte testen (mit echten Credentials):

```
GET  api/client/chat/{clientId}/conversations
GET  api/client/chat/{clientId}/messages/{trainerId}
POST api/client/chat/{clientId}/messages/{trainerId}   body: {"text": "Test"}
POST api/client/chat/{clientId}/messages/{trainerId}/read
GET  api/client/reviews/{clientId}
GET  api/client/tests/{clientId}
GET  api/client/profile/{clientId}
```

**Prüfen:**
- Response-Schema stimmt mit `ChatConversation`, `ChatMessage`, `TrainingReview`, `PerformanceTest`, `BodyMetric` überein?
- `ChatMessage.isCircle` — wann ist dieser Wert `true`?
- `ChatMessage.senderType` — welche Werte? (`"client"`, `"trainer"`, andere?)
- Welche exakten Präfixe sendet der Trainer für Daten-Karten? (`[Aufzeichnung]`, `[Performance]` etc.)

---

## Schritt 3 — Manueller Test-Plan (auf Gerät / Simulator)

### A — Conversation-Liste

| # | Szenario | Erwartet | OK? |
|---|---|---|---|
| A1 | App starten, Chat-Tab öffnen | Gespräche laden, Spinner dann Liste | |
| A2 | Kein Gespräch vorhanden | Empty-State View sichtbar | |
| A3 | Gespräche vorhanden | Trainer-Name, letzte Nachricht, Zeitstempel | |
| A4 | Ungelesene Nachrichten | Rotes Badge mit Zahl auf Conversation-Tile | |
| A5 | Pull-to-refresh | Liste neu laden, Unread-Counts aktuell | |
| A6 | Netzwerkfehler beim Laden | Fehlermeldung sichtbar (kein Crash) | |

### B — Thread / Nachrichten

| # | Szenario | Erwartet | OK? |
|---|---|---|---|
| B1 | Gespräch antippen | Thread öffnet, Nachrichten laden | |
| B2 | Thread öffnet | Scroll automatisch zur letzten Nachricht | |
| B3 | Unread-Badge nach Thread-Öffnen | Badge auf 0 gesetzt | |
| B4 | Pull-to-refresh im Thread | Nachrichten neu geladen | |
| B5 | Text eingeben & senden | Nachricht erscheint sofort (optimistisch) | |
| B6 | Nach erfolg. Send | Nachricht bleibt mit echter ID | |
| B7 | Leeren Text senden | Kein Senden (Guard in ViewModel) | |
| B8 | Netzwerkfehler beim Senden | Optimistische Nachricht verschwindet, Fehler sichtbar | |
| B9 | **BUG-Check:** Text nach Fehler | inputText bereits geleert → Text verloren? | |
| B10 | Langer Text | Eingabefeld wächst (axis: .vertical) | |
| B11 | Eigene Nachricht | Rechte Seite, Primary-Farbe | |
| B12 | Trainer-Nachricht | Linke Seite, Surface-Farbe, Avatar | |

### C — Daten-Karten (vom Trainer gesendete Daten)

| # | Szenario | Erwartet | OK? |
|---|---|---|---|
| C1 | Aufzeichnung-Karte antippen | ReviewDetailSheet öffnet sich | |
| C2 | Performance-Karte antippen | PerformanceDetailSheet öffnet sich | |
| C3 | Messwerte-Karte antippen | MetricsDetailSheet öffnet sich | |
| C4 | Detail-Sheet: Daten laden | Liste mit Reviews / Tests / Metriken | |
| C5 | Detail-Sheet: leer | Leere Liste ODER Hinweistext — kein Crash | |
| C6 | Detail-Sheet: Fehler | **BUG-Check:** silent `catch {}` — kein Fehlerhinweis? | |
| C7 | Teilen-Button im Sheet | Nachricht mit Daten-Tag an Trainer gesendet | |
| C8 | Nach Teilen | Detail-Sheet schließt, neue Nachricht im Thread | |

### D — Anhang-Flow (Paperclip)

| # | Szenario | Erwartet | OK? |
|---|---|---|---|
| D1 | Paperclip-Button antippen | AttachPickerSheet erscheint | |
| D2 | „Aufzeichnung" antippen | ReviewDetailSheet öffnet | |
| D3 | „Leistungstest" antippen | PerformanceDetailSheet öffnet | |
| D4 | „Körpermessung" antippen | MetricsDetailSheet öffnet | |
| D5 | Sheet ohne Daten | Kein Crash, Leer-State sichtbar | |

### E — CircleGroupBubble (Zirkel-Training)

| # | Szenario | Erwartet | OK? |
|---|---|---|---|
| E1 | Aufeinanderfolgende Circle-Nachrichten | Zu `CircleGroupBubble` gruppiert | |
| E2 | IntensityWheel | Ring-Chart mit Durchschnitt / Max | |
| E3 | Expand antippen | Vollständiges Grid sichtbar | |
| E4 | Collapse antippen | Kompakte Ansicht zurück | |
| E5 | Nachrichten neu laden | Expand-State zurückgesetzt (erwartet) | |

### F — Edge Cases

| # | Szenario | Erwartet | OK? |
|---|---|---|---|
| F1 | Sehr langer Trainer-Name | Truncation in ConversationTile | |
| F2 | Unread > 99 | Badge zeigt „99+" oder passt sich an | |
| F3 | Offline starten | Fehlermeldung, kein Crash | |
| F4 | Offline nach Gespräch öffnen | Bestehende Nachrichten sichtbar? | |
| F5 | Schnell senden (mehrfach tippen) | Keine Duplikate, isSending guard | |
| F6 | Hintergrund → Vordergrund | Neue Nachrichten erscheinen nach Refresh | |

---

## Schritt 4 — Befunde dokumentieren

Für jeden gefundenen Bug:

```
## Bug #N — [Titel]

**Datei:** ChatView.swift / ChatViewModel.swift / ChatService.swift
**Zeile:** ~xxx
**Schwere:** Kritisch / Hoch / Mittel / Niedrig
**Reproduktion:** [Schritte]
**Ist-Verhalten:** [Was passiert]
**Soll-Verhalten:** [Was erwartet wird]
**Fix-Vorschlag:** [Konkreter Code-Vorschlag]
```

---

## Schritt 5 — Priorisierter Fix-Plan

Nach der Analyse: Fixes nach Priorität sortieren.

**Erwartete kritische Punkte (aus Vorab-Analyse):**

1. **[KRITISCH] Input-Text-Verlust bei Send-Fehler**
   → In `ChatThreadView.inputBar`: `inputText` erst nach `vm.sendMessage` leeren, ODER im ViewModel bei Fehler den Text zurückgeben.
   ```swift
   // Aktuell (problematisch):
   Task { await vm.sendMessage(...) }
   inputText = ""   // zu früh
   
   // Fix:
   let textToSend = inputText
   inputText = ""
   Task {
       let success = await vm.sendMessage(clientId: id, trainerId: tid, text: textToSend)
       if !success { inputText = textToSend }  // Text wiederherstellen
   }
   ```

2. **[HOCH] Silent catch {} in Detail-Sheets**
   → Mindestens: `self.errorMessage = error.localizedDescription` + Text-Label im Sheet.

3. **[MITTEL] Unread-Count nach Server-Neustart**
   → Pull-to-refresh auf Conversation-Liste ruft `fetchConversations` erneut auf → OK, aber sicherstellen dass dies immer den echten Count liefert.

4. **[NIEDRIG] CircleGroupBubble State-Reset bei Refresh**
   → Kann accepted werden (Workaround: State in ViewModel halten).

---

## Context für den Agent

**Architektur:**
- `@Observable` ViewModels, `@Environment` injection
- `@MainActor` in ViewModel
- `APIClient.shared.get/post` für alle HTTP-Calls
- Auth: `X-Auth-Token` Header (gesetzt in `APIClient`)
- Backend: Railway NestJS, `https://admin-backend-php-production.up.railway.app/`

**Naming-Konvention:**
- `senderType == "client"` → eigene Nachricht (rechts, Primary)
- `senderType == "trainer"` → Trainer (links, Surface)
- `isCircle == true` → wird zu `CircleGroupBubble` gebündelt

**Deutsche UI-Texte** beibehalten (Aufzeichnung, Leistungstest, Körpermessung).
