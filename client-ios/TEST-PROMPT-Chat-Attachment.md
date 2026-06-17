# TEST-PROMPT — Chat Anhang-Darstellung (visueller Vergleich mit Flutter)

> **Zweck:** Finaler Abnahme-Test der Chat-Anhang-Funktion gegen die Flutter-Vorlage.
> Der Agent vergleicht die SwiftUI-App Element für Element mit dem Flutter-Screenshot.
> Übergib dieses Dokument 1:1 an einen Agenten mit Ausführungs-Tools.

---

## 1. Visuelle Referenz (Flutter — Soll-Zustand)

Der Screenshot des Flutter-Apps zeigt **3 Bereiche**, die 1:1 nachgebaut werden müssen:

### Bereich A — Daten-Karte im Thread

```
┌─────────────────────────────────────────┐
│  [Icon]  1 (27.11.2013)                 │
│          Dauer: 00:07:31 | HR: 60 bpm   │
│          ☞ Antippen fuer Details        │
│                                   22:42 │
└─────────────────────────────────────────┘
```

- Hintergrund: **olivgrün** (wie eigene Nachrichten — `AppColor.primary`)
- Icon: Herzfrequenz-Monitor-Symbol, **rot**, in kleiner roter Box
- Titel fett: „1 (27.11.2013)" — enthält den trainingType + Datum in Klammern
- Untertitel: „Dauer: 00:07:31 | HR: 60 bpm"
- Hinweiszeile: „☞ Antippen fuer Details" (Hand-Icon + Text in gedämpfter Farbe)
- Zeitstempel unten rechts

### Bereich B — „6 Trainingseinheiten"-Karte (TRAINING_REPORT)

```
┌──────────────────────────────────────┐
│  [🏃] 6 Trainingseinheiten       ›  │
└──────────────────────────────────────┘
```

- Surface-Hintergrund (wie Trainer-Nachrichten)
- Laufender-Figur-Icon links, Text, Chevron rechts
- Antippen → öffnet Report-Detail

### Bereich C — ReviewDetailSheet (bei Antippen der Daten-Karte)

```
┌─────────────────────────────────────────┐
│  [❤️]  1               ❤ 60 bpm        │
│        27.11.2013                        │
├────────────────────┬────────────────────┤
│  ⏱ 00:07:31       │  ↗ 32              │
│    Dauer           │    Load · Leicht    │
├────────────────────┴────────────────────┤
│  ❤️ Herzfrequenz         Min 53 / Max 70 │
│                                         │
│  80 ┤                                   │
│     │  ╭─╮   ╭─╮  ╭──╮    ╭──╮        │
│  60 ┤╭╯  ╰──╯  ╰──╯  ╰────╯  ╰──      │
│     │ - - - - - - - Max - - - - - -    │
│  43 ┤                                   │
│                                         │
│  ● Maximal (63+)   ● Intensiv (56+)    │
│  ● Moderat (49+)   ● Leicht (42+)      │
│  ● Sehr Leicht (35+)                   │
└─────────────────────────────────────────┘
```

- Roter Icon-Header + Trainings-Name + Datum + avg HR rechts
- **2 Stat-Karten** nebeneinander: Dauer (blau) + Load mit Rating (grün)
- TRIMP-Rating-Farben: Leicht=grün, Moderat=gelb, Mittel=orange, Hart=orange-rot, Sehr Hart/Extrem=rot
- **HR-Linien-Chart** mit Verlauf, Füll-Gradient in rot/salmon
- Gestrichelte rote Linie bei Max-HR
- **Zonen-Legende** unten: 5 Zonen mit bpm-Schwellwerten (= 90%, 80%, 70%, 60%, 50% von HRmax)

---

## 2. App starten

