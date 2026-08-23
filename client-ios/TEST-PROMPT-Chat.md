# Test-Prompt: Chat-Funktion (iOS / SihlCient)

> **Zweck:** Agent-fertiges Prompt für den **finalen funktionalen Test** der Chat-Funktion.
> Der Agent baut die App, installiert sie auf dem Gerät oder Simulator, navigiert zum
> Chat-Tab und arbeitet alle Test-Szenarien ab. Übergib dieses Dokument 1:1 an einen
> Agenten mit Ausführungs-Tools (Bash + Gerät/Simulator).

---

## 1. Auftrag an den Agenten

Du bist ein iOS-QA-Tester. **Teste die Chat-Funktion** der SihlCient-App End-to-End.
Baue & installiere die App, navigiere zum Chat-Tab und führe **jedes Szenario unten**
aus. Belege jeden Schritt mit einem **Screenshot** und einem **Pass/Fail**-Urteil.
Erfinde keine Ergebnisse — wenn ein Schritt nicht ausführbar ist (z.B. keine Daten),
notiere das als `blockiert` mit Grund. Halte dich strikt an die erwarteten Ergebnisse.
Wenn ein Verdacht-Punkt explizit markiert ist, teste ihn besonders sorgfältig.

## 2. App starten

### Option A — Physisches Gerät (iPhone 15, iOS 18.7.3)

```bash
cd /Users/piaclodimac.com/Admin-Backend-php/client-ios/SihlCient

# Build
xcodebuild \
  -project SihlCient.xcodeproj \
  -scheme SihlCient \
  -configuration Debug \
  -destination 'platform=iOS,id=00008120-001A6CE83C81A01E' \
  -derivedDataPath /tmp/sihl-chat-test \
  -allowProvisioningUpdates \
  build | tail -5

# Installieren
xcrun devicectl device install app \
  --device E2C5D08C-9F15-565A-92D7-842157B75723 \
  /tmp/sihl-chat-test/Build/Products/Debug-iphoneos/SihlCient.app

# Starten
xcrun devicectl device process launch \
  --device E2C5D08C-9F15-565A-92D7-842157B75723 \
  ch.sihltraining.SihlCient
```

### Option B — Simulator (iPhone 17, iOS 26.5)

```bash
cd /Users/piaclodimac.com/Admin-Backend-php/client-ios/SihlCient
DEV=E8C0D5B9-2CB3-45C6-9820-3DA8AE345236

xcodebuild \
  -project SihlCient.xcodeproj \
  -scheme SihlCient \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath /tmp/sihl-chat-test \
  -configuration Debug build | tail -5

xcrun simctl boot "$DEV" 2>/dev/null; open -a Simulator
APP=$(find /tmp/sihl-chat-test/Build/Products/Debug-iphonesimulator -name 'SihlCient.app' | head -1)
xcrun simctl install "$DEV" "$APP"
xcrun simctl launch "$DEV" ch.sihltraining.SihlCient

# Screenshot-Befehl (Simulator):
# xcrun simctl io "$DEV" screenshot /tmp/chat_<schritt>.png
```

**Navigation:** Login (falls nötig) → unterer Tab **„Chat"** (Icon `bubble.left.and.bubble.right`).
**Backend:** Railway (`admin-backend-php-production.up.railway.app`) — echter Client-Account
mit mindestens einem Trainer-Gespräch nötig.

---

## 3. Test-Szenarien

### S1 — Conversation-Liste

| # | Schritt | Erwartet |
|---|---|---|
| S1.1 | Chat-Tab öffnen, sofort beobachten | Ladezustand: Spinner oder Skeleton |
| S1.2 | Warten bis geladen | Liste der Gespräche: Trainer-Avatar (Initialen), Name, letzte Nachricht, Zeitstempel |
| S1.3 | Ungelesene Nachrichten vorhanden | Rotes Badge mit Zahl auf dem Conversation-Tile |
| S1.4 | Unread-Count im Tab-Bar | Zahl auf dem Chat-Tab-Icon stimmt mit Summe aller Gespräche überein |
| S1.5 | Pull-to-refresh in der Liste | Refresh läuft, Gespräche aktualisieren sich, kein Absturz |
| S1.6 | Kein Gespräch vorhanden | Empty-State: Icon + erläuternder Text, kein Crash |
| S1.7 | Netzwerk trennen, Tab öffnen | Fehlermeldung sichtbar (kein leeres Schweigen, kein Crash) |

