# Bug-Prompt: Analytics → Herzfrequenz — Crash bei Auswahl + langsames Laden

> **Zweck:** Agent-fertiges Prompt zur **Analyse, Reproduktion und Behebung** von zwei
> gemeldeten Fehlern im Herzfrequenz-Bereich der Analytics-Seite. Übergib 1:1 an einen
> Agenten mit Code- + Simulator-Zugriff.

---

## 0. Gemeldete Symptome (vom Nutzer)

1. **Crash:** „Beim **Auswählen von Trainingsdaten** stürzt die App ab." (Analytics →
   Herzfrequenz → Aufzeichnung antippen / Vergleich auswählen)
2. **Performance:** „Die Seite — **vor allem der Herzfrequenz-Bereich** — braucht **zu
   lange zum Laden**, wenn sie geöffnet wird."

## 1. Auftrag an den Agenten

Finde für **beide** Symptome die Ursache(n), belege sie am Code (`Datei:Zeile`), behebe
sie minimal-invasiv und verifiziere im Simulator. Crash-Fix hat Priorität. Bestehendes
Verhalten (Navigation, Vergleich, Charts) erhalten. Jeder Befund mit kurzer Begründung;
bei Unsicherheit als `unsicher` markieren statt weglassen.

Datei im Fokus: `client-ios/SihlCient/SihlCient/SihlClient/Views/AnalyticsView.swift`
Modelle: `Models/ChatMessage.swift` (enthält `TrainingReview`, `HrPoint`),
`Models/PerformanceSection.swift`. ViewModel: `ViewModels/PerformanceViewModel.swift`.

---

## 2. Teil A — Crash bei Auswahl (Priorität)

### H1 — Index-Out-of-Range bei der Vergleichs-Auswahl  ⭐ Hauptverdacht
`ReviewSectionTile` hält die Auswahl als **`selectedIndices: Set<Int>`** (Indizes in
`reviews`). Beim Bauen der Vergleichsansicht:
`TrainingCompareView(reviews: selectedIndices.sorted().map { reviews[$0] })`.
Wenn `reviews` sich zwischen Auswahl und Zugriff ändert (Pull-to-Refresh / erneutes
`.task`-Fetch / kürzere Liste), zeigt ein Index ins Leere → **`reviews[$0]` Index out of
range → Crash**.
- **Verifizieren:** Auswahl treffen, dann Daten neu laden, dann „Vergleichen" — oder
  Auswahl auf letzter Zeile + Refresh.
- **Fix-Richtung:** Auswahl **id-basiert** statt indexbasiert führen (`Set<String>` über
  `TrainingReview.id`); beim Mapping defensiv filtern (`compactMap`), nie per Index
  subscripten. Voraussetzung: stabile, eindeutige `id` (siehe H2).