```bash
cd /Users/piaclodimac.com/Admin-Backend-php/client-ios/SihlCient

# Option A — Gerät (iPhone 15)
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -configuration Debug \
  -destination 'platform=iOS,id=00008120-001A6CE83C81A01E' \
  -derivedDataPath /tmp/sihl-attach-test -allowProvisioningUpdates \
  build 2>&1 | grep -E "error:|BUILD"

xcrun devicectl device install app \
  --device E2C5D08C-9F15-565A-92D7-842157B75723 \
  /tmp/sihl-attach-test/Build/Products/Debug-iphoneos/SihlCient.app

xcrun devicectl device process launch \
  --device E2C5D08C-9F15-565A-92D7-842157B75723 ch.sihltraining.SihlCient

# Option B — Simulator (iPhone 17)
DEV=E8C0D5B9-2CB3-45C6-9820-3DA8AE345236
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath /tmp/sihl-attach-test -configuration Debug build 2>&1 | grep -E "error:|BUILD"
xcrun simctl boot "$DEV" 2>/dev/null; open -a Simulator
APP=$(find /tmp/sihl-attach-test/Build/Products/Debug-iphonesimulator -name 'SihlCient.app' | head -1)
xcrun simctl install "$DEV" "$APP" && xcrun simctl launch "$DEV" ch.sihltraining.SihlCient
# Screenshot: xcrun simctl io "$DEV" screenshot /tmp/attach_<schritt>.png
```

---

## 3. Test-Szenarien

### A — Daten-Karte im Thread (MessageBubble.dataCard)

| # | Was prüfen | Soll (Flutter) | Pass? |
|---|---|---|---|
| A1 | Karten-Hintergrund | **Olivgrün** (`AppColor.primary`) wie eigene Nachricht | |
| A2 | Icon-Box Farbe: `[Aufzeichnung]` | **Rot** mit rotem Hintergrund 15% opacity | |
| A3 | Icon-Box Farbe: `[Performance]` | **Grün** mit grünem Hintergrund | |
| A4 | Icon-Box Farbe: `[Messwerte]` | **Blau** mit blauem Hintergrund | |
| A5 | Icon-Box Farbe: `[TRAINING_REPORT]` | **Orange** mit orangenem Hintergrund | |
| A6 | Titel-Text | „1 (27.11.2013)" — trainingType + Datum in Klammern | |
| A7 | Untertitel-Text | „Dauer: 00:07:31 \| HR: 60 bpm" — echte Werte | |
| A8 | Hinweiszeile | „Antippen für Details" mit Hand-Icon, gedämpft | |
| A9 | Zeitstempel | Uhrzeit unten rechts sichtbar | |

> **Verdacht A6/A7:** Die gesendeten Texte enthalten möglicherweise nicht Dauer und HR,
> sondern nur den Typ. Prüfe das exakte Format des `[Aufzeichnung]`-Texts in der DB
> (via `ChatService.getMessages`) und vergleiche mit dem gesendeten Tag-Format in
> `ChatThreadView` (Zeile ~218).

---

### B — „6 Trainingseinheiten" / TRAINING_REPORT-Karte

| # | Was prüfen | Soll (Flutter) | Pass? |
|---|---|---|---|
| B1 | Karte sichtbar | Surface-Hintergrund, Laufender-Figur-Icon, „N Trainingseinheiten" | |
| B2 | Icon-Farbe | Orange (TRAINING_REPORT) | |
| B3 | Antippen | Öffnet Report-Detail-Sheet (TrainingReportSheet) | |
| B4 | Report-Sheet Inhalt | Zeigt den formatierten Report-Text | |

---

### C — AttachPickerSheet (Paperclip-Button)

| # | Was prüfen | Soll (Flutter) | Pass? |
|---|---|---|---|
| C1 | Paperclip antippen | Bottom-Sheet mit „Daten senden" öffnet | |
| C2 | Zeile „Training Aufzeichnung" | **Rote** Icon-Box (36×36), Titel + Untertitel | |
| C3 | Zeile „Leistungstest" | **Grüne** Icon-Box | |
| C4 | Zeile „Körpermessung" | **Blaue** Icon-Box | |
| C5 | Antippen → Aufzeichnung | Öffnet Liste der verfügbaren Aufzeichnungen | |
| C6 | Zeilen in der Liste | Zeigen Typ, Datum, HR-Stats, Dauer-Wert | |
| C7 | Share-Button antippen | Sendet `[Aufzeichnung] Typ (TT.MM.JJJJ)\nDauer: … | HR: …` | |

