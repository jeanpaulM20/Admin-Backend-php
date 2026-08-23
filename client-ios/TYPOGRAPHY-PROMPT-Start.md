# Typografie-Prompt: Start-Screen — UX/UI-Verbesserungen

> **Zweck:** Agent-fertiges Prompt für alle Typografie-Korrekturen und -Verbesserungen
> auf dem Start-Screen. Übergib 1:1 an einen Agenten mit Code-Zugriff.

---

## 0. Kontext

Datei: `client-ios/SihlCient/SihlCient/SihlClient/Views/StartView.swift`
Analyse-Basis: Typografische Prüfung des Start-Screens (Stand Commit `7322778`).

Es gibt **2 Bugs** (sofort fixen) und **2 Verbesserungen** (Hierarchie/Lesbarkeit).
Kein Layout-Umbau, keine Funktionsänderung — nur Schriftgrade, -gewichte und eine
Zeichenkette korrigieren.

---

## 1. Bugs — Pflicht

### Bug ①: Falsches deutsches Anführungszeichen im Zitat

**Datei:** `Views/StartView.swift` — `struct DailyQuoteWidget`, Zeile ~146

**Problem:** `\u{201C}` ist das *linke* (öffnende) Anführungszeichen (= `"`).
Als schließendes Zeichen ergibt das `„Text"` statt korrekt `„Text"`.

**Fix:**
```swift
// Vorher (falsch):
Text("„\(q.text)\u{201C}")

// Nachher (korrekt):
Text("„\(q.text)\u{201D}")
//          ↑ U+201D = rechtes schließendes Anführungszeichen "
```

---

### Bug ②: Zitat-Text — fixe 13pt kursiv, nicht zugänglich

**Datei:** `Views/StartView.swift` — `struct DailyQuoteWidget`

**Problem:** `.font(.system(size: 13).italic())` skaliert **nicht** mit der
Systemschriftgröße (Accessibility → Textgröße). 13pt kursiv ist zudem
grenzwertig lesbar.

**Fix — beide Zeilen in `DailyQuoteWidget` anpassen:**
```swift
// Zitat-Text (Vorher):
.font(.system(size: 13).italic())

// Zitat-Text (Nachher):
.font(.footnote.italic())
// .footnote = 13pt Standard, skaliert mit Dynamic Type

// Zitat-Autor (Vorher):
.font(.system(size: 12))

// Zitat-Autor (Nachher):
.font(.caption)
// .caption = 12pt Standard, skaliert mit Dynamic Type
```

> **Hinweis:** Die Farbe (`AppColor.muted`) bleibt unverändert.

---

## 2. Verbesserungen — Hierarchie & Lesbarkeit

### Verbesserung ③: Sektions-Header zu nah am Karten-Titel

**Datei:** `Views/StartView.swift` — `mainContent`, Sektions-Header-Block

**Problem:** „Nächste Termine" (17pt bold) vs. Karten-Titel (15pt bold):
nur 2pt Unterschied, beide `.bold` — der Leser erkennt keine klare Ebene.

**Fix — Sektions-Header 1pt größer, Karten-Titel zu `.semibold` degradieren:**

Im Sektions-Header (`HStack` mit `RoundedRectangle`):
```swift
// Vorher:
Text("Nächste Termine")
    .font(.system(size: 17, weight: .bold))

// Nachher:
Text("Nächste Termine")
    .font(.system(size: 18, weight: .bold))
```

In `struct AppointmentCard`, Karten-Titel:
```swift
// Vorher:
Text(appointment.trainingTypeName.isEmpty ? "Training" : appointment.trainingTypeName)
    .font(.system(size: 15, weight: .bold))

// Nachher:
Text(appointment.trainingTypeName.isEmpty ? "Training" : appointment.trainingTypeName)
    .font(.system(size: 15, weight: .semibold))
```

> Resultat: Header 18pt bold → Karte 15pt semibold — klare 2-Ebenen-Hierarchie
> durch Größe *und* Gewicht.

---

### Verbesserung ④: Begrüßungszeile zu unauffällig

**Datei:** `Views/StartView.swift` — `mainContent`, Begrüßungs-Block

**Problem:** „Guten Abend," (16pt muted regular) verschmilzt optisch mit dem
Zitat-Block darunter — beide sind muted, ähnliche Größe, kein Kontrast.

**Fix — 1pt größer + Letter-Spacing für klare Trennung:**
```swift
// Vorher:
Text(greeting)
    .font(.system(size: 16))
    .foregroundStyle(AppColor.muted)

// Nachher:
Text(greeting)
    .font(.system(size: 17))
    .foregroundStyle(AppColor.muted)
    .kerning(0.3)
```

> `kerning(0.3)` gibt der Begrüßungszeile einen eigenen Rhythmus
> gegenüber dem kursiven Zitat — ohne zusätzlichen Abstand zu brauchen.

---

## 3. Gesamtüberblick der Schriftskala nach der Änderung

| Element            | Vorher              | Nachher                    |
|--------------------|---------------------|----------------------------|
| Begrüßung          | 16pt regular muted  | 17pt regular muted +kern   |
| Name               | 28pt heavy text     | **unverändert** ✓          |
| Zitat-Text         | 13pt italic muted   | `.footnote.italic()` muted |
| Zitat-Autor        | 12pt regular muted  | `.caption` muted           |
| Sektions-Header    | 17pt bold text      | **18pt** bold text         |
| Karten-Titel       | 15pt **bold** text  | 15pt **semibold** text     |
| Karten-Details     | 12pt regular muted  | **unverändert**            |
| Datum-Zahl         | 18pt heavy primary  | **unverändert** ✓          |

---

## 4. Nicht anfassen

- Layout-Struktur (fixer Kopf / ScrollView) — bleibt unverändert
- Farben (`AppColor.*`) — keine Änderungen
- `AppointmentCard`-Layout (HStack, Datum-Bubble, Chevron) — unverändert
- `StartEmptyState` — unverändert
- Loading- und Error-Zweige — unverändert

---

## 5. Verifikation

```bash
cd client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build
```

Prüfliste:
- [ ] Build SUCCEEDED, keine neuen Warnings
- [ ] Zitat zeigt: `„Text"` (mit `"` als Schluss, **nicht** `"`)
- [ ] Zitat-Text im Simulator bei Standard-Schriftgröße: sauber lesbar
- [ ] Zitat-Text bei großem Dynamic Type (Einstellungen → Schriftgröße max): skaliert
- [ ] „Nächste Termine" deutlich prominenter als Karten-Titel (Größe + Gewicht)
- [ ] Begrüßungszeile besser vom Zitat-Block abgesetzt
- [ ] Kein Layout-Bruch / kein abgeschnittener Text

---

## 6. Ausgabeformat

```
## Änderungen
- Bug ①: StartView.swift:NN — Anführungszeichen korrigiert
- Bug ②: DailyQuoteWidget:NN — .footnote.italic() / .caption
- Verbess. ③: mainContent:NN + AppointmentCard:NN — 18pt bold / semibold
- Verbess. ④: mainContent:NN — 17pt + kerning(0.3)

## Verifikation
- Build: SUCCEEDED ja/nein
- Screenshot Zitat (Anführungszeichen sichtbar korrekt)
- Screenshot Terminliste (Header vs. Karten-Hierarchie)
- Checkliste abgehakt
```
