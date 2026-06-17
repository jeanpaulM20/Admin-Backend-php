# Quality-Check: Start-Screen-Änderungen (iOS / SihlCient)

> **Zweck:** Agent-fertiges Prompt für einen **Code-Review/Quality-Check** der jüngsten
> Änderungen am Start-Screen. Übergib 1:1 an einen Review-Agenten (z.B. `/code-review`
> oder `general-purpose`).

---

## 1. Auftrag an den Agenten

Du bist Senior iOS/SwiftUI-Reviewer. Prüfe die **Start-Screen-Änderungen** auf
**Korrektheit, Layout/UX, Accessibility, Performance und Sauberkeit (kein toter Code,
keine Regression)**. Jeder Befund mit `Datei:Zeile` + kurzer Begründung; bei Unsicherheit
`unsicher` statt weglassen. Kein Umbau ohne Grund — Verhalten erhalten.

## 2. Umfang

Datei: `client-ios/SihlCient/SihlCient/SihlClient/Views/StartView.swift`
Bezugs-Commit: `7322778` „refactor(start): Start-Screen entschlacken + Kopf fixieren".

**Was geändert wurde:**
1. Zwei Summary-Boxen entfernt („Nächster Termin" → Kalender, „Credits" → Profil).
2. Toter Code entfernt: `struct SummaryCard`, computed `nextApptText`.
3. Layout aufgeteilt: **fixer Kopf** (Begrüßung, `DailyQuoteWidget`, Sektions-Header
   „Nächste Termine") **außerhalb** des ScrollViews; **nur die Terminliste** in einem
   `ScrollView { LazyVStack { … } }`. `.refreshable` hängt am ScrollView.

Querbezug: `MainTabView` (setzt `onGoToCalendar`), `ProfileView` (Credits), `CalendarView`
(`AppointmentDetailSheet`) — nur prüfen, dass nichts gebrochen ist, nicht ändern.

## 3. Prüf-Checkliste

### A. Korrektheit des Sticky-Header-Umbaus
- [ ] Fixer Kopf bleibt beim Scrollen wirklich stehen; **nur** die Terminkarten scrollen.
- [ ] `.refreshable` (Pull-to-Refresh) funktioniert weiterhin — und ist sinnvoll am
      ScrollView (nicht am fixen Kopf) platziert.
- [ ] Leer-Zustand `StartEmptyState(onBookNow: onGoToCalendar)` wird **im Scrollbereich**
      korrekt angezeigt; Button „Termin buchen" funktioniert noch (→ `onGoToCalendar`).
- [ ] Loading- und Error-Zweige in `mainContent` unverändert/funktionsfähig.
- [ ] `upcoming.count` im fixen Header bleibt korrekt (aktualisiert nach Refresh).

### B. Layout / UX
- [ ] Kopf und Liste **horizontal bündig** (beide `padding(.horizontal, 20)`).
- [ ] Vertikale Abstände stimmig: `top, 24` am Kopf, Abstand Zitat→Header (12),
      Header→Liste (16), `bottom, 24` an der Liste — kein doppelter/fehlender Abstand.
- [ ] Erste Terminkarte klebt nicht am Sektions-Header / kein abgeschnittener Inhalt.
- [ ] Kein sichtbarer „Sprung"/Clipping an der Grenze fixer Kopf ↔ Scrollbereich.
- [ ] Safe-Area: Kopf nicht unter Notch/Statusbar; Liste scrollt nicht unter die TabBar weg.

### C. Sauberkeit / Regression
- [ ] **Kein toter Code**: `grep -n "SummaryCard\|nextApptText" StartView.swift` leer.
- [ ] `onGoToCalendar` ist **nicht** tot (wird von `StartEmptyState` genutzt) — nicht entfernen.
- [ ] Keine ungenutzten Imports/Properties/Warnungen durch den Umbau.
- [ ] Kein Funktionsverlust: Credits weiterhin über Profil, Termine über Liste/Kalender
      erreichbar (Navigationswege intakt).
- [ ] Doc-Kommentar oben spiegelt den neuen Inhalt (keine „Summary-Karten" mehr).

### D. Accessibility / Robustheit
- [ ] Dynamic Type: feste `.system(size:)`-Schriften — bewerten, ob der fixe Kopf bei
      großer Schrift zu viel Höhe einnimmt und die Liste erdrückt.
- [ ] Lange Vornamen (Begrüßung) / viele Termine → kein Layout-Bruch; Liste scrollt sauber.
- [ ] 0 Termine → Leer-Zustand; 1 Termin → Singular; sehr viele Termine → flüssiges Scrollen.
- [ ] `LazyVStack` weiterhin sinnvoll (Lazy-Laden bei vielen Karten).

## 4. Verifikation (optional, Simulator)
```bash
cd client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build
```
Start-Screen braucht Login; sonst Mock-Harness wie in `TAP-DIAGNOSE-Analytics.md`
(mit **vielen** Mock-Terminen, um das Scroll-/Sticky-Verhalten sichtbar zu machen).

## 5. Ausgabeformat
```
### [Schweregrad: hoch | mittel | niedrig | unsicher] Kurztitel
- Datei: Views/StartView.swift:NN
- Problem: <1–3 Sätze>
- Empfehlung: <konkreter Fix>
```
Abschluss: Übersicht (Anzahl je Schweregrad) + Top-3 zuerst beheben. Funktionsverhalten
unverändert lassen, außer es ist der eigentliche Bug.
