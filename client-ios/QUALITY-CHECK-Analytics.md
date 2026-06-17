# Quality-Check: Analytics-Seite (iOS / SihlCient)

> **Zweck:** Dieses Dokument ist ein **Auftrag für einen Review-Agenten**. Es beschreibt
> Umfang, Setup, Prüf-Dimensionen, bekannte Verdachtsstellen und das erwartete
> Ausgabeformat. Übergib dieses Dokument 1:1 an den Agenten (z.B. `/code-review` oder
> einen `general-purpose`-Agenten) und lass ihn die Checkliste abarbeiten.

---

## 1. Auftrag an den Agenten

Du bist ein Senior iOS/SwiftUI-Reviewer. Prüfe die **Analytics-Seite** der nativen
SihlCient-App auf **Korrektheit, Robustheit, UX/Design-System-Treue, Accessibility,
Performance und Architektur**. Erfinde keine Probleme — jeder Befund muss mit
`Datei:Zeile` belegt und mit einer kurzen Begründung versehen sein. Wenn du dir bei
einem Befund unsicher bist, markiere ihn als `unsicher` statt ihn wegzulassen.

## 2. Umfang (Dateien)

Pfad-Basis: `client-ios/SihlCient/SihlCient/SihlClient/`

| Rolle | Datei |
|---|---|
| View (alle Sub-Views, Charts, Detail/Compare) | `Views/AnalyticsView.swift` (~1086 Z.) |
| ViewModel | `ViewModels/PerformanceViewModel.swift` |
| Service / API | `Services/PerformanceService.swift` |
| Models (Performance) | `Models/PerformanceSection.swift` |
| Models (Review/HR) ⚠️ | `Models/ChatMessage.swift` — enthält **`TrainingReview` & `HrPoint`** (Fehlplatzierung, s.u.) |
| Networking | `Networking/APIClient.swift` |

Backend-Endpunkte (Railway NestJS): `api/client/metrics/{id}`, `api/client/tests/{id}`,
`api/client/reviews/{id}`.

## 3. Setup / Verifikation

```bash
cd client-ios/SihlCient
# Kompiliert es überhaupt?
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build
# Optional im Simulator visuell prüfen (Boot + Install + Launch)
```

Wenn möglich: leere/teilweise/fehlerhafte API-Antworten simulieren und Verhalten beobachten.

---

## 4. Prüf-Dimensionen (Checkliste)

### A. Korrektheit & SwiftUI-Identität
- [ ] **ID-Kollision `PerformanceItem.id = name`** (`Models/PerformanceSection.swift:24`) und
      **`PerformanceSection.id = title`** (Z.48): Wenn zwei Metriken/Sektionen denselben
      Namen/Titel haben → doppelte SwiftUI-IDs → Render-Glitches, falsche Animationen.
      Prüfen, ob das Backend Eindeutigkeit garantiert; sonst stabile ID nötig.
- [ ] **`ForEach(reviews.enumerated(), id: \.offset)`** (`AnalyticsView.swift:274`):
      Index-basierte ID. In Kombination mit **index-basierter Auswahl**
      (`selectedIndices: Set<Int>`, Z.218) ist die Auswahl an die Array-Position gebunden.
      Was passiert bei Refresh/Reorder von `reviews`, während Compare-Mode aktiv ist?
      → Auswahl zeigt dann auf falsche Einträge. Verifizieren.
- [ ] **Compare-Selektion vs. `comparableReviews`** (Z.222): Toggle erscheint ab
      `comparableReviews.count >= minCompare`, ausgewählt wird aber in **allen** `reviews`
      indexiert. Disabled-Logik (Z.345) deckt das ab — gegenprüfen, dass kein Eintrag ohne
      Chart in die `TrainingCompareView` gelangen kann.

### B. Datenschicht & Parsing
- [ ] **Datums-Fallback auf `Date()`** (`PerformanceSection.swift:13`, analog in
      `TrainingReview`): `ISO8601DateFormatter().date(from:)` liefert `nil` bei
      Fractional-Seconds (`.SSS`) oder reinen Datums-Strings → Fallback ist **heute**.
      Das verfälscht Verlauf-Sortierung und X-Achsen-Reihenfolge **still**. Prüfen, welches
      Format das Backend liefert; ggf. `formatOptions` setzen oder mehrere Formatter.
- [ ] **Silentes `try?`-Decoding überall** (PerformanceItem/Section): Fehlerhafte Felder
      werden zu `""`/`0`/`[]` ohne Log. Bewusst gewollt (Resilienz) — aber dokumentieren,
      dass Decoding-Fehler unsichtbar sind.
- [ ] **`async let` Parallel-Fetch** (`PerformanceViewModel.swift:17–20`): gut. Aber: kein
      Cancel/Dedupe, wenn `.task` (View:16) und `.refreshable` (View:76) gleichzeitig oder
      bei `clientId`-Wechsel feuern. Race möglich? Bewerten.
