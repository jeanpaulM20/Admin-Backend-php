# Test-Prompt: Analytics-Seite (iOS / SihlCient)

> **Zweck:** Agent-fertiges Prompt für den **funktionalen Test** der Analytics-Seite.
> Der Agent baut die App, startet sie (Simulator oder Gerät), navigiert zur Analytics-
> Seite und arbeitet die Test-Szenarien ab. Übergib dieses Dokument 1:1 an einen Agenten
> mit Ausführungs-Tools (Bash + Simulator/Preview).

---

## 1. Auftrag an den Agenten

Du bist ein iOS-QA-Tester. **Teste die Analytics-Seite** der SihlCient-App End-to-End.
Baue & starte die App, navigiere zur Analytics-Seite und führe **jedes Szenario unten**
aus. Belege jeden Schritt mit einem **Screenshot** und einem **Pass/Fail**-Urteil.
Erfinde keine Ergebnisse — wenn ein Schritt nicht ausführbar ist (z.B. keine Daten),
notiere das als `blockiert` mit Grund. Halte dich strikt an die erwarteten Ergebnisse.

## 2. App starten

```bash
cd client-ios/SihlCient
# Build für Simulator
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build

# Boot + Install + Launch (iPhone 17 Sim)
DEV=E8C0D5B9-2CB3-45C6-9820-3DA8AE345236
xcrun simctl boot "$DEV" 2>/dev/null; open -a Simulator
APP=$(find ~/Library/Developer/Xcode/DerivedData/SihlCient-*/Build/Products/Debug-iphonesimulator -name 'SihlCient.app' | head -1)
xcrun simctl install "$DEV" "$APP"
xcrun simctl launch "$DEV" ch.sihltraining.SihlCient
# Screenshot:  xcrun simctl io "$DEV" screenshot /tmp/analytics_<schritt>.png
```

Navigation: Login (falls nötig) → unterer Tab **„Analytics"** (Icon `chart.line.uptrend.xyaxis`).
Backend: Railway (`admin-backend-php-production.up.railway.app`) — echter Client-Account nötig,
damit Leistungsdaten/Reviews vorhanden sind.

---

## 3. Test-Szenarien

### S1 — Zustände der Wurzelansicht
| # | Schritt | Erwartet |
|---|---|---|
| S1.1 | Analytics-Tab öffnen, sofort beobachten | Ladezustand: Spinner + „Lade Leistungsdaten…" |
| S1.2 | Warten bis geladen | Liste aus Sektions-Kacheln + ggf. „Herzfrequenz"-Kachel; unten dünne Abschlusslinie |
| S1.3 | Account/Endpoint ohne Daten testen | Empty-State: Icon + „Keine Leistungsdaten" + „Noch keine Leistungstests erfasst." |
| S1.4 | Netzwerk trennen, Tab öffnen | Fehler-State: Warn-Icon + Fehlertext + Button **„Erneut versuchen"** |
| S1.5 | Bei Fehler „Erneut versuchen" tippen (Netz wieder an) | Lädt neu, zeigt Daten |
| S1.6 | In Datenliste nach unten ziehen (Pull-to-Refresh) | Refresh läuft, Daten aktualisieren sich, kein Absturz |

### S2 — Performance-Sektionen (PerformanceSectionTile)
| # | Schritt | Erwartet |
|---|---|---|
| S2.1 | Sektions-Header antippen | Klappt auf (Chevron ▼→▲), Messwert-Zeilen erscheinen animiert |
| S2.2 | Icon je Sektion prüfen | Körper=Waage, Kraft=Blitz, Koordination=Läufer, Ausdauer=Herz, Mobilität=Flex, sonst Balken |
| S2.3 | Zähler im Header | „N Messwert/e" stimmt mit Anzahl Zeilen (Singular/Plural korrekt) |
| S2.4 | Zeilen-Striping | abwechselnde Hintergründe, letzte Zeile ohne Trennlinie |
| S2.5 | Change-Indikator | „+" → grüner Pfeil/Text, „-" → roter, „0"/leer → nichts. **Farbe und Pfeilrichtung müssen übereinstimmen** (Verdacht: `"increase"`/`"decrease"` evtl. inkonsistent) |
| S2.6 | Messwert-Zeile antippen | Navigation zu **PerformanceDetailView** |