### H2 — ForEach mit leerer/doppelter `id` → undefiniertes Verhalten/Crash
`TrainingReview.id` fällt im Decoder auf `""` zurück (`Models/ChatMessage.swift`), wenn das
Backend kein `id` liefert. In `TrainingCompareView` nutzen `legend` und `statsTable`
`ForEach(... id: \.element.id)` → bei mehreren leeren/gleichen IDs **doppelte SwiftUI-Keys**
→ Fehlrendering bis Crash, genau beim Öffnen des Vergleichs („Trainingsdaten auswählen").
- **Verifizieren:** Reviews ohne `id` vom Backend? Mehrere mit gleicher `id`?
- **Fix-Richtung:** stabile eindeutige ID erzeugen (z.B. `id` + `date` + `trainingType`,
  oder Offset als Fallback). Konsistent in allen ForEach verwenden.

### H3 — Auswahl/Disabled-Randfälle
Compare erlaubt nur Reviews mit `chart.filter{$0.value>0}.count >= 2` (disabled sonst).
Prüfen, ob ein disabled-/chartloser Eintrag doch in `TrainingCompareView` gelangen kann
(z.B. über `comparableReviews` vs. Index-Mismatch) → leere `normalized`-Serie → Chart-Edge.

> Hinweis: H1+H2 hängen zusammen — die saubere Lösung ist **id-basierte Auswahl mit
> garantiert eindeutiger ID**. Damit fallen beide Crash-Pfade weg.

---

## 3. Teil B — Langsames Laden (Herzfrequenz)

### H4 — Sehr große HR-Kurven, ungedrosselt gerendert  ⭐ Hauptverdacht
HR-Aufzeichnungen können **tausende Punkte** haben (Screenshot: Dauer 01:47:55 → sehr dichte
Kurve). `HRLineChart` rendert **alle** Punkte mit `.interpolationMethod(.catmullRom)` —
teuer. Im Detail-/Vollbild und potenziell mehrfach.
- **Fix-Richtung:** Chart-Daten **downsamplen** (z.B. auf ~150–300 Punkte für die
  Anzeige; Min/Max je Bucket erhalten, damit Peaks bleiben). Für das kleine Inline-Chart
  stärker reduzieren als fürs Vollbild. Ggf. `.interpolationMethod(.linear)` bei vielen
  Punkten.

### H5 — Teure Computed Properties bei jedem Render
Pro Render erneut über volle Chart-Arrays iteriert:
- `ReviewSectionTile.comparableReviews` = `reviews.filter { $0.chart.filter { $0.value > 0 }.count >= 2 }` (Header)
- `reviewRow`: `hasChart = review.chart.filter { $0.value > 0 }.count >= 2` (pro Zeile)
- `TrainingReview.edwardsTrimp` = `reduce` über alle Chart-Punkte (statCards/statsTable)
Bei großen Charts × vielen Reviews × mehreren Re-Renders summiert sich das.
- **Fix-Richtung:** Werte **einmal vorberechnen/cachen** (z.B. beim Decodieren in
  `PerformanceViewModel.fetch` ableiten und im Model/VM ablegen: `hasComparableChart`,
  `validPointCount`, vorgerechneter `trimp`). Computed Properties nicht in `body`-Pfaden
  über große Arrays laufen lassen.

### H6 — Großer Netzwerk-/Decode-Aufwand für Reviews
`PerformanceService.getReviews` lädt volle HR-Kurven; `HrPoint` hat einen Custom-Decoder
pro Punkt. Großer Payload + viele Allocations blockieren die Section-Anzeige.
- **Fix-Richtung:** prüfen, ob das Backend eine **reduzierte Kurve** liefern kann
  (Server-seitiges Downsampling) oder ob `chart` erst **on-demand** beim Öffnen der
  Detailansicht geladen wird (Liste ohne volle Kurve laden). Decode-Kosten messen.

### Weitere Checks
- [ ] Läuft Decoding/Mapping auf dem Main-Actor und blockiert UI? (`@MainActor` VM)
- [ ] Wird `fetch` doppelt ausgelöst (`.task` + `.refreshable`)? (Guard `isLoading` vorhanden — verifizieren)
- [ ] Mehrfache `DateFormatter`-Allokationen in Schleifen (separater Cleanup, s. Quality-Check)

---

## 4. Reproduktion & Verifikation (Simulator)

```bash
cd client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build
```
Datenzugang: Detail-/HR-Daten brauchen Login. Falls nicht möglich, **temporären
Mock-Harness per Launch-Argument** nutzen (Vorlage: `TAP-DIAGNOSE-Analytics.md`,
Abschnitt Mock) — und dafür eine **große Kurve** (mehrere tausend Punkte) sowie Reviews
**ohne `id`** einbauen, um H2/H4 zu provozieren. Nach dem Test wieder entfernen.

Crash gezielt provozieren:
- Auswahl treffen → Refresh/Reload → „Vergleichen" (H1)
- Reviews ohne/又 doppelte `id` → Vergleich öffnen (H2)
Performance messen:
- Zeit von „Analytics öffnen" bis HR-Section interaktiv; Instruments (Time Profiler)
  optional. Vorher/nachher vergleichen.

Erwartetes Ergebnis nach Fix:
- Kein Crash bei Auswahl/Refresh/Vergleich, auch ohne Backend-`id`.
- HR-Section lädt spürbar schneller; große Kurven flüssig (downsampled).
- Vergleich, Navigation, Stat-Werte unverändert korrekt.

## 5. Ausgabeformat
```
## Ursachenanalyse
- [bestätigt|widerlegt|unsicher] H1 … (Datei:Zeile) — Beleg
- …
## Fix
- <Diff je Datei:Zeile + Begründung>
## Verifikation
- Crash-Repro vorher/nachher
- Ladezeit vorher/nachher (grobe ms-Angabe) + Screenshots
- Build: SUCCEEDED ja/nein
```
Abschluss: „Ursache → Fix → verifiziert" je Symptom.
