# BUG-PROMPT — Chat: lange Ladezeit dann Absturz (Diagnose & Fix)

**Symptom (User):** Beim Tippen in den Chat / auf eine Aufzeichnung braucht die App
sehr lange und stürzt dann ab.

**Wichtig:** Erst den **echten Crash-Log** beschaffen und den Typ bestimmen
(Memory / Watchdog / Exception). NICHT raten. Die unten genannten Verdachtspunkte
stammen aus der Code-Analyse und sind nach Wahrscheinlichkeit sortiert — bestätige sie
mit dem Crash-Log, bevor du fixst.

Dateien:
- `SihlClient/Views/ChatView.swift` (UI, ~1690 Zeilen)
- `SihlClient/ViewModels/ChatViewModel.swift`
- `SihlClient/Services/ChatService.swift`
- `SihlClient/Models/ChatMessage.swift` (Modelle inkl. `TrainingReview`, `HrPoint`)

---

## Schritt 1 — Crash reproduzieren & Log beschaffen (zwingend zuerst)

### Auf dem Gerät (iPhone 15, devicectl-ID `E2C5D08C-9F15-565A-92D7-842157B75723`)

```bash
# Live-Konsole während der Reproduktion mitschneiden
log stream --predicate 'process == "SihlCient"' --level debug > /tmp/sihl-crash-live.log &

# App starten, dann manuell reproduzieren: Chat → Gespräch → Aufzeichnung antippen → aufklappen
# Nach dem Crash: Crash-Reports vom Gerät holen
xcrun devicectl device info processes --device E2C5D08C-9F15-565A-92D7-842157B75723 >/dev/null 2>&1
ls -lt ~/Library/Logs/CrashReporter/MobileDevice/*/SihlCient* 2>/dev/null | head
```

Crash-Reports liegen sonst in: **Xcode → Window → Devices and Simulators → View Device Logs**.

### Im Simulator (schneller zu reproduzieren, ID `E8C0D5B9-2CB3-45C6-9820-3DA8AE345236`)

```bash
# Konsole live
xcrun simctl spawn E8C0D5B9-2CB3-45C6-9820-3DA8AE345236 log stream \
  --predicate 'process == "SihlCient"' --level debug > /tmp/sihl-crash-sim.log &

# Crash-Logs des Simulators
ls -lt ~/Library/Logs/DiagnosticReports/SihlCient* 2>/dev/null | head
```

### Crash-Typ bestimmen

| Im Log / Crash-Report | Bedeutung | Richtung |
|---|---|---|
| `EXC_RESOURCE … MEMORY` / `Jetsam` / `per-process-limit` | **Out-of-Memory** | → Verdacht 1 & 2 (Chart/Daten zu groß) |
| `0x8badf00d` / `watchdog` / `exhausted … CPU` / `hang` | **Watchdog** (Hauptthread blockiert) | → Verdacht 1 & 3 (teures Rendering) |
| `EXC_BAD_ACCESS` / `Fatal error:` / `index out of range` / `Duplicate` | **Exception** | → Stacktrace lesen, Verdacht 4 |

> „Lange Ladezeit dann Absturz" ist klassisch für **OOM** oder **Watchdog** — beides
> passt zum HR-Chart-Rendering. Das deckt sich mit Verdacht 1.

---

## Verdacht 1 (HÖCHSTWAHRSCHEINLICH) — HR-Chart mit catmullRom über unbegrenzt viele Punkte

**Datei:** `ChatView.swift` — `ReviewRow.hrChart` (ca. Zeile 948–1013) + `chartPoints` (Zeile 790)

**Problem:**
```swift
private var chartPoints: [(x: Double, y: Double)] {
    let valid = review.chart.filter { $0.value > 0 }
    return valid.enumerated().map { (i, p) in (Double(i), p.value) }   // ALLE Punkte, ungefiltert
}

// hrChart:
Chart {
    ForEach(pts, id: \.x) { pt in
        AreaMark(...).interpolationMethod(.catmullRom)   // teure Spline-Interpolation
        LineMark(...).interpolationMethod(.catmullRom)   // nochmal teuer, pro Punkt
    }
    ...
}
```

Eine HR-Aufzeichnung kann **hunderte bis tausende** Messpunkte enthalten (siehe Screenshot:
sehr dichte Kurve). Für JEDEN Punkt werden **zwei** Marks (Area + Line) mit
**Catmull-Rom-Spline** gezeichnet. Das blockiert den Hauptthread sekundenlang
(→ Watchdog-Kill) und/oder erzeugt riesige Render-Buffer (→ OOM).
Genau das erklärt „lange dann Absturz".

**Fix A — Punkte downsamplen (Pflicht):** Auf max. ~120 Punkte reduzieren.
```swift
// In ReviewRow — neue Konstante:
private static let maxChartPoints = 120

private var chartPoints: [(x: Double, y: Double)] {
    let valid = review.chart.filter { $0.value > 0 }
    guard valid.count > Self.maxChartPoints else {
        return valid.enumerated().map { (Double($0.offset), $0.element.value) }
    }
    // gleichmäßiges Downsampling (jeder n-te Punkt, Min/Max bleiben grob erhalten)
    let stride = Double(valid.count) / Double(Self.maxChartPoints)
    var result: [(x: Double, y: Double)] = []
    result.reserveCapacity(Self.maxChartPoints)
    var i = 0.0
    while Int(i) < valid.count {
        let idx = Int(i)
        result.append((Double(result.count), valid[idx].value))
        i += stride
    }
    return result
}
```

