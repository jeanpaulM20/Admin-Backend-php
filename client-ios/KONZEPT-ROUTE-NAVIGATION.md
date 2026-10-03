# Konzept: Route starten — Aufzeichnung mit Navigation

Stand: 4. Oktober 2026 · Status: Phase 5.1 und 5.2 umgesetzt, 5.3 offen
Ergänzt KONZEPT-ROUTENPLANER.md (Phase 5).

## 1. Beobachtung und Ursache

**Beobachtung:** Nach „Tour starten" aus dem Planer landet man wieder im
Routenplaner statt in der Aufzeichnung; die Route lässt sich nicht wie mit
einem Navigationssystem ablaufen.

**Ursache (Code):** Die Aufzeichnung hat in der App genau einen Ort — den
Tab „Start" mit `RecordWorkoutView` und dem `WorkoutRecorder`. „Tour
starten" aus Planer, Tour-Detail und Assistent schiebt aber jeweils eine
**zweite Kopie** von `RecordWorkoutView` in den Navigationsstapel des
Touren-Tabs (eigener Recorder, eigene Sensoren):

| Einstieg | Code | Folge |
|---|---|---|
| Planer-Panel | `TourDiscoveryView` → `navigationDestination(item: $startRoute)` | Kopie im Touren-Stapel |
| Tour-Detail | `TourDetailView` → `navigationDestination(isPresented: $showRecord)` | Kopie im Touren-Stapel |
| Assistent | `TourAssistantView` → `navigationDestination(isPresented: $showRecord)` | Kopie im Sheet des Assistenten |

Die Kopie zeigt die Session als `fullScreenCover`; beim Beenden ruft ihr
`onDismiss` **`dismiss()`** auf und poppt die Kopie — man steht wieder im
Planer. Der Start-Tab weiss von alledem nichts: Er zeigt währenddessen
seine leere Startseite, und die Übersicht nach dem Training erscheint im
falschen Tab. Zusätzlich braucht jeder Start aus den Touren einen zweiten
Tipp („Training starten"), obwohl „Tour starten" bereits der Start war.

**Was heute beim Folgen fehlt:** Die Session kennt nur die Routenlinie
(`TourRoute`: Name, Segmente, Distanz, Aktivität) und prüft alle fünf
GPS-Punkte den Abstand zur Linie (Hinweis ab 100 m, zurück unter 60 m).
Es gibt keinen Fortschritt auf der Route, keine Restdistanz, keine
Resthöhenmeter, keine Ankunftszeit, keine Richtung zurück zur Route, keine
Abbiegehinweise, keine Zielerkennung. Höhen und Dauer der geplanten Route
gehen bei der Übergabe verloren.

## 2. Ziel

„Tour starten" bringt mich **mit einem Tipp** in die Aufzeichnung — dort,
wo jedes Training läuft (Tab „Start") — mit der Route als Leitlinie, und
die Aufzeichnung führt mich wie ein Navi: Karte in Laufrichtung, Rest
bis zum Ziel, Hinweis beim Verlassen der Route mit Richtung zurück,
Ankunft am Ziel, auf Wunsch Abbiegehinweise mit Sprache.

## 3. Übergabe: ein Ort für die Aufzeichnung (Phase 5.1)

- **`RecordingLauncher`** (@Observable, app-weit in der Environment wie
  `StartViewModel`): `func start(_ route: PlannedTourRoute)`. Er merkt sich
  die Route als `pending` und setzt `requestedTab = .start`.
- **`MainTabView`** beobachtet `requestedTab` und wechselt die Auswahl auf
  „Start". Der Touren-Stapel bleibt, wie er ist (der Planer behält seine
  Punkte — man kann nach dem Training zurück und die Route speichern).
- **Start-Tab `RecordWorkoutView`** beobachtet `pending`: Route in den
  Recorder laden, Aktivität vorwählen, **Aufzeichnung sofort starten** —
  mit 3-Sekunden-Countdown und „Abbrechen" (Gurt verbindet, GPS holt den
  ersten Fix). „Tour starten" war der Startbefehl; ein zweites „Training
  starten" entfällt.
- **Alle drei Einstiege** (Planer, Tour-Detail, Assistent) rufen nur noch
  den Launcher. Die gepushten Kopien von `RecordWorkoutView` und das
  `dismiss()` im `onDismiss` entfallen. Nach dem Beenden bleibt man im
  Start-Tab mit der gewohnten Übersicht.
- **Läuft bereits eine Aufzeichnung** (Recorder-Phase ≠ idle): Rückfrage
  „Laufendes Training beenden und Route starten?" — nie zwei Sessions.
- **Übergabemodell `PlannedTourRoute`** ersetzt `TourRoute`: Name,
  Segmente **mit Höhen**, Distanz, Höhenmeter auf/ab, Dauer (SAC),
  Aktivität, Rundkurs, optional benannte Wegpunkte (Planer-Punkte,
  Assistenten-Orte). Damit hat die Navigation ihre Grundlage.

