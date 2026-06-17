# Feature-Prompt: Start-Screen entschlacken — zwei Summary-Boxen entfernen

> **Zweck:** Agent-fertiges Prompt. Die zwei Summary-Boxen („Nächster Termin" + „Credits")
> auf dem Start-Screen entfernen, weil sie das Bild überladen wirken lassen. Übergib 1:1 an
> einen Agenten mit Code- + Simulator-Zugriff.

---

## 0. Wunsch (vom Nutzer)

> „Die **zwei Boxen** oben auf dem Start-Screen (das Datum „Nächster Termin" und „Credits")
> **rausnehmen** — mit den zwei Boxen wirkt das Start-Bild überladen."

## 1. Analyse — exakte Fundstelle

Datei: `client-ios/SihlCient/SihlCient/SihlClient/Views/StartView.swift`

Die beiden Boxen sind der **`HStack`-Block in `mainContent`, Zeilen ~93–114**:

```swift
// ── Summary-Karten ────────────────────────────────────
HStack(spacing: 12) {
    Button { onGoToCalendar?() } label: {
        SummaryCard(icon: "calendar", value: nextApptText,
                    label: "Nächster Termin", isLink: true)
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)

    NavigationLink {
        ProfileView(scrollToCredits: true)
    } label: {
        SummaryCard(icon: "creditcard",
                    value: "\(vm.startData?.totalCredits ?? 0)",
                    label: "Credits", isLink: true)
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
}
.padding(.bottom, 28)
```

Reihenfolge im Screen: Begrüßung → Tageszitat (`DailyQuoteWidget`) → **[diese Boxen]** →
Sektion „Nächste Termine".

## 2. Auftrag an den Agenten

Entferne **nur** diesen Summary-Karten-Block. Layout/Abstände danach sauber halten, keine
anderen Bereiche verändern. Anschließend **verwaisten Code aufräumen** (siehe 3.3).

## 3. Umsetzung

**3.1 Block entfernen:** Den kompletten `HStack`-Block inkl. `.padding(.bottom, 28)` und
den Kommentar `// ── Summary-Karten ──` löschen.

**3.2 Abstände prüfen:** Nach dem Entfernen folgt direkt auf das `DailyQuoteWidget` der
Sektions-Header „Nächste Termine". Sicherstellen, dass der vertikale Abstand stimmt
(z.B. `.padding(.bottom, 24/28)` an das Tageszitat oder `.padding(.top, …)` an den Header) —
kein zu enger/zu weiter Sprung. Im Simulator visuell gegenprüfen.

**3.3 Dead Code entfernen (wenn dadurch ungenutzt):**
- `private var nextApptText: String { … }` (≈ Z.25–50) — wird **nur** von der entfernten
  Box genutzt. Prüfen (`grep nextApptText`) und entfernen, falls keine weitere Nutzung.
- `private struct SummaryCard` (≈ Z.178–216) — wird **nur** hier verwendet. Prüfen
  (`grep SummaryCard`) und entfernen, falls keine weitere Nutzung.
- `upcoming` / `selectedAppointment` etc. **nicht** anfassen — die werden von der
  „Nächste Termine"-Liste weiterhin gebraucht.

**3.4 Keine Funktion verlieren:** Die Infos bleiben anderweitig erreichbar — Termine über
Tab **Kalender** + Liste „Nächste Termine" direkt darunter; Credits über **Profil**
(Avatar oben rechts → `ProfileView`). Also kein Navigationsweg geht verloren. Nur
bestätigen, nichts Neues bauen.

## 4. Verifikation (Simulator)

```bash
cd client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build
```
Prüfen:
- [ ] Build SUCCEEDED, keine Warnungen wegen ungenutzter Symbole
- [ ] Start-Screen: Begrüßung → Tageszitat → **direkt** „Nächste Termine" (keine Boxen)
- [ ] Abstand zwischen Zitat und Sektion sieht ausgewogen aus (Screenshot)
- [ ] Credits weiterhin über Profil erreichbar, Termine über Kalender/Liste
- [ ] Kein toter Code mehr (`grep -n "SummaryCard\|nextApptText" Views/StartView.swift` leer)

## 5. Ausgabeformat
```
## Änderung
- <Diff Datei:Zeile — entfernter Block + Abstands-Anpassung + entfernter Dead Code>
## Verifikation
- Build: SUCCEEDED ja/nein
- Screenshot vorher/nachher
- Checkliste oben abgehakt
```
