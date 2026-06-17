# Feature-Prompt: Training-Screen — Hero-Banner-Bild (Querformat)

> **Zweck:** Agent-fertiges Prompt. Zwischen dem Navigations-Titel „Training" und der
> Trainingsplan-Liste soll ein **Querformat-Banner-Bild** erscheinen.
> Das Bild „Slackline Walking (Vorwärts/rückwärts)" kommt direkt aus dem
> Backend-Trainingskatalog — kein Asset-Bundle nötig.
> Übergib 1:1 an einen Agenten mit Code-Zugriff.

---

## 0. Wunsch (vom Nutzer)

> „Bitte füge ein Bild zwischen Header und Training ein — Bild in Querformat.
> Die Bildgröße so platzieren, dass es optisch ideal passt.
> Verwende das Bild 'Slackline Walking (Vorwärts/rückwärts)' aus dem Trainingskatalog."

---

## 1. Ist-Zustand & Datenfluss

**Datei:** `client-ios/SihlCient/SihlCient/SihlClient/Views/TrainingListView.swift`

Die `content`-View listet im `ScrollView > LazyVStack`:
1. `subscriptionBanner`
2. `errorBox` (optional)
3. `ForEach(vm.plans)` — Trainingspläne

Der Bereich zwischen Nav-Titel und den Karten ist aktuell leer.

**Bild-Quelle:**
`TrainingPlanViewModel.exerciseIconURLs` ist `[String: URL]` und wird beim `fetch()`
automatisch befüllt. Die URL wird gebaut als:
```
APIConfig.baseURL / api/exercise/{id}/icon.png
```
Der Key ist der exakte Übungs-Name aus der Datenbank.

→ Die Banner-URL lautet:
```swift
vm.exerciseIconURLs["Slackline Walking (Vorwärts/rückwärts)"]
```

Kein neues Asset-Catalog-Eintrag notwendig — `AsyncImage` lädt direkt vom Backend.

---

## 2. Auftrag

1. **`TrainingHeroBanner`** als `private struct` implementieren
2. Banner in `content` als erstes Element einfügen (vor `subscriptionBanner`)
3. Fallback-Zustand wenn URL noch nicht geladen / Übungsname nicht gefunden

---

## 3. Implementierung — `TrainingHeroBanner`

Füge am Ende von `TrainingListView.swift`, **vor** `TrialSheet`, ein:

```swift
// MARK: - Hero Banner

private struct TrainingHeroBanner: View {
    let imageURL: URL?

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let url = imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            bannerPlaceholder
                        case .empty:
                            // Lade-Zustand: dezenter Shimmer-Ersatz
                            AppColor.surface
                        @unknown default:
                            bannerPlaceholder
                        }
                    }
                } else {
                    bannerPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 185)
            .clipped()

            // Dunkler Verlauf — weicher Übergang zum App-Hintergrund
            LinearGradient(
                colors: [.clear, AppColor.background.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var bannerPlaceholder: some View {
        ZStack {
            AppColor.surface
            VStack(spacing: 8) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 38))
                    .foregroundStyle(AppColor.primary.opacity(0.45))
                Text("Slackline Walking")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColor.muted)
            }
        }
    }
}
```

**Begründung der Maße:**
| Parameter | Wert | Grund |
|---|---|---|
| `height: 185` | 185pt | Bei ~390pt Breite → Verhältnis ≈ 2.1:1 (klassisches Querformat-Banner) |
| `padding(.horizontal, 16)` | 16pt | Bündig mit den Trainingskarten darunter |
| `padding(.top, 16)` | 16pt | Gleicher Abstand wie `subscriptionBanner` |
| `cornerRadius: 10` | 10pt | Minimal größer als Karten (8pt) — Banner steht visuell darüber |
| Gradient-Höhe | 100pt | Deckt untere 54% ab — sanfter Übergang, kein harter Schnitt |
| `scaledToFill` | — | Füllt die Bannerbreite; Überschuss oben/unten wird abgeschnitten |

---

## 4. Integration in `content`

In `TrainingListView`, `content`-Property, im `LazyVStack`:

```swift
// Vorher:
LazyVStack(spacing: 0) {
    subscriptionBanner
    if let err = vm.error { errorBox(err) }
    ...
}

// Nachher:
LazyVStack(spacing: 0) {
    TrainingHeroBanner(
        imageURL: vm.exerciseIconURLs["Slackline Walking (Vorwärts/rückwärts)"]
    )
    subscriptionBanner
    if let err = vm.error { errorBox(err) }
    ...
}
```

Der Banner erscheint **immer** — unabhängig von Abo-Status, Lade-Zustand oder Fehler.
Wenn die URL noch nicht geladen ist (erster Frame), zeigt `AsyncImage` den
`.empty`-Zustand (dezenter dunkler Block) und wechselt automatisch zum Bild
sobald `vm.exerciseIconURLs` befüllt ist.

---

## 5. Vollständige Reihenfolge nach der Änderung

```
ScrollView
  └─ LazyVStack
       ├─ TrainingHeroBanner        ← Querformat-Bild, AsyncImage vom Backend
       ├─ subscriptionBanner        ← nur bei fehlendem Abo
       ├─ errorBox                  ← nur bei API-Fehler
       └─ planCards / emptyState
```

---

## 6. Nicht anfassen

- `subscriptionBanner`, `planCard`, `emptyState`, `TrialSheet` — unverändert
- `TrainingPlanViewModel.fetch()` — bereits lädt `exerciseIconURLs`, keine Änderung nötig
- `Assets.xcassets` — keine neuen Einträge nötig
- Alle `AppColor.*` Zuweisungen

---

## 7. Verifikation

```bash
cd client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build
```

Prüfliste (im Simulator nach Login):
- [ ] Build SUCCEEDED
- [ ] Training-Tab: Querformat-Banner über den Trainingskarten sichtbar
- [ ] Kurz nach dem Laden erscheint das Slackline-Walking-Bild (`AsyncImage` geladen)
- [ ] Gradient am unteren Rand weich (kein harter Schnitt zum Hintergrund)
- [ ] Banner und Karten horizontal bündig (beide 16pt Padding)
- [ ] Abo-Banner erscheint korrekt darunter (falls kein aktives Abo)
- [ ] Ohne Netz / falscher Übungsname → Fallback-Placeholder sichtbar (kein Crash)
- [ ] Pull-to-Refresh aktualisiert die Terminliste; Banner bleibt unverändert

---

## 8. Ausgabeformat

```
## Änderungen
- TrainingListView.swift: TrainingHeroBanner struct (Zeile NN–NN)
- TrainingListView.swift: content — TrainingHeroBanner(imageURL:) eingefügt (Zeile NN)

## Verifikation
- Build: SUCCEEDED ja/nein
- Screenshot Training-Screen (Banner sichtbar mit echtem Bild oder Placeholder)
- Checkliste abgehakt
```
