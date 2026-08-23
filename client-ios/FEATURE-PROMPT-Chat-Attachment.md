# FEATURE-PROMPT — Chat Anhang: Analyse & Anpassung an Flutter-Vorlage

Datei: `SihlClient/Views/ChatView.swift`
Referenz: `client-flutter/lib/screens/chat_screen.dart`

Die Anhang-Funktion im SwiftUI-Chat weicht visuell und inhaltlich von der Flutter-Vorlage ab.
Dieser Prompt beschreibt **alle Unterschiede** und die konkreten Kode-Änderungen.

---

## Zusammenfassung der Abweichungen

| # | Bereich | Flutter (Soll) | SwiftUI (Ist) |
|---|---|---|---|
| 1 | AttachPickerSheet — Icon-Farbe | Farbige Icon-Box je Kategorie | Alle gleich `AppColor.primary` |
| 2 | Daten-Karte im Thread — Farbe | Semantisch: rot/grün/blau/orange | Alle gleich `AppColor.primary` |
| 3 | Daten-Karte — Touch-Hinweis | „Antippen für Details" + Icon | Nur `chevron.right`, kein Text |
| 4 | PerformanceDetailSheet | Alle Metriken aufgelistet | Nur Typ + Datum — Metriken fehlen |
| 5 | ReviewDetailSheet — TRIMP | Farbkodiertes Rating-Label | Nur Zahlenwert, kein Rating |
| 6 | ReviewDetailSheet — Dauer | `duration` angezeigt | `duration` vorhanden aber nicht angezeigt |
| 7 | MetricsDetailSheet | Gewicht + BMI + KF% + Ruhepuls | Nur Gewicht + KF% (BMI fehlt) |
| 8 | Gesendetes Nachrichtenformat | Strukturiert mit Datum + Kennzahlen | Nur Tag + Typ |

---

## Fix 1 — AttachPickerSheet: Farbige Icon-Hintergründe

**Datei:** `ChatView.swift` — `private struct AttachPickerSheet` (ca. Zeile 570–612)

**Ist:**
```swift
private func attachRow(_ icon: String, _ title: String, _ sub: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppColor.primary)
                .frame(width: 36)
            // ...
        }
    }
}
```

**Soll:** Die Funktion bekommt einen zusätzlichen `color: Color`-Parameter. Das Icon wird in einem farbigen 36×36-Box dargestellt (wie Flutter: 38×38).

```swift
private func attachRow(_ icon: String, _ title: String, _ sub: String,
                        color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(AppColor.text)
                Text(sub).font(.system(size: 12)).foregroundStyle(AppColor.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(AppColor.muted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    .buttonStyle(.plain)
}
```

**Aufrufe anpassen** (in `body`):
```swift
attachRow("heart.text.square", "Training Aufzeichnung", "HR-Daten & TRIMP",
           color: AppColor.red,   action: onReview)
Divider().background(AppColor.border).padding(.leading, 70)
attachRow("chart.bar.fill", "Leistungstest", "Kraft & Kondition",
           color: AppColor.green, action: onPerf)
Divider().background(AppColor.border).padding(.leading, 70)
attachRow("scalemass", "Körpermessung", "Gewicht · BMI · Körperfett",
           color: AppColor.blue,  action: onMetrics)
```

---

## Fix 2 — MessageBubble.dataCard: Semantische Icon-Farben

**Datei:** `ChatView.swift` — `private var dataCard` + `private func cardMeta` (ca. Zeile 432–468)

**Ist:** `cardMeta` gibt nur `(String, String)` zurück (Icon-Name + Label). Die Icon-Farbe ist immer `AppColor.primary`.

**Soll:** `cardMeta` gibt `(icon: String, label: String, color: Color)` zurück, damit jede Karte ihre eigene Farbe bekommt.

```swift
private func cardMeta(_ text: String) -> (icon: String, label: String, color: Color) {
    if text.hasPrefix("[Aufzeichnung]")    { return ("heart.text.square",  "Training Aufzeichnung", AppColor.red)    }
    if text.hasPrefix("[Performance]")     { return ("chart.bar.fill",     "Leistungstest",         AppColor.green)  }
    if text.hasPrefix("[Messwerte]")       { return ("scalemass",           "Körpermessung",         AppColor.blue)   }
    if text.hasPrefix("[TRAINING_REPORT]") { return ("doc.text.fill",      "Trainingsreport",       AppColor.orange) }
    return ("doc", "Datei", AppColor.muted)
}
```

