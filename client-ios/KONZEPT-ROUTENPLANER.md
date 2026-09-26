# Konzept: Routenplaner — Start, Zwischenpunkte, Ziel

Stand: 26. September 2026 · Status: Konzept zur Freigabe

## 1. Ziel

Auf der Touren-Karte eine Route **selbst zusammenstecken**: Start antippen,
beliebig viele Zwischenpunkte, Ziel — das System berechnet den Weg
automatisch, passend zur Aktivität, und zeigt **vor dem Start** Distanz,
Höhenmeter (auf/ab), Dauer, Schwierigkeit und das Höhenprofil. Die geplante
Route lässt sich starten (mit Routen-Overlay und Off-Route-Hinweis wie bei
Touren), als GPX exportieren und — in einer späteren Phase — speichern.

Gilt für **alle Aktivitäten** des Generators: Wandern, Bergtour, Joggen,
Rennrad, Gravel, MTB — jede mit eigenem Routing-Profil.

## 2. Was bereits vorhanden ist (und wiederverwendet wird)

| Baustein | Wo | Rolle im Planer |
|---|---|---|
| BRouter-Aufruf `brouter(lonlats, profile)` | `tours.service.ts` | Akzeptiert **beliebig viele** Punkte (`lon,lat\|lon,lat\|…`) — Zwischenpunkte sind nativ möglich; liefert Koordinaten **mit Höhe**, Länge, gefilterten Aufstieg |
| Aktivitäts-Profile `roundtripSpec` | `tours.service.ts` | Profil, Richtgeschwindigkeit, Steigleistung je Aktivität — Dauer und Schwierigkeit werden bereits daraus berechnet |
| Antwortform von Rundtour/`routeAB` | `tours.service.ts` | `TourDetail`-JSON (Segmente mit `ele`, `elevationGain`, `durationMin`, `difficulty`) — der Planer liefert exakt dieselbe Form |
| `TourDetailView` | `Views/Touren` | Kennzahlen, Höhenprofil, GPX-Export, **„Tour starten"** mit Overlay + Off-Route — funktioniert unverändert für geplante Routen |
| `RoundtripActivity` | `TourService.swift` | Aktivitäts-Chips (Icon, Label, Profil) — dieselben Chips im Planer |
| `PlanTourSheet` (Rundtour) | `TourDiscoveryView` | Muster für Aktivitätswahl und Fehlerdarstellung |
| `OneShotLocator` | `Views/Touren` | „Start = mein Standort" mit einem Tipp |
| `GPXFile.write/parse` | `Services` | Export der geplanten Route; Import bleibt der alternative Weg |

**Kernaussage:** Die Rechenseite ist zu ~80 % vorhanden. Neu sind ein
schmaler Endpunkt für Via-Punkte, die **Interaktion auf der Karte** und
(Phase 3) die Persistenz.

## 3. Nutzerfluss

### 3.1 Einstieg
- Neuer Chip **„Route planen"** in der Filterzeile der Touren-Karte, neben
  „Hier suchen". Er ist ein Kontext-Chip (Surface-Stil), **kein zweiter
  CTA** — der orange „Rundtour"-Knopf bleibt die einzige CTA-Fläche
  (Ein-CTA-Prinzip).
- Antippen wechselt die Karte in den **Planungsmodus**: Die Tour-Karten
  unten weichen dem **Planungspanel**, die Kopfzeile zeigt „Route planen ·
  Punkt antippen", ein „Fertig/Abbrechen" erscheint links oben.