## 4. Navigation während der Aufzeichnung (Phase 5.2)

**Fortschritt auf der Route** (`RouteProgress` im Recorder, bei jedem
Track-Punkt, nicht nur alle fünf):
- Projektion der Position auf die Route: nächster Linienabschnitt, aber
  **monoton** (nie zurück auf einen früheren Abschnitt — wichtig bei
  Hin-und-zurück-Strecken und Rundkursen), mit Toleranz für Abkürzungen.
- Daraus: zurückgelegte Routendistanz, **Restdistanz**, **Resthöhenmeter
  auf/ab** (aus den Höhen ab der Projektion), **Ankunft ca.** (Rest nach
  SAC-Formel mit dem Tempo der Aktivität, gemischt mit dem eigenen
  bisherigen Schnitt, sobald > 500 m zurückgelegt), nächster Wegpunkt mit
  Distanz.

**Karte:**
- Laufrichtung-oben und Kamera-Folgen gibt es schon. Neu: der Kamera-
  Mittelpunkt liegt **etwas voraus** (Position im unteren Drittel), damit
  man sieht, was kommt.
- **Gelaufener Teil** der Route grau, **Rest** blau; nächster Wegpunkt
  als Marker mit Distanz; Ziel-Fahne mit Restdistanz.
- Kennzahlen-Kacheln der Session bekommen eine Routen-Zeile:
  „Noch 4.2 km · ↑180 m · Ankunft ca. 15:40". Der Mini-Höhenprofil-Streifen
  (aus dem Planer) zeigt die aktuelle Position als Marker.

