# Feature-Prompt: Start-Screen — Kopfbereich fixieren, nur Termine scrollen

> **Zweck:** Agent-fertiges Prompt. Der obere Bereich des Start-Screens (Begrüßung,
> Tageszitat, Sektions-Header „Nächste Termine") soll **fixiert** bleiben; **nur die
> Terminliste** darunter scrollt. Übergib 1:1 an einen Agenten mit Code- + Simulator-Zugriff.

---

## 0. Wunsch (vom Nutzer)

> „Beim Scrollen der Termine soll der **markierte Kopfbereich fixiert** bleiben."
> (Markiert: Avatar/Titel-Zone, Begrüßung, Zitat, Header „Nächste Termine".)

## 1. Analyse — Ist-Zustand

Datei: `client-ios/SihlCient/SihlCient/SihlClient/Views/StartView.swift`, `mainContent`.

Aktuell liegt **alles** in **einem** `ScrollView { LazyVStack { … } }`: Begrüßung →
Tageszitat → Sektions-Header → Termine. Dadurch **scrollt der gesamte Kopf mit**.

## 2. Auftrag

Den Kopfbereich aus dem ScrollView herauslösen, sodass er fix steht, und nur die
Terminliste (bzw. den Leer-Zustand) scrollbar lassen. Optik/Abstände beibehalten,
Pull-to-Refresh erhalten.

## 3. Umsetzung

Struktur in `mainContent` (else-Zweig) umbauen zu:

```swift
VStack(alignment: .leading, spacing: 0) {
    // Fixer Kopf — Begrüßung, Zitat, Sektions-Header
    VStack(alignment: .leading, spacing: 0) {
        // greeting + Name (.padding(.bottom, 16))
        // DailyQuoteWidget (.padding(.bottom, 12))
        // Sektions-Header „Nächste Termine" + upcoming.count (.padding(.bottom, 16))
    }
    .padding(.horizontal, 20)
    .padding(.top, 24)

    // Scrollender Teil — NUR die Termine / Leer-Zustand
    ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
            if upcoming.isEmpty {
                StartEmptyState(onBookNow: onGoToCalendar)
            } else {
                ForEach(upcoming) { appt in
                    Button { selectedAppointment = appt } label: {
                        AppointmentCard(appointment: appt)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 10)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
    .refreshable { if let id = auth.clientId { await vm.load(clientId: id) } }
}
```

Hinweise:
- `.refreshable` an den **ScrollView** (Liste) hängen — Pull-to-Refresh dann über der Liste.
- Horizontale 20pt-Polsterung auf **beide** Teile, damit Kopf und Liste bündig sind.
- Der Sektions-Header bleibt im fixen Teil (inkl. `upcoming.count`), seine
  `.padding(.bottom, 16)` erzeugt den Abstand zur scrollenden Liste.
- **Alternative (nur falls gewünscht):** „sticky section header" via
  `ScrollView { LazyVStack(pinnedViews: .sectionHeaders) { Section { … } header: { … } } }`.
  Pinnt den Header erst beim Hochscrollen an die Oberkante — anderes Verhalten als ein
  immer-fixer Kopf. Default ist der oben gezeigte feste Kopf.

## 4. Verifikation (Simulator/Gerät)

```bash
cd client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build
```
(Start-Screen braucht Login; sonst Mock-Harness wie in `TAP-DIAGNOSE-Analytics.md`.)

Prüfen:
- [ ] Beim Scrollen der Termine bleiben Begrüßung, Zitat und „Nächste Termine"-Header **fix**
- [ ] Nur die Terminkarten bewegen sich
- [ ] Kopf und Liste sind horizontal bündig (20pt)
- [ ] Pull-to-Refresh funktioniert weiter
- [ ] Leer-Zustand (`StartEmptyState`) wird korrekt im Scrollbereich angezeigt
- [ ] Screenshot vorher/nachher

## 5. Ausgabeformat
```
## Änderung
- <Diff Datei:Zeile — Aufteilung fixer Kopf / scrollende Liste>
## Verifikation
- Build: SUCCEEDED ja/nein
- Screenshot/Video vorher-nachher (Scroll-Verhalten)
- Checkliste abgehakt
```
