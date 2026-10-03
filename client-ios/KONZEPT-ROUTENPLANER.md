# Konzept: Routenplaner — Start, Zwischenpunkte, Ziel

Stand: 26. September 2026 · Status: Phase 1 bis 4 umgesetzt

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
- Neuer Chip **„Route planen"** als Karten-Aktion **neben dem
  Lokalisieren-Knopf** (rechts über den Tour-Karten). Umsetzungsnotiz:
  In der Filterzeile war auf 402-pt-Geräten kein Platz für einen vierten
  Chip. Er ist ein Kontext-Chip (Surface-Stil), **kein zweiter CTA** —
  der orange „Rundtour"-Knopf bleibt die einzige CTA-Fläche
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

## 10. Umsetzungsnotizen Phase 2 (2. Oktober 2026)

- **Pins ziehen:** Karten-Annotationen nehmen in SwiftUI nur Tipps an, keine
  Zieh-Gesten. Die Planer-Pins liegen deshalb als eigene Ebene über der
  Karte (`PlannerPinsOverlay`) und folgen ihr über einen Kamera-Takt.
  Tipp auf einen Pin öffnet die Aktionen (löschen, Richtung umkehren).
- **Punkt auf der Linie einfügen:** Tipp auf die Route (18 pt Trefferbreite)
  fügt dort einen Zwischenpunkt ein, an der richtigen Stelle der
  Reihenfolge; anschliessend lässt er sich ziehen.
- **Rundkurs-Schalter** im Panel: führt vom letzten Punkt zurück zum Start;
  das Ziel wird dann zum nummerierten Punkt, der Start heisst „Start/Ziel".
- **Menü „…":** Richtung umkehren, Ganze Route zeigen, Details und
  Höhenprofil, Alle Punkte löschen. Tipp auf Kennzahlen oder Mini-Profil
  öffnet ebenfalls die Details.
- **Rote Markierung:** BRouter lehnt abgelegene Punkte nicht ab, sondern
  rastet sie auf den nächsten Weg ein. Das Backend liefert darum je Punkt
  den Abstand zur Route (`offRouteM`); ab 150 m wird der Pin rot und das
  Panel nennt den Abstand. Meldet BRouter einen Punkt ausdrücklich als
  nicht zuordenbar, kommt dessen Index mit der 422-Antwort.