**`dataCard` anpassen:**
```swift
private var dataCard: some View {
    let meta = cardMeta(msg.text)
    return HStack(spacing: 10) {
        Image(systemName: meta.icon)
            .font(.system(size: 18))
            .foregroundStyle(meta.color)
            .frame(width: 36, height: 36)
            .background(meta.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
        VStack(alignment: .leading, spacing: 2) {
            Text(meta.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.text)
            Text(cardDetail(msg.text))
                .font(.system(size: 12))
                .foregroundStyle(AppColor.muted)
                .lineLimit(1)
            // Fix 3: Touch-Hinweis
            HStack(spacing: 3) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 10))
                Text("Antippen für Details")
                    .font(.system(size: 11))
            }
            .foregroundStyle(AppColor.muted.opacity(0.7))
        }
        Spacer()
        Image(systemName: "chevron.right")
            .font(.system(size: 12))
            .foregroundStyle(AppColor.muted)
    }
    .padding(10)
    .background(AppColor.surface)
    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
    .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).stroke(AppColor.border, lineWidth: 1))
    .frame(maxWidth: 280)
}
```

> **Prüfen:** Ob `AppColor.red`, `.green`, `.blue`, `.orange` in `Theme.swift` vorhanden sind.
> Falls noch nicht, hinzufügen analog zu `AppColor.primary`.

---

## Fix 3 — ReviewDetailSheet: TRIMP-Rating + Dauer anzeigen

**Datei:** `ChatView.swift` — `private struct ReviewRow` (ca. Zeile 695–745)

**Ist:** Zeigt `trainingType`, `hrAvg`, `hrMax`, `edwardsTrimp` als Zahl, `date`.
`duration` und `trimpRating` sind im Model vorhanden, werden aber NICHT angezeigt.

**Soll:**
1. `duration` als Zeile anzeigen (wenn vorhanden)
2. TRIMP als Zahl + farbkodiertes Rating-Label

```swift
var body: some View {
    HStack(spacing: 12) {
        // Linke Spalte: Icon-Box (wie Flutter: 48x48, rot)
        Image(systemName: "heart.text.square")
            .font(.system(size: 22))
            .foregroundStyle(AppColor.red)
            .frame(width: 44, height: 44)
            .background(AppColor.red.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))

        VStack(alignment: .leading, spacing: 4) {
            Text(review.trainingType.isEmpty ? "Training" : review.trainingType)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColor.text)

            // Dauer (wenn vorhanden)
            if let dur = review.duration, !dur.isEmpty {
                statLabel("Dauer", dur)
            }

            // HR-Stats
            HStack(spacing: 10) {
                if let avg = review.hrAvg  { statLabel("HFø", "\(avg)") }
                if let max = review.hrMax  { statLabel("HFmax", "\(max)") }
                if let t = review.edwardsTrimp {
                    statLabel("TRIMP", "\(Int(t))")
                    trimpBadge(t)
                }
            }

            Text(dateStr)
                .font(.system(size: 12))
                .foregroundStyle(AppColor.muted)
        }
        Spacer()
        Button(action: onShare) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16))
                .foregroundStyle(AppColor.primary)
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(AppColor.background)
}

// TRIMP-Badge mit Ampelfarbe
private func trimpBadge(_ trimp: Double) -> some View {
    let label = TrainingReview.trimpRating(trimp)
    let color: Color
    switch label {
    case "Leicht":    color = AppColor.green
    case "Moderat":   color = Color(hue: 0.22, saturation: 0.7, brightness: 0.75)
    case "Mittel":    color = AppColor.orange
    case "Hart":      color = Color(hue: 0.07, saturation: 0.9, brightness: 0.85)
    default:          color = AppColor.red  // Sehr Hart / Extrem
    }
    return Text(label)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 4))
}
```

---

## Fix 4 — PerformanceDetailSheet: Metriken aufklappen

**Datei:** `ChatView.swift` — `private func perfRow` (ca. Zeile 812–835)

Das Model `PerformanceTest` enthält `metrics: [String: String]` — ein Dictionary mit allen Einzelwerten.
Aktuell wird dieses Dictionary **nicht angezeigt**. Flutter zeigt alle vorhandenen Metriken mit Icons.

**Soll:** Nach dem Test-Typ/Datum die nicht-leeren Metriken anzeigen.