### 3.2 Punkte setzen — die Regel „der letzte Punkt ist das Ziel"
1. Erster Tipp auf die Karte → **Start** (Pin „S", olivgrün).
2. Zweiter Tipp → **Ziel** (Pin „Z", CTA-orange).
3. Jeder weitere Tipp → wird neues **Ziel**; das bisherige Ziel wird
   **Zwischenpunkt** (nummeriert 1, 2, 3 …).

Diese Regel braucht keine Moduswahl („jetzt Zwischenpunkt, jetzt Ziel") und
entspricht dem Verhalten bekannter Planer (Komoot, Strava).

Weitere Gesten:
- **„Mein Standort als Start"** — Knopf im Panel, nutzt `OneShotLocator`.
- **Pin antippen** → kleines Menü: *Löschen*, *Als Start setzen* (dreht die
  Reihenfolge), *Punkt verschieben* (Phase 2: direkt per Drag).
- **Rückgängig** (letzten Punkt entfernen) und **Alles löschen**.
- **Rundkurs**-Schalter: hängt den Start als Ziel an — für Runden vom
  Parkplatz aus.
- **Umkehren**: Reihenfolge spiegeln (Phase 2).

### 3.3 Automatische Berechnung
- Nach jeder Änderung (Punkt hinzu/weg/verschoben, Aktivität gewechselt)
  wird die Route **nach 400 ms Ruhe** neu berechnet; ein laufender Aufruf
  wird bei erneuter Änderung abgebrochen.
- Während der Berechnung: **gestrichelte Luftlinien** zwischen den Pins
  und ein Lade-Kreis im Panel — die Karte bleibt bedienbar.
- Ergebnis: die berechnete Route in der Track-Farbe (orange) unter den
  Pins; die Karte zoomt beim ersten Ergebnis auf die ganze Route.
- **Ein Punkt ist nicht erreichbar** (z. B. mitten im See): der Pin wird
  rot markiert, das Panel zeigt „Punkt 2 nicht erreichbar — verschieben
  oder löschen"; der Rest bleibt erhalten.

### 3.4 Das Planungspanel (unten)
- **Aktivitäts-Chips** (Wandern · Bergtour · Joggen · Rennrad · Gravel ·
  MTB) — Wechsel berechnet sofort neu, mit dem passenden Profil.
- **Live-Kennzahlen** in Kacheln: Distanz · Höhenmeter ↑ · Höhenmeter ↓ ·
  Dauer ca. · Schwierigkeit.
- **Mini-Höhenprofil** (eine Zeile) — das volle Profil im Detail.
- Aktionen: **„Tour starten"** (CTA), *Details* (öffnet `TourDetailView`
  mit Höhenprofil und GPX-Export), *Speichern* (Phase 3).

### 3.5 Starten
„Tour starten" übergibt die geplante Route wie eine gefundene Tour an
`RecordWorkoutView(tour:)`: Routen-Overlay (blau gestrichelt), eigene Spur
(orange), Off-Route-Hinweis, Aktivität vorgewählt. Nichts davon ist neu.

## 4. Berechnung und Backend

### 4.1 Neuer Endpunkt
`POST /api/client/tours/route/:clientId`
```json
{ "activity": "wandern", "points": [{"lat":47.37,"lon":8.54}, …], "roundtrip": false }
```
- Validierung: 2–25 Punkte, gültige Koordinaten, bekannte Aktivität.
- Ruft `brouter(lonlats, spec.profile)` mit **allen** Punkten in
  Reihenfolge; BRouter rastet jeden Punkt auf den nächsten Weg ein.
- Antwort in der bestehenden `TourDetail`-Form (`id: plan-…`, `generated:
  true`, ein Segment ≤ 2000 Punkte mit `ele`, `distanceKm`,
  `elevationGain`, **neu `elevationLoss`**, `durationMin`, `difficulty`).
  Der Abstieg wird aus den Höhen berechnet (gleiches 2-m-Glättungsprinzip
  wie im Recorder), damit ↑ und ↓ konsistent sind.
- **Cache** je (Punkte gerundet auf 5 Dezimalen, Profil) für 24 h — ein
  Nutzer, der Punkte hin- und herschiebt, erzeugt sonst viele Aufrufe.
- **Fair use** gegenüber brouter.de: Debounce im Client, Cache im Backend,
  Timeout 30 s. Fällt BRouter aus, meldet der Planer das ehrlich („Routing
  vorübergehend nicht erreichbar") statt Luftlinien als Route auszugeben.
  Mittelfristige Option: eigene BRouter-Instanz auf Railway (Java, ~1 GB
  Schweiz-Daten) — entkoppelt von der öffentlichen Instanz.

### 4.2 Demo-Modus
Ohne Backend zeigt der Planer **Luftlinien** mit Haversine-Distanz und dem
Hinweis „Demo: ohne Wegeführung und Höhen" — der Ablauf ist erlebbar, ohne
falsche Zahlen vorzutäuschen.

## 5. Persistenz — Phase 3: „Meine Routen"
- Tabelle `planned_route`: `id, client_id, name, activity, points (JSON),
  geometry (JSON, ausgedünnt), distance_m, elevation_gain, elevation_loss,
  duration_min, created_at, updated_at`.
- Endpunkte: `GET/POST/DELETE tours/planned/:clientId` mit
  `assertClientAccess` (Eigentumsprüfung wie bei Fotos).
- Auf der Touren-Karte eine Kartenreihe **„Meine Routen"** über den
  gefundenen Touren; Tipp → Detail → Starten / Bearbeiten (lädt die Punkte
  zurück in den Planer) / Löschen.
- Datenschutz: Geplante Routen beginnen typischerweise zu Hause. Sie
  bleiben **privat** (nur hinter Anmeldung, Eigentumsprüfung); es gibt
  keine Teilen-Funktion — falls die später kommt, greift die Kappung der
  Start-/Endpunkte aus dem Re-Identifikations-Hinweis.

## 6. Regeln und Kanten
- **Kein Netz:** Planungsmodus startet, aber die Berechnung meldet „Kein
  Netz — Route wird berechnet, sobald du online bist"; bereits berechnete
  Routen bleiben sichtbar.
- **Zu viele Punkte (> 25):** Hinweis; BRouter und die Bedienbarkeit
  verlieren darüber an Wert.
- **Pins:** 44-pt-Trefffläche, VoiceOver „Startpunkt", „Zwischenpunkt 2",
  „Ziel"; Pins liegen über Touren-Markern, damit sie nicht konkurrieren.
- **Verlassen des Modus** mit ungespeicherter Route: kurze Rückfrage
  „Planung verwerfen?" — nur wenn mindestens zwei Punkte gesetzt sind.
- **Tab-Wechsel** behält den Planungszustand (View-State), ein App-Neustart
  nicht (bis Phase 3).
- **Genauigkeit:** BRouter-Höhen stammen aus SRTM/Swisstopo-nahen Daten
  (±10 m); Dauer ist eine Schätzung mit Steigleistung — beides wird wie
  bei Touren als „ca." ausgewiesen.

## 7. Abgrenzung zu Rundtour und Assistent
Drei Wege zur selben Route-Form (`TourDetail`), klar getrennt nach Frage:
- **Rundtour** — „Ich will *x* km, egal wohin": ein Slider, eine Runde.
- **Route planen** — „Ich weiss, wo ich durch will": Punkte auf der Karte.
- **Assistent** — „Ich beschreibe es in Worten": der Chat nutzt in Phase 4
  denselben Via-Endpunkt („von Adliswil über den Uetliberg nach Zürich").

## 8. Phasen und Aufwand

| Phase | Inhalt | Aufwand |
|---|---|---|
| **1 · Kern** | Endpunkt mit Via-Punkten + `elevationLoss`; Planungsmodus mit Pins (Start/Zwischen/Ziel, Löschen, Rückgängig, Alles löschen, Mein Standort); Debounce + Abbruch; Panel mit Chips, Kennzahlen, Mini-Profil; Details; Tour starten; GPX-Export; Demo-Luftlinie | 2–3 Tage |
| **2 · Feinschliff** | Pins per Drag verschieben; Punkt **auf der Linie** einfügen (Linie ziehen → neuer Zwischenpunkt); Rundkurs-Schalter; Umkehren; rote Markierung unerreichbarer Punkte; Karten-Fit | 1–2 Tage |
| **3 · Meine Routen** | Tabelle + Endpunkte; Speichern/Umbenennen/Löschen; Kartenreihe auf der Touren-Karte; Bearbeiten lädt in den Planer | 1–2 Tage |
| **4 · Assistent** | Chat-Werkzeug `route_via` auf dem neuen Endpunkt; Vorschlag direkt in den Planer übernehmen | 0,5 Tag |

Phase 1 ist für sich vollständig nutzbar.

## 9. Offene Entscheidungen (bitte bestätigen)
1. **Einstieg:** Chip „Route planen" (vorgeschlagen) — oder zusätzlich
   *langes Drücken* auf die Karte setzt sofort den Start?
2. **Rundkurs** standardmässig **aus** (vorgeschlagen) — Runden entstehen
   bewusst per Schalter.
3. **Maximal 25 Punkte** — reicht das?
4. **Phase 3 zeitnah** oder erst nach Praxiserfahrung mit Phase 1?