### S2 — Thread öffnen & Nachrichten anzeigen

| # | Schritt | Erwartet |
|---|---|---|
| S2.1 | Gespräch antippen | Thread öffnet, Nachrichten laden, Spinner sichtbar |
| S2.2 | Nach dem Laden | Scroll automatisch zur **letzten** Nachricht |
| S2.3 | Eigene Nachrichten | Rechte Seite, Primary-Farbe (`AppColor.primary`) |
| S2.4 | Trainer-Nachrichten | Linke Seite, Surface-Farbe, Trainer-Avatar (Initialen-Kreis) |
| S2.5 | Unread-Badge nach Thread-Öffnen | Badge auf dem Tile zurück auf 0 gesetzt |
| S2.6 | Pull-to-refresh im Thread | Nachrichten neu geladen, Scroll-Position bleibt unten |
| S2.7 | Tages-Trennlinie | Nachrichten verschiedener Tage durch Datums-Label getrennt |

### S3 — Nachricht senden

| # | Schritt | Erwartet |
|---|---|---|
| S3.1 | Text eingeben | Eingabefeld wächst bei mehrzeiligem Text (axis: .vertical) |
| S3.2 | Senden-Button tippen | Nachricht erscheint **sofort** als Blase (optimistisch, rechts) |
| S3.3 | Erfolgreiche Übertragung | Nachricht bleibt mit echter ID (keine sichtbare Änderung) |
| S3.4 | Eingabefeld nach dem Senden | Feld geleert, Cursor bereit für neue Eingabe |
| S3.5 | Leeren Text senden | Kein Senden (Guard im ViewModel, Button inaktiv oder keine Reaktion) |
| S3.6 | Nur Leerzeichen senden | Kein Senden (`trimmingCharacters` im ViewModel greift) |
| S3.7 | **Verdacht — Netzwerkfehler beim Senden:** Netz trennen, Text senden | Optimistische Nachricht verschwindet + Fehlermeldung. **KRITISCH prüfen: Ist der eingetippte Text noch im Eingabefeld?** (Verdacht: Text geht verloren, da `inputText` VOR dem Send geleert wird) |
| S3.8 | Mehrfach schnell senden | Keine Duplikate (isSending-Guard aktiv) |

### S4 — Anhang-Flow (Paperclip)

| # | Schritt | Erwartet |
|---|---|---|
| S4.1 | Paperclip-Button antippen | `AttachPickerSheet` erscheint als Bottom-Sheet |
| S4.2 | Sheet zeigt 3 Zeilen | „Aufzeichnung", „Leistungstest", „Körpermessung" je mit Icon |
| S4.3 | „Aufzeichnung" antippen | `ReviewDetailSheet` öffnet sich |
| S4.4 | „Leistungstest" antippen | `PerformanceDetailSheet` öffnet sich |
| S4.5 | „Körpermessung" antippen | `MetricsDetailSheet` öffnet sich |
| S4.6 | Sheet schließen (Swipe down / X) | Schließt sauber, kein Crash |

### S5 — Daten-Karten (vom Trainer gesendete Nachrichten)

| # | Schritt | Erwartet |
|---|---|---|
| S5.1 | `[Aufzeichnung]`-Karte im Thread | Dargestellt als Daten-Karte mit Icon, Label, Chevron — nicht als normaler Text |
| S5.2 | `[Performance]`-Karte | Eigene Karte mit passendem Icon |
| S5.3 | `[Messwerte]`-Karte | Eigene Karte mit passendem Icon |
| S5.4 | `[TRAINING_REPORT]`-Karte | Eigene Karte (prüfen welches Sheet öffnet) |
| S5.5 | Aufzeichnung-Karte antippen | `ReviewDetailSheet` öffnet sich |
| S5.6 | Performance-Karte antippen | `PerformanceDetailSheet` öffnet sich |
| S5.7 | Messwerte-Karte antippen | `MetricsDetailSheet` öffnet sich |
| S5.8 | Unbekannter Präfix | Als normale Text-Blase dargestellt, kein Crash |

### S6 — Detail-Sheets (Reviews / Performance / Metriken)