Icon-Mapping für bekannte Schlüssel (entspricht Flutter):
```
"punkte"          → "star.fill"            grün
"liegestuetz"     → "dumbbell.fill"        blau
"klimmzuege"      → "figure.strengthtraining.traditional" grün
"unterarmstuetz"  → "timer"                orange
"seitstuetz"      → "timer"                orange
"kniebeuge"       → "figure.walk"          blau
"rumpfbeuge"      → "figure.flexibility"   grün
"sensomotorik"    → "brain.head.profile"   blau
"symmetrie"       → "align.horizontal.center" grün
"reaktion"        → "bolt.fill"            orange
"cmj"             → "arrow.up.circle"      rot
"tapping"         → "hand.tap"             blau
"sprint_10"       → "figure.run"           grün
"sprint_20"       → "figure.run"           grün
"sprint_30"       → "figure.run"           grün
```

**Erweiterter `perfRow`:**
```swift
private func perfRow(_ test: PerformanceTest) -> some View {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "dd.MM.yyyy"

    return VStack(alignment: .leading, spacing: 0) {
        // Header-Zeile
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppColor.green)
                .frame(width: 40, height: 40)
                .background(AppColor.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(test.testType.isEmpty ? "Leistungstest" : test.testType)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.text)
                Text(f.string(from: test.testDate))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColor.muted)
            }
            Spacer()
            Button { onShare(test); dismiss() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        // Metriken-Grid (nur nicht-leere Werte)
        if !test.metrics.isEmpty {
            let sorted = test.metrics.sorted { $0.key < $1.key }
                .filter { !$0.value.isEmpty && $0.value != "0" }
            if !sorted.isEmpty {
                VStack(spacing: 0) {
                    ForEach(sorted, id: \.key) { key, value in
                        HStack {
                            Image(systemName: perfIcon(for: key))
                                .font(.system(size: 14))
                                .foregroundStyle(perfColor(for: key))
                                .frame(width: 20)
                            Text(perfLabel(for: key))
                                .font(.system(size: 13))
                                .foregroundStyle(AppColor.text)
                            Spacer()
                            Text(value)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColor.text)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColor.surface.opacity(0.5))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
}

// Hilfsfunktionen für Metriken-Anzeige
private func perfIcon(for key: String) -> String {
    switch key.lowercased() {
    case "punkte":         return "star.fill"
    case "liegestuetz":    return "dumbbell.fill"
    case "klimmzuege":     return "figure.strengthtraining.traditional"
    case "unterarmstuetz", "seitstuetz": return "timer"
    case "kniebeuge":      return "figure.walk"
    case "rumpfbeuge":     return "figure.flexibility"
    case "sensomotorik":   return "brain.head.profile"
    case "symmetrie":      return "align.horizontal.center"
    case "reaktion":       return "bolt.fill"
    case "cmj":            return "arrow.up.circle.fill"
    case "tapping":        return "hand.tap"
    case let k where k.hasPrefix("sprint"): return "figure.run"
    default:               return "circle.fill"
    }
}

private func perfColor(for key: String) -> Color {
    switch key.lowercased() {
    case "punkte":         return AppColor.green
    case "cmj":            return AppColor.red
    case "unterarmstuetz", "seitstuetz", "reaktion": return AppColor.orange
    default:               return AppColor.blue
    }
}

private func perfLabel(for key: String) -> String {
    switch key.lowercased() {
    case "punkte":         return "Punkte"
    case "liegestuetz":    return "Liegestütz"
    case "klimmzuege":     return "Klimmzüge"
    case "unterarmstuetz": return "Unterarmstütz"
    case "seitstuetz":     return "Seitstütz"
    case "kniebeuge":      return "Kniebeuge (Wand)"
    case "rumpfbeuge":     return "Rumpfbeuge"
    case "sensomotorik":   return "Sensomotorik"
    case "symmetrie":      return "Symmetrie"
    case "reaktion":       return "Reaktion"
    case "cmj":            return "CMJ"
    case "tapping":        return "Tapping"
    case "sprint_10":      return "Sprint 10m"
    case "sprint_20":      return "Sprint 20m"
    case "sprint_30":      return "Sprint 30m"
    default:               return key.capitalized
    }
}
```

---

## Fix 5 — MetricsDetailSheet: BMI und Muskelmasse ergänzen

**Datei:** `ChatView.swift` — `struct MetricsDetailSheet` (ca. Zeile 840+)

Das Model `BodyMetric` hat: `weight`, `bodyFat`, `muscleMass`, `bmi`.
Aktuell zeigt `metricsTag` (in `ChatThreadView`) nur `weight` + `bodyFat`.

**MetricsDetailSheet — Zeile pro Wert mit Icon und Farbe (wie Flutter):**