### S3 — Performance-Detail (PerformanceDetailView)
| # | Schritt | Erwartet |
|---|---|---|
| S3.1 | Kopf-Karte | „Aktueller Wert", „Vorher", Change-Badge (Farbe passend) |
| S3.2 | Mit Verlauf | Linien-Chart (Verlauf) + Tabelle „Messwerte" (neueste zuerst) |
| S3.3 | Y-Achse bei konstanten Werten | Chart kollabiert nicht (Domain ±5 um den Wert) |
| S3.4 | Ohne Verlauf | „Kein Verlauf vorhanden"-Karte statt Chart |
| S3.5 | Datums-/Wert-Format | Datum `dd.MM.yyyy` (de), Ganzzahl ohne Nachkomma, sonst 1 Dezimal + Einheit; **Datum darf NICHT fälschlich „heute" sein** (Verdacht ISO8601-Fallback) |
| S3.6 | Zurück-Navigation | kehrt sauber zur Liste zurück, Sektion bleibt offen? (Verhalten dokumentieren) |

### S4 — Herzfrequenz / Reviews (ReviewSectionTile)
| # | Schritt | Erwartet |
|---|---|---|
| S4.1 | „Herzfrequenz"-Header aufklappen | Review-Zeilen mit Trainingstyp, Datum, „… bpm" (Max) |
| S4.2 | Review-Zeile antippen (normal) | Navigation zu **TrainingReviewDetailView** |
| S4.3 | Detail: Stat-Karten | Max/Avg HF, Load (TRIMP) mit Ampelfarbe + Rating; HRR/HRV nur wenn vorhanden |
| S4.4 | Detail: HR-Chart | Kurve sichtbar wenn ≥2 Punkte, sonst „Keine HF-Kurvendaten vorhanden" |
| S4.5 | Detail: Vollbild-Button (↗) | öffnet Fullscreen-Sheet, X schließt wieder |

### S5 — Vergleichsmodus (kritischster Flow)
| # | Schritt | Erwartet |
|---|---|---|
| S5.1 | „Vergleichen"-Toggle sichtbar? | nur wenn ≥2 vergleichbare Reviews (Charts mit ≥2 Punkten) |
| S5.2 | „Vergleichen" tippen | Compare-Mode an: Banner „Mindestens 2, max. 4 wählen", Checkboxen, Rahmen wird primärfarben |
| S5.3 | Zeilen ohne Chart | sind **disabled/ausgegraut**, nicht wählbar |
| S5.4 | 2–4 Reviews auswählen | Banner zählt „n / 4 ausgewählt", ab 2 erscheint „Vergleichen"-Button |
| S5.5 | 5. Auswahl versuchen | wird verhindert (max. 4) |
| S5.6 | **Auswahl + Pull-to-Refresh / Datenwechsel** | **Verdacht:** index-basierte Auswahl (`Set<Int>`) könnte nach Reorder auf falsche Reviews zeigen → genau prüfen |
| S5.7 | „Vergleichen" tippen | **TrainingCompareView**: Legende, normiertes Overlay-Chart (0–100%), Stats-Tabelle (Max/Avg/TRIMP) |
| S5.8 | „Abbrechen" im Compare-Mode | Auswahl wird geleert, normaler Modus zurück |

### S6 — Robustheit / Edge Cases
- [ ] Sehr lange Trainingsnamen → Truncation statt Layout-Bruch
- [ ] Sektion mit genau 1 Messwert → „1 Messwert" (Singular)
- [ ] Reviews ohne `hrMax`/`hrAvg` → „–" statt Crash
- [ ] Schneller Doppel-Tap auf Header / schnelles Tab-Wechseln → keine Doppel-Navigation, kein Hänger
- [ ] Dark Mode (App ist dark by default) → Kontraste lesbar
- [ ] Dynamic Type groß (Einstellungen) → prüfen ob Layout skaliert (Verdacht: feste `.system(size:)`)
- [ ] VoiceOver an → Icon-Buttons (Vergleichen/Fullscreen/X) und Charts vorlesbar?

---

## 4. Ausgabeformat

Pro Szenario:
```
S2.5 Change-Indikator — PASS / FAIL / BLOCKIERT
  Beobachtet: <was passiert ist>
  Screenshot: /tmp/analytics_s2_5.png
  Abweichung (falls FAIL): <erwartet vs. tatsächlich>
```

Abschluss:
- **Übersicht:** PASS/FAIL/BLOCKIERT je Szenario-Gruppe (Tabelle)
- **Gefundene Bugs:** priorisiert (blocker → niedrig), je mit Repro-Schritten + Screenshot
- **Top-3 zuerst beheben**

> Hinweis: Reines UI-Verhalten testen, nichts am Code ändern. Für Code-Befunde siehe
> separates Dokument `QUALITY-CHECK-Analytics.md`.
