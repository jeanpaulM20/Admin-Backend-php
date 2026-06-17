# Feature-Prompt: Start-Screen — Zwei neue Summary-Boxen (Woche / Monat)

> **Zweck:** Agent-fertiges Prompt. Zwei kompakte Info-Boxen sollen auf dem Start-Screen
> unterhalb des Tageszitats erscheinen:
> - **Links:** „Diese Woche" — Anzahl Termine/Trainings in der laufenden Woche
> - **Rechts:** „Diesen Monat" — Anzahl Termine/Trainings im laufenden Monat
> Übergib 1:1 an einen Agenten mit Code-Zugriff.

---

## 0. Wunsch (vom Nutzer)

> „Bitte die Box wieder hinzufügen.
> Linke Box: Diese Woche → Anzahl eingetragene Termine/Training
> Rechte Box: Diesen Monat → Anzahl eingetragene Termine/Training"

---

## 1. Kontext — Ist-Zustand

Datei: `client-ios/SihlCient/SihlCient/SihlClient/Views/StartView.swift`

Der Start-Screen zeigt aktuell (von oben nach unten):
1. Begrüßung + Name (fixer Kopf)
2. `DailyQuoteWidget` (Tageszitat)
3. Sektions-Header „Nächste Termine" + Zähler
4. Scrollbare Terminliste / Leer-Zustand

Die Daten kommen aus `vm.startData?.appointments: [Appointment]`.
`Appointment` hat mindestens: `startDate: Date`, `trainingTypeName: String`.

Das `vm.startData?.appointments`-Array enthält **alle** Termine, die vom Backend
geliefert werden (Vergangenheit + Zukunft im geladenen Zeitraum). Diese Menge nutzen
wir für Woche/Monat-Zählung.

---

## 2. Auftrag an den Agenten

Füge zwei Summary-Boxen (nebeneinander, `HStack`) direkt **unterhalb** des
`DailyQuoteWidget` im **fixen Kopfbereich** (`StartView.mainContent`) ein.

**Nicht verändern:**
- Die scrollende Terminliste und `.refreshable`
- Den Sektions-Header „Nächste Termine" + `upcoming.count`
- `StartEmptyState`, `AppointmentCard`, `AppointmentDetailSheet`
- Loading- und Error-Zweige

---

## 3. Daten-Logik

Füge in `StartView` zwei berechnete Properties ein:

```swift
/// Anzahl Termine/Trainings in der laufenden Kalenderwoche (Mo–So).
private var thisWeekCount: Int {
    let cal = Calendar.current
    let now = Date()
    return (vm.startData?.appointments ?? [])
        .filter { cal.isDate($0.startDate, equalTo: now, toGranularity: .weekOfYear) }
        .count
}

/// Anzahl Termine/Trainings im laufenden Kalendermonat.
private var thisMonthCount: Int {
    let cal = Calendar.current
    let now = Date()
    return (vm.startData?.appointments ?? [])
        .filter { cal.isDate($0.startDate, equalTo: now, toGranularity: .month) }
        .count
}
```

> Hinweis: `Calendar.current` verwendet die Geräteeinstellungen (Locale). Für
> Montag-Wochenstart kann `cal.firstWeekday = 2` gesetzt werden — nur wenn das
> aktuelle `Calendar.current` nicht bereits `firstWeekday == 2` hat.

---

## 4. UI-Komponente

Füge eine neue `private struct StatBox` hinzu (kein NavigationLink, kein Button —
reine Info-Box):

```swift
private struct StatBox: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(AppColor.text)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

---

## 5. Integration in `mainContent`

Im **fixen Kopfbereich** (`VStack` außerhalb des `ScrollView`), direkt nach dem
`DailyQuoteWidget`-Block und **vor** dem Sektions-Header „Nächste Termine":

```swift
// ── Woche / Monat ─────────────────────────────────────
HStack(spacing: 12) {
    StatBox(value: thisWeekCount, label: "Diese Woche")
    StatBox(value: thisMonthCount, label: "Diesen Monat")
}
.padding(.bottom, 16)
```

Der Sektions-Header „Nächste Termine" folgt direkt darunter (mit seinem
`.padding(.bottom, 16)` zum ScrollView).

---

## 6. Vollständige Reihenfolge im fixen Kopf (nach der Änderung)

```
Begrüßung (greeting + Name)     → .padding(.bottom, 16)
DailyQuoteWidget                 → .padding(.bottom, 0)  [Widget setzt .bottom, 16 selbst]
StatBox-HStack (Woche | Monat)   → .padding(.bottom, 16)
Sektions-Header „Nächste Termine"→ .padding(.bottom, 16)
```
→ dann ScrollView (Terminliste)

---

## 7. Verifikation

```bash
cd client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build
```

Prüfliste:
- [ ] Build SUCCEEDED, keine neuen Warnings
- [ ] Start-Screen zeigt zwei Boxen: „Diese Woche" + „Diesen Monat" mit Zähler
- [ ] Zähler zeigen `0` wenn keine Daten geladen (kein Crash bei `nil`)
- [ ] Boxen werden nach Pull-to-Refresh aktualisiert (da `vm.startData` neu gesetzt)
- [ ] Fixer Kopf bleibt beim Scrollen der Terminliste stehen
- [ ] Abstände oben/unten zu Zitat und Sektions-Header ausgewogen (Screenshot)
- [ ] Kein Layout-Bruch bei großem Dynamic-Type oder langem Namen

---

## 8. Ausgabeformat

```
## Änderung
- <Diff Datei:Zeile — neue Properties + StatBox-Struct + HStack im Kopf>
## Verifikation
- Build: SUCCEEDED ja/nein
- Screenshot Start-Screen mit neuen Boxen
- Checkliste oben abgehakt
```