| # | Schritt | Erwartet |
|---|---|---|
| S6.1 | Sheet öffnen mit Daten | Liste lädt, Inhalte sichtbar (Trainings-Reviews / Tests / Messwerte) |
| S6.2 | Sheet öffnen ohne Daten | Empty-State oder Leer-Liste — **kein** stummes leeres Sheet |
| S6.3 | **Verdacht — Ladefehler:** Netz trennen, Sheet öffnen | Fehlermeldung sichtbar? (`catch {}` ist silent — Verdacht auf stillen Fehler) |
| S6.4 | Teilen-Button in ReviewDetailSheet | Schickt Nachricht mit `[Aufzeichnung]`-Tag an Trainer |
| S6.5 | Teilen-Button in PerformanceDetailSheet | Schickt Nachricht mit `[Performance]`-Tag |
| S6.6 | Teilen-Button in MetricsDetailSheet | Schickt Nachricht mit `[Messwerte]`-Tag |
| S6.7 | Nach Teilen | Sheet schließt, neue Daten-Karte erscheint im Thread |
| S6.8 | Sheet schließen ohne Teilen | Kein unerwünschtes Senden, sauberes Schließen |

### S7 — CircleGroupBubble (Zirkel-Training)

| # | Schritt | Erwartet |
|---|---|---|
| S7.1 | Aufeinanderfolgende Circle-Nachrichten | Zu `CircleGroupBubble` zusammengefasst, nicht als Einzelblasen |
| S7.2 | Kompakte Ansicht | `IntensityWheel` Ring-Chart sichtbar, Durchschnitt + Max angezeigt |
| S7.3 | Expand-Button antippen | Vollständiges Übungs-Grid klappt auf |
| S7.4 | Collapse antippen | Kompakte Ansicht kehrt zurück |
| S7.5 | Nachrichten neu laden (Pull-to-refresh) | Expand-State zurückgesetzt → kompakte Ansicht (erwartet, notieren) |

### S8 — Robustheit / Edge Cases

- [ ] Sehr langer Trainer-Name → Truncation in `ConversationTile`, kein Layout-Bruch
- [ ] Unread-Count > 99 → Badge zeigt „99+" oder passt sich an (kein Overflow)
- [ ] Schneller Tab-Wechsel Chat ↔ anderer Tab → kein Hänger, kein Doppel-Laden
- [ ] Hintergrund → Vordergrund nach Netz-Unterbrechung → keine Endlos-Spinner
- [ ] Sehr viele Nachrichten (100+) → Thread scrollt flüssig (LazyVStack)
- [ ] Zeitstempel-Format — Heute: „14:35", Gestern/Diese Woche: Wochentag, Älter: Datum
- [ ] Dark Mode → Alle Farben lesbar, Bubbles kontrastreich (App ist Dark-First)
- [ ] Dynamic Type (groß) → Bubbles skalieren, kein Text-Clipping

---

## 4. Ausgabeformat

Pro Szenario:

```
S3.7 Text-Verlust bei Send-Fehler — PASS / FAIL / BLOCKIERT
  Beobachtet: <was passiert ist>
  Screenshot: /tmp/chat_s3_7.png
  Abweichung (falls FAIL): <erwartet vs. tatsächlich>
```

Abschluss:

- **Übersicht:** PASS / FAIL / BLOCKIERT je Szenario-Gruppe (Tabelle)
- **Gefundene Bugs:** priorisiert (Blocker → Niedrig), je mit Repro-Schritten + Screenshot
- **Top-3 zuerst beheben**

---

## 5. Bekannte Verdachts-Punkte (besondere Aufmerksamkeit)

| Prio | Szenario | Verdacht |
|---|---|---|
| **Kritisch** | S3.7 | `inputText` wird VOR dem async Send geleert — Text geht bei Fehler verloren |
| **Hoch** | S6.3 | `catch {}` in Detail-Sheets ist silent — Ladefehler unsichtbar für den User |
| **Mittel** | S5.1–S5.4 | Backend-Präfixe müssen exakt stimmen (`[Aufzeichnung]` etc.) — Groß-/Kleinschreibung prüfen |
| **Niedrig** | S7.5 | CircleGroup-Expand-State nach Refresh — bewusstes Design oder Bug? |

> Hinweis: Reines UI-Verhalten testen, nichts am Code ändern. Für Code-Befunde und
> Fix-Vorschläge siehe separates Dokument `QUALITY-CHECK-Chat.md`.
