# Tap-Diagnose & Fix-Prompt: Analytics-Bereich (iOS / SihlCient)

> **Zweck:** Agent-fertiges Prompt zur **Analyse, Reproduktion und Behebung** eines
> gemeldeten Tap-Problems im Analytics-Bereich. Übergib es 1:1 an einen Agenten mit
> Code- und Ausführungs-Tools (Bash + Simulator).

---

## 0. Gemeldetes Symptom (vom Nutzer)

> „Taps im Analytics-Bereich reagieren **verzögert**, und **nur bestimmte Flächen**
> reagieren. **Vor allem der HR-Bereich (Herzfrequenz) reagiert schlecht.**"

## 1. Auftrag an den Agenten

Finde die **Ursache(n)** des Tap-Problems, **belege** sie am Code (`Datei:Zeile`),
**behebe** sie minimal-invasiv und **verifiziere** die Behebung im Simulator. Ändere kein
visuelles Design außer dem, was für die Tap-Behebung nötig ist. Funktionsverhalten
(Navigation, Compare-Mode) muss erhalten bleiben.

Datei im Fokus: `client-ios/SihlCient/SihlCient/SihlClient/Views/AnalyticsView.swift`
Betroffene Sub-Views: `ReviewSectionTile`, `PerformanceSectionTile`, `PerformanceItemRow`,
`reviewRow` / `reviewRowContent`.

## 2. Leithypothesen (zuerst prüfen — nach Wahrscheinlichkeit)

### H1 — Verschachtelte Buttons im HR-Header  ⭐ Hauptverdacht
Der Header von `ReviewSectionTile` ist ein `Button` (≈ Z.242), und **in dessen Label**
steckt der `compareToggle`-**Button** (≈ Z.258 → Definition ≈ Z.295). SwiftUI-Hit-Testing
mit einem Button im Label eines anderen Buttons ist mehrdeutig → **verzögerte/verschluckte
Taps**. Erklärt, warum **nur die HR-Kachel** betroffen ist (nur sie hat diesen Toggle).
- **Verifizieren:** „Vergleichen" tippen — wird stattdessen auf-/zugeklappt? Muss man
  präzise treffen? Reagiert es verzögert?
- **Fix-Richtung:** Header NICHT als umschließenden `Button` bauen. Stattdessen Header-Inhalt
  + `.contentShape(Rectangle())` + `.onTapGesture { expanded.toggle() }`, und den
  `compareToggle` als eigenständiges, daneben liegendes Tap-Element (mit eigener
  `contentShape`) — beide auf gleicher Ebene, NICHT verschachtelt. Alternativ
  `compareToggle` aus dem Header-Tap-Bereich herausziehen.

### H2 — Fehlende `.contentShape(Rectangle())` → nur opake Flächen tappbar
`reviewRowContent` (Compare-Mode nutzt `.onTapGesture`, ≈ Z.351) und Zeilen mit
`Spacer()` + teils `Color.clear`-Hintergrund (z.B. gerade Zeilen): Ohne
`.contentShape(Rectangle())` feuert `onTapGesture` **nur auf gerenderten/opaken Pixeln**,
nicht im transparenten Zwischenraum (Spacer). → Erklärt „nur bestimmte Flächen reagieren".
- **Verifizieren:** In Compare-Mode auf den leeren Mittelbereich einer Zeile tippen vs. auf
  den Text/die Checkbox.
- **Fix-Richtung:** `.contentShape(Rectangle())` auf die Zeile, bevor `.onTapGesture`/im
  `Button`-Label, sodass die gesamte Zeilenfläche tappbar ist.

### H3 — `Color.clear`-Hintergrund nicht zuverlässig hittable
Gerade Zeilen: `background(isEven ? Color.clear : …)` (PerformanceItemRow ≈ Z.202,
reviewRowContent ≈ Z.412–416). Transparente Bereiche ohne `contentShape` schlucken Taps.
- **Fix-Richtung:** wie H2 — explizite `contentShape`.

### H4 — ScrollView-Tap-Verzögerung / Gesten-Konflikt
Taps in einer `ScrollView` werden minimal verzögert (Scroll-Erkennung). In Kombination mit
verschachtelten Gesten (H1) wirkt das stärker. `NavigationLink`-Zeilen + `onTapGesture`-Zeilen
im selben Tile mischen zwei Mechanismen.
- **Verifizieren:** Tritt die Verzögerung auch außerhalb des ScrollView-Scrollens auf?
  Bei `PerformanceSectionTile` (kein Toggle) ebenfalls?
- **Fix-Richtung:** konsistenter Tap-Mechanismus pro Zeile; ggf. `.buttonStyle(.plain)`
  beibehalten, aber Hierarchie entwirren.

### H5 — Tap-Targets zu klein
Compare-Checkbox 20×20 (≈ Z.379), Chevron/Icons < 44pt. Apple-Mindestgröße 44×44.
- **Fix-Richtung:** Tap-Fläche der ganzen Zeile nutzen (H2) statt nur der Checkbox.

## 3. Reproduktion (vor dem Fix dokumentieren)

```bash
cd client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build
DEV=E8C0D5B9-2CB3-45C6-9820-3DA8AE345236
xcrun simctl boot "$DEV" 2>/dev/null; open -a Simulator
APP=$(find ~/Library/Developer/Xcode/DerivedData/SihlCient-*/Build/Products/Debug-iphonesimulator -name 'SihlCient.app' | head -1)
xcrun simctl install "$DEV" "$APP"; xcrun simctl launch "$DEV" ch.sihltraining.SihlCient
```

Repro-Matrix (jeweils „reagiert / verzögert / gar nicht" notieren):
| Element | Tap-Fläche getestet | Reaktion |
|---|---|---|
| HR-Header (Fläche um Titel) | | |
| HR-Header „Vergleichen"-Toggle | | |
| HR-Review-Zeile (auf Text) | | |
| HR-Review-Zeile (leerer Mittelbereich/Spacer) | | |
| HR-Review-Zeile in Compare-Mode (Checkbox) | | |
| Performance-Sektion-Header | | |
| Performance-Messwert-Zeile | | |

> Tipp: Taps am Gerät/Sim auf exakte Koordinaten setzen, um „nur opake Fläche reagiert"
> nachzuweisen. Falls verfügbar, Tap-Latenz subjektiv bewerten (sofort vs. spürbar verzögert).

## 4. Erwartetes Ergebnis nach Fix
- Gesamte Header-Fläche klappt zuverlässig & sofort auf/zu.
- „Vergleichen"-Toggle reagiert unabhängig vom Header, ohne diesen mitzuschalten.
- Gesamte Zeilenfläche (inkl. Spacer-Bereich) ist tappbar — in normalem **und** Compare-Mode.
- Keine spürbare Verzögerung außerhalb der normalen ScrollView-Toleranz.
- Navigation in Detail-Views und Compare-Auswahl funktionieren unverändert.

## 5. Ausgabeformat
```
## Ursachenanalyse
- [bestätigt|widerlegt|unsicher] H1 … (Datei:Zeile) — Beleg/Beobachtung
- …
## Fix
- <Diff-Zusammenfassung je Datei:Zeile + Begründung>
## Verifikation
- Repro-Matrix vorher/nachher (Tabelle) + Screenshots
- Build: BUILD SUCCEEDED ja/nein
```

Abschluss: kurze Zusammenfassung „Ursache → Fix → verifiziert".
