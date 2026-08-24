# Konzept: Training-Tracking mit Polar H10 + GPS-Routen (Komoot-Vorbild)

*Stand: 2026-08-24 — Analyse & Ausarbeitung für die native iOS-App (SihlClient)*

## 1. Zielbild

Im **Trainingsbereich** der App kann der Client ein Training **live aufzeichnen**:

- **Herzfrequenz** in Echtzeit über den **Polar H10** Brustgurt (Bluetooth LE)
- **GPS-Route** für Outdoor-Aktivitäten (Joggen, Radfahren, Wandern) mit
  Live-Karte, Distanz, Pace und Höhenmetern — nach dem Vorbild von Komoot
- Nach dem Training: **Zusammenfassung** (Karte + HF-Kurve + Statistiken),
  die automatisch in **Analytics** erscheint und mit dem **Trainer im Chat**
  geteilt werden kann

## 2. Ist-Analyse — was bereits existiert (und was fehlt)

Die entscheidende Erkenntnis der Code-Analyse: **Die gesamte Auswerte-Pipeline
für aufgezeichnete Trainings existiert bereits.** Das Tracking muss nur vorne
„einspeisen".

### Vorhanden ✅

| Baustein | Wo | Bedeutung fürs Tracking |
|---|---|---|
| `Review`-Entity | `nestjs-backend/src/entities/review.entity.ts` | Datenmodell für „ein aufgezeichnetes Training": `duration`, `kcal`, `heart_rate` (Ø), `training_type`, **`speed`**, **`distance`**, `trainingplan_id`, Feedback-Felder — passt fast 1:1 |
| `ReviewHeartRateTimeseries` | `review-heartrate-timeseries.entity.ts` | HF-Kurve pro Training (timestamp + value) — exakt das, was der H10 liefert |
| `POST /api/review` + `PUT` | `review.controller.ts` | Reviews können bereits angelegt werden (Timeseries-Schreib-Endpunkt fehlt noch) |
| Analytics-Auswertung | `client-ios .../Analytics/` | Trainingsliste, HF-Kurven-Detail, **Edwards TRIMP**, Trainingsvergleich — visualisiert jede neue Aufzeichnung sofort |
| Chat-Datenkarten | `ChatThreadView` | Aufzeichnungen können dem Trainer als `[Aufzeichnung]`-Karte geschickt werden |
| Trainingsplan-Verknüpfung | `review.trainingplan_id` | Aufzeichnung kann einem Plan zugeordnet werden |

### Fehlt ❌

| Baustein | Aufwand |
|---|---|
| Bluetooth-LE-Anbindung (CoreBluetooth) in der iOS-App | mittel |
| GPS-Aufzeichnung (CoreLocation) + Karte (MapKit) | mittel |
| Aufnahme-UI im Training-Tab (Live-Screen, Summary) | mittel |
| Backend: Batch-Upload-Endpunkt (Review + HF-Serie + GPS-Track in einem Request) | klein |
| Backend: GPS-Track-Tabelle | klein |
| Routen**planung** à la Komoot (A→B-Routing) | groß, externer Dienst nötig → Phase 3 |

**Wichtig:** Die serverseitige Polar-Integration (AccessLink/Polar Flow) ist im
NestJS-Backend aktuell nur ein **Stub** (`getPolarStatus` liefert immer
`connected: false`). Das ist für dieses Konzept aber **kein Blocker** — im
Gegenteil: Die **Live-BLE-Verbindung zum H10 braucht keine Polar-Cloud**. Der
Gurt sendet die Herzfrequenz direkt an das iPhone. Der Cloud-Sync kann später
unabhängig ergänzt werden (holt dann Trainings nach, die ohne App z. B. mit
einer Polar-Uhr aufgezeichnet wurden).

## 3. Nutzerfluss

```
Training-Tab
 └── „Training aufzeichnen" (neue Karte über der Planliste)
      └── Aktivität wählen:  🏃 Joggen · 🚴 Rad · 🥾 Wandern · 🏋️ Kraft (ohne GPS)
           └── Sensor-Check: H10 verbinden (optional überspringbar) + GPS-Fix
                └── AUFNAHME-SCREEN (Vollbild, Display bleibt an)
                     ├── Live-Karte mit Routenlinie (Outdoor)
                     ├── HF gross + Zonen-Farbe (AppColor.zone*)  ← Tokens existieren!
                     ├── Dauer · Distanz · Pace/Tempo · Höhenmeter
                     └── Pause / Fortsetzen / Beenden
                          └── ZUSAMMENFASSUNG
                               ├── Karte mit kompletter Route
                               ├── HF-Kurve (HrLineChart — existiert!)
                               ├── Stats: Dauer, Distanz, Ø/Max HF, TRIMP, kcal
                               ├── Feedback-Emoticon (Review-Feld existiert!)
                               ├── optional: Trainingsplan zuordnen
                               └── Speichern → Upload → erscheint in Analytics
```