- **Drosselung von brouter.de:** Antwortet bei schnellen Folgen mit 403
  „Please, retry later!" — wird als „ausgelastet" (503, mit „Nochmals
  versuchen") gemeldet, nicht als „Keine Route gefunden". Bei vielen
  gleichzeitigen Nutzern bleibt die eigene BRouter-Instanz (Abschnitt 4.1)
  die saubere Lösung.

## 11. Umsetzungsnotizen Phase 3 (2. Oktober 2026)

- **Speichern im Planer:** Lesezeichen im Panel. Eine neue Route fragt nach
  dem Namen (Vorschlag „Wandern · 12.4 km"); eine geladene Route wird
  direkt ersetzt. Gefülltes Lesezeichen = gespeichert und unverändert;
  jede Änderung macht es wieder leer. Im Menü „…" zusätzlich „Als neue
  Route speichern". Verlassen des Planers fragt nur noch bei
  ungespeicherter Arbeit nach.
- **Meine Routen:** Lesezeichen-Knopf neben „Route planen" öffnet eine
  Liste (statt der im Konzept skizzierten Kartenreihe — die hätte der
  Karte dauerhaft Platz genommen und skaliert nicht mit vielen Routen).
  Tipp = Details mit Höhenprofil, GPX und „Tour starten"; Menü je Zeile:
  Im Planer bearbeiten, Umbenennen, Löschen.
- **Backend:** Tabelle `planned_route` (Startup-Migration), Entity
  `PlannedRoute`, `PlannedRouteService`, Endpunkte
  `GET/POST tours/planned/:clientId` und
  `GET/PUT/DELETE tours/planned/:clientId/:routeId`. Die Geometrie wird
  beim Speichern serverseitig aus den Punkten berechnet (Routing-Cache),
  nicht vom Gerät übernommen. Eigentumsprüfung in jeder Abfrage
  (`client_id`), fremde IDs antworten mit 404. Höchstens 100 Routen je
  Klient. Beim Löschen eines Klienten gehen seine Routen mit.
- **Demo-Modus:** Speichern funktioniert für die laufende Sitzung
  (Speicher im Gerät), damit der Ablauf erlebbar ist.

## 12. Umsetzungsnotizen Phase 4 (2. Oktober 2026)

- **Werkzeug `route_ueber`** im Touren-Assistenten: Start, Zwischenziele
  und Ziel in Reihenfolge (2–25 Punkte), optional `rundkurs`. Der
  Assistent nutzt es bei Wünschen mit „über", „via", „vorbei an"; neu
  kennt er auch die Aktivität „bergtour". Nennt das Modell den Start
  nochmals als letzten Punkt, wird daraus serverseitig ein Rundkurs.
- **Planungspunkte an jeder Empfehlung:** Die Antwort trägt `route.plan`
  (Punkte, Planer-Aktivität, Rundkurs) — auch für A→B und die erzeugte
  Rundtour. „velo" (Trekking) wird im Planer zu „Gravel", weil der Planer
  kein Trekking-Profil hat; die Route kann dort leicht anders verlaufen.
- **„Im Planer anpassen"** auf der Routen-Karte im Chat: schliesst den
  Assistenten und lädt die Punkte in den Planer (Name als Vorschlag beim
  Speichern). Liegt dort ungespeicherte Arbeit, wird zuerst nachgefragt.
- **Darstellung:** Hervorhebungen in den Antworten (**fett**) werden als
  Auszeichnung gezeigt statt als Sternchen.
- **Geprüft** mit dem echten Modell: „Wanderung von Adliswil über die
  Felsenegg auf den Uetliberg" (3 Punkte, 7.9 km, ↑508 ↓147) und
  „Gravel-Runde ab Adliswil über Langnau und Thalwil und zurück"
  (Rundkurs, 3 Punkte, 12.9 km).

## 13. Quality Check Phase 2–4 (2. Oktober 2026)

Behoben nach eigenem und unabhängigem Review:

- **Speichern und Verwerfen:** Ein Speichern, das erst nach Verwerfen oder
  Laden einer anderen Route zurückkommt, hängt sich nicht mehr an die neue
  Planung (sonst hätte das nächste Speichern die alte Route überschrieben).
  Der Planer startet bei jedem Betreten frisch, ohne Rundkurs.
- **Gespeicherte Routen sind privat:** Die fünf Endpunkte lassen nur den
  Klienten selbst zu, auch keinen Trainer — passend zum Hinweis „nur für
  dich sichtbar".
- **Ersetzen:** längere Wartezeit (Server rechnet neu); existiert die
  geladene Route nicht mehr, wird sie als neue angelegt.
- **Abgebrochene Zieh-Geste** (Anruf, App-Wechsel) setzt den Pin ab und
  rechnet neu.
- **Einfügen auf der Linie** stimmt auch auf Hin-und-zurück-Strecken.
- **Assistent:** höchstens sechs Routing-Aufrufe je Anfrage; „velo"
  entfällt (Gravel/Rennrad/MTB), damit der Planer exakt gleich nachrechnet;
  Rundtour-Punkte liegen auf der Route statt auf dem Hilfskreis; Links in
  Antworten sind nicht antippbar.
- **Backend:** Klient löschen und Routen entfernen in einer Transaktion;
  Obergrenze unmittelbar vor dem Einfügen geprüft; Tabelle mit utf8mb4.
- **Suche:** grosse Regionen zoomen weit genug heraus; ein zweiter Tipp
  auf den Such-Pin setzt keinen doppelten Punkt.

Tageslimit des Assistenten: **30 Fragen pro Klient und Tag** (Standard im
Code, per `ASSISTANT_DAILY_LIMIT` übersteuerbar; `0` = kein Limit). Der
Tag wechselt um Mitternacht Schweizer Zeit. Der Zähler lebt im Speicher
der Instanz und beginnt nach einem Deploy von vorn.

## 14. Eigene BRouter-Instanz (vorbereitet, 3. Oktober 2026)

- Ordner `brouter/` im Repo: Dockerfile (BRouter 1.7.10, Java 17),
  `start.sh` (lädt fehlende/alte Kacheln E5_N45 + E10_N45 nach `/data`,
  startet den RouteServer), Zusatzprofil `hiking-beta` (nur auf brouter.de
  vorhanden, Kopie im Repo), `railway.json`, README mit Einrichtung.
- Backend: `ToursService` bekommt die Routing-Server an der Composition
  Root (`ClientModule`, Token `ROUTING_BASE_URLS`) — `BROUTER_URL` zuerst,
  brouter.de als Rückfallebene bei Ausfall/Überlast. Ohne `BROUTER_URL`
  ändert sich nichts.
- Einrichtung auf Railway: Dienst `brouter` aus dem Ordner, Volume unter
  `/data`, dann `BROUTER_URL=http://brouter.railway.internal:17777` im
  Backend. Siehe `brouter/README.md`.
- Noch nicht gebaut: lokal fehlen Docker und Java; der erste Bau auf
  Railway ist der Test.