**Verlassen der Route** (bestehende Hysterese 100 / 60 m bleibt):
- Zusätzlich **Haptik** (Warn-Taptic) und ein Pfeil im Positionsmarker,
  der zur nächsten Routenstelle zeigt, mit Abstand („120 m ↗ zur Route").
- Sprachhinweis optional (siehe 5.4), Standard aus.

**Ankunft:** Innerhalb 30 m vom Ziel und mindestens 90 % der Route
abgeschritten → „Ziel erreicht" (Haptik, Banner) mit Vorschlag „Beenden".
Beim Rundkurs zählt der Start als Ziel, aber erst nach 90 %.

**Ohne Route** ändert sich nichts an der Session.

## 5. Abbiegehinweise mit Sprache (Phase 5.3, optional)

- BRouter liefert mit `turnInstructionMode=2` je Route **Voice-Hints**
  (Abstand, Abbiegewinkel, Typ: links/rechts/halb/Kehre). Das Backend
  reicht sie als `hints: [{at: m, turn: "TL"|"TR"|"TSLL"|…, text}]` in
  der Tour-Form durch — für Planer, Rundtour, A→B und Assistent gleich.
- Die Session zeigt den nächsten Hinweis als Banner („In 180 m links")
  mit Pfeil-Symbol und spricht ihn **auf Wunsch** (AVSpeechSynthesizer,
  Deutsch) bei 150 m und bei 30 m; Haptik beim Abbiegepunkt. Schalter
  „Sprachhinweise" in der Session (merkt sich die Wahl).
- Grenze ehrlich benannt: Abbiegehinweise stammen aus OSM-Wegdaten und
  sind auf Wanderwegen gröber als auf Strassen; sie ergänzen die Karte,
  sie ersetzen sie nicht.

## 6. Regeln und Kanten

- **GPS-Lebenszyklus** bleibt: eingeschaltet nur während der Aufzeichnung
  (Entscheidung vom September). Der Countdown holt den ersten Fix.
- **Hintergrund:** Haptik und Sprache funktionieren mit gesperrtem
  Bildschirm (Audio-Session `.playback` mit Ducking), die Karte nicht —
  eine Live-Aktivität auf dem Sperrbildschirm (Restdistanz, nächster
  Hinweis) ist ein eigener späterer Schritt.
- **Rundkurs:** Start = Ziel; Fortschritt monoton, Zielerkennung erst
  nach 90 %.
- **Abkürzung/Umweg:** Projektion erlaubt Vorsprünge bis 300 m entlang
  der Route (Abkürzung); grössere Sprünge werden als Off-Route behandelt,
  bis man wieder nahe der Linie ist.
- **Demo-Modus:** Übergabe und Fortschritt funktionieren mit der
  Luftlinie, Hinweise nennen „Demo".
- **Speichern nach dem Training:** Die Route bleibt im Planer; die
  Zusammenfassung bietet „Route behalten" (speichert sie unter Meine
  Routen, falls noch nicht geschehen).

## 7. Phasen und Aufwand

| Phase | Inhalt | Aufwand |
|---|---|---|
| **5.1 Übergabe** | Launcher, Tab-Wechsel, Autostart mit Countdown, drei Einstiege umgestellt, Kopien und `dismiss()` entfernt, `PlannedTourRoute` mit Höhen/Dauer, Rückfrage bei laufender Session | 1 Tag |
| **5.2 Navigation** | Fortschritt (monotone Projektion), Rest/Ankunft/nächster Wegpunkt, Karte voraus und gelaufener Teil grau, Profil-Marker, Off-Route-Pfeil + Haptik, Ankunft | 1.5 Tage |
| **5.3 Abbiegehinweise** | BRouter-Hints im Backend, Banner, Sprache (optional), Haptik | 1.5–2 Tage |

5.1 behebt den gemeldeten Fehler vollständig und ist für sich nutzbar.

## 8. Offene Entscheidungen (bitte bestätigen)

1. **Autostart** mit 3-Sekunden-Countdown nach „Tour starten" (vorgeschlagen) — oder Landung auf der Startseite mit einem weiteren Tipp?
2. **Sprachhinweise** standardmässig **aus**, per Schalter in der Session (vorgeschlagen).
3. **Phase 5.3** gleich mit umsetzen oder nach Praxiserfahrung mit 5.1/5.2?

## 9. Umsetzungsnotizen Phase 5.1 (4. Oktober 2026)

- `RecordingLauncher` (ViewModels, app-weit in der Environment): `start(route)`
  legt die Route ab und zählt `requestCount` hoch. `MainTabView` wechselt
  darauf auf „Start"; `TourDiscoveryView` und `TourAssistantView` schliessen
  ihre Sheets. Die Startseite holt die Route in `onAppear` und bei
  `requestCount`-Änderung ab (`takePendingRoute`).
- Startseite: Route in den Recorder, Aktivität vorgewählt, Countdown 3→1
  mit „Abbrechen" (lässt die Route liegen — „Training starten" nimmt sie
  mit, „×" auf der Routenkarte entfernt sie). Nach der Session räumt
  `onDismiss` Recorder und Route ab; kein `dismiss()` mehr.
- Entfernt: die gepushten `RecordWorkoutView(tour:)`-Kopien in Planer,
  Tour-Detail und Assistent; die Recovery-Warnung ist ein eigener
  `ViewModifier`.
- `TourRoute` trägt jetzt Höhen, Höhenmeter auf/ab und Dauer (Grundlage
  für 5.2).
- Nicht nötig: die Rückfrage bei laufender Session — die Session liegt als
  Vollbild über allen Tabs, „Tour starten" ist währenddessen unerreichbar.
- Geprüft im Simulator: Planer → „Tour starten" → Start-Tab mit laufender
  Session und Route; „Beenden" → Übersicht → Start-Tab, Route abgeräumt;
  Planer behält seine Punkte.

## 10. Umsetzungsnotizen Phase 5.2 (4. Oktober 2026)

- **Recorder:** `RouteProgress` (Stützpunkt, gelaufene und restliche
  Routendistanz, Resthöhenmeter ↑/↓ als Suffixsummen mit 2-m-Glättung,
  Ankunft in Minuten, Distanz zum nächsten Zwischenpunkt, Anteil).
  Projektion bei jedem Track-Punkt: Fenster 20 Punkte zurück bis 300 m
  voraus, monoton; ausserhalb des Fensters weltweit nächste Stelle
  (ausgedünnt), Sprung nach vorn nur bei < 60 m. Off-Route-Hysterese
  100/60 m bleibt, jetzt aus derselben Projektion. Ankunft bei ≥ 90 % und
  < 30 m vom Ende. ETA: SAC-Formel mit Richttempo je Aktivität, ab 500 m
  halbiert mit dem eigenen Schnitt.
- **Session:** Routen-Zeile „Noch · nächster Punkt / Hm noch / Ankunft
  ca." in beiden Layouts, „noch x km" im Vollbild-HUD; gelaufener Teil
  grau, Rest blau gestrichelt; Kamera mit Blick voraus (18 % der
  Kameradistanz in Laufrichtung) sobald Route und Richtung bekannt;
  Mini-Höhenprofil mit Positionsmarker, wenn die Route Höhen hat;
  Rückweg-Pfeil (Richtung relativ zur Kartendrehung) mit Abstand beim
  Verlassen; Haptik bei Verlassen, Zurückfinden und Ankunft; Banner
  „Ziel erreicht" mit „Beenden".
- **Übergabe:** `TourRoute.waypoints` aus den Planer-Punkten bzw. den
  Orten des Assistenten — Grundlage für „nächster Punkt".
- Ankunft zusätzlich, sobald der letzte Routenpunkt erreicht ist (Rest
  0 m) — die 30-m-Regel allein griff im Test nicht, weil der Läufer am
  Ende 91 m neben dem gesetzten Ziel vorbeizog. „Hm noch" zeigt „–",
  solange die Route keine Höhen hat (Demo).
- Geprüft im Simulator mit Routen auf der simulierten GPS-Bahn:
  Fortschritt (grau/blau), Rest und nächster Punkt, Rückweg-Pfeil mit
  Abstand, „Ziel erreicht" mit Beenden.
