# Typografie-Prompt: App-weite Vereinheitlichung (SihlCient iOS)

> **Zweck:** Agent-fertiges Prompt. Die Start-Screen-Typografie wird als Vorlage für
> alle Views der App verwendet. Ziel ist ein einheitliches visuelles Bild.
> Kein Layout-Umbau, keine Funktionsänderung — nur Schriftgrade und -gewichte.
> Übergib 1:1 an einen Agenten mit Code-Zugriff.

---

## 0. Kontext & Vorlage

**Vorlage:** `StartView.swift` (nach TYPOGRAPHY-PROMPT-Start.md angepasst).
Die dort verwendeten Größen und Gewichte gelten ab jetzt als **Typografie-Skala**.

---

## 1. Definierte Typografie-Skala

| Rolle           | Größe · Gewicht     | Verwendung                                      |
|-----------------|---------------------|-------------------------------------------------|
| Hero            | 28pt · .heavy       | Name/Fokuspunkt — einmal pro Screen             |
| Screen Title    | 22pt · .bold        | Profilname, Haupt-Sheet-Titel                   |
| Section Header  | **18pt · .bold**    | Alle Sektions-Überschriften in Listen/Screens   |
| Headline        | 16pt · .bold        | Banner-Titel, Empty-State-Titel                 |
| Body Strong     | **15pt · .semibold**| Karten-Titel, Listen-Einträge (Primärtext)      |
| Body            | 14pt · .regular     | Detail-Werte, Sheet-Felder                      |
| Label           | 13pt · .regular     | Feld-Labels, Datumstexte, Beschreibungen        |
| Caption         | 12pt · .regular     | Timestamps, Zähler, Metadaten                   |
| Micro           | 11pt · .medium      | Chips, kompakte Badges                          |

**Faustregel:**
- Alles was eine **Sektion einleitet** → **18pt bold**
- Alles was ein **Listen-/Karten-Element benennt** → **15pt semibold**
- Kein `bold` unterhalb von Sektions-Ebene außer bei absoluten Ausnahmen (Timer, Badges)

---

## 2. Änderungen je View

### 2.1 `AnalyticsView.swift`

**Section Headers — alle auf 18pt bold vereinheitlichen:**

```swift
// Zeile ~115 (Performance-Sektion Titel)
// Vorher: .font(.system(size: 15, weight: .bold))
// Nachher:
.font(.system(size: 18, weight: .bold))

// Zeile ~265 (Herzfrequenz-Header "Herzfrequenz")
// Vorher: .font(.system(size: 15, weight: .bold))
// Nachher:
.font(.system(size: 18, weight: .bold))

// Zeile ~556 (Detail-View "Verlauf")
// Vorher: .font(.system(size: 17, weight: .bold))
// Nachher:
.font(.system(size: 18, weight: .bold))

// Zeile ~626 (Detail-View "Messwerte")
// Vorher: .font(.system(size: 17, weight: .bold))
// Nachher:
.font(.system(size: 18, weight: .bold))
```

**Review-Zeilen-Titel — Body Strong:**
```swift
// Zeile ~426 (Review-Typ-Titel in der Liste)
// Vorher: .font(.system(size: 13, weight: .semibold))
// Nachher:
.font(.system(size: 15, weight: .semibold))

// Zeile ~435 (HR-Max-Wert-Label in Review-Zeile)
// Vorher: .font(.system(size: 13, weight: .semibold))
// Nachher:
.font(.system(size: 14, weight: .semibold))  // Sekundärwert: Body
```

**Chart/Detail-Header — Headline:**
```swift
// Zeile ~782 (HR-Chart-Header "HR-Verlauf" in TrainingReviewDetailView)
// Vorher: .font(.system(size: 14, weight: .bold))
// Nachher:
.font(.system(size: 16, weight: .bold))

// Zeile ~1117 (Compare-Landscape HR-Header)
// Vorher: .font(.system(size: 14, weight: .bold))
// Nachher:
.font(.system(size: 16, weight: .bold))
```

---

### 2.2 `CalendarView.swift`

