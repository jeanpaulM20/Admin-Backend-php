# Feature-Prompt: Training-Banner — Korrektes Übungsbild aus Trainingskatalog

> **Zweck:** Agent-fertiges Prompt.
> (1) Sofort-Fix: Falscher Übungsname → Banner zeigt Placeholder statt Bild.
> (2) Robuste Lösung: Konfigurierbarer Banner-Name mit Fuzzy-Matching, damit ein
>     Tippfehler nie wieder zum Placeholder führt.
> Übergib 1:1 an einen Agenten mit Code-Zugriff.

---

## 0. Problem

**Datei:** `client-ios/SihlCient/SihlCient/SihlClient/Views/TrainingListView.swift`

Der `TrainingHeroBanner` verwendet:
```swift
imageURL: vm.exerciseIconURLs["Slackline Walking (Vorwärts/rückwärts)"]
```

Der exakte Name im Trainingskatalog (Backend-Datenbank / `api/exercise`) lautet jedoch:
```
"Slackline Walking (vorwärts/rückwärts)"
                    ↑ klein              ↑ klein
```

→ `Dictionary`-Lookup schlägt fehl → `nil` → `AsyncImage` nicht aufgerufen →
Fallback-Placeholder statt echtem Bild.

**Quelle des richtigen Namens:** `test-plan-athletik-client23.json`, Zeile mit
`"exercise": "Slackline Walking (vorwärts/rückwärts)"`.

---

## 1. Sofort-Fix (1 Zeile)

In `TrainingListView.content`, `LazyVStack`:

```swift
// Vorher (falsch — Großbuchstaben V und R):
TrainingHeroBanner(
    imageURL: vm.exerciseIconURLs["Slackline Walking (Vorwärts/rückwärts)"]
)

// Nachher (korrekt):
TrainingHeroBanner(
    imageURL: vm.exerciseIconURLs["Slackline Walking (vorwärts/rückwärts)"]
)
```

---

## 2. Robuste Lösung — Fuzzy-Matching + konfigurierbarer Name

Damit ein Tippfehler oder eine Backend-Umbenennung nicht erneut zum leeren Banner führt,
soll der Lookup **case-insensitive + contains** funktionieren.

### 2.1 Hilfsfunktion in `TrainingListView`

```swift
/// Sucht die Banner-URL mit case-insensitivem Teilstring-Match.
/// Gibt nil zurück wenn kein Eintrag passt.
private func bannerURL(containing keyword: String) -> URL? {
    let lower = keyword.lowercased()
    guard let matchedKey = vm.exerciseIconURLs.keys.first(where: {
        $0.lowercased().contains(lower)
    }) else { return nil }
    return vm.exerciseIconURLs[matchedKey]
}
```

### 2.2 Verwendung im `content`-LazyVStack

```swift
TrainingHeroBanner(
    imageURL: bannerURL(containing: "slackline walking")
)
```

**Warum `"slackline walking"` als Keyword:**
- Trifft `"Slackline Walking (vorwärts/rückwärts)"` ✓
- Trifft auch zukünftige Varianten wie `"Slackline Walking Balance"` ✓
- Trifft nicht `"Slackline Grundposition"` (anderer Übungstyp) ✓

> Falls mehrere Übungen den Begriff enthalten, gibt `.first(where:)` die erste
> alphabetisch geladene zurück — für den Banner akzeptabel.

---

## 3. Vollständige geänderte `content`-Stelle

```swift
// In TrainingListView.content:
LazyVStack(spacing: 0) {
    TrainingHeroBanner(
        imageURL: bannerURL(containing: "slackline walking")   // ← Fuzzy-Match
    )
    subscriptionBanner
    if let err = vm.error { errorBox(err) }
    if vm.plans.isEmpty {
        emptyState
    } else {
        ForEach(vm.plans) { plan in
            planCard(plan)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}
```

---

## 4. Wie das Banner-Bild in Zukunft gewechselt wird

Um ein anderes Übungsbild als Banner zu verwenden, nur das Keyword anpassen:

| Gewünschtes Bild | Keyword |
|---|---|
| Slackline Walking | `"slackline walking"` |
| Einbeinstand | `"einbeinstand"` |
| Kniebeuge | `"kniebeuge"` |
| Beliebig | Teilstring des Übungsnamens aus `api/exercise` |

Der Agent muss bei einer Änderung nur das Keyword in `bannerURL(containing:)` tauschen.

---

## 5. Verifikation

```bash
cd client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build
```

Auf dem Gerät (nach Re-Deploy):
- [ ] Build SUCCEEDED
- [ ] Training-Tab: Slackline-Walking-Bild erscheint im Banner (kein Placeholder mehr)
- [ ] Gradient am unteren Rand sichtbar
- [ ] Bei schlechter Verbindung: Fallback-Placeholder erscheint (kein Crash)

---

## 6. Ausgabeformat

```
## Änderungen
- TrainingListView.swift:NN — bannerURL(containing:) Hilfsfunktion eingefügt
- TrainingListView.swift:NN — TrainingHeroBanner Aufruf auf Fuzzy-Match umgestellt

## Verifikation
- Build: SUCCEEDED ja/nein
- Screenshot Training-Tab: echtes Slackline-Bild sichtbar
- Checkliste abgehakt
```