**Fix B — Interpolation entschärfen:** `.catmullRom` → `.linear` (oder `.monotone`).
Linear ist um Größenordnungen billiger und bei dichten Daten optisch praktisch gleich.
```swift
AreaMark(...).interpolationMethod(.linear)
LineMark(...).interpolationMethod(.linear)
```

**Fix C — Nur EIN Mark-Typ pro Punkt wenn möglich:** Area + Line verdoppelt die Last.
Behalte beide nur wenn nötig; sonst nur `LineMark` + separates `AreaMark` ohne eigene
ForEach-Iteration (Charts kann eine Reihe als Ganzes zeichnen — `ForEach` ist hier ok,
aber die Interpolation ist der Kostentreiber).

---

## Verdacht 2 — `getReviews` lädt ALLE Aufzeichnungen inkl. voller Chart-Arrays

**Datei:** `ChatService.swift` `getReviews` + `ReviewDetailSheet.task` (Zeile 726)

Das Sheet lädt **alle** Reviews auf einmal:
```swift
reviews = try await ChatService.shared.getReviews(clientId: clientId)
```
Jedes `TrainingReview` enthält ein `chart: [HrPoint]`. Bei vielen Trainings × tausenden
Punkten ist die JSON-Antwort mehrere MB → langer Decode (das „lange Laden") + hoher
Speicher. Zusammen mit Verdacht 1 ergibt das den OOM.

**Diagnose — Payload-Größe messen:**
```bash
TOKEN="<token aus Keychain auth_token>"
BASE="https://admin-backend-php-production.up.railway.app"
curl -s -H "X-Auth-Token: $TOKEN" "$BASE/api/client/reviews/<clientId>" -o /tmp/reviews.json -w "Größe: %{size_download} Bytes\n"
python3 -c "import json;d=json.load(open('/tmp/reviews.json'));print('Reviews:',len(d));print('Chart-Punkte gesamt:',sum(len(r.get('chart',[])) for r in d))"
```

**Fix-Optionen (nach Befund):**
- Wenn > ~1 MB / > ~5000 Punkte gesamt: Chart-Daten **nicht** in der Listen-Antwort laden,
  sondern erst beim Aufklappen einer Aufzeichnung per Detail-Endpoint nachladen
  (`ChatService.getReview(id:)`). Falls Backend das nicht hat → mit Backend-Owner klären.
- Übergangslösung clientseitig: Charts erst rendern wenn aufgeklappt (ist bereits via
  `if isExpanded` der Fall) **und** Downsampling aus Verdacht 1 → reduziert die Render-Last.
  Der Decode-Aufwand bleibt aber → Downsampling möglichst **schon beim Decode** im Model.

**Fix beim Decode (am wirksamsten gegen OOM):** In `TrainingReview.init` das `chart`
beim Dekodieren auf z.B. 200 Punkte begrenzen, statt tausende im Speicher zu halten:
```swift
// ChatMessage.swift — TrainingReview.init, chart-Zeile ersetzen:
let rawChart = (try? c.decode([HrPoint].self, forKey: .chart)) ?? []
chart = TrainingReview.downsample(rawChart, to: 200)

// + statische Helper-Funktion in TrainingReview:
static func downsample(_ pts: [HrPoint], to maxCount: Int) -> [HrPoint] {
    guard pts.count > maxCount else { return pts }
    let stride = Double(pts.count) / Double(maxCount)
    var out: [HrPoint] = []; out.reserveCapacity(maxCount)
    var i = 0.0
    while Int(i) < pts.count { out.append(pts[Int(i)]); i += stride }
    return out
}
```

---

## Verdacht 3 — Teure Computed Properties bei jedem Render

**Datei:** `ChatView.swift` — `chartPoints`, `hrMin` (Zeile 790–799) und
`TrainingReview.edwardsTrimp` (Model, Zeile 130 ff.)

`edwardsTrimp` iteriert das gesamte `chart`-Array **und** parst pro Punkt ISO8601-Datumswerte
mit `iso8601Fmt`. Es wird in `ReviewRow` mehrfach pro Render aufgerufen (`trimpBadge`,
`statCards`). `chartPoints`/`hrMin` filtern ebenfalls das ganze Array bei jedem `body`.
Bei großen Charts × SwiftUI-Re-Renders (Animation beim Aufklappen!) summiert sich das zu
sekundenlangem Hauptthread-Blocking → Watchdog.

**Fix:** Schwere Werte **einmal** berechnen und cachen — nicht als computed property.
Entweder im Model als gespeicherte Eigenschaft (in `init` berechnet), oder in `ReviewRow`
per `@State`, das in `.onAppear`/`.task` einmal gefüllt wird:
```swift
// In ReviewRow:
@State private var cachedPoints: [(x: Double, y: Double)] = []
@State private var cachedHrMin: Int? = nil
@State private var cachedTrimp: Double? = nil

// body: statt computed properties die gecachten Werte nutzen.
// Befüllen, sobald aufgeklappt wird (oder in .task):
.onChange(of: isExpanded) { _, expanded in
    guard expanded, cachedPoints.isEmpty else { return }
    cachedPoints = Self.makePoints(review.chart)   // Downsampling-Logik
    cachedHrMin  = Self.makeHrMin(review.chart)
    cachedTrimp  = review.edwardsTrimp
}
```
Die `withAnimation(.easeInOut)` beim Aufklappen (Zeile 750) animiert sonst den Chart-Aufbau
Frame für Frame → besonders teuer. Erwäge, den Chart **ohne** Animation einzublenden bzw.
die Punkte vor der Animation zu cachen.

---

## Verdacht 4 — Sonstige (nur falls Crash-Log eine Exception zeigt)

- **`ForEach(pts, id: \.x)`** (Zeile 962): Nach Downsampling sind die `x` eindeutig (0,1,2,…).
  Vor dem Fix mit Original-Indizes ebenfalls eindeutig — also kein Duplicate-Key-Crash.
  Trotzdem im Stacktrace prüfen.
- **ISO8601 ohne Millisekunden** (`ChatMessage.swift` Zeile 3): `ISO8601DateFormatter()` parst
  `…T..:..:..000Z` nicht → `edwardsTrimp` fällt auf nil/Fallback. Kein Crash, aber falsche
  Werte. Falls relevant: `formatOptions = [.withInternetDateTime, .withFractionalSeconds]`.
- **Thread-Nachrichtenliste** (`messageList`, Zeile 243): `groupMessages` + `circleRuns` +
  `.filter` sind O(n²) pro Render, aber nur für die Nachrichtenanzahl (Dutzende) → unkritisch.
  Nur prüfen, falls der Crash schon beim Öffnen des Threads (ohne Aufzeichnung) auftritt.

---

## Schritt 2 — Fix-Reihenfolge

1. **Crash-Log beschaffen** (Schritt 1) → Typ bestätigen.
2. **Verdacht 1** umsetzen: Downsampling in `chartPoints` + `.linear` Interpolation.
3. **Verdacht 3**: schwere Computed Properties cachen, Animation beim Aufklappen entschärfen.
4. **Verdacht 2** messen; bei großer Payload Downsampling **im Model-Decode** ergänzen.
5. Neu bauen, erneut reproduzieren, mit **Instruments** (Allocations + Time Profiler) prüfen,
   dass Hauptthread beim Aufklappen < ~1 s blockiert und Speicher stabil bleibt.

## Schritt 3 — Build & Verifikation

```bash
cd /Users/piaclodimac.com/Admin-Backend-php/client-ios/SihlCient

# Simulator-Build (schnell zum Reproduzieren)
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath /tmp/sihl-crash-fix -configuration Debug build 2>&1 | grep -E "error:|BUILD"

# Geräte-Build (finale Verifikation)
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -configuration Debug \
  -destination 'platform=iOS,id=00008120-001A6CE83C81A01E' \
  -derivedDataPath /tmp/sihl-crash-fix -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD"

xcrun devicectl device install app --device E2C5D08C-9F15-565A-92D7-842157B75723 \
  /tmp/sihl-crash-fix/Build/Products/Debug-iphoneos/SihlCient.app
xcrun devicectl device process launch --device E2C5D08C-9F15-565A-92D7-842157B75723 \
  ch.sihltraining.SihlCient
```

**Abnahme-Kriterien:**
- [ ] Crash-Log-Typ ist dokumentiert (Memory / Watchdog / Exception)
- [ ] Chat-Tab → Gespräch → Aufzeichnung antippen → aufklappen: **kein** Absturz
- [ ] HR-Chart erscheint in < 1 s, flüssig (kein mehrsekündiges Einfrieren)
- [ ] Auch bei der größten vorhandenen Aufzeichnung (meiste Chart-Punkte) stabil
- [ ] Instruments: kein OOM-Spike, Hauptthread nicht dauerhaft blockiert

---

## Zusammenfassung der Verdachtspunkte

| # | Verdacht | Datei:Zeile | Crash-Typ | Fix |
|---|---|---|---|---|
| 1 | catmullRom-Chart über alle Punkte | `ChatView.swift:790,948` | Watchdog/OOM | Downsampling + `.linear` |
| 2 | `getReviews` lädt alle Chart-Arrays | `ChatService.swift` / `:726` | OOM | Decode-Downsampling / Lazy-Load |
| 3 | Teure Computed Props je Render + Animation | `ChatView.swift:790–799`, Model `edwardsTrimp` | Watchdog | Werte cachen, Animation entschärfen |
| 4 | ISO8601 ohne Millisek. / O(n²)-Liste | `ChatMessage.swift:3`, `ChatView.swift:243` | (kein Crash / Exception) | nur falls Log es zeigt |