**Monatstitel — Section Header:**
```swift
// Zeile ~217 (Monats-/Jahres-Titel im Kalender-Grid)
// Vorher: .font(.system(size: 16, weight: .bold))
// Nachher:
.font(.system(size: 18, weight: .bold))
```

**Event-Titel in Terminliste — Body Strong:**
```swift
// Zeile ~353 (Training-Typ-Name im Termin-Eintrag)
// Vorher: .font(.system(size: 14, weight: .bold))
// Nachher:
.font(.system(size: 15, weight: .semibold))
```

**Sheet-Header — Screen Title:**
```swift
// Zeile ~501 ("Termin buchen" Sheet-Titel) → bereits 18pt bold ✓ — nicht anfassen
// Zeile ~640 (AppointmentDetailSheet Titel) → bereits 18pt bold ✓ — nicht anfassen
```

**Slot-Header:**
```swift
// Zeile ~411 ("Verfügbare Slots" Label)
// Vorher: .font(.system(size: 12, weight: .semibold))
// Nachher:
.font(.system(size: 13, weight: .semibold))  // Label-Ebene
```

**Datum-Header über Terminliste:**
```swift
// Zeile ~127 (Ausgewähltes-Datum-Label "Mo, 18. Jun.")
// Vorher: .font(.system(size: 15, weight: .semibold))
// Nachher:
.font(.system(size: 15, weight: .semibold))  // Body Strong — bereits korrekt ✓
```

---

### 2.3 `ChatView.swift`

**Empty State Icon — vereinheitlichen:**
```swift
// Zeile ~69 (Leerer Posteingang Icon)
// Vorher: .font(.system(size: 48))
// Nachher:
.font(.system(size: 44))
```

**Konversations-Namen — Body Strong:**
```swift
// Zeile ~121 (Trainer-Name in Konversationsliste)
// Vorher: .font(.system(size: 15, weight: .semibold))
// → bereits korrekt ✓ — nicht anfassen
```

**Data-Card Label:**
```swift
// Zeile ~400 (Daten-Karte Label, z.B. "Trainingseinheit")
// Vorher: .font(.system(size: 13, weight: .semibold))
// → Label-Ebene — korrekt ✓
```

---

### 2.4 `ProfileView.swift`

**Section Titles — Section Header:**
```swift
// Zeile ~329 (ExpandableSection Titel, z.B. "Credits", "Rechnungen")
// Vorher: .font(.system(size: 15, weight: .bold))
// Nachher:
.font(.system(size: 18, weight: .bold))
```

**Sheet-Titel — Screen Title:**
```swift
// Zeile ~474 (Rechnungs-Sheet-Titel)
// Vorher: .font(.system(size: 17, weight: .heavy))
// Nachher:
.font(.system(size: 18, weight: .bold))
// heavy → bold: konsistent mit allen anderen Sheet-Titeln
```

**Credits-Pack-Titel — Body Strong:**
```swift
// Zeile ~376 (Credit-Pack-Name)
// Vorher: .font(.system(size: 14, weight: .bold))
// Nachher:
.font(.system(size: 15, weight: .semibold))
```

**"Credits kaufen" Zeile:**
```swift
// Zeile ~186 ("Credits kaufen" Aktions-Zeile Titel)
// Vorher: .font(.system(size: 15, weight: .bold))
// Nachher:
.font(.system(size: 15, weight: .semibold))
```

**Rechnungs-Betrag:**
```swift
// Zeile ~441 (Rechnungs-Betrag, Primärinfo)
// Vorher: .font(.system(size: 15, weight: .bold))
// Nachher:
.font(.system(size: 15, weight: .semibold))
```

---

### 2.5 `TrainingListView.swift`

**Banner-Titel — Section Header:**
```swift
// Zeile ~52 (Plan-Banner-Titel)
// Vorher: .font(.system(size: 16, weight: .bold))
// Nachher:
.font(.system(size: 18, weight: .bold))
```

**Plan-Name in Liste — Body Strong:**
```swift
// Zeile ~156 (Trainingsplan-Name)
// Vorher: .font(.system(size: 15, weight: .bold))
// Nachher:
.font(.system(size: 15, weight: .semibold))
```