---

### D — ReviewDetailSheet (beim Antippen einer Daten-Karte im Thread)

> **KRITISCH:** Dies ist der wichtigste und wahrscheinlich fehlende Teil.
> Flutter öffnet beim Antippen einer `[Aufzeichnung]`-Karte eine DETAIL-Ansicht der
> spezifischen Aufzeichnung — mit HR-Chart und Stat-Karten.
> Die SwiftUI-Version öffnet aktuell die **Auswahl-Liste** (zum Teilen), NICHT die Detail-Ansicht.

| # | Was prüfen | Soll (Flutter) | Pass? |
|---|---|---|---|
| D1 | `[Aufzeichnung]`-Karte antippen | Öffnet **Detail** der SPEZIFISCHEN Aufzeichnung (nicht Picker-Liste) | |
| D2 | Header | Roter Icon 48×48, Trainingsname, Datum, avg HR rechts | |
| D3 | Stat-Karten | 2 Karten nebeneinander: „Dauer" + „Load · [Rating]" | |
| D4 | Load-Karte Farbe | Grüne Pfeil-Icon, TRIMP-Wert, Rating-Label farbkodiert | |
| D5 | TRIMP-Rating-Farbe | Leicht=grün, Moderat=gelb, Mittel=orange, Hart=rot-orange, Extrem=rot | |
| D6 | HR-Chart vorhanden | Liniendiagramm mit Verlauf, salmon/rot gefärbt | |
| D7 | Gradient-Füllung | Bereich unter der Kurve als halbtransparenter Farbverlauf | |
| D8 | Max-HR-Linie | Gestrichelte rote Linie bei HRmax-Wert | |
| D9 | Y-Achse | Min-Wert unten, Max-Wert oben, Zwischenwerte lesbar | |
| D10 | Zonen-Legende | 5 Zonen mit farbigen Dots + bpm-Schwelle (90/80/70/60/50% von HRmax) | |
| D11 | Kein Chart möglich | Falls `chart: []` leer → „Keine HR-Kurvendaten vorhanden" (kein Crash) | |

**Erwartetes Ergebnis D1:** FAIL — SwiftUI öffnet die Auswahl-Liste statt das Detail.

---

### E — PerformanceDetailSheet (beim Antippen einer `[Performance]`-Karte)

| # | Was prüfen | Soll (Flutter) | Pass? |
|---|---|---|---|
| E1 | Sheet öffnet | Grüner Header-Icon, Titel, Datum | |
| E2 | Metriken-Zeilen | **Alle** nicht-leeren Felder aus `metrics: [String:String]` aufgelistet | |
| E3 | Icon je Metrik | Passend: Liegestütz=Hantel, Sprint=Läufer, CMJ=Pfeil etc. | |
| E4 | Wert rechtsbündig | Zahl fett rechts, Label links | |

**Erwartetes Ergebnis E2:** Wahrscheinlich FAIL — aktuell zeigt SwiftUI nur Typ + Datum.

---

### F — MetricsDetailSheet (beim Antippen einer `[Messwerte]`-Karte)

| # | Was prüfen | Soll (Flutter) | Pass? |
|---|---|---|---|
| F1 | Zeile Gewicht | Waage-Icon (blau), Wert in kg | |
| F2 | Zeile BMI | Tacho-Icon (grün), Wert | |
| F3 | Zeile Körperfett | Tropfen-Icon (orange), Wert in % | |
| F4 | Zeile Muskelmasse | Hantel-Icon (primary), Wert in kg | |

**Erwartetes Ergebnis F2/F4:** Wahrscheinlich FAIL — BMI und Muskelmasse fehlen aktuell.

---

## 4. Befunde-Vorlage

```
D1 ReviewDetailSheet öffnet falsches Sheet — FAIL
  Beobachtet: Beim Antippen der [Aufzeichnung]-Karte öffnet sich die Auswahl-Liste
              statt der Detailansicht der Aufzeichnung.
  Screenshot: /tmp/attach_d1.png
  Fix nötig: Neues ReviewReadDetailSheet erstellen (mit HR-Chart) —
             dataCardAction in ChatThreadView für [Aufzeichnung] anpassen.
```