- [ ] **Fehlertext** = `error.localizedDescription` (VM:24) → ggf. technische
      Netzwerk-Meldung für Endnutzer. UX prüfen.

### C. Charts (Swift Charts)
- [ ] **X-Achse = Array-Index statt Zeit** (`AnalyticsView.swift:518–545` Verlauf,
      `798` HR, `965` Compare-Normierung): ungleiche Zeitabstände werden gleichmäßig
      dargestellt. Bekannter Trade-off — bewerten, ob für die Aussage akzeptabel.
- [ ] **Y-Achsen-Domain bei flacher Linie** (`minY/maxY` PerformanceDetailView:439–453):
      `range == 0` → `±5`. Sinnvoll? Force-Unwrap `.min()!/.max()!` ist durch `guard`
      abgesichert (Z.440) — gegenprüfen.
- [ ] **HR-Chart Filter `value > 0`** (Z.786, 342): konsistent angewendet? Compare-View
      (Z.963) filtert ebenfalls — ja. Leere Serien → leeres Chart, kein Absturz? Verifizieren.

### D. UI/UX & Design-System
- [ ] **Inkonsistente `change`-Interpretation**: `changeColor` (Z.156–160) prüft
      `hasPrefix("+")`/`=="up"`; `changeIndicator` (Z.162–176) prüft
      `"up"/"increase"/"+"`. Ein Backend-Wert `"increase"` ⇒ grüner Pfeil (Icon), aber
      `changeColor` fällt auf `muted` zurück → **Farbe und Icon widersprechen sich**.
      Vereinheitlichen.
- [ ] **Hardcodierte Schriftgrößen** (`.system(size: …)` durchgängig): kein Dynamic Type →
      ältere/sehbehinderte Nutzer können nicht skalieren. Bewerten ob `.font(.body)` etc.
      sinnvoll wäre.
- [ ] Design-System-Treue: Werden `AppColor`, `AppRadius` konsequent genutzt? Suche nach
      hartcodierten `Color(red:…)` — z.B. `trimpColor` (Z.769–776) nutzt rohe RGB-Werte
      statt `AppColor`. Beabsichtigt (Ampel-Skala)? Dann zentralisieren.
- [ ] Leerer/Loading/Fehler-Zustand vorhanden (View:22–56) — vollständig & konsistent?

### E. Accessibility (VoiceOver / Kontrast)
- [ ] **Icon-only Buttons ohne Label**: Vergleichen-Toggle (Z.287), Fullscreen-Button
      (Z.736), Schließen-X (Z.866), Chevrons. → `.accessibilityLabel` fehlt.
- [ ] **Charts ohne A11y-Repräsentation**: keine `.accessibilityChartDescriptor` /
      `.accessibilityLabel`. VoiceOver liest nur „Diagramm“.
- [ ] Tap-Targets der Compare-Checkboxen (20×20, Z.379) ≥ 44pt? Eher nein → bewerten.

### F. Performance
- [ ] **`DateFormatter` in `ForEach`** (`historyTable` Z.575–581): pro Zeile neuer Formatter
      (teuer). Auch sonst werden Formatter ad hoc erzeugt (Z.226, 618, 854, 1066). →
      `static let` cachen.
- [ ] `LazyVStack` (View:59) gut; aber Sektionen rendern bei `expanded` alle Items —
      bei sehr vielen Messwerten relevant? Bewerten.

### G. Architektur / Sauberkeit
- [ ] **`TrainingReview` & `HrPoint` in `Models/ChatMessage.swift`**: irreführende
      Platzierung. → eigene Datei `Models/TrainingReview.swift`.
- [ ] Riesige `AnalyticsView.swift` (~1086 Z.) mit vielen Sub-Views. Aufteilen in mehrere
      Dateien (PerformanceSectionTile, ReviewSectionTile, Charts, Detail/Compare)?
- [ ] Doppelter alter Quell-Ordner `client-ios/SihlClient/` (NICHT im Build) — Verwechslungs-
      gefahr. Sollte entfernt werden (separate Aufgabe).

---

## 5. Erwartetes Ausgabeformat des Agenten

Pro Befund:

```
### [Schweregrad: blocker | hoch | mittel | niedrig | unsicher] Kurztitel
- Datei: Views/AnalyticsView.swift:156
- Problem: <1–3 Sätze, was & warum>
- Empfehlung: <konkreter Fix>
```

Abschluss: kurze **Zusammenfassung** (Anzahl je Schweregrad) + **Top-3 zuerst beheben**.
Keine Stiländerungen ohne Begründung. Funktionsverhalten unverändert lassen, sofern es
nicht der eigentliche Bug ist.