**Empty State Icon:**
```swift
// Zeile ~227 und ~262 (Leer-Zustand / Gesperrt-Zustand Icons)
// Vorher: .font(.system(size: 48))
// Nachher:
.font(.system(size: 44))
```

**Empty State Titel — Headline:**
```swift
// Zeile ~230, ~265 (Leer/Gesperrt Titel)
// Vorher: .font(.system(size: 16, weight: .bold))
// → bereits Headline-Ebene ✓ — nicht anfassen
```

---

### 2.6 `TrainingDetailView.swift`

**Exercise-Name — Body Strong:**
```swift
// Zeile ~237 (Übungs-Name in der Trainings-Liste)
// Vorher: .font(.system(size: 14, weight: .semibold))
// Nachher:
.font(.system(size: 15, weight: .semibold))
```

**Kommentar-Sheet-Titel — Screen Title:**
```swift
// Zeile ~511 ("Kommentare" Sheet-Titel)
// Vorher: .font(.system(size: 15, weight: .bold))
// Nachher:
.font(.system(size: 18, weight: .bold))
```

**Section Tabs** (Zeile ~115) — **nicht anfassen**: Tab-Labels bleiben bei 12pt,
da Tab-Navigation eigene Hierarchie-Ebene hat.

**Timer-Display** (Zeile ~154, 52pt monospaced) — **nicht anfassen**: Funktionselement.

---

## 3. Nicht anfassen

- `LoginView.swift` — eigenständiger Screen, andere visuelle Logik (Splash-Charakter)
- `MainTabView.swift` — Tab-Bar-System-Fonts
- Alle `AppColor.*` Zuweisungen — Farben bleiben unverändert
- Chart-Achsenbeschriftungen (12pt) — technische Elemente, nicht Content-Typografie
- Timer-Display (`TrainingDetailView`, 52pt monospaced)
- Icon-Fonts (SF Symbols in `.font(.system(size:))`) die als Icons dienen — nur Text-Elemente anpassen
- Loading/Error-Zustände (14pt + 40pt Icon) — bereits konsistent über alle Views ✓

---

## 4. Zusammenfassung der Änderungen

| Was                  | Vorher          | Nachher          | Views betroffen        |
|----------------------|-----------------|------------------|------------------------|
| Section Headers      | 15–17pt bold    | **18pt bold**    | Analytics, Profile, Training, Calendar |
| Karten-/Listen-Titel | 14–15pt bold    | **15pt semibold**| Analytics, Calendar, Profile, Training |
| Empty-State Icons    | 48pt            | **44pt**         | Chat, Training         |
| Sheet-Titel          | 15–17pt         | **18pt bold**    | Profile, Training      |
| Exercise-Name        | 14pt semibold   | **15pt semibold**| TrainingDetail         |

**Gesamtzahl der Anpassungen: ~26 Stellen in 6 View-Dateien**

---

## 5. Verifikation

```bash
cd client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build
```

Prüfliste:
- [ ] Build SUCCEEDED, keine neuen Warnings
- [ ] Sektions-Header in allen Views visuell gleichwertig zu „Nächste Termine" (Start)
- [ ] Karten-Titel überall gleich prominent (15pt semibold)
- [ ] Sheet-Titel (Termin buchen, Kommentare, Rechnungen) einheitlich
- [ ] Empty-State-Icons in Chat + Training kleiner als vorher (44pt statt 48pt)
- [ ] Start-Screen als Vergleichs-Referenz — kein visueller Unterschied zur Baseline

---

## 6. Ausgabeformat

```
## Änderungen
- AnalyticsView.swift: N Stellen (Section Headers, Review-Titel, Chart-Header)
- CalendarView.swift: N Stellen (Monatstitel, Event-Titel)
- ChatView.swift: N Stellen (Icon)
- ProfileView.swift: N Stellen (Section-Titel, Sheet-Titel, Pack-Titel)
- TrainingListView.swift: N Stellen (Banner, Plan-Name, Icons)
- TrainingDetailView.swift: N Stellen (Exercise-Name, Sheet-Titel)

## Verifikation
- Build: SUCCEEDED ja/nein
- Screenshots (je 1 pro View — Fokus auf Section Header + Karten-Titel)
- Checkliste abgehakt
```