Danach greift alles Bestehende automatisch: Analytics-Liste, HF-Detail,
TRIMP-Bewertung, Trainingsvergleich, Chat-Karte an den Trainer.

## 4. Technisches Konzept — iOS

### 4.1 Polar H10 über CoreBluetooth

Der H10 spricht den **standardisierten BLE Heart Rate Service** (`0x180D`,
Characteristic `0x2A37`) — es ist **kein Polar-SDK nötig**:

- `CBCentralManager`: Scan nach Service `180D`, Verbindung, Notify auf `2A37`
- Payload liefert HF (1 Hz) und **RR-Intervalle** (für spätere HRV-Auswertung —
  das `hrv`-Feld existiert im iOS-Modell bereits)
- Auto-Reconnect bei Abbruch (Gurt-Kontakt, Reichweite): `didDisconnect` →
  erneut verbinden, Lücken in der Serie einfach auslassen (die bestehende
  Chart-Logik filtert Nullwerte schon)
- Gurt-Merken über `UserDefaults` (Peripheral-UUID), damit „Verbinden" beim
  zweiten Mal automatisch klappt
- *(Optional später: offizielles Polar BLE SDK für EKG-Rohdaten — für dieses
  Konzept unnötig)*

**Wichtig fürs Testen:** BLE funktioniert **nicht im Simulator** — die
Sensor-Schicht braucht Gerätetests (iPhone + H10). Deshalb wird sie hinter ein
Protokoll gelegt (`HeartRateSource`), mit einer Simulations-Implementierung
für Demo-Modus und Simulator-Tests.

### 4.2 GPS-Aufzeichnung über CoreLocation

- `CLLocationManager` mit `activityType = .fitness`,
  `desiredAccuracy = kCLLocationAccuracyBest`,
  `allowsBackgroundLocationUpdates = true`,
  `pausesLocationUpdatesAutomatically = false`
- **Filterung**: Punkte mit `horizontalAccuracy > 30 m` verwerfen (GPS-Drift),
  Distanz über gefilterte Punkte summieren; Höhenmeter über geglättete
  `altitude`-Deltas (Schwelle ~2 m gegen Barometer-Rauschen)
- **Auto-Pause** (optional, Phase 2): Geschwindigkeit < Schwelle → Timer anhalten
- Live-Anzeige: `MapKit` mit `MKPolyline`-Overlay, das während der Aufnahme wächst

### 4.3 Aufnahme-Engine (Herzstück)

```
WorkoutRecorder (@Observable, MainActor)
 ├── state: idle / recording / paused / finished
 ├── hrSource: HeartRateSource        (BLE-H10 oder Simulation)
 ├── gpsSource: LocationSource        (CoreLocation oder aus)
 ├── samples:  [HrSample]             (1 Hz: timestamp + bpm)
 ├── track:    [TrackPoint]           (timestamp, lat, lon, ele, accuracy)
 ├── live:     Dauer, Distanz, Pace, aktuelle HF, HF-Zone
 └── persist:  JSON-Snapshot alle 30 s in FileManager
               → Crash/Kill-Recovery: „Unterbrochenes Training fortsetzen?"
```

**Absturzsicherheit ist Pflicht**: Ein 2-h-Training darf nicht verloren gehen,
wenn iOS die App beendet. Lokal speichern während der Aufnahme, Upload erst am
Ende (mit Retry; bei Offline-Ende bleibt das Training lokal und wird beim
nächsten App-Start nachgereicht).

### 4.4 Hintergrund & Berechtigungen

`project.yml` / Info.plist-Erweiterungen:

- `UIBackgroundModes`: `location` + `bluetooth-central` (Aufnahme läuft weiter,
  wenn das Display aus ist oder der Nutzer die App wechselt)