```swift
// Ersetze den bestehenden Inhalt der metricsRow-Funktion / des metric-Listenbereichs

private func metricRows(for m: BodyMetric) -> some View {
    VStack(spacing: 0) {
        if let w = m.weight {
            metricRow(icon: "scalemass",     label: "Gewicht",     value: String(format: "%.1f kg", w),  color: AppColor.blue)
        }
        if let b = m.bmi {
            metricRow(icon: "speedometer",   label: "BMI",         value: String(format: "%.1f", b),      color: AppColor.green)
        }
        if let f = m.bodyFat {
            metricRow(icon: "drop.fill",     label: "Körperfett",  value: String(format: "%.1f %%", f),  color: AppColor.orange)
        }
        if let mm = m.muscleMass {
            metricRow(icon: "dumbbell.fill", label: "Muskelmasse", value: String(format: "%.1f kg", mm), color: AppColor.primary)
        }
    }
    .background(AppColor.surface)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
}

private func metricRow(icon: String, label: String, value: String, color: Color) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        Text(label)
            .font(.system(size: 14))
            .foregroundStyle(AppColor.text)
        Spacer()
        Text(value)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppColor.text)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
}
```

---

## Fix 6 — Gesendetes Nachrichtenformat verbessern

**Datei:** `ChatView.swift` — `ChatThreadView` Body (ca. Zeile 215–234)

**Ist:**
```swift
// Review:
let tag = "[Aufzeichnung] \(review.trainingType) | \(reviewSummary(review))"

// Performance:
let tag = "[Performance] \(test.testType)"

// Metriken:
let tag = "[Messwerte] \(metricsTag(metric))"
```

**Soll:** Datum integrieren, Metriken kompakter (entspricht Flutter-Format):
```swift
// Review — mit Datum und TRIMP-Rating
let df = DateFormatter(); df.locale = Locale(identifier: "de_DE"); df.dateFormat = "dd.MM.yyyy"
var tag = "[Aufzeichnung] \(review.trainingType) (\(df.string(from: review.date)))"
let summary = reviewSummary(review)
if !summary.isEmpty { tag += "\n\(summary)" }
if let t = review.edwardsTrimp { tag += " · \(TrainingReview.trimpRating(t))" }

// Performance — mit Datum
let df = DateFormatter(); df.locale = Locale(identifier: "de_DE"); df.dateFormat = "dd.MM.yyyy"
let tag = "[Performance] \(test.testType) (\(df.string(from: test.testDate)))"

// Metriken — mit Datum
let df = DateFormatter(); df.locale = Locale(identifier: "de_DE"); df.dateFormat = "dd.MM.yyyy"
var parts: [String] = []
if let w = metric.weight    { parts.append(String(format: "%.1f kg", w)) }
if let b = metric.bmi       { parts.append(String(format: "BMI %.1f", b)) }
if let f = metric.bodyFat   { parts.append(String(format: "KF %.1f%%", f)) }
let tag = "[Messwerte] (\(df.string(from: metric.measuredAt)))\n\(parts.joined(separator: " · "))"
```

---

## Reihenfolge der Änderungen

1. **Fix 2 zuerst** — `cardMeta` Rückgabetyp und `dataCard` (kein Abhängigkeits-Problem)
2. **Fix 1** — `attachRow` Signatur + Aufrufe
3. **Fix 4** — `perfRow` + Hilfsfunktionen in `PerformanceDetailSheet`
4. **Fix 3** — `ReviewRow` erweitern
5. **Fix 5** — `MetricsDetailSheet` Zeilen-Layout
6. **Fix 6** — Nachrichten-Tags aktualisieren

## Nach den Änderungen

- App bauen und prüfen dass keine Compiler-Fehler entstehen (Typ-Änderung in `cardMeta`)
- `AppColor.red`, `.green`, `.blue`, `.orange` in `Theme.swift` vorhanden? Falls nicht, vor Fix 2 ergänzen
- Auf Gerät testen: Jede Karte im Thread zeigt die richtige Farbe; Performance-Sheet zeigt Metriken-Liste

Buildbefehl:
```bash
cd /Users/piaclodimac.com/Admin-Backend-php/client-ios/SihlCient
xcodebuild -project SihlCient.xcodeproj -scheme SihlCient \
  -destination 'platform=iOS,id=00008120-001A6CE83C81A01E' \
  -derivedDataPath /tmp/sihl-attach-fix -allowProvisioningUpdates \
  build 2>&1 | grep -E "error:|warning:|BUILD"
```
