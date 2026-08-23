# Feature-Prompt: HF-Diagramm in Queransicht drehen (iOS / SihlCient)

> **Zweck:** Agent-fertiges Prompt. Den „Vergrößern"-Button im Herzfrequenz-Verlauf
> durch einen **Dreh-Button** ersetzen, der das Diagramm in die **Querformat-Ansicht**
> (Landscape) dreht. Übergib 1:1 an einen Agenten mit Code- + Simulator-Zugriff.

---

## 1. Gewünschtes Verhalten (vom Nutzer)

> „Den **Vergrößerungs-Button** (↗, oben rechts im HF-Verlauf) durch einen **Dreh-Button**
> ersetzen. Beim Betätigen **dreht sich das Diagramm in die Queransicht** (Landscape) —
> die HF-Kurve nutzt dann die volle Bildschirmbreite."

## 2. Auftrag an den Agenten

Ersetze den bestehenden Vollbild-Button durch einen Dreh-Button (passendes SF-Symbol)
und präsentiere den Herzfrequenz-Verlauf **um 90° gedreht im Querformat**. Beim Schließen
zurück zur normalen Hochkant-Ansicht. Bestehende Funktion (Stat-Karten, TRIMP, normale
Detailansicht) unverändert lassen. Minimal-invasiv, Design-System (`AppColor`, `AppRadius`)
beibehalten.

## 3. Fundstellen (Code)

Datei: `client-ios/SihlCient/SihlCient/SihlClient/Views/AnalyticsView.swift`

- **`TrainingReviewDetailView`**
  - `@State private var showFullscreen = false`
  - `.sheet(isPresented: $showFullscreen) { HRFullscreenView(review: review) }`
  - in `hrChartCard`: Button mit `Image(systemName: "arrow.up.left.and.arrow.down.right")`,
    Aktion `showFullscreen = true`  ← **dieser Button soll zum Dreh-Button werden**
- **`HRFullscreenView`** (private struct) — die präsentierte Vollbildansicht (Header mit
  X-Button + Stat-Chips + `HRLineChart`)
- **`HRLineChart`** — wiederverwendbares Chart (Swift Charts), wird auch hier genutzt

## 4. Umsetzung

**Button:** Icon tauschen, z.B. `arrow.up.left.and.arrow.down.right` →
`rotate.right` (alternativ `arrow.clockwise` / `rectangle.landscape.rotate`).
`.accessibilityLabel("In Queransicht drehen")` setzen.

**Queransicht — zwei Wege, bevorzugt A:**

### Weg A (empfohlen, robust): View per `rotationEffect` drehen
Den HF-Verlauf in einem `fullScreenCover` zeigen und den Chart-Container um 90° drehen,
sodass er das Hochkant-Display im Querformat füllt — funktioniert **unabhängig von der
Geräte-Orientierung** (auch bei aktivierter Ausrichtungssperre).
- `.fullScreenCover(isPresented:)` statt `.sheet` (randlos, kein Karten-Look).
- Inhalt: `GeometryReader { geo in HRLandscapeChart(...) .frame(width: geo.size.height, height: geo.size.width).rotationEffect(.degrees(90)).position(x: geo.size.width/2, y: geo.size.height/2) }`
  (Breite/Höhe vertauschen, dann 90° drehen, zentrieren).
- Schließen-Button (X) ebenfalls mitdrehen, gut erreichbar platzieren.
- Hintergrund `AppColor.background.ignoresSafeArea()`.

### Weg B (alternativ, „echtes" Landscape): Geräte-Orientierung anfordern
iOS 16+: beim Öffnen Landscape anfordern, beim Schließen Portrait —
`windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))` +
`setNeedsUpdateOfSupportedInterfaceOrientations()`.
- Voraussetzung: App erlaubt Landscape (Info.plist `UISupportedInterfaceOrientations`
  enthält bereits Landscape Left/Right — prüfen/sicherstellen).
- Komplexer (Scene-Zugriff, Zurücksetzen beim Verlassen). Nur nehmen, wenn echtes
  Drehen des ganzen Screens gewünscht ist statt nur des Diagramms.

> Empfehlung: **Weg A** — keine Orientierungs-/Scene-Abhängigkeiten, funktioniert auch bei
> gesperrter Ausrichtung, klar zurücksetzbar. Falls der Nutzer das ganze UI gedreht haben
> will (nicht nur das Chart), Weg B wählen.

## 5. Verifikation (Simulator)

```bash
cd client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build
```
Hinweis: Die Detailansicht braucht Review-Daten. Falls kein Login möglich ist, einen
temporären Mock-Einstieg per Launch-Argument nutzen (siehe `TAP-DIAGNOSE-Analytics.md`,
Mock-Harness) und nach dem Test wieder entfernen.

Prüfen:
- [ ] Button zeigt jetzt das Dreh-Icon, nicht mehr die Vergrößern-Pfeile
- [ ] Tap → HF-Verlauf erscheint im **Querformat**, Kurve nutzt volle Breite
- [ ] Achsen/Beschriftung lesbar und korrekt orientiert (nicht spiegelverkehrt/kopfüber)
- [ ] Schließen kehrt sauber zur Hochkant-Detailansicht zurück
- [ ] Bei Ausrichtungssperre (Weg A) funktioniert es trotzdem
- [ ] Screenshot vorher/nachher als Beleg

## 6. Ausgabeformat
```
## Umsetzung
- <Diff je Datei:Zeile + Begründung, gewählter Weg A/B>
## Verifikation
- Build: SUCCEEDED ja/nein
- Screenshots: vorher (Hochkant-Button) / nachher (Querformat)
- Checkliste oben abgehakt
```