- `NSLocationWhenInUseUsageDescription` (reicht zusammen mit dem
  Background-Mode für Tracking bei laufender Session; „Always" ist **nicht** nötig)
- `NSBluetoothAlwaysUsageDescription`
- Aufnahme-Screen: `UIApplication.shared.isIdleTimerDisabled = true`

**Batterie-Realität**: GPS best-accuracy + BLE ≈ 6–10 %/h — üblich für
Tracking-Apps, sollte aber im Onboarding-Text stehen.

## 5. Komoot-Vorbild — saubere Scope-Abgrenzung

„Wie Komoot" zerfällt in drei sehr unterschiedlich teure Stufen:

**Stufe A — Route aufzeichnen & anzeigen** *(Phase 2, reine Bordmittel)*
Eigene Route live und in der Zusammenfassung auf der Karte; Distanz, Pace,
Höhenprofil (Höhe über Zeit als zweites Chart unter der HF-Kurve — 
`HrLineChart` ist dafür bereits parametrisierbar).

**Stufe B — Routen-Bibliothek** *(Phase 3a, Bordmittel)*
Alle aufgezeichneten Routen als Liste mit Karten-Thumbnails („Meine Routen",
filterbar nach Aktivität), **„Route wiederholen"** (alte Route als graue Linie,
Live-Position darüber — der eigentliche Komoot-Kern-Nutzen fürs Training),
**GPX-Export/-Import** (Share-Sheet; Komoot & Co. können GPX lesen → 
Interoperabilität statt Nachbau).

**Stufe C — Routen-Planung (A→B-Routing)** *(Phase 3b, externer Dienst nötig)*
Apple `MKDirections` kann **kein** Rad-/Wander-Routing. Optionen:

| Dienst | Profile | Kosten | Einschätzung |
|---|---|---|---|
| **OpenRouteService** (OSM) | foot-hiking, cycling-regular, running | frei (API-Key, faire Limits) | **Empfehlung** — reicht für den Zweck |
| GraphHopper | dito | Free-Tier klein | Alternative |
| Mapbox Directions | dito | ab Volumen kostenpflichtig | wenn ohnehin Mapbox-Karten gewünscht |
| Komoot selbst | — | keine öffentliche API | scheidet aus |

Kartendarstellung bleibt in allen Stufen **MapKit** (kostenlos, nativ);
optional später OSM-Outdoor-Tiles via `MKTileOverlay` für den „Komoot-Look".

**Empfehlung: A und B zuerst.** Sie liefern 90 % des Trainingsnutzens ohne
Fremddienst und ohne laufende Kosten. C ist ein eigenes Projekt und sollte erst
kommen, wenn A/B im Alltag laufen.

## 6. Backend-Erweiterungen (NestJS)

### 6.1 Neue Tabelle `review_gps_track`

Analog zur bestehenden HF-Timeseries:

```
review_gps_track: id, review_id (FK), timestamp (datetime),
                  lat (double), lon (double), ele (float), accuracy (float)
```

Zusätzlich im `Review` (kleine Migration): `source` ('app' | 'polar_sync' | 'manual'),
`elevation_gain` (int), optional `polyline` (text — encoded polyline für schnelle
Karten-Thumbnails ohne den vollen Track zu laden).

### 6.2 Neuer Endpunkt: Batch-Upload

```
POST /api/client/workouts/:clientId        (X-Auth-Token, assertClientAccess)
{
  "trainingType": "Joggen", "startedAt": "...", "duration": "00:52:10",
  "distance": 8432.5, "elevationGain": 120, "kcal": 610,
  "trainingplanId": null, "feedbackEmoticon": "💪",
  "hrSeries":  [{ "t": "...", "v": 142 }, ...],        // 1 Hz
  "gpsTrack":  [{ "t": "...", "lat": .., "lon": .., "ele": .., "acc": .. }, ...]
}
→ legt Review + Timeseries + GPS-Track in einer Transaktion an
→ Response: die fertige Review-Repräsentation (wie GET /api/client/reviews)
```

Ein Request am Trainingsende (1 h ≈ 3 600 HF-Punkte + ~1 500 GPS-Punkte
≈ 400–700 KB JSON; gzip über den bestehenden Client). Kein Live-Streaming
nötig — das hält Backend und Batterie einfach.

`GET /api/client/reviews` wird um `distance`, `elevationGain`, `source` und
(auf Anfrage, `?track=1` oder eigener Endpunkt `GET /api/review/:id/track`)
den GPS-Track erweitert — die bestehenden Flutter-/iOS-Parser ignorieren
unbekannte Felder, es bricht also nichts.

### 6.3 Trainer-Seite gratis

Da Aufzeichnungen normale `Review`-Zeilen sind, sieht der Trainer sie ohne
weitere Arbeit in seinen bestehenden Ansichten; Chat-Datenkarten funktionieren
unverändert.

## 7. Integration in den Trainingsbereich (iOS-UI)

Neue Dateien (Konvention wie bisher: Views/ViewModels/Services):

```
SihlClient/
 ├── Services/
 │    ├── HeartRateSource.swift        (Protokoll + PolarH10Source [CoreBluetooth]
 │    │                                 + SimulatedHeartRateSource [Demo])
 │    ├── LocationTracker.swift        (CoreLocation-Wrapper, Filterung, Distanz)
 │    └── WorkoutUploadService.swift   (Batch-Upload + Offline-Queue)
 ├── ViewModels/
 │    └── WorkoutRecorder.swift        (Aufnahme-Engine, s. 4.3)
 └── Views/Training/Record/
      ├── RecordStartView.swift        (Aktivitätswahl + Sensor-Check)
      ├── RecordingView.swift          (Live: Karte, HF, Stats, Pause/Stop)
      └── WorkoutSummaryView.swift     (Karte + HrLineChart + Stats + Speichern)
```