---

## 5. Was gebaut werden muss (falls Tests fehlschlagen)

### Lücke 1 — Neues ReviewReadDetailSheet (Detail-Ansicht einer Aufzeichnung)

Aktuell existiert kein Sheet das eine SPEZIFISCHE Aufzeichnung mit Chart zeigt.
Neues Struct erstellen: `ReviewReadDetailSheet(clientId: String, messageText: String)`

```swift
// Datum aus Nachrichtentext extrahieren (Regex: dd.MM.yyyy)
// Alle Reviews laden → Match über Datum
// Anzeigen: Header (Icon + Name + Datum + HRavg) + 2 Stat-Karten + HR-Chart + Zonenlegende
```

**Zonenberechnung** (5 Zonen, Schwellen = % von HRmax):
```swift
// Flutter-Formel:
let zones = [
    (label: "Maximal",    pct: 0.90, color: AppColor.red),
    (label: "Intensiv",   pct: 0.80, color: AppColor.orange),
    (label: "Moderat",    pct: 0.70, color: Color(hue: 0.22, saturation: 0.7, brightness: 0.75)),
    (label: "Leicht",     pct: 0.60, color: AppColor.blue),
    (label: "Sehr Leicht",pct: 0.50, color: AppColor.muted),
]
// Schwellwert = Int(zone.pct * Double(hrMax))
```

**HR-Chart** kann mit SwiftUI `Charts` Framework implementiert werden:
```swift
import Charts
Chart(review.chart, id: \.time) { point in
    AreaMark(x: .value("Zeit", idx), y: .value("HR", point.value))
        .foregroundStyle(.red.opacity(0.3))
    LineMark(x: .value("Zeit", idx), y: .value("HR", point.value))
        .foregroundStyle(AppColor.red)
}
RuleMark(y: .value("Max", hrMax)).lineStyle(StrokeStyle(dash: [5])).foregroundStyle(.red)
```

### Lücke 2 — dataCardAction unterscheiden: Tap-Detail vs. Picker-Share

```swift
// Aktuell in ChatThreadView.dataCardAction:
// [Aufzeichnung] → showReviewSheet (Auswahl zum Teilen)

// Soll:
// → showReviewDetailSheet (Detail der angetippten Karte, mit Chart)
// Paperclip → showReviewSheet bleibt (Picker zum Teilen)
```

### Lücke 3 — gesendetes Nachrichtenformat (Bereich A6/A7)

Damit „Dauer: 00:07:31 | HR: 60 bpm" in der Karte erscheint, muss das
gesendete Format folgendes enthalten:
```
[Aufzeichnung] Cardio (15.06.2026)
Dauer: 00:07:31 | HR: 60 bpm
```
→ Ist in `FEATURE-PROMPT-Chat-Attachment.md` Fix 6 beschrieben.

---

## 6. Priorisierte Fix-Reihenfolge

| Prio | Fix | Datei | Aufwand |
|---|---|---|---|
| 1 | `ReviewReadDetailSheet` mit HR-Chart | `ChatView.swift` neu | Hoch |
| 2 | `dataCardAction` für Tap-Detail trennen | `ChatView.swift` ~Z.362 | Mittel |
| 3 | Farbige Icon-Boxen in `dataCard` + `AttachPickerSheet` | `ChatView.swift` | Niedrig |
| 4 | Gesendetes Nachrichtenformat mit Dauer + HR | `ChatView.swift` ~Z.218 | Niedrig |
| 5 | PerformanceDetailSheet — Metriken-Grid | `ChatView.swift` ~Z.812 | Mittel |
| 6 | MetricsDetailSheet — BMI + Muskelmasse | `ChatView.swift` ~Z.840 | Niedrig |

> Alle Fixes 3–6 sind in `FEATURE-PROMPT-Chat-Attachment.md` als konkreter Code beschrieben.
> Fix 1 und 2 sind neue Lücken, die dieser Test aufgedeckt hat.