Einstieg: **„Training aufzeichnen"-Karte oben im Training-Tab** (über der
Planliste, im bestehenden Card-Stil mit `AppSpacing`/`AppRadius`-Tokens).
Navigation programmatisch (`navigationDestination(item:)`) — gemäß der
Architektur-Lektionen aus der Analytics-Sanierung. `RecordingView` als
`fullScreenCover` (verhindert versehentliches Weg-Navigieren).

Detail-Ansicht bestehender Aufzeichnungen (`TrainingReviewDetailView`) bekommt
in Phase 2 eine **Karten-Sektion** über der HF-Kurve, wenn ein GPS-Track
vorhanden ist.

## 8. Risiken & Grenzen

| Risiko | Gegenmaßnahme |
|---|---|
| BLE-Abbrüche (Gurtkontakt, Distanz) | Auto-Reconnect, Lücken tolerieren, Status-Anzeige im Live-Screen |
| iOS beendet App im Hintergrund | Background-Modes + lokale 30-s-Snapshots + Recovery-Dialog |
| GPS-Drift (Wald, Häuserschluchten, Tunnel) | Accuracy-Filter, Glättung; Distanz eher konservativ |
| Batterieverbrauch | Erwartung kommunizieren; Accuracy im Kraft-Modus aus |
| Kein Simulator-Test für BLE/GPS | `HeartRateSource`-Protokoll + Simulation; Demo-Modus zeigt Fake-Aufnahme |
| App-Store-Review | Nutzungsbeschreibungen sauber, Health-Bezug ohne HealthKit unkritisch |
| Datenschutz (Standortdaten!) | GPS-Tracks sind sensibel: nur eigener Client + Trainer; in Datenschutzerklärung aufnehmen |

## 9. Phasenplan

**Phase 1 — HF-Tracking MVP** *(kleinster echter Nutzen, ~Backend 1 Endpunkt + iOS 4 Dateien)*
H10 verbinden, Aufnahme (Timer + HF live + Zonenfarbe), Kraft-Modus ohne GPS,
Summary, Upload als Review + Timeseries → erscheint in Analytics/Chat.
*Kein* GPS, *keine* Karte — dadurch schnell lieferbar und am Gerät testbar.

**Phase 2 — Outdoor + Karte**
CoreLocation + MapKit: Live-Route, Distanz/Pace/Höhenmeter, GPS-Track-Upload,
Karten-Sektion im Review-Detail, Höhenprofil-Chart. Auto-Pause.

**Phase 3 — Komoot-Funktionen**
3a: Routen-Bibliothek, „Route wiederholen", GPX-Export/Import.
3b: Routenplanung über OpenRouteService (A→B, Profile Wandern/Rad/Laufen).

**Phase 4 — Ökosystem (optional)**
HealthKit-Export, Live Activity/Dynamic Island, Polar-AccessLink-Cloud-Sync
(ersetzt den heutigen Stub), Apple-Watch-Companion.

## 10. Offene Entscheidungen

1. **Nur Polar H10** oder beliebige BLE-Herzfrequenzgurte? (Standard-Service →
   jeder Gurt ginge; Empfehlung: generisch bauen, H10 als getesteter Weg)
2. Aufnahme **ohne Gurt** erlauben (nur GPS)? (Empfehlung: ja)
3. **kcal-Schätzung**: Formel aus HF/Gewicht/Alter (Keytel) oder weglassen bis
   HealthKit? (Gewicht/Alter liegen in den Körperwerten vor)
4. Budget/Konto für **OpenRouteService** in Phase 3b?
5. Soll der **Trainer** Aufzeichnungen kommentieren können (bestehendes
   `feedback_trainer`-Feld nutzen)?

---

*Fazit: Das Vorhaben ist gut machbar und fügt sich ungewöhnlich sauber ein,
weil das Review-Datenmodell samt HF-Timeseries und die komplette
Auswerte-Pipeline (Analytics, TRIMP, Vergleich, Chat) bereits existieren. Der
Polar H10 braucht keine Cloud und kein SDK — nur CoreBluetooth. Die
Komoot-Anmutung sollte in Stufen kommen: erst aufzeichnen & anzeigen, dann
Bibliothek & Wiederholen, erst zuletzt echte Routenplanung mit externem
Routing-Dienst.*
